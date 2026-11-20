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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';

/// Daylight-styled sleep-timer dialog shared by the player controls and the
/// radio page.
Future<void> showSleepTimerDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) {
      final duration = sleepTimerNotifier.value ?? Duration.zero;
      var hours = duration.inMinutes ~/ 60;
      var minutes = duration.inMinutes % 60;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Daylight.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.timer_24_regular, color: Daylight.cobalt),
                const SizedBox(width: 12),
                Text(
                  context.l10n!.sleepTimer,
                  style: Daylight.ui(
                    15,
                    color: Daylight.ink,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n!.selectDuration,
                  style: Daylight.ui(12, color: Daylight.muted),
                ),
                const SizedBox(height: 20),
                _buildTimeSelector(
                  context: context,
                  label: context.l10n!.hours,
                  value: hours,
                  onDecrement: () {
                    if (hours > 0) setState(() => hours--);
                  },
                  onIncrement: () => setState(() => hours++),
                ),
                const SizedBox(height: 12),
                _buildTimeSelector(
                  context: context,
                  label: context.l10n!.minutes,
                  value: minutes,
                  onDecrement: () {
                    if (minutes > 0) setState(() => minutes--);
                  },
                  onIncrement: () {
                    if (minutes < 59) setState(() => minutes++);
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ...[15, 30, 45, 60].map(
                      (mins) => DaylightPill(
                        label: '$mins min',
                        onTap: () => setState(() {
                          hours = mins ~/ 60;
                          minutes = mins % 60;
                        }),
                      ),
                    ),
                    DaylightPill(
                      label: context.l10n!.endOfSong,
                      onTap: () {
                        audioHandler.setSleepTimerEndOfSong();
                        showToast(
                          context,
                          context.l10n!.sleepTimerSet,
                          duration: const Duration(
                            seconds: 1,
                            milliseconds: 500,
                          ),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  context.l10n!.cancel,
                  style: Daylight.ui(12, color: Daylight.muted),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final duration = Duration(hours: hours, minutes: minutes);
                  if (duration.inSeconds > 0) {
                    audioHandler.setSleepTimer(duration);
                    showToast(
                      context,
                      context.l10n!.sleepTimerSet,
                      duration: const Duration(seconds: 1, milliseconds: 500),
                    );
                  }
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Daylight.cobalt,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: Text(context.l10n!.setTimer),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildTimeSelector({
  required BuildContext context,
  required String label,
  required int value,
  required VoidCallback onDecrement,
  required VoidCallback onIncrement,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Daylight.cardTint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Daylight.ui(
            13,
            color: Daylight.ink,
            weight: FontWeight.w600,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                FluentIcons.line_horizontal_1_24_regular,
                size: 17,
                color: Daylight.muted,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              onPressed: onDecrement,
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Daylight.ui(
                  17,
                  color: Daylight.ink,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                FluentIcons.add_24_regular,
                size: 17,
                color: Daylight.cobalt,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    ),
  );
}
