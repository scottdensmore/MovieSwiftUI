#!/usr/bin/env bash
#
# Stamps CFBundleVersion in the built app's Info.plist with the git commit
# count, so every build is uniquely and monotonically numbered without anyone
# hand-editing CURRENT_PROJECT_VERSION. Run as a "Run Script" build phase on
# each app target (after Info.plist processing, before code signing).
#
# The marketing version (CFBundleShortVersionString) is NOT touched here — that
# stays the single, human-bumped MARKETING_VERSION build setting.
#
# Sandboxing: the app targets set ENABLE_USER_SCRIPT_SANDBOXING = NO so this
# phase can write the built Info.plist. Declaring the plist as an outputPaths
# entry isn't an option — it collides with Xcode's own Info.plist processing
# ("Multiple commands produce …/Info.plist") — so the write happens unsandboxed.
#
# Falls back to CURRENT_PROJECT_VERSION (then 1) when git can't produce a count
# — e.g. building from a source export, or a shallow CI checkout — so a build
# never fails on account of versioning. (For real release builds, CI must do a
# full clone — `fetch-depth: 0` — or the count will be the shallow depth.)

set -euo pipefail

plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
if [ ! -f "$plist" ]; then
    echo "note: set_build_number: Info.plist not found at $plist; skipping"
    exit 0
fi

build_number=""
if command -v git >/dev/null 2>&1; then
    build_number="$(git -C "${SRCROOT}" rev-list --count HEAD 2>/dev/null || true)"
fi

# Accept only a positive integer; otherwise fall back so we never stamp a blank,
# zero, or warning-polluted value (any of which App Store Connect rejects).
if ! [[ "$build_number" =~ ^[1-9][0-9]*$ ]]; then
    build_number="${CURRENT_PROJECT_VERSION:-1}"
    echo "note: set_build_number: git count unavailable; using fallback $build_number"
fi

# PlistBuddy's `Set` only updates an existing key, so fall back to `Add` for the
# (rare) case where CFBundleVersion isn't already present in the processed plist.
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $build_number" "$plist"

echo "note: set_build_number: CFBundleVersion = $build_number"
