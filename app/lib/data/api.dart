// The API contract in Dart: the exact shape of what /api/nodes, /api/stream
// and /api/whoami return. Mirrors shared/api.ts field by field (written by
// hand, checked by test/api_test.dart against a real snapshot of the mock).
//
// Every field the server may not know is nullable: "I don't know" and "no"
// are different things, and the page must be able to tell them apart.
// Parsing is lenient: a missing or mistyped field becomes null (or empty),
// never an exception, so a newer server cannot break an older page.

typedef Json = Map<String, dynamic>;

// ---------- lenient readers ----------

String? _str(Object? v) => v is String ? v : null;
num? _num(Object? v) => v is num ? v : null;
int? _int(Object? v) => v is num ? v.round() : null;
double? _dbl(Object? v) => v is num ? v.toDouble() : null;
bool? _bool(Object? v) => v is bool ? v : null;
Json? _obj(Object? v) => v is Map ? v.cast<String, dynamic>() : null;
List<Object?> _list(Object? v) => v is List ? v : const [];
List<String> _strings(Object? v) => _list(v).whereType<String>().toList();
List<T> _objs<T>(Object? v, T Function(Json) f) => _list(v).map(_obj).whereType<Json>().map(f).toList();
List<double?> _nullableNums(Object? v) => _list(v).map(_dbl).toList();

/// epoch ms from a number or an ISO date string; null if neither
int? epochMs(Object? v) {
  if (v is num) return v.round();
  if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch;
  return null;
}

// ---------- types ----------

/// 'lan' = same physical network, 'wan' = direct over the internet, 'relay' = no direct path
enum Link {
  hub,
  lan,
  wan,
  relay;

  static Link? parse(Object? v) => switch (v) {
    'hub' => hub,
    'lan' => lan,
    'wan' => wan,
    'relay' => relay,
    _ => null,
  };
}

class Label {
  const Label({required this.name, this.color});
  final String name;
  final String? color;
  factory Label.fromJson(Json j) => Label(name: _str(j['name']) ?? '', color: _str(j['color']));
}

class LatencyTrend {
  const LatencyTrend({this.median, this.p95, this.prevMedian, this.trend, this.samples = 0});
  final double? median;
  final double? p95;

  /// median of the previous week, if there are enough samples
  final double? prevMedian;

  /// recent median / previous median: > 1 means it got worse
  final double? trend;
  final int samples;

  factory LatencyTrend.fromJson(Json j) => LatencyTrend(
    median: _dbl(j['median']),
    p95: _dbl(j['p95']),
    prevMedian: _dbl(j['prevMedian']),
    trend: _dbl(j['trend']),
    samples: _int(j['samples']) ?? 0,
  );
}

class NodeTraffic {
  const NodeTraffic({required this.packets, required this.days, required this.errors});

  /// packets (not bytes) over the last 30 days
  final int packets;

  /// 30 values, oldest first, ending today
  final List<int> days;

  /// packet errors in the last 24 hours
  final int errors;

  factory NodeTraffic.fromJson(Json j) => NodeTraffic(
    packets: _int(j['packets']) ?? 0,
    days: _list(j['days']).map((v) => _int(v) ?? 0).toList(),
    errors: _int(j['errors']) ?? 0,
  );
}

class NetNode {
  const NetNode({
    required this.id,
    required this.name,
    this.ips = const [],
    this.online = false,
    this.relayed = false,
    this.latencyMs,
    this.link,
    this.version,
    this.idleSec,
    this.halfOpen = false,
    this.family,
    this.paths,
    this.pathsDead,
    this.note,
    this.labels = const [],
    this.since,
    this.lastSeen,
    this.hub = false,
    this.spark = const [],
    this.uptime,
    this.beats = const [],
    this.traffic,
    this.latency30,
  });

  final String id;
  final String name;
  final List<String> ips;
  final bool online;
  final bool relayed;
  final double? latencyMs;
  final Link? link;
  final String? version;

  /// seconds since the last packet received
  final double? idleSec;

  /// we talk to it but it doesn't answer: a broken path nobody has noticed yet
  final bool halfOpen;

  /// address family (never the address itself): 4 or 6
  final int? family;

  /// active paths; 1 = no fallback if it drops
  final int? paths;
  final int? pathsDead;
  final String? note;
  final List<Label> labels;

  /// member since (epoch ms)
  final int? since;

  /// last seen (epoch ms), from a number or an ISO string
  final int? lastSeen;
  final bool hub;

  /// last 90 latency samples; null = sample with no direct latency
  final List<double?> spark;

  /// fraction 0..1 over the last 24 hours
  final double? uptime;

  /// 60 ticks of 24 minutes each: fraction online, null = no data
  final List<double?> beats;
  final NodeTraffic? traffic;
  final LatencyTrend? latency30;

  factory NetNode.fromJson(Json j) => NetNode(
    id: _str(j['id']) ?? '',
    name: _str(j['name']) ?? '',
    ips: _strings(j['ips']),
    online: _bool(j['online']) ?? false,
    relayed: _bool(j['relayed']) ?? false,
    latencyMs: _dbl(j['latencyMs']),
    link: Link.parse(j['link']),
    version: _str(j['version']),
    idleSec: _dbl(j['idleSec']),
    halfOpen: _bool(j['halfOpen']) ?? false,
    family: _int(j['family']),
    paths: _int(j['paths']),
    pathsDead: _int(j['pathsDead']),
    note: _str(j['note']),
    labels: _objs(j['labels'], Label.fromJson),
    since: _int(j['since']),
    lastSeen: epochMs(j['lastSeen']),
    hub: _bool(j['hub']) ?? false,
    spark: _nullableNums(j['spark']),
    uptime: _dbl(j['uptime']),
    beats: _nullableNums(j['beats']),
    traffic: _obj(j['traffic']) == null ? null : NodeTraffic.fromJson(_obj(j['traffic'])!),
    latency30: _obj(j['latency30']) == null ? null : LatencyTrend.fromJson(_obj(j['latency30'])!),
  );
}

class Pending {
  const Pending({required this.id, this.name, this.since, this.waitingSec, this.deauthorized = false});
  final String id;
  final String? name;
  final int? since;
  final double? waitingSec;

  /// it was authorized and the authorization was revoked
  final bool deauthorized;

  factory Pending.fromJson(Json j) => Pending(
    id: _str(j['id']) ?? '',
    name: _str(j['name']),
    since: _int(j['since']),
    waitingSec: _dbl(j['waitingSec']),
    deauthorized: _bool(j['deauthorized']) ?? false,
  );
}

enum EventKind {
  offline,
  online,
  relay,
  direct,
  spike,
  pending,
  netdrop;

  static EventKind? parse(Object? v) => values.where((k) => k.name == v).firstOrNull;
}

class NetEvent {
  const NetEvent({required this.t, required this.kind, this.id, this.name, this.detail, this.count});
  final int t;
  final String? id;
  final String? name;
  final EventKind kind;
  final String? detail;

  /// only for netdrop: how many dropped together
  final int? count;

  /// null when the kind is unknown to this version of the page
  static NetEvent? fromJson(Json j) {
    final kind = EventKind.parse(j['kind']);
    final t = _int(j['t']);
    if (kind == null || t == null) return null;
    return NetEvent(t: t, kind: kind, id: _str(j['id']), name: _str(j['name']), detail: _str(j['detail']), count: _int(j['count']));
  }
}

class Route {
  const Route({required this.target, this.via});
  final String target;
  final String? via;
  factory Route.fromJson(Json j) => Route(target: _str(j['target']) ?? '', via: _str(j['via']));
}

class Dns {
  const Dns({this.domain, this.servers = const []});
  final String? domain;
  final List<String> servers;
  factory Dns.fromJson(Json j) => Dns(domain: _str(j['domain']), servers: _strings(j['servers']));
}

class Pool {
  const Pool({required this.start, required this.end});
  final String start;
  final String end;
  factory Pool.fromJson(Json j) => Pool(start: _str(j['start']) ?? '', end: _str(j['end']) ?? '');
}

/// network configuration as distributed by the controller
class NetConfig {
  const NetConfig({
    this.routes = const [],
    this.pools = const [],
    this.dns,
    this.private,
    this.v6,
    this.mtu,
    this.broadcast,
    this.multicastLimit,
    this.creationTime,
  });
  final List<Route> routes;
  final List<Pool> pools;
  final Dns? dns;
  final bool? private;
  final List<String>? v6;
  final int? mtu;
  final bool? broadcast;
  final int? multicastLimit;
  final int? creationTime;

  factory NetConfig.fromJson(Json j) => NetConfig(
    routes: _objs(j['routes'], Route.fromJson),
    pools: _objs(j['pools'], Pool.fromJson),
    dns: _obj(j['dns']) == null ? null : Dns.fromJson(_obj(j['dns'])!),
    private: _bool(j['private']),
    v6: j['v6'] is List ? _strings(j['v6']) : null,
    mtu: _int(j['mtu']),
    broadcast: _bool(j['broadcast']),
    multicastLimit: _int(j['multicastLimit']),
    creationTime: _int(j['creationTime']),
  );
}

/// the ZeroTier service of the node hosting Netmap (/status)
class ZtStatus {
  const ZtStatus({
    this.online = false,
    this.version,
    this.tcpFallback = false,
    this.forceTcpRelay = false,
    this.allowTcpFallback = false,
    this.portMapping,
    this.port,
  });
  final bool online;
  final String? version;
  final bool tcpFallback;
  final bool forceTcpRelay;
  final bool allowTcpFallback;
  final bool? portMapping;
  final int? port;

  factory ZtStatus.fromJson(Json j) => ZtStatus(
    online: _bool(j['online']) ?? false,
    version: _str(j['version']),
    tcpFallback: _bool(j['tcpFallback']) ?? false,
    forceTcpRelay: _bool(j['forceTcpRelay']) ?? false,
    allowTcpFallback: _bool(j['allowTcpFallback']) ?? false,
    portMapping: _bool(j['portMapping']),
    port: _int(j['port']),
  );
}

/// the network as seen by the local node (/network)
class ZtLocalNetwork {
  const ZtLocalNetwork({
    required this.status,
    required this.statusLabel,
    this.ok = false,
    this.revision,
    this.portError = 0,
    this.device,
    this.mtu,
    this.bridge = false,
    this.dns,
    this.addresses = const [],
    this.routes = const [],
    this.allowManaged,
    this.allowGlobal,
    this.allowDefault,
    this.allowDNS,
  });
  final String status;
  final String statusLabel;
  final bool ok;
  final int? revision;
  final int portError;
  final String? device;
  final int? mtu;
  final bool bridge;
  final Dns? dns;
  final List<String> addresses;
  final List<Route> routes;
  final bool? allowManaged;
  final bool? allowGlobal;
  final bool? allowDefault;
  final bool? allowDNS;

  factory ZtLocalNetwork.fromJson(Json j) => ZtLocalNetwork(
    status: _str(j['status']) ?? '',
    statusLabel: _str(j['statusLabel']) ?? '',
    ok: _bool(j['ok']) ?? false,
    revision: _int(j['revision']),
    portError: _int(j['portError']) ?? 0,
    device: _str(j['device']),
    mtu: _int(j['mtu']),
    bridge: _bool(j['bridge']) ?? false,
    dns: _obj(j['dns']) == null ? null : Dns.fromJson(_obj(j['dns'])!),
    addresses: _strings(j['addresses']),
    routes: _objs(j['routes'], Route.fromJson),
    allowManaged: _bool(j['allowManaged']),
    allowGlobal: _bool(j['allowGlobal']),
    allowDefault: _bool(j['allowDefault']),
    allowDNS: _bool(j['allowDNS']),
  );
}

class UdpTcp {
  const UdpTcp(this.udp, this.tcp);
  final num udp;
  final num tcp;
  factory UdpTcp.fromJson(Json j) => UdpTcp(_num(j['udp']) ?? 0, _num(j['tcp']) ?? 0);
}

/// actual network bytes over 30 days
class NodeBytes {
  const NodeBytes({required this.total, required this.days});
  final UdpTcp total;
  final List<UdpTcp> days;
  factory NodeBytes.fromJson(Json j) => NodeBytes(total: UdpTcp.fromJson(j), days: _objs(j['days'], UdpTcp.fromJson));
}

class ErrorCount {
  const ErrorCount(this.type, this.count);
  final String type;
  final int count;
  factory ErrorCount.fromJson(Json j) => ErrorCount(_str(j['type']) ?? '', _int(j['count']) ?? 0);
}

class Health {
  const Health({this.zt, this.local, this.bytes, this.errors, this.localReason});
  final ZtStatus? zt;
  final ZtLocalNetwork? local;

  /// why the hub's local ZeroTier service is unavailable ('ok' when it
  /// answers): token-unreadable, token-missing, token-error, refused,
  /// timeout, unauthorized, error. Null from servers that do not say.
  final String? localReason;

  /// null if metrics are disabled
  final NodeBytes? bytes;
  final List<ErrorCount>? errors;

  factory Health.fromJson(Json j) => Health(
    zt: _obj(j['zt']) == null ? null : ZtStatus.fromJson(_obj(j['zt'])!),
    local: _obj(j['local']) == null ? null : ZtLocalNetwork.fromJson(_obj(j['local'])!),
    bytes: _obj(j['bytes']) == null ? null : NodeBytes.fromJson(_obj(j['bytes'])!),
    errors: j['errors'] is List ? _objs(j['errors'], ErrorCount.fromJson) : null,
    localReason: _str(j['localReason']),
  );
}

class QuickLink {
  const QuickLink({
    required this.name,
    required this.url,
    this.description,
    this.app,
    this.host,
    this.color,
    this.up,
    this.ms,
    this.downSince,
    this.hours = const [],
    this.icon,
  });
  final String name;
  final String url;
  // from services.json (optional: QUICK_LINKS only gives name and URL)
  final String? description;

  /// recommended app to use it with
  final String? app;

  /// name of the member hosting it
  final String? host;
  final String? color;
  // reachability check done by the server
  /// null = not checked yet
  final bool? up;
  final double? ms;

  /// start of the ongoing outage (epoch ms), null if it answers
  final int? downSince;

  /// 24 hourly buckets: fraction of successful checks, null = no data
  final List<double?> hours;

  /// the service's icon, served by Netmap itself (a same-origin path); null = none
  final String? icon;

  factory QuickLink.fromJson(Json j) => QuickLink(
    name: _str(j['name']) ?? '',
    url: _str(j['url']) ?? '',
    description: _str(j['description']),
    app: _str(j['app']),
    host: _str(j['host']),
    color: _str(j['color']),
    up: _bool(j['up']),
    ms: _dbl(j['ms']),
    downSince: _int(j['downSince']),
    hours: _nullableNums(j['hours']),
    icon: _str(j['icon']),
  );
}

class Snapshot {
  const Snapshot({
    this.updatedAt,
    required this.networkId,
    required this.networkName,
    this.net,
    this.links = const [],
    this.total,
    this.pollSeconds,
    this.pending = const [],
    this.health,
    this.nodes = const [],
    this.metrics,
    this.events = const [],
    this.error,
  });

  /// epoch ms of the last successful ZTNET poll
  final int? updatedAt;
  final String networkId;
  final String networkName;
  final NetConfig? net;
  final List<QuickLink> links;
  final int? total;
  final int? pollSeconds;
  final List<Pending> pending;
  final Health? health;
  final List<NetNode> nodes;
  final bool? metrics;
  final List<NetEvent> events;
  final String? error;

  factory Snapshot.fromJson(Json j) => Snapshot(
    updatedAt: epochMs(j['updatedAt']),
    networkId: _str(j['networkId']) ?? '',
    networkName: _str(j['networkName']) ?? '',
    net: _obj(j['net']) == null ? null : NetConfig.fromJson(_obj(j['net'])!),
    links: _objs(j['links'], QuickLink.fromJson),
    total: _int(j['total']),
    pollSeconds: _int(j['pollSeconds']),
    pending: _objs(j['pending'], Pending.fromJson),
    health: _obj(j['health']) == null ? null : Health.fromJson(_obj(j['health'])!),
    nodes: _objs(j['nodes'], NetNode.fromJson),
    metrics: _bool(j['metrics']),
    events: _objs(j['events'], NetEvent.fromJson).whereType<NetEvent>().toList(),
    error: _str(j['error']),
  );
}

class WhoAmI {
  const WhoAmI({required this.ip, this.name, this.id});
  final String ip;
  final String? name;
  final String? id;
  factory WhoAmI.fromJson(Json j) => WhoAmI(ip: _str(j['ip']) ?? '', name: _str(j['name']), id: _str(j['id']));
}
