## [0.1.0] - 9-11-2026

### Web app
**Added**
- The map as home page: the hub in the middle, one island per person with two or more devices, lines for direct, relay and one-way links.
- A sheet beside the map that says how you are connected, copies your address and lists people, services and activity.
- Device details in plain words, with the technical ones folded away.
- Devices, Activity, Network and Join pages.
- English and Italian, light and dark themes, phone layout, `Ctrl K` command palette.

### Server
**Added**
- Reads members and configuration from ZTNET, and latency, paths and health from the local ZeroTier service.
- Live updates over Server-Sent Events.
- Service checks, 24-hour history and events, saved to disk.
- Read-only: the ZTNET token and public IPs never reach the browser.

### Docker
**Added**
- `ghcr.io/ales-drnz/netmap` for amd64 and arm64: `latest` from `main`, `X.Y.Z` and `X.Y` from a `vX.Y.Z` tag.
