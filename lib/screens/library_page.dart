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
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart' show logger;
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/offline_playlist_dialogs.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_bar.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          pinnedPlaylistIds,
          offlineMode,
          userCustomPlaylists,
          userPlaylistFolders,
          offlinePlaylistService.offlinePlaylists,
          userLikedPlaylists,
          onlinePlaylists,
          userPlaylists,
          userOfflineSongs,
          userLikedSongsList,
        ]),
        builder: (context, _) {
          final isOffline = offlineMode.value;
          final hasAnyContent = _hasAnyContent(isOffline);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(
                child: _LibraryTabs(
                  index: _tab,
                  onChanged: (index) => setState(() => _tab = index),
                ),
              ),
              if (isOffline)
                SliverToBoxAdapter(child: _buildOfflineBanner(context)),
              if (!hasAnyContent)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: DaylightEmptyState(
                      title: isOffline
                          ? context.l10n!.youAreOffline
                          : context.l10n!.libraryQuiet,
                      message: isOffline
                          ? context.l10n!.noOfflineLibraryContent
                          : context.l10n!.libraryQuietNote,
                      icon: FluentIcons.library_24_regular,
                      actions: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            DaylightPill(
                              label: context.l10n!.importFiles,
                              icon: FluentIcons.arrow_download_24_regular,
                              onTap: () => context.push(
                                '/settings/import-spotify-playlist',
                              ),
                            ),
                            if (!isOffline)
                              DaylightPill(
                                label: context.l10n!.pastePlaylistLink,
                                icon: FluentIcons.link_24_regular,
                                onTap: () => showCreatePlaylistDialog(context),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._buildTabSlivers(context),
              const SliverMiniPlayerBottomSpace(),
            ],
          );
        },
      ),
    );
  }

  bool _hasAnyContent(bool isOffline) {
    if (pinnedPlaylistIds.value.isNotEmpty) return true;
    if (userPlaylistFolders.value.isNotEmpty) return true;
    if (userCustomPlaylists.value.isNotEmpty) return true;
    if (userPlaylists.value.isNotEmpty) return true;
    if (userLikedPlaylists.value.isNotEmpty) return true;
    if (getLikedArtistItems(offlineOnly: isOffline).isNotEmpty) return true;
    if (userOfflineSongs.value.isNotEmpty) return true;
    if (userLikedSongsList.value.isNotEmpty) return true;
    if (offlinePlaylistService.offlinePlaylists.value.any(
      (p) => p is Map && !PlaylistUtils.isArtistPlaylist(p),
    )) {
      return true;
    }
    return false;
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: DaylightCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Daylight.cobaltSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                FluentIcons.cloud_off_24_filled,
                size: 17,
                color: Daylight.cobalt,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n!.youAreOffline,
                    style: Daylight.ui(
                      12,
                      color: Daylight.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n!.cataloguePaused,
                    style: Daylight.ui(10, color: Daylight.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _retryOnline,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  context.l10n!.retry,
                  style: Daylight.ui(
                    11,
                    color: Daylight.cobalt,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _retryOnline() {
    addOrUpdateData<bool>('settings', 'offlineMode', false);
    offlineMode.value = false;
    NavigationManager.refreshRouter();
  }

  Widget _buildHeader(BuildContext context) {
    return DaylightAppBar(
      title: context.l10n!.library,
      actions: [
        DaylightPill(
          label: context.l10n!.importLabel,
          icon: FluentIcons.arrow_download_24_regular,
          onTap: () => context.push('/settings/import-spotify-playlist'),
        ),
        const SizedBox(width: 8),
        DaylightCircleButton(
          icon: FluentIcons.add_24_regular,
          tooltip: context.l10n!.addPlaylist,
          onTap: () => showCreatePlaylistDialog(context),
        ),
      ],
    );
  }

  List<Widget> _buildTabSlivers(BuildContext context) {
    switch (_tab) {
      case 1:
        return _buildAlbumsSlivers(context);
      case 2:
        return _buildDownloadsSlivers(context);
      default:
        return _buildPlaylistsSlivers(context);
    }
  }

  List<Widget> _buildPlaylistsSlivers(BuildContext context) {
    final isOffline = offlineMode.value;
    final folders = isOffline
        ? userPlaylistFolders.value
              .where(PlaylistUtils.folderHasOfflinePlaylists)
              .toList()
        : userPlaylistFolders.value;
    final rawOfflinePlaylists = offlinePlaylistService.offlinePlaylists.value
        .where((p) => p is Map && !PlaylistUtils.isArtistPlaylist(p))
        .cast<Map>()
        .toList();
    final offlineNotInFolders =
        PlaylistUtils.filterOfflinePlaylistsNotInFolders(
          rawOfflinePlaylists,
          folders,
        );
    final offlineIds = PlaylistUtils.offlinePlaylistIdsNotInFolders(
      rawOfflinePlaylists,
      folders,
    );
    final playlistsNotInFolders = PlaylistUtils.excludePlaylistsWithIds(
      getPlaylistsNotInFolders(),
      offlineIds,
    );
    final likedPlaylists = isOffline ? <Map>[] : getLikedPlaylistItems();
    final likedArtists = getLikedArtistItems(offlineOnly: isOffline);

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList.list(
          children: [
            _LikedSongsCard(
              songs: userLikedSongsList.value,
              onTap: () =>
                  NavigationManager.router.go('/library/userSongs/liked'),
            ),
            const SizedBox(height: 16),
            if (pinnedPlaylistIds.value.isNotEmpty) ...[
              DaylightSectionHeader(
                title: context.l10n!.pinnedPlaylists,
                trailing: Icon(
                  FluentIcons.pin_16_filled,
                  size: 14,
                  color: Daylight.cobalt,
                ),
              ),
              for (final playlist
                  in resolvePinnedPlaylists(pinnedPlaylistIds.value).where(
                    (p) =>
                        !isOffline ||
                        offlinePlaylistService.isPlaylistDownloaded(
                          p['ytid']?.toString() ?? '',
                        ),
                  ))
                _playlistRow(context, playlist),
              const SizedBox(height: 12),
            ],
            DaylightSectionHeader(
              title: context.l10n!.playlists,
              actionLabel: isOffline ? null : context.l10n!.addPlaylist,
              onAction: isOffline
                  ? null
                  : () => showCreatePlaylistDialog(context),
            ),
            for (final folder in folders)
              PlaylistBar(
                folder['name'],
                playlistData: folder,
                onDelete: () => _showDeleteFolderDialog(folder),
              ),
            for (final playlist in playlistsNotInFolders)
              _playlistRow(
                context,
                playlist,
                onDelete:
                    playlist['source'] == 'user-created' ||
                        playlist['source'] == 'user-youtube'
                    ? () => _showRemovePlaylistDialog(playlist)
                    : null,
              ),
            if (folders.isNotEmpty || playlistsNotInFolders.isNotEmpty)
              const SizedBox(height: 12),
            if (!isOffline)
              AsyncLoader<List<dynamic>>(
                future: getUserPlaylistsNotInFolders(),
                emptyWidget: const SizedBox.shrink(),
                builder: (context, playlists) {
                  if (playlists.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DaylightSectionHeader(
                        title: context.l10n!.addedPlaylists,
                        actionLabel: context.l10n!.seeAll,
                        onAction: () => context.go('/library'),
                      ),
                      for (final playlist in playlists.take(3))
                        _playlistRow(
                          context,
                          playlist,
                          onDelete: () => _showRemovePlaylistDialog(playlist),
                        ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            if (rawOfflinePlaylists.isNotEmpty) ...[
              DaylightSectionHeader(
                title: context.l10n!.downloaded,
                actionLabel: context.l10n!.manage,
                onAction: () => context.push('/library/downloads'),
              ),
              for (final playlist in offlineNotInFolders.take(3))
                _playlistRow(
                  context,
                  playlist,
                  isOfflinePlaylist: true,
                  onDelete: () => _showRemoveOfflinePlaylistDialog(playlist),
                ),
              if (offlineNotInFolders.isEmpty && folders.isNotEmpty)
                for (final folder in folders.take(2))
                  PlaylistBar(folder['name'], playlistData: folder),
              const SizedBox(height: 12),
            ],
            if (likedPlaylists.isNotEmpty) ...[
              DaylightSectionHeader(title: context.l10n!.likedPlaylists),
              for (final playlist in likedPlaylists)
                _playlistRow(context, playlist),
              const SizedBox(height: 12),
            ],
            if (likedArtists.isNotEmpty) ...[
              DaylightSectionHeader(title: context.l10n!.artist),
              for (final artist in likedArtists)
                _playlistRow(context, artist, isArtist: true),
              const SizedBox(height: 12),
            ],
            if (!isOffline)
              _ImportNote(
                onTap: () => context.push('/settings/import-spotify-playlist'),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildAlbumsSlivers(BuildContext context) {
    final likedAlbums = getLikedPlaylistItems()
        .where((playlist) => playlist['isAlbum'] == true)
        .cast<Map>()
        .toList();
    final offlineAlbums = offlinePlaylistService.offlinePlaylists.value
        .where((p) => p is Map && p['isAlbum'] == true)
        .cast<Map>()
        .toList();
    final seen = <String>{};
    final albums = <Map>[];
    for (final album in [...likedAlbums, ...offlineAlbums]) {
      final id = album['ytid']?.toString() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      albums.add(album);
    }

    if (albums.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: DaylightEmptyState(
              title: context.l10n!.albums,
              message: context.l10n!.libraryQuietNote,
              icon: FluentIcons.cd_16_regular,
              actions: [
                DaylightPill(
                  label: context.l10n!.addPlaylist,
                  icon: FluentIcons.add_24_regular,
                  onTap: () => showCreatePlaylistDialog(context),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList.list(
          children: [
            DaylightSectionHeader(title: context.l10n!.albums),
            for (final album in albums)
              _playlistRow(
                context,
                album,
                onDelete: album['source'] == 'user-created'
                    ? () => _showRemovePlaylistDialog(album)
                    : null,
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildDownloadsSlivers(BuildContext context) {
    final offlineSongs = userOfflineSongs.value;
    final downloadedPlaylists = offlinePlaylistService.offlinePlaylists.value
        .where((p) => p is Map && !PlaylistUtils.isArtistPlaylist(p))
        .cast<Map>()
        .toList();
    final downloadedArtists = offlinePlaylistService.offlinePlaylists.value
        .where((p) => p is Map && PlaylistUtils.isArtistPlaylist(p))
        .cast<Map>()
        .toList();

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList.list(
          children: [
            _LikedSongsCard(
              songs: offlineSongs,
              title: context.l10n!.offlineSongs,
              icon: FluentIcons.cloud_off_24_regular,
              onTap: () =>
                  NavigationManager.router.go('/library/userSongs/offline'),
            ),
            const SizedBox(height: 16),
            DaylightSectionHeader(
              title: context.l10n!.onThisPhone,
              actionLabel: context.l10n!.manage,
              onAction: () => context.push('/library/downloads'),
            ),
            if (downloadedPlaylists.isEmpty && downloadedArtists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  context.l10n!.libraryQuietNote,
                  style: Daylight.ui(12, color: Daylight.muted),
                ),
              ),
            for (final playlist in downloadedPlaylists)
              _playlistRow(
                context,
                playlist,
                isOfflinePlaylist: true,
                onDelete: () => _showRemoveOfflinePlaylistDialog(playlist),
              ),
            for (final artist in downloadedArtists)
              _playlistRow(
                context,
                artist,
                isArtist: true,
                isOfflinePlaylist: true,
                onDelete: () => _showRemoveOfflinePlaylistDialog(artist),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ];
  }

  Widget _playlistRow(
    BuildContext context,
    Map playlist, {
    bool isArtist = false,
    bool isOfflinePlaylist = false,
    VoidCallback? onDelete,
  }) {
    final source = playlist['source']?.toString();
    return PlaylistBar(
      playlist['title']?.toString() ?? '',
      playlistId: playlist['ytid']?.toString(),
      playlistArtwork: playlist['image']?.toString(),
      cubeIcon: isArtist
          ? FluentIcons.person_24_filled
          : FluentIcons.text_bullet_list_24_filled,
      isAlbum: playlist['isAlbum'],
      playlistData:
          isArtist ||
              source == 'user-created' ||
              source == 'user-youtube' ||
              isOfflinePlaylist
          ? playlist
          : null,
      onDelete: onDelete,
    );
  }

  void _showRemoveOfflinePlaylistDialog(Map playlist) {
    final playlistId = playlist['ytid']?.toString() ?? '';
    if (playlistId.isEmpty) return;
    showRemoveOfflinePlaylistDialog(context, playlistId);
  }

  void _showRemovePlaylistDialog(Map playlist) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        confirmationMessage: context.l10n!.removePlaylistQuestion,
        submitMessage: context.l10n!.remove,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSubmit: () {
          Navigator.of(context).pop();

          final playlistId = playlist['ytid']?.toString() ?? '';

          if (playlistId.isEmpty) {
            logger.log('Playlist ID is missing, cannot remove playlist.');
            showToast(context, context.l10n!.error);
            return;
          }

          removeUserPlaylistEntry(playlist);
          if (offlinePlaylistService.isPlaylistDownloaded(playlistId)) {
            unawaited(offlinePlaylistService.removeOfflinePlaylist(playlistId));
          }
        },
      );
    },
  );

  void _showDeleteFolderDialog(Map folder) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        confirmationMessage: context.l10n!.deleteFolderQuestion,
        submitMessage: context.l10n!.delete,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSubmit: () {
          final result = deletePlaylistFolder(folder['id'], context);
          Navigator.of(context).pop();
          showToast(context, result);
        },
      );
    },
  );
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n!.playlists,
      context.l10n!.albums,
      context.l10n!.downloads,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 18),
                GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          labels[i],
                          style: Daylight.ui(
                            12.5,
                            color: i == index ? Daylight.ink : Daylight.muted,
                            weight: i == index
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          height: 2,
                          width: i == index ? 22 : 0,
                          decoration: BoxDecoration(
                            color: Daylight.cobalt,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          Divider(color: Daylight.line, height: 1),
        ],
      ),
    );
  }
}

class _LikedSongsCard extends StatelessWidget {
  const _LikedSongsCard({
    required this.songs,
    required this.onTap,
    this.title,
    this.icon = FluentIcons.heart_24_filled,
  });

  final List<dynamic> songs;
  final VoidCallback onTap;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final minutes = _totalMinutes(songs);
    final count = songs.length;
    final meta = [
      '$count ${context.l10n!.tracks}',
      if (minutes > 0) _formatMinutes(minutes),
    ].join(' · ');

    return DaylightCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Daylight.cobaltSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Daylight.cobalt),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title ?? context.l10n!.likedSongs,
                  style: Daylight.ui(13.5, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(meta, style: Daylight.ui(10, color: Daylight.muted)),
              ],
            ),
          ),
          Icon(
            FluentIcons.chevron_right_20_regular,
            size: 18,
            color: Daylight.muted,
          ),
        ],
      ),
    );
  }

  int _totalMinutes(List<dynamic> songs) {
    var seconds = 0;
    for (final song in songs) {
      if (song is! Map) continue;
      final duration = song['duration'];
      if (duration is num) seconds += duration.toInt();
    }
    return seconds ~/ 60;
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours > 0
        ? '${hours}h ${rest.toString().padLeft(2, '0')}m'
        : '${rest}m';
  }
}

class _ImportNote extends StatelessWidget {
  const _ImportNote({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DaylightCard(
      onTap: onTap,
      color: Daylight.cobaltWash,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n!.importLabel,
                  style: Daylight.ui(
                    12.5,
                    color: Daylight.cobaltDeep,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n!.youtubePlaylistLinkOrId,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Daylight.ui(10, color: Daylight.muted),
                ),
              ],
            ),
          ),
          Icon(
            FluentIcons.arrow_right_20_regular,
            size: 18,
            color: Daylight.cobalt,
          ),
        ],
      ),
    );
  }
}
