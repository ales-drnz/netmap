import { LAT_DAYS, LAT_EDGES, latBucket } from './latency.js';
import { dayKey, type HistoryState, histOf, SPARK_SAMPLES } from './state.js';
import { BEAT_MS } from './uptime.js';

/** what a node's history needs at every poll */
export interface SampleNode {
  id: string;
  name: string;
  online: boolean;
  relayed: boolean;
  latencyMs: number | null;
}

export function recordSample(state: HistoryState, node: SampleNode, now: number): void {
  const h = histOf(state, node.id, node.name);

  h.lat.push(node.online && !node.relayed ? node.latencyMs : null);
  if (h.lat.length > SPARK_SAMPLES) h.lat.splice(0, h.lat.length - SPARK_SAMPLES);

  // the day's histogram: only for samples with a real latency
  if (node.online && !node.relayed && node.latencyMs != null) {
    const day = dayKey(now);
    let b = h.latDays[day];
    if (!b) {
      b = new Array(LAT_EDGES.length).fill(0);
      h.latDays[day] = b;
    }
    const k = latBucket(node.latencyMs);
    b[k] = (b[k] as number) + 1;
  }

  // current bucket aligned to a multiple of BEAT_MS: this way every node's ticks
  // cover the same time windows and are comparable
  const slot = Math.floor(now / BEAT_MS) * BEAT_MS;
  const last = h.beats[h.beats.length - 1];
  if (last && last.t === slot) {
    last.tot++;
    if (node.online) last.up++;
  } else h.beats.push({ t: slot, up: node.online ? 1 : 0, tot: 1 });
  const cutoff = now - 24 * 3600e3;
  while (h.beats.length && (h.beats[0] as { t: number }).t < cutoff) h.beats.shift();

  // the daily histogram is pruned here, not together with traffic: that lives
  // inside `refreshMetrics`, which doesn't run when metrics are disabled
  const keep = new Set<string>();
  for (let i = 0; i < LAT_DAYS; i++) keep.add(dayKey(now - i * 864e5));
  for (const d of Object.keys(h.latDays)) if (!keep.has(d)) delete h.latDays[d];
}
