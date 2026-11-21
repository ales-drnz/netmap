/// The app version, taken from package.json at build time
/// (`--dart-define=NETMAP_VERSION=…`, see scripts/build-web.mjs).
const String appVersion = String.fromEnvironment('NETMAP_VERSION', defaultValue: 'dev');
