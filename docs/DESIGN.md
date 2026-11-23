# PocketServer — Design Notes

## Product goal
Use an iPhone as a local HTTP file server on the local Wi-Fi network, with a browser interface on a PC or iPad.

## MVP milestones
1. SwiftUI app with Start/Stop controls
2. Show local address and port; copy/share URL
3. Browser file listing and metadata
4. Upload/download files
5. Delete files
6. Dedicated app storage
7. Authentication, path validation and safe handling
8. GitHub Actions unsigned IPA artifact

## Architecture
- SwiftUI native UI
- Native Network framework listener (NWListener) for initial HTTP server
- Browser interface will be served by the app
- Files stored in a dedicated sandbox directory
- Build via GitHub Actions macOS runner

## Constraints
- No local Mac assumed.
- iOS does not guarantee background execution for a generic server; initial operation is foreground.
- Only dedicated app storage is accessible initially.

## Security
- Local network usage only by default; no port forwarding.
- Authentication for file management.
- Reject path traversal and keep operations within server storage.
- Never log passwords or file contents.
- Warn users to use trusted Wi-Fi networks.

## Milestones
### M0 — Setup
Repository, documentation, app skeleton and CI.

### M1 — Server lifecycle
Implemented as first development step: start/stop listener, local IPv4/port display and a basic HTTP response page. Requires device testing.

### M2 — Browser file management
Listing, metadata, upload/download/delete, refresh/search.

### M3 — Security and usability
Authentication, path safety, size limits, storage errors and clear messages.

### M4 — Polish
Transfer progress, multiple uploads, desktop drag/drop, storage usage and optional Files app import/export.

## MVP completion
Open app on iPhone, start server, visit URL from a browser on the same LAN, authenticate, upload, list, download and delete a file. Stop server cleanly in app.
