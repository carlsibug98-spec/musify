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

import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/offline_playlist_dialogs.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          offlinePlaylistService.offlinePlaylists,
          userOfflineSongs,
          userCustomPlaylists,
        ]),
        builder: (context, _) {
          final playlists = offlinePlaylistService.offlinePlaylists.value
              .where((p) => p is Map && !PlaylistUtils.isArtistPlaylist(p))
              .cast<Map>()
              .toList();
          final artists = offlinePlaylistService.offlinePlaylists.value
              .where((p) => p is Map && PlaylistUtils.isArtistPlaylist(p))
              .cast<Map>()
              .toList();
          final songs = userOfflineSongs.value;
          final audioBytes = _totalSize(songs, 'audioPath');
          final artworkBytes = _totalSize(songs, 'artworkPath');
          final activeIds = List<String>.from(
            offlinePlaylistService.activeDownloads,
          );
          final isEmpty =
              songs.isEmpty &&
              playlists.isEmpty &&
              artists.isEmpty &&
              activeIds.isEmpty;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: DaylightAppBar(
                  overline: context.l10n!.downloads,
                  showBack: true,
                  onBack: () => context.pop(),
                  actions: [
                    if (songs.isNotEmpty || playlists.isNotEmpty)
                      DaylightCircleButton(
                        icon: FluentIcons.delete_24_regular,
                        tooltip: context.l10n!.deleteDownloads,
                        iconSize: 16,
                        color: Daylight.danger,
                        onTap: () => _confirmDeleteAll(context),
                      ),
                  ],
                ),
              ),
              if (isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: DaylightEmptyState(
                      title: context.l10n!.downloaded,
                      message: context.l10n!.libraryQuietNote,
                      icon: FluentIcons.cloud_off_24_regular,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      _StorageCard(
                        audioBytes: audioBytes,
                        artworkBytes: artworkBytes,
                        count: songs.length,
                      ),
                      if (activeIds.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        DaylightSectionHeader(
                          title: context.l10n!.downloads,
                        ),
                        for (final id in activeIds)
                          _ActiveDownload(
                            playlistId: id,
                            title: _titleFor(id),
                          ),
                      ],
                      const SizedBox(height: 16),
                      if (playlists.isNotEmpty || artists.isNotEmpty) ...[
                        DaylightSectionHeader(
                          title: context.l10n!.albums,
                          actionLabel: context.l10n!.manage,
                          onAction: () => setState(() {}),
                        ),
                        for (final playlist in playlists)
                          _DownloadItem(
                            title: playlist['title']?.toString() ?? '',
                            subtitle: _playlistSubtitle(playlist),
                            imageUrl: playlist['image']?.toString(),
                            bytes: _playlistBytes(playlist),
                            onTap: () => context.push(
                              '/library/playlist/${playlist['ytid']}',
                            ),
                            onRemove: () => showRemoveOfflinePlaylistDialog(
                              context,
                              playlist['ytid']?.toString() ?? '',
                            ),
                          ),
                        for (final artist in artists)
                          _DownloadItem(
                            title: artist['title']?.toString() ?? '',
                            subtitle: context.l10n!.artist,
                            imageUrl: artist['image']?.toString(),
                            bytes: _playlistBytes(artist),
                            onTap: () => context.push(
                              '/library/artist/${artist['ytid']}',
                            ),
                            onRemove: () => showRemoveOfflinePlaylistDialog(
                              context,
                              artist['ytid']?.toString() ?? '',
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      DaylightSectionHeader(
                        title: context.l10n!.songs,
                        actionLabel: context.l10n!.seeAll,
                        onAction: () => NavigationManager.router.go(
                          '/library/userSongs/offline',
                        ),
                      ),
                      if (songs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            context.l10n!.noSongsInQueue,
                            style: Daylight.ui(12, color: Daylight.muted),
                          ),
                        ),
                      for (final song in songs.take(5))
                        _SongRow(
                          song: song is Map ? song : const {},
                          onRemove: () async {
                            final removed = await offlinePlaylistService
                                .removeSongFromOfflineAndResync(
                                  (song as Map)['ytid']?.toString() ?? '',
                                );
                            if (removed && context.mounted) {
                              showToast(context, context.l10n!.downloadsDeleted);
                            }
                          },
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            FluentIcons.checkmark_circle_24_regular,
                            size: 14,
                            color: Daylight.cobalt,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.l10n!.downloaded,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Daylight.ui(10, color: Daylight.faint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              const SliverMiniPlayerBottomSpace(),
            ],
          );
        },
      ),
    );
  }

  String _titleFor(String id) {
    for (final playlist in [
      ...offlinePlaylistService.offlinePlaylists.value.whereType<Map>(),
      ...userCustomPlaylists.value,
      ...playlists,
    ]) {
      if (playlist['ytid']?.toString() == id) {
        return playlist['title']?.toString() ?? id;
      }
    }
    return id;
  }

  String _playlistSubtitle(Map playlist) {
    final count = (playlist['list'] as List?)?.length ?? 0;
    final source = playlist['source']?.toString();
    return [
      if (count > 0) '$count ${context.l10n!.tracks}',
      if (source != null && source.isNotEmpty) source,
    ].join(' · ');
  }

  int _playlistBytes(Map playlist) {
    final list = playlist['list'] as List?;
    if (list == null) return 0;
    var bytes = 0;
    for (final song in list) {
      if (song is Map) bytes += _fileSize(song['audioPath']?.toString());
    }
    return bytes;
  }

  int _totalSize(List<dynamic> songs, String key) {
    var bytes = 0;
    for (final song in songs) {
      if (song is! Map) continue;
      bytes += _fileSize(song[key]?.toString());
    }
    return bytes;
  }

  int _fileSize(String? path) {
    if (path == null || path.isEmpty) return 0;
    try {
      final file = File(path);
      return file.existsSync() ? file.lengthSync() : 0;
    } catch (_) {
      return 0;
    }
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmationDialog(
        confirmationMessage: context.l10n!.deleteDownloadsQuestion,
        submitMessage: context.l10n!.deleteDownloads,
        isDangerous: true,
        onCancel: () => Navigator.of(dialogContext).pop(),
        onSubmit: () async {
          Navigator.of(dialogContext).pop();
          await offlinePlaylistService.deleteAllDownloads();
          if (context.mounted) {
            showToast(context, context.l10n!.downloadsDeleted);
          }
        },
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.audioBytes,
    required this.artworkBytes,
    required this.count,
  });

  final int audioBytes;
  final int artworkBytes;
  final int count;

  @override
  Widget build(BuildContext context) {
    final total = audioBytes + artworkBytes;
    final musicShare = total == 0 ? 0.0 : audioBytes / total;

    return DaylightCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatBytes(total),
                style: Daylight.display(24, letterSpacing: -0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${context.l10n!.onThisPhone} · $count ${context.l10n!.tracks}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Daylight.ui(10.5, color: Daylight.muted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              DaylightProgressBar(value: 1, height: 7),
              FractionallySizedBox(
                widthFactor: musicShare.clamp(0.0, 1.0),
                child: DaylightProgressBar(
                  value: 1,
                  height: 7,
                  color: Daylight.cobalt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${context.l10n!.songs} ${_formatBytes(audioBytes)}',
                style: Daylight.ui(9.5, color: Daylight.muted),
              ),
              const Spacer(),
              Text(
                '${context.l10n!.downloaded} ${_formatBytes(artworkBytes)}',
                style: Daylight.ui(9.5, color: Daylight.faint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveDownload extends StatelessWidget {
  const _ActiveDownload({required this.playlistId, required this.title});

  final String playlistId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final notifier = offlinePlaylistService.getProgressNotifier(playlistId);
    return ValueListenableBuilder<DownloadProgress>(
      valueListenable: notifier,
      builder: (context, progress, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
          decoration: BoxDecoration(
            color: Daylight.cobaltWash,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Daylight.cobalt.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    FluentIcons.arrow_download_24_regular,
                    size: 16,
                    color: Daylight.cobalt,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Daylight.ui(12, weight: FontWeight.w600),
                        ),
                        Text(
                          '${(progress.progress * 100).round()}% · '
                          '${progress.completed}/${progress.total}',
                          style: Daylight.ui(10, color: Daylight.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await offlinePlaylistService.cancelDownload(
                        context,
                        playlistId,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Daylight.cobalt,
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      context.l10n!.cancel,
                      style: Daylight.ui(
                        10.5,
                        color: Daylight.cobalt,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              DaylightProgressBar(value: progress.progress, height: 5),
            ],
          ),
        );
      },
    );
  }
}

class _DownloadItem extends StatelessWidget {
  const _DownloadItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.bytes,
    required this.onTap,
    required this.onRemove,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final int bytes;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: DaylightCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Row(
          children: [
            DaylightCover(size: 42, imageUrl: imageUrl),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Daylight.ui(12.5, weight: FontWeight.w600),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Daylight.ui(10, color: Daylight.muted),
                    ),
                ],
              ),
            ),
            Text(
              _formatBytes(bytes),
              style: Daylight.ui(9.5, color: Daylight.faint),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(
                FluentIcons.dismiss_16_regular,
                size: 15,
                color: Daylight.muted,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.song, required this.onRemove});

  final Map song;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final title = song['title']?.toString() ?? '';
    final artist = song['artist']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DaylightCard(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Row(
          children: [
            DaylightCover(
              size: 40,
              imageUrl: song['image']?.toString(),
              localPath: song['artworkPath']?.toString(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Daylight.ui(12.5, weight: FontWeight.w600),
                  ),
                  if (artist.isNotEmpty)
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Daylight.ui(10, color: Daylight.muted),
                    ),
                ],
              ),
            ),
            DaylightBadge(
              label: context.l10n!.downloaded,
              icon: FluentIcons.checkmark_16_filled,
              background: Daylight.cardTint,
              color: Daylight.muted,
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(
                FluentIcons.dismiss_16_regular,
                size: 15,
                color: Daylight.muted,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  final megabytes = bytes / (1024 * 1024);
  if (megabytes >= 1024) return '${(megabytes / 1024).toStringAsFixed(1)} GB';
  return '${megabytes.toStringAsFixed(megabytes >= 10 ? 0 : 1)} MB';
}
