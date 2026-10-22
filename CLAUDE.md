# MovieSwiftUI — Project Guidelines

## Delivery workflow — every issue and feature follows this

Each fix or feature goes through the same pipeline. Do not push
directly to `main`, and do not skip steps even for small changes.

1. **Branch.** Cut a feature branch off the latest `main`
   (`fix/…`, `feat/…`, `refactor/…`, `docs/…`, `chore/…`). Never
   commit to `main` directly.
2. **TDD.** Build the change test-first per the red → green →
   refactor cycle below. The test and the code it satisfies land in
   the **same commit**.
3. **Format.** Run `./scripts/format.sh` (or `swiftformat` on the
   files you touched) before staging — see "Format and lint before every
   commit".
4. **Verify.** After the work is done, run the same gates CI enforces —
   `SwiftLint` (`./scripts/lint.sh`, strict), the relevant build(s),
   and the `package-tests` / `ios-tests` / `ios-tests-ipad` /
   `mac-tests` / `tvos-tests` suites that cover the change — and fix
   every build failure, failing test, or lint violation before opening
   a PR.
5. **Open a PR.** Push the branch and open a pull request with `gh`
   (always the GitHub CLI, never the web UI). The PR description
   states what changed, why, and how it was tested.
6. **Verification before merge.** Run local verification gates
   (`SwiftLint` via `./scripts/lint.sh`, the relevant build(s), and
   unit/UI test suites) before opening the PR. With GitHub Actions
   disabled, verification is completed locally before merging.
7. **Address review feedback as it lands.** If Copilot or a human
   comments before you merge, act on the valid points: push the fix,
   reply on the thread noting what changed, and resolve the thread.
8. **Merge & clean up.** This is the only step that merges. Merge with
   `gh pr merge --squash --delete-branch`, then return to `main`,
   `git pull --ff-only`, and delete the local branch. The repository
   enforces squash merges to maintain a strictly linear commit graph.

One PR per logical unit of work. Keep unrelated changes on separate
branches/PRs so each diff reviews cleanly.

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

## Format and lint before every commit

Run the project's formatter and linter on the files you touched before
staging changes:

Before `git commit`:

```bash
# Format the files you touched, or run `./scripts/format.sh` to
# format the whole `MovieSwift/` tree — `.swiftformat` is
# preserve-heavy (`--wraparguments preserve`, `--wrapcollections
# preserve`, etc.) precisely so tree-wide runs don't reflow
# unrelated files.
swiftformat path/to/ChangedFile.swift path/to/OtherChanged.swift
```

`format.sh` is a thin wrapper around `swiftformat MovieSwift` that
adds a `--check` mode and an install-guard:

```bash
./scripts/format.sh           # rewrite every file under MovieSwift/ in place
./scripts/format.sh --check   # lint-only; non-zero exit if anything would change
```

When `./scripts/lint.sh` reports lint violations, fix what it flags. Most are
hand-fixes; for the mechanically-correctable ones (trailing whitespace,
colon/comma spacing, redundant void return, trailing newline) you may
run `./scripts/lint.sh --fix`, which auto-applies SwiftLint's
correctable rules and THEN re-runs `swiftlint lint --strict` to surface
anything autocorrect couldn't fix. Running bare `swiftlint --fix` only
applies auto-corrections and does **not** re-lint, so don't rely on it;
`./scripts/lint.sh` (no `--fix`) is the strict lint gate.

### Exemptions: two-tier policy

Codebase-wide patterns (SwiftUI multi-trailing-closure builders,
long view bodies, TMDB snake_case field names, reducer-pattern
cyclomatic complexity) are already relaxed in `.swiftlint.yml` —
see the header comment there for the rationale on each tuned
threshold. Don't add new global relaxations without a similar note.

For one-off outliers (font-name factories that legitimately need
long identifier strings, the TMDB-schema struct name kept for
backwards compatibility, the single `MoviesReducer` switch that
exceeds even the project's already-raised `cyclomatic_complexity`
threshold), use an inline `// swiftlint:disable:next <rule>`
annotation with a one-line reason so the exception is documented at
the offending site.

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
