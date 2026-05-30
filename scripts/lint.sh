#!/usr/bin/env bash
#
# Run SwiftLint over the project using the repo's .swiftlint.yml.
#
# Usage:
#   ./scripts/lint.sh              # default: fail on any violation (--strict)
#   ./scripts/lint.sh --fix        # apply autocorrect, then re-lint --strict
#   ./scripts/lint.sh --warn-only  # report violations but exit 0 (advisory)
#
# Requires: swiftlint (install via `brew bundle install`).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "error: swiftlint not installed. Run 'brew bundle install' from the repo root." >&2
    exit 127
fi

MODE="strict"
case "${1:-}" in
    --fix)
        MODE="fix"
        ;;
    --warn-only)
        MODE="warn"
        ;;
    "")
        ;;
    *)
        echo "usage: $0 [--fix|--warn-only]" >&2
        exit 64
        ;;
esac

case "${MODE}" in
    fix)
        echo "==> swiftlint --fix (auto-correct)"
        swiftlint --fix
        echo "==> swiftlint --strict (verify)"
        swiftlint lint --strict
        ;;
    warn)
        # Advisory mode: surface violations but always exit 0. Without
        # `|| true`, `set -e` + `swiftlint lint`'s non-zero exit on
        # error-level violations would defeat the "advisory" contract.
        swiftlint lint || true
        ;;
    strict)
        swiftlint lint --strict
        ;;
esac
