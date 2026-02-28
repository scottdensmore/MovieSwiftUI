#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_PATH="$ROOT_DIR/MovieSwift/MovieSwift.xcodeproj"
SCHEME_NAME="MovieSwift"
RESULT_BUNDLE_PATH="${XCODE_TEST_RESULT_BUNDLE_PATH:-}"
SIMULATOR_UDID="${IOS_SIMULATOR_UDID:-}"

if [[ -z "$SIMULATOR_UDID" ]]; then
  SHOW_DESTINATIONS="$(
    xcodebuild \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME_NAME" \
      -showdestinations 2>/dev/null || true
  )"
  SIMULATOR_UDID="$(
    awk -F'id:' '
      /platform:iOS Simulator/ && /name:iPhone/ && $0 !~ /placeholder/ {
        split($2, parts, ",")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[1])
        print parts[1]
        exit
      }
    ' <<<"$SHOW_DESTINATIONS"
  )"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(
    awk -F'id:' '
      /platform:iOS Simulator/ && $0 !~ /placeholder/ {
        split($2, parts, ",")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[1])
        print parts[1]
        exit
      }
    ' <<<"$SHOW_DESTINATIONS"
  )"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }')"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPad/ { print $2; exit }')"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  echo "Could not find an available iOS simulator device." >&2
  exit 1
fi

SIMULATOR_NAME="$(xcrun simctl list devices available | awk -F '[()]' -v udid="$SIMULATOR_UDID" '$2 == udid { gsub(/^ +| +$/, "", $1); print $1; exit }')"
echo "Running tests on simulator: ${SIMULATOR_NAME:-Unknown} ($SIMULATOR_UDID)"

XCODEBUILD_CMD=(
  xcodebuild
  -project "$PROJECT_PATH"
  -scheme "$SCHEME_NAME"
  -destination "id=$SIMULATOR_UDID"
  test
)

if [[ -n "$RESULT_BUNDLE_PATH" ]]; then
  mkdir -p "$(dirname "$RESULT_BUNDLE_PATH")"
  XCODEBUILD_CMD+=( -resultBundlePath "$RESULT_BUNDLE_PATH" )
fi

"${XCODEBUILD_CMD[@]}"
