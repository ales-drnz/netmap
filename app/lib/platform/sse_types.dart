/// raw JSON of one `snapshot` event
typedef SseListener = void Function(String data);

/// [opened] = the stream delivered at least one event before failing
typedef SseErrorListener = void Function(bool opened);

abstract interface class SseConnection {
  void close();
}
