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

import 'package:material_ui/material_ui.dart';

class MarqueeWidget extends StatefulWidget {
  const MarqueeWidget({
    super.key,
    required this.child,
    this.direction = Axis.horizontal,
    this.animationDuration = const Duration(milliseconds: 6000),
    this.backDuration = const Duration(milliseconds: 800),
    this.pauseDuration = const Duration(milliseconds: 800),
    this.manualScrollEnabled = true,
  });

  final Widget child;
  final Axis direction;
  final Duration animationDuration, backDuration, pauseDuration;
  final bool manualScrollEnabled;

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  bool _isAnimating = false;
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The controller's viewport metrics only exist after the first layout,
      // so rebuild once to paint the clipped-edge fade before any scrolling.
      setState(() {});
      _startAnimation();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final viewport = SingleChildScrollView(
      scrollDirection: widget.direction,
      controller: _scrollController,
      physics: widget.manualScrollEnabled
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      child: widget.child,
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, child) {
          if (!_scrollController.hasClients) return child!;
          final position = _scrollController.position;
          if (position.maxScrollExtent <= 0) return child!;

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (!width.isFinite || width <= 0) return child!;

              // Soften the hard cut at whichever edge still has hidden text.
              // Fading only the clipped side leaves the first character solid
              // at rest and the last one solid once the title has scrolled.
              final fade = math.min(24, width / 3);
              final fadeLeft = position.pixels > 0.5;
              final fadeRight =
                  position.pixels < position.maxScrollExtent - 0.5;
              if (!fadeLeft && !fadeRight) return child!;

              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) {
                  final colors = <Color>[];
                  final stops = <double>[];
                  if (fadeLeft) {
                    colors.add(Colors.transparent);
                    stops.add(0);
                    colors.add(Colors.white);
                    stops.add(fade / rect.width);
                  } else {
                    colors.add(Colors.white);
                    stops.add(0);
                  }
                  if (fadeRight) {
                    colors.add(Colors.white);
                    stops.add(1 - fade / rect.width);
                    colors.add(Colors.transparent);
                    stops.add(1);
                  } else {
                    colors.add(Colors.white);
                    stops.add(1);
                  }
                  return LinearGradient(
                    colors: colors,
                    stops: stops,
                  ).createShader(rect);
                },
                child: child,
              );
            },
          );
        },
        child: viewport,
      ),
    );
  }

  Future<void> _startAnimation() async {
    if (_isDisposed || _isAnimating) return;

    _isAnimating = true;

    while (_scrollController.hasClients && !_isDisposed) {
      try {
        // Check if content actually needs scrolling
        if (_scrollController.position.maxScrollExtent <= 0) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        await Future.delayed(widget.pauseDuration);
        if (_isDisposed || !_scrollController.hasClients) break;

        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.animationDuration,
          curve: Curves.linear,
        );

        await Future.delayed(widget.pauseDuration);
        if (_isDisposed || !_scrollController.hasClients) break;

        await _scrollController.animateTo(
          0,
          duration: widget.backDuration,
          curve: Curves.easeOut,
        );
      } catch (e) {
        // Handle animation interruptions gracefully
        break;
      }
    }

    _isAnimating = false;
  }
}
