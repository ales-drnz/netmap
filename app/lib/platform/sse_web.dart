import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'sse_types.dart';

class _Web implements SseConnection {
  _Web(this.es);
  final web.EventSource es;
  @override
  void close() => es.close();
}

SseConnection? openSse(Uri url, {required SseListener onSnapshot, required SseErrorListener onError}) {
  var opened = false;
  final es = web.EventSource(url.toString());
  es.addEventListener(
    'snapshot',
    ((web.Event e) {
      opened = true;
      final data = (e as web.MessageEvent).data;
      if (data.isA<JSString>()) onSnapshot((data as JSString).toDart);
    }).toJS,
  );
  es.onerror = ((web.Event _) => onError(opened)).toJS;
  return _Web(es);
}
