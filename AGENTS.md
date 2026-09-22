# Timebar

Native macOS menu bar timer. Swift 6, SwiftUI for the popover, AppKit for the status item and display overlays. Minimum macOS 14. No external dependencies.

- Keep timer arithmetic and persistence models in `TimebarCore`, independent of UI and real clocks.
- Keep AppKit and observable UI state on the main actor.
- The overlay must never receive mouse events, activate the app, or become a key window.
- Use deadline-based timing so sleep and delayed timer callbacks cannot introduce drift.
- Run `swift test` and `./scripts/build-app.sh` after behavior changes.
- Build output is `dist/Timebar.app`. `./scripts/run.sh` builds and opens it.
- Do not publish, sign with a developer identity, or change login items without a specific user request.
