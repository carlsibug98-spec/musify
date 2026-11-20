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
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/theme/daylight.dart';

/// Likes a playlist, an album or an artist, and follows the liked playlists so
/// that the same one stays in sync wherever it is shown.
class PlaylistLikeButton extends StatefulWidget {
  const PlaylistLikeButton({
    super.key,
    required this.playlistId,
    required this.playlistData,
    this.asPill = false,
  });

  final String playlistId;

  /// What to store when the playlist is liked, read on the tap so that a page
  /// still loading its songs stores them once they are there.
  final Map? Function() playlistData;

  /// Renders the action as a "Like" pill, as on the artist header, instead of
  /// the compact circular button shared with album and playlist pages.
  final bool asPill;

  @override
  State<PlaylistLikeButton> createState() => _PlaylistLikeButtonState();
}

class _PlaylistLikeButtonState extends State<PlaylistLikeButton> {
  late final ValueNotifier<bool> _isLiked = ValueNotifier<bool>(
    isPlaylistAlreadyLiked(widget.playlistId),
  );

  @override
  void initState() {
    super.initState();
    userLikedPlaylists.addListener(_syncLikeStatus);
  }

  @override
  void didUpdateWidget(covariant PlaylistLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The page can resolve its real id after the first build.
    if (oldWidget.playlistId != widget.playlistId) _syncLikeStatus();
  }

  @override
  void dispose() {
    userLikedPlaylists.removeListener(_syncLikeStatus);
    _isLiked.dispose();
    super.dispose();
  }

  void _syncLikeStatus() {
    _isLiked.value = isPlaylistAlreadyLiked(widget.playlistId);
  }

  void _toggleLikeStatus() {
    _isLiked.value = !_isLiked.value;
    unawaited(
      updatePlaylistLikeStatus(
        widget.playlistId,
        _isLiked.value,
        playlistData: widget.playlistData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playlistId.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: _isLiked,
      builder: (context, isLiked, __) {
        final tooltip = isLiked
            ? context.l10n!.removeFromLikedPlaylists
            : context.l10n!.addToLikedPlaylists;

        if (widget.asPill) {
          return Tooltip(
            message: tooltip,
            child: GestureDetector(
              onTap: _toggleLikeStatus,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isLiked ? Daylight.cobalt : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: isLiked
                      ? null
                      : Border.all(color: Daylight.lineStrong),
                  boxShadow: isLiked ? Daylight.cobaltShadow : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLiked
                          ? FluentIcons.heart_24_filled
                          : FluentIcons.heart_24_regular,
                      size: 17,
                      color: isLiked ? Daylight.onAccent : Daylight.ink,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      isLiked ? context.l10n!.liked : context.l10n!.like,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Daylight.ui(
                        12,
                        color: isLiked ? Daylight.onAccent : Daylight.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return IconButton(
          icon: Icon(
            isLiked
                ? FluentIcons.heart_24_filled
                : FluentIcons.heart_24_regular,
            size: 18,
            color: isLiked ? Colors.white : Daylight.cobalt,
          ),
          style: IconButton.styleFrom(
            fixedSize: const Size(42, 42),
            backgroundColor: isLiked ? Daylight.cobalt : Colors.white,
            shape: const CircleBorder(),
            side: isLiked
                ? BorderSide.none
                : BorderSide(color: Daylight.lineStrong),
            elevation: 0,
          ),
          onPressed: _toggleLikeStatus,
          tooltip: tooltip,
        );
      },
    );
  }
}
