# Build Instructions

## GitHub Actions (no local Mac needed)
1. Push changes to `main`, or manually run the **iOS Build** workflow from the Actions tab.
2. Wait for the workflow to complete.
3. Download the `PocketServer-iOS-Simulator` artifact from the workflow run.

This initial workflow builds a Simulator app package only. It is not an installable signed iPhone IPA.

## Local build (Mac)
1. Install Xcode and XcodeGen.
2. Run `xcodegen generate` in the repository root.
3. Open `PocketServer.xcodeproj` in Xcode or build with xcodebuild.

## Current scope
The first project skeleton contains a SwiftUI screen. HTTP server functionality has not been implemented yet.
