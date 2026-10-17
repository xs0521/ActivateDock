#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d /tmp/activatedock-gestures.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
clang -fobjc-arc -fmodules \
    -c ActivateDock/Services/Gestures/MultitouchReader.m -o "$TEST_DIR/reader.o"
swiftc -import-objc-header ActivateDock/ActivateDock-Bridging-Header.h \
    ActivateDock/Services/Gestures/FourFingerSwipeDetector.swift \
    tests/FourFingerSwipeTests.swift "$TEST_DIR/reader.o" -framework Cocoa \
    -o "$TEST_DIR/test-gestures"
"$TEST_DIR/test-gestures"
