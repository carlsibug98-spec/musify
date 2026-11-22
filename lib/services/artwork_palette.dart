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

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/daylight.dart';

/// Extracts a stable, muted colour from a song's artwork.
///
/// Spotify tints its floating mini-player with the current cover. We do the
/// same without another dependency: decode the already-cached artwork at full
/// size, average its saturated mid-tones, then clamp the result to a surface
/// lightness that keeps white/dark text readable.
Future<Color?> songArtworkTint(MediaItem metadata) {
  final artUri = metadata.artUri;
  if (artUri == null || artUri.toString().isEmpty) return Future.value();

  return _tintCache.putIfAbsent(
    artUri.toString(),
    () => _extractTint(metadata),
  );
}

final _tintCache = <String, Future<Color?>>{};

Future<Color?> _extractTint(MediaItem metadata) async {
  ImageStream? stream;
  ImageStreamListener? listener;
  ui.Image? image;

  try {
    final ImageProvider provider;
    if (metadata.artUri!.scheme == 'file') {
      final path = metadata.extras?['artWorkPath']?.toString() ?? '';
      if (path.isEmpty) return null;
      provider = FileImage(File(path));
    } else {
      provider = CachedNetworkImageProvider(metadata.artUri.toString());
    }

    final completer = Completer<ui.Image>();
    stream = provider.resolve(ImageConfiguration.empty);
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (error, _) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    );
    stream.addListener(listener);
    image = await completer.future.timeout(const Duration(seconds: 8));

    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    final bytes = data.buffer.asUint8List();
    var red = 0.0;
    var green = 0.0;
    var blue = 0.0;
    var weight = 0.0;

    for (var i = 0; i + 3 < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      final maxChannel = math.max(r, math.max(g, b));
      final minChannel = math.min(r, math.min(g, b));

      // Skip near-black and near-white pixels: they only desaturate the tint.
      if (maxChannel < 28 || minChannel > 232) continue;

      final saturation = (maxChannel - minChannel) / maxChannel;
      final pixelWeight = 0.12 + saturation;
      red += r * pixelWeight;
      green += g * pixelWeight;
      blue += b * pixelWeight;
      weight += pixelWeight;
    }

    if (weight == 0) return null;
    return Color.fromARGB(
      255,
      (red / weight).round(),
      (green / weight).round(),
      (blue / weight).round(),
    );
  } catch (_) {
    return null;
  } finally {
    if (stream != null && listener != null) stream.removeListener(listener);
    image?.dispose();
  }
}

/// Blends an artwork tint into a card surface while keeping contrast.
Color artworkTintedSurface(Color? tint) {
  if (tint == null) return Daylight.card;

  final hsl = HSLColor.fromColor(tint);
  final isDark = Daylight.isDark;
  final tuned = hsl
      .withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0))
      .withLightness(isDark ? 0.24 : 0.76)
      .toColor();

  return Color.alphaBlend(
    tuned.withValues(alpha: isDark ? 0.55 : 0.22),
    Daylight.card,
  );
}

/// Top colour of the full-player backdrop. The tint is clamped until its
/// relative luminance is at most 0.06, which keeps white text at >= 4.5:1
/// even when the cover is a bright yellow or white.
Color artworkBackdropTop(Color? tint) {
  if (!Daylight.isDark || tint == null) return Daylight.groundTop;

  final hsl = HSLColor.fromColor(tint);
  var tuned = hsl
      .withSaturation((hsl.saturation * 0.72).clamp(0.0, 1.0))
      .withLightness(0.20)
      .toColor();

  var guard = 0;
  while (tuned.computeLuminance() > 0.06 && guard < 24) {
    tuned = Color.lerp(tuned, const Color(0xFF000000), 0.14)!;
    guard++;
  }
  return tuned;
}

/// Bottom colour of the full-player backdrop.
Color artworkBackdropBottom() =>
    Daylight.isDark ? Daylight.groundBottom : Daylight.ground;
