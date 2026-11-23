# Build Instructions

## GitHub Actions (no local Mac needed)
1. Push changes to `main`, or manually run the **iOS Build** workflow from the Actions tab.
2. Wait for the workflow to complete.
3. Download the `PocketServer-unsigned-IPA` artifact from the workflow run.

The workflow builds an unsigned device IPA. Installing it requires a signing method.

## Local build (Mac)
1. Install Xcode and XcodeGen.
2. Run `xcodegen generate` in the repository root.
3. Open `PocketServer.xcodeproj` in Xcode or build with xcodebuild.

## Added features
- Share Extension embedded in the app.
- App Group `group.jp.shton13275.PocketServer` exchanges shared files and URL links.
- In-app browser uses WebKit download handling and saves files into PocketServer's folder, with a 25 MB limit.

## Verification
CI verifies compilation only. Share-sheet behavior, WebKit downloads, and real-device file transfers still need device testing.
