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

import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/widgets/playlist_cube.dart';

/// The hero cover on an album / playlist / user-songs page.
///
/// Albums use a large softly-rounded square (Spotify-style); playlists and
/// system collections keep the Daylight circular cover.
class PlaylistHeroArtwork extends StatelessWidget {
  const PlaylistHeroArtwork(
    this.playlist, {
    super.key,
    this.cubeIcon = FluentIcons.text_bullet_list_24_filled,
    this.square = false,
  });

  final Map playlist;
  final IconData cubeIcon;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.sizeOf(context);
        final preferredSize = screenSize.width > screenSize.height
            ? 180.0
            : 148.0;
        final size = preferredSize
            .clamp(0.0, math.min(constraints.maxWidth, constraints.maxHeight))
            .toDouble();

        final radius = square ? 18.0 : size;
        final child = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: PlaylistCube(
            playlist,
            size: size,
            cubeIcon: cubeIcon,
            showTypeLabel: false,
            borderRadius: radius,
          ),
        );

        if (square) {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: Daylight.ink.withValues(alpha: 0.20),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: child,
          );
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Daylight.ink.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 12),
                spreadRadius: -10,
              ),
            ],
          ),
          child: ClipOval(child: child),
        );
      },
    );
  }
}
