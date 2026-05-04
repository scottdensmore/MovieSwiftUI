# MovieSwiftUI — Project Guidelines

## Always write tests for fixes

Any time you fix a bug or change behavior, add or update a test that
exercises the change. Before committing a fix:

1. Reproduce the bug in a test (unit or UI) so the failing test
   demonstrates the problem.
2. Apply the code fix.
3. Verify the test now passes, and run the broader affected test
   suite.
4. Include the test in the same commit as the fix. The commit message
   should mention what the test covers.

This applies to every `fix:` commit — reducer changes, view logic,
navigation, focus handling, parsing, anything.

### Where tests live

- **Redux reducers & state selectors:** `MovieSwift/MovieSwiftTests/`
  (see `MovieDetailStateTests.swift`, `PeopleActionsTests.swift`,
  `MovieSwiftTests.swift`).
- **UI flows / smoke tests:** `MovieSwift/MovieSwiftTests/MovieSwiftUITests`
  (macOS uses env var `UI_TEST_SELECT_MENU` to pre-select the sidebar).
- **Swift packages:** `MovieSwift/Packages/<Name>/Tests/`.

### How to run tests

```
cd MovieSwift
xcodebuild test -scheme MovieSwift \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:MovieSwiftTests/<TestClassName>
```

For macOS-only logic, use `-scheme MovieSwiftMac` with a macOS
destination.

### When a pure test is impractical

If a fix can only be verified visually (layout, animation, focus
ring), still note that in the commit message and add at least a
structural assertion (e.g. view builds without crashing, the
relevant accessibility identifier is present) where possible.

## No file-header boilerplate

New `.swift` files must NOT include the Xcode-template file header
block — i.e. the lines that look like:

```
//
//  Foo.swift
//  MovieSwift
//
//  Created by Person on Date.
//  Copyright © Year Person. All rights reserved.
//
```

The project's `MovieSwift.xcodeproj/xcshareddata/IDETemplateMacros.plist`
sets `FILEHEADER` to empty so Xcode's templates don't add it. When
creating files outside Xcode (or via a Claude tool), start the file
directly at the first `import` statement. If you need to leave a
design note at the top, write it as ordinary `//` comments — but
don't include filename, project name, author, or copyright lines.
