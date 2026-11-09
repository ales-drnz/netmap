// The numbers behind Network → Performance. Pure (no Svelte, no i18n) so every
// definition is unit tested in perf.test.ts and identical wherever it's shown.
//
// Definitions (one each, see also stats.ts):
// - online now        = online devices / active devices (online or seen ≤ 7 days)
// - direct share      = direct / online (LAN + internet), relay is the rest
// - typical latency   = median of per-device medians (stats.typicalLatency)
// - outages 24 h      = netdrop incidents + single disconnections of ACTIVE
//                       devices in the last 24 h (from the event log, which the
//                       server caps: it can only under-count, never invent)
// - worse than last week = latency30.trend of devices with enough samples
import type { NetEvent, NetNode } from '$shared/api';
import { DAY_MS, deviceMedian, isActive, median, numbers, quantile } from '../stats';

/** the minimal device shape these helpers need (model.ts `Device` fits) */
export interface DevLike {
  id: string;
  name: string;
  /** person key */
  owner: string;
  node: NetNode;
}

/**
 * The server's spike threshold (SPIKE_MS, default 150 ms). It isn't in the API
 * snapshot, so the UI assumes the default; a custom SPIKE_MS only moves this
 * reference line, never which events are spikes (the server decides those).
 */
export const SPIKE_MS = 150;

/** latency axis domain of the strip and the map: 1–500 ms, log */
export const LAT_DOMAIN: [number, number] = [1, 500];
export const LAT_TICKS = [1, 3, 10, 30, 100, 300];

/** minimum recent samples for a device to be compared with last week */
export const MIN_TREND_SAMPLES = 50;
/** "worse" = at least this much slower than the previous week */
export const WORSE_RATIO = 1.1;

// ------------------------------------------------------------------ KPIs ---

export interface Outages {
  count: number;
  last: number | null;
}

/** netdrop incidents + disconnections of active devices in the last 24 h */
export function outages24h(events: readonly NetEvent[], nodes: readonly NetNode[], now: number): Outages {
  const byId = new Map(nodes.map((n) => [n.id, n]));
  let count = 0;
  let last: number | null = null;
  for (const e of events) {
    if (now - e.t > DAY_MS || e.t > now + 60e3) continue;
    let hit = false;
    if (e.kind === 'netdrop') hit = true;
    else if (e.kind === 'offline') {
      const n = e.id ? byId.get(e.id) : undefined;
      // a device removed from the network or inactive for > 7 days isn't an outage
      hit = !!n && !n.hub && isActive(n, now);
    }
    if (hit) {
      count++;
      if (last == null || e.t > last) last = e.t;
    }
  }
  return { count, last };
}

export interface WeekCompare {
  now: number;
  prev: number;
  /** now / prev */
  ratio: number;
  /** devices that had a previous-week median */
  n: number;
}

/**
 * Typical latency vs the previous week: median of latency30.median vs median of
 * latency30.prevMedian, over the online direct devices that have both. Only when
 * MOST of those devices have a previous week (otherwise it compares two different
 * populations and would mislead) → null.
 */
export function typicalVsLastWeek(nodes: readonly NetNode[]): WeekCompare | null {
  const pool = nodes.filter((n) => !n.hub && n.online && !n.relayed && deviceMedian(n) != null);
  const both = pool.filter((n) => n.latency30?.median != null && n.latency30.prevMedian != null);
  if (!pool.length || both.length * 2 <= pool.length) return null;
  const a = median(numbers(both.map((n) => n.latency30?.median)));
  const b = median(numbers(both.map((n) => n.latency30?.prevMedian)));
  if (a == null || b == null || b <= 0) return null;
  return { now: a, prev: b, ratio: a / b, n: both.length };
}

/** p95 of the per-device medians: "95 % of devices are faster than this" */
export function p95OfMedians(nodes: readonly NetNode[]): number | null {
  return quantile(numbers(nodes.filter((n) => !n.hub && n.online && !n.relayed).map(deviceMedian)), 0.95);
}

// --------------------------------------------------------- latency strip ---

export interface StripRow {
  id: string;
  name: string;
  lan: boolean;
  median: number;
  p10: number;
  p90: number;
  samples: number;
  mine: boolean;
}

/** one row per online direct device with samples, fastest first */
export function latencyStrip(devs: readonly DevLike[], mine: (d: DevLike) => boolean): StripRow[] {
  const rows: StripRow[] = [];
  for (const d of devs) {
    const n = d.node;
    if (n.hub || !n.online || n.relayed) continue;
    const xs = numbers(n.spark ?? []);
    const m = median(xs);
    const p10 = quantile(xs, 0.1);
    const p90 = quantile(xs, 0.9);
    if (m == null || p10 == null || p90 == null) continue;
    rows.push({
      id: d.id,
      name: d.name,
      lan: n.link === 'lan',
      median: m,
      p10,
      p90,
      samples: xs.length,
      mine: mine(d),
    });
  }
  return rows.sort((a, b) => a.median - b.median || a.name.localeCompare(b.name));
}

// --------------------------------------------------- worse than last week ---

export interface TrendRow {
  id: string;
  name: string;
  median: number;
  prev: number;
  trend: number;
  samples: number;
  mine: boolean;
}

/**
 * Devices with a previous-week median and enough recent samples.
 * `candidates` = how many could be compared at all (0 → "needs a week of data");
 * `rows` = the ones at least WORSE_RATIO slower, yours pinned first, then by trend.
 */
export function worseThanLastWeek(
  devs: readonly DevLike[],
  mine: (d: DevLike) => boolean,
  limit = 10,
): { candidates: number; rows: TrendRow[] } {
  const all: TrendRow[] = [];
  for (const d of devs) {
    const l = d.node.latency30;
    if (d.node.hub || !l || l.median == null || l.prevMedian == null || l.prevMedian <= 0) continue;
    if (l.samples < MIN_TREND_SAMPLES) continue;
    all.push({
      id: d.id,
      name: d.name,
      median: l.median,
      prev: l.prevMedian,
      trend: l.trend ?? l.median / l.prevMedian,
      samples: l.samples,
      mine: mine(d),
    });
  }
  const rows = all
    .filter((r) => r.trend >= WORSE_RATIO)
    .sort((a, b) => Number(b.mine) - Number(a.mine) || b.trend - a.trend || a.name.localeCompare(b.name))
    .slice(0, limit);
  return { candidates: all.length, rows };
}

// ------------------------------------------------------ availability 24 h ---

export interface HeatRow {
  id: string;
  name: string;
  uptime: number | null;
  beats: (number | null)[];
  mine: boolean;
}

/**
 * Devices active in the last 24 h, worst uptime first (null uptime last);
 * the ones offline for the whole window (every known bucket 0) are split out
 * so they collapse into one line instead of a wall of grey rows.
 */
export function availabilityRows(
  devs: readonly DevLike[],
  now: number,
  mine: (d: DevLike) => boolean,
): { rows: HeatRow[]; allDayOff: HeatRow[] } {
  const rows: HeatRow[] = [];
  const allDayOff: HeatRow[] = [];
  for (const d of devs) {
    const n = d.node;
    if (n.hub) continue;
    const known = numbers(n.beats ?? []);
    // active in the window: online, seen in the last 24 h, or with any online bucket
    if (!isActive(n, now, DAY_MS) && !known.some((v) => v > 0)) continue;
    const r: HeatRow = { id: d.id, name: d.name, uptime: n.uptime, beats: n.beats ?? [], mine: mine(d) };
    if (!n.online && known.length > 0 && known.every((v) => v <= 0)) allDayOff.push(r);
    else rows.push(r);
  }
  rows.sort(
    (a, b) => (a.uptime ?? 2) - (b.uptime ?? 2) || Number(b.mine) - Number(a.mine) || a.name.localeCompare(b.name),
  );
  allDayOff.sort((a, b) => a.name.localeCompare(b.name));
  return { rows, allDayOff };
}

/**
 * Expected number of devices online per bucket: sum of the fractions of the
 * rows that have data there. A bucket where NO row has data is null (gap).
 */
export function onlineCount(rows: readonly { beats: readonly (number | null)[] }[], buckets = 60): (number | null)[] {
  const out: (number | null)[] = Array.from({ length: buckets }, () => null);
  for (const r of rows) {
    // right-align: the last value of every series is the current bucket
    const off = buckets - r.beats.length;
    r.beats.forEach((v, i) => {
      const k = i + off;
      if (k < 0 || k >= buckets || v == null || !Number.isFinite(v)) return;
      out[k] = (out[k] ?? 0) + v;
    });
  }
  return out;
}

// ------------------------------------------------------------- relays ---

/** time of the latest 'relay' event of each device (events are newest first, but don't rely on it) */
export function relaySince(events: readonly NetEvent[]): Map<string, number> {
  const m = new Map<string, number>();
  for (const e of events) {
    if (e.kind !== 'relay' || !e.id) continue;
    if ((m.get(e.id) ?? -1) < e.t) m.set(e.id, e.t);
  }
  return m;
}

/** the client version run by most nodes (ties: the newest) */
export function commonVersion(nodes: readonly NetNode[]): string | null {
  const m = new Map<string, number>();
  for (const n of nodes) if (n.version) m.set(n.version, (m.get(n.version) ?? 0) + 1);
  let best: string | null = null;
  let bestN = 0;
  for (const [v, c] of m) {
    if (c > bestN || (c === bestN && best != null && cmpVersion(v, best) > 0)) {
      best = v;
      bestN = c;
    }
  }
  return best;
}

export const cmpVersion = (a: string, b: string) => a.localeCompare(b, undefined, { numeric: true });

/** versions with counts, newest first */
export function versionCounts(nodes: readonly NetNode[]): { v: string; n: number }[] {
  const m = new Map<string, number>();
  for (const n of nodes) if (n.version) m.set(n.version, (m.get(n.version) ?? 0) + 1);
  return [...m.entries()].map(([v, n]) => ({ v, n })).sort((a, b) => cmpVersion(b.v, a.v));
}

// ----------------------------------------------------------- top users ---

export interface UsageRow {
  key: string;
  /** person key or device name */
  label: string;
  /** device id when grouped by device */
  id: string | null;
  packets: number;
  share: number;
  /** 30 daily packet counts, oldest first; null = no data that day */
  days: (number | null)[];
  devices: number;
}

/**
 * Packets over 30 days by person (default) or by device: top `limit` + one
 * "others" row (key '__others') with the rest. Devices without traffic data are
 * skipped (not zero: unknown).
 */
export function topUsers(devs: readonly DevLike[], by: 'person' | 'device', limit = 8): UsageRow[] {
  const groups = new Map<string, UsageRow>();
  for (const d of devs) {
    const tr = d.node.traffic;
    if (!tr) continue;
    const key = by === 'person' ? d.owner : d.id;
    const g = groups.get(key) ?? {
      key,
      label: by === 'person' ? d.owner : d.name,
      id: by === 'device' ? d.id : null,
      packets: 0,
      share: 0,
      days: Array.from({ length: 30 }, () => null as number | null),
      devices: 0,
    };
    g.packets += tr.packets;
    g.devices++;
    const off = 30 - tr.days.length;
    tr.days.forEach((v, i) => {
      const k = i + off;
      if (k >= 0 && k < 30 && Number.isFinite(v)) g.days[k] = (g.days[k] ?? 0) + v;
    });
    groups.set(key, g);
  }
  const all = [...groups.values()].filter((g) => g.packets > 0).sort((a, b) => b.packets - a.packets);
  const total = all.reduce((s, g) => s + g.packets, 0);
  for (const g of all) g.share = total ? g.packets / total : 0;
  if (all.length <= limit + 1) return all;
  const top = all.slice(0, limit);
  const rest = all.slice(limit);
  const others: UsageRow = {
    key: '__others',
    label: '',
    id: null,
    packets: rest.reduce((s, g) => s + g.packets, 0),
    share: 0,
    days: Array.from({ length: 30 }, (_, i) => {
      const xs = rest.map((g) => g.days[i]).filter((v): v is number => v != null);
      return xs.length ? xs.reduce((a, b) => a + b, 0) : null;
    }),
    devices: rest.reduce((s, g) => s + g.devices, 0),
  };
  others.share = total ? others.packets / total : 0;
  return [...top, others];
}

// ------------------------------------------------------- network bytes ---

export interface ByteDay {
  /** local midnight of the day */
  t: number;
  udp: number;
  tcp: number;
  total: number;
  /** TCP / total, null when total is 0 */
  tcpShare: number | null;
  /** before the first day with traffic: metrics weren't counting yet */
  missing: boolean;
  /** today: still in progress */
  partial: boolean;
}

/**
 * The server sends 30 days (oldest first, ending today) with zeros for days it
 * has no counters for. Leading zero days are "no data yet" (metrics enabled
 * later, see README 2.3): drawn hatched, never as a zero bar. A zero AFTER the
 * first day with data is a real zero.
 */
export function byteDays(days: readonly { udp: number; tcp: number }[], now: number): ByteDay[] {
  const first = days.findIndex((d) => d.udp + d.tcp > 0);
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  return days.map((d, i) => {
    const back = days.length - 1 - i;
    const t = new Date(today.getFullYear(), today.getMonth(), today.getDate() - back).getTime();
    const total = d.udp + d.tcp;
    return {
      t,
      udp: d.udp,
      tcp: d.tcp,
      total,
      tcpShare: total > 0 ? d.tcp / total : null,
      missing: first < 0 || i < first,
      partial: back === 0,
    };
  });
}

/** TCP share above which traffic is giving up on the direct path */
export const TCP_THRESHOLD = 0.01;
