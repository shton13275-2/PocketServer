# PocketServer

PocketServer is an iOS app that turns an iPhone into a local-network file server. It is designed to serve a browser on a PC or iPad while the iPhone app is open.

## MVP features
- Start/stop a local HTTP server
- Display the local network address
- Browser-based file list
- Upload/download/delete
- App-specific storage
- Authentication and path safety
- GitHub Actions builds an unsigned IPA artifact

## Initial limitations
- No Internet-facing server or port forwarding
- No guaranteed background server operation
- No arbitrary iOS file access

## Build
GitHub Actions builds an unsigned iOS device app and packages it as an IPA artifact. Unsigned IPA files cannot be directly installed on a device without a valid signing process.

## Status
M0 project setup is complete. M1 basic listener and status UI are in initial implementation; device testing is still needed.
