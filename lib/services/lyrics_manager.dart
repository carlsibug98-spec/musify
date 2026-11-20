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

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:musify/models/song_lyrics.dart';

class LyricsManager {
  /// Fetches lyrics for a song, preferring a timestamped (LRC) source so the
  /// lyrics screens can highlight the line that is currently playing.
  Future<SongLyrics?> fetchSongLyrics(
    String artistName,
    String title, {
    Duration? duration,
    String? album,
  }) async {
    final cleanedTitle = _cleanTitle(title);
    final artists = _artistVariants(artistName);
    if (cleanedTitle.isEmpty || artists.isEmpty) return null;

    SongLyrics? plainFallback;
    for (final artist in artists) {
      final result = await _fetchFromLrclib(
        artist,
        cleanedTitle,
        duration: duration,
        album: album,
      );
      if (result == null) continue;
      if (result.isSynced) return result;
      plainFallback ??= result;
    }

    if (plainFallback != null) return plainFallback;

    final plain = await fetchLyrics(artists.first, cleanedTitle);
    if (plain == null || plain.isEmpty) return null;

    return SongLyrics(plain: plain);
  }

  /// YouTube metadata often carries suffixes that LRCLIB does not store.
  /// Cleaning them raises the exact-match hit rate enormously.
  String _cleanTitle(String title) {
    var cleaned = title.trim();

    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*[\(\[]\s*(official\s*(music\s*)?video|official\s*audio|'
        r'lyric\s*video|lyrics?\s*video|visuali[sz]er|audio|music\s*video|'
        r'hd|hq|4k|explicit)\s*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*-\s*(official\s*(music\s*)?video|official\s*audio|'
        r'lyric\s*video|lyrics?\s*video|visuali[sz]er|audio|music\s*video)'
        r'\s*$',
        caseSensitive: false,
      ),
      '',
    );

    if (cleaned.endsWith(' Lyrics')) {
      cleaned = cleaned.substring(0, cleaned.length - 7).trim();
    } else if (cleaned.endsWith(' Karaoke')) {
      cleaned = cleaned.substring(0, cleaned.length - 8).trim();
    }
    return cleaned.trim();
  }

  /// Tries the full artist string first, then the primary artist only.
  List<String> _artistVariants(String artistName) {
    final variants = <String>[];
    void add(String value) {
      final cleaned = value
          .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*VEVO$', caseSensitive: false), '')
          .trim();
      if (cleaned.isNotEmpty && !variants.contains(cleaned)) {
        variants.add(cleaned);
      }
    }

    add(artistName);
    if (artistName.contains(',')) add(artistName.split(',').first);
    return variants.take(2).toList();
  }

  Future<String?> fetchLyrics(String artistName, String title) async {
    // Remove Lyrics/Karaoke only from end of title
    if (title.endsWith(' Lyrics')) {
      title = title.substring(0, title.length - 7).trim();
    } else if (title.endsWith(' Karaoke')) {
      title = title.substring(0, title.length - 8).trim();
    }

    // Validate title is not empty after sanitization
    if (title.isEmpty || artistName.isEmpty) {
      return null;
    }

    final lyricsFromLyricsOvh = await _fetchLyricsFromLyricsOvh(
      artistName,
      title,
    );
    if (lyricsFromLyricsOvh != null) {
      return lyricsFromLyricsOvh;
    }

    final lyricsFromParolesNet = await _fetchLyricsFromParolesNet(
      artistName.split(',')[0],
      title,
    );
    if (lyricsFromParolesNet != null) {
      return lyricsFromParolesNet;
    }

    final lyricsFromLyricsMania1 = await _fetchLyricsFromLyricsMania1(
      artistName,
      title,
    );
    return lyricsFromLyricsMania1;
  }

  // LRCLIB ---------------------------------------------------------------
  //
  // Free, open synced-lyrics API. `/api/get` is an exact match by artist,
  // track and duration; `/api/search` is the fallback when the exact record
  // is missing.

  Future<SongLyrics?> _fetchFromLrclib(
    String artistName,
    String title, {
    Duration? duration,
    String? album,
  }) async {
    final exact = await _lrclibGet(
      artistName,
      title,
      duration: duration,
      album: album,
    );

    // An exact record without timestamps should not hide a synced match found
    // through search, and a search match must agree with the track length.
    if (exact != null && exact.isSynced) return exact;

    final searched = await _lrclibSearch(
      artistName,
      title,
      duration: duration,
      album: album,
    );
    if (searched != null && searched.isSynced) return searched;

    return exact ?? searched;
  }

  Future<SongLyrics?> _lrclibGet(
    String artistName,
    String title, {
    Duration? duration,
    String? album,
  }) async {
    try {
      final params = <String, String>{
        'artist_name': artistName,
        'track_name': title,
      };
      if (duration != null && duration.inSeconds > 0) {
        params['duration'] = duration.inSeconds.toString();
      }
      if (album != null && album.trim().isNotEmpty) {
        params['album_name'] = album.trim();
      }

      final response = await http
          .get(
            Uri.https('lrclib.net', '/api/get', params),
            headers: const {'User-Agent': _lrclibUserAgent},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      return _parseLrclibResponse(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      return null;
    }
  }

  Future<SongLyrics?> _lrclibSearch(
    String artistName,
    String title, {
    Duration? duration,
    String? album,
  }) async {
    try {
      var results = await _lrclibSearchRequest({
        'track_name': title,
        'artist_name': artistName,
      });
      if (results.isEmpty) {
        results = await _lrclibSearchRequest({'q': '$artistName $title'});
      }
      if (results.isEmpty) return null;

      final targetSeconds = duration != null && duration.inSeconds > 0
          ? duration.inSeconds
          : null;
      final targetAlbum = (album ?? '').trim().toLowerCase();

      SongLyrics? firstSynced;
      SongLyrics? bestSynced;
      var bestDelta = 1 << 30;
      SongLyrics? firstParsed;

      bool albumMatches(Map<String, dynamic> json) {
        if (targetAlbum.isEmpty) return true;
        final candidate = (json['albumName'] as String?)?.trim().toLowerCase();
        return candidate == targetAlbum;
      }

      for (final result in results) {
        final json = (result as Map).cast<String, dynamic>();
        final parsed = _parseLrclibResponse(json);
        if (parsed == null) continue;
        firstParsed ??= parsed;
        if (!parsed.isSynced) continue;
        firstSynced ??= parsed;

        final candidateSeconds = (json['duration'] as num?)?.round();
        if (targetSeconds == null || candidateSeconds == null) continue;

        final delta = (candidateSeconds - targetSeconds).abs();
        // A match more than 3 seconds off is a different edit; its timestamps
        // drift against this audio, so plain lyrics are the honest fallback.
        if (delta > 3) continue;

        // Same album and same length is almost certainly the right version.
        // Prefer it over a closer duration from a different release.
        if (targetAlbum.isNotEmpty && albumMatches(json)) {
          return parsed;
        }
        if (delta < bestDelta) {
          bestDelta = delta;
          bestSynced = parsed;
        }
      }

      if (bestSynced != null) return bestSynced;
      if (targetSeconds == null) return firstSynced ?? firstParsed;

      // No synced record matches this audio. Keep readable plain lyrics
      // instead of an out-of-sync highlight.
      if (firstParsed == null) return null;
      return SongLyrics(plain: firstParsed.plain);
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>> _lrclibSearchRequest(Map<String, String> params) async {
    final response = await http
        .get(
          Uri.https('lrclib.net', '/api/search', params),
          headers: const {'User-Agent': _lrclibUserAgent},
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body);
    return decoded is List ? decoded : const [];
  }

  static const _lrclibUserAgent = 'Musify/10.6.0 (https://github.com/gokadzev/Musify)';

  SongLyrics? _parseLrclibResponse(Map<String, dynamic> json) {
    final plain = (json['plainLyrics'] as String?)?.trim() ?? '';
    final synced = (json['syncedLyrics'] as String?)?.trim() ?? '';
    if (plain.isEmpty && synced.isEmpty) return null;

    final timed = synced.isEmpty ? const <LyricsLine>[] : parseLrc(synced);
    return SongLyrics(
      plain: plain.isEmpty ? timed.map((l) => l.text).join('\n') : plain,
      timed: timed,
    );
  }

  /// Parses LRC text into timestamped lines. Metadata tags (`[ar:]`, `[ti:]`,
  /// `[offset:]`) are handled; word-level enhanced tags are stripped.
  static List<LyricsLine> parseLrc(String lrc) {
    var offset = Duration.zero;
    final lines = <LyricsLine>[];

    for (final rawLine in lrc.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final offsetMatch = RegExp(
        r'\[offset:\s*([+-]?\d+(?:\.\d+)?)\]',
        caseSensitive: false,
      ).firstMatch(line);
      if (offsetMatch != null) {
        offset = Duration(milliseconds: int.parse(offsetMatch.group(1)!));
        continue;
      }

      final timestamps = RegExp(
        r'\[(\d{1,2}):(\d{1,2}(?:\.\d+)?)\]',
      ).allMatches(line);
      if (timestamps.isEmpty) continue;

      final text = line
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
      if (text.isEmpty) continue;

      for (final match in timestamps) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!);
        var time = Duration(
          minutes: minutes,
          milliseconds: (seconds * 1000).round(),
        );
        time = offset == Duration.zero ? time : time + offset;
        if (time < Duration.zero) time = Duration.zero;
        lines.add(LyricsLine(text: text, time: time));
      }
    }

    lines.sort((a, b) => (a.time ?? Duration.zero).compareTo(
      b.time ?? Duration.zero,
    ));
    return lines;
  }

  Future<String?> _fetchLyricsFromLyricsOvh(
    String artistName,
    String title,
  ) async {
    try {
      final artistFormatted = _lyricsUrl(artistName.split(',')[0]);
      final titleFormatted = _lyricsUrl(title);
      final uri = Uri.parse(
        'https://api.lyrics.ovh/v1/$artistFormatted/$titleFormatted',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final lyrics = json['lyrics'] as String?;
        if (lyrics != null && lyrics.isNotEmpty) {
          return addCopyright(lyrics, 'lyrics.ovh');
        }
      }
    } catch (e) {
      // Silently fail and return null to try next source
      return null;
    }
    return null;
  }

  Future<String?> _fetchLyricsFromParolesNet(
    String artistName,
    String title,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.paroles.net/${_lyricsUrl(artistName)}/paroles-${_lyricsUrl(title)}',
      );
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final songTextElements = document.querySelectorAll('.song-text');

        if (songTextElements.isNotEmpty) {
          final lyricsLines = songTextElements.first.text.split('\n');
          if (lyricsLines.length > 1) {
            lyricsLines.removeAt(0);

            final finalLyrics = addCopyright(
              lyricsLines.join('\n'),
              'www.paroles.net',
            );
            return _removeSpaces(finalLyrics);
          }
        }
      }
    } catch (e) {
      // Silently fail and return null to try next source
      return null;
    }

    return null;
  }

  Future<String?> _fetchLyricsFromLyricsMania1(
    String artistName,
    String title,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.lyricsmania.com/${_lyricsManiaUrl(title)}_lyrics_${_lyricsManiaUrl(artistName)}.html',
      );
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final lyricsBodyElements = document.querySelectorAll('.lyrics-body');

        if (lyricsBodyElements.isNotEmpty) {
          return addCopyright(
            lyricsBodyElements.first.text,
            'www.lyricsmania.com',
          );
        }
      }
    } catch (e) {
      // Silently fail and return null
      return null;
    }

    return null;
  }

  String _lyricsUrl(String input) {
    var result = input.replaceAll(' ', '-').toLowerCase();
    // Remove special characters
    result = result.replaceAll(RegExp('[^a-z0-9-]'), '');
    // Clean up multiple/trailing dashes
    result = result.replaceAll(RegExp('-+'), '-');
    if (result.isNotEmpty && result.endsWith('-')) {
      result = result.substring(0, result.length - 1);
    }
    if (result.isNotEmpty && result.startsWith('-')) {
      result = result.substring(1);
    }
    return result;
  }

  String _lyricsManiaUrl(String input) {
    var result = input.replaceAll(' ', '_').toLowerCase();
    if (result.isNotEmpty && result.startsWith('_')) {
      result = result.substring(1);
    }
    if (result.isNotEmpty && result.endsWith('_')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  String _removeSpaces(String input) {
    return input.replaceAll(RegExp(' {2,}'), ' ');
  }

  String addCopyright(String input, String copyright) {
    return '$input\n\n© $copyright';
  }
}
