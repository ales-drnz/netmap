// ZTNET API (the controller). The ZTNET token can also modify and deauthorize
// members: it stays here and never reaches the browser.

import { z } from 'zod';
import type { NetConfig, Pending } from '../../../shared/api.js';
import { arr, isRec, rec } from './loose.js';
import type { PeerInfo } from './ztservice.js';

export interface ZtnetOptions {
  ztnetUrl: string;
  apiToken: string;
}

export async function ztFetch(opts: ZtnetOptions, apiPath: string): Promise<unknown> {
  const res = await fetch(`${opts.ztnetUrl}/api/v1${apiPath}`, {
    headers: { 'x-ztnet-auth': opts.apiToken },
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`ZTNET ${apiPath} -> HTTP ${res.status}`);
  return res.json();
}

// Member schema: deliberately loose. ZTNET versions name the same fields
// differently and add new ones; here we only require each element to be an
// object, and the few fields that end up verbatim on the page (name, last seen)
// have a type — if they don't match it they count as missing, without breaking
// the poll.
export const MemberSchema = z.looseObject({
  id: z.unknown().optional(),
  address: z.unknown().optional(),
  nodeId: z.unknown().optional(),
  name: z.string().optional().catch(undefined),
  authorized: z.unknown().optional(),
  deleted: z.unknown().optional(),
  permanentlyDeleted: z.unknown().optional(),
  online: z.unknown().optional(),
  conStatus: z.unknown().optional(),
  lastSeen: z.union([z.string(), z.number()]).nullish().catch(null),
  ipAssignments: z.unknown().optional(),
  description: z.unknown().optional(),
  notations: z.unknown().optional(),
  creationTime: z.unknown().optional(),
  lastDeauthorizedTime: z.unknown().optional(),
  vMajor: z.unknown().optional(),
  vMinor: z.unknown().optional(),
  vRev: z.unknown().optional(),
});
export type Member = z.infer<typeof MemberSchema>;

/** Member list: anything that is not an array counts as empty, unreadable elements are dropped. */
export function parseMembers(json: unknown): Member[] {
  return arr(json).flatMap((x) => {
    const r = MemberSchema.safeParse(x);
    return r.success ? [r.data] : [];
  });
}

// The ZeroTier member id is the 10-character hex address; ZTNET versions expose
// it under different field names, so we look for it wherever it is.
export function memberAddress(m: Member): string {
  for (const v of [m.id, m.address, m.nodeId]) {
    if (typeof v === 'string' && /^[0-9a-f]{10}$/i.test(v)) return v.toLowerCase();
  }
  return String(m.id ?? m.nodeId ?? '');
}

export function isOnline(m: Member, onlineWindowMs: number, now: number = Date.now()): boolean {
  if (typeof m.online === 'boolean') return m.online;
  if (typeof m.conStatus === 'number') return m.conStatus > 0; // 0=offline, 1=relay, 2=direct
  const t = typeof m.lastSeen === 'number' ? m.lastSeen : Date.parse(m.lastSeen as string);
  return Number.isFinite(t) && now - t < onlineWindowMs;
}

// Network config (from the network object we already download for the name):
// managed routes, MTU, DNS, IP pools. This is public, static data about the
// network, not about a person — nothing sensitive here, unlike the nodes' public
// IPs. ZeroTier nests everything under `config`, but some ZTNET builds flatten it
// to the top level: we read from both.
export function networkInfo(network: unknown): NetConfig | null {
  if (!network) return null;
  const n = rec(network);
  const c = rec(n.config || network);
  const num = (v: unknown) => (Number.isFinite(Number(v)) ? Number(v) : null);
  const routes = arr(c.routes)
    .filter((r): r is Record<string, unknown> => isRec(r) && !!r.target)
    .map((r) => ({ target: String(r.target), via: r.via ? String(r.via) : null }));
  const pools = arr(c.ipAssignmentPools)
    .filter((p): p is Record<string, unknown> => isRec(p) && !!p.ipRangeStart)
    .map((p) => ({ start: String(p.ipRangeStart), end: String(p.ipRangeEnd || p.ipRangeStart) }));
  const cdns = rec(c.dns);
  const dnsServers = Array.isArray(cdns.servers) ? cdns.servers.map(String).filter(Boolean) : [];
  const dns =
    cdns.domain || dnsServers.length
      ? { domain: (cdns.domain as string | undefined) || null, servers: dnsServers }
      : null;
  // IPv6 assignment: `rfc4193` and `6plane` are the two schemes with which
  // ZeroTier can give every node an IPv6 address with no configuration. If they
  // are off, nodes only have managed IPv4 — which explains why a device isn't
  // reachable the way someone expects.
  const v6: string[] = [];
  const v6m = rec(c.v6AssignMode);
  if (v6m.rfc4193) v6.push('rfc4193');
  if (v6m['6plane']) v6.push('6plane');
  if (v6m.zt) v6.push('managed');
  return {
    routes,
    pools,
    dns,
    // private network = authorization is required to join. It is the most
    // important security fact of the configuration, and we weren't showing it.
    private: typeof c.private === 'boolean' ? c.private : null,
    v6: v6.length ? v6 : null,
    mtu: num(c.mtu),
    // enableBroadcast: ethernet-level broadcast enabled on the network
    broadcast: typeof c.enableBroadcast === 'boolean' ? c.enableBroadcast : null,
    multicastLimit: num(c.multicastLimit),
    creationTime: num(c.creationTime),
  };
}

/** network name: first the one inside `config`, then the top-level one */
export function networkName(network: unknown, fallback: string): string {
  const n = rec(network);
  return (rec(n.config).name as string) || (n.name as string) || fallback;
}

// ZeroTier client version, from two sources in order of preference.
//
// `/peer` knows it only for nodes we contacted DIRECTLY: for relayed ones it is
// "-1.-1.-1", i.e. unknown — which is a pity, because those are exactly the ones
// where you'd want to know whether they run an old client. The controller,
// however, records the version each member reported to it (`vMajor/vMinor/vRev`),
// even for those going through a relay. So: the peer first (fresher), then the
// controller (more complete).
export function versionOf(member: Member, peer: PeerInfo | null): string | null {
  if (peer?.version) return peer.version;
  const maj = Number(member.vMajor);
  const min = Number(member.vMinor);
  const rev = Number(member.vRev);
  if (![maj, min, rev].every(Number.isFinite) || maj < 0) return null;
  return `${maj}.${min}.${rev}`;
}

// Members deleted in ZTNET stay in the database with a flag, and may still show
// up in the controller's list: without this filter they would linger on the map
// as ghosts.
export const isDeleted = (m: Member): boolean => m.deleted === true || m.permanentlyDeleted === true;

// Who is knocking at the door. An unauthorized device is already in the response
// we read at every poll — we used to throw it away with a `filter`, and nobody
// knew someone had asked to join. It is not a device of the network and must not
// be listed among the devices: it is a security fact, and it must be shown.
export function pendingInfo(m: Member, now: number): Pending {
  const id = memberAddress(m);
  const created = Number(m.creationTime) || null;
  return {
    id,
    name: m.name || null,
    // how long it has been waiting
    since: created,
    waitingSec: created ? Math.max(0, Math.round((now - created) / 1000)) : null,
    // if it was authorized once and then lost it, that's a different case from a
    // first attempt: someone revoked it
    deauthorized: Number(m.lastDeauthorizedTime) > 0,
  };
}
