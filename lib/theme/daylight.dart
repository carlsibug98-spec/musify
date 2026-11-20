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

import 'package:material_ui/material_ui.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/app_themes.dart' show brightness;

/// Concept C — "Daylight".
///
/// A cool-grey daylight ground, one accent, circular artwork and floating
/// white cards. Everything visual in the redesign reads from here. The
/// accent starts as cobalt and follows the color picked in Settings.
abstract final class Daylight {
  /// True when the effective app brightness is dark. Every surface token below
  /// switches on this so the whole concept has a real dark appearance.
  static bool get isDark => brightness == Brightness.dark;

  // Ground — light values
  static const _lightGroundTop = Color(0xFFF7F9FC);
  static const _lightGround = Color(0xFFEEF0F5);
  static const _lightGroundBottom = Color(0xFFE8EBF2);

  // Ink — light values
  static const _lightInk = Color(0xFF16181D);
  static const _lightMuted = Color(0xFF5F6673);
  static const _lightFaint = Color(0xFF8A919E);

  // Lines and surfaces — light values
  static const _lightLine = Color(0xFFDDE1E9);
  static const _lightLineStrong = Color(0xFFC4CAD6);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightCardTint = Color(0xFFF1F3F8);
  static const _lightCardTintStrong = Color(0xFFE7EAF2);

  // Ground — dark values (cool charcoal, keeps the same blue-grey family)
  static const _darkGroundTop = Color(0xFF101319);
  static const _darkGround = Color(0xFF0C0E13);
  static const _darkGroundBottom = Color(0xFF080A0E);

  // Ink — dark values
  static const _darkInk = Color(0xFFF4F6FA);
  static const _darkMuted = Color(0xFFA8B0BE);
  static const _darkFaint = Color(0xFF727B8B);

  // Lines and surfaces — dark values
  static const _darkLine = Color(0xFF232935);
  static const _darkLineStrong = Color(0xFF363E4E);
  static const _darkCard = Color(0xFF171B23);
  static const _darkCardTint = Color(0xFF1E232D);
  static const _darkCardTintStrong = Color(0xFF262C38);

  static Color get groundTop => isDark ? _darkGroundTop : _lightGroundTop;
  static Color get ground => isDark ? _darkGround : _lightGround;
  static Color get groundBottom =>
      isDark ? _darkGroundBottom : _lightGroundBottom;

  static Color get ink => isDark ? _darkInk : _lightInk;
  static Color get muted => isDark ? _darkMuted : _lightMuted;
  static Color get faint => isDark ? _darkFaint : _lightFaint;

  static Color get line => isDark ? _darkLine : _lightLine;
  static Color get lineStrong => isDark ? _darkLineStrong : _lightLineStrong;
  static Color get card => isDark ? _darkCard : _lightCard;
  static Color get cardTint => isDark ? _darkCardTint : _lightCardTint;
  static Color get cardTintStrong =>
      isDark ? _darkCardTintStrong : _lightCardTintStrong;

  // Accent ----------------------------------------------------------------

  /// The Daylight accent before the user picks one in Settings.
  static const cobaltBase = Color(0xFF2743E8);

  /// The live accent. While "system color" is enabled the concept's cobalt
  /// stays in place; a swatch or custom RGB color from Settings replaces it.
  static Color get cobalt =>
      useSystemColor.value ? cobaltBase : primaryColorSetting;

  /// Alias used by newer widgets.
  static Color get accent => cobalt;

  static Color _scale(Color color, double lightness) {
    final hsl = HSLColor.fromColor(color);
    final scaled = (hsl.lightness * lightness).clamp(0.14, 0.94);
    final saturation = (hsl.saturation * (lightness < 1 ? 1.06 : 1.0)).clamp(
      0.0,
      1.0,
    );
    return hsl.withLightness(scaled).withSaturation(saturation).toColor();
  }

  static Color get cobaltDeep => _scale(cobalt, 0.72);
  static Color get cobaltNight => _scale(cobalt, 0.50);
  static Color get _surfaceBase => isDark ? _darkCard : Colors.white;
  static Color get cobaltSoft =>
      Color.alphaBlend(cobalt.withValues(alpha: 0.18), _surfaceBase);
  static Color get cobaltWash =>
      Color.alphaBlend(cobalt.withValues(alpha: 0.08), _surfaceBase);

  /// Readable foreground for the accent gradient and filled controls.
  /// A light accent needs dark ink; a dark accent needs white. (_lightInk is
  /// the near-black text color; _darkInk is the near-white one for dark mode.)
  static Color get onAccent =>
      cobalt.computeLuminance() > 0.52 ? _lightInk : Colors.white;

  static LinearGradient get cobaltGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_scale(cobalt, 1.18), cobaltDeep, cobaltNight],
    stops: const [0.0, 0.62, 1.0],
  );

  static LinearGradient get softCobaltGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cobaltWash, cobaltSoft],
  );

  static const danger = Color(0xFFD64545);
  static const success = Color(0xFF1F8F6A);

  static LinearGradient get screenGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [groundTop, ground, groundBottom],
    stops: const [0.0, 0.34, 1.0],
  );

  // Typography ------------------------------------------------------------

  static const displayFamily = 'Bricolage Grotesque';
  static const uiFamily = 'Inter';

  /// Returns [duration], or zero when the system "Remove animations" setting
  /// is on. Animated widgets should always route their duration through this
  /// so Reduce Motion is honored consistently across the app.
  static Duration motion(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  static TextStyle display(
    double size, {
    Color? color,
    double height = 1.05,
    double? letterSpacing,
    FontWeight weight = FontWeight.w700,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: letterSpacing ?? size * -0.022,
      color: color ?? ink,
    );
  }

  static TextStyle ui(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 1.35,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: uiFamily,
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color ?? ink,
    );
  }

  // Depth -----------------------------------------------------------------

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: ink.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 10),
      spreadRadius: -16,
    ),
    BoxShadow(
      color: ink.withValues(alpha: 0.08),
      blurRadius: 6,
      offset: const Offset(0, 2),
      spreadRadius: -3,
    ),
  ];

  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: ink.withValues(alpha: 0.18),
      blurRadius: 28,
      offset: const Offset(0, 12),
      spreadRadius: -14,
    ),
    BoxShadow(
      color: ink.withValues(alpha: 0.07),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get cobaltShadow => [
    BoxShadow(
      color: cobaltDeep.withValues(alpha: 0.42),
      blurRadius: 22,
      offset: const Offset(0, 10),
      spreadRadius: -8,
    ),
  ];

  /// Hairline used on cards instead of a visible border.
  static Border get hairline => Border.all(color: ink.withValues(alpha: 0.04));

  static ThemeData theme() {
    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: cobalt,
      onPrimary: onAccent,
      primaryContainer: cobaltSoft,
      onPrimaryContainer: cobaltDeep,
      secondary: cobaltDeep,
      onSecondary: onAccent,
      secondaryContainer: cobaltSoft,
      onSecondaryContainer: cobaltDeep,
      tertiary: cobalt,
      onTertiary: onAccent,
      tertiaryContainer: cobaltSoft,
      onTertiaryContainer: cobaltDeep,
      surface: ground,
      onSurface: ink,
      surfaceContainerLowest: isDark ? _darkGroundTop : Color(0xFFFFFFFF),
      surfaceContainerLow: isDark ? _darkCard : Color(0xFFF8F9FC),
      surfaceContainer: isDark ? _darkCardTint : Color(0xFFF1F3F8),
      surfaceContainerHigh: isDark ? _darkCardTintStrong : Color(0xFFEBEEF4),
      surfaceContainerHighest: isDark ? _darkLineStrong : Color(0xFFE4E8EF),
      onSurfaceVariant: muted,
      outline: lineStrong,
      outlineVariant: line,
      shadow: ink,
      scrim: ink,
      inverseSurface: ink,
      onInverseSurface: groundTop,
      inversePrimary: cobaltSoft,
      error: danger,
      onError: Colors.white,
      errorContainer: Color(0xFFFBE9E9),
      onErrorContainer: Color(0xFF8E2424),
    );

    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme
        .copyWith(
          displayLarge: display(34),
          displayMedium: display(30),
          displaySmall: display(26),
          headlineLarge: display(24),
          headlineMedium: display(21),
          headlineSmall: display(18),
          titleLarge: display(16, height: 1.12),
          titleMedium: ui(14, weight: FontWeight.w600, height: 1.25),
          titleSmall: ui(13, weight: FontWeight.w600, height: 1.25),
          bodyLarge: ui(14, height: 1.4),
          bodyMedium: ui(13, height: 1.4),
          bodySmall: ui(12, color: muted, height: 1.35),
          labelLarge: ui(12.5, weight: FontWeight.w600, height: 1.2),
          labelMedium: ui(11.5, weight: FontWeight.w500, height: 1.2),
          labelSmall: ui(10.5, weight: FontWeight.w500, height: 1.2),
        )
        .apply(bodyColor: ink, displayColor: ink);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: ground,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        iconTheme: IconThemeData(color: ink, size: 20),
        actionsIconTheme: IconThemeData(color: muted, size: 20),
        titleTextStyle: display(24),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ink.withValues(alpha: 0.04)),
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        textColor: ink,
        iconColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: ink, size: 22),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        isDense: true,
        fillColor: card,
        hintStyle: ui(13, color: faint),
        labelStyle: ui(13, color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ink.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cobalt, width: 1.4),
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        year2023: false,
        trackHeight: 5,
        activeTrackColor: cobalt,
        inactiveTrackColor: line,
        thumbColor: card,
        overlayColor: cobaltSoft,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 7,
          elevation: 1,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: ink.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: display(20),
        contentTextStyle: ui(13.5, color: muted),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: ink.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: ui(13, weight: FontWeight.w500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: ui(13, color: Colors.white),
        actionTextColor: const Color(0xFF9DB0FF),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: card,
        selectedColor: cobalt,
        disabledColor: cardTint,
        side: BorderSide(color: ink.withValues(alpha: 0.05)),
        shape: const StadiumBorder(),
        labelStyle: ui(12, weight: FontWeight.w500),
        secondaryLabelStyle: ui(12, color: onAccent, weight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      switchTheme: base.switchTheme.copyWith(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? cobalt
              : const Color(0xFFD6DAE3);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? cobalt : lineStrong;
        }),
        trackOutlineWidth: WidgetStateProperty.all(1),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cobalt,
        linearTrackColor: line,
        circularTrackColor: line,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cobalt,
        foregroundColor: onAccent,
        elevation: 0,
        shape: const CircleBorder(),
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      useMaterial3: true,
    );
  }
}
