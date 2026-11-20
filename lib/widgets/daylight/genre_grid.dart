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
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/screens/search_page.dart' show genreSearchRequest;
import 'package:musify/widgets/daylight/browse_tile.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';

/// A genre card opens Search with a real query, so every card leads to actual
/// Musify songs instead of a dead category page. The label and the query are
/// deliberately the same plain words people search for on YouTube.
class _Genre {
  const _Genre(this.label, this.query, this.color, this.icon);

  final String label;
  final String query;
  final Color color;
  final IconData icon;
}

const _genres = <_Genre>[
  _Genre(
    'Pop',
    'pop songs',
    BrowseColors.rose,
    FluentIcons.music_note_2_24_filled,
  ),
  _Genre(
    'OPM',
    'OPM songs',
    BrowseColors.sun,
    FluentIcons.music_note_2_24_filled,
  ),
  _Genre(
    'Rock',
    'rock songs',
    BrowseColors.ember,
    FluentIcons.music_note_2_24_filled,
  ),
  _Genre(
    'Hip-Hop',
    'hip hop songs',
    BrowseColors.violet,
    FluentIcons.music_note_2_24_filled,
  ),
  _Genre(
    'R&B',
    'R and B songs',
    BrowseColors.indigo,
    FluentIcons.heart_24_filled,
  ),
  _Genre(
    'Jazz',
    'jazz songs',
    BrowseColors.teal,
    FluentIcons.music_note_2_24_filled,
  ),
  _Genre(
    'Electronic',
    'electronic songs',
    BrowseColors.cobalt,
    FluentIcons.sparkle_24_filled,
  ),
  _Genre(
    'K-Pop',
    'kpop songs',
    BrowseColors.sky,
    FluentIcons.music_note_2_24_filled,
  ),
];

/// A Spotify-style "Browse all" grid of genre cards. Tapping a card fills the
/// Search field with that genre's query and navigates to the Search tab, which
/// resolves real songs through the normal search pipeline.
class GenreGrid extends StatelessWidget {
  const GenreGrid({super.key, this.title, this.actionLabel, this.onAction});

  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  void _open(String query, BuildContext context) {
    genreSearchRequest.value = query;
    context.go('/search');
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <BrowseTileData>[
      for (final genre in _genres)
        BrowseTileData(
          title: genre.label,
          color: genre.color,
          icon: genre.icon,
          onTap: () => _open(genre.query, context),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          DaylightSectionHeader(
            title: title!,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        if (title != null) const SizedBox(height: 4),
        BrowseTileGrid(tiles: tiles),
      ],
    );
  }
}
