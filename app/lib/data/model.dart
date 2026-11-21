// From raw API data to the model the pages render. Pure: no state, no
// fetching, no text (words come from the l10n layer), so it is unit tested.
import 'api.dart';
import 'naming.dart';
import 'stats.dart';

/// How a device is connected: one name per concept, in every page.
/// Words (it / en, see l10n/GLOSSARY.md): at home and over the internet are
/// both Diretto / Direct · Online · Tramite relay / Through a relay ·
/// Senza risposta / No reply · Offline.
enum LinkState {
  /// online, direct, same physical network
  atHome,

  /// online, direct over the internet
  internet,

  /// online, but how is unknown: the hub's local ZeroTier service gives the
  /// path (direct or relay), and it could not be read. Never guessed.
  online,

  /// online through a relay: works, slower
  relay,

  /// we talk to it but it does not answer (half-open path)
  oneWay,

  /// not online
  offline;

  bool get isOnline => this != offline;
  bool get isDirect => this == atHome || this == internet;
}

LinkState linkStateOf(NetNode n) {
  if (!n.online) return LinkState.offline;
  if (n.halfOpen) return LinkState.oneWay;
  if (n.relayed) return LinkState.relay;
  return switch (n.link) {
    Link.lan => LinkState.atHome,
    Link.wan => LinkState.internet,
    Link.relay => LinkState.relay,
    // no path information: online, but whether direct or relayed is unknown
    Link.hub || null => LinkState.online,
  };
}

class Device {
  const Device({
    required this.node,
    required this.owner,
    required this.ownerLabel,
    required this.type,
    required this.state,
    required this.active,
    this.ms,
    this.median,
  });

  final NetNode node;

  /// person key (lowercase), or the whole name when it cannot be inferred
  final String owner;
  final String ownerLabel;
  final DeviceType type;
  final LinkState state;

  /// online, or seen within the last 7 days; inactive devices are shown dimmed
  final bool active;

  /// last latency sample, only when online and direct
  final double? ms;

  /// median of the recent samples, only when online and direct: the number to show
  final double? median;

  String get id => node.id;
  String get name => node.name;
  String? get ip => node.ips.firstOrNull;
  bool get online => state.isOnline;
}

Device toDevice(NetNode n, int now) {
  final direct = n.online && !n.relayed;
  final owner = ownerOf(n.name) ?? n.name.toLowerCase();
  return Device(
    node: n,
    owner: owner,
    ownerLabel: cap(owner),
    type: typeOf(n.name) ?? (n.hub ? DeviceType.server : DeviceType.pc),
    state: linkStateOf(n),
    active: isActive(n, now),
    ms: direct ? n.latencyMs : null,
    median: direct ? (deviceMedian(n) ?? n.latencyMs) : null,
  );
}

class Person {
  const Person({required this.key, required this.label, required this.devices});
  final String key;
  final String label;

  /// sorted by name
  final List<Device> devices;

  int get online => devices.where((d) => d.online).length;

  /// a person whose devices are all inactive is shown dimmed as a whole
  bool get active => devices.any((d) => d.active);
}

/// People, "you" first, then by number of devices, then by name.
List<Person> groupPeople(Iterable<Device> devices, String? me) {
  final map = <String, List<Device>>{};
  for (final d in devices) {
    map.putIfAbsent(d.owner, () => []).add(d);
  }
  final out = [
    for (final e in map.entries)
      Person(key: e.key, label: e.value.first.ownerLabel, devices: e.value..sort((a, b) => a.name.compareTo(b.name))),
  ];
  out.sort((a, b) {
    final mine = (b.key == me ? 1 : 0) - (a.key == me ? 1 : 0);
    if (mine != 0) return mine;
    final n = b.devices.length - a.devices.length;
    return n != 0 ? n : a.label.compareTo(b.label);
  });
  return out;
}

// ---------- events ----------

/// The Activity filter an event belongs to.
enum EventFilter { off, on, path, spike, join }

EventFilter filterOf(EventKind k) => switch (k) {
  EventKind.offline || EventKind.netdrop => EventFilter.off,
  EventKind.online => EventFilter.on,
  EventKind.relay || EventKind.direct => EventFilter.path,
  EventKind.spike => EventFilter.spike,
  EventKind.pending => EventFilter.join,
};

/// Events grouped by local calendar day, newest first.
List<(DateTime day, List<NetEvent> events)> eventsByDay(Iterable<NetEvent> events) {
  final sorted = events.toList()..sort((a, b) => b.t.compareTo(a.t));
  final out = <(DateTime, List<NetEvent>)>[];
  for (final e in sorted) {
    final d = DateTime.fromMillisecondsSinceEpoch(e.t);
    final day = DateTime(d.year, d.month, d.day);
    if (out.isEmpty || out.last.$1 != day) out.add((day, []));
    out.last.$2.add(e);
  }
  return out;
}

// ---------- versions ----------

/// Compares dotted versions numerically ("1.14.2" > "1.9.10"); null = unknown, lowest.
int compareVersions(String? a, String? b) {
  if (a == b) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  final pa = a.split(RegExp(r'[^0-9]+')).where((s) => s.isNotEmpty).map(int.parse).toList();
  final pb = b.split(RegExp(r'[^0-9]+')).where((s) => s.isNotEmpty).map(int.parse).toList();
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// The newest ZeroTier version anyone in the network runs. Netmap never calls
/// a version "outdated": it only says someone runs a newer one.
String? newestVersion(Iterable<NetNode> nodes) {
  String? best;
  for (final n in nodes) {
    if (compareVersions(n.version, best) > 0) best = n.version;
  }
  return best;
}

/// Versions in use, newest first, with how many nodes run each.
List<(String, int)> versionsInUse(Iterable<NetNode> nodes) {
  final m = <String, int>{};
  for (final n in nodes) {
    if (n.version != null) m[n.version!] = (m[n.version!] ?? 0) + 1;
  }
  return m.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => compareVersions(b.$1, a.$1));
}
