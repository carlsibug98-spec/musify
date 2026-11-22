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
import 'package:musify/theme/daylight.dart';

void main() {
  test('dark tokens are black-first', () {
    brightness = Brightness.dark;
    expect(Daylight.groundTop, const Color(0xFF121212));
    expect(Daylight.groundBottom, const Color(0xFF000000));
    expect(Daylight.ink, const Color(0xFFFFFFFF));
    expect(Daylight.card, const Color(0xFF181818));
  });

  test('onColor picks the higher-contrast foreground', () {
    expect(Daylight.onColor(const Color(0xFF1ED760)), const Color(0xFF16181D));
    expect(Daylight.onColor(const Color(0xFF2743E8)), Colors.white);
    expect(Daylight.onColor(const Color(0xFFF2F2F2)), const Color(0xFF16181D));
  });
}
