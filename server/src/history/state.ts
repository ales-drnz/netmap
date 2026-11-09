// --- history ---------------------------------------------------------------
// Lives in RAM, but is periodically saved to a file (see store.ts): without
// persistence a container restart would reset the 24h uptime, which would then
// be a meaningless number for the next 24 hours.
//
// Two structures per node, with very different costs:
//  - `lat`: the last SPARK_SAMPLES raw latency values, one per poll → feeds the
//    sparkline. With a 20s poll it covers ~30 minutes.
//  - `beats`: 24 hours aggregated into 60 buckets of 24 minutes, each with how
//    many polls were online out of the total. The 24h uptime and the 60-tick
//    heartbeat bar come from here. Aggregating instead of keeping raw samples
//    brings memory down from thousands of records per node to sixty.

import type { NetEvent } from '../../../shared/api.js';

export const SPARK_SAMPLES = 90;
export const EVENT_MAX = 40;

export interface TrafDay {
  rx: number;
  tx: number;
  err?: number;
}

export interface Traf {
  lastRx: number | null;
  lastTx: number | null;
  lastErr: number | null;
  days: Record<string, TrafDay>;
}

export interface Beat {
  t: number;
  up: number;
  tot: number;
}

// id -> { name, lat: number[], beats: {t,up,tot}[], traf: { lastRx, lastTx, days: {'YYYY-MM-DD': {rx,tx}} } }
export interface NodeHistory {
  lat: (number | null)[];
  /** 'YYYY-MM-DD' -> counts per bucket (see LAT_EDGES) */
  latDays: Record<string, number[]>;
  beats: Beat[];
  traf: Traf;
  name: string;
}

export interface DataCounters {
  udpRx: number;
  udpTx: number;
  tcpRx: number;
  tcpTx: number;
}

export type NodeState = 'on' | 'relay' | 'off';

// Network bytes and errors by type: cumulative counters like the peers' ones,
// so the same care with deltas and the same per-day accumulation.
export interface NetTraffic {
  last: DataCounters | null;
  /** 'YYYY-MM-DD' -> { udpRx, udpTx, tcpRx, tcpTx } */
  days: Record<string, DataCounters>;
}
export interface NetErrors {
  last: Map<string, number> | null;
  /** 'YYYY-MM-DD' -> { type: count } */
  days: Record<string, Record<string, number>>;
}

export interface HistoryState {
  history: Map<string, NodeHistory>;
  /** [{ t, id, name, kind, detail }] — most recent first */
  events: NetEvent[];
  /** id -> 'on' | 'relay' | 'off', snapshot of the previous poll */
  prevStates: Map<string, NodeState>;
  /** nodes currently spiking: avoids logging it again at every poll */
  spiking: Set<string>;
  // Who asked to join. Already reported ids are remembered (and saved in the
  // history), otherwise on every server restart the same request would jump
  // back to the top of the timeline as if it had just arrived.
  pendingSeen: Set<string>;
  netTraffic: NetTraffic;
  netErrors: NetErrors;
  /** service name -> reachability checks (see services.ts) */
  services: Map<string, ServiceHistory>;
}

/** A service's history: HOURLY buckets (not 24-minute ones like nodes), plus the start of the ongoing outage. */
export interface ServiceHistory {
  beats: Beat[];
  downSince: number | null;
}

export function createState(): HistoryState {
  return {
    history: new Map(),
    events: [],
    prevStates: new Map(),
    spiking: new Set(),
    pendingSeen: new Set(),
    netTraffic: { last: null, days: {} },
    netErrors: { last: null, days: {} },
    services: new Map(),
  };
}

export const emptyTraf = (): Traf => ({ lastRx: null, lastTx: null, lastErr: null, days: {} });

export function histOf(state: HistoryState, id: string, name: string): NodeHistory {
  let h = state.history.get(id);
  if (!h) {
    h = { lat: [], latDays: {}, beats: [], traf: emptyTraf(), name };
    state.history.set(id, h);
  }
  if (!h.latDays) h.latDays = {}; // history saved by an older version
  h.name = name;
  return h;
}

/** 'YYYY-MM-DD' (UTC) of the day containing `t` */
export const dayKey = (t: number): string => new Date(t).toISOString().slice(0, 10);
