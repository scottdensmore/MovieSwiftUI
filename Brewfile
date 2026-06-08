# Homebrew dependencies for MovieSwiftUI development tooling.
#
# Install everything with:
#   brew bundle install
#
# Used by:
#   scripts/lint.sh    → swiftlint
#   scripts/format.sh  → swiftformat
#
# CI pins SwiftLint to an exact version (SWIFTLINT_VERSION in
# .github/workflows/lint.yml — currently 0.63.3) because lint behavior
# can change between patch releases (e.g. 0.63.3 stopped flagging static
# `URL(string: "literal")!` under force_unwrapping). Homebrew tracks the
# latest, so to match CI keep your local SwiftLint on that same version:
# `brew upgrade swiftlint` (or pin via the GitHub release if Homebrew has
# moved ahead). If lint passes locally but fails CI, check
# `swiftlint version` against the pinned value first.

brew "swiftlint"
brew "swiftformat"
