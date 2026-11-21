# Spotify onboarding behaviour — REA reverse-engineering findings

Target: `com.spotify.music` base.apk pulled from the TECNO device
SHA-256: `a6bded836537f252d9e8f280649145d39a5e69d2797d0e7806f8ed504c6e174d`
Size: 96.6 MB · classes: 103,569 · resources: 4,092

Tooling: REA 6.10.1 MCP + jadx-headless-mcp 0.7.1
JAR SHA-256 (verified against REA's pinned value): `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`
Provider evidence classifies these as **observed** static decompiler facts from the shipped artifact, not runtime behaviour. The APK was never executed.

## Question
How does Spotify implement "ask which artists you like at onboarding, then build a lot of things from that"?

## Evidence (decompiled protobuf field inventories)

### `com.spotify.musicquizservice.v1.GetOnboardingCarouselResponse`
- `screens_ : p.he90` — repeated `CarouselScreen` list (FIELD_NUMBER 1)
- Evidence: intro screens explaining the quiz before the artist picks.

### `com.spotify.musicquizservice.v1.CarouselScreen`
- `title_ : String`, `subtitle_ : String`, `lottieAnimationUrl_ : String`, `imageMappings_ : Map`
- Evidence: an animated (Lottie) intro carousel with title/subtitle per screen.

### `com.spotify.musicquizservice.v1.ArtistDisplayInfo`
- `spotlightUri_ : String` (the artist), `backgroundUrls_ : p.he90` (background images)
- Evidence ID (REA CLI): `ev_a42ce71a5cc15047a50755b6f8b47cd1bf058f964281bcba8bcb95db07e649e1`
- Evidence: each artist choice carries a URI + artwork backgrounds (artist card).

### `com.spotify.musicquizservice.v1.CardMetadata`
- `backgroundColour1_ / 2_ / 3_ : String`, `baseTextColour_`, `foregroundTextColour_`,
  `backgroundArtworkUrl_`, `foregroundArtworkUrl_`, `quizLogoUrl_`, `spotifyLogoUrl_`, `quizName_`
- Evidence: quiz cards are colour-themed from three colours + artwork — the
  visual identity is generated from the artist art, matching the live player's
  colour-extracted gradient (screenshot pixel sample: warm browns from album art).

### `com.spotify.musicquizservice.v1.CompleteQuizRequest`
- `quizUri_ : String` (1), `challengeId_ : String` (2), `answers_ : p.he90` (3)
- Evidence: the user's selections are submitted as a list of answers tied to a
  quiz URI/challenge id.

### Full quiz service surface (68 classes)
`GetOrCreateChallengeRequest/Response`, `GetRoundRequest/Response`, `Question`,
`ImageQuestion`, `MusicIdentifierQuestion`, `TextQuestion`, `QuotationQuestion`,
`MultipleChoiceAnswer`, `ReportAnswersRequest`, `CompleteQuizRequest/Response`,
`GetResultsRequest/Response`, `GetQuizColorsRequest/Response`, `QuizColors`,
`GetShareCardForQuizRequest/Response`, `Result`, `Score`, `EndRound`, `Source`.
Evidence: a multi-round quiz; answers are reported per round and a result/share
card is generated.

### Recommendation side (separate services)
- `com.spotify.assistedcuration.v1.RecommendationsProto` with `CurationRecommendationsRequest`,
  `SuggestedTracks`, `SuggestedByGenre`, `ItemSpecificRecommendationsRequest`,
  `SuggestedAudiobooks`, `SuggestedEpisodes`
- `com.spotify.quizrecommendationservice.v1.GetRecommendedQuizzesRequest/Response`, `RecommendedQuiz`
- Evidence: the quiz service produces quiz results; a distinct curation service
  turns selections into suggested tracks grouped by genre — i.e. the picked
  artists feed genre-based suggestion shelves.

## Conclusion (observation vs inference)
- Observed: the protobuf schema for a multi-round onboarding quiz, artist cards
  with artwork/colours, an answers submission, and a genre-based curation service.
- Inference (clearly not observed execution): the artist answers seed the
  curation service which builds the personalised home shelves. This is consistent
  with the live logged-in Home UI captured earlier: "Start listening", "To get
  you started" mixes, "Recommended Stations" — all derived from taste.
- Unknown: the server-side ranking algorithm and network payloads are not in the
  APK; only the request/response shapes are.

## Cloned behaviour in Musify
- `lib/services/artist_preference_service.dart` — stores chosen artists (mirrors
  `CompleteQuizRequest.answers_`) with id/name/image (mirrors `ArtistDisplayInfo`).
- `lib/widgets/artist_preference_picker.dart` — artist grid with select/check states;
  real artist data from `searchArtists()`.
- `getRecommendedSongs()` now seeds from chosen artists via their catalog top songs
  (mirrors the curation step) before falling back to the existing sources.
- Onboarding "Start listening" now opens the picker; a Settings entry re-opens it.
