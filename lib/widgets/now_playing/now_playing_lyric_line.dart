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
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/models/song_lyrics.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/daylight.dart';

/// The live lyric line that sits between the artwork and the track title on
/// the reference player. When a synced source exists it follows playback; for
/// plain lyrics it shows the first line.
class NowPlayingLyricLine extends StatefulWidget {
  const NowPlayingLyricLine({super.key, required this.metadata});

  final MediaItem metadata;

  @override
  State<NowPlayingLyricLine> createState() => _NowPlayingLyricLineState();
}

class _NowPlayingLyricLineState extends State<NowPlayingLyricLine> {
  SongLyrics? _lyrics;
  String? _resolvedKey;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(NowPlayingLyricLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolve();
  }

  void _resolve() {
    final key =
        '${widget.metadata.artist} - ${widget.metadata.title} - '
        '${widget.metadata.duration?.inSeconds ?? 0}';
    if (key == _resolvedKey) return;
    _resolvedKey = key;
    _lyrics = null;

    unawaited(
      getSongLyricsData(
        widget.metadata.artist,
        widget.metadata.title,
        duration: widget.metadata.duration,
        album: widget.metadata.album,
      ).then((data) {
        if (mounted && key == _resolvedKey) {
          setState(() => _lyrics = data);
        }
      }),
    );
  }

  LyricsLine? _activeLine(Duration position) {
    final lyrics = _lyrics;
    if (lyrics == null) return null;

    var adjusted =
        position -
        Duration(
          milliseconds: getLyricsOffset(lyricsOffsetKey(widget.metadata)),
        );
    if (adjusted.isNegative) adjusted = Duration.zero;

    final timed = lyrics.timed;
    if (timed.isEmpty) {
      final first = lyrics.plainLines.firstWhere(
        (line) => !line.startsWith('©'),
        orElse: () => '',
      );
      return first.isEmpty ? null : LyricsLine(text: first);
    }

    LyricsLine? current;
    for (final line in timed) {
      final time = line.time ?? Duration.zero;
      if (time <= adjusted) {
        current = line;
      } else {
        break;
      }
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.metadata.extras?['isLive'] ?? false;
    if (isLive) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: StreamBuilder<PositionData>(
        stream: audioHandler.positionDataStream,
        initialData: audioHandler.currentPositionData,
        builder: (context, snapshot) {
          final active = _activeLine(snapshot.data?.position ?? Duration.zero);
          if (active == null) return const SizedBox.shrink();

          final line = active.isInstrumental ? instrumentalGlyphs : active.text;
          final synced = _lyrics?.isSynced ?? false;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/lyrics'),
            child: Semantics(
              label: active.isInstrumental ? context.l10n!.instrumental : null,
              excludeSemantics: active.isInstrumental,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: Daylight.display(
                    active.isInstrumental ? 19 : 17,
                    color: synced ? Daylight.cobalt : Daylight.ink,
                    height: 1.25,
                    letterSpacing: active.isInstrumental ? 2 : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
