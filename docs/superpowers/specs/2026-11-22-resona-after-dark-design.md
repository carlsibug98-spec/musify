# Resona After Dark — design specification

Date: 2026-11-22
Status: proposed
Implements the P0 items in `docs/resona-spotify-ui-audit.md`.

## 1. Goal

Move Resona's dark appearance from "Daylight with the lights off" to a
black-first streaming interface with Spotify's hierarchy, while keeping the
Daylight identity (Bricolage Grotesque, Inter, 12–18 px radii, GPL headers,
Resona green brand) and the product decisions that make Resona better: no ads,
no podcasts, no fake catalogue, local-first taste controls.

## 2. Principles

1. **Black is the canvas, content is the colour.** Neutral surfaces carry the
   layout; the only chromatic surfaces are artwork-derived, the accent, and
   semantic states.
2. **One accent at a time.** Dark mode defaults to Resona green. A user-picked
   accent still wins. Selected controls use an accent fill with a computed
   readable foreground.
3. **Artwork is the hero.** The mini-player and full player derive their tint
   from the current cover, with a contrast floor so text never becomes muddy.
4. **Daylight bones stay.** Headings use Bricolage; UI copy uses Inter; cards use
   12–18 px radii; shelf rhythm is 16 dp; section headings sit 10 dp above their
   content.
5. **Honest surfaces.** No upsell, no empty placeholders, no invented releases.
   If a category is unsupported, say so.

## 3. Tokens

All values live in `lib/theme/daylight.dart`. Light tokens are unchanged.

| Token | Dark value | Role |
|---|---|---|
| `groundTop` | `#121212` | app bar / first screen |
| `ground` | `#0B0B0B` | body |
| `groundBottom` | `#000000` | nav, page bottom |
| `card` | `#181818` | cards, sheets |
| `cardTint` | `#1F1F1F` | raised rows |
| `cardTintStrong` | `#282828` | pressed / selected surfaces |
| `ink` | `#FFFFFF` | primary text |
| `muted` | `#B3B3B3` | secondary text (≈8.9:1 on `#121212`) |
| `faint` | `#7C7C7C` | tertiary text / disabled |
| `line` | `#2A2A2A` | hairlines |
| `lineStrong` | `#3E3E3E` | outlines |
| dark accent | `#1ED760` | selected chips, play, progress |
| `brand` | `#22D760` | logo, unchanged |

Accent rules:

- `cobalt` returns the user accent when `useSystemColor` is false; otherwise it
  returns `#1ED760` in dark and cobalt `#2743E8` in light.
- `onAccent` is chosen by WCAG contrast, not a luminance threshold. Black text on
  green; white text on cobalt.
- `cobaltSoft` / `cobaltWash` blend the accent over `card` in dark and white in
  light.

Depth:

- Shadows are black-based in dark mode and ink-based in light mode. No white
  glow around cards.
- Radii stay 12–18 px; the player backdrop is full-bleed and square.

## 4. Player backdrop

New widget: `NowPlayingBackdrop` in
`lib/widgets/now_playing/now_playing_backdrop.dart`.

- Resolves the cover colour through `songArtworkTint(metadata)` (already cached
  by URL).
- Produces a three-stop vertical gradient: tinted top (`L ≈ 0.20`, saturation
  preserved at 60–80 %), tinted mid, `groundBottom` at 72 %.
- Adds one soft radial glow behind the artwork at 28 % opacity.
- Animates colour changes over 450 ms with `Daylight.motion`; reduce-motion
  disables the transition.
- Fallback when no artwork or extraction fails: `Daylight.screenGradient`.
- Compatibility: light mode keeps the existing neutral Daylight backdrop; the
  tint is dark-mode only.

Contrast floor: the backdrop top is clamped to relative luminance ≤ 0.06 before
the gradient overlay, so white title text stays ≥ 4.5:1.

## 5. Navigation and Profile

Bottom navigation becomes four destinations:

`Home · Search · Library · Profile`

- Profile uses `FluentIcons.person_circle_24_regular/filled` and the new
  `profile` l10n key (English template; other locales fall back).
- The `/settings` route and branch index stay intact for deep links and offline
  fallback.
- Profile screen = current Settings page with:
  - a header card: brand monogram, "Resona listener", and three stat chips
    (liked songs, playlists, minutes this month), each wired to live notifiers;
  - grouped sections: Appearance, Playback, Library & data, About;
  - a "Settings" title is replaced by "Profile"; the gear remains on deep-linked
    settings flows.

Rationale: Spotify treats account-level controls as a destination, not as a
peer of Home. This also removes the odd "Settings" tab from the main listening
loop without hiding the controls.

## 6. Home, Search, Library

No structural rewrite in this pass.

- Home keeps quick access, All/Playlists/Songs filters, Jump back in, suggested
  playlists, month recap, taste shelf, and recommendations.
- Selected filter chips automatically become green-on-black via the token and
  `onAccent` fix.
- Search and Library keep their current layouts; they inherit the new surfaces.
- Shelf spacing stays 16 dp; headings stay 10 dp above content.

## 7. Scope

In scope:

- Dark tokens, accent selection, readable foreground, shadow direction.
- Full-player artwork backdrop.
- Profile tab and profile header/grouping.
- Regression fixes found while verifying (contrast, overflow, stale colours).

Out of scope:

- Podcasts, audiobooks, live events, ads, Premium.
- Profiles in search results, play counts, device picker, queue parity.
- Server or recommendation-algorithm changes.
- A pixel-for-pixel Spotify clone.

## 8. Acceptance criteria

1. In dark mode the app reads as black with neutral `#181818` cards; no blue-grey
   cast remains on Home, Search, Library, or Player.
2. Selected chips and primary play controls are green with dark readable text;
   light mode still uses cobalt.
3. Opening Now Playing on two different covers produces two visibly different,
   contrast-safe backdrops, with a smooth transition and no flash on load.
4. Bottom navigation shows Home / Search / Library / Profile; Profile shows the
   listener header and grouped settings; the `/settings` deep link still works.
5. Light mode is visually unchanged apart from the intended components.
6. `flutter analyze --no-pub` is clean; `flutter test` passes; the debug APK
   builds and runs on the TECNO.
7. Every new Dart file carries the GPL header and upstream attribution.
