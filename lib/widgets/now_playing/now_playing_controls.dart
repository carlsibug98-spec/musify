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
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/now_playing/marquee_text_widget.dart';
import 'package:musify/widgets/now_playing/now_playing_lyric_line.dart';
import 'package:musify/widgets/now_playing/song_quick_actions.dart';
import 'package:musify/widgets/playback_icon_button.dart';
import 'package:musify/widgets/position_slider.dart';

class NowPlayingControls extends StatelessWidget {
  const NowPlayingControls({
    super.key,
    required this.size,
    required this.audioId,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.metadata,
  });

  final Size size;
  final dynamic audioId;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final isDesktop = size.width > 800;
    final isLive = metadata.extras?['isLive'] ?? false;

    final titleFontSize = getResponsiveTitleFontSize(size);
    final artistFontSize = getResponsiveArtistFontSize(size);
    final canOpenArtist = _canOpenArtist(metadata);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 280;
        final isVeryCompact = availableHeight < 200;

        final spacing = isVeryCompact
            ? 2.0
            : isCompact
            ? 4.0
            : 8.0;
        final iconScale = isVeryCompact
            ? 0.65
            : isCompact
            ? 0.75
            : 1.0;
        final fontScale = isCompact ? 0.9 : 1.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCompact && !isLive) NowPlayingLyricLine(metadata: metadata),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 24,
                vertical: spacing,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () =>
                              _copyNowPlayingSong(context, metadata),
                          child: MarqueeTextWidget(
                            text: metadata.title,
                            fontColor: Daylight.ink,
                            fontSize: titleFontSize * fontScale,
                            fontWeight: FontWeight.w700,
                            fontFamily: Daylight.displayFamily,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SongQuickActions(metadata: metadata),
                    ],
                  ),
                  SizedBox(height: spacing),
                  if (metadata.artist != null && metadata.artist!.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canOpenArtist
                          ? () => _openArtistPage(context, metadata)
                          : null,
                      onLongPress: () => _copyNowPlayingSong(context, metadata),
                      child: MarqueeTextWidget(
                        text: metadata.artist!,
                        fontColor: Daylight.muted,
                        fontSize: artistFontSize * fontScale,
                        fontWeight: FontWeight.w500,
                        fontFamily: Daylight.uiFamily,
                      ),
                    ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 400 : constraints.maxWidth,
              ),
              child: const PositionSlider(),
            ),
            SizedBox(height: spacing),
            PlayerControlButtons(
              metadata: metadata,
              iconSize: adjustedIconSize * iconScale,
              miniIconSize: adjustedMiniIconSize * iconScale,
            ),
          ],
        );
      },
    );
  }

  bool _canOpenArtist(MediaItem metadata) {
    final info = _extractArtistInfo(metadata);
    return !offlineMode.value &&
        (info.artist.isNotEmpty ||
            info.artistId.isNotEmpty ||
            info.sourceSongId.isNotEmpty);
  }

  void _openArtistPage(BuildContext context, MediaItem metadata) {
    final info = _extractArtistInfo(metadata);
    final lookup = info.artistId.isNotEmpty
        ? info.artistId
        : info.artist.isNotEmpty
        ? info.artist
        : info.sourceSongId;

    if (lookup.isEmpty) return;

    final router = GoRouter.of(context);
    final artistPath = NavigationManager.artistPath(context, lookup);
    final artistData = {
      'ytid': info.artistId.isNotEmpty ? info.artistId : lookup,
      if (info.artist.isNotEmpty) 'title': info.artist,
      if (info.sourceSongId.isNotEmpty) 'sourceSongId': info.sourceSongId,
      if (info.videoAuthor.isNotEmpty) 'videoAuthor': info.videoAuthor,
      'source': 'youtube-artist',
      'isArtist': true,
      'list': [],
    };

    Navigator.of(context).pop();
    unawaited(router.push(artistPath, extra: artistData));
  }

  ({String artist, String artistId, String sourceSongId, String videoAuthor})
  _extractArtistInfo(MediaItem metadata) {
    return (
      artist: metadata.artist?.trim() ?? '',
      artistId: metadata.extras?['artistId']?.toString().trim() ?? '',
      sourceSongId: metadata.extras?['ytid']?.toString().trim() ?? '',
      videoAuthor: metadata.extras?['videoAuthor']?.toString().trim() ?? '',
    );
  }
}

Future<void> _copyNowPlayingSong(
  BuildContext context,
  MediaItem metadata,
) async {
  final artist = metadata.artist?.trim();
  final title = metadata.title.trim();
  final text = artist == null || artist.isEmpty ? title : '$artist - $title';
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showToast(context, context.l10n!.songInfoCopied);
}

class PlayerControlButtons extends StatelessWidget {
  const PlayerControlButtons({
    super.key,
    required this.metadata,
    required this.iconSize,
    required this.miniIconSize,
  });
  final MediaItem metadata;
  final double iconSize;
  final double miniIconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveIconSize = screenWidth < 360 ? iconSize * 0.85 : iconSize;
    final responsiveMiniIconSize = screenWidth < 360
        ? miniIconSize * 0.85
        : miniIconSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isTight = maxWidth < 360;
        final isUltraTight = maxWidth < 320;

        final horizontalPadding = isUltraTight
            ? 10.0
            : isTight
            ? 14.0
            : 20.0;
        final buttonSpacing = isUltraTight
            ? 6.0
            : isTight
            ? 10.0
            : screenWidth < 360
            ? 8.0
            : 16.0;
        final minButtonSize = isUltraTight
            ? 38.0
            : isTight
            ? 42.0
            : 46.0;
        final buttonPadding = EdgeInsets.all(
          isUltraTight
              ? 6.0
              : isTight
              ? 8.0
              : 10.0,
        );

        final buttonConstraints = BoxConstraints(
          minWidth: minButtonSize,
          minHeight: minButtonSize,
        );

        final controlIconSize =
            responsiveIconSize *
            (isUltraTight
                ? 0.75
                : isTight
                ? 0.85
                : 0.92);
        final miniControlSize =
            responsiveMiniIconSize *
            (isUltraTight
                ? 0.8
                : isTight
                ? 0.9
                : 1.0);
        final playPadding = EdgeInsets.all(
          responsiveIconSize *
              (isUltraTight
                  ? 0.30
                  : isTight
                  ? 0.36
                  : 0.45),
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: <Widget>[
              _buildShuffleButton(
                context,
                colorScheme,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
              SizedBox(width: buttonSpacing),
              Expanded(
                child: Center(
                  child: _PlaybackControlsRow(
                    colorScheme: colorScheme,
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    buttonSpacing: buttonSpacing,
                    minButtonSize: minButtonSize,
                    playPadding: playPadding,
                  ),
                ),
              ),
              SizedBox(width: buttonSpacing),
              _buildRepeatButton(
                context,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShuffleButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: shuffleNotifier,
      builder: (_, value, __) {
        return IconButton(
          icon: Icon(
            value
                ? FluentIcons.arrow_shuffle_24_filled
                : FluentIcons.arrow_shuffle_24_regular,
            color: value ? Daylight.cobalt : Daylight.muted,
          ),
          tooltip: context.l10n!.shuffle,
          iconSize: size,
          constraints: buttonConstraints,
          padding: buttonPadding,
          style: IconButton.styleFrom(
            backgroundColor: value ? Daylight.cobaltSoft : Colors.transparent,
            shape: const CircleBorder(),
          ),
          onPressed: () {
            audioHandler.setShuffleMode(
              value
                  ? AudioServiceShuffleMode.none
                  : AudioServiceShuffleMode.all,
            );
          },
        );
      },
    );
  }

  /// Repeat owns the far-right transport slot. Tapping cycles
  /// off → all → one with a filled, accented state while active.
  Widget _buildRepeatButton(
    BuildContext context,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return ValueListenableBuilder<AudioServiceRepeatMode>(
      valueListenable: repeatNotifier,
      builder: (_, mode, __) {
        final isActive = mode != AudioServiceRepeatMode.none;
        final isOne = mode == AudioServiceRepeatMode.one;
        return IconButton(
          icon: Icon(
            isOne
                ? FluentIcons.arrow_repeat_1_24_filled
                : isActive
                ? FluentIcons.arrow_repeat_all_24_filled
                : FluentIcons.arrow_repeat_all_24_regular,
            color: isActive ? Daylight.cobalt : Daylight.muted,
          ),
          tooltip: context.l10n!.repeat,
          iconSize: size,
          constraints: buttonConstraints,
          padding: buttonPadding,
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? Daylight.cobaltSoft
                : Colors.transparent,
            shape: const CircleBorder(),
          ),
          onPressed: () {
            final next = switch (mode) {
              AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
              AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
              _ => AudioServiceRepeatMode.none,
            };
            repeatNotifier.value = next;
            unawaited(audioHandler.setRepeatMode(next));
          },
        );
      },
    );
  }
}

class _PlaybackControlsRow extends StatelessWidget {
  const _PlaybackControlsRow({
    required this.colorScheme,
    required this.buttonConstraints,
    required this.buttonPadding,
    required this.controlIconSize,
    required this.buttonSpacing,
    required this.minButtonSize,
    required this.playPadding,
  });

  final ColorScheme colorScheme;
  final BoxConstraints buttonConstraints;
  final EdgeInsets buttonPadding;
  final double controlIconSize;
  final double buttonSpacing;
  final double minButtonSize;
  final EdgeInsets playPadding;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MediaItem>>(
      stream: audioHandler.queue,
      builder: (context, snapshot) {
        return ValueListenableBuilder<AudioServiceRepeatMode>(
          valueListenable: repeatNotifier,
          builder: (_, repeatMode, __) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlaybackControlButton(
                    icon: FluentIcons.previous_24_regular,
                    isEnabled:
                        audioHandler.hasPrevious ||
                        repeatMode != AudioServiceRepeatMode.none,
                    tooltip: context.l10n!.skipToPrevious,
                    onPressed: () => audioHandler.skipToPrevious(),
                    colorScheme: colorScheme,
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    minButtonSize: minButtonSize,
                  ),
                  SizedBox(width: buttonSpacing),
                  Container(
                    width: minButtonSize + 18,
                    height: minButtonSize + 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: Daylight.cobaltGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Daylight.cobaltDeep.withValues(alpha: 0.3),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: PlaybackIconButton(
                      iconColor: Daylight.onAccent,
                      backgroundColor: Colors.transparent,
                      iconSize: controlIconSize * 0.62,
                    ),
                  ),
                  SizedBox(width: buttonSpacing),
                  _PlaybackControlButton(
                    icon: FluentIcons.next_24_regular,
                    isEnabled:
                        audioHandler.hasNext ||
                        repeatMode == AudioServiceRepeatMode.one,
                    tooltip: context.l10n!.skipToNext,
                    onPressed: () => repeatMode == AudioServiceRepeatMode.one
                        ? audioHandler.playAgain()
                        : audioHandler.skipToNext(),
                    colorScheme: colorScheme,
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    minButtonSize: minButtonSize,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PlaybackControlButton extends StatelessWidget {
  const _PlaybackControlButton({
    required this.icon,
    required this.isEnabled,
    required this.tooltip,
    required this.onPressed,
    required this.colorScheme,
    required this.buttonConstraints,
    required this.buttonPadding,
    required this.controlIconSize,
    required this.minButtonSize,
  });

  final IconData icon;
  final bool isEnabled;
  final String tooltip;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final BoxConstraints buttonConstraints;
  final EdgeInsets buttonPadding;
  final double controlIconSize;
  final double minButtonSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        color: isEnabled ? Daylight.ink : Daylight.ink.withValues(alpha: 0.24),
      ),
      tooltip: tooltip,
      constraints: buttonConstraints,
      iconSize: controlIconSize * 0.65,
      onPressed: isEnabled ? onPressed : null,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shape: const CircleBorder(),
        padding: buttonPadding,
        minimumSize: Size(minButtonSize, minButtonSize),
      ),
    );
  }
}
