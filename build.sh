#!/usr/bin/env bash
#
# Package ActivateDock for distribution.
#
# Builds the Release configuration into ./.build-package, copies the
# resulting .app into ./dist, and zips it for sharing. Pass --install
# to also drop the .app into /Applications (replacing any prior copy).
#
# Usage:
#   ./build.sh                  # build + zip into ./dist
#   ./build.sh --install        # also install to /Applications
#   ./build.sh Debug            # override config (default Release)
#

set -euo pipefail

cd "$(dirname "$0")"

readonly PROJECT="ActivateDock.xcodeproj"
readonly SCHEME="ActivateDock"
readonly BUILD_DIR="$(pwd)/.build-package"
readonly DIST_DIR="$(pwd)/dist"
readonly LOG="/tmp/activatedock-package.log"

INSTALL=0
CONFIG="Release"
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        Debug|Release) CONFIG="$arg" ;;
        *) echo "[error] unknown arg: $arg"; exit 2 ;;
    esac
done

readonly APP_BUILT="$BUILD_DIR/Build/Products/$CONFIG/$SCHEME.app"
readonly APP_DIST="$DIST_DIR/$SCHEME.app"

stop_running_app() {
    if ! pgrep -x "$SCHEME" >/dev/null; then
        return
    fi

    echo "[stop] $SCHEME"
    killall "$SCHEME" 2>/dev/null || true

    for _ in {1..20}; do
        if ! pgrep -x "$SCHEME" >/dev/null; then
            return
        fi
        sleep 0.2
    done

    echo "[stop] forcing $SCHEME"
    killall -9 "$SCHEME" 2>/dev/null || true
}

echo "[build] $SCHEME ($CONFIG)"
mkdir -p "$DIST_DIR"

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

echo "[build] OK -> $APP_BUILT"

rm -rf "$APP_DIST"
cp -R "$APP_BUILT" "$APP_DIST"

# Best-effort version pull from Info.plist (modern Xcode apps may
# leave these blank in the source plist; xcodebuild substitutes them
# at build time, so we read the built product).
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$APP_DIST/Contents/Info.plist" 2>/dev/null || echo '')"
BUILD_NUM="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
    "$APP_DIST/Contents/Info.plist" 2>/dev/null || echo '')"
TAG="${VERSION:-0.0.0}-${BUILD_NUM:-1}"
ZIP_NAME="$SCHEME-$TAG.zip"

echo "[zip] $DIST_DIR/$ZIP_NAME"
(cd "$DIST_DIR" && rm -f "$ZIP_NAME" && \
    /usr/bin/ditto -c -k --keepParent "$SCHEME.app" "$ZIP_NAME")

if [[ "$INSTALL" == "1" ]]; then
    stop_running_app
    echo "[install] /Applications/$SCHEME.app"
    rm -rf "/Applications/$SCHEME.app"
    cp -R "$APP_DIST" "/Applications/$SCHEME.app"
fi

echo
echo "[done]"
echo "  app: $APP_DIST"
echo "  zip: $DIST_DIR/$ZIP_NAME"
if [[ "$INSTALL" == "1" ]]; then
    echo "  installed: /Applications/$SCHEME.app"
else
    echo
    echo "To install:"
    echo "  ./build.sh --install"
    echo "  # or manually:"
    echo "  cp -R \"$APP_DIST\" /Applications/"
fi
