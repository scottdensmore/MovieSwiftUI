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
APP_MIN_LINE_COVERAGE="${APP_MIN_LINE_COVERAGE:-}"
APP_COVERAGE_TARGET="${APP_COVERAGE_TARGET:-MovieSwift.app}"
XCODE_ENABLE_CODE_COVERAGE="${XCODE_ENABLE_CODE_COVERAGE:-0}"
APP_COVERAGE_REPORT_DIR="${COVERAGE_REPORT_DIR:-}"

if [[ -n "$APP_MIN_LINE_COVERAGE" ]]; then
  XCODE_ENABLE_CODE_COVERAGE="1"
fi

if [[ "$XCODE_ENABLE_CODE_COVERAGE" == "1" && -z "$RESULT_BUNDLE_PATH" ]]; then
  TEMP_RESULT_BUNDLE_DIR="$(mktemp -d /tmp/movieswiftui-xcresult.XXXXXX)"
  RESULT_BUNDLE_PATH="$TEMP_RESULT_BUNDLE_DIR/MovieSwift.xcresult"
fi

if [[ -n "$APP_MIN_LINE_COVERAGE" && -z "$APP_COVERAGE_REPORT_DIR" ]]; then
  APP_COVERAGE_REPORT_DIR="$(mktemp -d /tmp/movieswiftui-app-coverage.XXXXXX)"
fi

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
if [[ "$XCODE_ENABLE_CODE_COVERAGE" == "1" ]]; then
  echo "Code coverage collection is enabled."
fi
if [[ -n "$APP_MIN_LINE_COVERAGE" ]]; then
  echo "App coverage gate: $APP_COVERAGE_TARGET >= ${APP_MIN_LINE_COVERAGE}%"
fi

XCODEBUILD_CMD=(
  xcodebuild
  -project "$PROJECT_PATH"
  -scheme "$SCHEME_NAME"
)

if [[ -n "$SIMULATOR_NAME_PREFERENCE" ]]; then
  XCODEBUILD_CMD+=( -destination "platform=iOS Simulator,name=$SIMULATOR_NAME_PREFERENCE" )
  echo "Using name-based destination: $SIMULATOR_NAME_PREFERENCE"
else
  XCODEBUILD_CMD+=( -destination "id=$SIMULATOR_UDID" )
fi

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

if [[ "$XCODE_ENABLE_CODE_COVERAGE" == "1" ]]; then
  XCODEBUILD_CMD+=( -enableCodeCoverage YES )
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

assert_threshold() {
  local label="$1"
  local actual="$2"
  local minimum="$3"

  if awk -v actual="$actual" -v minimum="$minimum" 'BEGIN { exit !(actual + 0 >= minimum + 0) }'; then
    printf '%s line coverage %.2f%% meets threshold %.2f%%\n' "$label" "$actual" "$minimum"
  else
    printf '%s line coverage %.2f%% is below threshold %.2f%%\n' "$label" "$actual" "$minimum" >&2
    return 1
  fi
}

extract_target_line_coverage() {
  local report_text="$1"
  local target_name="$2"
  awk -v target_name="$target_name" '
    $1 == target_name {
      gsub("%", "", $2)
      print $2
      exit
    }
  ' <<<"$report_text"
}

evaluate_app_coverage() {
  if [[ -z "$RESULT_BUNDLE_PATH" || ! -d "$RESULT_BUNDLE_PATH" ]]; then
    if [[ -n "$APP_MIN_LINE_COVERAGE" ]]; then
      echo "App coverage gating requires a valid xcresult bundle." >&2
      return 1
    fi
    return 0
  fi

  local coverage_report
  coverage_report="$(xcrun xccov view --report "$RESULT_BUNDLE_PATH" 2>/dev/null || true)"
  if [[ -z "$coverage_report" ]]; then
    if [[ -n "$APP_MIN_LINE_COVERAGE" ]]; then
      echo "Failed to read app coverage report from $RESULT_BUNDLE_PATH." >&2
      return 1
    fi
    return 0
  fi

  if [[ -n "$APP_COVERAGE_REPORT_DIR" ]]; then
    mkdir -p "$APP_COVERAGE_REPORT_DIR"
    printf '%s\n' "$coverage_report" > "$APP_COVERAGE_REPORT_DIR/app-coverage.txt"
  fi

  local target_coverage
  target_coverage="$(extract_target_line_coverage "$coverage_report" "$APP_COVERAGE_TARGET")"
  if [[ -z "$target_coverage" && "$APP_COVERAGE_TARGET" == *.app ]]; then
    target_coverage="$(extract_target_line_coverage "$coverage_report" "${APP_COVERAGE_TARGET%.app}")"
  fi
  if [[ -z "$target_coverage" && "$APP_COVERAGE_TARGET" != *.app ]]; then
    target_coverage="$(extract_target_line_coverage "$coverage_report" "${APP_COVERAGE_TARGET}.app")"
  fi

  if [[ -z "$target_coverage" ]]; then
    if [[ -n "$APP_MIN_LINE_COVERAGE" ]]; then
      echo "Could not locate coverage target '$APP_COVERAGE_TARGET' in xccov report." >&2
      return 1
    fi
    return 0
  fi

  printf 'App target %s line coverage %.2f%%\n' "$APP_COVERAGE_TARGET" "$target_coverage"
  if [[ -n "$APP_MIN_LINE_COVERAGE" ]]; then
    assert_threshold "App target $APP_COVERAGE_TARGET" "$target_coverage" "$APP_MIN_LINE_COVERAGE"
  fi
}

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

if [[ "$XCODE_ENABLE_CODE_COVERAGE" == "1" || -n "$APP_MIN_LINE_COVERAGE" ]]; then
  evaluate_app_coverage
fi
