# MovieSwiftUI — Project Guidelines

## Test-Driven Development (TDD) — write the test first

Every behaviour change ships with a test, and the test is written
**before** the production code. This applies to bug fixes, new
features, refactors that change observable behaviour, and
parameterization/modernization passes — anything that isn't pure
formatting.

The cycle is **red → green → refactor**:

1. **RED.** Write the smallest test that captures the next desired
   behaviour (or, for a bug, reproduces the bug). Run it. It MUST
   fail for the right reason — wrong assertion, missing symbol,
   wrong value — not because the harness mis-loaded.
2. **GREEN.** Write the minimum production code to make that test
   pass. Resist the urge to write code the failing test doesn't
   demand.
3. **REFACTOR.** Tidy the production code and/or the test while
   keeping the suite green. Run the affected suite again at the
   end.

The test and the code that satisfies it land in the **same commit**.
The commit message names what the test covers (e.g.
`fix(reducer): clear popularLoading when SetPopular dispatches with
empty results — covered by peopleReducerSetPopularClearsLoadingOnEmpty`).

This applies to every `fix:`, `feat:`, and `refactor:` commit —
reducer changes, view logic, navigation, focus handling, parsing,
test-helper rewrites, anything that crosses an assertion boundary.

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
relevant accessibility identifier is present) where possible. The
TDD cycle still applies — the failing test is the structural
assertion before the visual fix lands.

## Lint & format before every commit

Run the project's linter and (for files you touched) the formatter
before staging changes. CI runs `swiftlint --strict` on every PR
(`.github/workflows/lint.yml`) — catching violations locally avoids
a forced fixup commit + extra CI cycle.

Before `git commit`:

```bash
# Format only the files you touched. Targeted runs avoid reflowing
# unrelated parts of the tree.
swiftformat path/to/ChangedFile.swift path/to/OtherChanged.swift

# Lint the whole repo (fast, ~5s). `--fix` auto-applies correctable
# rules (whitespace, colon spacing, trailing commas, brace position).
./scripts/lint.sh --fix
```

Either of the above can also be run as the bare repo-root tools
(`swiftlint --fix` / `swiftformat MovieSwift`); the scripts just
wire in the standard flags and exit-code semantics.

If a rule fires on code that's intentionally exempted (font factory
names, Redux switches, etc.), use an inline
`// swiftlint:disable:next <rule>` annotation with a one-line
reason rather than relaxing the rule in `.swiftlint.yml`.

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
