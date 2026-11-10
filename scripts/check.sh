#!/bin/bash
# Builds the app, runs the app tests, and runs the StoryLoomKit package tests.
# Exits non-zero on the first failure. Run from anywhere.
#
#   scripts/check.sh
#
# Build output goes under $STORYLOOM_CHECK_DIR (default: $TMPDIR/storyloom-check),
# never into the repository. Full logs are kept there; on failure the tail of
# the failing step is printed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${STORYLOOM_CHECK_DIR:-${TMPDIR:-/tmp}/storyloom-check}"
DERIVED="$WORK/DerivedData"
LOGS="$WORK/logs"
mkdir -p "$LOGS"

PROJECT="$ROOT/StoryLoom.xcodeproj"
CONTAINER_PREFS="$HOME/Library/Containers/io.storyloom.dev/Data/Library/Preferences"

step() { printf '\n==> %s\n' "$1"; }

run() {
    local name="$1"; shift
    local log="$LOGS/$name.log"
    if "$@" >"$log" 2>&1; then
        return 0
    fi
    echo "FAILED: $name (full log: $log)" >&2
    tail -n 40 "$log" >&2
    exit 1
}

# Leftover test defaults from before this run, so only new ones count.
stray_defaults() { ls "$CONTAINER_PREFS" 2>/dev/null | grep -E '^StoryLoomTests\..*\.plist$' || true; }
BEFORE="$(stray_defaults)"

step "Build app (Debug)"
run build xcodebuild -project "$PROJECT" -scheme StoryLoom -configuration Debug \
    -derivedDataPath "$DERIVED" build
grep -E "warning:" "$LOGS/build.log" | grep -v "appintentsmetadataprocessor" | sort -u || true

APP_PLIST="$DERIVED/Build/Products/Debug/StoryLoom.app/Contents/Info.plist"
BUNDLE_ID="$(defaults read "$APP_PLIST" CFBundleIdentifier)"
echo "Debug bundle id: $BUNDLE_ID"
if [ "$BUNDLE_ID" != "io.storyloom.dev" ]; then
    echo "FAILED: Debug build must use io.storyloom.dev, not the release bundle id." >&2
    exit 1
fi

step "App tests (StoryLoomTests)"
run app-tests xcodebuild -project "$PROJECT" -scheme StoryLoom -configuration Debug \
    -derivedDataPath "$DERIVED" test
grep -E "Test run|Executed|\*\* TEST" "$LOGS/app-tests.log" | tail -n 3 || true

AFTER="$(stray_defaults)"
if [ "$BEFORE" != "$AFTER" ]; then
    echo "FAILED: the app tests left UserDefaults files behind:" >&2
    diff <(echo "$BEFORE") <(echo "$AFTER") >&2 || true
    exit 1
fi

step "StoryLoomKit tests (swift test)"
run kit-tests swift test --package-path "$ROOT/StoryLoomKit" --scratch-path "$WORK/kit-build"
grep -E "Test run with|error:|warning:" "$LOGS/kit-tests.log" | tail -n 5 || true

step "storyloom --version"
run kit-cli swift run --package-path "$ROOT/StoryLoomKit" --scratch-path "$WORK/kit-build" storyloom --version
tail -n 1 "$LOGS/kit-cli.log"

printf '\nAll checks passed.\n'
