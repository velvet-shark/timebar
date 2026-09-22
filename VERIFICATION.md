# Verification

Version 1.0.1 (build 2) was built and its distribution artifacts verified on 2026-09-22 with macOS 27.0 on Apple silicon, Xcode 27.0, and Apple Swift 6.4. Existing interactive coverage is listed below.

## Build and automated checks

- `swift test`: 28 tests passed, including five parameterized invalid-duration cases.
- Native release and universal release builds succeeded.
- The universal binary contains `arm64` and `x86_64` architectures.
- Bundle metadata sets macOS 14.0 as the minimum OS.
- The build validates Info.plist and verifies its signature. Local builds use an ad hoc signature by default; the release uses Developer ID Application signing with hardened runtime and a secure timestamp.
- Extracted the release ZIP and copied the app from the mounted DMG, then verified both signatures, both architectures, and the macOS 14 deployment target. The app includes the MIT license.
- No third-party packages are required.

Tests cover expiration after delayed callbacks and sleep, pause/resume, stop/restart, timer replacement, relaunch recovery, malformed persistence, custom duration bounds, leading-zero editing, component stepping, countdown rounding, appearance persistence, one-pixel hairlines, and normal/notched/offset display geometry.

Refresh-policy regression tests cover no polling while idle or paused, adaptive pixel intervals, visible second counters, short-timer completion deadlines, invalid display widths, and suppression of visual updates while displays sleep.

## Signing and notarization

- Apple accepted both the app and DMG submissions with no issues reported.
- Notarization tickets were stapled to the app and DMG and validated successfully.
- Gatekeeper accepted the final DMG as `Notarized Developer ID`.
- The app copied from the DMG and the app extracted from the final ZIP both passed signature verification, ticket validation, Gatekeeper assessment, and `syspolicy_check distribution`.
- The DMG contains an Applications shortcut pointing to `/Applications`.
- Disk-image integrity and the final SHA-256 checksums passed.

## Interactive checks

- Presets start immediately and close the menu; the progress line remains visible.
- Remaining time and percentage update in the menu.
- Pause/resume controls preserve remaining time. Quit/relaunch restores a running deadline.
- Custom duration replaces the initial zero, supports arrows and steppers, and retains entered values when the menu is destroyed and reopened.
- The half-point setting renders a visible one-pixel line at Retina scale.
- The Custom color picker fits beside the six preset swatches.
- Focused controls do not draw the former blue focus outlines.
- Appearance presets, custom colors, thickness, opacity, optional track, and menu countdown controls have been exercised.
- An isolated app preference domain was used for optimization checks, preserving the existing timer in the normal app.
- A three-second custom timer started with Return, closed the menu, and transitioned to finished at its deadline.

Resource measurements and their limitations are recorded in [Performance](docs/PERFORMANCE.md).

## Coverage limits

macOS 14 and macOS 26 are within the deployment target, but interactive checks used macOS 27.0. The Intel binary was compiled, not tested on Intel hardware.

Physical sleep/wake, multiple connected displays, full-screen Spaces, display hot-plugging, and a notched MacBook were not exercised interactively. Timing recovery and display-coordinate logic have automated coverage. The line uses nonactivating, click-through AppKit panels; desktop-wide click-through and full-screen behavior still need hardware coverage.

These checks do not establish laptop battery life or guarantee a fixed resource footprint across machines. Version 1.0.1 is signed and notarized, with Gatekeeper checks performed on the build Mac. A browser download and first launch on a fresh Mac have not been tested.
