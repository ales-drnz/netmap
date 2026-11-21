// Server-Sent Events: EventSource in the browser; elsewhere (tests) there is
// no stream and the page polls instead.
export 'sse_stub.dart' if (dart.library.js_interop) 'sse_web.dart';
