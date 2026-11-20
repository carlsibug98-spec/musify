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
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/now_playing/bottom_actions_row.dart';
import 'package:musify/widgets/now_playing/lyrics_preview_card.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import 'package:musify/widgets/now_playing/now_playing_controls.dart';
import 'package:musify/widgets/overflow_menu_button.dart';
import 'package:musify/widgets/popup_menu_item.dart';
import 'package:musify/widgets/queue_list_view.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800 && size.height > 600;
    final screenWidth = size.width;
    final baseIconSize = screenWidth < 360
        ? 36.0
        : screenWidth < 400
        ? 40.0
        : 44.0;
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            if (snapshot.data == null || !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            final metadata = snapshot.data!;
            return Column(
              children: [
                _buildAppBar(context, metadata),
                Expanded(
                  child: isLargeScreen
                      ? _DesktopLayout(
                          metadata: metadata,
                          size: size,
                          adjustedIconSize: baseIconSize,
                          adjustedMiniIconSize: miniIconSize,
                        )
                      : _MobileLayout(
                          metadata: metadata,
                          size: size,
                          adjustedIconSize: baseIconSize,
                          adjustedMiniIconSize: miniIconSize,
                          isLargeScreen: isLargeScreen,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, MediaItem metadata) {
    final colorScheme = Theme.of(context).colorScheme;
    final album = metadata.album?.trim() ?? '';
    final subtitle = album.isNotEmpty
        ? album
        : (metadata.artist?.trim().isNotEmpty ?? false)
        ? metadata.artist!.trim()
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Row(
        children: [
          DaylightCircleButton(
            icon: FluentIcons.chevron_down_24_regular,
            tooltip: context.l10n!.close,
            iconSize: 19,
            onTap: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n!.nowPlaying,
                    style: Daylight.ui(
                      9,
                      color: Daylight.muted,
                      weight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Daylight.display(
                        13,
                        color: Daylight.ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          OverflowMenuButton<String>(
            iconSize: 18,
            color: Daylight.ink,
            onSelected: (value) =>
                _handleMenuAction(context, metadata, value),
            itemBuilder: (context) => [
              if (!(metadata.extras?['isLive'] ?? false))
                buildPopupMenuItem<String>(
                  value: 'download',
                  icon: isSongAlreadyOffline(metadata.extras?['ytid'])
                      ? FluentIcons.arrow_download_24_filled
                      : FluentIcons.arrow_download_24_regular,
                  label: isSongAlreadyOffline(metadata.extras?['ytid'])
                      ? context.l10n!.removeOffline
                      : context.l10n!.makeOffline,
                  colorScheme: colorScheme,
                ),
              buildPopupMenuItem<String>(
                value: 'copy',
                icon: FluentIcons.copy_24_regular,
                label: context.l10n!.copySongInfo,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, MediaItem metadata, String value) {
    switch (value) {
      case 'download':
        unawaited(_toggleOffline(context, metadata));
        break;
      case 'copy':
        final artist = metadata.artist?.trim();
        final text = artist == null || artist.isEmpty
            ? metadata.title
            : '$artist - ${metadata.title}';
        unawaited(Clipboard.setData(ClipboardData(text: text)));
        if (context.mounted) {
          showToast(context, context.l10n!.songInfoCopied);
        }
        break;
    }
  }

  Future<void> _toggleOffline(BuildContext context, MediaItem metadata) async {
    final id = metadata.extras?['ytid']?.toString();
    if (id == null || id.isEmpty) return;

    final wasOffline = isSongAlreadyOffline(id);
    final bool success;
    try {
      success = wasOffline
          ? await OfflinePlaylistService().removeSongFromOfflineAndResync(id)
          : await makeSongOffline(mediaItemToMap(metadata));
    } catch (_) {
      if (context.mounted) showToast(context, context.l10n!.error);
      return;
    }

    if (!context.mounted) return;
    showToast(
      context,
      success
          ? (wasOffline
                ? context.l10n!.songRemovedFromOffline
                : context.l10n!.songAddedToOffline)
          : context.l10n!.error,
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: NowPlayingArtwork(size: size, metadata: metadata),
                  ),
                ),
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    flex: 4,
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  iconSize: adjustedMiniIconSize,
                  metadata: metadata,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        const Expanded(child: QueueWidget()),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;

  @override
  Widget build(BuildContext context) {
    final isLandscape = size.width > size.height;

    if (isLandscape) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NowPlayingArtwork(size: size, metadata: metadata),
          if (!isLive) ...[
            const SizedBox(height: 4),
            NowPlayingControls(
              size: size,
              audioId: metadata.extras?['ytid'],
              adjustedIconSize: adjustedIconSize,
              adjustedMiniIconSize: adjustedMiniIconSize,
              metadata: metadata,
            ),
            const SizedBox(height: 4),
            BottomActionsRow(
              iconSize: adjustedMiniIconSize,
              metadata: metadata,
            ),
            const SizedBox(height: 6),
            LyricsPreviewCard(metadata: metadata),
            const SizedBox(height: 2),
          ] else
            BottomActionsRow(
              iconSize: adjustedMiniIconSize,
              metadata: metadata,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: NowPlayingArtwork(size: size, metadata: metadata),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isLive)
                  NowPlayingControls(
                    size: size,
                    audioId: metadata.extras?['ytid'],
                    adjustedIconSize: adjustedIconSize,
                    adjustedMiniIconSize: adjustedMiniIconSize,
                    metadata: metadata,
                  ),
                BottomActionsRow(
                  iconSize: adjustedMiniIconSize,
                  metadata: metadata,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
