#!/usr/bin/env bash
#
# Run SwiftFormat over the project using the repo's .swiftformat.
#
# Usage:
#   ./scripts/format.sh           # rewrite files in place
#   ./scripts/format.sh --check   # exit non-zero if any file would change
#
# Requires: swiftformat (install via `brew bundle install`).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v swiftformat >/dev/null 2>&1; then
    echo "error: swiftformat not installed. Run 'brew bundle install' from the repo root." >&2
    exit 127
fi

# `.swiftformat` at the repo root carries all configuration.
TARGETS=("MovieSwift")

case "${1:-}" in
    --check)
        swiftformat --lint "${TARGETS[@]}"
        ;;
    "")
        swiftformat "${TARGETS[@]}"
        ;;
    *)
        echo "usage: $0 [--check]" >&2
        exit 64
        ;;
esac
