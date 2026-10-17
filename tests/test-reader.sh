#!/usr/bin/env bash
# Hardware smoke check: run with at least one trackpad connected.
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d /tmp/activatedock-reader.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
clang -fobjc-arc -fmodules -framework Cocoa \
    -I ActivateDock/Services/Gestures ActivateDock/Services/Gestures/MultitouchReader.m \
    tests/MultitouchReaderCheck.m -o "$TEST_DIR/check-reader"
"$TEST_DIR/check-reader"
