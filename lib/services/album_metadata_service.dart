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

String _cacheKey(String title, String? artist) =>
    'albumMeta_${_normalize(artist == null ? title : '$title $artist')}';

/// Looks up real album metadata for [title]. Musify album titles are often
/// "Album - Artist", so a trailing artist is split out to improve the match.
/// Returns `null` on any failure — callers simply omit the fields.
Future<AlbumMetadata?> fetchAlbumMetadata(
  String title, {
  String? artist,
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
  final key = _cacheKey(title, artist);

  final cached = box.get(key);
  if (cached is String && cached.isNotEmpty) {
    try {
      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      return AlbumMetadata(
        artist: decoded['artist']?.toString() ?? '',
        releaseDate: decoded['date'] != null
            ? DateTime.tryParse(decoded['date'].toString())
            : null,
        artworkUrl: decoded['art']?.toString(),
      );
    } catch (_) {}
  }

  final query = hint == null || hint.isEmpty ? rawTitle : '$rawTitle $hint';
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
    Map? best;
    for (final item in results) {
      if (item is! Map) continue;
      final name = _normalize(item['collectionName']?.toString() ?? '');
      if (name.contains(wanted) || wanted.contains(name)) {
        best = item;
        break;
      }
    }
    best ??= results.firstWhere((item) => item is Map, orElse: () => null);
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
