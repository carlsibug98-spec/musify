# Spotify-Style Album View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or subagent-driven-development. Steps use `- [ ]` checkboxes.

**Goal:** Reshape the album/playlist page to the Spotify reference: dark theme, large square cover, left-aligned title, artist row with avatar/date, single action row with a big play button; remove sort/search chips.

**Architecture:**
1. Make Daylight tokens brightness-aware (getters reading global `brightness`) and re-enable real `themeMode` in `main.dart`, so the whole app can go dark.
2. Add a token-free `album_metadata_service.dart` backed by the iTunes Search API for real artist / release date / artwork, with a Hive cache.
3. Restructure `PlaylistHeader` + a new hero/action layout for albums while keeping playlists/user-songs working.

**Tech Stack:** Flutter 3.47.9, Dart, Hive, `http`, iTunes Search API, Daylight design tokens.

**Spec:** User screenshot reference (Spotify album view) + chat decisions: dark theme too; fetch artist/date online; remove sort/search. GPL-3.0 headers required.

## Global Constraints
- Flutter 3.47.9; GPL-3.0 header on every new Dart file.
- Keep Daylight accent system (dynamic cobalt / user RGB).
- Real data only — no invented artist/date; omit when unavailable.
- l10n: add keys to `app_en.arb` then `flutter gen-l10n`.

## Review Focus
- Dark-mode contrast: body text ≥4.5:1 on dark ground; accent foreground auto-picks.
- Brightness switch rebuilds all tokens without stale const colors.
- Offline: metadata fetch fails gracefully; cached values used; no hang.
- `PlaylistHeader` shared by user_songs_page — album styling must not break it.
- Large cover + long title must not overflow on small 320dp screens.

---

### Task 1: Brightness-aware Daylight tokens + dark ThemeData ✅ DONE

**Files:**
- Modify: `lib/theme/daylight.dart`
- Modify: `lib/main.dart:257-263`

- [ ] Convert ground/ink/muted/faint/line/lineStrong/card/cardTint/cardTintStrong/surface roles from `static const` to `static Color get ...` switching on `brightness` (import `app_themes.dart`).
- [ ] Fix accent-derived getters (`cobaltSoft`, `cobaltWash`, `onAccent`) to blend against dark surface when dark.
- [ ] Make `Daylight.theme()` build a dark `ColorScheme` when `brightness == dark` (set system bar icons light).
- [ ] In `main.dart`, set `themeMode: themeMode`, `theme: light theme`, `darkTheme: dark theme` (rebuild on `changeSettings` already calls setState).
- [ ] Run `flutter analyze --no-pub` — zero errors/warnings.

### Task 2: Online album metadata (artist/date/artwork) ✅ DONE

**Files:**
- Create: `lib/services/album_metadata_service.dart`
- Modify: `lib/localization/app_en.arb`

- [ ] `Future<AlbumMetadata?> fetchAlbumMetadata({required String title, String? artist})` — query `https://itunes.apple.com/search?term=...&entity=album&limit=5`, pick best-normalized result (title match, then artist), return artist/releaseDate/artwork.
- [ ] Cache results in Hive box `userNoBackup` key `albumMeta_<normalized>`; read cache first; 8s timeout; return null offline.
- [ ] GPL header; normalize accents/case for matching.
- [ ] No new l10n keys needed for data display (uses title/artist/date strings).
- [ ] Run `flutter analyze --no-pub`.

### Task 3: Restructure album layout + remove sort/search ✅ DONE

**Files:**
- Modify: `lib/widgets/playlist_page/playlist_header.dart`
- Modify: `lib/widgets/playlist_hero_artwork.dart`
- Modify: `lib/widgets/playlist_page/playlist_action_buttons.dart`
- Modify: `lib/screens/playlist_page.dart`

- [ ] Add album hero: large square cover (radius 18), replacing circle for `isAlbum` playlists only.
- [ ] `PlaylistHeader`: for albums, left-aligned title (28px), artist avatar+name row (cover as avatar fallback, real artist image when fetched), `Album · <date or N songs>` line.
- [ ] Replace two big pills with one action row: small cover thumb, add, download, share, shuffle (circular icons) + big filled play button on the right.
- [ ] Wire `fetchAlbumMetadata` in `playlist_page` for albums; fill artist/date when found; omit when not.
- [ ] Remove `SortChips` and `SearchBarSection` and their state from `playlist_page` (keep for playlists/user-songs if shared — album only).
- [ ] Run `flutter analyze --no-pub`, then `flutter gen-l10n`.

### Task 4: Verify on device ✅ DONE (TECNO: album view shows real artist/date `Album · 23 Jul 2020`, action row Download/Share/Shuffle/Play; no crash)

- [ ] Build `app-github-debug.apk`, install on TECNO.
- [ ] Set dark mode, open an album: verify large cover, artist/date, action row, play button.
- [ ] Verify light mode still works; verify playlist/user-songs pages unaffected.
- [ ] Screenshot each state.
