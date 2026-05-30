#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PATH="${SCRIPT_DIR}/DeveloperSettings.template.xcconfig"
SETTINGS_PATH="${SCRIPT_DIR}/DeveloperSettings.xcconfig"

TEAM_ID="${DEV_TEAM_ID:-}"
ORG_IDENTIFIER="${ORG_IDENTIFIER:-}"
TMDB_API_KEY="${TMDB_API_KEY:-}"
NON_INTERACTIVE=false

usage() {
  cat <<'USAGE'
Usage: ./setup.sh [options]

Creates:
  - DeveloperSettings.xcconfig

Options:
  --non-interactive            Run without prompts (requires all values)
  --dev-team-id <id>           Apple Developer Team ID
  --org-identifier <value>     Reverse-domain identifier (e.g. com.example)
  --tmdb-api-key <key>         TMDB v3 API Key
  -h, --help                   Show this help

Environment fallbacks:
  DEV_TEAM_ID
  ORG_IDENTIFIER
  TMDB_API_KEY
USAGE
}

require_option_value() {
  local option="$1"
  local value="${2:-}"
  if [ -z "${value}" ]; then
    echo "error: ${option} requires a value" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive)
      NON_INTERACTIVE=true
      shift
      ;;
    --dev-team-id)
      require_option_value "$1" "${2:-}"
      TEAM_ID="$2"
      shift 2
      ;;
    --org-identifier)
      require_option_value "$1" "${2:-}"
      ORG_IDENTIFIER="$2"
      shift 2
      ;;
    --tmdb-api-key)
      require_option_value "$1" "${2:-}"
      TMDB_API_KEY="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ "${NON_INTERACTIVE}" = true ]; then
  missing=()
  [ -z "${TEAM_ID}" ] && missing+=("DEV_TEAM_ID/--dev-team-id")
  [ -z "${ORG_IDENTIFIER}" ] && missing+=("ORG_IDENTIFIER/--org-identifier")
  [ -z "${TMDB_API_KEY}" ] && missing+=("TMDB_API_KEY/--tmdb-api-key")

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "error: --non-interactive mode requires all values." >&2
    printf 'missing: %s\n' "${missing[@]}" >&2
    exit 1
  fi
else
  if [ -z "${TEAM_ID}" ]; then
    echo "1. Enter your Apple Developer Team ID:" 
    read -r TEAM_ID
  fi

  if [ -z "${ORG_IDENTIFIER}" ]; then
    echo "2. Enter your organization identifier (reverse-domain, e.g. com.example):"
    read -r ORG_IDENTIFIER
  fi

  if [ -z "${TMDB_API_KEY}" ]; then
    echo "3. Enter your TMDB v3 API key:"
    read -r TMDB_API_KEY
  fi
fi

if [ ! -f "${TEMPLATE_PATH}" ]; then
  echo "error: template file not found at ${TEMPLATE_PATH}" >&2
  exit 1
fi

echo "Creating ${SETTINGS_PATH}"
cat <<SETTINGS > "${SETTINGS_PATH}"
CODE_SIGN_IDENTITY = Apple Development
DEVELOPMENT_TEAM = ${TEAM_ID}
CODE_SIGN_STYLE = Automatic
ORGANIZATION_IDENTIFIER = ${ORG_IDENTIFIER}
TMDB_API_KEY = ${TMDB_API_KEY}
SETTINGS

chmod 600 "${SETTINGS_PATH}"

# Install Homebrew-managed dev tooling (swiftlint, swiftformat) if a
# Brewfile is present and brew is installed. Skipping is fine — the
# CI lint job installs its own copies — but local lint/format scripts
# won't run without these.
if [ -f "${SCRIPT_DIR}/Brewfile" ] && command -v brew >/dev/null 2>&1; then
  echo "Installing dev tooling from Brewfile (swiftlint, swiftformat)..."
  (cd "${SCRIPT_DIR}" && brew bundle install --no-upgrade) || \
    echo "warning: 'brew bundle install' failed; run it manually if you want local lint/format." >&2
elif [ -f "${SCRIPT_DIR}/Brewfile" ]; then
  echo "note: install Homebrew (https://brew.sh) and run 'brew bundle install' for local lint/format."
fi

echo "Done. Open Xcode and build MovieSwift or MovieSwiftTV."
