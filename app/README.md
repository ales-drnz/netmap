# Netmap web app

The Flutter web app of [Netmap](../README.md): the map, the Devices, Activity and Network pages, in English and
Italian. It talks to the server in `../server` through the API contract in `lib/data`, which mirrors
`../shared/api.ts`.

```bash
npm run dev:web    # from the repo root: hot reload on :8083, API proxied to the mock on :8082
npm run test:app   # unit, widget, accessibility and golden tests
```

See the [main README](../README.md#5-development) for the layout of the code and the other commands.
