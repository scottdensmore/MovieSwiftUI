#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_PATH="$ROOT_DIR/MovieSwift/MovieSwift.xcodeproj"
SCHEME_NAME="MovieSwift"
RESULT_BUNDLE_PATH="${XCODE_TEST_RESULT_BUNDLE_PATH:-}"
DERIVED_DATA_PATH="${XCODE_DERIVED_DATA_PATH:-}"
IOS_TEST_ITERATIONS="${IOS_TEST_ITERATIONS:-1}"
SIMULATOR_UDID="${IOS_SIMULATOR_UDID:-}"
SIMULATOR_FAMILY="${IOS_SIMULATOR_FAMILY:-iPhone}"

if [[ "$SIMULATOR_FAMILY" != "iPhone" && "$SIMULATOR_FAMILY" != "iPad" ]]; then
  echo "Unsupported IOS_SIMULATOR_FAMILY '$SIMULATOR_FAMILY'; falling back to iPhone."
  SIMULATOR_FAMILY="iPhone"
fi

pick_simulator_uuid_from_simctl() {
  local family="$1"
  xcrun simctl list devices available | awk -v family="$family" '
    $0 ~ family {
      if (match($0, /[0-9A-F-]{36}/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  '
}

if [[ -z "$SIMULATOR_UDID" ]]; then
  SHOW_DESTINATIONS="$(
    xcodebuild \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME_NAME" \
      -showdestinations 2>/dev/null || true
  )"
  SIMULATOR_UDID="$(
    awk -F'id:' -v family="$SIMULATOR_FAMILY" '
      /platform:iOS Simulator/ && $0 ~ ("name:" family) && $0 !~ /placeholder/ {
        split($2, parts, ",")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[1])
        print parts[1]
        exit
      }
    ' <<<"$SHOW_DESTINATIONS"
  )"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(pick_simulator_uuid_from_simctl "$SIMULATOR_FAMILY")"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(pick_simulator_uuid_from_simctl "iPhone")"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(pick_simulator_uuid_from_simctl "iPad")"
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
  echo "Could not find an available iOS simulator device." >&2
  exit 1
fi

SIMULATOR_NAME="$(
  xcrun simctl list devices available | awk -v udid="$SIMULATOR_UDID" '
    index($0, udid) {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+\(.*/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      print line
      exit
    }
  '
)"
echo "Running tests on simulator: ${SIMULATOR_NAME:-Unknown} ($SIMULATOR_UDID)"
echo "Preferred simulator family: $SIMULATOR_FAMILY"
echo "Test iterations: $IOS_TEST_ITERATIONS"

XCODEBUILD_CMD=(
  xcodebuild
  -project "$PROJECT_PATH"
  -scheme "$SCHEME_NAME"
  -destination "id=$SIMULATOR_UDID"
)

if [[ -n "$RESULT_BUNDLE_PATH" ]]; then
  mkdir -p "$(dirname "$RESULT_BUNDLE_PATH")"
  XCODEBUILD_CMD+=( -resultBundlePath "$RESULT_BUNDLE_PATH" )
fi

if [[ -n "$DERIVED_DATA_PATH" ]]; then
  mkdir -p "$DERIVED_DATA_PATH"
  XCODEBUILD_CMD+=( -derivedDataPath "$DERIVED_DATA_PATH" )
fi

if [[ "$IOS_TEST_ITERATIONS" -gt 1 ]]; then
  XCODEBUILD_CMD+=( -retry-tests-on-failure -test-iterations "$IOS_TEST_ITERATIONS" )
fi

XCODEBUILD_CMD+=( test )

print_failure_diagnostics() {
  if [[ -n "$RESULT_BUNDLE_PATH" && -d "$RESULT_BUNDLE_PATH" ]]; then
    echo "xcodebuild test failed. Diagnostic snippet from xcresult:"
    xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" --format json 2>/dev/null \
      | rg -n '"testStatus"|"message"|"issueType"|"name"' \
      | head -n 200 || true
  fi
}

if ! "${XCODEBUILD_CMD[@]}"; then
  print_failure_diagnostics
  exit 1
fi
