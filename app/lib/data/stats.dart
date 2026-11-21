// Pure numbers about nodes, one definition per concept, used everywhere:
// - "active"          = online now, or seen within the last 7 days
// - "device median"   = median of the device's non-null latency samples (spark)
// - "typical latency" = median of the device medians of online, direct devices
// - "availability"    = mean 24 h uptime of the devices active in that window
//                       (never only the online ones: that would hide outages)
import 'api.dart';

const int minuteMs = 60000;
const int hourMs = 60 * minuteMs;
const int dayMs = 24 * hourMs;
const int weekMs = 7 * dayMs;

/// width of one `beats` bucket: 60 buckets cover 24 hours
const int beatMs = dayMs ~/ 60;

double? median(Iterable<double> xs) {
  final s = xs.toList()..sort();
  return s.isEmpty ? null : s[s.length >> 1];
}

double? quantile(Iterable<double> xs, double q) {
  final s = xs.toList()..sort();
  return s.isEmpty ? null : s[(q * s.length).floor().clamp(0, s.length - 1)];
}

double? avg(Iterable<double> xs) {
  final l = xs.toList();
  return l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;
}

Iterable<double> numbers(Iterable<double?> xs) => xs.whereType<double>().where((v) => v.isFinite);

/// online now, or seen within [window] (default 7 days). Never seen = not active.
bool isActive(NetNode n, int now, {int window = weekMs}) {
  if (n.online) return true;
  final seen = n.lastSeen;
  return seen != null && now - seen <= window;
}

/// median of the recent latency samples; null samples (no direct path) are ignored
double? deviceMedian(NetNode n) => median(numbers(n.spark));

/// the typical latency of the network: median of per-device medians (online, direct, not the hub)
double? typicalLatency(Iterable<NetNode> nodes) => median(numbers(nodes.where((n) => !n.hub && n.online && !n.relayed).map(deviceMedian)));

/// mean 24 h uptime over the devices active in the last 24 h (null = no data at all)
double? availability(Iterable<NetNode> nodes, int now) =>
    avg(numbers(nodes.where((n) => !n.hub && isActive(n, now, window: dayMs)).map((n) => n.uptime)));

/// Availability fraction → step of a sequential scale: -1 = no data, 0 = never
/// online, then 1..5 for (0, .3), [.3, .6), [.6, .9), [.9, .995), ≥ .995.
int seqStep(double? v) {
  if (v == null || !v.isFinite) return -1;
  if (v <= 0) return 0;
  if (v >= .995) return 5;
  if (v >= .9) return 4;
  if (v >= .6) return 3;
  if (v >= .3) return 2;
  return 1;
}

/// start (epoch ms) of bucket 0 of a server series of [n] time-aligned buckets ending with the current one
int seriesStart(int n, int bucketMs, int now) => (now ~/ bucketMs) * bucketMs - (n - 1) * bucketMs;
