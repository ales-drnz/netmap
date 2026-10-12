## [0.1.0] - 2026-10-12

First public release.

### Added

- Web UI in English and Italian: Overview, My devices, Map, Devices, Activity, Network, Stats, Services and a Join guide, with light and dark themes and a `Ctrl K` command palette.
- Map of the network around the hub, with one island per person (owner and device type come from the member name), direct, relayed and offline links, pan and zoom.
- Live updates over Server-Sent Events (`/api/stream`), falling back to polling `/api/nodes`.
- Per-device details: latency trend against the previous week, 24-hour availability, path type, client version, half-open path detection, packet counts.
- Network view: what the controller configures, what reached the hub and what the hub applies, for DNS, managed routes and addresses.
- Activity timeline with disconnections, path changes, latency spikes, access requests and simultaneous drops grouped as one incident.
- Services page from `services.json` or `QUICK_LINKS`, with a TCP reachability check and 24-hour history.
- Single-file server bundle (`dist/server.mjs`) and a multi-arch Docker image on GitHub Container Registry.
