#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

BUILD_ARGS=(-c release)
if [[ "${1:-}" == "--universal" ]]; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64)
elif [[ $# -gt 0 ]]; then
    printf 'Usage: %s [--universal]\n' "$0" >&2
    exit 1
fi
swift build "${BUILD_ARGS[@]}" --product Timebar
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
APP_BUNDLE="$PROJECT_ROOT/dist/Timebar.app"
ICONSET="$PROJECT_ROOT/.build/Timebar.iconset"

mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$ICONSET"
cp "$BIN_DIR/Timebar" "$APP_BUNDLE/Contents/MacOS/Timebar"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp LICENSE "$APP_BUNDLE/Contents/Resources/LICENSE"
swift scripts/create-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/Timebar.icns"
plutil -lint "$APP_BUNDLE/Contents/Info.plist"
SIGNING_IDENTITY="${TIMEBAR_SIGNING_IDENTITY:--}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP_BUNDLE"
else
    codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$APP_BUNDLE"
fi
codesign --verify --deep --strict "$APP_BUNDLE"
printf '\nBuilt %s\n' "$APP_BUNDLE"
