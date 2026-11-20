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

/// The metadata and actions below a playlist, album or artist hero.
class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader({
    super.key,
    required this.title,
    this.songsLength,
    this.isAlbum,
    this.isArtist = false,
    this.showTitle = true,
    this.monthlyListeners,
    this.description,
    this.artist,
    this.releaseDate,
    this.artistArtwork,
  });

  final String title;

  /// Left null by the artist page, which does not hold the song list itself.
  final int? songsLength;
  final bool? isAlbum;
  final bool isArtist;
  final bool showTitle;

  /// Real metadata for the Spotify-style album header (all optional).
  final String? artist;
  final DateTime? releaseDate;
  final String? artistArtwork;

  /// Monthly listeners of an artist, already shortened, e.g. `447M`.
  final String? monthlyListeners;

  /// Artist biography, collapsed until tapped.
  final String? description;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;
    final isAlbumView = isAlbum == true && !isArtist;
    if (isAlbumView) return _buildAlbumHeader(context);

    final typeLabel = isArtist
        ? l10n.artist
        : isAlbum == true
        ? l10n.album
        : l10n.playlist;

    final details = <String>[
      typeLabel,
      if (songsLength != null) '$songsLength ${l10n.songs}',
      if (monthlyListeners != null)
        '$monthlyListeners ${l10n.monthlyListeners}',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(24, showTitle ? 12 : 4, 24, 8),
      child: Column(
        children: [
          if (showTitle) ...[
            Text(
              title,
              style: Daylight.display(
                23,
                color: Daylight.ink,
                height: 1.12,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
          ],
          Text(
            details.join(' · '),
            style: Daylight.ui(10.5, color: Daylight.muted),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (description != null && description!.trim().isNotEmpty)
            _Description(description!.trim()),
        ],
      ),
    );
  }

  /// Spotify-style left-aligned album header: bold title, an artist row with a
  /// circular avatar, and a `Album • date` line. All metadata is real (looked
  /// up online) and simply omitted when unavailable.
  Widget _buildAlbumHeader(BuildContext context) {
    final l10n = context.l10n!;
    final dateText = releaseDate != null
        ? '${releaseDate!.day} ${_monthShort(releaseDate!.month)} ${releaseDate!.year}'
        : null;
    final meta = <String>[l10n.album];
    if (dateText != null) {
      meta.add(dateText);
    } else if (songsLength != null) {
      meta.add('$songsLength ${l10n.songs}');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Daylight.display(28, weight: FontWeight.w800, height: 1.08),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (artist != null && artist!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (artistArtwork != null && artistArtwork!.isNotEmpty)
                  ClipOval(
                    child: Image(
                      image: ArtworkProvider.get(artistArtwork!),
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(),
                    ),
                  )
                else
                  _avatarFallback(),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    artist!.trim(),
                    style: Daylight.ui(
                      13,
                      weight: FontWeight.w700,
                      color: Daylight.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            meta.join('  ·  '),
            style: Daylight.ui(12, color: Daylight.muted),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: Daylight.cardTintStrong,
      shape: BoxShape.circle,
    ),
    child: Icon(FluentIcons.person_24_regular, size: 15, color: Daylight.faint),
  );

  String _monthShort(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

/// The artist biography, three lines until it is tapped.
class _Description extends StatefulWidget {
  const _Description(this.text);

  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          widget.text,
          style: Daylight.ui(11, color: Daylight.muted, height: 1.5),
          textAlign: TextAlign.center,
          maxLines: _isExpanded ? null : 3,
          overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
