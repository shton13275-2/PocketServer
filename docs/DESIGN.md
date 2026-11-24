# PocketServer — Design Notes

## Product goal
Use an iPhone as a local HTTP file server on the local Wi-Fi network, with a browser interface on a PC or iPad, plus native file management.

## Features
1. Start/stop server and share local address
2. Browser file listing and downloads
3. Browser single-file upload and deletion
4. Native Files picker import (multi-select)
5. Native URL download (HTTP/HTTPS)
6. iOS Share Extension for shared files and URL links using an App Group inbox
7. In-app WebKit browser with WKDownload handling
6. Native list, refresh, and delete
7. 25 MB per-file limit for server downloads, browser upload, native import, and URL downloads
9. GitHub Actions unsigned IPA build

## Architecture
- Embedded iOS Share Extension and App Group shared inbox
- WKWebView navigation and WKDownload temporary-file handling
- SwiftUI native UI
- Network framework NWListener local HTTP server
- Browser UI served by the app
- Dedicated app sandbox folder: Documents/PocketServerFiles
- GitHub Actions macOS build

## Constraints
- Local Wi-Fi use; no Internet-facing setup or port forwarding
- Foreground operation only; background server operation is not guaranteed
- Only app-managed storage is exposed
- Native URL downloads use URLSession download-to-temporary-file; validate 2xx HTTP response and enforce a 25 MB size limit before copying into app storage
- Browser upload supports one selected file per submission

## Security
- No authentication in this version; use only trusted networks and stop the server after use
- Reject unsafe filenames and keep access within the dedicated folder
- Browser upload does not overwrite existing files; native import/download uses a numbered filename on collision
- Transfer size limit: 25 MB per file
- Authentication, robust HTTP parsing, and security hardening remain future work

## Milestones
### M0 — Setup
Repository, docs, app skeleton and CI.

### M1 — Server lifecycle (verified by user)
Start/stop, local address and basic response.

### M2 — Browser file management
Listing, download, single-file upload, delete routes and HTML controls added. Build and real-device/browser testing pending.

### M3 — Native file management
Files picker import, URL download, in-app listing, refresh and delete added. Build and real-device testing pending.

### M4 — Share import and browser download
Share Extension, shared inbox, and in-app WebKit browser added; CI/device validation pending.

### M5 — Security and polish
Authentication, improved streaming transfer, progress and cancellation, robust HTTP handling, browser multi-file upload.

## Verification status
- CI build status and on-device behavior must be checked after code changes; implemented features are not considered verified until build and device/browser tests pass.

## MVP completion
On iPhone, start server; from a browser on the same LAN, upload, list, download and delete files; in-app import and URL download; stop server cleanly.


## Liquid Glass UI

- On iOS 26 and newer, the main cards and interactive buttons use native SwiftUI Liquid Glass (`glassEffect`, `.glass`, `.glassProminent`).
- On iOS 17 and iOS 18, the UI keeps compatible fallback materials and bordered button styles.
- Liquid Glass is limited to the main surfaces and controls to avoid excessive effects.


## Offline local mode

- The app and local file-management UI remain usable without Wi-Fi.
- When the listener reaches ready but no Wi-Fi IPv4 address is available, show `ローカルモード（Wi-Fi未接続）`.
- File listing, import, export/share, and deletion remain available offline.
- Remote access from another device and URL downloads require network connectivity.
- When Wi-Fi IPv4 is available, the server displays its address and normal LAN access mode.
