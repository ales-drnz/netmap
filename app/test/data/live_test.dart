import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netmap/data/live.dart';
import 'package:netmap/platform/sse_types.dart';

final _snapshot = File('test/fixtures/snapshot.json').readAsStringSync();

class FakeSse implements SseConnection {
  SseListener? onSnapshot;
  SseErrorListener? onError;
  bool closed = false;
  @override
  void close() => closed = true;
}

ProviderContainer containerWith({required http.Client client, FakeSse? sse}) {
  final c = ProviderContainer(
    overrides: [
      apiProvider.overrideWithValue(
        Api(
          client: client,
          base: Uri.parse('http://netmap.test/'),
          sse: (url, {required onSnapshot, required onError}) {
            if (sse == null) return null;
            sse.onSnapshot = onSnapshot;
            sse.onError = onError;
            return sse;
          },
        ),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

MockClient server({bool fail = false, List<String>? calls}) => MockClient((r) async {
  calls?.add(r.url.path);
  if (fail) return http.Response('down', 502);
  return switch (r.url.path) {
    '/api/nodes' => http.Response.bytes(utf8.encode(_snapshot), 200),
    '/api/whoami' => http.Response('{"ip":"10.147.17.4","name":"alice-phone","id":"0000000003"}', 200),
    _ => http.Response('nope', 404),
  };
});

void main() {
  test('without a stream it polls /api/nodes, and learns who is watching', () async {
    final calls = <String>[];
    final c = containerWith(client: server(calls: calls));
    c.listen(liveProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final s = c.read(liveProvider);
    expect(s.snap?.nodes, hasLength(13));
    expect(s.me?.name, 'alice-phone');
    expect(s.offline, isFalse);
    expect(calls, containsAll(['/api/nodes', '/api/whoami']));

    final net = c.read(networkProvider)!;
    expect(net.me?.name, 'alice-phone');
    expect(net.people.first.key, 'alice');
    expect(net.hub?.name, 'nas');
    expect(net.devices, hasLength(12));
  });

  test('snapshots arrive on the stream; an error after it opened marks the data stale', () async {
    final sse = FakeSse();
    final calls = <String>[];
    final c = containerWith(
      client: server(calls: calls),
      sse: sse,
    );
    c.listen(liveProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    sse.onSnapshot!(_snapshot);
    expect(c.read(liveProvider).snap?.networkName, 'home-net');
    sse.onError!(true);
    expect(c.read(liveProvider).offline, isTrue);
    expect(calls, isNot(contains('/api/nodes')));
    sse.onSnapshot!(_snapshot);
    expect(c.read(liveProvider).offline, isFalse);
  });

  test('a stream that never opens falls back to polling', () async {
    final sse = FakeSse();
    final calls = <String>[];
    final c = containerWith(
      client: server(calls: calls),
      sse: sse,
    );
    c.listen(liveProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    sse.onError!(false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sse.closed, isTrue);
    expect(calls, contains('/api/nodes'));
    expect(c.read(liveProvider).snap, isNotNull);
  });

  test('a server that does not answer marks the page offline, and the verdict says so', () async {
    final c = containerWith(client: server(fail: true));
    c.listen(liveProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(liveProvider).offline, isTrue);
    expect(c.read(verdictProvider).reason.runtimeType.toString(), 'Stale');
  });
}
