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
import 'package:musify/theme/daylight.dart';
import 'package:musify/widgets/daylight/press_scale.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/utilities/playlist_dialogs.dart';

/// The single circled "+" beside the now-playing title.
///
/// It opens one sheet that holds Liked Songs and the user's playlists. When a
/// song is actually added to Liked Songs, the plus morphs into a check as
/// confirmation, then settles back.
class SongQuickActions extends StatefulWidget {
  const SongQuickActions({super.key, required this.metadata});

  final MediaItem metadata;

  @override
  State<SongQuickActions> createState() => _SongQuickActionsState();
}

class _SongQuickActionsState extends State<SongQuickActions> {
  bool _addedToLiked = false;
  Timer? _resetTimer;

  bool get _isRadio => widget.metadata.extras?['isLive'] ?? false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _openPlaylistSheet() async {
    final addedToLiked = await showAddToPlaylistDialog(
      context,
      song: mediaItemToMap(widget.metadata),
      showLikedSongs: !_isRadio,
    );

    if (!mounted || !addedToLiked) return;

    _resetTimer?.cancel();
    setState(() => _addedToLiked = true);
    _resetTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _addedToLiked = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;
    final active = _addedToLiked;

    return Semantics(
      button: true,
      label: active ? l10n.liked : l10n.addToPlaylist,
      child: SizedBox(
        width: 40,
        height: 40,
        child: PressScale(
          child: Material(
            color: active ? Daylight.cobalt : Daylight.card,
            shape: CircleBorder(
              side: BorderSide(
                color: active
                    ? Colors.transparent
                    : Daylight.lineStrong.withValues(alpha: 0.5),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _openPlaylistSheet,
              customBorder: const CircleBorder(),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    active
                        ? FluentIcons.checkmark_24_filled
                        : FluentIcons.add_24_regular,
                    key: ValueKey(active),
                    size: 20,
                    color: active ? Daylight.onAccent : Daylight.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
