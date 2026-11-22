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

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/widgets/profile_stat.dart';

void main() {
  test('profile counts stay compact', () {
    expect(profileCountLabel(0), '0');
    expect(profileCountLabel(999), '999');
    expect(profileCountLabel(1200), '1.2k');
    expect(profileCountLabel(15400), '15.4k');
  });

  testWidgets('a stat fits a narrow tile', (tester) async {
    brightness = Brightness.dark;
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 90,
          child: ProfileStat(label: 'Liked songs', value: 12500),
        ),
      ),
    );
    expect(find.text('12.5k'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
