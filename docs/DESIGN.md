# PocketServer — Design Notes

## Product goal
Use an iPhone as a local HTTP file server on the local Wi-Fi network, with a browser interface on a PC or iPad.

## MVP features
1. Start/stop server
2. Show/share local address
3. Browser file listing
4. Download files
5. Upload files
6. Delete files
7. Authentication, path safety and limits
8. GitHub Actions unsigned IPA build

## Architecture
- SwiftUI native UI
- Network framework NWListener
- Browser UI served by the app
- Dedicated app sandbox folder: Documents/PocketServerFiles
- GitHub Actions macOS build

## Constraints
- Local Wi-Fi use; no Internet-facing setup or port forwarding
- Foreground operation only; background server operation is not guaranteed
- Only app-managed storage is exposed

## Security
- No authentication in the current M2 partial implementation; use only trusted networks and stop the server after use
- Reject unsafe filenames and keep access within the dedicated folder
- Downloads are limited to 25 MB in this initial implementation
- Authentication and stricter request/size handling are required before broader use

## Milestones
### M0 — Setup
Repository, docs, app skeleton and CI.

### M1 — Server lifecycle (verified by user)
Start/stop, local address and basic response.

### M2 — Browser file management (in progress)
- Implemented in code: list files in dedicated storage and download individual files
- Not implemented: upload, delete, refresh/search controls
- Requires fresh build and user device/browser verification

### M3 — Security and usability
Authentication, stronger HTTP parsing, upload size limits, error handling and clearer messages.

### M4 — Polish
Transfer progress, multi-file upload, drag/drop, storage usage, optional Files app import/export.

## MVP completion
On iPhone, start server; from a browser on the same LAN, upload, list, download and delete files safely; stop server cleanly.
