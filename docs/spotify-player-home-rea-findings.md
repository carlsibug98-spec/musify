# Spotify player & home — REA findings (UI, UX, behaviour)

Target: `com.spotify.music` 9.2.0.2053 (`base.apk`, SHA-256
`a6bded83…174d`) plus `split_config.arm64_v8a.apk`.

Tooling: REA CLI (`rea-agents`) for ELF/export inspection, Ghidra 12.2 for
native work, androguard 4.1.4 for DEX/resource inspection. All statements
below are **static observations from the shipped artifact** unless marked
*inference*. Nothing here comes from executing Spotify.

> Ghidra note: REA's Windows Ghidra P0 provider accepts PE/MZ only, so it
> refuses the ELF/ARM64 `liborbit-jni-spotify.so`. Native evidence therefore
> comes from REA's ELF export reader and the `.so` string table; DEX plus
> `resources.arsc` are the authoritative source for UI/UX. This is a host
> limitation, not missing artifact data.

## 1. Player

### 1.1 Floating mini-player (what Home actually shows)

`res/layout/nowplayingmini_default.xml` + resolved `dimen` values:

| Token | Value |
|---|---|
| `floating_now_playing_bar_height` | 56 dp |
| `floating_now_playing_bar_horizontal_margin` | 8 dp |
| `floating_now_playing_bar_bottom_margin` | 8 dp |
| `floating_now_playing_bar_corner_radius` | 8 dp |
| `floating_now_playing_bar_content_padding` | 8 dp |
| `floating_now_playing_bar_content_size` (artwork) | 40 dp |
| `floating_now_playing_bar_cover_art_radius` | 4 dp |
| docked `bottom_sheet_now_playing_bar_height` | 62 dp |
| `mini_primary_button_size` (play) | 40 dp |
| `mini_secondary_button_size` (next) | 24 dp |

The XML itself uses 16 dp side guidelines, a 54×54 dp carousel (`TrackCarouselNowPlaying`),
8 dp art→text margin, 24 dp text→menu margin, and a 2 dp `CancellableSeekBar`
flush to the top edge (`nowplayingmini_seek_bar.xml`). The 56 dp floating
variant is the one visible in `screenshots/sp-home.png`: an 8 dp-inset,
8 dp-radius card whose surface is a **dark tint of the album art** (olive for
the fire cover), not a neutral grey.

Track info behaviour (`TrackInfoView.y`):
`TrackInfoView` exposes a single state entry point, `y(zag1)`, plus
`setAppearance(TypedArray)`. Disassembled `y`:

- the title is written only when `TextView.getText().contentEquals(state.a)`
  is false, and the artist only when its own `contentEquals` check fails, so
  repeated state emissions do not restart text effects;
- the accessibility content description is built as
  `listOfNotNull(title, enhancedLabel, queuedLabel).joinToString(", ")`, i.e.
  title first, then optional badge labels;
- `EnhancedBadgeView`, `QueuedBadgeView` and a third child (the loading/
  speed slot, `X0`) are separate children whose visibility is set from
  `state.c` (enhanced), `state.d` (queued) and `state.e` (loading);
- it has no marquee API; there is no `setMarqueeEnabled` on the class — the
  mini bar is a plain title/artist/badge state machine.

`FadingSeekBarView` has no touch handling of its own: it wraps a
`CancellableSeekBar` (`setProgress(int)` from `setPosition(int)`) and fades
the two timestamp labels in/out through `setTimestampsVisible(boolean)`,
which calls a `ViewGroup` transition helper and swaps between two interpolator
instances (`Y0`/`Z0`) for the visible and hidden states. The 2 dp bar itself is
declared in `nowplayingmini_seek_bar.xml` with a transparent thumb.

### 1.2 Full player = scroll-card stack

- `ScrollCardType` has 34 values (BYOM, COMMENTS, COMPANION_CONTENT,
  CONCERT_CAMPAIGN, CONTENT_STORY, CREATOR_BIO, DISPLAY_AD, ENTITY_SEGMENTS,
  EPISODE_DESCRIPTION, E_READER, FANDOM_HUB, FRY, GATED_CONTENT, KALLAX_*,
  LEAVEBEHIND_ADS, …). The player is a feed of cards, not one fixed layout.
- `ScrollCardsContainer.addView`: a card becomes visible when it has children;
  `onViewRemoved` hides it after the last child leaves, with a translation
  animation of direction 80 and **300 ms** duration.
- `PeekScrollView.setPeekHeight` uses `topMargin = -(peek + q1)`; expand
  animates `scrollY` with an `ObjectAnimator` over **500 ms** and
  `PathInterpolator(0.3, 0, 0, 1)`.
- `NowPlayingScrollView.onScrollChanged` emits `p/xa51(scrollY delta)` through a
  `BehaviorProcessor` — downstream parallax consumes scroll deltas.
- `FullScreenLayout.onMeasure` clamps content to
  `min(parentWidth, screenWidth, parentHeight, screenHeight)` and honours
  `fillScreenHeight`.
- `TouchBlockingFrameLayout.onInterceptTouchEvent` is gated by a boolean, so
  card gestures can be selectively blocked.
- `NowPlayingMiniMode`: `Ad, Default, Empty, Endless, Greenroom, Podcast,
  ReinventFree`.
- `CarouselView.onInterceptTouchEvent` (DEX disassembly): records the down
  point, uses a **10 px** slop to classify horizontal vs vertical, and invokes
  the collapse callback when the vertical drag exceeds **50 px**; it also
  supports `setDisallowScrollLeft/Right`.

### 1.3 Playback model

- `PlayerOptions`: `repeatingContext`, `repeatingTrack`, `shufflingContext`,
  `playbackSpeed`, `modes`.
- `PlayerQueue`: `track()`, `nextTracks()`, `prevTracks()`, `revision()` —
  the queue is revisioned state, not a mutable list. `SetQueueCommand` is the
  only way the queue is replaced.
- `SleepTimer`: `None`, `EndOfTrack`, `Timestamp(long)`; `Timestamp.create(J)`
  stores the raw timestamp and its constructor is the only writer.
- `TimerType`: `clear()`, `duration(long)`, `endOfTrack()` — the three
  factory methods that populate `SetSleepTimerCommand`.
- `SetRepeatingContextCommand.create(boolean)` and
  `SetShufflingContextCommand` are separate commands from the track-repeat
  one, so context repeat and track repeat are independent flags.
- `PlaybackSettingsEsperantoService.SetShuffleStateRequest` carries
  `id : String`, `shuffleOn : boolean`, `contextEnhancement : int` — the
  shuffle toggle is addressed by playback id, not by a global singleton.
- 129 classes under `com/spotify/player/model/command/`, including
  `AddToQueue`, `PlayAsNextInQueue`, `Pause`, `Resume`, `SeekTo`,
  `SetOptions`, `SetQueue`, `SetSleepTimer`, `SkipToNextTrack`,
  `SkipToPrevTrack`, `UpdateTrack`, `UpdatePage`, `UpdateViewUri`.
- Native `liborbit-jni-spotify.so` (ELF, ARM64, 2,244 exports) contains the
  engine-side counterparts: `set sleep timer`,
  `es_set_sleep_timer_request.proto`, `getAudioTransition: gapless`,
  `getAudioTransition: crossfade (fade API)`,
  `crossfade setting < length`, `normalization_mode`, `shuffle_group_shuffle`,
  and wake paths for local playback / Connect while asleep. Sleep is enforced
  in the audio engine, not only by a UI countdown.

### 1.4 Observed player composition (`screenshots/sp-player.png`)

Top bar: down chevron · "Playing from Playlist" (muted, ~12 sp) over the
context title (bold, ~16 sp) · overflow. Background: full-bleed album art,
blurred/darkened. A synced lyric line floats above the track row. Track row:
54 dp art (4 dp radius), 20 sp bold title, 15 sp muted artist, X (dismiss) and
+ (add) on the right. Then 2 dp seekbar with 12 sp timestamps, a transport row
(shuffle 24 · previous 32 · white 64 dp play · next 32 · repeat 24), a utility
row (device left; share, queue right), and the **Lyrics preview** card with a
grab handle.

## 2. Home

### 2.1 Data model

- `ResolvedHome.structure_ : HomeStructure`; `HomeStructure` is a repeated
  `Section` list — **the server defines section order**.
- `Section` is a proto `oneof` of 80 resolved section types: `Shortcuts`,
  `RecentsShelf`, `ImageLink`, `ActionCardCarousel`, `PreviewCarousel`,
  `TopStoryCarousel`, `VideoCarousel`, `LiveEvent`, `Narrative`, `Reflection`,
  `PromptableSection`, `WatchFeed`, ads/banners, …
- Every shelf carries its own `heading` + `itemSource`. `ItemSource` is
  `provided`, `listPlatform`, or `localRecentlyPlayed`; `RecentsShelf` also
  carries `titleDensity`.
- Heading variants: empty, enriched, heading-with-description,
  heading-with-text, sponsored, static-enriched.
- Home state is Mobius: `State$Content { model, isOnline, pageToken,
  refreshToken, loadingHistory }`; events include dismiss/undo section,
  temp-dismissed entities, refresh, offline fallback.
- Both dismiss events carry one `DismissedEntity { id : String, type : Type }`
  (disassembled); `Type` is one of `EXPLICIT_FEEDBACK`, `INLINE_CARD`,
  `MARKED_AS_PLAYED`, `ONBOARDING`, `RECENTLY_PLAYED`, `RECENTS`, `SHOWCASE`,
  `VERTICAL_VIDEO_CARD`. `TempDismissedEntitiesChanged` carries a
  `Set<DismissedEntity>` — dismissal is a typed, identity-addressed set, and
  undo is the same entity object routed back through `UndoDismissSection`.
  That is why undo works after the shelf has already left the screen.

### 2.2 Layout tokens (`resources.arsc`)

| Token | Value |
|---|---|
| `section_top_margin` | 16 dp |
| `home_section_header_top_spacing` | 8 dp |
| `home_section_header_bottom_spacing` | 10 dp |
| `section_heading_vertical_padding` | 12 dp |
| `sectionheading_bottom_padding` | 16 dp |
| `home_carousel_spacing` | 16 dp |
| `card_margin` | 16 dp |
| `playlist_card_dimen` | 152 dp |
| `recents_card_image_size` | 97 dp |
| `medium_density_card_radius` | 8 dp |
| `recents_card_title_margin_top` | 8 dp |
| `image_link_card_title_top_margin` | 2 dp |

Dark tokens: `appframe_background_base #000000`,
`background_elevated #141414`, `background_tinted #21FFFFFF`,
`text_subdued #747474`, `essential_brightaccent #1ED760`.

### 2.3 Observed composition (`screenshots/sp-home.png`)

Top: avatar + filter chips (All selected in green). Then an eyebrow
("Jump into a session based on your tastes") over a large bold
"Start listening", rendered as **compact rows** (56–64 dp art, title, artist,
one overflow each) rather than cards. Below: "To get you started" horizontal
carousel with overlay label bars ("IV OF SPADES Mix") and a collaborator line
under each cover; "Recommended Stations" radio-art cards. The floating mini
bar overlays the last row, above a 5-tab bar (Home, Search, Your Library,
Premium, Create).

### 2.4 Behavioural read

- Shelves are server-composed; the client resolves `itemSource` and renders
  each section type with its own density.
- Dismissal is local + undoable (`DismissSection`, `UndoDismissSection`,
  `TempDismissedEntitiesChanged`).
- Offline and stale-feed states are explicit (`State$Content.isOnline`,
  refresh tokens, offline fallback effect).
- Local recents are an `ItemSource`, which is why a fresh account shows no
  recents shelf at all rather than an empty placeholder.

## 3. Deltas applied to Musify

Kept Daylight identity (cobalt accent, Bricolage/Inter, 12–18 dp radii):
the goal is Spotify's **rhythm and behaviour**, not a pixel copy.

1. Floating mini-player: 56 dp / 8 dp radius / 40 dp rounded-square art /
   8 dp padding, art-derived tinted surface instead of neutral card.
2. Player rhythm: 12 dp art→controls, 10 dp inside controls, 12 dp
   controls→utility, 14 dp utility→lyrics; header label/subtitle scaled to
   Spotify's hierarchy; play target 64 dp.
3. Home: 16 dp between shelves and 10 dp under section headers, matching
   `section_top_margin` / `home_section_header_bottom_spacing`.
4. Sleep timer already exposes end-of-track, matching `TimerType.EndOfTrack`.
