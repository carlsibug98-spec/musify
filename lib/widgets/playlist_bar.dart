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
import 'package:musify/services/artist_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/offline_playlist_dialogs.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:musify/widgets/dialog_item.dart';
import 'package:musify/widgets/edit_playlist_dialog.dart';
import 'package:musify/widgets/overflow_menu_button.dart';
import 'package:musify/widgets/popup_menu_item.dart';
import 'package:musify/widgets/spinner.dart';

class PlaylistBar extends StatelessWidget {
  PlaylistBar(
    this.playlistTitle, {
    super.key,
    this.playlistId,
    this.playlistArtwork,
    this.playlistData,
    this.onPressed,
    this.onDelete,
    this.cubeIcon = FluentIcons.text_bullet_list_24_filled,
    this.showBuildActions = true,
    this.isAlbum = false,
    this.borderRadius = BorderRadius.zero,
  });

  final Map? playlistData;
  final String? playlistId;
  final String playlistTitle;
  final String? playlistArtwork;
  final VoidCallback? onPressed;
  final VoidCallback? onDelete;
  final IconData cubeIcon;
  final bool? isAlbum;
  final bool showBuildActions;
  final BorderRadius borderRadius;

  static const double artworkSize = 60;
  static const double iconSize = 27;

  static const likeStatusToIconMapper = {
    true: FluentIcons.heart_off_24_regular,
    false: FluentIcons.heart_24_regular,
  };

  // Helper to determine if this is a folder
  bool get isFolder =>
      playlistData != null && PlaylistUtils.isFolder(playlistData!);

  bool get isArtist {
    final data = playlistData;
    return data != null && isArtistPlaylist(data);
  }

  String? get _resolvedPlaylistId =>
      playlistId ?? playlistData?['ytid']?.toString();

  bool get _canAddToPlaylist => !isFolder && _resolvedPlaylistId != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayTitle = isArtist
        ? normalizeArtistDisplayTitle(playlistTitle)
        : playlistTitle;
    Map<dynamic, dynamic>? updatedPlaylist;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Daylight.card,
          borderRadius: BorderRadius.circular(14),
          border: Daylight.hairline,
          boxShadow: [
            BoxShadow(
              color: Daylight.ink.withValues(alpha: 0.05),
              blurRadius: 9,
              offset: const Offset(0, 3),
              spreadRadius: -5,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed ?? _getDefaultOnPressed(context, updatedPlaylist),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Row(
                children: [
                  if (isFolder)
                    _buildFolderIcon(colorScheme)
                  else
                    _buildPlaylistIcon(colorScheme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (!isFolder && _resolvedPlaylistId != null)
                              ValueListenableBuilder<List<String>>(
                                valueListenable: pinnedPlaylistIds,
                                builder: (_, ids, __) {
                                  if (!ids.contains(_resolvedPlaylistId)) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      FluentIcons.pin_24_filled,
                                      size: 13,
                                      color: colorScheme.primary,
                                    ),
                                  );
                                },
                              ),
                            Expanded(
                              child: Text(
                                displayTitle,
                                style: Daylight.ui(
                                  13.5,
                                  weight: FontWeight.w600,
                                  height: 1.25,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (isFolder) ...[
                          const SizedBox(height: 2),
                          _buildFolderSubtitle(context) ?? const SizedBox.shrink(),
                        ] else if (playlistArtwork != null &&
                            playlistArtwork!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            isAlbum == true
                                ? context.l10n!.album
                                : context.l10n!.playlist,
                            style: Daylight.ui(10, color: Daylight.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showBuildActions) ...[
                    const SizedBox(width: 4),
                    OverflowMenuButton<String>(
                      onSelected: (String value) {
                        switch (value) {
                          case 'like':
                            if (_resolvedPlaylistId != null) {
                              final isLiked = isPlaylistAlreadyLiked(
                                _resolvedPlaylistId,
                              );
                              unawaited(
                                updatePlaylistLikeStatus(
                                  _resolvedPlaylistId!,
                                  !isLiked,
                                  playlistData: playlistData,
                                ),
                              );
                            }
                            break;
                          case 'pin':
                            if (_resolvedPlaylistId != null) {
                              final pinned = togglePinnedPlaylist(
                                _resolvedPlaylistId!,
                                context,
                              );
                              if (!pinned &&
                                  !isPlaylistPinned(_resolvedPlaylistId!) &&
                                  pinnedPlaylistIds.value.length >=
                                      pinnedPlaylistsLimit) {
                                showToast(
                                  context,
                                  context.l10n!.pinnedPlaylistsLimit,
                                );
                              }
                            }
                            break;
                          case 'delete':
                            if (onDelete != null) onDelete!();
                            break;
                          case 'moveToFolder':
                            _showMoveToFolderDialog(context);
                            break;
                          case 'edit':
                            if (isFolder) {
                              _handleEditFolder(context);
                            } else {
                              _handleEdit(context);
                            }
                            break;
                          case 'add_to_playlist':
                            _handleAddPlaylistToPlaylist(context);
                            break;
                          case 'remove_offline':
                            if (playlistData != null &&
                                playlistData!['ytid'] != null) {
                              showRemoveOfflinePlaylistDialog(
                                context,
                                playlistData!['ytid'].toString(),
                              );
                            }
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        final isUserCreated =
                            playlistData?['source'] == 'user-created';
                        final pinnedIds = pinnedPlaylistIds.value;

                        final isPinned =
                            _resolvedPlaylistId != null &&
                            pinnedIds.contains(_resolvedPlaylistId);

                        final isLiked =
                            _resolvedPlaylistId != null &&
                            isPlaylistAlreadyLiked(_resolvedPlaylistId);

                        final isOffline =
                            playlistData != null &&
                            (playlistData!['downloadedAt'] != null ||
                                playlistData!['isOffline'] == true);

                        return [
                          if (!isFolder && _resolvedPlaylistId != null)
                            buildPopupMenuItem<String>(
                              value: 'pin',
                              icon: isPinned
                                  ? FluentIcons.pin_off_24_regular
                                  : FluentIcons.pin_24_regular,
                              label: isPinned
                                  ? context.l10n!.unpinFromLibrary
                                  : context.l10n!.pinToLibrary,
                              colorScheme: colorScheme,
                            ),
                          if (!isFolder && (onDelete == null || !isUserCreated))
                            buildPopupMenuItem<String>(
                              value: 'like',
                              icon: likeStatusToIconMapper[isLiked]!,
                              label: isLiked
                                  ? context.l10n!.removeFromLikedPlaylists
                                  : context.l10n!.addToLikedPlaylists,
                              colorScheme: colorScheme,
                            ),
                          if (_canAddToPlaylist)
                            buildPopupMenuItem<String>(
                              value: 'add_to_playlist',
                              icon: FluentIcons.album_add_24_regular,
                              label: context.l10n!.addToPlaylist,
                              colorScheme: colorScheme,
                            ),
                          if (isOffline)
                            buildPopupMenuItem<String>(
                              value: 'remove_offline',
                              icon: FluentIcons.cloud_off_24_regular,
                              label: context.l10n!.removeOffline,
                              colorScheme: colorScheme,
                              iconColor: colorScheme.error,
                            ),
                          if (playlistData != null &&
                              !isFolder &&
                              (playlistData!['source'] == 'user-created' ||
                                  playlistData!['source'] == 'user-youtube'))
                            buildPopupMenuItem<String>(
                              value: 'moveToFolder',
                              icon: FluentIcons.folder_24_regular,
                              label: context.l10n!.moveToFolder,
                              colorScheme: colorScheme,
                            ),
                          if (playlistData != null &&
                              (isFolder ||
                                  playlistData!['source'] == 'user-created'))
                            buildPopupMenuItem<String>(
                              value: 'edit',
                              icon: FluentIcons.edit_24_regular,
                              label: isFolder
                                  ? context.l10n!.editFolder
                                  : context.l10n!.editPlaylist,
                              colorScheme: colorScheme,
                            ),
                          if (onDelete != null)
                            buildPopupMenuItem<String>(
                              value: 'delete',
                              icon: FluentIcons.delete_24_regular,
                              label: isFolder
                                  ? context.l10n!.deleteFolder
                                  : context.l10n!.deletePlaylist,
                              colorScheme: colorScheme,
                              iconColor: isFolder
                                  ? colorScheme.error
                                  : colorScheme.primary,
                              labelStyle: isFolder
                                  ? TextStyle(color: colorScheme.error)
                                  : null,
                            ),
                        ];
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistIcon(ColorScheme colorScheme) {
    final artwork = isArtist
        ? normalizeArtistThumbnailUrl(playlistArtwork)
        : playlistArtwork;
    if (artwork != null && artwork.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(isArtist ? 23 : 12),
        child: Image(
          image: ArtworkProvider.get(artwork),
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildIconFallback(colorScheme),
        ),
      );
    }
    return _buildIconFallback(colorScheme);
  }

  Widget _buildIconFallback(ColorScheme colorScheme) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Daylight.cobaltSoft,
        shape: isArtist ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isArtist ? null : BorderRadius.circular(12),
      ),
      child: Icon(cubeIcon, size: 21, color: Daylight.cobalt),
    );
  }

  void _showMoveToFolderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.folder_arrow_right_24_regular,
              color: colorScheme.secondary,
              size: 28,
            ),
          ),
          title: Text(
            context.l10n!.moveToFolder,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: ValueListenableBuilder<List>(
              valueListenable: userPlaylistFolders,
              builder: (context, folders, _) {
                // Find the current folder containing this playlist
                String? currentFolderId;
                if (playlistData != null) {
                  for (final folder in folders) {
                    final folderPlaylists = folder['playlists'] as List? ?? [];
                    if (folderPlaylists.any(
                      (p) => p['ytid'] == playlistData!['ytid'],
                    )) {
                      currentFolderId = folder['id'];
                      break;
                    }
                  }
                }

                // Filter folders to exclude current one
                final availableFolders = folders
                    .where((folder) => folder['id'] != currentFolderId)
                    .toList();

                final hasLibrary = currentFolderId != null;
                final hasItems = hasLibrary || availableFolders.isNotEmpty;

                if (!hasItems) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      context.l10n!.noFolders,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (hasLibrary)
                      DialogItem(
                        icon: FluentIcons.library_24_regular,
                        iconColor: colorScheme.primary,
                        iconBgColor: colorScheme.primaryContainer,
                        label: context.l10n!.library,
                        onTap: () {
                          Navigator.pop(context);
                          if (playlistData != null) {
                            movePlaylistToFolder(playlistData!, null, context);
                          }
                        },
                      ),
                    ...availableFolders.map(
                      (folder) => DialogItem(
                        icon: FluentIcons.folder_24_regular,
                        iconColor: colorScheme.secondary,
                        iconBgColor: colorScheme.secondaryContainer,
                        label: folder['name'] as String,
                        onTap: () {
                          Navigator.pop(context);
                          if (playlistData != null) {
                            movePlaylistToFolder(
                              playlistData!,
                              folder['id'],
                              context,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide(color: colorScheme.outline),
                ),
                child: Text(
                  context.l10n!.cancel,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper methods for folder display
  Widget _buildFolderIcon(ColorScheme colorScheme) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Daylight.cobaltSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        FluentIcons.folder_24_regular,
        size: 22,
        color: Daylight.cobalt,
      ),
    );
  }

  Widget? _buildFolderSubtitle(BuildContext context) {
    if (!isFolder || playlistData == null) return null;

    final playlistCount = (playlistData!['playlists'] as List?)?.length ?? 0;
    return Text(
      playlistCount == 1
          ? '1 ${context.l10n!.playlist.toLowerCase()}'
          : '$playlistCount ${context.l10n!.playlists.toLowerCase()}',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  VoidCallback? _getDefaultOnPressed(
    BuildContext context,
    Map<dynamic, dynamic>? updatedPlaylist,
  ) {
    if (isFolder && playlistData != null) {
      return () {
        context.push(
          '/home/folder/${playlistData!['id']}/${Uri.encodeComponent(playlistTitle)}',
        );
      };
    }

    return () {
      if (_resolvedPlaylistId == null ||
          _resolvedPlaylistId!.isEmpty ||
          _resolvedPlaylistId == 'null') {
        showToast(context, context.l10n!.error);
        return;
      }

      if (isArtist) {
        context.push(
          NavigationManager.artistPath(context, _resolvedPlaylistId!),
          extra: playlistData,
        );
        return;
      }

      context.push('/home/playlist/$_resolvedPlaylistId');
    };
  }

  Future<void> _handleAddPlaylistToPlaylist(BuildContext context) async {
    if (_resolvedPlaylistId == null) {
      showToast(context, context.l10n!.error);
      return;
    }

    final navContext = NavigationManager().context;
    unawaited(
      showDialog(
        context: navContext,
        barrierDismissible: false,
        builder: (_) => const Center(child: Spinner()),
      ),
    );

    try {
      final fullPlaylist = await getPlaylistInfoForWidget(
        _resolvedPlaylistId,
        isArtist: isArtist,
        artistName: isArtist ? playlistTitle : null,
        artistImage: isArtist ? playlistArtwork : null,
        preferredVerified:
            isArtist && playlistData?['isVerifiedArtist'] == true,
      );
      if (!navContext.mounted) return;
      Navigator.pop(navContext);

      if (fullPlaylist == null || fullPlaylist['list'] == null) {
        showToast(navContext, navContext.l10n!.error);
        return;
      }

      final tracks = fullPlaylist['list'] as List<dynamic>;
      if (tracks.isEmpty) {
        showToast(navContext, navContext.l10n!.noSongsInPlaylist);
        return;
      }

      unawaited(showAddToPlaylistDialog(navContext, songs: tracks));
    } catch (e) {
      if (navContext.mounted) {
        Navigator.pop(navContext);
        showToast(navContext, navContext.l10n!.error);
      }
    }
  }

  Future<void> _handleEdit(BuildContext context) async {
    if (playlistData == null) return;

    final result = await showDialog<Map?>(
      context: context,
      builder: (context) => EditPlaylistDialog(playlistData: playlistData!),
    );

    if (result != null) {
      final index = userCustomPlaylists.value.indexOf(playlistData!);
      if (index != -1) {
        final updatedPlaylists = List<Map>.from(userCustomPlaylists.value);
        updatedPlaylists[index] = result;
        userCustomPlaylists.value = updatedPlaylists;
        unawaited(
          addOrUpdateData<List<Map>>(
            'user',
            'customPlaylists',
            userCustomPlaylists.value,
          ),
        );

        // Update offline playlist if it exists
        unawaited(syncOfflinePlaylistMetadata(result));

        final appCtx = NavigationManager().context;
        showToast(appCtx, appCtx.l10n!.playlistUpdated);
      }
    }
  }

  void _handleEditFolder(BuildContext context) {
    if (playlistData == null) return;
    final folderId = playlistData!['id'];
    var folderName = playlistTitle;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          FluentIcons.folder_24_regular,
          color: colorScheme.primary,
          size: 32,
        ),
        title: Text(
          context.l10n!.editFolder,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextFormField(
          decoration: InputDecoration(
            labelText: context.l10n!.folderName,
            prefixIcon: Icon(
              FluentIcons.text_field_20_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
          ),
          initialValue: folderName,
          autofocus: true,
          onChanged: (value) => folderName = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.l10n!.cancel,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              final result = renamePlaylistFolder(
                folderId,
                folderName,
                context,
              );
              showToast(context, result);
            },
            icon: const Icon(FluentIcons.save_20_regular),
            label: Text(context.l10n!.update),
          ),
        ],
      ),
    );
  }
}
