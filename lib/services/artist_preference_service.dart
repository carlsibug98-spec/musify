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

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musify/services/data_manager.dart' show addOrUpdateData;

/// A chosen favourite artist. The shape mirrors the fields REA recovered from
/// Spotify's onboarding quiz (`ArtistDisplayInfo`: a spotlight URI plus
/// artwork URLs): here the real Musify artist id, name and thumbnail.
class PreferredArtist {
  const PreferredArtist({
    required this.id,
    required this.name,
    this.image,
  });

  final String id;
  final String name;
  final String? image;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'image': image,
  };

  factory PreferredArtist.fromMap(Map m) => PreferredArtist(
    id: m['id']?.toString() ?? '',
    name: m['name']?.toString() ?? '',
    image: m['image']?.toString(),
  );
}

/// Selected artist seeds. Spotify's `CompleteQuizRequest` submits the user's
/// answers and its curation service builds the whole home feed from them; we
/// do the same locally — these seeds drive [getRecommendedSongs] and the
/// Home "Made for you" shelves.
final preferredArtists = ValueNotifier<List<PreferredArtist>>(
  _readPreferredArtists(),
);

List<PreferredArtist> _readPreferredArtists() {
  final raw = Hive.box('settings').get('preferredArtists');
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => PreferredArtist.fromMap(Map<String, dynamic>.from(m)))
      .where((a) => a.id.isNotEmpty || a.name.isNotEmpty)
      .toList();
}

bool get hasArtistPreferences => preferredArtists.value.isNotEmpty;

Future<void> setPreferredArtists(List<PreferredArtist> artists) async {
  preferredArtists.value = artists;
  await addOrUpdateData<List>(
    'settings',
    'preferredArtists',
    artists.map((a) => a.toMap()).toList(),
  );
}

Future<void> clearPreferredArtists() => setPreferredArtists(const []);

bool isPreferredArtist(String id) =>
    preferredArtists.value.any((a) => a.id == id);
