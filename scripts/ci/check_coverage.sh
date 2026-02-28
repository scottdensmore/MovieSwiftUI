#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="${COVERAGE_REPORT_DIR:-$(mktemp -d /tmp/movieswiftui-coverage.XXXXXX)}"
BACKEND_MIN="${BACKEND_MIN_LINE_COVERAGE:-76.0}"
FLUX_MIN="${FLUX_MIN_LINE_COVERAGE:-52.0}"

mkdir -p "$REPORT_DIR"
SUMMARY_FILE="$REPORT_DIR/summary.txt"
: > "$SUMMARY_FILE"

extract_line_coverage() {
  local report_text="$1"
  awk '/^TOTAL/ { gsub("%", "", $(NF-3)); print $(NF-3) }' <<<"$report_text"
}

assert_threshold() {
  local label="$1"
  local actual="$2"
  local minimum="$3"

  if awk -v actual="$actual" -v minimum="$minimum" 'BEGIN { exit !(actual + 0 >= minimum + 0) }'; then
    printf '%s line coverage %.2f%% meets threshold %.2f%%\n' "$label" "$actual" "$minimum" | tee -a "$SUMMARY_FILE"
  else
    printf '%s line coverage %.2f%% is below threshold %.2f%%\n' "$label" "$actual" "$minimum" | tee -a "$SUMMARY_FILE"
    return 1
  fi
}

run_package_coverage() {
  local label="$1"
  local relative_dir="$2"
  local test_binary_name="$3"
  local ignore_regex="$4"
  local minimum="$5"

  local abs_dir="$ROOT_DIR/$relative_dir"
  printf 'Running %s tests with coverage in %s\n' "$label" "$relative_dir" | tee -a "$SUMMARY_FILE"

  (
    cd "$abs_dir"
    swift test --enable-code-coverage

    local profdata
    profdata="$(find .build -type f -name default.profdata | head -n 1)"
    if [[ -z "$profdata" ]]; then
      echo "Could not locate default.profdata for $label" >&2
      exit 1
    fi

    local test_binary
    test_binary="$(find .build -type f -path "*debug/*.xctest/Contents/MacOS/$test_binary_name" | head -n 1)"
    if [[ -z "$test_binary" ]]; then
      test_binary="$(find .build -type f -name "$test_binary_name" -path "*.xctest/*" | head -n 1)"
    fi
    if [[ -z "$test_binary" ]]; then
      echo "Could not locate test binary $test_binary_name for $label" >&2
      exit 1
    fi

    local report
    report="$(xcrun llvm-cov report "$test_binary" -instr-profile "$profdata" -ignore-filename-regex="$ignore_regex")"
    printf '%s\n' "$report" > "$REPORT_DIR/${label// /_}-coverage.txt"

    local line_coverage
    line_coverage="$(extract_line_coverage "$report")"
    if [[ -z "$line_coverage" ]]; then
      echo "Could not parse line coverage for $label" >&2
      exit 1
    fi

    assert_threshold "$label" "$line_coverage" "$minimum"
  )
}

run_package_coverage \
  "Backend" \
  "MovieSwift/Packages/Backend" \
  "BackendPackageTests" \
  "(Tests|\\.build)" \
  "$BACKEND_MIN"

run_package_coverage \
  "MovieSwiftFluxCore" \
  "MovieSwift" \
  "MovieSwiftFluxCorePackageTests" \
  "(Tests|\\.build|Shared/flux/testing|Packages/Backend)" \
  "$FLUX_MIN"

printf 'Coverage reports written to %s\n' "$REPORT_DIR" | tee -a "$SUMMARY_FILE"
