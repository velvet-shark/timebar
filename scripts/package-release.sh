#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_BUNDLE="$PROJECT_ROOT/dist/Timebar.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
ARCHITECTURES="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/Timebar")"
if [[ "$ARCHITECTURES" == *arm64* && "$ARCHITECTURES" == *x86_64* ]]; then
    PLATFORM="universal"
else
    PLATFORM="$ARCHITECTURES"
fi
ARCHIVE="Timebar-${VERSION}-macOS-${PLATFORM}.zip"
codesign --verify --deep --strict "$APP_BUNDLE"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$PROJECT_ROOT/dist/$ARCHIVE"
cd "$PROJECT_ROOT/dist"
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
printf 'Packaged %s\n' "$PROJECT_ROOT/dist/$ARCHIVE"
