## [0.1.0] - 22-11-2026

### Web app
**Added**
- Flutter Web app in Material 3 Expressive: Laguna colours, a flat look without animations, light, dark or system theme.
- The map as home page: the hub and one lane per state (direct, online, relay, no reply, offline, inactive), each joined to it by a line in the state's colour. In a lane each person's devices sit together and, for two or more, on a shared rounded band with their owner's name ("You" for yours, tinted). Every device is a circle of the same size, with the colour, icon and word of its link; tapping one opens its details beside the map. On a phone the lanes go below the hub and the map fits the width, so names stay readable.
- A small panel beside the map that says how you are connected, copies your address and lists services with their own icon, a tap away; a legend under the map counts the devices in each state.
- Device details: the state, last seen and 24-hour availability first, then addresses, version, paths, latency against the week before and packets, all on one page.
- Devices, Activity and Network pages.
- English and Italian with one word per concept, phone layout, keyboard and screen reader support, AA contrast in both themes.

### Server
**Added**
- Reads members and configuration from ZTNET, and latency, paths and health from the local ZeroTier service.
- Live updates over Server-Sent Events.
- Service checks, 24-hour history and events, saved to disk.
- Service icons, read from each service's own address and served by Netmap: the browser never contacts the services.
- Serves the web app with WebAssembly support and cross-origin isolation.
- Read-only: the ZTNET token and public IPs never reach the browser.

### Docker
**Added**
- `ghcr.io/ales-drnz/netmap` for amd64 and arm64: `latest` from `main`, `X.Y.Z` and `X.Y` from a `vX.Y.Z` tag.
- CI checks the server and the app (analysis, unit, widget, accessibility and golden tests) before building the image.
