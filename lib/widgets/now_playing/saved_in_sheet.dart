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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/utilities/playlist_dialogs.dart';

/// Spotify-style "Saved in" sheet. It lists every place the current song can
/// be saved (Liked Songs plus each playlist) and toggles the song in place.
class SavedInSheet extends StatelessWidget {
  const SavedInSheet({
    super.key,
    required this.metadata,
    this.showLikedSongs = true,
  });

  final MediaItem metadata;
  final bool showLikedSongs;

  static Future<void> show(
    BuildContext context,
    MediaItem metadata, {
    bool showLikedSongs = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SavedInSheet(metadata: metadata, showLikedSongs: showLikedSongs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;
    final song = mediaItemToMap(metadata);
    final songId = song['ytid']?.toString() ?? '';

    return ValueListenableBuilder<List>(
      valueListenable: userLikedSongsList,
      builder: (context, likedSongs, _) {
        return ValueListenableBuilder<List<Map>>(
          valueListenable: userCustomPlaylists,
          builder: (context, playlists, _) {
            final isLiked = likedSongs.any(
              (item) => item['ytid']?.toString() == songId,
            );

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: Material(
                color: Daylight.card,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Daylight.lineStrong,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.savedIn,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              metadata.title,
                              style: TextStyle(
                                color: Daylight.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [
                            if (showLikedSongs)
                              _SavedRow(
                                icon: FluentIcons.heart_24_regular,
                                color: const Color(0xFF7C4DFF),
                                title: l10n.likedSongs,
                                subtitle:
                                    '${likedSongs.length} ${l10n.songs.toLowerCase()}',
                                saved: isLiked,
                                onTap: () {
                                  unawaited(
                                    updateSongLikeStatus(
                                      songId,
                                      !isLiked,
                                      songData: song,
                                    ),
                                  );
                                },
                              ),
                            for (final playlist in playlists)
                              _playlistRow(context, playlist, song),
                            const Divider(height: 1),
                            _SavedRow(
                              icon: FluentIcons.folder_24_regular,
                              color: Daylight.accent,
                              title: l10n.newPlaylist,
                              saved: false,
                              onTap: () {
                                Navigator.pop(context);
                                showCreatePlaylistDialog(
                                  context,
                                  songToAdd: song,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// One row per custom playlist. A tap adds the song when it is missing and
  /// removes it when it is already there, so no secondary dialog is needed.
  Widget _playlistRow(BuildContext context, Map playlist, Map song) {
    final l10n = context.l10n!;
    final songs = playlist['list'] as List? ?? const [];
    final saved = songs.any(
      (item) => item['ytid']?.toString() == song['ytid']?.toString(),
    );

    return _SavedRow(
      icon: FluentIcons.music_note_1_24_regular,
      color: Daylight.accent,
      title: playlist['title']?.toString() ?? l10n.playlist,
      subtitle: '${songs.length} ${l10n.songs.toLowerCase()}',
      saved: saved,
      onTap: () {
        if (saved) {
          removeSongFromPlaylist(Map.from(playlist), song);
          showToast(context, l10n.songRemoved);
        } else {
          final message = addSongInCustomPlaylist(
            context,
            playlist['ytid']?.toString() ?? '',
            song,
          );
          showToast(context, message);
        }
      },
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.saved,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: color.withValues(alpha: 0.85),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: Daylight.muted, fontSize: 11),
            ),
      trailing: Icon(
        saved ? FluentIcons.checkmark_24_filled : FluentIcons.add_24_regular,
        color: saved ? Daylight.accent : Daylight.muted,
        size: 19,
      ),
    );
  }
}
