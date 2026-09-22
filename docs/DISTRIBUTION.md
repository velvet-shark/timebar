# Distribution

## Current downloads

Version 1.0.1 provides a Developer ID signed and Apple-notarized DMG for drag-to-Applications installation, plus a notarized ZIP alternative. The app and DMG have stapled notarization tickets, and both downloads have SHA-256 checksums. Both Apple silicon and Intel binaries are included; macOS 14 or later is required.

Source, tests, build scripts, and the MIT license are public. Updates use the same download-and-replace process. There is no automatic updater or App Store listing.

## Local builds

Local builds use an ad hoc signature unless `TIMEBAR_SIGNING_IDENTITY` is set. They are separate from the signed and notarized release downloads.

```sh
swift test
./scripts/build-app.sh --universal
./scripts/package-release.sh
```

Validate the extracted ZIP as well as the original bundle before publishing. The MIT license is included inside the app's Resources directory.

## Local signing setup

A paid Apple Developer Program membership provides access to Developer ID signing. The release machine must also have a valid **Developer ID Application** certificate and its private key. An Apple Development certificate is not a substitute.

Create the Developer ID Application identity through Xcode's account settings or the Apple Developer certificate portal. The matching private key must be in the release machine's Keychain.

Create an app-specific password through your Apple Account, then store it in a local Keychain profile. The command prompts securely for the password:

```sh
xcrun notarytool store-credentials Timebar \
  --apple-id 'YOUR_APPLE_ACCOUNT_EMAIL' \
  --team-id 'YOUR_DEVELOPER_TEAM_ID'
```

Do not pass the password on the command line or save it in the repository.

## Prepare a notarized app

These commands prepare version 1.0.1 locally and submit it to Apple. Publishing the verified artifacts as a GitHub release is a separate step. Adjust the version and filenames for future releases.

```sh
export TIMEBAR_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
swift test
./scripts/build-app.sh --universal
./scripts/package-release.sh
xcrun notarytool submit dist/Timebar-1.0.1-macOS-universal.zip --keychain-profile Timebar --wait
```

Continue only when the submission status is `Accepted`. Save the submission ID and inspect Apple's log, including any warnings:

```sh
xcrun notarytool log APP_SUBMISSION_ID --keychain-profile Timebar dist/notarization-app-log.json
xcrun stapler staple dist/Timebar.app
xcrun stapler validate dist/Timebar.app
codesign --verify --deep --strict dist/Timebar.app
spctl --assess --type execute --verbose dist/Timebar.app
syspolicy_check distribution dist/Timebar.app
./scripts/package-release.sh
```

Replace `APP_SUBMISSION_ID` with the ID Apple returned. The last packaging step is required: it replaces the pre-notarization ZIP with one containing the stapled app and refreshes the checksum. Adjust filenames when the version changes. The signing script enables hardened runtime and secure timestamps when a signing identity is provided. Changing the app after signing requires signing and notarization again.

## Prepare the drag-to-Applications DMG

The DMG script requires a Developer ID signed app with a valid stapled ticket and passing Gatekeeper assessment. It copies the app into a compressed disk image alongside an Applications shortcut, then signs the image with the same identity.

```sh
./scripts/package-dmg.sh
xcrun notarytool submit dist/Timebar-1.0.1-macOS-universal.dmg --keychain-profile Timebar --wait
```

After the DMG submission is `Accepted`, inspect its log, staple the ticket, and generate the checksum for the final file:

```sh
xcrun notarytool log DMG_SUBMISSION_ID --keychain-profile Timebar dist/notarization-dmg-log.json
xcrun stapler staple dist/Timebar-1.0.1-macOS-universal.dmg
xcrun stapler validate dist/Timebar-1.0.1-macOS-universal.dmg
codesign --verify --strict dist/Timebar-1.0.1-macOS-universal.dmg
spctl --assess --type open --context context:primary-signature --verbose dist/Timebar-1.0.1-macOS-universal.dmg
cd dist
shasum -a 256 Timebar-1.0.1-macOS-universal.dmg > Timebar-1.0.1-macOS-universal.dmg.sha256
```

Replace `DMG_SUBMISSION_ID` with the second submission ID. Mount and inspect the final DMG, and verify the app copied from it. Before publishing, also test a real browser download on a clean Mac or test environment so Gatekeeper evaluates the downloaded artifact rather than the development copy. A normal first-launch confirmation can still appear.

For local packaging checks before credentials are available, `./scripts/package-dmg.sh --unsigned-preview` writes an explicitly named preview into `.build/`. That preview is not signed for distribution or notarized and must not be uploaded as a release asset.

Keep private keys, passwords, and notarization credentials out of the repository. See Apple's [Developer ID guide](https://developer.apple.com/developer-id/) and [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

A notarized ZIP also supports a normal drag-to-Applications installation. The Mac App Store is a separate distribution choice that requires sandboxing and App Review.
