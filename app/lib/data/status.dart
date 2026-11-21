// The single global verdict ("Everything works", "Netmap can't be reached"…).
// Pure: snapshot + clocks in, a structured verdict out; the words are chosen
// by the UI.
//
// Priority (the first that applies wins):
//   1. stale data: the browser can't reach the server, or ZTNET isn't answering → danger
//   2. a netdrop (several devices dropped together) in the last hour           → danger
//   3. the hub's ZeroTier is on TCP fallback, or TCP relay is forced            → warn
//   4. some online devices go through a relay                                   → warn
//   5. all good                                                                 → ok
import 'api.dart';
import 'stats.dart';

enum Tone { ok, warn, danger, neutral }

sealed class Reason {
  const Reason();
}

class Loading extends Reason {
  const Loading();
}

/// [ztnet]: the server answers but ZTNET doesn't. [ageSec]: how old the data shown is.
class Stale extends Reason {
  const Stale({required this.ztnet, this.ageSec, this.error});
  final bool ztnet;
  final int? ageSec;
  final String? error;
}

class NetDrop extends Reason {
  const NetDrop({this.count, required this.t});
  final int? count;
  final int t;
}

class TcpFallback extends Reason {
  const TcpFallback();
}

class ForceTcp extends Reason {
  const ForceTcp();
}

class Relayed extends Reason {
  const Relayed(this.count);
  final int count;
}

class AllGood extends Reason {
  const AllGood();
}

class Counts {
  const Counts({
    this.active = 0,
    this.online = 0,
    this.direct = 0,
    this.atHome = 0,
    this.internet = 0,
    this.relay = 0,
    this.oneWay = 0,
    this.unknown = 0,
    this.offline = 0,
    this.inactive = 0,
  });

  /// devices (hub excluded) online or seen within 7 days
  final int active;
  final int online;

  /// online and direct (at home + over the internet + one-way, which still has a direct path)
  final int direct;
  final int atHome;
  final int internet;
  final int relay;

  /// one-way devices (also counted in [direct])
  final int oneWay;

  /// online, but whether direct or relayed is unknown (no local ZeroTier data)
  final int unknown;

  /// active devices that are offline now
  final int offline;

  /// offline for more than 7 days (or never seen): not counted anywhere else
  final int inactive;
}

Counts countsOf(Iterable<NetNode> nodes, int now) {
  var active = 0, online = 0, direct = 0, lan = 0, wan = 0, relay = 0, oneWay = 0, unknown = 0, offline = 0, inactive = 0;
  for (final n in nodes) {
    if (n.hub) continue;
    if (!isActive(n, now)) {
      inactive++;
      continue;
    }
    active++;
    if (!n.online) {
      offline++;
    } else {
      online++;
      if (n.relayed) {
        relay++;
      } else if (n.link == null || n.link == Link.hub) {
        // nothing says how it is connected: not counted as direct
        unknown++;
      } else {
        direct++;
        if (n.halfOpen) oneWay++;
        if (n.link == Link.lan) {
          lan++;
        } else {
          wan++;
        }
      }
    }
  }
  return Counts(
    active: active,
    online: online,
    direct: direct,
    atHome: lan,
    internet: wan,
    relay: relay,
    oneWay: oneWay,
    unknown: unknown,
    offline: offline,
    inactive: inactive,
  );
}

class Verdict {
  const Verdict({required this.tone, required this.reason, this.ageSec, required this.pollSeconds, required this.counts});
  final Tone tone;
  final Reason reason;

  /// seconds since the browser received the last snapshot (null before the first)
  final int? ageSec;
  final int pollSeconds;
  final Counts counts;
}

/// data older than this many polls (and at least a minute) counts as stale
const _stalePolls = 3;
const _staleMinSec = 60;

Verdict verdict({required Snapshot? snap, required int receivedAt, required int now, required bool offline}) {
  final pollSeconds = snap?.pollSeconds ?? 20;
  final ageSec = receivedAt > 0 ? ((now - receivedAt) / 1000).round().clamp(0, 1 << 31) : null;
  final counts = countsOf(snap?.nodes ?? const [], now);
  Verdict out(Tone tone, Reason r) => Verdict(tone: tone, reason: r, ageSec: ageSec, pollSeconds: pollSeconds, counts: counts);

  if (snap == null) return offline ? out(Tone.danger, const Stale(ztnet: false)) : out(Tone.neutral, const Loading());

  final staleAfter = _stalePolls * pollSeconds > _staleMinSec ? _stalePolls * pollSeconds : _staleMinSec;
  if (offline || (ageSec != null && ageSec > staleAfter)) return out(Tone.danger, Stale(ztnet: false, ageSec: ageSec));
  if (snap.error != null) {
    // the server answers but serves the last good ZTNET data: its age is updatedAt
    final upd = snap.updatedAt;
    final age = upd == null ? null : ((now - upd) / 1000).round().clamp(0, 1 << 31);
    return out(Tone.danger, Stale(ztnet: true, ageSec: age, error: snap.error));
  }

  final drops = snap.events.where((e) => e.kind == EventKind.netdrop && now - e.t <= hourMs).toList()..sort((a, b) => b.t.compareTo(a.t));
  if (drops.isNotEmpty) return out(Tone.danger, NetDrop(count: drops.first.count, t: drops.first.t));

  final zt = snap.health?.zt;
  if (zt?.tcpFallback ?? false) return out(Tone.warn, const TcpFallback());
  if (zt?.forceTcpRelay ?? false) return out(Tone.warn, const ForceTcp());
  if (counts.relay > 0) return out(Tone.warn, Relayed(counts.relay));
  return out(Tone.ok, const AllGood());
}
