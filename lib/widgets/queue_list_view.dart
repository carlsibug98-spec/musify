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
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/no_artwork_cube.dart';

class QueueWidget extends StatefulWidget {
  const QueueWidget({
    super.key,
    this.isBottomSheet = false,
    this.showHeader = true,
  });

  final bool isBottomSheet;
  final bool showHeader;

  @override
  State<QueueWidget> createState() => _QueueWidgetState();
}

class _QueueWidgetState extends State<QueueWidget> {
  List<Map> _queue = [];
  late StreamSubscription<List<Map>> _subscription;
  late StreamSubscription<MediaItem?> _mediaSubscription;
  bool _isDismissing = false;
  bool _hasScrolledToInitial = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _subscription = audioHandler.queueAsMapStream.listen((queue) {
      if (mounted && !_isDismissing) {
        setState(() {
          _queue = List<Map>.from(queue);
        });
        if (!_hasScrolledToInitial && queue.isNotEmpty) {
          _hasScrolledToInitial = true;
          _scrollToCurrentSong();
        }
      }
    });
    // listen to mediaItem changes UI reflects current song accurately.
    _mediaSubscription = audioHandler.mediaItem
        .distinct((prev, next) => prev?.id == next?.id)
        .listen((_) {
          if (mounted && !_isDismissing) setState(() {});
        });
  }

  void _scrollToCurrentSong() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final currentIndex = audioHandler.currentQueueIndex;
      if (currentIndex <= 0) return;
      const estimatedItemHeight = 68.0;
      const topPadding = 4.0;
      final targetOffset = currentIndex * estimatedItemHeight + topPadding;
      final clampedOffset = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _mediaSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentIndex = audioHandler.currentQueueIndex;

    if (widget.isBottomSheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, colorScheme, textTheme, compact: true),
          _buildBottomSheetContent(context, colorScheme, currentIndex),
        ],
      );
    }

    return Column(
      children: [
        if (widget.showHeader) ...[
          _buildHeader(context, colorScheme, textTheme, compact: false),
          Divider(color: Daylight.line, height: 1, thickness: 1),
        ],
        Expanded(
          child: _queue.isEmpty
              ? _buildEmptyState(context, colorScheme, textTheme)
              : _buildList(context, colorScheme, currentIndex),
        ),
      ],
    );
  }

  Future<void> _shuffleQueue() async {
    await audioHandler.shuffleQueue();
    if (mounted && _scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _confirmClearQueue(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => ConfirmationDialog(
        confirmationMessage: context.l10n!.clearQueueQuestion,
        submitMessage: context.l10n!.clear,
        isDangerous: true,
        onCancel: () => Navigator.pop(context),
        onSubmit: () {
          Navigator.pop(context);
          audioHandler.clearQueue();
          if (widget.isBottomSheet) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required bool compact,
  }) {
    return Padding(
      padding: compact
          ? const EdgeInsets.only(left: 10, right: 8, bottom: 12)
          : const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            decoration: BoxDecoration(
              color: Daylight.cobaltSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.apps_list_24_regular,
              color: Daylight.cobalt,
              size: compact ? 18.0 : 20.0,
            ),
          ),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n!.queue,
                  style: Daylight.display(compact ? 18 : 22, height: 1.05),
                ),
                if (_queue.isNotEmpty)
                  Text(
                    '${_queue.length} ${context.l10n!.songs.toLowerCase()}',
                    style: Daylight.ui(
                      compact ? 11 : 11.5,
                      color: Daylight.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (_queue.length > 1)
            DaylightCircleButton(
              onTap: _shuffleQueue,
              icon: FluentIcons.arrow_shuffle_24_filled,
              tooltip: context.l10n!.shuffle,
              size: 36,
              iconSize: 16,
              color: Daylight.cobalt,
            ),
          if (_queue.isNotEmpty) ...[
            const SizedBox(width: 8),
            DaylightCircleButton(
              onTap: () => _confirmClearQueue(context),
              icon: FluentIcons.dismiss_24_regular,
              tooltip: context.l10n!.clear,
              size: 36,
              iconSize: 16,
              color: Daylight.danger,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent(
    BuildContext context,
    ColorScheme colorScheme,
    int currentIndex,
  ) {
    if (_queue.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          context.l10n!.noSongsInQueue,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
      );
    }
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.52,
      child: _buildList(context, colorScheme, currentIndex, closeOnTap: true),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                FluentIcons.music_note_1_24_regular,
                color: colorScheme.onSurfaceVariant,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n!.noSongsInQueue,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _queueEntryKey(Map song, int index) {
    final entryId = song['queueEntryId']?.toString() ?? song['ytid'];
    return '${entryId}_$index';
  }

  Widget _buildList(
    BuildContext context,
    ColorScheme colorScheme,
    int currentIndex, {
    bool closeOnTap = false,
  }) {
    return ReorderableListView.builder(
      scrollController: _scrollController,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(top: 4, bottom: 24, left: 8, right: 8),
      itemCount: _queue.length,
      onReorderItem: (oldIndex, newIndex) {
        final movingId =
            _queue[oldIndex]['queueEntryId']?.toString() ??
            'legacy_${_queue[oldIndex]['ytid']}_$oldIndex';

        setState(() {
          final item = _queue.removeAt(oldIndex);
          var insertIndex = newIndex;
          if (insertIndex < 0) insertIndex = 0;
          if (insertIndex > _queue.length) insertIndex = _queue.length;
          _queue.insert(insertIndex, item);
        });

        final actualIndex = _queue.indexWhere(
          (item) => item['queueEntryId']?.toString() == movingId,
        );
        audioHandler.reorderQueueById(movingId, actualIndex);
      },
      proxyDecorator: (child, index, animation) => Material(
        elevation: 8,
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        shadowColor: colorScheme.shadow.withValues(alpha: 0.35),
        child: child,
      ),
      itemBuilder: (context, index) {
        final song = _queue[index];
        final isCurrentSong = index == currentIndex;
        final queueEntryId = _queueEntryKey(song, index);
        return QueueTile(
          key: ValueKey(queueEntryId),
          song: song,
          index: index,
          queueEntryId: queueEntryId,
          isCurrentSong: isCurrentSong,
          colorScheme: colorScheme,
          onTap: () {
            audioHandler.skipToSong(index);
            if (closeOnTap) Navigator.pop(context);
          },
          confirmDismiss: (_) async {
            _isDismissing = true;
            return true;
          },
          onDismissed: () {
            final actualIndex = _queue.indexWhere(
              (item) =>
                  _queueEntryKey(item, _queue.indexOf(item)) == queueEntryId,
            );
            if (actualIndex == -1) return;
            setState(() {
              _isDismissing = false;
              _queue.removeAt(actualIndex);
            });
            audioHandler.removeFromQueue(actualIndex);
          },
        );
      },
    );
  }
}

class QueueTile extends StatelessWidget {
  const QueueTile({
    super.key,
    required this.song,
    required this.index,
    required this.queueEntryId,
    required this.isCurrentSong,
    required this.colorScheme,
    required this.onTap,
    required this.onDismissed,
    this.confirmDismiss,
  });

  final Map song;
  final int index;
  final String queueEntryId;
  final bool isCurrentSong;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final Future<bool?> Function(DismissDirection)? confirmDismiss;

  static const double _artSize = 46;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(queueEntryId),
      confirmDismiss: confirmDismiss,
      onDismissed: (_) => onDismissed(),
      background: _DismissBackground(
        alignment: Alignment.centerLeft,
        colorScheme: colorScheme,
      ),
      secondaryBackground: _DismissBackground(
        alignment: Alignment.centerRight,
        colorScheme: colorScheme,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isCurrentSong ? Daylight.cobaltWash : Daylight.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrentSong
                  ? Daylight.cobalt.withValues(alpha: 0.18)
                  : Daylight.ink.withValues(alpha: 0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Daylight.ink.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
                spreadRadius: -5,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              splashColor: Colors.transparent,
              highlightColor: Daylight.cobalt.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _ArtworkThumbnail(
                      song: song,
                      size: _artSize,
                      radius: _artSize / 2,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song['title']?.toString() ?? '',
                            style: Daylight.ui(
                              13,
                              color: isCurrentSong
                                  ? Daylight.cobaltDeep
                                  : Daylight.ink,
                              weight: isCurrentSong
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song['artist']?.toString() ?? '',
                            style: Daylight.ui(
                              10,
                              color: Daylight.muted,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCurrentSong) ...[
                      Icon(
                        FluentIcons.music_note_2_24_regular,
                        color: Daylight.cobalt,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                    ],
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
                        child: Icon(
                          FluentIcons.re_order_24_regular,
                          color: Daylight.faint,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkThumbnail extends StatelessWidget {
  const _ArtworkThumbnail({
    required this.song,
    required this.size,
    required this.radius,
    required this.colorScheme,
  });

  final Map song;
  final double size;
  final double radius;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final artworkPath = song['artworkPath'] as String?;
    if (artworkPath != null && artworkPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          File(artworkPath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    final imageUrl = song['lowResImage']?.toString() ?? '';
    if (imageUrl.isEmpty) return _fallback();
    // Low-res YouTube 'default.jpg' thumbnails ship with baked-in black
    // letterbox bars, so BoxFit.cover keeps them visible. Detect that case and
    // stretch over the bars with fill + centerSlice, otherwise crop with cover —
    // matching SongBar so the queue frames covers the same way (no black bars).
    final isImageSmall = imageUrl.contains('default.jpg');
    return CachedNetworkImage(
      width: size,
      height: size,
      imageUrl: imageUrl,
      imageBuilder: (_, imageProvider) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image(
          image: imageProvider,
          width: size,
          height: size,
          fit: isImageSmall ? BoxFit.fill : BoxFit.cover,
          centerSlice: isImageSmall ? const Rect.fromLTRB(1, 1, 1, 1) : null,
        ),
      ),
      placeholder: (_, __) => _loading(),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() => NullArtworkWidget(
    size: size,
    borderRadius: radius,
    iconSize: size * 0.45,
  );

  Widget _loading() => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({
    required this.alignment,
    required this.colorScheme,
  });

  final Alignment alignment;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        FluentIcons.delete_24_regular,
        color: colorScheme.onErrorContainer,
        size: 22,
      ),
    );
  }
}
