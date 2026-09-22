# Distribution

## Version 1.0

The GitHub release contains a universal app bundle in a ZIP and a SHA-256 checksum. It is ad hoc signed, not Developer ID signed or notarized. Source, tests, build scripts, and the MIT license are public. No installer, automatic updater, or App Store listing is included.

```sh
swift test
./scripts/build-app.sh --universal
./scripts/package-release.sh
```

Validate the extracted ZIP as well as the original bundle before publishing. The MIT license is included inside the app's Resources directory.

## Future notarized downloads

A paid Apple Developer Program membership provides access to Developer ID signing. The release machine must also have a valid **Developer ID Application** certificate and its private key. An Apple Development certificate is not a substitute.

After configuring that identity and a notarytool Keychain profile locally:

```sh
TIMEBAR_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./scripts/build-app.sh --universal
./scripts/package-release.sh
xcrun notarytool submit dist/Timebar-1.0.0-macOS-universal.zip --keychain-profile Timebar --wait
xcrun stapler staple dist/Timebar.app
xcrun stapler validate dist/Timebar.app
spctl --assess --type execute --verbose dist/Timebar.app
./scripts/package-release.sh
```

The last packaging step is required: it replaces the pre-notarization ZIP with one containing the stapled app and refreshes the checksum. Adjust the filename when the version changes. The signing script enables hardened runtime and secure timestamps when a signing identity is provided.

Keep private keys, passwords, and notarization credentials out of the repository. See Apple's [Developer ID guide](https://developer.apple.com/developer-id/) and [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

A notarized ZIP already supports a normal drag-to-Applications installation. A DMG can add a more familiar presentation later; the Mac App Store is a separate distribution choice that also requires sandboxing and App Review.
