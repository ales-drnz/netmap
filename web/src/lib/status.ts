// The single global verdict shown by the status pill in the top bar.
// Pure: Snapshot + clocks in, a structured verdict out. The text is produced by
// the StatusPill component (this file has no i18n so it can be unit tested).
//
// Priority (the first that applies wins):
//   1. stale data: the browser can't reach the server, or ZTNET isn't answering → danger
//   2. a netdrop (several devices dropped together) in the last hour           → danger
//   3. the hub's ZeroTier is on TCP fallback, or TCP relay is forced            → warn
//   4. some online devices go through a relay                                   → warn
//   5. all good                                                                 → ok
import type { NetEvent, Snapshot } from '$shared/api';
import { HOUR_MS, isActive, typicalLatency } from './stats';

export type Tone = 'ok' | 'warn' | 'danger' | 'neutral';

export type Reason =
  | { kind: 'loading' }
  /** source: who isn't answering. ageSec: how old the data shown is (null = unknown) */
  | { kind: 'stale'; source: 'ztnet' | 'server'; ageSec: number | null; error: string | null }
  | { kind: 'netdrop'; count: number | null; t: number }
  | { kind: 'tcpFallback' }
  | { kind: 'forceTcp' }
  | { kind: 'relay'; count: number }
  | { kind: 'ok' };

export interface Counts {
  /** devices (hub excluded) online or seen within 7 days */
  active: number;
  online: number;
  direct: number;
  lan: number;
  wan: number;
  relay: number;
  /** active devices that are offline now */
  offline: number;
  /** offline for more than 7 days (or never seen): not counted anywhere else */
  inactive: number;
}

export interface Verdict {
  tone: Tone;
  reason: Reason;
  /** seconds since the browser received the last snapshot (null before the first) */
  ageSec: number | null;
  pollSeconds: number;
  counts: Counts;
  /** median of per-device medians, ms */
  typicalMs: number | null;
}

export interface VerdictInput {
  snap: Snapshot | null;
  /** browser clock when the last snapshot arrived (0 = never) */
  receivedAt: number;
  now: number;
  /** the browser can't reach the server right now */
  offline: boolean;
}

/** data older than this many polls (and at least a minute) counts as stale */
const STALE_POLLS = 3;
const STALE_MIN_SEC = 60;

export function countsOf(snap: Snapshot | null, now: number): Counts {
  const c: Counts = { active: 0, online: 0, direct: 0, lan: 0, wan: 0, relay: 0, offline: 0, inactive: 0 };
  for (const n of snap?.nodes ?? []) {
    if (n.hub) continue;
    if (!isActive(n, now)) {
      c.inactive++;
      continue;
    }
    c.active++;
    if (!n.online) c.offline++;
    else {
      c.online++;
      if (n.relayed) c.relay++;
      else {
        c.direct++;
        if (n.link === 'lan') c.lan++;
        else c.wan++;
      }
    }
  }
  return c;
}

const lastNetdrop = (events: NetEvent[], now: number): NetEvent | null =>
  events.filter((e) => e.kind === 'netdrop' && now - e.t <= HOUR_MS).sort((a, b) => b.t - a.t)[0] ?? null;

export function verdict({ snap, receivedAt, now, offline }: VerdictInput): Verdict {
  const pollSeconds = snap?.pollSeconds ?? 20;
  const ageSec = receivedAt ? Math.max(0, Math.round((now - receivedAt) / 1000)) : null;
  const counts = countsOf(snap, now);
  const typicalMs = snap ? typicalLatency(snap.nodes) : null;
  const out = (tone: Tone, reason: Reason): Verdict => ({ tone, reason, ageSec, pollSeconds, counts, typicalMs });

  if (!snap)
    return offline
      ? out('danger', { kind: 'stale', source: 'server', ageSec: null, error: null })
      : out('neutral', { kind: 'loading' });

  const staleAfter = Math.max(STALE_POLLS * pollSeconds, STALE_MIN_SEC);
  if (offline || (ageSec != null && ageSec > staleAfter)) {
    return out('danger', { kind: 'stale', source: 'server', ageSec, error: null });
  }
  if (snap.error) {
    // the server answers but serves the last good ZTNET data: its age is updatedAt
    const upd = snap.updatedAt ? Date.parse(snap.updatedAt) : Number.NaN;
    const age = Number.isFinite(upd) ? Math.max(0, Math.round((now - upd) / 1000)) : null;
    return out('danger', { kind: 'stale', source: 'ztnet', ageSec: age, error: snap.error });
  }

  const drop = lastNetdrop(snap.events ?? [], now);
  if (drop) return out('danger', { kind: 'netdrop', count: drop.count ?? null, t: drop.t });

  const zt = snap.health?.zt;
  if (zt?.tcpFallback) return out('warn', { kind: 'tcpFallback' });
  if (zt?.forceTcpRelay) return out('warn', { kind: 'forceTcp' });
  if (counts.relay) return out('warn', { kind: 'relay', count: counts.relay });
  return out('ok', { kind: 'ok' });
}
