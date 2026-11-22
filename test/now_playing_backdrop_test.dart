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
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/widgets/now_playing/now_playing_backdrop.dart';

void main() {
  testWidgets('renders its child when artwork is missing', (tester) async {
    brightness = Brightness.dark;
    await tester.pumpWidget(
      const MaterialApp(
        home: NowPlayingBackdrop(
          metadata: MediaItem(id: '1', title: 'Test'),
          child: Text('player'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);
  });
}
