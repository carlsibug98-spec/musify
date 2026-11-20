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
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/formatter.dart';
import 'package:musify/utilities/url_launcher.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/mini_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A source track and its original position, used to preserve playlist order.
typedef _ImportRow = ({int index, String title, String artist});

enum _ImportMode { link, csv }

/// Imports a public Spotify playlist as a Musify playlist. The default path
/// reads the playlist from its public embed page (no token, no CSV export),
/// matches every track on YouTube Music, and keeps the cover and track order.
/// A CSV export path is kept for playlists the embed page cannot expose.
class ImportSpotifyPlaylistPage extends StatefulWidget {
  const ImportSpotifyPlaylistPage({super.key});

  @override
  State<ImportSpotifyPlaylistPage> createState() =>
      _ImportSpotifyPlaylistPageState();
}

class _ImportSpotifyPlaylistPageState extends State<ImportSpotifyPlaylistPage> {
  // Shared across page instances so navigating away and reopening the page
  // can't spawn a second import running concurrently with the first.
  static bool _importRunning = false;

  // Limit concurrency and leave a short pause between batches.
  static const _batchSize = 12;
  static const _batchPause = Duration(milliseconds: 150);

  final _linkController = TextEditingController();
  final _csvController = TextEditingController();
  final _playlistNameController = TextEditingController();
  _ImportMode _mode = _ImportMode.link;
  bool _isImporting = false;
  String? _fileName;
  SpotifyPlaylist? _playlist;
  String? _createdPlaylistId;
  int _processedCount = 0;
  int _totalCount = 0;

  bool get _isBusy => _isImporting;

  @override
  void dispose() {
    _linkController.dispose();
    _csvController.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  void _switchMode(_ImportMode mode) {
    if (_isBusy) return;
    setState(() {
      _mode = mode;
      _playlist = null;
      _createdPlaylistId = null;
      _processedCount = 0;
      _totalCount = 0;
    });
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _linkController.text = text;
      _playlist = null;
      _createdPlaylistId = null;
      _processedCount = 0;
      _totalCount = 0;
    });
  }

  Future<void> _chooseFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result.isEmpty || !mounted) return;

    final file = result.single;
    final path = file.path;
    if (path == null) return;
    _csvController.text = await File(path).readAsString();
    if (!mounted) return;
    setState(() => _fileName = file.name);
  }

  Future<void> _startImport() async {
    if (_isBusy || _importRunning) {
      showToast(context, context.l10n!.spotifyPlaylistAlreadyImporting);
      return;
    }

    FocusScope.of(context).unfocus();
    _importRunning = true;
    setState(() {
      _isImporting = true;
      _playlist = null;
      _createdPlaylistId = null;
      _processedCount = 0;
      _totalCount = 0;
    });

    try {
      final (rows, title, coverUrl) = switch (_mode) {
        _ImportMode.link => await _readFromLink(),
        _ImportMode.csv => _readFromCsv(),
      };
      if (!mounted || rows == null) return;

      setState(() {
        _totalCount = rows.length;
        if (_mode == _ImportMode.link) {
          _playlist = SpotifyPlaylist(
            id: '',
            title: title ?? '',
            owner: '',
            tracks: const [],
            coverUrl: coverUrl,
          );
        }
      });

      final foundByIndex = <int, Map<String, dynamic>>{};
      List<_ImportRow> missing;
      var rateLimited = false;

      final firstPass = await _searchBatch(
        rows,
        onProgress: (n) {
          if (mounted) {
            setState(() {
              _processedCount = (_processedCount + n).clamp(0, _totalCount);
            });
          }
        },
      );
      foundByIndex.addAll(firstPass.found);
      missing = firstPass.missing;
      rateLimited = firstPass.rateLimited;

      if (!rateLimited && missing.isNotEmpty) {
        if (mounted) setState(() => _totalCount += missing.length);
        final retryPass = await _searchBatch(
          missing,
          onProgress: (n) {
            if (mounted) {
              setState(() {
                _processedCount = (_processedCount + n).clamp(0, _totalCount);
              });
            }
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
        showToast(context, context.l10n!.spotifyPlaylistNoMatches);
        return;
      }

      final typedName = _playlistNameController.text.trim();
      final finalName = typedName.isNotEmpty
          ? typedName
          : (title ?? context.l10n!.spotifyPlaylistNameHint);
      final (_, playlistId) = createCustomPlaylist(
        finalName,
        coverUrl,
        context,
      );
      addSongsInCustomPlaylist(context, playlistId, foundSongs);

      setState(() {
        _processedCount = _totalCount;
        _createdPlaylistId = playlistId;
      });

      final resultText = context.l10n!.spotifyPlaylistImportResult(
        foundSongs.length,
        rows.length,
      );
      if (missing.isNotEmpty) {
        final missingText = missing
            .map((row) => '${row.title} - ${row.artist}')
            .join('\n');
        await Clipboard.setData(ClipboardData(text: missingText));
        if (mounted) {
          final message =
              '${rateLimited ? '${context.l10n!.spotifyPlaylistImportFailed}\n' : ''}'
              '$resultText\n${context.l10n!.spotifyPlaylistMissingSongs}';
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(message),
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: context.l10n!.copy,
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: missingText)),
                ),
              ),
            );
        }
      } else {
        showToast(
          context,
          rateLimited
              ? '${context.l10n!.spotifyPlaylistImportFailed}\n$resultText'
              : resultText,
        );
      }
    } finally {
      _importRunning = false;
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Reads a Spotify playlist link from its public embed page.
  Future<(List<_ImportRow>?, String?, String?)> _readFromLink() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) {
      showToast(context, context.l10n!.spotifyPlaylistLinkEmpty);
      return (null, null, null);
    }
    final playlistId = parseSpotifyPlaylistId(link);
    if (playlistId == null) {
      showToast(context, context.l10n!.spotifyPlaylistLinkInvalid);
      return (null, null, null);
    }

    final playlist = await fetchSpotifyPlaylist(playlistId);
    if (!mounted) return (null, null, null);
    if (playlist == null) {
      showToast(context, context.l10n!.spotifyPlaylistLinkLoadFailed);
      return (null, null, null);
    }

    if (_playlistNameController.text.trim().isEmpty) {
      _playlistNameController.text = playlist.title;
    }

    final rows = <_ImportRow>[
      for (var index = 0; index < playlist.tracks.length; index++)
        (
          index: index,
          title: playlist.tracks[index].title,
          artist: playlist.tracks[index].artist.isEmpty
              ? playlist.owner
              : playlist.tracks[index].artist,
        ),
    ];
    return (rows, playlist.title, playlist.coverUrl);
  }

  /// Reads tracks from a pasted or picked CSV export.
  (List<_ImportRow>?, String?, String?) _readFromCsv() {
    final records = _parseCsv(_csvController.text);
    if (records.length < 2) {
      showToast(context, context.l10n!.spotifyPlaylistEmpty);
      return (null, null, null);
    }

    final headers = records.first
        .map((header) => header.replaceFirst('\ufeff', '').trim().toLowerCase())
        .toList();
    bool isNameColumn(String header) =>
        !header.contains('id') &&
        !header.contains('uri') &&
        !header.contains('url') &&
        !header.contains('genre');
    final songIndex = headers.indexWhere(
      (header) =>
          (header.contains('song') || header.contains('track')) &&
          isNameColumn(header),
    );
    final artistIndex = headers.indexWhere(
      (header) => header.contains('artist') && isNameColumn(header),
    );
    if (songIndex == -1 || artistIndex == -1) {
      showToast(context, context.l10n!.spotifyPlaylistInvalid);
      return (null, null, null);
    }

    final songs = records.skip(1).where((row) {
      return row.length > songIndex &&
          row.length > artistIndex &&
          row[songIndex].trim().isNotEmpty;
    }).toList();
    if (songs.isEmpty) {
      showToast(context, context.l10n!.spotifyPlaylistEmpty);
      return (null, null, null);
    }

    final rows = songs.indexed
        .map(
          (entry) => (
            index: entry.$1,
            title: entry.$2[songIndex].trim(),
            artist: entry.$2[artistIndex].trim(),
          ),
        )
        .toList();
    return (rows, null, null);
  }

  /// Resolves [rows] in batches and stops when rate limiting is detected.
  /// Results are keyed by the rows' original positions for retry merging.
  Future<
    ({
      Map<int, Map<String, dynamic>> found,
      List<_ImportRow> missing,
      bool rateLimited,
    })
  >
  _searchBatch(
    List<_ImportRow> rows, {
    required void Function(int processedCount) onProgress,
  }) async {
    final found = <int, Map<String, dynamic>>{};
    final missing = <_ImportRow>[];
    for (var i = 0; i < rows.length; i += _batchSize) {
      final batch = rows.skip(i).take(_batchSize).toList();
      final batchResults = await Future.wait(
        batch.map((row) async {
          final (match, wasRateLimited) = await _findSongWithRetry(
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
        missing.addAll(rows.skip(i + _batchSize));
        return (found: found, missing: missing, rateLimited: true);
      }
      await Future.delayed(_batchPause);
    }
    return (found: found, missing: missing, rateLimited: false);
  }

  /// Returns the best match for [query], or `null` if none was found.
  /// The second value is `true` when YouTube is actively rate-limiting this
  /// device, so the caller can stop the whole import instead of retrying
  /// every remaining song for minutes on end.
  Future<(Map<String, dynamic>?, bool)> _findSongWithRetry(
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
            'Error searching Spotify import match for "$query"',
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

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;

    for (var index = 0; index < input.length; index++) {
      final character = input[index];
      if (character == '"') {
        if (quoted && index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (character == ',' && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((character == '\n' || character == '\r') && !quoted) {
        if (character == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        field = StringBuffer();
        if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(character);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.importSpotifyPlaylistTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            l10n.importSpotifyPlaylistInstructions,
            style: Daylight.ui(12.5, color: Daylight.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DaylightPill(
                  label: context.l10n!.pastePlaylistLink,
                  selected: _mode == _ImportMode.link,
                  onTap: () => _switchMode(_ImportMode.link),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DaylightPill(
                  label: context.l10n!.importFromCsv,
                  selected: _mode == _ImportMode.csv,
                  onTap: () => _switchMode(_ImportMode.csv),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DaylightCard(
            radius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_mode == _ImportMode.link) ...[
                  TextField(
                    controller: _linkController,
                    enabled: !_isBusy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => unawaited(_startImport()),
                    decoration: InputDecoration(
                      labelText: l10n.spotifyPlaylistLink,
                      hintText: l10n.spotifyPlaylistLinkHint,
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
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _chooseFile,
                    icon: const Icon(FluentIcons.document_add_24_regular),
                    label: Text(_fileName ?? l10n.chooseCsvFile),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _csvController,
                    enabled: !_isBusy,
                    minLines: 8,
                    maxLines: 16,
                    decoration: InputDecoration(
                      labelText: l10n.pasteCsv,
                      hintText: l10n.spotifyCsvHint,
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Daylight.cardTint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => launchURL(
                      Uri.parse(
                        'https://www.chosic.com/spotify-playlist-exporter/',
                      ),
                    ),
                    icon: const Icon(FluentIcons.open_24_regular),
                    label: Text(l10n.openChosicExporter),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _playlistNameController,
                  enabled: !_isBusy,
                  decoration: InputDecoration(
                    labelText: '${l10n.playlistName} (${l10n.optional})',
                    hintText: l10n.spotifyPlaylistNameHint,
                    filled: true,
                    fillColor: Daylight.cardTint,
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
                    _isBusy
                        ? l10n.spotifyPlaylistImporting
                        : l10n.importPlaylist,
                  ),
                ),
              ],
            ),
          ),
          if (_playlist != null && _playlist!.title.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildPlaylistCard(_playlist!),
          ],
          if (_isImporting && _totalCount > 0) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_processedCount / _totalCount).clamp(0.0, 1.0),
                minHeight: 5,
                color: Daylight.cobalt,
                backgroundColor: Daylight.cobaltSoft,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              l10n.spotifyPlaylistProgress(_processedCount, _totalCount),
              textAlign: TextAlign.center,
              style: Daylight.ui(11, color: Daylight.muted),
            ),
          ],
          if (_createdPlaylistId != null && !_isImporting) ...[
            const SizedBox(height: 18),
            Center(
              child: DaylightPill(
                label: l10n.openPlaylist,
                selected: true,
                onTap: () =>
                    context.push('/library/playlist/$_createdPlaylistId'),
              ),
            ),
          ],
          const SizedBox(height: MiniPlayer.playerHeight + 24),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(SpotifyPlaylist playlist) {
    return DaylightCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          DaylightCover(
            size: 64,
            imageUrl: playlist.coverUrl,
            icon: FluentIcons.music_note_2_24_filled,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Daylight.display(16, height: 1.15),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n!.tracksCount(playlist.tracks.length),
                  style: Daylight.ui(11, color: Daylight.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
