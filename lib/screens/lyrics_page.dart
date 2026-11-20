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
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/models/song_lyrics.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/overflow_menu_button.dart';
import 'package:musify/widgets/popup_menu_item.dart';
import 'package:musify/widgets/position_slider.dart';
import 'package:share_plus/share_plus.dart';

/// Full-screen lyrics. Reference layout: title in the app bar, scrolling
/// lines, Share / text-size actions, then the transport at the bottom.
class LyricsPage extends StatefulWidget {
  const LyricsPage({super.key});

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  double _textSize = 18;
  int _offsetMs = 0;
  String _offsetKey = '';

  void _loadOffset(MediaItem metadata) {
    final key = lyricsOffsetKey(metadata);
    if (key == _offsetKey) return;
    _offsetKey = key;
    _offsetMs = getLyricsOffset(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            final metadata = snapshot.data;
            if (metadata == null) {
              return Center(
                child: DaylightEmptyState(
                  title: context.l10n!.lyrics,
                  message: context.l10n!.lyricsNotAvailable,
                  icon: FluentIcons.text_quote_24_regular,
                ),
              );
            }

            _loadOffset(metadata);

            return Column(
              children: [
                _buildAppBar(context, metadata),
                Expanded(
                  child: _LyricsBody(
                    metadata: metadata,
                    textSize: _textSize,
                    offsetMs: _offsetMs,
                  ),
                ),
                _buildBottomActions(context, metadata),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: PositionSlider(),
                ),
                _buildTransport(),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, MediaItem metadata) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Row(
        children: [
          DaylightCircleButton(
            icon: FluentIcons.chevron_down_24_regular,
            iconSize: 19,
            tooltip: context.l10n!.close,
            onTap: () => context.pop(),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metadata.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Daylight.display(
                    13,
                    color: Daylight.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                if (metadata.artist != null && metadata.artist!.isNotEmpty)
                  Text(
                    metadata.artist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Daylight.ui(10, color: Daylight.muted),
                  ),
              ],
            ),
          ),
          OverflowMenuButton<String>(
            iconSize: 18,
            color: Daylight.ink,
            onSelected: (value) {
              if (value == 'size') {
                setState(
                  () => _textSize = _textSize >= 22 ? 15 : _textSize + 2,
                );
              }
            },
            itemBuilder: (context) => [
              buildPopupMenuItem<String>(
                value: 'size',
                icon: FluentIcons.text_font_size_24_regular,
                label: context.l10n!.lyrics,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, MediaItem metadata) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          DaylightPill(
            label: context.l10n!.share,
            icon: FluentIcons.share_24_regular,
            onTap: () {
              final artist = metadata.artist?.trim();
              final text = artist == null || artist.isEmpty
                  ? metadata.title
                  : '$artist - ${metadata.title}';
              SharePlus.instance.share(ShareParams(text: text));
            },
          ),
          const SizedBox(width: 8),
          DaylightPill(
            label: 'Aa',
            onTap: () => setState(
              () => _textSize = _textSize >= 22 ? 15 : _textSize + 2,
            ),
          ),
          const Spacer(),
          DaylightPill(
            label: context.l10n!.syncLyrics,
            icon: FluentIcons.arrow_sync_24_regular,
            onTap: () => _showSyncSheet(context, metadata),
          ),
        ],
      ),
    );
  }

  void _showSyncSheet(BuildContext context, MediaItem metadata) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final seconds = (_offsetMs / 1000).toStringAsFixed(1);
            final signed = _offsetMs > 0 ? '+$seconds' : seconds;

            void apply(int next) {
              setState(() => _offsetMs = next);
              setSheetState(() {});
              unawaited(setLyricsOffset(_offsetKey, next));
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: DaylightCard(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n!.lyricsOffset,
                        style: Daylight.display(20, height: 1.1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n!.syncHint,
                        textAlign: TextAlign.center,
                        style: Daylight.ui(11, color: Daylight.muted),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _offsetButton(
                            context.l10n!.syncEarlier,
                            FluentIcons.subtract_20_regular,
                            () => apply(_offsetMs - 500),
                          ),
                          SizedBox(
                            width: 76,
                            child: Text(
                              '$signed s',
                              textAlign: TextAlign.center,
                              style: Daylight.display(
                                20,
                                color: _offsetMs == 0
                                    ? Daylight.muted
                                    : Daylight.cobalt,
                                height: 1,
                              ),
                            ),
                          ),
                          _offsetButton(
                            context.l10n!.syncLater,
                            FluentIcons.add_20_regular,
                            () => apply(_offsetMs + 500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _offsetMs == 0 ? null : () => apply(0),
                        child: Text(context.l10n!.reset),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _offsetButton(String label, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Daylight.ink,
        backgroundColor: Daylight.cardTint,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Widget _buildTransport() {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.playing ?? false;
        final isLoading =
            state?.processingState == AudioProcessingState.loading ||
            state?.processingState == AudioProcessingState.buffering;

        return Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: Daylight.cobaltGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Daylight.cobaltDeep.withValues(alpha: 0.34),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isPlaying ? audioHandler.pause : audioHandler.play,
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Daylight.onAccent,
                          ),
                        )
                      : Icon(
                          isPlaying
                              ? FluentIcons.pause_16_filled
                              : FluentIcons.play_16_filled,
                          color: Daylight.onAccent,
                          size: 24,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LyricsBody extends StatefulWidget {
  const _LyricsBody({
    required this.metadata,
    required this.textSize,
    required this.offsetMs,
  });

  final MediaItem metadata;
  final double textSize;
  final int offsetMs;

  @override
  State<_LyricsBody> createState() => _LyricsBodyState();
}

class _LyricsBodyState extends State<_LyricsBody> {
  String? _key;
  late Future<SongLyrics?> _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_LyricsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolve();
  }

  void _resolve() {
    final key =
        '${widget.metadata.artist} - ${widget.metadata.title} - '
        '${widget.metadata.duration?.inSeconds ?? 0}';
    if (key == _key) return;
    _key = key;
    _future = getSongLyricsData(
      widget.metadata.artist ?? '',
      widget.metadata.title,
      duration: widget.metadata.duration,
      album: widget.metadata.album,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncLoader<SongLyrics?>(
      future: _future,
      emptyWidget: Center(
        child: DaylightEmptyState(
          title: context.l10n!.lyricsNotAvailable,
          message: widget.metadata.title,
          icon: FluentIcons.text_quote_24_regular,
        ),
      ),
      errorBuilder: (context, error, stack) => Center(
        child: DaylightEmptyState(
          title: context.l10n!.lyricsNotAvailable,
          message: widget.metadata.title,
          icon: FluentIcons.text_quote_24_regular,
        ),
      ),
      builder: (context, lyrics) {
        if (lyrics == null || lyrics.plainLines.isEmpty) {
          return Center(
            child: DaylightEmptyState(
              title: context.l10n!.lyricsNotAvailable,
              message: widget.metadata.title,
              icon: FluentIcons.text_quote_24_regular,
            ),
          );
        }

        return lyrics.isSynced
            ? _SyncedLyricsView(
                lines: lyrics.timed,
                textSize: widget.textSize,
                offsetMs: widget.offsetMs,
              )
            : _PlainLyricsView(
                lines: lyrics.plainLines,
                textSize: widget.textSize,
              );
      },
    );
  }
}

/// Plain lyrics: static scrolling text with the Daylight fade at the edges.
class _PlainLyricsView extends StatelessWidget {
  const _PlainLyricsView({required this.lines, required this.textSize});

  final List<String> lines;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0.0, 0.12, 0.88, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  line,
                  style: Daylight.display(
                    textSize,
                    color: Daylight.ink.withValues(alpha: 0.8),
                    weight: FontWeight.w600,
                    height: 1.34,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Timestamped lyrics: the active line follows playback, is highlighted and
/// scrolled into view; tapping a line seeks to its timestamp.
class _SyncedLyricsView extends StatefulWidget {
  const _SyncedLyricsView({
    required this.lines,
    required this.textSize,
    required this.offsetMs,
  });

  final List<LyricsLine> lines;
  final double textSize;
  final int offsetMs;

  @override
  State<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<_SyncedLyricsView> {
  final Map<int, GlobalKey> _keys = {};
  final ScrollController _controller = ScrollController();
  int _active = -1;
  DateTime? _userScrollAt;

  static const _userScrollCooldown = Duration(seconds: 5);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexFor(Duration position) {
    var index = -1;
    for (var i = 0; i < widget.lines.length; i++) {
      final time = widget.lines[i].time ?? Duration.zero;
      if (time <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  void _scrollToActive(int index, {bool animate = true}) {
    final context = _keys[index]?.currentContext;
    if (context == null) return;

    final scrolledAt = _userScrollAt;
    if (scrolledAt != null &&
        DateTime.now().difference(scrolledAt) < _userScrollCooldown) {
      return;
    }

    Scrollable.ensureVisible(
      context,
      alignment: 0.42,
      duration: animate ? const Duration(milliseconds: 320) : Duration.zero,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: audioHandler.positionDataStream,
      initialData: audioHandler.currentPositionData,
      builder: (context, snapshot) {
        final position = snapshot.data?.position ?? Duration.zero;
        final offset = Duration(milliseconds: widget.offsetMs);
        var adjusted = position - offset;
        if (adjusted.isNegative) adjusted = Duration.zero;
        final active = _indexFor(adjusted);
        if (active != _active) {
          _active = active;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToActive(active);
          });
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification ||
                notification is ScrollStartNotification) {
              _userScrollAt = DateTime.now();
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _controller,
            padding: const EdgeInsets.fromLTRB(26, 64, 26, 120),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.lines.length; i++)
                  _buildLine(i, widget.lines[i]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLine(int index, LyricsLine line) {
    final isActive = index == _active;
    return Padding(
      key: _keys.putIfAbsent(index, () => GlobalKey()),
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          var target =
              (line.time ?? Duration.zero) +
              Duration(milliseconds: widget.offsetMs);
          if (target.isNegative) target = Duration.zero;
          audioHandler.seek(target);
        },
        child: AnimatedDefaultTextStyle(
          duration: Daylight.motion(context, const Duration(milliseconds: 220)),
          curve: Curves.easeOut,
          style: Daylight.display(
            isActive ? widget.textSize + 2.5 : widget.textSize,
            color: isActive
                ? Daylight.cobalt
                : Daylight.ink.withValues(alpha: 0.34),
            weight: isActive ? FontWeight.w700 : FontWeight.w500,
            height: 1.3,
          ),
          child: Text(line.text, textAlign: TextAlign.left),
        ),
      ),
    );
  }
}
