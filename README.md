# PocketServer

PocketServer is an iOS app that turns an iPhone into a local-network file server. The first milestone is a foreground-running server that lets another device's browser upload and download files.

## MVP goals
- Start/stop an HTTP server from the iOS app
- Show the local URL and offer a copy action
- Browser-based file listing
- Upload and download files
- Delete files
- Store files in app-local storage
- Basic authentication and safe path handling
- Build an unsigned iOS artifact with GitHub Actions

## Non-goals for the first milestone
- Internet-facing server or port forwarding
- Always-on background server guarantees
- Arbitrary iOS file access without user selection
- Remote control of iOS or other apps

## Development
Swift and SwiftUI. The server is initially designed to operate while the app is in the foreground, since iOS may suspend apps in the background.

See [Design](docs/DESIGN.md).

## Security
Default to local network use; require authentication; validate paths and prevent directory traversal; do not log credentials or file contents. Wi-Fi access does not guarantee that all devices are trusted.

## Status
Repository setup is complete. Implementation and device testing have not yet started.
