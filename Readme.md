[![CI](https://github.com/scottdensmore/MovieSwiftUI/actions/workflows/xcodebuild.yml/badge.svg?branch=main)](https://github.com/scottdensmore/MovieSwiftUI/actions/workflows/xcodebuild.yml)

# MovieSwiftUI

MovieSwiftUI is an application that uses the MovieDB API and is built with SwiftUI. 
It demos some SwiftUI (& Combine) concepts. The goal is to make a real world application using SwiftUI only. It'll be updated with new features as they come to the SwiftUI framework. 

I have written a series of articles that document the design and architecture of the app: [Making a Real World Application With SwiftUI](https://medium.com/better-programming/collection-making-a-real-world-application-with-swiftui-4f9bc8c7fb71).

![App Image](images/MovieSwiftUI_promo_new.png?)

## Architecture

MovieSwiftUI data flow is a subset and a custom implementation of the Flux part of [Redux](https://redux.js.org/). 
It implement the State in an [ObservableObject](https://developer.apple.com/documentation/combine/observableobject) as a @Published wrapped property, so changes are published whenever a dispatched action produces a new state after being reduced. 
The state is injected as an environment object in the root view of the application, and is easily accessible anywhere in the application. 
SwiftUI does all aspects of diffing on the render pass when your state changes. No need to be clever when extracting props from your State, they're simple dynamic vars at the view level. No matter your objects' graph size, SwiftUI speed depends on the complexity of your views hierarchy, not the complexity of your object graph.

## SwiftUI

MovieSwiftUI is in pure Swift UI, the goal is to see how far SwiftUI can go in its current implementation without using anything from UIKit (basically no UIView/UIViewController representable).

It'll evolve with SwiftUI, every time Apple edits existing or adds new features to the framework.

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
```

After this, open `MovieSwift/MovieSwift.xcodeproj` and build `MovieSwift` or `MovieSwiftTV`.

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

Currently MovieSwiftUI runs on iPhone, iPad, and macOS. 
