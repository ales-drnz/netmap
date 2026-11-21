import type { LatencyTrend } from '../../../shared/api.js';
import { dayKey, type HistoryState } from './state.js';

// Daily latency summary, as a HISTOGRAM.
//
// Why it was needed. Traffic is kept for 30 days, uptime for 24 hours, but
// latency only for 90 samples — half an hour. So the most natural question of
// all, "has this node got worse than last week?", could not be answered: we had
// had the data and thrown it away.
//
// Why buckets instead of keeping the samples. Computing the median and the 95th
// percentile at the end of the day would need every value of the day (thousands
// per node). Counting how many samples fall into each bucket instead takes twelve
// numbers per day, and median and percentiles are derived by interpolating
// within the bucket they fall into. It is the same trade-off Prometheus makes
// with its histograms: a little precision is lost, in exchange for being able to
// keep it forever.
export const LAT_EDGES: readonly number[] = [5, 10, 20, 35, 50, 75, 100, 150, 250, 400, 700, Infinity];
export const LAT_DAYS = 30;

export function latBucket(ms: number): number {
  for (let i = 0; i < LAT_EDGES.length; i++) if (ms <= (LAT_EDGES[i] as number)) return i;
  return LAT_EDGES.length - 1;
}

// quantile estimated within the bucket it falls into, by linear interpolation
export function latQuantile(counts: readonly number[], q: number): number | null {
  const tot = counts.reduce((a, b) => a + b, 0);
  if (!tot) return null;
  const target = q * tot;
  let seen = 0;
  for (let i = 0; i < counts.length; i++) {
    const c = counts[i] as number;
    if (!c) continue;
    if (seen + c >= target) {
      const lo = i === 0 ? 0 : (LAT_EDGES[i - 1] as number);
      const edge = LAT_EDGES[i] as number;
      const hi = Number.isFinite(edge) ? edge : lo * 1.5;
      const frac = (target - seen) / c;
      return Math.round(lo + (hi - lo) * Math.min(1, Math.max(0, frac)));
    }
    seen += c;
  }
  return null;
}

// Latency trend: how it went today and how it went in the days before.
// `trend` is the ratio between the recent median and that of the previous period,
// so > 1 means it got worse. It is the only claim the data supports: not "it is
// slow", but "it is slower than it used to be".
export function latencyTrend(state: HistoryState, id: string, now: number): LatencyTrend | null {
  const days = state.history.get(id)?.latDays;
  if (!days) return null;
  const at = (i: number): number[] | null => days[dayKey(now - i * 864e5)] || null;
  const sum = (from: number, to: number) => {
    const acc: number[] = new Array(LAT_EDGES.length).fill(0);
    let n = 0;
    for (let i = from; i < to; i++) {
      const b = at(i);
      if (!b) continue;
      for (let k = 0; k < acc.length; k++) acc[k] = (acc[k] as number) + (b[k] || 0);
      n += b.reduce((a, v) => a + v, 0);
    }
    return { acc, n };
  };
  const recent = sum(0, 2); // today and yesterday
  const before = sum(2, 9); // the week before
  if (recent.n < 20) return null;
  const med = latQuantile(recent.acc, 0.5);
  const p95 = latQuantile(recent.acc, 0.95);
  const prev = before.n >= 20 ? latQuantile(before.acc, 0.5) : null;
  return {
    median: med,
    p95,
    prevMedian: prev,
    trend: prev && med ? Math.round((med / prev) * 100) / 100 : null,
    samples: recent.n,
  };
}
