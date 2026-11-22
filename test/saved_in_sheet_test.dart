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

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/localization/app_localizations.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/widgets/now_playing/saved_in_sheet.dart';

void main() {
  late Directory temporaryDirectory;

  setUpAll(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'musify_saved_in_test',
    );
    Hive.init(temporaryDirectory.path);
    await Hive.openBox('user');
    await Hive.openBox('userNoBackup');
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  testWidgets('opens a modal sheet with the app Material localizations', (
    tester,
  ) async {
    const metadata = MediaItem(
      id: 'https://www.youtube.com/watch?v=demo',
      title: 'Demo song',
      artist: 'Demo artist',
      extras: {'ytid': 'demo'},
    );
    userLikedSongsList.value = [
      {'ytid': 'demo'},
    ];
    addTearDown(() => userLikedSongsList.value = []);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => SavedInSheet.show(context, metadata),
              child: const Text('open saved in'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open saved in'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Saved in'), findsOneWidget);
    expect(find.text('Demo song'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);
  });
}
