# MovieSwiftUI — Roadmap

A phased plan derived from an expert audit (Apple-platform modernity, test
coverage, readability, and product/feature gaps). The app is in strong
shape — iOS/macOS/tvOS 26, Swift 6 strict concurrency, modern SwiftUI,
503 unit + 109 UI tests, good accessibility/localization. What follows is
high-leverage refinement and growth, sequenced so the codebase stays safe
to change at every step.

**Guiding principle: harden as you build.** Every feature ships with
unit + UI tests for its journey. Every change goes through the delivery
workflow in `CLAUDE.md` (branch → TDD → `code-reviewer` → green CI →
merge).

Effort key: **S** ≈ days · **M** ≈ 1–2 weeks · **L** ≈ multi-week.

---

## Phase 1 — Trailer playback (the headline gap) · S

Trailers are half-built: `MoviesActions.FetchVideos` fetches `[Video]`
(YouTube keys) into `moviesState.videos`, and `MovieDetailState` emits a
`.videos` load slice — **but nothing renders it.** No `VideoPlayer`,
play button, or link anywhere. Best impact-to-effort item in the app; the
data pipeline already exists.

- [ ] `MovieVideosRow` rendering `moviesState.videos` (trailer thumbnails).
- [ ] "Play Trailer" affordance on the hero/cover row.
- [ ] Inline YouTube/web-embed player (or deep-link to the YouTube app).
- [ ] Tests: a `MovieVideosState`/presentation unit test + a UI test that
      opens a movie and plays/launches the top trailer.

## Phase 2 — Harden critical journeys (tests) · S–M

Close the regression-risk holes so feature work is safe. (Logic layer is
already excellent; these are end-to-end + edge gaps.)

- [ ] **UI: Settings data management** — export creates a document;
      import shows preview counts + merges; iCloud backup + "restore older
      version". *No UI test exists on any platform today, and it's the most
      data-destructive surface in the app.*
- [ ] **UI: Fan Club** — people-search results + follow/unfollow toggle
      (full reducer coverage today, zero XCUITest).
- [ ] **Platform parity UI tests** — tvOS currently covers only
      browse/detail/search; macOS lags iOS on MyLists create/edit,
      Discover undo, search-cancel. Bring the critical journeys to parity.
- [ ] Strengthen existence-only assertions (189 `XCTAssertTrue` vs 18
      value-asserting on iOS) — verify state *changed*, not just that an
      element appeared.
- [ ] `PeopleActions` per-thunk failure tests (currently thinner than
      `MoviesActions`).
- [ ] Fix the two tracked macOS parity bugs and un-skip their tests:
      `CustomListRow` needs an accessibility identifier; macOS
      `DiscoverView` doesn't render `discover.undoButton`.

## Phase 3 — Readability & architecture foundation · S–M

Make the codebase easier for humans *and* agents before scaling it up.

- [ ] **Model `CodingKeys` boundary** — `Movie`/`People`/`Image`/etc.
      expose raw TMDB `snake_case` (`poster_path`, `vote_average`) as the
      public Swift API, while the `state/` layer already uses `CodingKeys`
      + camelCase. Confine snake_case to the decoding boundary (same move
      as the `productionCountry` rename, scaled up). This is the biggest
      "agent trap" in the code.
- [ ] **Centralize test seams** — env-var flags
      (`UI_TEST_INTENT_DESTINATION`, etc.) and the 77 accessibility IDs are
      bare string literals re-typed across app + test targets. Hoist into
      `enum UITestEnv` / an `AccessibilityID` namespace shared by both.
- [ ] Document the 43 `MoviesActions` structs (the Redux flow's
      discoverability hinges on them).
- [ ] Extract a `MovieDetailFocusModel` — the ~16 near-identical
      `*Targets(props:)` focus helpers dominate `MovieDetail.swift`.

## Phase 4 — Modern platform plumbing · M

Adopt current iOS-26 patterns; unblock cleaner code.

- [x] **Removed the SwiftUIFlux dependency — replaced with an in-repo
      `@Observable` `Flux` package** (PRs #47/#48). Rather than just
      migrating the vendored store, the third-party dependency was dropped
      entirely: a new `MovieSwift/Packages/Flux` reimplements its contract
      with an `@Observable @MainActor Store`. This cleared the **33
      `@preconcurrency import SwiftUIFlux`** workarounds and the
      `nonisolated(unsafe)` sample-store/middleware globals. The Redux
      architecture (reducers, actions, `ConnectedView`) is unchanged.
- [ ] **App Intent entities + parameterized Shortcuts** — intents are
      launch-only today. Add a `MovieEntity: AppEntity` +
      `AddToWatchlistIntent(movie:)` / `MarkAsSeenIntent` that dispatch the
      existing `AddToWishlist`/`AddToSeenList` actions. Unlocks Siri +
      Spotlight actions and feeds Widgets/Controls.
- [ ] Liquid Glass (`.glassEffect`) on the Discover floating buttons +
      toolbars; `@Entry` macro for environment keys; `reduceMotion` gating
      on the swipe animations; SF Symbol animations on toggles/loading.
- [ ] Remove the dead `ActionSheet`/`Alert.Button` factory
      (`Shared/extensions/ActionSheet.swift`).
- [ ] `ShareLink` on movie + person detail (TMDB URL + poster preview).

## Phase 5 — Killer features · M

- [ ] **"Where to Watch" streaming providers** — the #1 table-stakes
      feature that's entirely missing. Add `Endpoint.watchProviders`, a
      `WatchProvider` model + action/reducer, and a region-aware provider
      row (region picker already exists).
- [ ] **Watchlist Widget + lock-screen Control** — reads persisted
      `AppState`; pairs with the Phase-4 App Intents.
- [ ] Personal star ratings (stored in `AppState`); release notifications
      (`UNUserNotification` keyed off `release_date`); `movieswift://` URL
      scheme + Handoff; Spotlight poster thumbnails (`thumbnailData`).

## Phase 6 — Strategic / marquee · L

- [ ] **TV-show support** — the app is movies-only (`/tv` endpoints
      absent). Add `/tv`, season/episode models, and a media-type enum
      threaded through state. The bet that removes the app's ceiling.
- [ ] watchOS companion (watchlist on the wrist); visionOS target; Apple
      TV "Top Shelf"; "Your Year in Movies" recap (seenlist + genres are
      already in state).

---

## Cross-cutting / housekeeping

- [ ] Re-enable Swift CodeQL analysis once the refactoring sprint settles
      (temporarily dropped to skip the ~30-min `Analyze (swift)` job —
      `gh api --method PATCH .../code-scanning/default-setup -f
      state=configured -f 'languages[]=actions' -f 'languages[]=ruby' -f
      'languages[]=swift'`).
