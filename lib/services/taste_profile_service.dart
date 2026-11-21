/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musify/services/artist_preference_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/utilities/listening_stats_utils.dart';
import 'package:musify/utilities/map_utils.dart';

/// Local interest profile. Spotify keeps the ranking server-side and sends the
/// client a resolved feed; Musify has no server, so the same signals are
/// collected here and used to rank the home shelves on device.
///
/// Signals are intentionally asymmetric:
/// - onboarding artist picks, likes, recent plays and qualified plays are read
///   from the stores that already own them (no double bookkeeping),
/// - skips and "not interested" are persisted here because nothing else keeps
///   them,
/// - `TasteDismissType` mirrors Spotify's `DismissedEntity$Type` wire names so
///   the distinction between hiding a card and rejecting an entity survives.
const tasteProfileStorageKey = 'tasteProfile';

/// Bumped whenever the profile changes so home shelves can rebuild without
/// polling Hive.
final tasteProfileRevision = ValueNotifier<int>(0);

enum TasteDismissType {
  explicitFeedback('EXPLICIT_FEEDBACK'),
  inlineCard('INLINE_CARD'),
  markedAsPlayed('MARKED_AS_PLAYED'),
  onboarding('ONBOARDING'),
  recentlyPlayed('RECENTLY_PLAYED'),
  recents('RECENTS'),
  showcase('SHOWCASE'),
  verticalVideoCard('VERTICAL_VIDEO_CARD');

  const TasteDismissType(this.wireName);

  final String wireName;
}

/// Undo token for a "not interested" tap.
class TasteFeedbackEntry {
  const TasteFeedbackEntry({
    required this.ytid,
    required this.artist,
    required this.previousArtistWeight,
  });

  final String? ytid;
  final String artist;
  final double previousArtistWeight;
}

/// One positive artist signal, used to title and seed the interest shelf.
class TasteArtistScore {
  const TasteArtistScore({required this.name, required this.score});

  final String name;
  final double score;
}

/// The artist a home interest shelf is built from. [id] may be empty when the
/// signal came from a song that predates artist ids; the caller can resolve the
/// name through the artist service.
class TasteSeedArtist {
  const TasteSeedArtist({required this.id, required this.name, this.image});

  final String id;
  final String name;
  final String? image;
}

/// Snapshot of the derived artist weights for one ranking pass.
class TasteAffinity {
  TasteAffinity._(this._scores, this._names, this._ids);

  final Map<String, double> _scores;
  final Map<String, String> _names;
  final Map<String, String> _ids;

  double forArtist(String? artist) => _scores[_normalizeArtist(artist)] ?? 0;

  String? idForArtist(String? artist) => _ids[_normalizeArtist(artist)];

  /// Strongest artist above [minimum]. Returns null when the profile has no
  /// positive signal, which keeps the home from inventing a reason.
  TasteArtistScore? topArtistScore({double minimum = 0}) {
    TasteArtistScore? best;
    for (final entry in _scores.entries) {
      if (entry.value <= minimum) continue;
      if (best != null && entry.value <= best.score) continue;
      final candidate = _names[entry.key];
      if (candidate == null || candidate.isEmpty) continue;
      best = TasteArtistScore(name: candidate, score: entry.value);
    }
    return best;
  }

  String? get topArtist => topArtistScore()?.name;
}

class TasteProfileService {
  TasteProfileService() {
    _read();
  }

  static const _hiddenSongTtl = Duration(days: 180);
  static const _sectionTtl = Duration(days: 7);
  static const _maxArtistWeight = 48.0;
  static const _minArtistWeight = -24.0;

  final Map<String, double> _artistWeights = {};
  final Map<String, int> _hiddenSongs = {};
  final Map<String, int> _sectionDismissedAt = {};
  final Map<String, String> _sectionDismissTypes = {};

  /// Builds the affinity map from the stores that already hold the signal.
  TasteAffinity affinitySnapshot() {
    final scores = <String, double>{};
    final names = <String, String>{};
    final ids = <String, String>{};

    void add(String? artist, double delta, {String? id}) {
      final name = artist?.trim() ?? '';
      final key = _normalizeArtist(name);
      if (key.isEmpty) return;
      names.putIfAbsent(key, () => name);
      if (id != null && id.trim().isNotEmpty) ids.putIfAbsent(key, () => id);
      scores[key] = (scores[key] ?? 0) + delta;
    }

    for (final entry in _artistWeights.entries) {
      scores[entry.key] = (scores[entry.key] ?? 0) + entry.value;
    }
    for (final artist in preferredArtists.value) {
      add(artist.name, 8, id: artist.id);
    }
    for (final song in userLikedSongsList.value.whereType<Map>()) {
      add(_artistOf(song), 3, id: _artistIdOf(song));
    }
    for (final song in userRecentlyPlayed.value.whereType<Map>()) {
      add(_artistOf(song), 0.75, id: _artistIdOf(song));
    }
    final monthSongs = listeningStatsService.monthTopSongs(
      listeningStatsMonthKey(DateTime.now()),
      limit: 40,
    );
    for (final song in monthSongs) {
      final plays = (song['playCount'] as num?)?.toInt() ?? 1;
      add(_artistOf(song), math.min(plays, 8) * 0.9, id: _artistIdOf(song));
    }

    return TasteAffinity._(scores, names, ids);
  }

  /// Picks the strongest positive artist for "Because you like …". Onboarding
  /// picks win ties because they are the user's explicit answer, matching the
  /// way Spotify's quiz outranks passive plays.
  TasteSeedArtist? topSeedArtist() {
    final affinity = affinitySnapshot();
    final top = affinity.topArtistScore(minimum: 2);
    if (top == null) return null;

    final key = _normalizeArtist(top.name);
    for (final artist in preferredArtists.value) {
      if (_normalizeArtist(artist.name) != key) continue;
      return TasteSeedArtist(
        id: artist.id,
        name: artist.name,
        image: artist.image,
      );
    }

    return TasteSeedArtist(
      id: affinity.idForArtist(top.name) ?? '',
      name: top.name,
    );
  }

  /// Ranks recommendation candidates for the home shelf. Hidden tracks and, by
  /// default, already-liked tracks are removed; recently played tracks stay but
  /// are pushed down. Three tracks per artist keeps one seed from taking over.
  List<Map> rankSongs(
    Iterable<dynamic> songs, {
    int limit = 10,
    Set<String> excludeIds = const {},
    bool excludeLiked = true,
  }) {
    final affinity = affinitySnapshot();
    final likedIds = excludeLiked
        ? userLikedSongsList.value
              .whereType<Map>()
              .map(songYtid)
              .whereType<String>()
              .toSet()
        : const <String>{};
    final recentIds = userRecentlyPlayed.value
        .whereType<Map>()
        .map(songYtid)
        .whereType<String>()
        .toList();

    final candidates = <_ScoredSong>[];
    final seen = <String>{};
    var order = 0;
    for (final raw in songs) {
      if (raw is! Map) continue;
      final ytid = songYtid(raw);
      if (ytid == null || !seen.add(ytid)) continue;
      if (excludeIds.contains(ytid)) continue;
      if (isSongHidden(raw)) continue;
      if (likedIds.contains(ytid)) continue;

      final recentIndex = recentIds.indexOf(ytid);
      final recencyPenalty = recentIndex < 0
          ? 0.0
          : math.max(0, 2.5 - recentIndex * 0.25).toDouble();
      candidates.add(
        _ScoredSong(
          song: raw,
          score: affinity.forArtist(_artistOf(raw)) - recencyPenalty,
          order: order++,
        ),
      );
    }

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.order.compareTo(b.order);
    });

    final selected = <Map>[];
    final perArtist = <String, int>{};
    for (final candidate in candidates) {
      if (selected.length >= limit) break;
      final key = _normalizeArtist(_artistOf(candidate.song));
      final count = perArtist[key] ?? 0;
      if (count >= 3) continue;
      perArtist[key] = count + 1;
      selected.add(candidate.song);
    }
    return selected;
  }

  bool isSongHidden(Map song) {
    final ytid = songYtid(song);
    if (ytid == null) return false;
    final hiddenAt = _hiddenSongs[ytid];
    if (hiddenAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - hiddenAt > _hiddenSongTtl.inMilliseconds) {
      _hiddenSongs.remove(ytid);
      return false;
    }
    return true;
  }

  /// Hides one track and pushes its artist down. The returned token restores
  /// both the hidden id and the exact previous artist weight.
  TasteFeedbackEntry markNotInterested(Map song) {
    final ytid = songYtid(song);
    final artist = _artistOf(song);
    final key = _normalizeArtist(artist);
    final previousWeight = key.isEmpty ? 0.0 : (_artistWeights[key] ?? 0);

    if (ytid != null) {
      _hiddenSongs[ytid] = DateTime.now().millisecondsSinceEpoch;
    }
    if (key.isNotEmpty) {
      _artistWeights[key] = _clampWeight(previousWeight - 8);
    }
    _save();
    tasteProfileRevision.value++;
    return TasteFeedbackEntry(
      ytid: ytid,
      artist: artist,
      previousArtistWeight: previousWeight,
    );
  }

  void undoNotInterested(TasteFeedbackEntry entry) {
    final ytid = entry.ytid;
    if (ytid != null) _hiddenSongs.remove(ytid);

    final key = _normalizeArtist(entry.artist);
    if (key.isNotEmpty) {
      if (entry.previousArtistWeight.abs() < 0.001) {
        _artistWeights.remove(key);
      } else {
        _artistWeights[key] = entry.previousArtistWeight;
      }
    }
    _save();
    tasteProfileRevision.value++;
  }

  /// A skip is only meaningful before the play qualifies. The audio handler
  /// asks this through [recordSkipIfUnqualified] so a completed play, a queue
  /// refill or an error-driven advance is never punished.
  void recordSkipIfUnqualified(Map? song, {required bool qualified}) {
    if (song == null || qualified) return;
    recordSkip(song);
  }

  void recordSkip(Map song) {
    final key = _normalizeArtist(_artistOf(song));
    if (key.isEmpty) return;
    _artistWeights[key] = _clampWeight((_artistWeights[key] ?? 0) - 1.5);
    _save();
    tasteProfileRevision.value++;
  }

  void dismissSection(
    String id, {
    TasteDismissType type = TasteDismissType.inlineCard,
  }) {
    if (id.isEmpty) return;
    _sectionDismissedAt[id] = DateTime.now().millisecondsSinceEpoch;
    _sectionDismissTypes[id] = type.wireName;
    _save();
    tasteProfileRevision.value++;
  }

  bool isSectionDismissed(String id, {Duration ttl = _sectionTtl}) {
    final dismissedAt = _sectionDismissedAt[id];
    if (dismissedAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - dismissedAt > ttl.inMilliseconds) {
      _sectionDismissedAt.remove(id);
      _sectionDismissTypes.remove(id);
      return false;
    }
    return true;
  }

  void undoSectionDismissal(String id) {
    if (_sectionDismissedAt.remove(id) == null) return;
    _sectionDismissTypes.remove(id);
    _save();
    tasteProfileRevision.value++;
  }

  Future<void> reset() async {
    _artistWeights.clear();
    _hiddenSongs.clear();
    _sectionDismissedAt.clear();
    _sectionDismissTypes.clear();
    await deleteData('settings', tasteProfileStorageKey);
    tasteProfileRevision.value++;
  }

  void _read() {
    try {
      final raw = Hive.box('settings').get(tasteProfileStorageKey);
      if (raw is! Map) return;

      final artists = raw['artists'];
      if (artists is Map) {
        artists.forEach((key, value) {
          final weight = (value as num?)?.toDouble();
          if (weight != null) _artistWeights[key.toString()] = weight;
        });
      }
      final hidden = raw['hiddenSongs'];
      if (hidden is Map) {
        hidden.forEach((key, value) {
          final at = (value as num?)?.toInt();
          if (at != null) _hiddenSongs[key.toString()] = at;
        });
      }
      final dismissed = raw['dismissedSections'];
      if (dismissed is Map) {
        dismissed.forEach((key, value) {
          final at = (value as num?)?.toInt();
          if (at != null) _sectionDismissedAt[key.toString()] = at;
        });
      }
      final types = raw['dismissedSectionTypes'];
      if (types is Map) {
        types.forEach((key, value) {
          final type = value?.toString();
          if (type != null) _sectionDismissTypes[key.toString()] = type;
        });
      }
    } catch (_) {
      // The settings box may not be open yet on a very early import; the first
      // write below will persist the next state.
    }
  }

  void _save() {
    unawaited(
      addOrUpdateData<Map<String, dynamic>>(
        'settings',
        tasteProfileStorageKey,
        {
          'artists': Map<String, double>.from(_artistWeights),
          'hiddenSongs': Map<String, int>.from(_hiddenSongs),
          'dismissedSections': Map<String, int>.from(_sectionDismissedAt),
          'dismissedSectionTypes': Map<String, String>.from(
            _sectionDismissTypes,
          ),
        },
      ),
    );
  }

  double _clampWeight(double value) =>
      value.clamp(_minArtistWeight, _maxArtistWeight);
}

final tasteProfileService = TasteProfileService();

class _ScoredSong {
  const _ScoredSong({
    required this.song,
    required this.score,
    required this.order,
  });

  final Map song;
  final double score;
  final int order;
}

String _artistOf(Map song) {
  final artist = song['artist']?.toString().trim() ?? '';
  if (artist.isNotEmpty) return artist;
  return song['uploader']?.toString().trim() ?? '';
}

String? _artistIdOf(Map song) {
  for (final key in const ['artistId', 'channelId']) {
    final value = song[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
  }
  return null;
}

String _normalizeArtist(String? artist) =>
    (artist ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
