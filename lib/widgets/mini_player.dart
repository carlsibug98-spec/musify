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
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/models/full_player_state.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/screens/now_playing_page.dart';
import 'package:musify/services/artwork_palette.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/widgets/marquee.dart';
import 'package:musify/widgets/song_artwork.dart';
import 'package:rxdart/rxdart.dart';

final Stream<FullPlayerState> _fullPlayerStateStream =
    Rx.combineLatest3(
          audioHandler.playbackStateStream,
          audioHandler.queue.distinct(),
          audioHandler.positionDataStream,
          (PlaybackState state, List<MediaItem> queue, PositionData pos) =>
              FullPlayerState(
                playbackState: state,
                queue: queue,
                position: pos,
              ),
        )
        .throttleTime(const Duration(milliseconds: 120), trailing: true)
        .asBroadcastStream();

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  // Spotify's floating now-playing bar: 56 dp tall, 8 dp radius, 8 dp inset,
  // 40 dp cover with a 4 dp radius. Matching those measurements keeps the bar
  // from dominating the home feed while the artwork stays legible.
  static const double playerHeight = 56;
  static const double _borderRadius = 8;
  static const double _artworkSize = 40;
  static const double _artworkRadius = 4;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaSnapshot) {
          final metadata = mediaSnapshot.data;
          if (metadata == null) return const SizedBox.shrink();

          return StreamBuilder<FullPlayerState>(
            stream: _fullPlayerStateStream,
            builder: (context, stateSnapshot) {
              final state = stateSnapshot.data;
              if (state == null) return const SizedBox.shrink();

              final hasNext =
                  state.queue.length > 1 &&
                  (state.playbackState.queueIndex ?? 0) <
                      state.queue.length - 1;

              return _MiniPlayerBody(
                colorScheme: colorScheme,
                metadata: metadata,
                state: state,
                hasNext: hasNext,
              );
            },
          );
        },
      ),
    );
  }
}

class _MiniPlayerBody extends StatefulWidget {
  const _MiniPlayerBody({
    required this.colorScheme,
    required this.metadata,
    required this.state,
    required this.hasNext,
  });

  final ColorScheme colorScheme;
  final MediaItem metadata;
  final FullPlayerState state;
  final bool hasNext;

  @override
  State<_MiniPlayerBody> createState() => _MiniPlayerBodyState();
}

class _MiniPlayerBodyState extends State<_MiniPlayerBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  static const double _dragThresholdForNavigation = 10;

  void _handleVerticalDrag(DragUpdateDetails details) {
    if ((details.primaryDelta ?? 0) < -_dragThresholdForNavigation) {
      _navigateToNowPlaying();
    }
  }

  void _navigateToNowPlaying() {
    Navigator.of(context).push(_createSlideTransition());
  }

  PageRoute<void> _createSlideTransition() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, _) => const NowPlayingPage(),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final tween = Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final metadata = widget.metadata;
    final state = widget.state;

    final totalDuration = state.position.duration > Duration.zero
        ? state.position.duration
        : (metadata.duration ?? Duration.zero);
    final progress = totalDuration.inMilliseconds == 0
        ? 0.0
        : (state.position.position.inMilliseconds /
                  totalDuration.inMilliseconds)
              .clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            onVerticalDragUpdate: _handleVerticalDrag,
            onTap: _navigateToNowPlaying,
            child: FutureBuilder<Color?>(
              future: songArtworkTint(metadata),
              builder: (context, tintSnapshot) {
                return Container(
                  height: MiniPlayer.playerHeight,
                  decoration: BoxDecoration(
                    color: artworkTintedSurface(tintSnapshot.data),
                    borderRadius: BorderRadius.circular(
                      MiniPlayer._borderRadius,
                    ),
                    boxShadow: Daylight.floatingShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      MiniPlayer._borderRadius,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 2,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(color: Daylight.line),
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: ColoredBox(color: Daylight.cobalt),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                            child: Row(
                              children: [
                                _ArtworkWidget(metadata: metadata),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: Daylight.motion(
                                      context,
                                      const Duration(milliseconds: 300),
                                    ),
                                    switchInCurve: Curves.easeIn,
                                    switchOutCurve: Curves.easeOut,
                                    layoutBuilder:
                                        (currentChild, previousChildren) =>
                                            Stack(
                                              alignment: Alignment.centerLeft,
                                              children: [
                                                ...previousChildren,
                                                if (currentChild != null)
                                                  currentChild,
                                              ],
                                            ),
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                    child: KeyedSubtree(
                                      key: ValueKey(metadata.id),
                                      child: _MetadataWidget(
                                        title: metadata.title,
                                        artist: metadata.artist,
                                        colorScheme: colorScheme,
                                      ),
                                    ),
                                  ),
                                ),
                                _ControlsWidget(
                                  playbackState: state.playbackState,
                                  hasNext: widget.hasNext,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ArtworkWidget extends StatelessWidget {
  const _ArtworkWidget({required this.metadata});
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Hero(
        tag: 'now_playing_artwork',
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MiniPlayer._artworkRadius),
            boxShadow: [
              BoxShadow(
                color: Daylight.ink.withValues(alpha: 0.14),
                blurRadius: 8,
                offset: const Offset(0, 3),
                spreadRadius: -3,
              ),
            ],
          ),
          child: SongArtworkWidget(
            metadata: metadata,
            size: MiniPlayer._artworkSize,
            errorWidgetIconSize: 20,
            borderRadius: MiniPlayer._artworkRadius,
          ),
        ),
      ),
    );
  }
}

class _MetadataWidget extends StatelessWidget {
  const _MetadataWidget({
    required this.title,
    required this.artist,
    required this.colorScheme,
  });

  final String title;
  final String? artist;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarqueeWidget(
            manualScrollEnabled: false,
            animationDuration: const Duration(seconds: 8),
            backDuration: const Duration(seconds: 2),
            pauseDuration: const Duration(seconds: 2),
            child: Text(
              title,
              style: Daylight.ui(
                13.5,
                color: Daylight.ink,
                weight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (artist != null && artist!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              artist!,
              style: Daylight.ui(11.5, color: Daylight.muted, height: 1.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlsWidget extends StatelessWidget {
  const _ControlsWidget({required this.playbackState, required this.hasNext});

  final PlaybackState playbackState;
  final bool hasNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniPlayButton(playbackState: playbackState),
        if (hasNext) ...[
          const SizedBox(width: 2),
          IconButton(
            onPressed: audioHandler.skipToNext,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            icon: Icon(
              FluentIcons.next_24_filled,
              color: Daylight.ink,
              size: 24,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ],
    );
  }
}

class _MiniPlayButton extends StatelessWidget {
  const _MiniPlayButton({required this.playbackState});

  final PlaybackState playbackState;

  @override
  Widget build(BuildContext context) {
    final processingState = playbackState.processingState;
    final isPlaying = playbackState.playing;
    final isLoading =
        processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering;
    final isCompleted = processingState == AudioProcessingState.completed;

    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: isCompleted
            ? () => audioHandler.playAgain()
            : (isPlaying ? audioHandler.pause : audioHandler.play),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Daylight.ink,
                ),
              )
            : Icon(
                isCompleted
                    ? FluentIcons.arrow_counterclockwise_24_filled
                    : (isPlaying
                          ? FluentIcons.pause_24_filled
                          : FluentIcons.play_24_filled),
                color: Daylight.ink,
                size: 26,
              ),
      ),
    );
  }
}
