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

/// A single lyric line. [time] is null for unsynchronised text.
class LyricsLine {
  const LyricsLine({required this.text, this.time});

  final String text;
  final Duration? time;
}

/// Lyrics for one song, optionally with per-line timestamps (LRC).
class SongLyrics {
  const SongLyrics({required this.plain, this.timed = const []});

  /// The full plain-text lyrics.
  final String plain;

  /// Timestamped lines when a synced source was available.
  final List<LyricsLine> timed;

  bool get isSynced => timed.length > 1;

  /// The plain text split into non-empty lines, timestamps removed.
  List<String> get plainLines => plain
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}
