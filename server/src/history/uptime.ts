import type { HistoryState } from './state.js';

export const BEAT_BUCKETS = 60;
export const BEAT_MS = (24 * 3600e3) / BEAT_BUCKETS; // 24 minutes

// uptime over the last 24h; null until there is at least one sample
export function uptimeOf(state: HistoryState, id: string): number | null {
  const h = state.history.get(id);
  if (!h?.beats.length) return null;
  let up = 0;
  let tot = 0;
  for (const b of h.beats) {
    up += b.up;
    tot += b.tot;
  }
  return tot ? up / tot : null;
}

// 60 time-aligned ticks: windows without data (server just started) stay `null`
// and the browser draws them empty, instead of faking full uptime
export function beatsOf(state: HistoryState, id: string, now: number): (number | null)[] {
  const h = state.history.get(id);
  const byT = new Map((h?.beats || []).map((b) => [b.t, b]));
  const cur = Math.floor(now / BEAT_MS) * BEAT_MS;
  const out: (number | null)[] = [];
  for (let i = BEAT_BUCKETS - 1; i >= 0; i--) {
    const b = byT.get(cur - i * BEAT_MS);
    out.push(b?.tot ? Math.round((b.up / b.tot) * 100) / 100 : null);
  }
  return out;
}
