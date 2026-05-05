#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

readonly PROJECT="ActivateDock.xcodeproj"
readonly SCHEME="ActivateDock"
readonly CONFIG="${1:-Debug}"
readonly BUILD_DIR="$(pwd)/.build"
readonly APP_PATH="$BUILD_DIR/Build/Products/$CONFIG/$SCHEME.app"
readonly LOG="/tmp/activatedock-build.log"

echo "[build] $SCHEME ($CONFIG)"
if ! xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'platform=macOS' \
    build > "$LOG" 2>&1; then
    echo "[build] FAILED. Tail of $LOG:"
    tail -40 "$LOG"
    exit 1
fi

echo "[build] OK -> $APP_PATH"

killall "$SCHEME" 2>/dev/null || true

echo "[run] launching"
open "$APP_PATH"
