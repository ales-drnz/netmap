// Pure helpers for the Activity timeline (no Svelte, no i18n): tested in activity.test.ts.
import type { NetEvent, NetNode } from '$shared/api';

/** a stable key for an event (the API has no event id) */
export const eventKey = (e: NetEvent) => `${e.t}-${e.kind}-${e.id ?? e.detail ?? ''}`;

/** local calendar day of a timestamp, as a sortable key "2026-10-19" */
export function dayKey(tm: number): string {
  const d = new Date(tm);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** events (any order) → days newest first, events newest first inside each day */
export function groupByDay(events: readonly NetEvent[]): { key: string; t: number; events: NetEvent[] }[] {
  const m = new Map<string, NetEvent[]>();
  for (const e of [...events].sort((a, b) => b.t - a.t)) {
    const k = dayKey(e.t);
    const list = m.get(k);
    if (list) list.push(e);
    else m.set(k, [e]);
  }
  return [...m.entries()].map(([key, evs]) => ({ key, t: evs[0]?.t ?? 0, events: evs }));
}

/**
 * Keys of the 'offline' events whose device is STILL offline: the device is
 * offline now and nothing newer happened to it (no later online/relay/direct).
 */
export function stillOffline(events: readonly NetEvent[], nodes: readonly NetNode[]): Set<string> {
  const offline = new Set(nodes.filter((n) => !n.online).map((n) => n.id));
  const latest = new Map<string, NetEvent>();
  for (const e of events) {
    if (!e.id || e.kind === 'spike' || e.kind === 'pending') continue;
    const cur = latest.get(e.id);
    if (!cur || e.t > cur.t) latest.set(e.id, e);
  }
  const out = new Set<string>();
  for (const [id, e] of latest) if (e.kind === 'offline' && offline.has(id)) out.add(eventKey(e));
  return out;
}

/** names listed in a netdrop event's detail ("a, b, c…"), without the trailing ellipsis */
export function netdropNames(e: NetEvent): { names: string[]; more: boolean } {
  if (e.kind !== 'netdrop' || !e.detail) return { names: [], more: false };
  const more = /…$/.test(e.detail);
  const names = e.detail
    .replace(/…$/, '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return { names, more: more || (e.count != null && e.count > names.length) };
}

/** counts per filter key (an event belongs to exactly one filter) */
export function countBy(events: readonly NetEvent[], filterOf: (e: NetEvent) => string): Map<string, number> {
  const m = new Map<string, number>();
  for (const e of events) {
    const f = filterOf(e);
    m.set(f, (m.get(f) ?? 0) + 1);
  }
  return m;
}
