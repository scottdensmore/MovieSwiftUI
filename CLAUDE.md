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
   files you touched) before staging — see "Format before every
   commit". **Linting is not a separate pre-staging step.** The
   `verifier` subagent (step 4) owns the strict-lint gate, so don't
   run `./scripts/lint.sh --fix` here; let the verifier surface any
   violations and fix what it reports.
4. **Verify with the `verifier` subagent.** After the work is done
   and before the review, run the `verifier` subagent
   (`.claude/agents/verifier.md`) over the pending change. It runs the
   same gates CI enforces — `SwiftLint` (`./scripts/lint.sh`, strict;
   this is the project's lint gate, not a step-3 pre-pass), the
   relevant build(s), and the `package-tests` / `ios-tests` /
   `ios-tests-ipad` / `mac-tests` / `tvos-tests` suites that cover the
   change — and reports any build failures, failing tests, or lint
   violations. The verifier is read-only, so it reports violations
   rather than auto-correcting them. **The main agent must
   fix every issue the verifier reports and re-run the verifier until it
   returns a `PASS` verdict before moving on to the review.** This is a required
   step, not optional — it keeps broken builds and red tests from ever
   reaching the reviewer or CI.
5. **Pre-PR review with the `code-reviewer` subagent.** Once the
   verifier is green, run the `code-reviewer` subagent
   (`.claude/agents/code-reviewer.md`) over the pending diff. Address
   every **must-fix** finding (and reasonable should-fix ones) before
   pushing. This is a required step, not optional — it catches
   correctness bugs, missing tests, and lint/readability issues while
   they're still cheap to fix. If addressing review feedback changes
   code, re-run the verifier before pushing.
6. **Open a PR.** Push the branch and open a pull request with `gh`
   (always the GitHub CLI, never the web UI). The PR description
   states what changed, why, and how it was tested.
7. **Green CI is the merge gate.** The branch-protection–required
   checks are the `package-tests`, `ios-tests`, `ios-tests-ipad`,
   `mac-tests`, and `tvos-tests` suites — all must pass. The
   `SwiftLint` and CodeQL/Analyze scans also run on every PR and
   should be green before merging. Never merge with a pending or
   failing required check. **A pending Copilot review (or any other
   automated reviewer) is not part of the gate — do not wait on it.**
8. **Address review feedback as it lands.** If Copilot or a human
   comments before you merge, act on the valid points: push the fix,
   reply on the thread noting what changed, resolve the thread, and
   let CI re-run. Automated feedback that arrives after a green merge
   is handled as a follow-up — it never blocks the merge.
9. **Merge & clean up.** This is the only step that merges. Once the
   required CI checks are green, merge with
   `gh pr merge --merge --delete-branch`, then return to `main`,
   `git pull --ff-only`, and delete the local branch.

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

## Format before every commit; lint is the verifier's gate

Run the project's formatter on the files you touched before staging
changes. **Linting is not a separate pre-commit step** — the
`verifier` subagent (delivery-workflow step 4) runs `./scripts/lint.sh`
(strict, matching CI's `.github/workflows/lint.yml`) as the lint gate
and reports any violations for the main agent to fix. CI still runs
the same `./scripts/lint.sh` on every PR, so the verifier is what
catches violations locally before they reach CI.

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

When the verifier reports lint violations, fix what it flags. Most are
hand-fixes; for the mechanically-correctable ones (trailing whitespace,
colon/comma spacing, redundant void return, trailing newline) you may
run `./scripts/lint.sh --fix`, which auto-applies SwiftLint's
correctable rules and THEN re-runs `swiftlint lint --strict` to surface
anything autocorrect couldn't fix — then re-run the verifier. Running
bare `swiftlint --fix` only applies auto-corrections and does **not**
re-lint, so don't rely on it; `./scripts/lint.sh` (no `--fix`) is the
strict gate the verifier runs.

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
