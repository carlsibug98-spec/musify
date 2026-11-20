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
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/theme/daylight.dart';

class PlaylistIconAction {
  const PlaylistIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
}

/// Play and shuffle whatever the page is about, shared by the playlist and the
/// artist pages. In [albumStyle] mode it becomes a Spotify-like single row: a
/// small cover thumb, compact icon actions, and a large filled play button on
/// the right.
class PlaylistActionButtons extends StatelessWidget {
  const PlaylistActionButtons({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.isLoading = false,
    this.albumStyle = false,
    this.coverThumb,
    this.actions = const [],
  });

  final VoidCallback onPlay;
  final AsyncCallback onShuffle;
  final bool isLoading;

  /// Spotify-style single action row for albums.
  final bool albumStyle;

  /// Optional small cover thumbnail shown at the far left of the album row.
  final Widget? coverThumb;

  /// Extra compact icon actions (add, download, share, ...) for albums.
  final List<PlaylistIconAction> actions;

  @override
  Widget build(BuildContext context) {
    if (albumStyle) return _buildAlbumRow(context);

    final labelStyle = Daylight.ui(
      12,
      color: Daylight.onAccent,
      weight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Daylight.cobalt,
              foregroundColor: Daylight.onAccent,
              disabledBackgroundColor: Daylight.cobalt.withValues(alpha: 0.45),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              elevation: 0,
              textStyle: labelStyle,
            ),
            icon: isLoading
                ? const _Spinner(color: Colors.white)
                : const Icon(FluentIcons.play_24_filled, size: 14),
            label: Text(context.l10n!.play),
            onPressed: isLoading ? null : onPlay,
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Daylight.card,
              foregroundColor: Daylight.ink,
              disabledBackgroundColor: Daylight.card.withValues(alpha: 0.6),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              elevation: 0,
              side: BorderSide(color: Daylight.lineStrong),
              textStyle: Daylight.ui(
                12,
                color: Daylight.ink,
                weight: FontWeight.w600,
              ),
            ),
            icon: isLoading
                ? _Spinner(color: Daylight.cobalt)
                : const Icon(FluentIcons.arrow_shuffle_24_filled, size: 14),
            label: Text(context.l10n!.shuffle),
            onPressed: isLoading ? null : onShuffle,
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          if (coverThumb != null) ...[coverThumb!, const SizedBox(width: 12)],
          for (final action in actions) ...[
            _iconAction(action),
            const SizedBox(width: 2),
          ],
          const Spacer(),
          _circleAction(
            icon: FluentIcons.arrow_shuffle_24_filled,
            tooltip: context.l10n!.shuffle,
            onTap: isLoading ? null : () => onShuffle(),
            filled: false,
          ),
          const SizedBox(width: 12),
          _playButton(context),
        ],
      ),
    );
  }

  Widget _iconAction(PlaylistIconAction action) {
    return Tooltip(
      message: action.tooltip,
      child: IconButton(
        icon: Icon(
          action.icon,
          size: 22,
          color: action.active ? Daylight.cobalt : Daylight.muted,
        ),
        onPressed: action.onTap,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.all(6),
      ),
    );
  }

  Widget _circleAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required bool filled,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: filled ? Daylight.onAccent : Daylight.cobalt,
        ),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: const EdgeInsets.all(8),
        style: IconButton.styleFrom(
          backgroundColor: filled ? Daylight.cobalt : Daylight.cobaltSoft,
          shape: const CircleBorder(),
        ),
      ),
    );
  }

  Widget _playButton(BuildContext context) {
    return Tooltip(
      message: context.l10n!.play,
      child: Material(
        color: Daylight.cobalt,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isLoading ? null : onPlay,
          child: SizedBox(
            width: 56,
            height: 56,
            child: isLoading
                ? const _Spinner(color: Colors.white)
                : Icon(
                    FluentIcons.play_24_filled,
                    size: 26,
                    color: Daylight.onAccent,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Replaces the icon of a button while its songs are being read.
class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
