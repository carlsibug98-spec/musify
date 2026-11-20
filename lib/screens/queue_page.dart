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
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/queue_list_view.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StreamBuilder<List<Map>>(
              stream: audioHandler.queueAsMapStream,
              builder: (context, snapshot) {
                final queue = snapshot.data ?? [];
                return DaylightAppBar(
                  overline: context.l10n!.queue,
                  showBack: true,
                  onBack: () => context.pop(),
                  actions: [
                    if (queue.length > 1)
                      DaylightCircleButton(
                        icon: FluentIcons.arrow_shuffle_24_filled,
                        tooltip: context.l10n!.shuffle,
                        iconSize: 16,
                        onTap: audioHandler.shuffleQueue,
                      ),
                    if (queue.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      DaylightCircleButton(
                        icon: FluentIcons.dismiss_24_regular,
                        tooltip: context.l10n!.clear,
                        iconSize: 16,
                        color: Daylight.danger,
                        onTap: () => _confirmClear(context),
                      ),
                    ],
                  ],
                );
              },
            ),
            const Expanded(child: QueueWidget(showHeader: false)),
          ],
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
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
        },
      ),
    );
  }
}
