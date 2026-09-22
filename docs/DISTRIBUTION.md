# Distribution

## Current downloads

The public app download is a single Developer ID signed and Apple-notarized DMG. The app and DMG have stapled notarization tickets. Both Apple silicon and Intel binaries are included; macOS 14 or later is required.

ZIP files are intermediate build artifacts used to submit the app to Apple. Keep checksums and verification logs locally; upload only the final DMG to the release. GitHub automatically adds its own source-code ZIP and tar.gz links, separate from uploaded release assets.

Source, tests, build scripts, and the MIT license are public. Updates use the same download-and-replace process. There is no automatic updater or App Store listing.

## Release process and triggers

Releases are currently prepared on a Mac with the Developer ID certificate, its private key, and the `Timebar` notarization Keychain profile. The scripts automate individual steps; there is no automatic release workflow or one-command release trigger.

- A push to `main` or a pull request runs tests, builds a universal app with an ad hoc signature, and saves CI artifacts. It does not perform Developer ID signing, notarization, or publishing.
- Pushing a version tag or creating a GitHub release does not build a DMG. A release publishes the files attached to it.
- `scripts/build-app.sh --universal` compiles the app for both architectures. With `TIMEBAR_SIGNING_IDENTITY` set, it signs the app with Developer ID, hardened runtime, and a secure timestamp.
- `scripts/package-dmg.sh` copies the notarized app and an Applications shortcut into a compressed disk image using `hdiutil`, then signs the DMG with the same identity. It requires the app to have a valid stapled ticket and pass Gatekeeper assessment.
- Notarization, ticket stapling, and GitHub publication are explicit commands, shown below.

For each new version, update `CFBundleShortVersionString` and increment `CFBundleVersion` in `Resources/Info.plist`. Update the changelog and README download link, then test, build, sign, notarize, and verify the new artifacts. Reuse the configured certificate and Keychain profile while they remain valid.

## Local builds

Local builds use an ad hoc signature unless `TIMEBAR_SIGNING_IDENTITY` is set. They are separate from the signed and notarized release downloads.

```sh
swift test
./scripts/build-app.sh --universal
./scripts/package-release.sh
```

The ZIP is an intermediate artifact, not a public download. The MIT license is included inside the app's Resources directory.

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

Run these commands from the repository root after setting the new version. Publishing the verified DMG is a separate step.

```sh
export TIMEBAR_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
APP_ZIP="dist/Timebar-${VERSION}-macOS-universal.zip"
DMG="dist/Timebar-${VERSION}-macOS-universal.dmg"
swift test
./scripts/build-app.sh --universal
./scripts/package-release.sh
xcrun notarytool submit "$APP_ZIP" --keychain-profile Timebar --wait
```

Continue only when the submission status is `Accepted`. Save the submission ID and inspect Apple's log, including any warnings:

```sh
xcrun notarytool log APP_SUBMISSION_ID --keychain-profile Timebar dist/notarization-app-log.json
xcrun stapler staple dist/Timebar.app
xcrun stapler validate dist/Timebar.app
codesign --verify --deep --strict dist/Timebar.app
spctl --assess --type execute --verbose dist/Timebar.app
syspolicy_check distribution dist/Timebar.app
```

Replace `APP_SUBMISSION_ID` with the ID Apple returned. The ZIP has served its purpose once Apple accepts the app. The stapled app is what goes into the DMG. Changing the app after signing requires signing and notarization again.

## Prepare the drag-to-Applications DMG

The DMG script requires a Developer ID signed app with a valid stapled ticket and passing Gatekeeper assessment. It copies the app into a compressed disk image alongside an Applications shortcut, then signs the image with the same identity.

```sh
./scripts/package-dmg.sh
xcrun notarytool submit "$DMG" --keychain-profile Timebar --wait
```

After the DMG submission is `Accepted`, inspect its log, staple the ticket, and record a checksum for local verification:

```sh
xcrun notarytool log DMG_SUBMISSION_ID --keychain-profile Timebar dist/notarization-dmg-log.json
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
codesign --verify --strict "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
shasum -a 256 "$DMG" > "$DMG.sha256"
```

Replace `DMG_SUBMISSION_ID` with the second submission ID. Mount and inspect the final DMG, and verify the app copied from it. Before publishing, also test a real browser download on a clean Mac or test environment so Gatekeeper evaluates the downloaded artifact rather than the development copy. A normal first-launch confirmation can still appear.

For local packaging checks before credentials are available, `./scripts/package-dmg.sh --unsigned-preview` writes an explicitly named preview into `.build/`. That preview is not signed for distribution or notarized and must not be uploaded as a release asset.

Keep private keys, passwords, and notarization credentials out of the repository. See Apple's [Developer ID guide](https://developer.apple.com/developer-id/) and [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Publish on GitHub

Commit and push the reviewed source, version, and documentation changes to `main`. Wait for CI to pass. The release tag must point to the source used to build the signed app; do not rebuild or modify that app after notarization.

Write release notes containing one opening paragraph and a Changes section. Keep installation instructions in the README and verification details in the maintainer documentation and local logs.

From the verified release commit, create the tag and a draft containing only the DMG. Replace `RELEASE_NOTES_FILE` with the path to the prepared Markdown notes:

```sh
TAG="v${VERSION}"
git tag -a "$TAG" -m "Timebar ${VERSION}"
git push origin "$TAG"
gh release create "$TAG" "$DMG" --verify-tag --draft \
  --title "Timebar ${VERSION}" --notes-file RELEASE_NOTES_FILE
```

Verify the uploaded DMG matches the local file, then publish:

```sh
gh release edit "$TAG" --draft=false --latest --verify-tag
```

Test the public README download link and the downloaded DMG's signature and ticket. GitHub's automatic source archives remain visible alongside the DMG; see [About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
