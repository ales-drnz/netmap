// Pure numbers about nodes: no i18n, no Svelte state, so it can be unit tested
// with plain vitest and reused by model.ts, status.ts and every page.
//
// One definition per concept, used everywhere:
// - "active"          = online now, or seen within the last 7 days
// - "device median"   = median of the device's non-null latency samples (spark)
// - "typical latency" = median of the device medians of online, direct devices
// - "availability"    = mean 24 h uptime of the devices active in that window
//                       (never only the online ones: that would hide outages)
import type { NetNode } from '$shared/api';

export const MIN_MS = 60e3;
export const HOUR_MS = 3600e3;
export const DAY_MS = 24 * HOUR_MS;
export const WEEK_MS = 7 * DAY_MS;
/** width of one `beats` bucket: 60 buckets cover 24 hours */
export const BEAT_MS = DAY_MS / 60;

export const median = (xs: number[]): number | null => {
  const s = xs.slice().sort((a, b) => a - b);
  return s.length ? (s[s.length >> 1] ?? null) : null;
};
export const quantile = (xs: number[], q: number): number | null => {
  const s = xs.slice().sort((a, b) => a - b);
  return s.length ? (s[Math.min(s.length - 1, Math.floor(q * s.length))] ?? null) : null;
};
export const avg = (xs: number[]): number | null => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);

export const numbers = (xs: readonly (number | null | undefined)[]): number[] =>
  xs.filter((v): v is number => v != null && Number.isFinite(v));

/** last time the node was seen (epoch ms), null if never / unknown */
export function lastSeenMs(n: Pick<NetNode, 'lastSeen'>): number | null {
  const v = n.lastSeen;
  const tm = typeof v === 'number' ? v : v ? Date.parse(v) : Number.NaN;
  return Number.isFinite(tm) ? tm : null;
}

/** online now, or seen within `windowMs` (default 7 days). Never seen = not active. */
export function isActive(n: Pick<NetNode, 'online' | 'lastSeen'>, now: number, windowMs = WEEK_MS): boolean {
  if (n.online) return true;
  const seen = lastSeenMs(n);
  return seen != null && now - seen <= windowMs;
}

/** median of the recent latency samples; null samples (no direct path) are ignored */
export const deviceMedian = (n: Pick<NetNode, 'spark'>): number | null => median(numbers(n.spark ?? []));

/** the typical latency of the network: median of per-device medians (online, direct, not the hub) */
export function typicalLatency(nodes: readonly NetNode[]): number | null {
  return median(numbers(nodes.filter((n) => !n.hub && n.online && !n.relayed).map(deviceMedian)));
}

/** mean 24 h uptime over the devices active in the last 24 h (null = no data at all) */
export function availability(nodes: readonly NetNode[], now: number): number | null {
  return avg(numbers(nodes.filter((n) => !n.hub && isActive(n, now, DAY_MS)).map((n) => n.uptime)));
}

/**
 * Availability fraction → step of the sequential scale (--seq-0..5):
 * null = no data (-1, drawn as an outlined empty cell), 0 = solid grey (0),
 * then 1..5 for (0, .3), [.3, .6), [.6, .9), [.9, .995), ≥ .995.
 */
export function seqStep(v: number | null | undefined): -1 | 0 | 1 | 2 | 3 | 4 | 5 {
  if (v == null || !Number.isFinite(v)) return -1;
  if (v <= 0) return 0;
  if (v >= 0.995) return 5;
  if (v >= 0.9) return 4;
  if (v >= 0.6) return 3;
  if (v >= 0.3) return 2;
  return 1;
}

/** start (epoch ms) of bucket 0 of a server series of `n` time-aligned buckets ending with the current one */
export const seriesStart = (n: number, bucketMs: number, now: number) =>
  Math.floor(now / bucketMs) * bucketMs - (n - 1) * bucketMs;
