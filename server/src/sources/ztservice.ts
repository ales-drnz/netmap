// Local ZeroTier service (http://127.0.0.1:9993): /peer, /status, /network.
//
// Controller->peer latency: read from the local ZeroTier service, reachable
// because netmap shares the zerotier container's network namespace. The token
// comes from the zerotier volume mounted read-only (or from ZT_AUTHTOKEN).

import { z } from 'zod';
import type { Link, ZtLocalNetwork, ZtStatus } from '../../../shared/api.js';
import { arr, isRec, rec } from './loose.js';

// A private IP address means the path doesn't go out to the internet: the two
// nodes talk within the same physical network (same home router, or VPN).
// ZeroTier's `paths[].address` has the form "IP/port", not "IP:port".
export function isPrivateAddr(addr: unknown): boolean {
  const ip = String(addr || '')
    .split('/')[0]
    ?.replace(/^\[|\]$/g, '') as string;
  if (/^(10\.|127\.|169\.254\.|192\.168\.)/.test(ip)) return true;
  if (/^172\.(1[6-9]|2\d|3[01])\./.test(ip)) return true; // 172.16.0.0/12
  if (/^(::1$|fe80:|f[cd][0-9a-f]{2}:)/i.test(ip)) return true; // loopback, link-local, ULA
  return false;
}

// Deliberately loose schemas: they check that items are OBJECTS and leave the
// usual per-field conversions to `peerInfo`. An element that is not an object is
// dropped, instead of failing the whole read.
const PathSchema = z.looseObject({
  address: z.unknown().optional(),
  preferred: z.unknown().optional(),
  expired: z.unknown().optional(),
  active: z.unknown().optional(),
  lastReceive: z.unknown().optional(),
  lastSend: z.unknown().optional(),
});
export const PeerSchema = z.looseObject({
  address: z.unknown().optional(),
  role: z.unknown().optional(),
  latency: z.unknown().optional(),
  version: z.unknown().optional(),
  versionMajor: z.unknown().optional(),
  tunneled: z.unknown().optional(),
  paths: z.unknown().optional(),
});
export type RawPeer = z.infer<typeof PeerSchema>;
type RawPath = z.infer<typeof PathSchema>;

/** /peer list: anything that is not an array counts as empty, unreadable elements are dropped. */
export function parsePeerList(json: unknown): RawPeer[] {
  return arr(json).flatMap((x) => {
    const r = PeerSchema.safeParse(x);
    return r.success ? [r.data] : [];
  });
}

/** What is left of a peer after `peerInfo`: no address, only facts. */
export interface PeerInfo {
  latency: number | null;
  version: string | null;
  link: Exclude<Link, 'hub'>;
  tunneled: boolean | null;
  paths: number;
  pathsAlive: number;
  family: 4 | 6 | null;
  lastRecv: number | null;
  lastSend: number | null;
}

// From the /peer response we derive a few facts for each peer. None of them is
// the public IP address: that stays HERE and never reaches the browser. Every
// member of the network sees this page, and a person's public IP reveals where
// they connect from (city, ISP, and so whether they are at home or out). It is
// personal data, not a neutral technical detail.
export function peerInfo(p: RawPeer): PeerInfo {
  const paths: RawPath[] = arr(p.paths).flatMap((x) => {
    const r = PathSchema.safeParse(x);
    return r.success ? [r.data] : [];
  });
  // the "real" path is the preferred, non-expired one; failing that, the first live one
  const best = paths.find((x) => x.preferred && !x.expired) || paths.find((x) => !x.expired) || null;
  const bestAddr = best ? String(best.address ?? '') : '';

  // ZeroTier client version. It is "-1.-1.-1" (or -1) for peers the node has
  // never contacted directly: there the version is simply unknown.
  const vMaj = Number(p.versionMajor);
  const version = Number.isFinite(vMaj) && vMaj >= 0 ? String(p.version || '') : null;

  const lat = Number(p.latency);
  const alive = paths.filter((x) => x.active && !x.expired).length;
  return {
    // -1 = unknown, not "0 ms"
    latency: Number.isFinite(lat) && lat >= 0 ? lat : null,
    version: version && !version.startsWith('-1') ? version : null,
    // No path = the peer is reached only through a relay. `tunneled` is the
    // field ZeroTier dedicates to the same question: when present, it is the
    // direct answer rather than an inferred one. We keep both because not every
    // version exposes it, and the absence of paths is always valid.
    link: !best ? 'relay' : isPrivateAddr(bestAddr) ? 'lan' : 'wan',
    tunneled: typeof p.tunneled === 'boolean' ? p.tunneled : null,
    // how many paths it really has: just one means no fallback if it drops
    paths: paths.length,
    pathsAlive: alive,
    // IPv4 or IPv6 — the FAMILY, not the address: it tells how the node got here
    // without revealing where from
    family: best ? (bestAddr.includes(']') || (bestAddr.match(/:/g) || []).length > 1 ? 6 : 4) : null,
    // when the last packet from this peer arrived
    lastRecv: best && Number(best.lastReceive) > 0 ? Number(best.lastReceive) : null,
    // ...and the last one we sent to it. Comparing the two is what matters: if we
    // talk and it hasn't answered in a while, the path is half dead — quite
    // different from a node that is simply quiet, which used to look the same.
    lastSend: best && Number(best.lastSend) > 0 ? Number(best.lastSend) : null,
  };
}

// The network as seen BY THE LOCAL NODE, which is a different point of view from
// the controller's: here you see whether the configuration was accepted, which
// revision it reached, and whether the virtual port has problems. When the two
// views diverge, that is where the fault is.
export const NET_STATUS_LABEL: Record<string, string> = {
  OK: 'active',
  ACCESS_DENIED: 'access denied',
  NOT_FOUND: 'network not found',
  REQUESTING_CONFIGURATION: 'waiting for configuration',
  PORT_ERROR: 'port error',
  CLIENT_TOO_OLD: 'client too old',
  AUTHENTICATION_REQUIRED: 'authentication required',
};

// `tcpFallbackActive` was the most-missed piece of data: when UDP is blocked,
// ZeroTier falls back to TCP through a relay and the whole network slows down.
// Without it, the map would show many relayed nodes with no way to say why.
//
// `surfaceAddresses` does NOT leave this function: they are the public addresses
// the node is seen with from outside, i.e. the home's public IP. The same rule
// we apply to peer paths holds.
export function statusInfo(json: unknown): ZtStatus {
  const s = rec(json);
  const cfg = rec(rec(s.config).settings);
  return {
    online: !!s.online,
    version: typeof s.version === 'string' && !s.version.startsWith('-1') ? s.version : null,
    // TCP fallback is active right now
    tcpFallback: !!s.tcpFallbackActive,
    // ...or it was forced manually, which explains a permanent relay
    forceTcpRelay: !!cfg.forceTcpRelay,
    allowTcpFallback: cfg.allowTcpFallbackRelay !== false,
    // port mapping (UPnP/NAT-PMP): if it is off, many nodes will never manage
    // to go direct and will stay relayed forever
    portMapping: typeof cfg.portMappingEnabled === 'boolean' ? cfg.portMappingEnabled : null,
    port: Number(cfg.primaryPort) || null,
  };
}

const routesOf = (v: unknown) =>
  arr(v)
    .filter((r): r is Record<string, unknown> => isRec(r) && !!r.target)
    .map((r) => ({ target: String(r.target), via: r.via ? String(r.via) : null }));

export function localNetworkInfo(json: unknown, networkId: string): ZtLocalNetwork | null {
  const found = arr(json).find(
    (x) => isRec(x) && String(x.id || x.nwid || '').toLowerCase() === networkId.toLowerCase(),
  );
  if (!found) return null;
  const n = rec(found);
  const dns = isRec(n.dns) ? n.dns : null;
  const status = n.status as string;
  return {
    status: String(n.status || ''),
    statusLabel: NET_STATUS_LABEL[status] || String(n.status || '—'),
    ok: n.status === 'OK',
    revision: Number.isFinite(Number(n.netconfRevision)) ? Number(n.netconfRevision) : null,
    portError: Number(n.portError) || 0,
    device: n.portDeviceName ? String(n.portDeviceName) : null,
    mtu: Number(n.mtu) || null,
    bridge: !!n.bridge,
    // The DNS this node ACTUALLY received, which is not the same as what the
    // controller says it distributes: configuration propagation sits between the
    // two. If they differ, the change made in ZTNET hasn't reached this node yet
    // — and no `allowDNS` would rescue it.
    dns:
      dns && (dns.domain || (Array.isArray(dns.servers) && dns.servers.length))
        ? {
            domain: dns.domain ? String(dns.domain) : null,
            servers: arr(dns.servers).map(String).filter(Boolean),
          }
        : null,
    // the addresses the network assigned to this node
    addresses: arr(n.assignedAddresses).map(String),
    // the routes as they ARRIVED here: comparable with the configured ones
    routes: routesOf(n.routes),
    // LOCAL settings of this node, not of the network: they explain why a route
    // or the network's DNS might not be applied here.
    //
    // `null` if the field is missing, not `false`: ZeroTier versions that don't
    // expose it would otherwise be reported as "permission denied", i.e. a made-up
    // fault. Not knowing and knowing it's a no are different things.
    allowManaged: typeof n.allowManaged === 'boolean' ? n.allowManaged : null,
    allowGlobal: typeof n.allowGlobal === 'boolean' ? n.allowGlobal : null,
    allowDefault: typeof n.allowDefault === 'boolean' ? n.allowDefault : null,
    allowDNS: typeof n.allowDNS === 'boolean' ? n.allowDNS : null,
  };
}

export interface ZtServiceOptions {
  ztServiceUrl: string;
  ztToken: string;
  networkId: string;
  log?: (...args: unknown[]) => void;
  error?: (...args: unknown[]) => void;
}

// --- local ZeroTier service status ------------------------------------------
// Two endpoints we used not to read at all, which answer questions no per-node
// data can settle: "is it the network that's unwell, or that device?".
export class ZtService {
  /** address -> { latency, version, link, lastRecv, ... } */
  peers = new Map<string, PeerInfo>();
  /** from /status: the node hosting this page */
  status: ZtStatus | null = null;
  /** from /network: OUR network as seen by the local node */
  network: ZtLocalNetwork | null = null;
  private peersLogged = false;
  private statusWarned = false;
  private networkWarned = false;
  private readonly log: (...args: unknown[]) => void;
  private readonly error: (...args: unknown[]) => void;

  constructor(private readonly opts: ZtServiceOptions) {
    this.log = opts.log ?? console.log;
    this.error = opts.error ?? console.error;
  }

  private async get(pathname: string): Promise<unknown> {
    const res = await fetch(`${this.opts.ztServiceUrl}${pathname}`, {
      headers: { 'X-ZT1-Auth': this.opts.ztToken },
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json();
  }

  async refreshStatus(): Promise<void> {
    if (!this.opts.ztToken) return;
    try {
      this.status = statusInfo(await this.get('/status'));
    } catch (err) {
      this.status = null;
      if (!this.statusWarned) {
        this.statusWarned = true;
        this.error('reading ZeroTier /status failed:', (err as Error).message || err);
      }
    }
  }

  async refreshLocalNetwork(): Promise<void> {
    if (!this.opts.ztToken) return;
    try {
      this.network = localNetworkInfo(await this.get('/network'), this.opts.networkId);
    } catch (err) {
      this.network = null;
      if (!this.networkWarned) {
        this.networkWarned = true;
        this.error('reading ZeroTier /network failed:', (err as Error).message || err);
      }
    }
  }

  async refreshPeers(): Promise<void> {
    if (!this.opts.ztToken) return;
    try {
      const list = parsePeerList(await this.get('/peer'));
      this.peers = new Map(
        list
          // PLANET and MOON are ZeroTier roots, not devices of the network
          .filter((p) => !p.role || p.role === 'LEAF')
          .map((p) => [String(p.address || '').toLowerCase(), peerInfo(p)]),
      );
      if (!this.peersLogged) {
        this.peersLogged = true;
        this.log(`ZeroTier service: ${this.peers.size} peers read (latency, version, path type)`);
      }
    } catch (err) {
      this.error('reading ZeroTier peers failed:', (err as Error).message || err);
    }
  }
}
