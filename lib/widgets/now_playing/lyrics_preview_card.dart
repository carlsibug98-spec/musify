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
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/models/song_lyrics.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';

/// The tall lyrics card that appears below the player controls: a scrollable,
/// playback-following lyric sheet that can also be tapped to seek.
class LyricsPreviewCard extends StatefulWidget {
  const LyricsPreviewCard({super.key, required this.metadata});

  final MediaItem metadata;

  @override
  State<LyricsPreviewCard> createState() => _LyricsPreviewCardState();
}

class _LyricsPreviewCardState extends State<LyricsPreviewCard> {
  SongLyrics? _lyrics;
  String? _resolvedKey;
  bool _loading = true;

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _active = -1;
  DateTime? _userScrollAt;
  bool _programmaticScroll = false;

  static const _userScrollCooldown = Duration(seconds: 4);

  // Strong ease-out (Emil Kowalski's --ease-out): starts fast, settles gently.
  static const _scrollCurve = Cubic(0.23, 1, 0.32, 1);

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(LyricsPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolve();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final artist = widget.metadata.artist ?? '';
    final key =
        '$artist - ${widget.metadata.title} - '
        '${widget.metadata.album ?? ''} - '
        '${widget.metadata.duration?.inSeconds ?? ''}';
    if (key == _resolvedKey) return;

    _resolvedKey = key;
    _lineKeys.clear();
    _active = -1;
    _userScrollAt = null;
    setState(() {
      _loading = true;
      _lyrics = null;
    });

    final data = await getSongLyricsData(
      artist,
      widget.metadata.title,
      duration: widget.metadata.duration,
      album: widget.metadata.album,
    );

    if (!mounted || key != _resolvedKey) return;
    setState(() {
      _lyrics = data;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;
    final cardHeight = (MediaQuery.sizeOf(context).height * 0.42).clamp(
      320.0,
      430.0,
    );

    return DaylightCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
      child: SizedBox(
        height: cardHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.lyricsPreview.toUpperCase(),
                    style: Daylight.ui(
                      9,
                      color: Daylight.faint,
                      weight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                if (_lyrics?.isSynced ?? false)
                  Icon(
                    FluentIcons.music_note_2_20_regular,
                    size: 16,
                    color: Daylight.cobalt.withValues(alpha: 0.7),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildBody(context)),
            const SizedBox(height: 8),
            DaylightPill(
              label: l10n.showLyrics,
              icon: FluentIcons.text_quote_24_regular,
              onTap: () => context.push('/lyrics'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Daylight.cobalt,
          ),
        ),
      );
    }

    final lyrics = _lyrics;
    if (lyrics == null || lyrics.plainLines.isEmpty) {
      return Center(
        child: Text(
          context.l10n!.lyricsNotAvailable,
          textAlign: TextAlign.center,
          style: Daylight.ui(12, color: Daylight.muted),
        ),
      );
    }

    final lines = _linesFor(lyrics);
    if (lines.isEmpty) {
      return Center(
        child: Text(
          context.l10n!.lyricsNotAvailable,
          textAlign: TextAlign.center,
          style: Daylight.ui(12, color: Daylight.muted),
        ),
      );
    }

    return StreamBuilder<PositionData>(
      stream: audioHandler.positionDataStream,
      initialData: audioHandler.currentPositionData,
      builder: (context, snapshot) {
        final position = snapshot.data?.position ?? Duration.zero;
        final offsetMs = getLyricsOffset(lyricsOffsetKey(widget.metadata));
        var adjusted = position - Duration(milliseconds: offsetMs);
        if (adjusted.isNegative) adjusted = Duration.zero;

        final active = _activeIndex(lyrics, adjusted);
        if (active != _active) {
          _active = active;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToActive(active);
          });
        }

        return _buildLines(context, lines, active, offsetMs);
      },
    );
  }

  List<LyricsLine> _linesFor(SongLyrics lyrics) {
    if (lyrics.isSynced) return lyrics.timed;
    return lyrics.plainLines
        .where((line) => !line.startsWith('©'))
        .map((line) => LyricsLine(text: line))
        .toList();
  }

  int _activeIndex(SongLyrics lyrics, Duration position) {
    if (!lyrics.isSynced) return -1;
    var index = -1;
    for (var i = 0; i < lyrics.timed.length; i++) {
      final time = lyrics.timed[i].time ?? Duration.zero;
      if (time <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  Widget _buildLines(
    BuildContext context,
    List<LyricsLine> lines,
    int active,
    int offsetMs,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_programmaticScroll) return false;
        final isUserScroll =
            notification is UserScrollNotification ||
            (notification is ScrollStartNotification &&
                notification.dragDetails != null);
        if (isUserScroll) _userScrollAt = DateTime.now();
        return false;
      },
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.07, 0.93, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 16, 6, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines.length; i++)
                _buildLine(i, lines[i], active, offsetMs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(int index, LyricsLine line, int active, int offsetMs) {
    final isActive = index == active;
    final isPast = active >= 0 && index < active;
    final time = line.time;

    return Padding(
      key: _lineKeys.putIfAbsent(index, () => GlobalKey()),
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: time == null
            ? null
            : () {
                var target = time + Duration(milliseconds: offsetMs);
                if (target.isNegative) target = Duration.zero;
                audioHandler.seek(target);
              },
        child: AnimatedDefaultTextStyle(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          style: Daylight.display(
            isActive ? 16.5 : 15,
            color: isActive
                ? Daylight.cobalt
                : Daylight.ink.withValues(alpha: isPast ? 0.3 : 0.52),
            weight: isActive ? FontWeight.w700 : FontWeight.w500,
            height: 1.3,
          ),
          child: Text(line.text),
        ),
      ),
    );
  }

  Future<void> _scrollToActive(int index) async {
    if (index < 0) return;

    final lineContext = _lineKeys[index]?.currentContext;
    if (lineContext == null || !_scrollController.hasClients) return;

    final scrolledAt = _userScrollAt;
    if (scrolledAt != null &&
        DateTime.now().difference(scrolledAt) < _userScrollCooldown) {
      return;
    }

    final renderObject = lineContext.findRenderObject();
    if (renderObject == null) return;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _programmaticScroll = true;
    try {
      await _scrollController.position.ensureVisible(
        renderObject,
        alignment: 0.38,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: reduceMotion ? Curves.linear : _scrollCurve,
      );
    } finally {
      _programmaticScroll = false;
    }
  }
}
