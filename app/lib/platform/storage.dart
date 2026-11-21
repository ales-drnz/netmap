// Per-browser preferences (theme, language). localStorage on the web, an
// in-memory map elsewhere (tests). Failures are ignored: a private window or
// blocked storage just means the choice is not remembered.
export 'storage_stub.dart' if (dart.library.js_interop) 'storage_web.dart';
