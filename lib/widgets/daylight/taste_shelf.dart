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
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/popup_menu_item.dart';

/// One interest-driven shelf. The header carries the section-level "hide this
/// section" action, and each card carries the item-level "not interested"
/// action — the same split Spotify uses between `DismissSection` and explicit
/// feedback URIs.
class TasteShelf extends StatelessWidget {
  const TasteShelf({
    required this.title,
    required this.songs,
    required this.onPlay,
    required this.onNotInterested,
    required this.onDismiss,
    super.key,
  });

  final String title;
  final List<Map> songs;
  final void Function(int index) onPlay;
  final ValueChanged<Map> onNotInterested;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DaylightSectionHeader(
          title: title,
          trailing: PopupMenuButton<String>(
            tooltip: l10n.moreOptions,
            color: Daylight.card,
            surfaceTintColor: Colors.transparent,
            onSelected: (_) => onDismiss(),
            itemBuilder: (context) => [
              buildPopupMenuItem<String>(
                value: 'dismiss',
                icon: FluentIcons.eye_off_24_regular,
                label: l10n.hideThisSection,
                colorScheme: Theme.of(context).colorScheme,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _TasteSongCard(
                song: songs[index],
                onTap: () => onPlay(index),
                onNotInterested: () => onNotInterested(songs[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TasteSongCard extends StatelessWidget {
  const _TasteSongCard({
    required this.song,
    required this.onTap,
    required this.onNotInterested,
  });

  final Map song;
  final VoidCallback onTap;
  final VoidCallback onNotInterested;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;
    final imageUrl = (song['highResImage'] ?? song['image'])?.toString();

    return SizedBox(
      width: 116,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 116,
                    height: 116,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image(
                            image: ArtworkProvider.get(imageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _artFallback(),
                          )
                        : _artFallback(),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: PopupMenuButton<String>(
                    tooltip: l10n.moreOptions,
                    color: Daylight.card,
                    surfaceTintColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    onSelected: (_) => onNotInterested(),
                    itemBuilder: (context) => [
                      buildPopupMenuItem<String>(
                        value: 'not_interested',
                        icon: FluentIcons.eye_off_24_regular,
                        label: l10n.notInterested,
                        colorScheme: Theme.of(context).colorScheme,
                      ),
                    ],
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Daylight.card.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: Daylight.cardShadow,
                      ),
                      child: Icon(
                        FluentIcons.more_horizontal_20_regular,
                        size: 16,
                        color: Daylight.ink,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: Daylight.cobaltGradient,
                      shape: BoxShape.circle,
                      boxShadow: Daylight.cobaltShadow,
                    ),
                    child: const Icon(
                      FluentIcons.play_24_filled,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              song['title']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Daylight.ui(11.5, weight: FontWeight.w600),
            ),
            const SizedBox(height: 1),
            Text(
              song['artist']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Daylight.ui(9.5, color: Daylight.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: Daylight.softCobaltGradient),
      child: Center(
        child: Icon(
          FluentIcons.music_note_2_24_filled,
          size: 28,
          color: Daylight.cobalt,
        ),
      ),
    );
  }
}
