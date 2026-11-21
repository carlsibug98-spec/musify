# Spotify interest capture & home recommendations — REA findings

Target: `com.spotify.music` 9.2.0.2053 (`base.apk`, SHA-256
`a6bded83…174d`) plus `split_config.arm64_v8a.apk`.

Tooling: androguard 4.1.4 over the shipped DEX files, `resources.arsc`, and
the existing runtime captures (`screenshots/sp-home.png`,
`screenshots/sp-player.png`). Statements are **static observations** from the
artifact unless marked *inference*. No request payloads were captured: the
installed Spotify build is logged out, so the server contract below is read
from the client protobufs and the events that consume them.

## 1. What the client actually does

The ranking itself is **not in the APK**. Home arrives pre-resolved:

| Class | Role |
|---|---|
| `com.spotify.casita.v1.resolved.ResolvedHome` | whole home response |
| `com.spotify.casita.v1.resolved.HomeStructure` | `sections_` list, already ordered |
| `com.spotify.home.evopage.mobius.Effect$LoadHomeStructure` | request first page |
| `Effect$LoadMoreHomeStructure` | request next page |
| `com.spotify.home.slotloading.proto.GetMainHomeLayoutResponse` | `slots_` layout |
| `GetSlotContentResponse` | `sections_` for one slot, plus `responseId` / `slotType` |
| `State$Content` | `model`, `pageToken`, `refreshToken`, online flag |

So the client is a **renderer plus a feedback loop**: the sequence of shelves,
their contents, and their order come from the backend. The client can only
hide/reorder what it has already received, and send signals back.

## 2. Signals the client captures

### 2.1 Onboarding / taste profile

- `CompleteQuizRequest.answers_` submits the onboarding answers; the artist
  picker is the visible part of that quiz.
- Deep links confirm the taste model is explicit, not inferred only from plays:
  `spotify:internal:taste:artist`, `:taste:genre`, `:taste:mixing`,
  `:taste-onboarding`, `:taste-onboarding-update`.
- Taste Profile is a first-class screen backed by
  `spotify-user-profile-service/v0/taste-profile`
  (`com.spotify.spotifyuserprofile.v0.TasteProfilePage`) with feedback notes
  (`taste_feedback_note_input`, `TASTEPROFILE_FEEDBACK`).

### 2.2 Runtime consumption (plays and skips)

`com.spotify.runtime_consumption.esperanto.proto.ConsumptionRecord`:

| Field | Meaning |
|---|---|
| `contentUri_` | track/episode URI |
| `streamId_` | playback stream identity |
| `msPlayed_` | actual milliseconds played |
| `msPlayedNominal_` | expected duration of the content |
| `wallTimestampSeconds_` | when it happened |

`QueryRuntimeConsumptionRequest` adds `contentUri_`, `excludePreviews_`,
`playbackStack_`, `orchestrationStack_`; `GetConsumptionRecordsRequest`/
`Response` are the batch form. Trigger tuning is shipped as remote config:
`ng_poll_min_ms_played`, `ng_poll_age_threshold_hours`,
`ng_poll_age_window_hours`, `ng_poll_dedup_enabled`,
`ng_poll_retry_interval_seconds`.

`msPlayed` vs `msPlayedNominal` is the important pair: it distinguishes a
completed play from an early skip without a separate "skip" event.
*Inference*: ratios well below nominal are negative interest; repeated
near-complete plays are positive interest.

### 2.3 Library actions

`YourLibraryRequest` / `YourLibraryDecorateRequest` and the saved-state
telemetry (`com.spotify.app.music.scaffolds.events.proto.SavedStateSizeTelemetry`)
show likes/saves/follows live in the library service, not in the home feed.
The home client reads that state as an input but does not compute affinity
from it locally.

### 2.4 Explicit feedback ("Not interested")

`com.spotify.home.explicitfeedback.proto.Feedback` = `{ uri_, createdAt_ }`;
`FeedbackList` = `feedbacks_`. Home receives
`Event$ExplicitFeedbackListChanged { entityUris }` and re-filters itself.

Strings shipped for this flow: `NOT_INTERESTED`, `not_interested`,
`not_interested_button`, `not_interested_followup_input`,
`not_interested_reasons`, `explicit_feedback_not_interested`,
`Added to not interested`, `Failed to mark not interested`.
`com.spotify.contentagnostic.v2.GranularRatings` (1–5 stars) and
`ratings-runtime-consumption` show ratings are a second explicit channel.

### 2.5 Dismissals

`com.spotify.home.evopage.structureapi.DismissedEntity` = `{ id, type }`.
Types recovered from the enum:

```
EXPLICIT_FEEDBACK, INLINE_CARD, MARKED_AS_PLAYED, ONBOARDING,
RECENTLY_PLAYED, RECENTS, SHOWCASE, VERTICAL_VIDEO_CARD
```

Home events: `DismissSection(entity)`, `UndoDismissSection(entity)`,
`TempDismissedEntitiesChanged(dismissedEntities)`. The undo event proves the
UI is expected to restore a section immediately, not wait for a server round
trip.

### 2.6 Consumption state inside home

`Event$ConsumptionStateChanged { entityUriToWasPlayed }` updates cards that
were already shown. Combined with `MARKED_AS_PLAYED`, this means a card can be
removed/marked without a new recommendation request.

## 3. How the captured interest is used on Home

1. Backend resolves `ResolvedHome` → `HomeStructure.sections_` (or slot
   layout → slot content) using taste profile, consumption history, library,
   explicit feedback and dismissals. **Ranking is server-side.**
2. Client renders sections in received order and applies local state:
   - explicit feedback URIs are filtered out,
   - dismissed section ids are hidden (temporarily or permanently by type),
   - played entities get the played treatment,
   - an undo restores a dismissed section.
3. Client sends the next signals back: consumption records, feedback list,
   library changes, onboarding/taste updates, dismissals.
4. Negative feedback is both item-level (`not interested` URI) and
   section-level (`DismissedEntity.type = EXPLICIT_FEEDBACK` /
   `INLINE_CARD`).

The home is therefore **interest-driven on the server, feedback-reactive on
the client**. There is no on-device recommender to copy; the portable part is
the signal set, the dismissal semantics, and the section contract.

## 4. What Musify adopted

Musify has no backend, so the same loop is implemented locally:

| Spotify evidence | Musify implementation |
|---|---|
| `CompleteQuizRequest.answers_` / taste onboarding | existing artist picker → `preferredArtists` |
| `ConsumptionRecord.msPlayed` vs `msPlayedNominal` | skip capture when a track is left before the qualified-play threshold |
| `Feedback {uri}` + `ExplicitFeedbackListChanged` | "Not interested" on a Made for you card; hidden by track id |
| `DismissedEntity {id, type}` + undo events | section dismissal with undo and a persisted TTL; same type names |
| `ResolvedHome.sections_` order | local shelf order: Made for you, genres, recents, playlists |
| server-side affinity | `TasteProfileService` derived affinity from picks, likes, qualified plays, recents, skips, not-interested |

Deliberate differences:

- affinity is computed **on device** and is inspectable;
- the taste model has no genre taxonomy because Musify songs do not carry a
  reliable genre field;
- explicit feedback is stored locally for 180 days and can be undone;
- the home still uses real Musify services (YouTube-backed catalog), never a
  mock feed.

## 5. Limits

- Ranking weights and the server model remain opaque; nothing in the APK
  reveals them.
- Spotify was logged out, so no live `ResolvedHome` payload or network trace
  was captured.
- `liborbit-jni-spotify.so` could not be loaded into Ghidra on Windows
  (`target_format_unsupported`); DEX/resources are authoritative here.
- The `msPlayed`/`msPlayedNominal` skip interpretation is labelled inference,
  not a string-confirmed rule.
