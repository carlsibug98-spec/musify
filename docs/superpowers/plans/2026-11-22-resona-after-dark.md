# Resona After Dark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Resona a black-first Spotify-grade dark UI with a cover-derived player backdrop and a Profile destination, without losing the Daylight identity or the no-ads/no-podcasts product model.

**Architecture:** Retune the existing `Daylight` token layer (one file) so every screen inherits the new palette, add a small palette helper plus a full-player backdrop widget, then move Settings behind a Profile tab that keeps the `/settings` route intact. No screen is rewritten from scratch.

**Tech Stack:** Flutter 3.47.x, Dart, `material_ui`, `audio_service`, `cached_network_image`, Fluent UI icons, Hive-backed settings, ARB localization.

**Spec:** `docs/superpowers/specs/2026-11-22-resona-after-dark-design.md`

## Global Constraints

- Keep the GPL-3.0 header and `Copyright (C) 2026 Valeri Gokadze` on every new Dart file.
- Keep Bricolage Grotesque for display and Inter for UI copy; do not add fonts.
- Keep 12–18 px card radii. Do not introduce 8 px Spotify cards.
- No new package dependencies; colour extraction uses `dart:ui` and the existing cache.
- Do not add podcasts, audiobooks, live events, ads, or Premium surfaces.
- Light mode must keep cobalt `#2743E8`; dark mode defaults to `#1ED760`.
- User-selected accent colours always override the default.
- Body text must stay ≥ 4.5:1 on its background.
- Run `flutter analyze --no-pub` and `flutter test` before building.
- Never print, commit, or persist the GitHub PAT.

## Review Focus

- A bright cover (yellow, white, pastel) must not produce a player backdrop that
  destroys white-text contrast.
- A missing, broken, or `file://` cover must not leave the player blank or crash.
- A user-picked accent close to white must still get readable text via
  `onAccent`, and light mode must not inherit the green default.
- Long profile stat labels and long nav labels must not overflow on a 320 dp
  screen.
- Switching tracks quickly must not show the previous track's tint after the new
  one has loaded.

---

### Task 1: Dark tokens and contrast-safe accent

**Files:**
- Modify: `lib/theme/daylight.dart`
- Test: `test/daylight_dark_tokens_test.dart`

**Interfaces:**
- Produces: `Daylight.onColor(Color background) -> Color`; `Daylight.cobalt`,
  `Daylight.onAccent`, and all surface getters keep their existing names/types.
- `brightness` remains a mutable top-level `Brightness` in
  `lib/theme/app_themes.dart` so tests can switch modes.

- [ ] **Step 1: Write the failing token test**

```dart
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
```

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/daylight_dark_tokens_test.dart`
Expected: FAIL because `onColor` does not exist and the dark values are the old charcoal ones.

- [ ] **Step 3: Retune the dark tokens**

In `lib/theme/daylight.dart` replace the dark constants with:

```dart
static const _darkGroundTop = Color(0xFF121212);
static const _darkGround = Color(0xFF0B0B0B);
static const _darkGroundBottom = Color(0xFF000000);
static const _darkInk = Color(0xFFFFFFFF);
static const _darkMuted = Color(0xFFB3B3B3);
static const _darkFaint = Color(0xFF7C7C7C);
static const _darkLine = Color(0xFF2A2A2A);
static const _darkLineStrong = Color(0xFF3E3E3E);
static const _darkCard = Color(0xFF181818);
static const _darkCardTint = Color(0xFF1F1F1F);
static const _darkCardTintStrong = Color(0xFF282828);
```

Replace `cobaltBase` with:

```dart
static const _lightAccent = Color(0xFF2743E8);
static const _darkAccent = Color(0xFF1ED760);
static Color get cobaltBase => isDark ? _darkAccent : _lightAccent;
```

Add and use the contrast helper:

```dart
/// Picks near-black or white by WCAG contrast rather than a raw luminance
/// threshold, so green (#1ED760) gets dark text and cobalt gets white.
static Color onColor(Color background) {
  final luminance = background.computeLuminance();
  final whiteContrast = 1.05 / (luminance + 0.05);
  final darkContrast = (luminance + 0.05) / 0.05;
  return darkContrast > whiteContrast ? _lightInk : Colors.white;
}

static Color get onAccent => onColor(cobalt);
```

Make the shadows direction-aware: use `Colors.black.withValues(alpha: isDark ? 0.55 : 0.10)`
for `cardShadow`, `Colors.black.withValues(alpha: isDark ? 0.62 : 0.18)` for
`floatingShadow`, and keep `cobaltShadow` on `cobaltDeep`.

- [ ] **Step 4: Run the test**

Run: `flutter test test/daylight_dark_tokens_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze --no-pub`
Expected: no new issues.

```bash
git add lib/theme/daylight.dart test/daylight_dark_tokens_test.dart
git commit -m "feat: retune dark theme to a black-first palette"
```

---

### Task 2: Contrast-safe artwork backdrop colour

**Files:**
- Modify: `lib/services/artwork_palette.dart`
- Test: `test/artwork_backdrop_test.dart`

**Interfaces:**
- Produces: `Color artworkBackdropTop(Color? tint)` and
  `Color artworkBackdropBottom()`.
- Consumes: `Daylight.groundTop`, `Daylight.groundBottom`, `Daylight.isDark`.

- [ ] **Step 1: Write the failing helper test**

```dart
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
```

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/artwork_backdrop_test.dart`
Expected: FAIL because the helpers do not exist.

- [ ] **Step 3: Implement the helpers**

In `lib/services/artwork_palette.dart`:

```dart
/// Top colour of the full-player backdrop. The tint is clamped until its
/// relative luminance is at most 0.06, which keeps white text at >= 4.5:1.
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

Color artworkBackdropBottom() =>
    Daylight.isDark ? Daylight.groundBottom : Daylight.ground;
```

- [ ] **Step 4: Run the helper test**

Run: `flutter test test/artwork_backdrop_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/artwork_palette.dart test/artwork_backdrop_test.dart
git commit -m "feat: add contrast-safe artwork backdrop colours"
```

---

### Task 3: Full-player artwork backdrop

**Files:**
- Create: `lib/widgets/now_playing/now_playing_backdrop.dart`
- Modify: `lib/screens/now_playing_page.dart:64-99`
- Test: `test/now_playing_backdrop_test.dart`

**Interfaces:**
- Produces: `NowPlayingBackdrop({required MediaItem metadata, required Widget child, Key? key})`.
- Consumes: `songArtworkTint(MediaItem)` and `artworkBackdropTop(Color?)`.

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/widgets/now_playing/now_playing_backdrop.dart';

void main() {
  testWidgets('renders its child when artwork is missing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingBackdrop(
          metadata: const MediaItem(id: '1', title: 'Test'),
          child: const Text('player'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/now_playing_backdrop_test.dart`
Expected: FAIL because the widget does not exist.

- [ ] **Step 3: Create the backdrop widget**

`NowPlayingBackdrop` is a `StatelessWidget` using `FutureBuilder<Color?>` on
`songArtworkTint(metadata)`:

- root: `AnimatedContainer` with `Daylight.motion(context, 450ms)`;
- decoration: `BoxDecoration(gradient: LinearGradient(begin: topCenter,
  end: bottomCenter, colors: [artworkBackdropTop(tint), Color.lerp(top,
  bottom, 0.45)!, bottom], stops: [0, 0.52, 1]))`;
- overlay: one `RadialGradient` glow centred at `Alignment(0, -0.35)` using the
  raw tint at 22 % alpha, `radius: 0.9`;
- child: `Stack` with the glow, a `DecoratedBox` filling the screen, and the
  caller's `child`;
- when `Daylight.isDark` is false, return the child over
  `Daylight.screenGradient` with no tint.

Add the GPL header verbatim from `lib/widgets/now_playing/now_playing_artwork.dart`.

- [ ] **Step 4: Wrap the player body**

In `lib/screens/now_playing_page.dart`, change the `StreamBuilder` body to:

```dart
final metadata = snapshot.data!;
return NowPlayingBackdrop(
  metadata: metadata,
  child: SafeArea(
    child: Column(
      children: [
        _buildAppBar(context, metadata),
        Expanded(
          child: isLargeScreen
              ? _DesktopLayout(...)
              : _MobileLayout(...),
        ),
      ],
    ),
  ),
);
```

Keep `Scaffold(backgroundColor: Colors.transparent)`. Do not wrap the app bar
twice in `SafeArea`.

- [ ] **Step 5: Run tests and analyze**

Run: `flutter test test/now_playing_backdrop_test.dart`
Expected: PASS.

Run: `flutter analyze --no-pub`
Expected: no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/now_playing/now_playing_backdrop.dart lib/screens/now_playing_page.dart test/now_playing_backdrop_test.dart
git commit -m "feat: add cover-derived full-player backdrop"
```

---

### Task 4: Profile tab with grouped settings

**Files:**
- Create: `lib/widgets/profile_stat.dart`
- Modify: `lib/screens/bottom_navigation_page.dart:185-223`
- Modify: `lib/screens/settings_page.dart:56-115`
- Modify: `lib/localization/app_en.arb`
- Test: `test/profile_summary_test.dart`

**Interfaces:**
- Produces: `String profileCountLabel(int count)` and
  `ProfileStat({required String label, required int value, Key? key})` in
  `lib/widgets/profile_stat.dart`. The formatter returns `count.toString()` for
  counts < 1000 and `'${(count / 1000).toStringAsFixed(1)}k'` otherwise.
- Consumes: `userLikedSongsList`, `userLikedPlaylists`,
  `listeningStatsService.monthStats`, `listeningStatsMonthKey`,
  `monthDisplayMinutes`.

- [ ] **Step 1: Write the failing formatter and overflow tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/widgets/profile_stat.dart';

void main() {
  test('profile counts stay compact', () {
    expect(profileCountLabel(0), '0');
    expect(profileCountLabel(999), '999');
    expect(profileCountLabel(1200), '1.2k');
    expect(profileCountLabel(15400), '15.4k');
  });

  testWidgets('a stat fits a narrow tile', (tester) async {
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
```

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/profile_summary_test.dart`
Expected: FAIL because `profileCountLabel` and `ProfileStat` do not exist.

- [ ] **Step 3: Create `ProfileStat` and the profile header**

Create `lib/widgets/profile_stat.dart` with the GPL header, the
`profileCountLabel` function above, and a `ProfileStat` that renders the value in
`Daylight.display(18)` over a caption in `Daylight.ui(10.5,
color: Daylight.muted)`. The caption uses `maxLines: 1`,
`overflow: TextOverflow.ellipsis`; the value uses `FittedBox(fit: BoxFit.scaleDown)`.

In `lib/screens/settings_page.dart`, import `ProfileStat` and add a
`_ProfileHeader` widget above `_buildPreferencesSection`:

- `DaylightCard` with `padding: 16`;
- `Row`: 48 px circular `DaylightBrandMark` (or app icon), then
  `Column("Resona listener", l10n.settings)` and a small green status dot;
- 12 px gap;
- `Row` of three expanded stat tiles built from `ValueListenableBuilder`s:
  liked songs (`userLikedSongsList.value.length`), playlists
  (`userLikedPlaylists.value.length`), minutes
  (`monthDisplayMinutes(listeningStatsService.monthStats(
  listeningStatsMonthKey(DateTime.now())))`);
- each stat is a `ProfileStat(label: ..., value: ...)` using the same three
  captions (`l10n.likedSongs`, `l10n.playlists`, `l10n.minutes`).

- [ ] **Step 4: Rename the destination and group the sections**

In `_getNavigationItems`, replace the Settings item with:

```dart
_NavigationItem(
  icon: FluentIcons.person_circle_24_regular,
  selectedIcon: FluentIcons.person_circle_24_filled,
  label: context.l10n?.profile ?? 'Profile',
  shellIndex: 3,
)
```

In `lib/localization/app_en.arb` add:

```json
"profile": "Profile",
```

In `SettingsPage.build`, use `title: context.l10n!.profile` and insert
`const _ProfileHeader()` as the first child. Keep the `/settings` route and all
existing groups/actions. If a section header already says "Preferences", leave
it; the header card supplies the identity layer, not a second settings stack.

- [ ] **Step 5: Run tests and analyze**

Run: `flutter test test/profile_summary_test.dart`
Expected: PASS (2 tests).

Run: `flutter gen-l10n`
Expected: completes without missing-key errors.

Run: `flutter analyze --no-pub`
Expected: no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/profile_stat.dart lib/screens/bottom_navigation_page.dart lib/screens/settings_page.dart lib/localization/app_en.arb test/profile_summary_test.dart
git commit -m "feat: turn settings into a profile destination"
```

---

### Task 5: Verify on device and ship

**Files:**
- No source changes unless verification finds a defect.

- [ ] **Step 1: Run the full checks**

Run: `flutter gen-l10n`
Run: `flutter analyze --no-pub`
Run: `flutter test`
Expected: all clean.

- [ ] **Step 2: Build and install**

```powershell
flutter build apk --debug --flavor github --no-pub --target-platform android-arm64
adb install -r build\app\outputs\flutter-apk\app-github-debug.apk
adb shell monkey -p com.gokadzev.musify.debug 1
```

- [ ] **Step 3: Capture the four proof states**

1. Home in dark mode (black canvas, green selected chip).
2. Now Playing on a light/bright cover.
3. Now Playing on a dark cover (different backdrop).
4. Profile tab (header + stats + grouped settings).
5. Light mode Home (cobalt still present).

Save to `C:\Users\clarisse sibug\AppData\Local\Temp\opencode\res_after_dark_*.png`
and inspect each. If the player text is not readable on a bright cover, return to
Task 2 and lower the luminance ceiling, then rebuild.

- [ ] **Step 4: Commit any verification fixes**

```bash
git add -A
git commit -m "fix: polish after-dark contrast on device"
```

- [ ] **Step 5: Push to the fork**

Use the PAT from `C:\Users\clarisse sibug\OneDrive\Desktop\CARL\token for all.txt`
without printing it:

```powershell
$token = (Get-Content "C:\Users\clarisse sibug\OneDrive\Desktop\CARL\token for all.txt" -Raw).Trim()
git push "https://x-access-token:$token@github.com/carlsibug98-spec/musify.git" HEAD:main
Remove-Variable token
```

Expected: `main -> main` accepted.

- [ ] **Step 6: Confirm the remote**

```powershell
git ls-remote "https://github.com/carlsibug98-spec/musify.git" refs/heads/main
git log --oneline -3
```

Expected: the remote SHA equals local `HEAD`.
