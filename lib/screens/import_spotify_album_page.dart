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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart' show logger;
import 'package:musify/services/artist_service.dart' show ytMusicClient;
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/spotify_album_service.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/formatter.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/mini_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A Spotify album link and the order it had there.
typedef _AlbumRow = ({int index, String title, String artist});

/// Imports a public Spotify album as a Musify playlist: reads the album from
/// its embed page, matches every track on YouTube Music, and keeps the album
/// cover and the original track order.
class ImportSpotifyAlbumPage extends StatefulWidget {
  const ImportSpotifyAlbumPage({super.key});

  @override
  State<ImportSpotifyAlbumPage> createState() => _ImportSpotifyAlbumPageState();
}

class _ImportSpotifyAlbumPageState extends State<ImportSpotifyAlbumPage> {
  // Shared across page instances so a second page cannot start a parallel
  // import while the first is still searching.
  static bool _importRunning = false;

  static const _batchSize = 8;
  static const _batchPause = Duration(milliseconds: 150);

  final _linkController = TextEditingController();
  bool _isImporting = false;
  SpotifyAlbum? _album;
  String? _createdPlaylistId;
  int _processedCount = 0;
  int _totalCount = 0;
  int _importedCount = 0;

  bool get _isBusy => _isImporting;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _linkController.text = text;
      _album = null;
      _createdPlaylistId = null;
      _importedCount = 0;
      _processedCount = 0;
      _totalCount = 0;
    });
  }

  Future<void> _startImport() async {
    if (_isBusy) {
      showToast(context, context.l10n!.spotifyAlbumAlreadyImporting);
      return;
    }
    if (_importRunning) {
      showToast(context, context.l10n!.spotifyAlbumAlreadyImporting);
      return;
    }

    final link = _linkController.text.trim();
    if (link.isEmpty) {
      showToast(context, context.l10n!.spotifyAlbumEmpty);
      return;
    }
    final albumId = parseSpotifyAlbumId(link);
    if (albumId == null) {
      showToast(context, context.l10n!.spotifyAlbumInvalid);
      return;
    }

    FocusScope.of(context).unfocus();
    _importRunning = true;
    setState(() {
      _isImporting = true;
      _album = null;
      _createdPlaylistId = null;
      _importedCount = 0;
      _processedCount = 0;
      _totalCount = 0;
    });

    var rateLimited = false;
    try {
      final album = await fetchSpotifyAlbum(albumId);
      if (!mounted) return;
      if (album == null) {
        showToast(context, context.l10n!.spotifyAlbumLoadFailed);
        return;
      }

      setState(() {
        _album = album;
        _totalCount = album.tracks.length;
      });

      final rows = <_AlbumRow>[
        for (var index = 0; index < album.tracks.length; index++)
          (
            index: index,
            title: album.tracks[index].title,
            artist: album.tracks[index].artist.isEmpty
                ? album.artist
                : album.tracks[index].artist,
          ),
      ];

      final foundByIndex = <int, Map<String, dynamic>>{};
      var missing = rows;
      final firstPass = await _searchBatch(
        rows,
        onProgress: (count) {
          if (!mounted) return;
          setState(() {
            _processedCount = (_processedCount + count).clamp(0, _totalCount);
          });
        },
      );
      foundByIndex.addAll(firstPass.found);
      missing = firstPass.missing;
      rateLimited = firstPass.rateLimited;

      // Retry misses once unless YouTube is actively rate-limiting the device.
      if (!rateLimited && missing.isNotEmpty) {
        final retryPass = await _searchBatch(
          missing,
          onProgress: (count) {
            if (!mounted) return;
            setState(() {
              _processedCount = (_processedCount + count).clamp(0, _totalCount);
            });
          },
        );
        foundByIndex.addAll(retryPass.found);
        missing = retryPass.missing;
        rateLimited = retryPass.rateLimited;
      }

      final foundSongs = [
        for (final row in rows)
          if (foundByIndex[row.index] case final song?) song,
      ];

      if (!mounted) return;
      if (foundSongs.isEmpty) {
        showToast(context, context.l10n!.spotifyAlbumNoMatches);
        return;
      }

      final (_, playlistId) = createCustomPlaylist(
        album.title,
        album.coverUrl,
        context,
      );
      addSongsInCustomPlaylist(context, playlistId, foundSongs);

      setState(() {
        _processedCount = _totalCount;
        _importedCount = foundSongs.length;
        _createdPlaylistId = playlistId;
      });

      final result = context.l10n!.spotifyAlbumImportResult(
        foundSongs.length,
        rows.length,
      );
      showToast(
        context,
        rateLimited ? '${context.l10n!.error}\n$result' : result,
      );
    } finally {
      _importRunning = false;
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Resolves [rows] in small batches and stops as soon as the service starts
  /// rate-limiting the device.
  Future<
    ({Map<int, Map<String, dynamic>> found, List<_AlbumRow> missing, bool rateLimited})
  >
  _searchBatch(
    List<_AlbumRow> rows, {
    required void Function(int processedCount) onProgress,
  }) async {
    final found = <int, Map<String, dynamic>>{};
    final missing = <_AlbumRow>[];

    for (var index = 0; index < rows.length; index += _batchSize) {
      final batch = rows.skip(index).take(_batchSize).toList();
      final batchResults = await Future.wait(
        batch.map((row) async {
          final (match, wasRateLimited) = await _findSong(
            '${row.title} ${row.artist}',
            expectedArtist: row.artist,
            expectedTitle: row.title,
          );
          return (row, match, wasRateLimited);
        }),
      );

      var batchRateLimited = false;
      for (final (row, match, wasRateLimited) in batchResults) {
        if (wasRateLimited) batchRateLimited = true;
        if (match == null) {
          missing.add(row);
        } else {
          found[row.index] = match;
        }
      }
      onProgress(batchResults.length);

      if (batchRateLimited) {
        missing.addAll(rows.skip(index + _batchSize));
        return (found: found, missing: missing, rateLimited: true);
      }
      await Future.delayed(_batchPause);
    }

    return (found: found, missing: missing, rateLimited: false);
  }

  Future<(Map<String, dynamic>?, bool)> _findSong(
    String query, {
    String? expectedArtist,
    String? expectedTitle,
  }) async {
    const maxAttempts = 2;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final video = await ytMusicClient.music.searchSong(
          query,
          expectedArtist: expectedArtist,
          expectedTitle: expectedTitle,
        );
        if (video == null) return (null, false);
        return (Map<String, dynamic>.from(returnSongLayout(0, video)), false);
      } on RequestLimitExceededException {
        if (attempt == maxAttempts - 1) return (null, true);
        await Future.delayed(const Duration(seconds: 2));
      } catch (e, stackTrace) {
        if (attempt == maxAttempts - 1) {
          logger.log(
            'Error matching Spotify album track "$query"',
            error: e,
            stackTrace: stackTrace,
          );
          return (null, false);
        }
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    return (null, false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.importSpotifyAlbumTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            l10n.importSpotifyAlbumInstructions,
            style: Daylight.ui(12.5, color: Daylight.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          DaylightCard(
            radius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _linkController,
                  enabled: !_isBusy,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => unawaited(_startImport()),
                  decoration: InputDecoration(
                    labelText: l10n.spotifyAlbumLink,
                    hintText: l10n.spotifyAlbumLinkHint,
                    filled: true,
                    fillColor: Daylight.cardTint,
                    suffixIcon: IconButton(
                      icon: const Icon(
                        FluentIcons.clipboard_paste_24_regular,
                        size: 18,
                      ),
                      tooltip: l10n.pasteFromClipboard,
                      color: Daylight.cobalt,
                      onPressed: _isBusy ? null : _pasteLink,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _isBusy ? null : () => unawaited(_startImport()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Daylight.cobalt,
                    foregroundColor: Daylight.onAccent,
                    disabledBackgroundColor: Daylight.cobalt.withValues(
                      alpha: 0.45,
                    ),
                    minimumSize: const Size.fromHeight(46),
                    shape: const StadiumBorder(),
                    textStyle: Daylight.ui(
                      12,
                      color: Daylight.onAccent,
                      weight: FontWeight.w600,
                    ),
                  ),
                  icon: _isBusy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Daylight.onAccent,
                          ),
                        )
                      : const Icon(FluentIcons.sparkle_24_regular, size: 17),
                  label: Text(
                    _isBusy ? l10n.spotifyAlbumImporting : l10n.importAlbum,
                  ),
                ),
              ],
            ),
          ),
          if (_album case final album?) ...[
            const SizedBox(height: 18),
            _buildAlbumCard(album),
          ],
          if (_isImporting) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _totalCount > 0
                    ? (_processedCount / _totalCount).clamp(0.0, 1.0)
                    : null,
                minHeight: 5,
                color: Daylight.cobalt,
                backgroundColor: Daylight.cobaltSoft,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _totalCount > 0
                  ? context.l10n!.spotifyPlaylistProgress(
                      _processedCount,
                      _totalCount,
                    )
                  : context.l10n!.spotifyAlbumReading,
              textAlign: TextAlign.center,
              style: Daylight.ui(10.5, color: Daylight.muted),
            ),
          ],
          if (_createdPlaylistId != null) ...[
            const SizedBox(height: 18),
            _buildResultCard(context),
          ],
          const SizedBox(height: MiniPlayer.playerHeight + 20),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(SpotifyAlbum album) {
    final cover = album.coverUrl;

    return DaylightCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: cover == null || cover.isEmpty
                  ? ColoredBox(
                      color: Daylight.cardTintStrong,
                      child: Icon(
                        FluentIcons.music_note_2_24_regular,
                        color: Daylight.faint,
                        size: 22,
                      ),
                    )
                  : Image(
                      image: ArtworkProvider.get(cover),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: Daylight.cardTintStrong,
                        child: Icon(
                          FluentIcons.music_note_2_24_regular,
                          color: Daylight.faint,
                          size: 22,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Daylight.ui(
                    13.5,
                    weight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  album.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Daylight.ui(11, color: Daylight.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n!.tracksCount(album.tracks.length),
                  style: Daylight.ui(10, color: Daylight.faint),
                ),
              ],
            ),
          ),
          if (_isImporting)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_createdPlaylistId != null)
            Icon(
              FluentIcons.checkmark_circle_24_filled,
              size: 22,
              color: Daylight.cobalt,
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    final l10n = context.l10n!;

    return DaylightCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                FluentIcons.checkmark_circle_24_filled,
                size: 20,
                color: Daylight.cobalt,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.spotifyAlbumImportResult(
                    _importedCount,
                    _totalCount,
                  ),
                  style: Daylight.ui(12, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push(
              '/library/playlist/$_createdPlaylistId',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Daylight.cobaltSoft,
              foregroundColor: Daylight.cobaltDeep,
              minimumSize: const Size.fromHeight(42),
              shape: const StadiumBorder(),
              textStyle: Daylight.ui(12, weight: FontWeight.w600),
            ),
            icon: const Icon(FluentIcons.play_24_filled, size: 15),
            label: Text(l10n.openPlaylist),
          ),
        ],
      ),
    );
  }
}
