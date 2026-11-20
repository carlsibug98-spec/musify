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
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/now_playing/sleep_timer_dialog.dart';
import 'package:share_plus/share_plus.dart';

/// The quiet utility strip between the transport and the lyrics preview:
/// sleep timer on the left, share and queue on the right.
class BottomActionsRow extends StatelessWidget {
  const BottomActionsRow({
    super.key,
    required this.iconSize,
    required this.metadata,
  });

  final double iconSize;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          _buildSleepTimerButton(context),
          const Spacer(),
          _buildIconButton(
            context,
            icon: FluentIcons.share_24_regular,
            tooltip: context.l10n!.share,
            onPressed: _share,
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            context,
            icon: FluentIcons.apps_list_24_regular,
            tooltip: context.l10n!.queue,
            onPressed: () => context.push('/queue'),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: iconSize, color: Daylight.ink),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    );
  }

  Widget _buildSleepTimerButton(BuildContext context) {
    return ValueListenableBuilder<Duration?>(
      valueListenable: sleepTimerNotifier,
      builder: (_, remaining, __) {
        final isActive = remaining != null;
        return IconButton(
          icon: Icon(
            isActive
                ? FluentIcons.timer_24_filled
                : FluentIcons.timer_24_regular,
            size: iconSize,
            color: isActive ? Daylight.cobalt : Daylight.muted,
          ),
          tooltip: context.l10n!.sleepTimer,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? Daylight.cobaltSoft
                : Colors.transparent,
            shape: const CircleBorder(),
          ),
          onPressed: () {
            if (isActive) {
              audioHandler.cancelSleepTimer();
              sleepTimerNotifier.value = null;
              showToast(
                context,
                context.l10n!.sleepTimerCancelled,
                duration: const Duration(seconds: 1, milliseconds: 500),
              );
            } else {
              showSleepTimerDialog(context);
            }
          },
        );
      },
    );
  }

  void _share() {
    final artist = metadata.artist?.trim();
    final text = artist == null || artist.isEmpty
        ? metadata.title
        : '$artist - ${metadata.title}';
    unawaited(SharePlus.instance.share(ShareParams(text: text)));
  }
}
