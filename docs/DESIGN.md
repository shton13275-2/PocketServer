# PocketServer — Design Notes

## Product goal
Use an iPhone as a small HTTP file server on the local Wi-Fi network, with a web interface usable from a PC or iPad browser.

## First milestone (MVP)
1. SwiftUI app with server Start/Stop controls
2. Show host address and port; copy URL
3. Browser UI: list files and display basic metadata
4. Upload files from other devices
5. Download files to other devices
6. Delete selected files
7. Store content in the app's own Documents area
8. Basic authentication, path validation, and safe request handling
9. GitHub Actions workflow to build an unsigned iOS artifact

## Architecture (initial proposal)
- Native UI: SwiftUI
- HTTP server: embedded Swift HTTP server library (evaluate and select before implementation)
- Browser interface: bundled HTML/CSS/JavaScript served by the app
- File storage: app sandbox, dedicated server directory
- Build: GitHub Actions macOS runner, Xcode

## Constraints
- No local Mac assumed; use GitHub Actions for builds.
- iOS background execution is not a guarantee for a general-purpose server. MVP runs while the app is foregrounded and clearly reports server status.
- Access only files in the app's designated directory, plus files explicitly imported through the system picker in a later phase.

## Security requirements
- LAN-only by default; no automatic port forwarding or Internet exposure.
- Authentication required for file operations.
- Validate request paths and reject traversal attempts.
- Generate safe storage names / avoid unsafe filesystem paths.
- Restrict file operations to the dedicated server directory.
- Do not expose credentials in logs or URLs.
- Show a clear warning that devices on the same network may not all be trusted.

## Milestones
### M0 — Setup
- Repository and design document
- Xcode project skeleton
- GitHub Actions build workflow

### M1 — Server lifecycle
- Start/stop
- Address/port display
- LAN URL and copy button
- Foreground status

### M2 — Browser file management
- File listing and metadata
- Upload/download
- Delete
- Refresh and basic search

### M3 — Security and usability
- Authentication
- Path-safety tests
- Upload size / storage error handling
- Clear error messages

### M4 — Polish
- Transfer progress
- Multi-file uploads
- Drag-and-drop in desktop browsers
- Storage usage indicator
- Optional Files app import/export

## Definition of done for MVP
A user can open PocketServer on an iPhone, start the server, open the displayed URL from a browser on a device connected to the same LAN, authenticate, upload a file, see it listed, download it, and delete it. Server shutdown is reliable when stopped in the app.
