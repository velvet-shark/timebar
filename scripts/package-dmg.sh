#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

PREVIEW=false
if [[ "${1:-}" == "--unsigned-preview" && $# -eq 1 ]]; then
    PREVIEW=true
elif [[ $# -gt 0 ]]; then
    printf 'Usage: %s [--unsigned-preview]\n' "$0" >&2
    exit 1
fi

APP_BUNDLE="$PROJECT_ROOT/dist/Timebar.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
    printf 'Build dist/Timebar.app first.\n' >&2
    exit 1
fi
codesign --verify --deep --strict "$APP_BUNDLE"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
ARCHITECTURES="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/Timebar")"
if [[ "$ARCHITECTURES" == *arm64* && "$ARCHITECTURES" == *x86_64* ]]; then
    PLATFORM="universal"
elif [[ "$ARCHITECTURES" == "arm64" || "$ARCHITECTURES" == "x86_64" ]]; then
    PLATFORM="$ARCHITECTURES"
else
    printf 'Unsupported architectures: %s\n' "$ARCHITECTURES" >&2
    exit 1
fi

mkdir -p "$PROJECT_ROOT/.build"
if [[ "$PREVIEW" == true ]]; then
    DMG="$PROJECT_ROOT/.build/Timebar-${VERSION}-macOS-${PLATFORM}-preview.dmg"
else
    : "${TIMEBAR_SIGNING_IDENTITY:?Set TIMEBAR_SIGNING_IDENTITY to your Developer ID Application identity.}"
    SIGNATURE="$(codesign --display --verbose=4 "$APP_BUNDLE" 2>&1)"
    if ! printf '%s\n' "$SIGNATURE" | /usr/bin/grep -q '^Authority=Developer ID Application:'; then
        printf 'The app must be signed with Developer ID Application before packaging.\n' >&2
        exit 1
    fi
    xcrun stapler validate "$APP_BUNDLE"
    spctl --assess --type execute --verbose "$APP_BUNDLE"
    DMG="$PROJECT_ROOT/dist/Timebar-${VERSION}-macOS-${PLATFORM}.dmg"
fi

STAGING="$(mktemp -d "$PROJECT_ROOT/.build/timebar-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP_BUNDLE" "$STAGING/Timebar.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname Timebar -srcfolder "$STAGING" -format UDZO -ov "$DMG"
hdiutil verify "$DMG"

if [[ "$PREVIEW" == true ]]; then
    printf '\nUnsigned layout preview only, not for distribution: %s\n' "$DMG"
else
    codesign --force --sign "$TIMEBAR_SIGNING_IDENTITY" --timestamp "$DMG"
    codesign --verify --strict "$DMG"
    printf '\nSigned DMG: %s\n' "$DMG"
    printf 'Next: notarize and staple the DMG, then generate its SHA-256 checksum.\n'
fi
