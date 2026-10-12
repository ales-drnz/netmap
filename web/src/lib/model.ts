// From raw API data to the model the pages render.
// Pure functions only: no state, no fetching (text follows the current language).
import type { NetEvent, NetNode } from '$shared/api';
import { i18n, t } from './i18n/index.svelte';
import { cap, type DeviceType, ownerOf, typeOf } from './naming';

export type Status = 'direct' | 'relay' | 'off';
/** one hourly cell: k = always online, p = intermittent, o = offline, n = no data */
export type Cell = 'k' | 'p' | 'o' | 'n';

export interface Device {
  id: string;
  name: string;
  /** person key (lowercase), or the whole name when it can't be inferred */
  owner: string;
  ownerLabel: string;
  type: DeviceType;
  status: Status;
  ip: string | null;
  ms: number | null;
  node: NetNode;
  hours: Cell[];
}

export interface Person {
  key: string;
  label: string;
  devices: Device[];
  online: number;
}

export const statusOf = (n: NetNode): Status => (!n.online ? 'off' : n.relayed ? 'relay' : 'direct');

export const statusLabel = (s: Status) => t(`status.${s}`);

/** 60 ticks of 24 minutes → 24 hourly cells (2.5 ticks per hour) */
export function hoursOf(beats: (number | null)[]): Cell[] {
  const out: Cell[] = [];
  for (let h = 0; h < 24; h++) {
    const slice = beats.slice(Math.floor(h * 2.5), Math.floor((h + 1) * 2.5)).filter((v): v is number => v != null);
    if (!slice.length) out.push('n');
    else {
      const avg = slice.reduce((a, b) => a + b, 0) / slice.length;
      out.push(avg >= 0.98 ? 'k' : avg > 0 ? 'p' : 'o');
    }
  }
  return out;
}

export function toDevice(n: NetNode): Device {
  const owner = ownerOf(n.name) ?? n.name.toLowerCase();
  return {
    id: n.id,
    name: n.name,
    owner,
    ownerLabel: cap(owner),
    type: typeOf(n.name) ?? (n.hub ? 'server' : 'pc'),
    status: statusOf(n),
    ip: n.ips[0] ?? null,
    ms: n.online && !n.relayed ? n.latencyMs : null,
    node: n,
    hours: hoursOf(n.beats ?? []),
  };
}

export function groupPeople(devices: Device[], me: string | null): Person[] {
  const map = new Map<string, Device[]>();
  for (const d of devices) {
    const list = map.get(d.owner) ?? [];
    list.push(d);
    map.set(d.owner, list);
  }
  return [...map.entries()]
    .map(([key, ds]) => ({
      key,
      label: ds[0]?.ownerLabel ?? cap(key),
      devices: ds.sort((a, b) => a.name.localeCompare(b.name)),
      online: ds.filter((d) => d.status !== 'off').length,
    }))
    .sort(
      (a, b) =>
        Number(b.key === me) - Number(a.key === me) ||
        b.devices.length - a.devices.length ||
        a.label.localeCompare(b.label),
    );
}

// ---------- statistics ----------

export const median = (xs: number[]) => {
  const s = xs.slice().sort((a, b) => a - b);
  return s.length ? (s[s.length >> 1] ?? null) : null;
};
export const quantile = (xs: number[], q: number) => {
  const s = xs.slice().sort((a, b) => a - b);
  return s.length ? (s[Math.min(s.length - 1, Math.floor(q * s.length))] ?? null) : null;
};
export const avg = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);

/**
 * Jitter: how much the milliseconds swing from one sample to the next. ZeroTier
 * doesn't expose it, so we compute it from history. Variability, not the
 * average, is what makes a video call stutter.
 */
export function jitter(spark: (number | null)[]): number | null {
  const d: number[] = [];
  for (let i = 1; i < spark.length; i++) {
    const a = spark[i - 1];
    const b = spark[i];
    if (a != null && b != null) d.push(Math.abs(b - a));
  }
  return avg(d);
}

/** network latency per sample: average of the direct nodes in that poll */
export function networkLatencySeries(devices: Device[]): (number | null)[] {
  const len = Math.max(0, ...devices.map((d) => d.node.spark?.length ?? 0));
  const out: (number | null)[] = [];
  for (let i = 0; i < len; i++) {
    const vals: number[] = [];
    for (const d of devices) {
      const s = d.node.spark ?? [];
      const v = s[s.length - len + i];
      if (v != null) vals.push(v);
    }
    out.push(vals.length ? avg(vals) : null);
  }
  return out;
}

// ---------- formats ----------

const toMs = (v: string | number | null | undefined) => (typeof v === 'number' ? v : v ? Date.parse(v) : Number.NaN);

export function timeAgo(v: string | number | null | undefined, now = Date.now()): string {
  const tm = toMs(v);
  if (!Number.isFinite(tm)) return t('time.neverSeen');
  const s = Math.max(0, (now - tm) / 1000);
  if (s < 90) return t('time.now');
  if (s < 3600) return t('time.minAgo', { n: Math.round(s / 60) });
  if (s < 86400) return t('time.hAgo', { n: Math.round(s / 3600) });
  const d = Math.round(s / 86400);
  return d === 1 ? t('time.yesterday') : t('time.daysAgo', { n: d });
}

/** like timeAgo, without the "ago": for "offline for …", "down for …" */
export function elapsed(v: string | number | null | undefined, now = Date.now()): string {
  const tm = toMs(v);
  if (!Number.isFinite(tm)) return t('time.neverSeen');
  const s = Math.max(0, (now - tm) / 1000);
  if (s < 90) return t('time.forNow');
  if (s < 3600) return t('time.forMin', { n: Math.round(s / 60) });
  if (s < 86400) return t('time.forH', { n: Math.round(s / 3600) });
  const d = Math.round(s / 86400);
  return d === 1 ? t('time.forDay') : t('time.forDays', { n: d });
}

/** "last seen 5 min ago", or "never seen" */
export const seen = (v: string | number | null | undefined, now = Date.now()) =>
  Number.isFinite(toMs(v)) ? t('time.seen', { ago: timeAgo(v, now) }) : t('time.neverSeen');

/** a wait in seconds: "5 minutes", "3 hours", "2 days" (short: "5 min") */
export function duration(s: number | null, short = false): string {
  if (s == null) return '—';
  if (s < 3600) {
    const count = Math.max(1, Math.round(s / 60));
    return short ? t('dur.min', { count }) : t('dur.minutes', { count });
  }
  if (s < 86400) return t('dur.hours', { count: Math.round(s / 3600) });
  return t('dur.days', { count: Math.round(s / 86400) });
}

export function since(v: number | null, now = Date.now()): string {
  if (!v) return '—';
  const days = (now - v) / 864e5;
  if (days < 31) return t('dur.days', { count: Math.max(1, Math.round(days)) });
  const m = Math.round(days / 30.4);
  return m < 12 ? t('dur.months', { count: m }) : t('dur.years', { n: num(days / 365, 1) });
}

/** percentage number only, no sign: "99.5" / "99,5" */
export const pctValue = (v: number, digits = 1) => num(v * 100, v > 0.999 ? 0 : digits);

export const pct = (v: number | null | undefined, digits = 1) =>
  v == null ? '—' : t('fmt.pct', { n: pctValue(v, digits) });

export const num = (v: number, digits = 0) => i18n.decimal(v, digits);

export function bytes(n: number): { v: string; unit: string } {
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0;
  let x = n;
  while (x >= 1000 && i < u.length - 1) {
    x /= 1000;
    i++;
  }
  return { v: num(x, x < 10 && i > 0 ? 1 : 0), unit: u[i] ?? 'B' };
}

export const packets = (n: number) =>
  n >= 1e6 ? `${num(n / 1e6, 1)} M` : n >= 1e3 ? `${Math.round(n / 1e3)} k` : String(n);

export const pathLabel = (d: Device) =>
  d.status === 'off'
    ? seen(d.node.lastSeen)
    : d.node.link === 'lan'
      ? t('path.lan')
      : d.node.link === 'relay' || d.status === 'relay'
        ? t('path.relay')
        : d.node.link === 'wan'
          ? t('path.wan')
          : t('path.direct');

// ---------- events ----------

export type EvTone = 'off' | 'on' | 'relay' | 'spike' | 'join';
export const EVENT_META: Record<NetEvent['kind'], { tone: EvTone; icon: string; filter: string }> = {
  offline: { tone: 'off', icon: 'i-down', filter: 'off' },
  netdrop: { tone: 'spike', icon: 'i-warn', filter: 'off' },
  online: { tone: 'on', icon: 'i-up', filter: 'on' },
  relay: { tone: 'relay', icon: 'i-relay', filter: 'path' },
  direct: { tone: 'on', icon: 'i-bolt', filter: 'path' },
  spike: { tone: 'spike', icon: 'i-bolt', filter: 'spike' },
  pending: { tone: 'join', icon: 'i-key', filter: 'join' },
};

export function eventText(e: NetEvent): { title: string; sub: string | null } {
  const name = e.name ?? t('ev.someDevice');
  switch (e.kind) {
    case 'offline':
      return { title: t('ev.offline', { name }), sub: null };
    case 'online':
      return { title: t('ev.online', { name }), sub: null };
    case 'relay':
      return { title: t('ev.relay', { name }), sub: t('ev.relaySub') };
    case 'direct':
      return { title: t('ev.direct', { name }), sub: null };
    case 'spike':
      return { title: t('ev.spike', { name }), sub: e.detail ?? null };
    case 'pending':
      // the server only sets `detail` when access was revoked in the past
      return { title: t('ev.pending', { name }), sub: e.detail ? t('ev.pendingRevokedSub') : t('ev.pendingSub') };
    case 'netdrop':
      return {
        title: e.count != null ? t('ev.netdrop', { count: e.count }) : t('ev.netdropMany'),
        sub: t('ev.netdropSub'),
      };
  }
}

export function dayLabel(tm: number, now = Date.now()): string {
  const d = new Date(tm);
  const today = new Date(now);
  const y = new Date(now - 864e5);
  const same = (a: Date, b: Date) => a.toDateString() === b.toDateString();
  if (same(d, today)) return t('time.Today');
  if (same(d, y)) return t('time.Yesterday');
  return d.toLocaleDateString(i18n.locale, { weekday: 'long', day: 'numeric', month: 'long' });
}

export const hhmm = (tm: number) =>
  new Date(tm).toLocaleTimeString(i18n.locale, { hour: '2-digit', minute: '2-digit' });
