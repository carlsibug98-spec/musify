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
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/artwork_provider.dart';

/// Spotify-style browse card: saturated tile, label top-left, a tilted piece of
/// artwork bleeding out of the bottom-right corner. Used by Home and Search.
class BrowseTileData {
  const BrowseTileData({
    required this.title,
    required this.color,
    required this.onTap,
    this.imageUrl,
    this.icon = FluentIcons.music_note_2_24_filled,
  });

  final String title;
  final Color color;
  final VoidCallback onTap;
  final String? imageUrl;
  final IconData icon;
}

/// A small palette that stays in the Daylight family but adds the colour the
/// browsing grids need to feel alive.
abstract final class BrowseColors {
  static const cobalt = Color(0xFF2743E8);
  static const indigo = Color(0xFF5B3FD8);
  static const violet = Color(0xFF8A3FA8);
  static const rose = Color(0xFFC2376E);
  static const ember = Color(0xFFD9612B);
  static const sun = Color(0xFFC99016);
  static const pine = Color(0xFF1F7F64);
  static const teal = Color(0xFF1C8C9B);
  static const sky = Color(0xFF2B6FC7);
  static const slate = Color(0xFF4A5570);

  static const palette = [
    cobalt,
    indigo,
    violet,
    rose,
    ember,
    sun,
    pine,
    teal,
    sky,
    slate,
  ];

  static Color forIndex(int index) => palette[index % palette.length];
}

class BrowseTileGrid extends StatelessWidget {
  const BrowseTileGrid({
    super.key,
    required this.tiles,
    this.crossAxisCount = 2,
    this.height = 92,
  });

  final List<BrowseTileData> tiles;
  final int crossAxisCount;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * 10) /
            crossAxisCount;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: itemWidth / height,
          children: [
            for (final tile in tiles)
              _BrowseTile(data: tile, height: height),
          ],
        );
      },
    );
  }
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({required this.data, required this.height});

  final BrowseTileData data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(data.color, Colors.black, 0.28) ?? data.color;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data.onTap,
          splashColor: Colors.white.withValues(alpha: 0.12),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [data.color, dark],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  top: 11,
                  right: 38,
                  child: Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      shadows: [
                        Shadow(
                          color: Color(0x33000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: -16,
                  bottom: -14,
                  child: Transform.rotate(
                    angle: 0.38,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(-2, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _Artwork(data: data),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.data});

  final BrowseTileData data;

  @override
  Widget build(BuildContext context) {
    final url = data.imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image(
        image: ArtworkProvider.get(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: Daylight.softCobaltGradient,
      ),
      child: Center(
        child: Icon(data.icon, size: 30, color: Daylight.cobalt),
      ),
    );
  }
}
