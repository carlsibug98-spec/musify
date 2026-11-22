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

import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/services/artwork_palette.dart';
import 'package:musify/theme/daylight.dart';

/// Full-bleed backdrop for the player.
///
/// The top colour is sampled from the current cover and clamped by
/// [artworkBackdropTop] so white text keeps its contrast. The tint resolves
/// once per artwork URL, so a fast track change cannot leave the previous
/// cover's colour on screen.
class NowPlayingBackdrop extends StatefulWidget {
  const NowPlayingBackdrop({
    required this.metadata,
    required this.child,
    super.key,
  });

  final MediaItem metadata;
  final Widget child;

  @override
  State<NowPlayingBackdrop> createState() => _NowPlayingBackdropState();
}

class _NowPlayingBackdropState extends State<NowPlayingBackdrop> {
  Future<Color?>? _tintFuture;
  String? _artKey;

  @override
  void initState() {
    super.initState();
    _resolveTint();
  }

  @override
  void didUpdateWidget(NowPlayingBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = widget.metadata.artUri?.toString();
    if (nextKey != _artKey) _resolveTint();
  }

  void _resolveTint() {
    _artKey = widget.metadata.artUri?.toString();
    _tintFuture = _artKey == null ? null : songArtworkTint(widget.metadata);
  }

  @override
  Widget build(BuildContext context) {
    final future = _tintFuture;
    if (!Daylight.isDark || future == null) {
      return _Backdrop(tint: null, child: widget.child);
    }

    return FutureBuilder<Color?>(
      future: future,
      builder: (context, snapshot) =>
          _Backdrop(tint: snapshot.data, child: widget.child),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.tint, required this.child});

  final Color? tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = artworkBackdropTop(tint);
    final bottom = artworkBackdropBottom();
    final gradient = Daylight.isDark
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, Color.lerp(top, bottom, 0.45)!, bottom],
            stops: const [0.0, 0.52, 1.0],
          )
        : Daylight.screenGradient;

    return AnimatedContainer(
      duration: Daylight.motion(context, const Duration(milliseconds: 450)),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (Daylight.isDark && tint != null)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 0.95,
                  colors: [
                    tint!.withValues(alpha: 0.22),
                    tint!.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
