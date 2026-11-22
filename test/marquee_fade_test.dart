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
import 'package:musify/widgets/marquee.dart';

Widget _host(Widget child, {double width = 120}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('overflowing marquee fades its clipped edge', (tester) async {
    await tester.pumpWidget(
      _host(
        const MarqueeWidget(
          animationDuration: Duration(milliseconds: 200),
          pauseDuration: Duration(milliseconds: 10),
          backDuration: Duration(milliseconds: 100),
          child: Text('A very long song title that cannot fit'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a title that fits stays fully opaque', (tester) async {
    await tester.pumpWidget(
      _host(
        const MarqueeWidget(
          child: Text('Short'),
        ),
        width: 200,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ShaderMask), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
