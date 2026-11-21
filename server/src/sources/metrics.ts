// --- per-node traffic -------------------------------------------------------
// ZeroTier does NOT count bytes per peer: that doesn't exist, in any of its APIs.
// The only per-node measure is `zt_peer_packets`, the number of PACKETS
// exchanged, exposed by the Prometheus /metrics endpoint (it must be enabled with
// `enableMetrics: true` in local.conf). So here we count packets, and we call
// them packets: they are not bytes and must not be passed off as such (a stream
// saturates them, a chat doesn't).
//
// ZeroTier's counters are cumulative and live in RAM: they reset every time its
// container restarts. We take their DELTAS and accumulate them per day in our
// own history, which is persistent. That is where the "who used the NAS the most
// in the last 30 days" ranking comes from, and it fills up over time: the past
// cannot be reconstructed, because nobody recorded it.

import type { Health, NodeTraffic } from '../../../shared/api.js';
import { type DataCounters, dayKey, type HistoryState } from '../history/state.js';

export const TRAFFIC_DAYS = 30;

export interface PromSample {
  name: string;
  labels: Record<string, string>;
  value: number;
}

// Generic Prometheus parser. There used to be a regex tailored to
// `zt_peer_packets` here, the only family we read: but /metrics exposes many
// others, and each would have needed its own regex. A single function returning
// (name, labels, value) makes them all available, and adding one becomes a line
// instead of a parser.
//
// The exact families and labels come from the ZeroTier sources
// (`node/Metrics.cpp` for names, `node/Peer.cpp` for labels), not from
// guesswork: lines have the form  name{key="value",...} number
export function* parseProm(text: string): Generator<PromSample> {
  const re = /^([a-zA-Z_:][a-zA-Z0-9_:]*)(?:\{([^}]*)\})?[ \t]+([0-9.eE+-]+)/gm;
  let m: RegExpExecArray | null;
  // biome-ignore lint/suspicious/noAssignInExpressions: classic RegExp.exec idiom
  while ((m = re.exec(text))) {
    const v = Number(m[3]);
    if (!Number.isFinite(v)) continue;
    const labels: Record<string, string> = {};
    if (m[2]) {
      const lr = /([a-zA-Z_][a-zA-Z0-9_]*)="((?:[^"\\]|\\.)*)"/g;
      let l: RegExpExecArray | null;
      // biome-ignore lint/suspicious/noAssignInExpressions: classic RegExp.exec idiom
      while ((l = lr.exec(m[2]))) labels[l[1] as string] = (l[2] as string).replace(/\\(.)/g, '$1');
    }
    yield { name: m[1] as string, labels, value: v };
  }
}

export interface PeerCounters {
  rx: number;
  tx: number;
  err: number;
  alive: number;
  dead: number;
}

// From the /metrics response alone we derive several different things:
//
//  · packets per node             zt_peer_packets{node_id,direction}
//  · packet errors per node       zt_peer_packet_errors{node_id}
//  · alive and dead paths         zt_peer_path_count{node_id,status}
//  · network BYTES, per protocol  zt_data{protocol,direction}
//  · errors by type               zt_packet_error{error_type,direction}
//
// About `zt_data`, a clarification the README used to get backwards: ZeroTier
// doesn't count bytes PER NODE — that is still true, and the per-device ranking
// rightly keeps talking about packets. But it certainly counts the node's total
// bytes, split between UDP and TCP. And that split is valuable: traffic going
// over TCP is traffic that has given up on the direct path.
//
// We do NOT read `zt_peer_latency`, even though it exists as a histogram. It is
// cumulative since the ZeroTier service started and resets on every restart,
// whereas we already sample latency ourselves at every poll, over a window we
// control. Two percentiles computed over different windows would give two
// different numbers with the same name: better a single one whose origin we can
// explain.
export function readMetrics(text: string): {
  peers: Map<string, PeerCounters>;
  data: DataCounters;
  errors: Map<string, number>;
} {
  const peers = new Map<string, PeerCounters>(); // node_id -> { rx, tx, err, alive, dead }
  const data: DataCounters = { udpRx: 0, udpTx: 0, tcpRx: 0, tcpTx: 0 };
  const errors = new Map<string, number>(); // error_type -> count (incoming)
  const peerOf = (id: string): PeerCounters => {
    let e = peers.get(id);
    if (!e) {
      e = { rx: 0, tx: 0, err: 0, alive: 0, dead: 0 };
      peers.set(id, e);
    }
    return e;
  };

  for (const { name, labels, value } of parseProm(text)) {
    const id = (labels.node_id || '').toLowerCase();
    switch (name) {
      case 'zt_peer_packets':
        if (id) peerOf(id)[labels.direction === 'tx' ? 'tx' : 'rx'] = value;
        break;
      case 'zt_peer_packet_errors':
        if (id) peerOf(id).err = value;
        break;
      case 'zt_peer_path_count':
        if (id) peerOf(id)[labels.status === 'dead' ? 'dead' : 'alive'] = value;
        break;
      case 'zt_data': {
        const k = `${labels.protocol === 'tcp' ? 'tcp' : 'udp'}${labels.direction === 'tx' ? 'Tx' : 'Rx'}` as const;
        data[k] = value;
        break;
      }
      case 'zt_packet_error':
        if (labels.direction !== 'tx' && labels.error_type) {
          errors.set(labels.error_type, (errors.get(labels.error_type) || 0) + value);
        }
        break;
      default:
        break;
    }
  }
  return { peers, data, errors };
}

// On the first sample we don't know how long the counter had been running: the
// delta is zero, not the total. If the value GOES DOWN, ZeroTier restarted from
// scratch and the new value is already the delta.
export const counterDelta = (cur: number, last: number | null | undefined): number =>
  last == null ? 0 : cur >= last ? cur - last : cur;

const DATA_KEYS = ['udpRx', 'udpTx', 'tcpRx', 'tcpTx'] as const;

export interface MetricsOptions {
  ztServiceUrl: string;
  ztToken: string;
  log?: (...args: unknown[]) => void;
  error?: (...args: unknown[]) => void;
}

export class MetricsSource {
  /** /metrics missing: stop asking */
  off = false;
  // If we have NEVER read a counter, metrics are not usable — and that must be
  // said. Looking at the 404 is not enough: ZeroTier with metrics disabled may
  // answer 200 with an empty body, and then the page would show "the ranking fills
  // up over the next days", i.e. it would keep the user waiting forever for
  // something that will never come.
  seen = false;
  // Instantaneous per-node measures (not counters): how many alive and dead
  // paths it has left. They don't go into the history because they don't
  // accumulate — it is a snapshot, and yesterday's snapshot is of no use to anyone.
  peerPaths = new Map<string, { alive: number; dead: number }>(); // node_id -> { alive, dead }
  private logged = false;
  private readonly log: (...args: unknown[]) => void;
  private readonly error: (...args: unknown[]) => void;

  constructor(
    private readonly opts: MetricsOptions,
    private readonly state: HistoryState,
  ) {
    this.log = opts.log ?? console.log;
    this.error = opts.error ?? console.error;
  }

  private unavailable(): void {
    this.off = true;
    this.log(
      'ZeroTier metrics not enabled: the traffic ranking will stay empty (everything else works). ' +
        'To enable it, put {"settings":{"enableMetrics":true}} in /var/lib/zerotier-one/local.conf ' +
        'and restart the zerotier container. In ZeroTier 1.14–1.16.0 it is already on by default.',
    );
  }

  async refresh(now: number): Promise<void> {
    if (!this.opts.ztToken || this.off) return;
    try {
      const res = await fetch(`${this.opts.ztServiceUrl}/metrics`, {
        headers: { 'X-ZT1-Auth': this.opts.ztToken },
        signal: AbortSignal.timeout(5000),
      });
      if (res.status === 404 || res.status === 401) {
        this.unavailable();
        return;
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      this.ingest(await res.text(), now);
    } catch (err) {
      this.error('reading ZeroTier metrics failed:', (err as Error).message || err);
    }
  }

  /** Accumulates a /metrics response into the history. Separate from `refresh` so it can be tested without a network. */
  ingest(text: string, now: number): void {
    const { history, netTraffic, netErrors } = this.state;
    const { peers: counters, data, errors } = readMetrics(text);
    // 200 but no counters: metrics are disabled. Counts as a 404.
    if (!counters.size) {
      if (!this.seen) this.unavailable();
      return;
    }
    this.seen = true;

    const day = dayKey(now);
    this.peerPaths = new Map();
    for (const [id, cur] of counters) {
      this.peerPaths.set(id, { alive: cur.alive, dead: cur.dead });
      const h = history.get(id);
      if (!h) continue; // peer that is not a member of the network (root, or removed node)
      const t = h.traf;
      const dRx = counterDelta(cur.rx, t.lastRx);
      const dTx = counterDelta(cur.tx, t.lastTx);
      const dErr = counterDelta(cur.err, t.lastErr);
      t.lastRx = cur.rx;
      t.lastTx = cur.tx;
      t.lastErr = cur.err;
      if (dRx || dTx || dErr) {
        let b = t.days[day];
        if (!b) {
          b = { rx: 0, tx: 0, err: 0 };
          t.days[day] = b;
        }
        b.rx += dRx;
        b.tx += dTx;
        b.err = (b.err || 0) + dErr;
      }
    }

    // network bytes, split by protocol
    {
      let b = netTraffic.days[day];
      if (!b) {
        b = { udpRx: 0, udpTx: 0, tcpRx: 0, tcpTx: 0 };
        netTraffic.days[day] = b;
      }
      for (const k of DATA_KEYS) {
        b[k] += counterDelta(data[k], netTraffic.last?.[k]);
      }
      netTraffic.last = data;
    }

    // errors by type (incoming only: outgoing ones are caused by us)
    {
      let b = netErrors.days[day];
      if (!b) {
        b = {};
        netErrors.days[day] = b;
      }
      for (const [type, v] of errors) {
        const d = counterDelta(v, netErrors.last?.get(type));
        if (d) b[type] = (b[type] || 0) + d;
      }
      netErrors.last = errors;
    }

    // keep only the last 30 days
    const keep = new Set<string>();
    for (let i = 0; i < TRAFFIC_DAYS; i++) {
      keep.add(dayKey(now - i * 864e5));
    }
    for (const h of history.values()) {
      for (const d of Object.keys(h.traf.days)) if (!keep.has(d)) delete h.traf.days[d];
    }
    for (const bag of [netTraffic.days, netErrors.days]) {
      for (const d of Object.keys(bag)) if (!keep.has(d)) delete bag[d];
    }

    if (!this.logged) {
      this.logged = true;
      this.log(`ZeroTier metrics enabled: ${counters.size} peers (packets, errors, paths) + network bytes`);
    }
  }
}

// network bytes over the last N days, split by protocol
export function netTrafficSummary(state: HistoryState, seen: boolean, now: number): Health['bytes'] {
  if (!seen) return null;
  let udp = 0;
  let tcp = 0;
  const days: { udp: number; tcp: number }[] = [];
  for (let i = TRAFFIC_DAYS - 1; i >= 0; i--) {
    const b = state.netTraffic.days[dayKey(now - i * 864e5)];
    const u = b ? b.udpRx + b.udpTx : 0;
    const t = b ? b.tcpRx + b.tcpTx : 0;
    udp += u;
    tcp += t;
    days.push({ udp: u, tcp: t });
  }
  return { udp, tcp, days };
}

// network packet errors over the last 24 hours, by type
export function netErrorSummary(state: HistoryState, seen: boolean, now: number): Health['errors'] {
  if (!seen) return null;
  const out: Record<string, number> = {};
  for (const i of [0, 1]) {
    const d = dayKey(now - i * 864e5);
    for (const [k, v] of Object.entries(state.netErrors.days[d] || {})) out[k] = (out[k] || 0) + v;
  }
  return Object.entries(out)
    .filter(([, v]) => v > 0)
    .sort((a, b) => b[1] - a[1])
    .map(([type, count]) => ({ type, count }));
}

// a node's traffic summary: 30-day total + daily series
export function trafficOf(state: HistoryState, id: string, now: number): NodeTraffic | null {
  const t = state.history.get(id)?.traf;
  if (!t) return null;
  const days: number[] = [];
  let total = 0;
  for (let i = TRAFFIC_DAYS - 1; i >= 0; i--) {
    const b = t.days[dayKey(now - i * 864e5)];
    const v = b ? b.rx + b.tx : 0;
    days.push(v);
    total += v;
  }
  // packet errors over the last 24 hours: a node piling them up has a link that
  // is degrading, and this shows it before it drops
  let errors = 0;
  for (const i of [0, 1]) {
    errors += t.days[dayKey(now - i * 864e5)]?.err || 0;
  }
  return { packets: total, days, errors };
}
