// The page's single data source: a snapshot from the server.
// It tries the stream first (SSE, one snapshot after each server poll); if the
// server doesn't offer it, it falls back to polling /api/nodes at the server's pace.
import type { Snapshot, WhoAmI } from '$shared/api';
import { availability, type Device, groupPeople, type Person, toDevice, typicalLatency } from './model';
import { ownerOf } from './naming';
import { verdict } from './status';

class Live {
  snap = $state<Snapshot | null>(null);
  me = $state<WhoAmI | null>(null);
  /** browser network error (the server isn't responding) */
  offline = $state(false);
  /** when the last snapshot arrived (browser clock) */
  receivedAt = $state(0);
  now = $state(Date.now());

  nodes = $derived(this.snap?.nodes ?? []);
  hub = $derived(this.nodes.find((n) => n.hub) ?? null);
  /** every device except the hub (active and inactive: filter with `d.active`) */
  devices: Device[] = $derived(this.nodes.filter((n) => !n.hub).map((n) => toDevice(n, this.receivedAt || Date.now())));
  myDevice = $derived(this.me?.name ? (this.devices.find((d) => d.name === this.me?.name) ?? null) : null);
  myOwner = $derived(this.me?.name ? ownerOf(this.me.name) : null);
  people: Person[] = $derived(groupPeople(this.devices, this.myOwner));
  online = $derived(this.devices.filter((d) => d.status !== 'off'));
  direct = $derived(this.devices.filter((d) => d.status === 'direct'));
  relay = $derived(this.devices.filter((d) => d.status === 'relay'));
  /** median of per-device medians (the one "typical latency" of the whole UI) */
  typical = $derived(typicalLatency(this.nodes));
  /** mean 24 h uptime of the devices active in the last 24 h */
  availability = $derived(availability(this.nodes, this.receivedAt || Date.now()));
  pending = $derived(this.snap?.pending ?? []);
  events = $derived(this.snap?.events ?? []);
  pollSeconds = $derived(this.snap?.pollSeconds ?? 20);
  ago = $derived(this.receivedAt ? Math.max(0, Math.round((this.now - this.receivedAt) / 1000)) : null);
  /** the global verdict of the status pill (see status.ts) */
  status = $derived(verdict({ snap: this.snap, receivedAt: this.receivedAt, now: this.now, offline: this.offline }));

  #es: EventSource | null = null;
  #timer: ReturnType<typeof setTimeout> | null = null;
  #started = false;

  start() {
    if (this.#started) return;
    this.#started = true;
    setInterval(() => (this.now = Date.now()), 1000);
    this.#whoami();
    this.#stream();
  }

  #accept(s: Snapshot) {
    this.snap = s;
    this.receivedAt = Date.now();
    this.offline = false;
  }

  async #whoami() {
    try {
      const r = await fetch('/api/whoami', { cache: 'no-store' });
      if (r.ok) this.me = (await r.json()) as WhoAmI;
    } catch {
      /* the viewer stays anonymous: the page works anyway */
    }
  }

  #stream() {
    if (typeof EventSource === 'undefined') return this.#poll();
    let opened = false;
    const es = new EventSource('/api/stream');
    this.#es = es;
    es.addEventListener('snapshot', (e) => {
      opened = true;
      this.#accept(JSON.parse((e as MessageEvent).data) as Snapshot);
    });
    es.onerror = () => {
      // never opened: the server has no stream (older version) → polling
      if (!opened) {
        es.close();
        this.#es = null;
        this.#poll();
      } else {
        this.offline = true; // EventSource reconnects on its own
      }
    };
  }

  async #poll() {
    try {
      const r = await fetch('/api/nodes', { cache: 'no-store' });
      if (!r.ok) throw new Error(String(r.status));
      this.#accept((await r.json()) as Snapshot);
    } catch {
      this.offline = true;
    }
    this.#timer = setTimeout(() => this.#poll(), this.pollSeconds * 1000);
  }

  stop() {
    this.#es?.close();
    if (this.#timer) clearTimeout(this.#timer);
  }
}

export const live = new Live();
