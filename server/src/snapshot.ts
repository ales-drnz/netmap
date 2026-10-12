// The poll and the public snapshot of the network.
//
// This is the ONLY place where the objects sent to the browser (Snapshot,
// NetNode, ...) are built. Everything in here is visible to every member of the
// network: no public IPs, no `surfaceAddresses`, no tokens. Raw source data
// arrives already sanitized (see `peerInfo` and `statusInfo` in
// sources/ztservice.ts) and here fields are picked one by one — never a spread
// of an object that comes from outside.

import type { NetNode, Pending, Snapshot } from '../../shared/api.js';
import type { Config } from './config.js';
import { detectEvents, detectPending } from './history/events.js';
import { latencyTrend } from './history/latency.js';
import { recordSample } from './history/samples.js';
import type { HistoryState } from './history/state.js';
import { beatsOf, uptimeOf } from './history/uptime.js';
import type { ServiceMonitor } from './services.js';
import { type MetricsSource, netErrorSummary, netTrafficSummary, trafficOf } from './sources/metrics.js';
import {
  isDeleted,
  isOnline,
  type Member,
  memberAddress,
  networkInfo,
  networkName,
  parseMembers,
  pendingInfo,
  versionOf,
  ztFetch,
} from './sources/ztnet.js';
import type { PeerInfo, ZtService } from './sources/ztservice.js';

/** The node before history is added: what can be derived from the poll alone. */
type LiveNode = Omit<NetNode, 'spark' | 'uptime' | 'beats' | 'traffic' | 'latency30' | 'pathsDead'>;

type Listener = (s: Snapshot) => void;

export interface SnapshotDeps {
  config: Config;
  state: HistoryState;
  zt: ZtService;
  metrics: MetricsSource;
  services: ServiceMonitor;
  /** clock that tests can replace */
  now?: () => number;
  error?: (...args: unknown[]) => void;
}

/** An authorized ZTNET member, matched with its peer, as a public node. */
export function liveNode(cfg: Config, m: Member, p: PeerInfo | null, ctx: LiveContext): LiveNode {
  const { now, peersKnown, hubVersion } = ctx;
  const id = memberAddress(m);
  const name = m.name || id;
  const hub = !!cfg.hubNodeName && (name.toLowerCase() === cfg.hubNodeName || id === cfg.hubNodeName);
  const latencyMs = hub ? 0 : (p?.latency ?? null);
  // the controller doesn't update its own lastSeen: the hub hosts this page,
  // so if you are reading it, it is online by definition
  const online = isOnline(m, cfg.onlineWindowMs, now) || hub;
  // conStatus 1 = online but relayed (no direct path); if it is missing, the
  // ZeroTier service tells us: no physical path = relay
  const relayed =
    online && !hub && (m.conStatus === 1 || (m.conStatus == null && peersKnown && (!p || p.link === 'relay')));
  const idleSec = online && !hub && p?.lastRecv ? Math.max(0, Math.round((now - p.lastRecv) / 1000)) : null;
  const sendSec = online && !hub && p?.lastSend ? Math.max(0, Math.round((now - p.lastSend) / 1000)) : null;
  return {
    latencyMs,
    id,
    name,
    ips: Array.isArray(m.ipAssignments) ? (m.ipAssignments as string[]) : [],
    online,
    relayed,
    // 'lan' = same physical network, 'wan' = direct over the internet, 'relay'
    link: hub ? 'hub' : online ? (relayed ? 'relay' : (p?.link ?? null)) : null,
    // ZeroTier client version; now also for relayed nodes
    version: hub ? hubVersion : versionOf(m, p),
    // age of the last packet received from this node, in seconds
    idleSec,
    // Half-open path: we talked to it recently but it hasn't answered in a long
    // time. A node that is quiet because it has nothing to say is quiet in BOTH
    // directions; if only it is quiet, the path is broken and nobody knows yet.
    // Generous threshold (2 minutes) so normal traffic doesn't raise alarms.
    halfOpen: !!(idleSec != null && sendSec != null && idleSec > 120 && sendSec < 30),
    // IPv4 or IPv6 (the family, never the address).
    // the value is the NUMBER 4 or 6: the client is the one writing `IPv4`/`IPv6`
    family: hub ? null : (p?.family ?? null),
    // how many paths it has: 1 means no fallback if that one drops
    paths: hub ? null : (p?.pathsAlive ?? null),
    // free text and colored labels the user already wrote in ZTNET
    note: typeof m.description === 'string' && m.description.trim() ? m.description.trim() : null,
    labels: Array.isArray(m.notations)
      ? m.notations
          .map((x) => (x as { label?: { name?: unknown; color?: unknown } } | null)?.label)
          .filter((l): l is { name: unknown; color?: unknown } => !!l?.name)
          .map((l) => ({ name: String(l.name), color: l.color ? String(l.color) : null }))
      : [],
    // since when it has been a member of the network
    since: Number(m.creationTime) || null,
    lastSeen: m.lastSeen ?? null,
    hub,
  };
}

export interface LiveContext {
  now: number;
  /** the ZeroTier service answered with at least one peer */
  peersKnown: boolean;
  hubVersion: string | null;
}

export class SnapshotService {
  private cache: Snapshot;
  private readonly listeners = new Set<Listener>();
  private readonly now: () => number;
  private readonly error: (...args: unknown[]) => void;

  constructor(private readonly deps: SnapshotDeps) {
    this.now = deps.now ?? Date.now;
    this.error = deps.error ?? console.error;
    const { config } = deps;
    this.cache = {
      updatedAt: null,
      networkId: config.networkId,
      networkName: config.networkId,
      net: null,
      links: deps.services.links(this.now()),
      nodes: [],
      events: [],
      error: null,
    };
  }

  get snapshot(): Snapshot {
    return this.cache;
  }

  /** Receives every new snapshot; returns the function to unsubscribe. */
  subscribe(fn: Listener): () => void {
    this.listeners.add(fn);
    return () => {
      this.listeners.delete(fn);
    };
  }

  get subscriberCount(): number {
    return this.listeners.size;
  }

  private publish(): void {
    for (const fn of this.listeners) {
      try {
        fn(this.cache);
      } catch (err) {
        this.error('sending update failed:', (err as Error).message || err);
      }
    }
  }

  async refresh(): Promise<void> {
    const { config, state, zt, metrics, services } = this.deps;
    try {
      const [network, members] = await Promise.all([
        ztFetch(config, `/network/${config.networkId}`).catch(() => null),
        ztFetch(config, `/network/${config.networkId}/member`),
        zt.refreshPeers(),
        zt.refreshStatus(),
        zt.refreshLocalNetwork(),
        services.probeAll(this.now()),
      ]);
      const now = this.now();
      const list = parseMembers(members).filter((m) => !isDeleted(m));
      const pending: Pending[] = list.filter((m) => m.authorized === false).map((m) => pendingInfo(m, now));
      const ctx: LiveContext = { now, peersKnown: zt.peers.size > 0, hubVersion: zt.status?.version ?? null };
      const all = list
        .filter((m) => m.authorized !== false)
        .map((m) => liveNode(config, m, zt.peers.get(memberAddress(m)) || null, ctx));

      // history is updated for ALL authorized nodes, even those SHOW_OFFLINE
      // hides: if they become visible again, their past is already there
      for (const n of all) recordSample(state, n, now);
      detectEvents(state, all, now, config.spikeMs);
      detectPending(state, pending, now);
      // after recordSample: traffic attaches to nodes that already exist in `history`
      await metrics.refresh(now);

      this.cache = {
        updatedAt: new Date(now).toISOString(),
        networkId: config.networkId,
        networkName: networkName(network, config.networkId),
        net: networkInfo(network),
        links: services.links(now),
        total: all.length,
        pollSeconds: config.pollSeconds,
        // Who asked to join and is waiting. They are not devices of the network and
        // don't belong among the devices: it is a separate list, because the
        // question they raise ("do I let it in?") is different from all the others.
        pending,
        // The state of the NETWORK, not of its nodes: the questions no
        // per-device data can answer.
        health: {
          zt: zt.status,
          local: zt.network,
          bytes: netTrafficSummary(state, metrics.seen, now),
          errors: netErrorSummary(state, metrics.seen, now),
        },
        // the hub stays visible even when offline: the page itself runs on it
        nodes: all
          .filter((n) => config.showOffline || n.online || n.hub)
          .sort((a, b) => (a.online === b.online ? a.name.localeCompare(b.name) : a.online ? -1 : 1))
          .map(
            (n): NetNode => ({
              ...n,
              spark: (state.history.get(n.id)?.lat || []).slice(),
              uptime: uptimeOf(state, n.id),
              beats: beatsOf(state, n.id, now),
              traffic: trafficOf(state, n.id, now),
              // how its latency is today compared to last week
              latency30: latencyTrend(state, n.id, now),
              // Dead paths: read HERE and not with the node's other fields
              // because it comes from /metrics, which runs further down — up
              // there we would have served the previous poll's snapshot.
              pathsDead: metrics.peerPaths.get(n.id)?.dead ?? null,
            }),
          ),
        // the criterion is "have I ever read a counter", not "the server answered":
        // disabled metrics may give a 404 or a 200 with an empty body, and in both
        // cases the page must say they are disabled, not "wait until tomorrow"
        metrics: metrics.seen,
        events: state.events.slice(),
        error: null,
      };
    } catch (err) {
      this.cache = { ...this.cache, error: String((err as Error).message || err) };
      this.error('refresh failed:', (err as Error).message || err);
    }
    this.publish();
  }
}
