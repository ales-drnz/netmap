// From raw API data to the model the pages render.
// Pure functions only: no state, no fetching (text follows the current language).
import type { NetEvent, NetNode } from '$shared/api';
import { i18n, t } from './i18n/index.svelte';
import { cap, type DeviceType, ownerOf, typeOf } from './naming';
import { deviceMedian, isActive } from './stats';

export type Status = 'direct' | 'relay' | 'off';

/**
 * What the status marker and badge show (shape + colour + word):
 * direct-lan / direct-wan = online direct (same LAN / over the internet),
 * relay, offline, fault (half-open: we talk, it doesn't answer), unknown (no data).
 */
export type StatusKind = 'direct-lan' | 'direct-wan' | 'relay' | 'offline' | 'fault' | 'unknown';

export interface Device {
  id: string;
  name: string;
  /** person key (lowercase), or the whole name when it can't be inferred */
  owner: string;
  ownerLabel: string;
  type: DeviceType;
  status: Status;
  kind: StatusKind;
  ip: string | null;
  /** last latency sample, only when online and direct */
  ms: number | null;
  /** median of the recent samples (spark), only when online and direct: the number to show */
  median: number | null;
  /** online, or seen within the last 7 days */
  active: boolean;
  node: NetNode;
}

export interface Person {
  key: string;
  label: string;
  devices: Device[];
  online: number;
}

export const statusOf = (n: NetNode): Status => (!n.online ? 'off' : n.relayed ? 'relay' : 'direct');

export const statusKindOf = (n: NetNode): StatusKind =>
  !n.online ? 'offline' : n.halfOpen ? 'fault' : n.relayed ? 'relay' : n.link === 'lan' ? 'direct-lan' : 'direct-wan';

export const statusLabel = (s: Status) => t(`status.${s}`);

/** the short word of a status badge: LAN / Internet / Relay / Offline / One-way / Unknown */
export const kindLabel = (k: StatusKind) => t(`badge.${k}`);

export function toDevice(n: NetNode, now = Date.now()): Device {
  const direct = n.online && !n.relayed;
  const owner = ownerOf(n.name) ?? n.name.toLowerCase();
  return {
    id: n.id,
    name: n.name,
    owner,
    ownerLabel: cap(owner),
    type: typeOf(n.name) ?? (n.hub ? 'server' : 'pc'),
    status: statusOf(n),
    kind: statusKindOf(n),
    ip: n.ips[0] ?? null,
    ms: direct ? n.latencyMs : null,
    median: direct ? (deviceMedian(n) ?? n.latencyMs) : null,
    active: isActive(n, now),
    node: n,
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

// ---------- statistics (pure, in stats.ts) ----------

export {
  availability,
  avg,
  BEAT_MS,
  DAY_MS,
  deviceMedian,
  HOUR_MS,
  isActive,
  lastSeenMs,
  median,
  quantile,
  seqStep,
  seriesStart,
  typicalLatency,
  WEEK_MS,
} from './stats';

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
/** per event kind: tone, icon, the Activity filter it belongs to, and the status marker to draw */
export const EVENT_META: Record<NetEvent['kind'], { tone: EvTone; icon: string; filter: string; marker: StatusKind }> =
  {
    offline: { tone: 'off', icon: 'i-down', filter: 'off', marker: 'offline' },
    netdrop: { tone: 'spike', icon: 'i-warn', filter: 'off', marker: 'fault' },
    online: { tone: 'on', icon: 'i-up', filter: 'on', marker: 'direct-wan' },
    relay: { tone: 'relay', icon: 'i-relay', filter: 'path', marker: 'relay' },
    direct: { tone: 'on', icon: 'i-bolt', filter: 'path', marker: 'direct-wan' },
    spike: { tone: 'spike', icon: 'i-bolt', filter: 'spike', marker: 'fault' },
    pending: { tone: 'join', icon: 'i-key', filter: 'join', marker: 'unknown' },
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
