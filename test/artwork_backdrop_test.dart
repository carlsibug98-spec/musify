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

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/artwork_palette.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/theme/daylight.dart';

void main() {
  test('missing tint falls back to the neutral top', () {
    brightness = Brightness.dark;
    expect(artworkBackdropTop(null), Daylight.groundTop);
  });

  test('bright covers are darkened below the contrast ceiling', () {
    brightness = Brightness.dark;
    final top = artworkBackdropTop(const Color(0xFFFFD400));
    expect(top.computeLuminance(), lessThanOrEqualTo(0.06));
  });

  test('light mode ignores the tint', () {
    brightness = Brightness.light;
    expect(artworkBackdropTop(const Color(0xFFFF00AA)), Daylight.groundTop);
  });
}
