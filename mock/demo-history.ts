// Demo history for the mock: 24 hours of availability, 30 days of latency
// histograms and traffic, and a couple of days of events, so a fresh
// `npm run dev` shows full charts instead of empty placeholders.
//
// It is written in the same format the server saves (see
// server/src/history/store.ts) and loaded at startup like a real history file.
// Deterministic: the same members always give the same history.

import { writeFileSync } from 'node:fs';
import { SCHEMA_VERSION } from '../server/src/history/store.js';
import type { NetEvent } from '../shared/api.js';

interface FakeMember {
  id: string;
  name: string;
  authorized?: boolean;
  deleted?: boolean;
  conStatus: number;
  lastSeen?: string | null;
}

const DAY = 864e5;
const BEAT_MS = (24 * 3600e3) / 60;
const HOUR = 3600e3;
const LAT_EDGES = [5, 10, 20, 35, 50, 75, 100, 150, 250, 400, 700, Number.POSITIVE_INFINITY];

/** small deterministic PRNG (mulberry32) */
function rng(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const dayKey = (t: number) => new Date(t).toISOString().slice(0, 10);
const bucketOf = (ms: number) => LAT_EDGES.findIndex((e) => ms <= e);

export function writeDemoHistory(file: string, members: FakeMember[], services: string[], now = Date.now()): void {
  const r = rng(42);
  const nodes = members.filter((m) => m.authorized !== false && !m.deleted);
  const history: Record<string, unknown> = {};
  const curSlot = Math.floor(now / BEAT_MS) * BEAT_MS;

  nodes.forEach((m, i) => {
    // same base latency the fake ZeroTier service uses for this member
    const base = 8 + ((i * 37) % 90);
    const online = m.conStatus > 0 || m.name === 'nas';
    const relayed = m.conStatus === 1;
    const offlineSince = m.lastSeen ? Date.parse(m.lastSeen) : now;

    const lat = Array.from({ length: 90 }, (_, k) =>
      online && !relayed ? Math.max(1, Math.round(base + Math.sin(k / 6 + i) * 6 + (r() - 0.5) * 8)) : null,
    );

    const beats = [];
    for (let k = 59; k >= 0; k--) {
      const t = curSlot - k * BEAT_MS;
      const tot = 72;
      let up: number;
      if (online) up = r() < 0.06 ? Math.round(tot * (0.4 + r() * 0.5)) : tot;
      else up = t < offlineSince ? tot : 0;
      beats.push({ t, up, tot });
    }

    const latDays: Record<string, number[]> = {};
    const days: Record<string, { rx: number; tx: number; err?: number }> = {};
    for (let d = 0; d < 30; d++) {
      const t = now - d * DAY;
      const k = dayKey(t);
      if (online && !relayed) {
        // a little worse in the most recent days for one device, so the
        // "compared with last week" line has something to say
        const drift = i === 3 && d < 2 ? 1.35 : 1;
        const counts = new Array(LAT_EDGES.length).fill(0) as number[];
        for (let s = 0; s < 120; s++) {
          const v = Math.max(1, base * drift + (r() - 0.5) * base * 0.6 + (r() < 0.03 ? 120 : 0));
          const b = bucketOf(v);
          counts[b] = (counts[b] ?? 0) + 1;
        }
        latDays[k] = counts;
      }
      if (online || t < offlineSince) {
        const heavy = m.name.includes('tv') ? 9 : m.name.includes('pc') ? 4 : 1.2;
        const v = Math.round(heavy * 1e5 * (0.4 + r()));
        days[k] = { rx: Math.round(v * 0.7), tx: Math.round(v * 0.3), err: r() < 0.05 ? 3 : 0 };
      }
    }

    history[m.id] = {
      name: m.name,
      lat,
      latDays,
      beats,
      traf: { lastRx: null, lastTx: null, lastErr: null, days },
    };
  });

  const netDays: Record<string, { udpRx: number; udpTx: number; tcpRx: number; tcpTx: number }> = {};
  for (let d = 0; d < 30; d++) {
    const t = now - d * DAY;
    const weekend = [0, 6].includes(new Date(t).getDay());
    const total = (1.6 + r() * 2.4 + (weekend ? 1.8 : 0)) * 1e9;
    // two days when UDP was blocked somewhere and traffic fell back to TCP
    const tcpShare = d === 9 || d === 21 ? 0.03 : 0.0004;
    netDays[dayKey(t)] = {
      udpRx: Math.round(total * (1 - tcpShare) * 0.6),
      udpTx: Math.round(total * (1 - tcpShare) * 0.4),
      tcpRx: Math.round(total * tcpShare * 0.6),
      tcpTx: Math.round(total * tcpShare * 0.4),
    };
  }

  const byName = (n: string) => nodes.find((m) => m.name === n);
  const ev = (minsAgo: number, name: string, kind: NetEvent['kind'], detail?: string): NetEvent | null => {
    const m = byName(name);
    return m ? { t: now - minsAgo * 60e3, id: m.id, name: m.name, kind, ...(detail ? { detail } : {}) } : null;
  };
  const events = [
    ev(14, 'frank-console', 'relay'),
    ev(52, 'alice-laptop', 'offline'),
    ev(3 * 60 + 8, 'PC-Dave', 'spike', '262 ms'),
    ev(7 * 60 + 40, 'bob-phone', 'direct'),
    {
      t: now - 26 * 3600e3,
      id: null,
      name: null,
      kind: 'netdrop' as const,
      count: 3,
      detail: 'bob-tablet, carol2-pc, lab-pi',
    },
    ev(25 * 60, 'carol2-pc', 'online'),
    ev(31 * 60, 'home-tv', 'offline'),
  ].filter((e): e is NetEvent => e != null);

  const svc: Record<string, unknown> = {};
  const curHour = Math.floor(now / HOUR) * HOUR;
  services.forEach((name, i) => {
    svc[name] = {
      beats: Array.from({ length: 24 }, (_, k) => {
        const t = curHour - (23 - k) * HOUR;
        const up = i === 1 && (k === 6 || k === 7) ? 140 : 180;
        return { t, up, tot: 180 };
      }),
      downSince: null,
    };
  });

  writeFileSync(
    file,
    JSON.stringify({
      schemaVersion: SCHEMA_VERSION,
      savedAt: now,
      history,
      events,
      netTraffic: { days: netDays },
      netErrors: { days: { [dayKey(now)]: { invalid_path: 4, internal_server_error: 1 } } },
      pendingSeen: [],
      services: svc,
    }),
  );
}
