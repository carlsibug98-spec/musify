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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/offline_playlist_dialogs.dart';

/// Downloads a playlist for offline playback, showing the download progress
/// and turning into a "remove offline" button once every song is stored.
///
/// Shared by the playlist page and the artist page: the artist page only has
/// its top songs on screen, so [resolvePlaylist] is what actually produces the
/// songs to download, and it is only called when the button is pressed.
class PlaylistDownloadButton extends StatefulWidget {
  const PlaylistDownloadButton({
    super.key,
    required this.playlistId,
    required this.resolvePlaylist,
    this.songs,
    this.requireSnapshotMatch = false,
  });

  final String playlistId;

  /// Loads the playlist together with its songs, on demand.
  final Future<Map?> Function() resolvePlaylist;

  /// The songs already on screen, when the caller has the whole list. Without
  /// them the button falls back to whether the playlist was downloaded.
  final List? songs;

  /// Also require the stored playlist snapshot to contain [songs]. Artists use
  /// this after refresh so files downloaded through another playlist cannot
  /// hide a newly discovered release.
  final bool requireSnapshotMatch;

  @override
  State<PlaylistDownloadButton> createState() => _PlaylistDownloadButtonState();
}

class _PlaylistDownloadButtonState extends State<PlaylistDownloadButton> {
  /// Whether the songs to download are still being read. On a page that does
  /// not hold them that is a whole discography, and nothing about the button
  /// would say so, so a second tap would read all of it a second time.
  bool _isResolving = false;

  String get playlistId => widget.playlistId;

  bool get _isOffline {
    final songs = widget.songs;
    if (songs == null) {
      return offlinePlaylistService.isPlaylistDownloaded(playlistId);
    }
    if (!isPlaylistFullyOffline(songs)) return false;
    if (!widget.requireSnapshotMatch) return true;

    // The files may already exist because another playlist downloaded them.
    // The artist itself is only current offline when its stored snapshot also
    // contains every song of the catalog now on screen.
    final snapshot = offlinePlaylistService.getOfflinePlaylist(playlistId);
    if (snapshot == null) return false;
    final snapshotIds = (snapshot['list'] as List? ?? const [])
        .map((song) => song['ytid'])
        .toSet();
    return songs.every((song) => snapshotIds.contains(song['ytid']));
  }

  @override
  Widget build(BuildContext context) {
    if (playlistId.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<List>(
      valueListenable: userOfflineSongs,
      builder: (context, _, __) => ValueListenableBuilder<List>(
        valueListenable: offlinePlaylistService.offlinePlaylists,
        builder: (context, __, ___) => ValueListenableBuilder<DownloadProgress>(
          valueListenable: offlinePlaylistService.getProgressNotifier(
            playlistId,
          ),
          builder: (context, progress, _) {
            final Widget child;
            if (_isOffline) {
              child = _buildStatusCircle(context, offline: true);
            } else if (offlinePlaylistService.isPlaylistDownloading(
              playlistId,
            )) {
              child = _buildProgress(context, progress);
            } else if (offlineMode.value) {
              child = const SizedBox.shrink(key: ValueKey('download-hidden'));
            } else if (_isResolving) {
              child = _buildResolving();
            } else {
              child = _buildStatusCircle(context, offline: false);
            }

            // The icon pops into the filled offline state when the last track
            // lands, so completion is visible without another toast.
            return AnimatedSwitcher(
              duration: Daylight.motion(
                context,
                const Duration(milliseconds: 260),
              ),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.78, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCircle(BuildContext context, {required bool offline}) {
    final tooltip = offline
        ? context.l10n!.removeOffline
        : context.l10n!.downloadPlaylist;

    return Tooltip(
      key: ValueKey(offline ? 'download-offline' : 'download-idle'),
      message: tooltip,
      child: Semantics(
        button: true,
        selected: offline,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: offline ? Daylight.cobalt : Daylight.card,
              shape: BoxShape.circle,
              border: offline ? null : Border.all(color: Daylight.lineStrong),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: offline
                  ? () => showRemoveOfflinePlaylistDialog(context, playlistId)
                  : () => _download(context),
              child: Icon(
                offline
                    ? FluentIcons.arrow_download_off_24_filled
                    : FluentIcons.arrow_download_24_filled,
                size: 18,
                color: offline ? Daylight.onAccent : Daylight.cobalt,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResolving() {
    return const SizedBox(
      key: ValueKey('download-resolving'),
      width: 48,
      height: 48,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context, DownloadProgress progress) {
    return SizedBox(
      key: const ValueKey('download-progress'),
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: progress.isCancelled ? null : progress.progress,
              strokeWidth: 3,
              color: Daylight.cobalt,
              backgroundColor: Daylight.cobaltSoft,
            ),
          ),
          if (!progress.isCancelled)
            IconButton(
              icon: Icon(
                FluentIcons.dismiss_24_filled,
                size: 14,
                color: Daylight.cobalt,
              ),
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              padding: EdgeInsets.zero,
              onPressed: () =>
                  offlinePlaylistService.cancelDownload(context, playlistId),
              tooltip: context.l10n!.cancel,
            ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    if (_isResolving) return;

    setState(() => _isResolving = true);
    Map? playlist;
    try {
      playlist = await widget.resolvePlaylist();
    } catch (_) {
      if (context.mounted) showToast(context, context.l10n!.error);
      return;
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
    if (!context.mounted) return;

    if (playlist == null) {
      showToast(context, context.l10n!.error);
      return;
    }

    await offlinePlaylistService.downloadPlaylist(context, playlist);
  }
}
