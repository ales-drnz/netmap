// The page's single data source: a snapshot from the server.
// It tries the stream first (SSE, one snapshot after each server poll); if the
// stream never opens it falls back to polling /api/nodes at the server's pace.
// While the stream is open and errors, EventSource reconnects on its own and
// the page shows the data as stale until it does.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../platform/sse.dart';
import '../platform/sse_types.dart';
import 'api.dart';
import 'model.dart';
import 'stats.dart' as stats;
import 'status.dart';

/// How the page talks to the server. Tests override [apiProvider].
class Api {
  Api({http.Client? client, Uri? base, this.sse = openSse}) : client = client ?? http.Client(), base = base ?? Uri.base;
  final http.Client client;

  /// the page's own origin: the API is always same-origin
  final Uri base;
  final SseConnection? Function(Uri, {required SseListener onSnapshot, required SseErrorListener onError}) sse;

  Uri url(String path) => base.resolve(path);

  Future<Snapshot> nodes() async {
    final r = await client.get(url('/api/nodes'), headers: {'Cache-Control': 'no-store'});
    if (r.statusCode != 200) throw http.ClientException('HTTP ${r.statusCode}', r.request?.url);
    return Snapshot.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Json);
  }

  Future<WhoAmI?> whoami() async {
    try {
      final r = await client.get(url('/api/whoami'), headers: {'Cache-Control': 'no-store'});
      return r.statusCode == 200 ? WhoAmI.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Json) : null;
    } catch (_) {
      return null; // the viewer stays anonymous: the page works anyway
    }
  }
}

final apiProvider = Provider<Api>((ref) => Api());

class LiveState {
  const LiveState({this.snap, this.me, this.offline = false, this.receivedAt = 0});
  final Snapshot? snap;
  final WhoAmI? me;

  /// the server is not responding (browser side)
  final bool offline;

  /// browser clock when the last snapshot arrived (0 = never)
  final int receivedAt;

  LiveState copyWith({Snapshot? snap, WhoAmI? me, bool? offline, int? receivedAt}) =>
      LiveState(snap: snap ?? this.snap, me: me ?? this.me, offline: offline ?? this.offline, receivedAt: receivedAt ?? this.receivedAt);
}

class LiveController extends Notifier<LiveState> {
  SseConnection? _sse;
  Timer? _poll;
  bool _disposed = false;

  @override
  LiveState build() {
    ref.onDispose(() {
      _disposed = true;
      _sse?.close();
      _poll?.cancel();
    });
    Future.microtask(_start);
    return const LiveState();
  }

  Api get _api => ref.read(apiProvider);

  void _start() {
    if (_disposed) return;
    _api.whoami().then((me) {
      if (!_disposed && me != null) state = state.copyWith(me: me);
    });
    _sse = _api.sse(
      _api.url('/api/stream'),
      onSnapshot: (data) {
        try {
          accept(Snapshot.fromJson(jsonDecode(data) as Json));
        } catch (_) {
          // a malformed event: keep the last good snapshot
        }
      },
      onError: (opened) {
        if (_disposed) return;
        if (!opened) {
          // never opened: no stream on this server → polling
          _sse?.close();
          _sse = null;
          _pollNow();
        } else {
          state = state.copyWith(offline: true);
        }
      },
    );
    if (_sse == null) _pollNow();
  }

  Future<void> _pollNow() async {
    if (_disposed) return;
    try {
      accept(await _api.nodes());
    } catch (_) {
      if (!_disposed) state = state.copyWith(offline: true);
    }
    if (_disposed) return;
    _poll = Timer(Duration(seconds: state.snap?.pollSeconds ?? 20), _pollNow);
  }

  /// a new snapshot from the stream or a poll
  void accept(Snapshot s) {
    if (_disposed) return;
    state = state.copyWith(snap: s, offline: false, receivedAt: DateTime.now().millisecondsSinceEpoch);
  }
}

final liveProvider = NotifierProvider<LiveController, LiveState>(LiveController.new);

/// Wall clock, ticking once a second ("updated 5 s ago", stale detection).
class Clock extends Notifier<int> {
  @override
  int build() {
    final t = Timer.periodic(const Duration(seconds: 1), (_) => state = DateTime.now().millisecondsSinceEpoch);
    ref.onDispose(t.cancel);
    return DateTime.now().millisecondsSinceEpoch;
  }
}

final clockProvider = NotifierProvider<Clock, int>(Clock.new);

/// Everything the pages need, derived once per snapshot.
class NetworkView {
  NetworkView(this.snap, WhoAmI? whoami, int now)
    : hub = snap.nodes.where((n) => n.hub).firstOrNull,
      devices = snap.nodes.where((n) => !n.hub).map((n) => toDevice(n, now)).toList(),
      typical = stats.typicalLatency(snap.nodes),
      availability = stats.availability(snap.nodes, now),
      counts = countsOf(snap.nodes, now) {
    me = whoami?.name == null ? null : devices.where((d) => d.name == whoami!.name).firstOrNull;
    myOwner = me?.owner;
    people = groupPeople(devices, myOwner);
  }

  final Snapshot snap;
  final NetNode? hub;

  /// every device except the hub, active and inactive (filter with `active`)
  final List<Device> devices;

  /// the viewer's device, when the viewer is a member
  late final Device? me;
  late final String? myOwner;
  late final List<Person> people;

  /// median of per-device medians: the one "typical latency" of the whole UI
  final double? typical;

  /// mean 24 h uptime of the devices active in the last 24 h
  final double? availability;
  final Counts counts;

  Device? byId(String id) => devices.where((d) => d.id == id).firstOrNull;
}

final networkProvider = Provider<NetworkView?>((ref) {
  final (snap, me, at) = ref.watch(liveProvider.select((s) => (s.snap, s.me, s.receivedAt)));
  return snap == null ? null : NetworkView(snap, me, at == 0 ? DateTime.now().millisecondsSinceEpoch : at);
});

final verdictProvider = Provider<Verdict>((ref) {
  final live = ref.watch(liveProvider);
  return verdict(snap: live.snap, receivedAt: live.receivedAt, now: ref.watch(clockProvider), offline: live.offline);
});
