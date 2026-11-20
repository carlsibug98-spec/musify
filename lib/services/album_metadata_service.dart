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

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

/// Real album metadata: the artist, release date and artwork. Sourced from the
/// public iTunes Search API — no token, no login — and cached locally so an
/// offline device still shows the last known values.
class AlbumMetadata {
  const AlbumMetadata({
    required this.artist,
    required this.releaseDate,
    this.artworkUrl,
  });

  final String artist;
  final DateTime? releaseDate;
  final String? artworkUrl;
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// A conservative title match: exact, or the same words with at most one
/// differing word and no short substring matches. This prevents a short album
/// like "Lia" from matching an unrelated "Tom Bailey" release.
bool _titlesMatch(String a, String b) {
  if (a == b) return true;
  if (a.isEmpty || b.isEmpty) return false;
  final aWords = a.split(' ');
  final bWords = b.split(' ');
  if (aWords.length != bWords.length) return false;
  var diff = 0;
  for (var i = 0; i < aWords.length; i++) {
    if (aWords[i] != bWords[i]) diff++;
  }
  return diff == 1 && aWords.length > 1;
}

String _cacheKey(String title, String? artist, String? expectedArtist) {
  final parts = <String>[title];
  if (artist != null && artist.isNotEmpty) parts.add(artist);
  if (expectedArtist != null && expectedArtist.isNotEmpty) {
    parts.add(expectedArtist);
  }
  return 'albumMeta_${_normalize(parts.join(' '))}';
}

/// Looks up real album metadata for [title]. Musify album titles are often
/// "Album - Artist", so a trailing artist is split out to improve the match.
/// Returns `null` on any failure — callers simply omit the fields.
Future<AlbumMetadata?> fetchAlbumMetadata(
  String title, {
  String? artist,
  String? expectedArtist,
  http.Client? client,
}) async {
  final box = Hive.box('userNoBackup');
  String? rawTitle = title.trim();
  String? hint = artist?.trim();
  var dash = rawTitle.lastIndexOf(' - ');
  if (dash == -1) dash = rawTitle.lastIndexOf(' – ');
  if (dash == -1) dash = rawTitle.lastIndexOf(' — ');
  if (dash != -1) {
    hint ??= rawTitle.substring(dash + 3).trim();
    rawTitle = rawTitle.substring(0, dash).trim();
  }
  final key = _cacheKey(title, artist, expectedArtist);

  final cached = box.get(key);
  if (cached is String && cached.isNotEmpty) {
    try {
      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      final cachedArtist = decoded['artist']?.toString() ?? '';
      // A cached value from an older, looser match can be wrong. If we now
      // know the real artist, discard a cache entry that disagrees with it.
      final knownArtist = _normalize(expectedArtist ?? hint ?? '');
      final cachedNorm = _normalize(cachedArtist);
      if (knownArtist.isEmpty ||
          cachedNorm.isEmpty ||
          cachedNorm.contains(knownArtist) ||
          knownArtist.contains(cachedNorm)) {
        return AlbumMetadata(
          artist: cachedArtist,
          releaseDate: decoded['date'] != null
              ? DateTime.tryParse(decoded['date'].toString())
              : null,
          artworkUrl: decoded['art']?.toString(),
        );
      }
    } catch (_) {}
  }

  // Include the known artist in the search so iTunes returns the right album.
  final searchArtist = hint?.isNotEmpty == true ? hint : expectedArtist;
  final query = searchArtist == null || searchArtist.isEmpty
      ? rawTitle
      : '$rawTitle $searchArtist';
  if (query.isEmpty) return null;

  final httpClient = client ?? http.Client();
  try {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': query,
      'entity': 'album',
      'limit': '5',
      'country': 'US',
    });
    final response = await httpClient
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    final results = decoded is Map ? decoded['results'] : null;
    if (results is! List || results.isEmpty) return null;

    final wanted = _normalize(rawTitle);
    final wantedArtist = _normalize(expectedArtist ?? hint ?? '');

    Map? best;
    for (final item in results) {
      if (item is! Map) continue;
      final name = _normalize(item['collectionName']?.toString() ?? '');
      if (!_titlesMatch(wanted, name)) continue;
      // If the album's real artist is known, require it to agree. A wrong
      // artist is worse than showing no metadata at all.
      if (wantedArtist.isNotEmpty) {
        final itemArtist = _normalize(item['artistName']?.toString() ?? '');
        if (itemArtist.isNotEmpty &&
            !itemArtist.contains(wantedArtist) &&
            !wantedArtist.contains(itemArtist)) {
          continue;
        }
      }
      best = item;
      break;
    }
    // No loose fallback: ambiguous results are simply omitted.
    if (best == null) return null;

    final meta = AlbumMetadata(
      artist: best['artistName']?.toString().trim() ?? '',
      releaseDate: DateTime.tryParse(best['releaseDate']?.toString() ?? ''),
      artworkUrl: best['artworkUrl100']?.toString(),
    );

    final toCache = jsonEncode({
      'artist': meta.artist,
      'date': meta.releaseDate?.toIso8601String(),
      'art': meta.artworkUrl,
    });
    await box.put(key, toCache);
    return meta;
  } catch (_) {
    return null;
  } finally {
    if (client == null) httpClient.close();
  }
}
