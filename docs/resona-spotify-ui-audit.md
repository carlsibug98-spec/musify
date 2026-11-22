# Resona × Spotify UI audit

Date: 2026-11-22
Scope: Home, Search, Library, Artist, Playlist/Album, Now Playing, mini-player,
navigation, settings, and the recommendation loop.
References:

- `video-ui-mockup (2).html` (the Spotify-style mockup)
- live Spotify 9.2.0.2053 on a TECNO LJ6 (free tier, account `hahayoudontknow`)
- Resona debug build (`com.gokadzev.musify.debug`)
- `docs/spotify-*-rea-findings.md` for artifact-level evidence

## 1. Verdict in one line

The mockup is a faithful **structural** Spotify clone; Resona already has the
better product model (no ads, no podcasts, inspectable taste controls), but its
dark theme and player still read as "Daylight with the lights off" rather than a
finished streaming UI. The gap is now mostly **colour hierarchy, artwork-led
surfaces, and profile/navigation shape**, not missing screens.

## 2. What the mockup gets right

| Area | Mockup behaviour | Matches live Spotify |
|---|---|---|
| Navigation | Five items: Home, Search, Library, Create, Profile | Yes (Spotify uses Home / Search / Your Library / Premium / Create) |
| Home | Greeting-free top bar, filter chips, quick-access grid, shelf carousels | Yes |
| Search | Search field, category tiles, top result + "Featuring" shelf | Yes |
| Artist | Full-bleed hero, Follow, popular tracks, releases, playlists | Yes |
| Playlist/Album | Large cover, title, owner row, action row, big play button | Yes |
| Player | Full-bleed artwork, down chevron, context label, transport row, utility row, lyrics preview | Yes |
| Library | Filter chips, list/grid toggle, pinned items | Yes |
| Sheets | Create, saved-in, share, queue | Yes |

## 3. Where the mockup is only a sketch

These are the gaps visible when the mockup is held next to real captures:

1. **Artwork colour is hardcoded.** Every mockup card has a fixed gradient. Spotify
   samples the actual cover and uses that colour for the mini-player, the player
   backdrop, and the header wash. This is the single biggest "feels fake" tell.
2. **No "Start listening" session block.** Spotify's Home opens with 3–5 compact
   rows generated from the current listening session, not just shelves.
3. **No runtime states.** No loading skeletons, empty library, offline banner,
   download progress, or "not available" dialogs.
4. **No Profiles results.** Spotify's Search can return users/profiles; the mockup
   only has the music chips.
5. **No play counts or popularity on tracks.** Spotify shows them in artist pages
   and search rankings.
6. **No device/Connect surface.** The player utility row omits the device picker
   and the queue behaviour is simplified.
7. **No events/live content.** Deliberately out of Resona's scope; the mockup
   should not imply it exists.
8. **Search chips are cosmetic.** In Spotify the chips actually filter result
   types; in the mockup they are static.

## 4. What Spotify does that Resona should copy

P0 — visible in the first five seconds:

- **True black canvas** (`#000` base, `#121212` raised) instead of charcoal.
- **One bright accent**: `#1ED760` green on selected chips, play buttons, and
  progress; black text on green.
- **Artwork-derived player background** with a darkening floor so white text
  always passes contrast.
- **56 dp floating mini-player** with an 8 px inset and artwork-tinted surface.
  Resona already has the tint; it needs the new dark tokens.
- **16 dp shelf rhythm** and 10 dp under section headings.

P1 — structural:

- A **Profile** destination as the fourth tab, with account-level actions and
  grouped preferences; Settings stops being a peer of Home/Library.
- **Session-first Home**: compact rows above the carousels when the user has
  enough recent context.
- **Selected chips = accent fill + readable foreground**, unselected = elevated
  surface, never outlined grey capsules on black.

P2 — polish:

- Animated colour transition when the track changes.
- Queue/device affordances grouped on the right of the player utility row.
- Reduced-motion respected in every new transition.

## 5. Deliberate divergences from Spotify

Resona should **not** clone these:

- No Premium upsell, ads, podcasts, audiobooks, or live events.
- No fake catalogue. Unsupported categories get an honest dialog.
- Keep Bricolage Grotesque + Inter and 12–18 px radii (Spotify uses Circular and
  8 px). This is the Daylight identity that makes Resona recognisable.
- Keep the inspectable taste controls and local-first recommendation loop.
- Keep the brand mark green in both themes; the live accent may be user-picked.

## 6. Resona today vs the target

| Area | Today | Target |
|---|---|---|
| Dark ground | Cool charcoal `#0C0E13` | `#121212` → `#000` |
| Accent in dark | Cobalt `#2743E8` | Resona green `#1ED760` (user override kept) |
| Cards | `#171B23` blue-grey | `#181818` neutral, `#282828` elevated |
| Full player | Transparent over app gradient | Cover-dominant gradient + glow |
| Mini-player | Tinted, correct structure | Retuned to the new dark surface |
| Nav | Home / Search / Library / Settings | Home / Search / Library / Profile |
| Settings | Flat list under three headers | Profile header + grouped settings |
| Home | Quick access, filters, recents, taste shelf | Same structure, new rhythm/colour |
| Search | Tiles, chips, results, top result, Featuring | Unchanged, retinted |
| Library | Tabs, filters, import note | Unchanged, retinted |

## 7. Observed recommendation behaviour (live Spotify)

What was done: completed onboarding with NIKI, 88rising, and Arash Buana (with a
transient Daniel Caesar tap), then played Mac DeMarco and Radiohead (KID A)
through Search, returning to Home after each session.

Observed states:

- **After onboarding:** "To get you started" showed NIKI Mix, Arash Buana Mix,
  Gary Lightbody Mix; "Recommended Stations" showed Daniel Caesar, Arash Buana,
  Taylor Swift.
- **After Mac DeMarco:** Home's stable shelves did not change. The session block
  ("Start listening") offered NIKI, beabadoobee, and Rex Orange County — adjacent
  indie-pop, not Mac DeMarco himself.
- **After Radiohead (KID A):** "Start listening" offered No. 1 Party Anthem
  (Arctic Monkeys), No Other Heart (Mac DeMarco), and Sofia (Clairo). The mixes
  and stations were still the onboarding set; a "More like IV OF SPADES" shelf
  appeared further down.

Interpretation (inference, consistent with the APK evidence):

1. Home order and contents are **server-composed** (`ResolvedHome.sections_`);
   the client is a renderer plus a feedback loop.
2. The persistent shelves are driven by the **explicit taste profile**, so a
   short playback session does not immediately rewrite them.
3. The session block is driven by **recent context + collaborative neighbours**,
   which is why Radiohead produced Arctic Monkeys / Mac DeMarco / Clairo rather
   than a literal "more Radiohead" row.
4. Refresh lag is real: a single play is a weak signal compared with onboarding
   picks and library saves.

Resona's local `TasteProfileService` already implements the portable parts of
this loop (picks, qualified plays, recents, skips, not-interested, section
dismissal with undo). It should keep exposing that model rather than pretending
to be a black box.

## 8. Prioritised improvements

P0 (this redesign pass)

1. Retune the dark tokens to Spotify's black/green hierarchy while keeping
   Daylight type and radii.
2. Add a cover-dominant, contrast-safe backdrop to the full player; animate it
   on track change.
3. Replace the Settings tab with a Profile tab that contains the grouped settings
   and a real listener header.

P1 (next pass)

4. Session-first Home block using recent plays, with compact rows.
5. Header wash on artist/playlist pages derived from the hero artwork.
6. Selected-chip and pressed-state polish across Search and Library.

P2 (only if it earns its keep)

7. Profiles in search results.
8. Play-count formatting on artist tracks.
9. Device/queue utility row parity.

## 9. Acceptance criteria for the redesign

- Dark mode is visibly black-first, not blue-grey.
- The player background changes with the cover and never drops body text below
  4.5:1 contrast.
- Light mode is unchanged in character.
- Navigation has four destinations and Settings is reached through Profile.
- No podcasts, audiobooks, live events, ads, or fake catalogue entries appear.
- `flutter analyze --no-pub` passes; debug APK builds and runs on the TECNO.
