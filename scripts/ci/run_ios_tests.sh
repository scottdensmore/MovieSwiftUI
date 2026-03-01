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
SIMULATOR_NAME_PREFERENCE="${IOS_SIMULATOR_NAME:-}"
ONLY_TESTING="${XCODE_ONLY_TESTING:-}"

if [[ "$SIMULATOR_FAMILY" != "iPhone" && "$SIMULATOR_FAMILY" != "iPad" ]]; then
  echo "Unsupported IOS_SIMULATOR_FAMILY '$SIMULATOR_FAMILY'; falling back to iPhone."
  SIMULATOR_FAMILY="iPhone"
fi

pick_simulator_uuid_from_simctl() {
  local family="$1"
  local preferred_name="${2:-}"
  xcrun simctl list devices available | awk -v family="$family" -v preferred_name="$preferred_name" '
    $0 ~ family {
      if (preferred_name != "" && index($0, preferred_name) == 0) {
        next
      }
      if (match($0, /[0-9A-F-]{36}/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  '
}

simulator_udid_is_available() {
  local udid="$1"
  [[ -n "$udid" ]] || return 1
  xcrun simctl list devices available | grep -Fq "$udid"
}

if [[ -z "$SIMULATOR_UDID" ]]; then
  SHOW_DESTINATIONS="$(
    xcodebuild \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME_NAME" \
      -showdestinations 2>/dev/null || true
  )"
  SIMULATOR_UDID="$(
    awk -v family="$SIMULATOR_FAMILY" -v preferred_name="$SIMULATOR_NAME_PREFERENCE" '
      /platform:iOS Simulator/ && $0 ~ ("name:" family) && $0 !~ /placeholder/ && $0 !~ /error:/ {
        if (preferred_name != "" && index($0, "name:" preferred_name) == 0) {
          next
        }
        id = ""
        os = "0"
        if (match($0, /id:[^,}]+/)) {
          id = substr($0, RSTART + 3, RLENGTH - 3)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
        }
        if (match($0, /OS:[^,}]+/)) {
          os = substr($0, RSTART + 3, RLENGTH - 3)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", os)
        }
        split(os, versionParts, ".")
        score = (versionParts[1] + 0) * 10000 + (versionParts[2] + 0) * 100 + (versionParts[3] + 0)
        if (id != "" && score >= bestScore) {
          bestScore = score
          bestId = id
        }
      }
      END {
        if (bestId != "") {
          print bestId
        }
      }
    ' <<<"$SHOW_DESTINATIONS"
  )"
fi

if [[ -n "$SIMULATOR_UDID" ]] && ! simulator_udid_is_available "$SIMULATOR_UDID"; then
  echo "Ignoring simulator selected from showdestinations because it is not available via simctl: $SIMULATOR_UDID"
  SIMULATOR_UDID=""
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(pick_simulator_uuid_from_simctl "$SIMULATOR_FAMILY" "$SIMULATOR_NAME_PREFERENCE")"
fi

if [[ -z "$SIMULATOR_UDID" && -n "$SIMULATOR_NAME_PREFERENCE" ]]; then
  SIMULATOR_UDID="$(pick_simulator_uuid_from_simctl "$SIMULATOR_FAMILY")"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(pick_simulator_uuid_from_simctl "iPhone" "$SIMULATOR_NAME_PREFERENCE")"
fi

if [[ -z "$SIMULATOR_UDID" && -n "$SIMULATOR_NAME_PREFERENCE" ]]; then
  SIMULATOR_UDID="$(pick_simulator_uuid_from_simctl "iPhone")"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(pick_simulator_uuid_from_simctl "iPad" "$SIMULATOR_NAME_PREFERENCE")"
fi

if [[ -z "$SIMULATOR_UDID" && -n "$SIMULATOR_NAME_PREFERENCE" ]]; then
  SIMULATOR_UDID="$(pick_simulator_uuid_from_simctl "iPad")"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(
    awk '
      /platform:iOS Simulator/ && $0 !~ /placeholder/ {
        id = ""
        os = "0"
        if (match($0, /id:[^,}]+/)) {
          id = substr($0, RSTART + 3, RLENGTH - 3)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
        }
        if (match($0, /OS:[^,}]+/)) {
          os = substr($0, RSTART + 3, RLENGTH - 3)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", os)
        }
        split(os, versionParts, ".")
        score = (versionParts[1] + 0) * 10000 + (versionParts[2] + 0) * 100 + (versionParts[3] + 0)
        if (id != "" && score >= bestScore) {
          bestScore = score
          bestId = id
        }
      }
      END {
        if (bestId != "") {
          print bestId
        }
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
if [[ -n "$SIMULATOR_NAME_PREFERENCE" ]]; then
  echo "Preferred simulator name: $SIMULATOR_NAME_PREFERENCE"
fi
echo "Test iterations: $IOS_TEST_ITERATIONS"
if [[ -n "$ONLY_TESTING" ]]; then
  echo "Only testing: $ONLY_TESTING"
fi

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

if [[ -n "$ONLY_TESTING" ]]; then
  IFS=',' read -r -a ONLY_TESTING_TARGETS <<<"$ONLY_TESTING"
  for target in "${ONLY_TESTING_TARGETS[@]}"; do
    trimmed_target="$(echo "$target" | xargs)"
    if [[ -n "$trimmed_target" ]]; then
      XCODEBUILD_CMD+=( "-only-testing:$trimmed_target" )
    fi
  done
fi

XCODEBUILD_CMD+=( test )

print_failure_diagnostics() {
  if [[ -n "$RESULT_BUNDLE_PATH" && -d "$RESULT_BUNDLE_PATH" ]]; then
    echo "xcodebuild test failed. Diagnostic snippet from xcresult:"
    if command -v rg >/dev/null 2>&1; then
      xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" --format json 2>/dev/null \
        | rg -n '"testStatus"|"message"|"issueType"|"name"' \
        | head -n 200 || true
    else
      xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" --format json 2>/dev/null \
        | grep -En '"testStatus"|"message"|"issueType"|"name"' \
        | head -n 200 || true
    fi
  fi
}

if ! "${XCODEBUILD_CMD[@]}"; then
  print_failure_diagnostics
  exit 1
fi
