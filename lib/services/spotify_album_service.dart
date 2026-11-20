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

import 'package:http/http.dart' as http;

/// One track of a public Spotify album, as much as the embed page exposes.
class SpotifyAlbumTrack {
  const SpotifyAlbumTrack({
    required this.title,
    required this.artist,
    this.duration,
  });

  final String title;
  final String artist;
  final Duration? duration;
}

/// The album metadata needed to build a Musify playlist.
class SpotifyAlbum {
  const SpotifyAlbum({
    required this.id,
    required this.title,
    required this.artist,
    required this.tracks,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String? coverUrl;
  final List<SpotifyAlbumTrack> tracks;
}

/// The playlist metadata needed to build a Musify playlist.
class SpotifyPlaylist {
  const SpotifyPlaylist({
    required this.id,
    required this.title,
    required this.owner,
    required this.tracks,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String owner;
  final String? coverUrl;
  final List<SpotifyAlbumTrack> tracks;
}

String? _parseSpotifyId(String input, String kind) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final web = RegExp(
    r'open\.spotify\.com/(?:intl-[a-z-]+/)?' +
        kind +
        r'/([A-Za-z0-9]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (web != null) return web.group(1);

  final uri = RegExp(
    'spotify:' + kind + r':([A-Za-z0-9]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (uri != null) return uri.group(1);

  final bare = RegExp(r'^[A-Za-z0-9]{22}$').firstMatch(text);
  return bare?.group(0);
}

/// Accepts every shape Spotify uses when an album is shared:
/// `https://open.spotify.com/album/…`, an `intl-xx` localized link,
/// `spotify:album:…`, or the bare album id.
String? parseSpotifyAlbumId(String input) => _parseSpotifyId(input, 'album');

/// Accepts every shape Spotify uses when a playlist is shared.
String? parseSpotifyPlaylistId(String input) =>
    _parseSpotifyId(input, 'playlist');

/// The parsed shape shared by album and playlist embed pages.
class _SpotifyEmbed {
  const _SpotifyEmbed({
    required this.entity,
    required this.tracks,
  });

  final Map entity;
  final List<SpotifyAlbumTrack> tracks;
}

/// Reads a public Spotify embed page (`/embed/album/…` or
/// `/embed/playlist/…`). Spotify serves the whole track list in the
/// `__NEXT_DATA__` JSON without authentication — no token, no cookies, no
/// third-party proxy. Both entity kinds use the same `trackList` shape.
Future<_SpotifyEmbed?> _fetchEmbed(
  String kind,
  String id, {
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .get(
          Uri.https('open.spotify.com', '/embed/$kind/$id'),
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
            'Accept-Language': 'en',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return null;

    // Spotify's embed page always serves UTF-8, but the header may omit the
    // charset, in which case http would decode as Latin-1 and mangle titles.
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);

    final script = RegExp(
      r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(body);
    if (script == null) return null;

    final decoded = jsonDecode(script.group(1)!);
    if (decoded is! Map) return null;

    final entity = decoded['props']?['pageProps']?['state']?['data']?['entity'];
    if (entity is! Map) return null;

    final trackList = entity['trackList'];
    if (trackList is! List || trackList.isEmpty) return null;

    final tracks = <SpotifyAlbumTrack>[];
    for (final raw in trackList) {
      if (raw is! Map) continue;
      final title = (raw['title'] ?? raw['name'])?.toString().trim() ?? '';
      if (title.isEmpty) continue;
      final artist =
          (raw['subtitle'] ?? raw['artist'] ?? entity['subtitle'])
              ?.toString()
              .trim() ??
          '';
      final milliseconds = raw['duration'];
      tracks.add(
        SpotifyAlbumTrack(
          title: title,
          // Playlist subtitles join artists with a non-breaking space after
          // each comma; normalize it so the YouTube search query is clean.
          artist: artist.replaceAll('\u00A0', ' '),
          duration: milliseconds is num
              ? Duration(milliseconds: milliseconds.round())
              : null,
        ),
      );
    }
    if (tracks.isEmpty) return null;

    return _SpotifyEmbed(entity: entity, tracks: tracks);
  } catch (_) {
    return null;
  } finally {
    if (client == null) httpClient.close();
  }
}

/// Reads the public embed page of the album. Spotify serves the whole track
/// list there without authentication; no API token is involved.
Future<SpotifyAlbum?> fetchSpotifyAlbum(
  String albumId, {
  http.Client? client,
}) async {
  final embed = await _fetchEmbed('album', albumId, client: client);
  if (embed == null) return null;
  final entity = embed.entity;
  return SpotifyAlbum(
    id: entity['id']?.toString() ?? albumId,
    title: (entity['title'] ?? entity['name'])?.toString().trim() ?? '',
    artist: (entity['subtitle'] ?? '').toString().trim(),
    coverUrl: _albumCover(entity),
    tracks: embed.tracks,
  );
}

/// Reads a public Spotify playlist from its embed page and maps it into the
/// same shape the album importer uses. No CSV export, token, or proxy needed.
Future<SpotifyPlaylist?> fetchSpotifyPlaylist(
  String playlistId, {
  http.Client? client,
}) async {
  final embed = await _fetchEmbed('playlist', playlistId, client: client);
  if (embed == null) return null;
  final entity = embed.entity;
  return SpotifyPlaylist(
    id: entity['id']?.toString() ?? playlistId,
    title: (entity['title'] ?? entity['name'] ?? entity['subtitle'])
            ?.toString()
            .trim() ??
        '',
    owner: (entity['subtitle'] ?? '').toString().trim(),
    coverUrl: _albumCover(entity),
    tracks: embed.tracks,
  );
}

String? _albumCover(Map entity) {
  final visual = entity['visualIdentity'];
  if (visual is Map) {
    final images = visual['image'];
    if (images is List) {
      final url = _largestImageUrl(images);
      if (url != null) return url;
    }
  }

  final coverArt = entity['coverArt'];
  if (coverArt is Map) {
    final sources = coverArt['sources'];
    if (sources is List) {
      final url = _largestImageUrl(sources);
      if (url != null) return url;
    }
  }

  final images = entity['images'];
  if (images is List) return _largestImageUrl(images);
  return null;
}

String? _largestImageUrl(List<dynamic> images) {
  Map? best;
  num bestWidth = -1;
  for (final image in images) {
    if (image is! Map) continue;
    final url = image['url']?.toString();
    if (url == null || url.isEmpty) continue;
    final width = image['maxWidth'] ?? image['width'] ?? image['maxHeight'] ?? 0;
    final numericWidth = width is num ? width : 0;
    if (numericWidth >= bestWidth) {
      bestWidth = numericWidth;
      best = image;
    }
  }
  return best?['url']?.toString();
}
