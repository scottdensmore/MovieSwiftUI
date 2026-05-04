[![CI](https://github.com/scottdensmore/MovieSwiftUI/actions/workflows/xcodebuild.yml/badge.svg?branch=main)](https://github.com/scottdensmore/MovieSwiftUI/actions/workflows/xcodebuild.yml)

# MovieSwiftUI

MovieSwiftUI is an application that uses the MovieDB API and is built with SwiftUI. 
It demos some SwiftUI (& Combine) concepts. The goal is to make a real world application using SwiftUI only. It'll be updated with new features as they come to the SwiftUI framework. 

![App Image](images/MovieSwiftUI_promo_new.png?)

## Architecture

MovieSwiftUI data flow is a subset and a custom implementation of the Flux part of [Redux](https://redux.js.org/). 
It implement the State in an [ObservableObject](https://developer.apple.com/documentation/combine/observableobject) as a @Published wrapped property, so changes are published whenever a dispatched action produces a new state after being reduced. 
The state is injected as an environment object in the root view of the application, and is easily accessible anywhere in the application. 
SwiftUI does all aspects of diffing on the render pass when your state changes. No need to be clever when extracting props from your State, they're simple dynamic vars at the view level. No matter your objects' graph size, SwiftUI speed depends on the complexity of your views hierarchy, not the complexity of your object graph.

## SwiftUI

MovieSwiftUI is in pure Swift UI, the goal is to see how far SwiftUI can go in its current implementation without using anything from UIKit (basically no UIView/UIViewController representable).

It'll evolve with SwiftUI, every time Apple edits existing or adds new features to the framework.

## Features

The app ships across iOS / iPadOS / macOS / tvOS. Beyond browsing TMDB, it covers the polish layer most movie-tracker apps cut corners on:

- **First-launch onboarding** — three-step wizard for TMDB key, region, and reset-from-Settings re-entry. Re-runs automatically when no usable API key is configured so a misconfigured install doesn't silently fail.
- **Network error UX** — every TMDB fetcher (~19 of them across Movies + People actions) routes through a `MoviesListLoadFailurePresenter` that translates `APIError` into user-facing copy. Inline retry banners on Home menu lists, Movie Detail, People Detail, Discover, and Genres surface offline / 401 / 403 / 429 / 5xx / decode failures with kind-specific icons and CTAs ("Try again" vs "Open Settings").
- **iCloud Drive backup + restore** — single rolling JSON envelope written to `Documents/Backups/`, browseable previous versions through `NSFileVersion`, conflict resolution after a multi-device race.
- **Local export / import** — same envelope format as iCloud backup, exposed through SwiftUI's `.fileExporter` / `.fileImporter` with merge semantics that union user collections rather than clobber.
- **MetricKit crash reporting** — Apple-native, no third-party SDK. Crash + hang + CPU + disk-write payloads land in `Documents/CrashReports/` and are visible inside the app via Settings → Debug info → View crash reports… with per-report `ShareLink` export.
- **User-supplied TMDB API key** — Settings exposes a `SecureField` for the user to paste their own TMDB v3 key. Layered provider checks user-supplied first, falls back to the bundled key. Power users with their own TMDB account get full personal quota.
- **Versioned persisted state** — on-disk format wraps `AppState` in a `formatVersion`-stamped envelope. Reading transparently falls back to the legacy bare-AppState format for installs upgrading from earlier builds; future-version files are rejected with a clear error rather than mis-decoded.
- **Accessibility** — Dynamic Type via `relativeTo:` on every custom font, `.isHeader` rotor traits on section titles, hit targets at the 44pt HIG minimum, VoiceOver labels on every icon-only button.

## Privacy & Attribution

- **Privacy manifest** — `Shared/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false`, empty tracking domains, empty collected data types. Required-reason API declarations cover file-timestamp reads (the iCloud backup last-modified date in Settings) and the `@UserDefault` wrapper.
- **TMDB attribution** — visible in Settings → About. The app surfaces "Powered by TMDB" with a tappable link to themoviedb.org and the required line: "This product uses the TMDB API but is not endorsed or certified by TMDB."
- **No data leaves the device** unless the user initiates it: TMDB fetches the movies they look at, iCloud Drive carries the backup file they write, and the local export writes the JSON envelope they pick a destination for.
- **Privacy policy URL** — set `PRIVACY_POLICY_URL` in `DeveloperSettings.xcconfig` to enable the Settings → About → Privacy policy row. Required for App Store submission.

## Local Setup (Code Signing + TMDB API Key)

This project is configured so each developer can use their own Apple Developer signing settings without modifying tracked project files.

### Option 1: Use setup script

Run:

```bash
chmod +x setup.sh
./setup.sh
```

The script creates a local `DeveloperSettings.xcconfig` (gitignored) with your Team ID, organization identifier, and TMDB API key.

### Option 2: Manual setup

Copy the template:

```bash
cp DeveloperSettings.template.xcconfig DeveloperSettings.xcconfig
```

Then update:

```xcconfig
CODE_SIGN_IDENTITY = Apple Development
DEVELOPMENT_TEAM = <YOUR_TEAM_ID>
CODE_SIGN_STYLE = Automatic
ORGANIZATION_IDENTIFIER = <YOUR_REVERSED_DOMAIN>
TMDB_API_KEY = <YOUR_TMDB_V3_API_KEY>

// Optional. Override to point at your own TMDB-compatible
// proxy that hides the API key server-side. URL escape is
// `https:/$()/example.com/tmdb` because Xcode parses `//` as
// a comment.
TMDB_BASE_URL = https:/$()/api.themoviedb.org/3

// Optional but required for App Store submission.
// URL string of your hosted privacy policy. When set, the
// Settings > About section shows a "Privacy policy" link row.
PRIVACY_POLICY_URL = https:/$()/yoursite.com/privacy
```

After this, open `MovieSwift/MovieSwift.xcodeproj` and build `MovieSwift`, `MovieSwiftMac`, or `MovieSwiftTV`.

## Testing and Coverage

### Run package tests locally

```bash
cd MovieSwift/Packages/Backend
swift test

cd ../../
swift test
```

### Run app tests locally (XCTest target tests)

```bash
xcodebuild \
  -project MovieSwift/MovieSwift.xcodeproj \
  -scheme MovieSwift \
  -destination "platform=iOS Simulator,name=iPhone 16e" \
  -only-testing:MovieSwiftTests \
  test
```

### Run coverage gate locally

```bash
./scripts/ci/check_coverage.sh
```

Optional overrides:

```bash
BACKEND_MIN_LINE_COVERAGE=76.1 FLUX_MIN_LINE_COVERAGE=52.2 COVERAGE_RATCHET_ENFORCE=1 ./scripts/ci/check_coverage.sh
```

Threshold and ratchet defaults are tracked in:

```bash
scripts/ci/coverage_thresholds.env
```

### Run CI-style iOS simulator tests locally

```bash
./scripts/ci/run_ios_tests.sh
```

iPhone unit suite + app coverage gate:

```bash
IOS_SIMULATOR_NAME="iPhone 16e" XCODE_ONLY_TESTING="MovieSwiftTests" APP_MIN_LINE_COVERAGE=5.0 ./scripts/ci/run_ios_tests.sh
```

iPad smoke + unit suite:

```bash
IOS_SIMULATOR_FAMILY="iPad" IOS_SIMULATOR_NAME="iPad (A16)" XCODE_ONLY_TESTING="MovieSwiftUITests/MovieSwiftUITests/testLaunchShowsMainTabs,MovieSwiftTests" ./scripts/ci/run_ios_tests.sh
```

The GitHub Actions CI workflow (`.github/workflows/xcodebuild.yml`) enforces:
- Package tests + coverage thresholds.
- Package coverage ratchet policy checks.
- iOS simulator tests for iPhone unit suite and iPad UI smoke coverage.
- App target coverage gate for `MovieSwift.app`.
- iOS and tvOS app build verification.

## Platforms

MovieSwiftUI ships across iPhone, iPad, macOS, and tvOS targets. macOS is a native
build (not Mac Catalyst) — it uses a `NavigationSplitView` sidebar with custom
`@FocusState`-driven keyboard navigation, a steam-themed selection highlight that
respects light/dark and active/inactive selection state, and `Cmd+1`-`Cmd+6`
shortcuts for jumping between sidebar menus.

## Architecture summary

- **Redux/Flux** state — `AppState`, persisted via `AppStatePersistedFormat`
  envelope (versioned, with legacy bare-AppState fallback).
- **Backend** Swift Package — `APIService` (config-driven `baseURL`, layered
  `APIKeyProviding` chain, query-param or bearer auth), `ImageLoaderCache`,
  `AppUserDefaults`. 34 unit tests.
- **Shared** — flux state / actions / reducers, all transient loading state
  centralised in `MoviesState.loadingStates: [LoadingKey: MoviesListLoadingState]`,
  one `SetLoadingState(key:state:)` action handles all 19 fetchers.
- **App targets** — iOS uses a `TabView`, macOS a `NavigationSplitView`, tvOS
  a focus-driven `HomeView`. Settings, onboarding, and crash-report viewer
  views are shared.

Suite is **349/349 in the app + 34/34 in Backend** across iOS / macOS / tvOS.
