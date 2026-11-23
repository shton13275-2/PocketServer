# PocketServer

An iOS app that turns an iPhone into a local-network file server for browsers on a PC or iPad, while the app is open.

## Current features
- Start/stop local HTTP server
- Show/share LAN address
- Browser file listing from dedicated app folder
- Download individual files (initial code limit: 25 MB)

## Not yet implemented
- Upload
- Delete
- Authentication
- Search/refresh UI

## Safety/limitations
- Intended for local Wi-Fi only; no port forwarding
- Keep to trusted networks and stop the server when not in use; current partial M2 has no authentication
- Background server operation is not guaranteed
- Only files in PocketServer's dedicated folder are served

## Build
GitHub Actions creates an unsigned iOS IPA. Installing it requires a valid signing method.
