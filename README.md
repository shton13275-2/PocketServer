# PocketServer

An iOS app that turns an iPhone into a local-network file server for browsers on a PC or iPad, while the app is open.

## Current features
- Start/stop local HTTP server and share its LAN address
- Browser file listing, download, single-file upload, and delete
- Native Files picker import (multi-select) into PocketServer's folder\n- Share extension to receive shared files and web URLs from the iOS share sheet; received items are queued in an App Group inbox for import when PocketServer is open\n- In-app WebKit browser with download handling and direct URL downloads
- Download a URL (HTTP/HTTPS) directly into the app's storage; checks HTTP response and saves through a temporary file
- Native list, refresh, and delete controls
- File transfer/import/download size limit: 25 MB per file
- Duplicate names from native import/download get an incrementing suffix; browser upload refuses to overwrite

## Not yet implemented
- Authentication/password protection
- Download progress percentage and cancellation\n- Share inbox imports are triggered when the app opens or when the user taps the import button (not guaranteed to auto-open the app)\n- In-app browser websites may require login; not all download flows are supported
- Multi-file upload in browser
- Stronger HTTP request handling / security hardening
- Transfer progress and cancellation (native URL download currently uses a temporary file but does not expose progress/cancel)

## Safety and limitations
- Intended for local Wi-Fi only; do not use port forwarding
- The browser server has no authentication; use trusted networks and stop the server when not needed
- Background server operation is not guaranteed
- Only files in PocketServer's dedicated folder are served
- Server download endpoint also has a 25 MB limit

## Build
GitHub Actions creates an unsigned iOS IPA. Installing it requires a valid signing method.
