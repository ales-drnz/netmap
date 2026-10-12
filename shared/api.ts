// Contract between server and UI: the exact shape of what /api/nodes and
// /api/whoami return. The client imports only these TYPES (no code), so the
// browser bundle drags in nothing from the server.
//
// Every field the server may not know is `| null`: "I don't know" and "no"
// are different things, and the page must be able to tell them apart.

/** 'lan' = same physical network, 'wan' = direct over the internet, 'relay' = no direct path */
export type Link = 'hub' | 'lan' | 'wan' | 'relay';

export interface Label {
  name: string;
  color: string | null;
}

export interface LatencyTrend {
  median: number | null;
  p95: number | null;
  /** median of the previous week, if there are enough samples */
  prevMedian: number | null;
  /** recent median / previous median: > 1 means it got worse */
  trend: number | null;
  samples: number;
}

export interface NodeTraffic {
  /** packets (not bytes) over the last 30 days */
  packets: number;
  /** 30 values, oldest first, ending today */
  days: number[];
  /** packet errors in the last 24 hours */
  errors: number;
}

export interface NetNode {
  id: string;
  name: string;
  ips: string[];
  online: boolean;
  relayed: boolean;
  latencyMs: number | null;
  link: Link | null;
  version: string | null;
  /** seconds since the last packet received */
  idleSec: number | null;
  /** we talk to it but it doesn't answer: a broken path nobody has noticed yet */
  halfOpen: boolean;
  /** address family (never the address itself): 4 or 6 */
  family: 4 | 6 | null;
  /** active paths; 1 = no fallback if it drops */
  paths: number | null;
  pathsDead: number | null;
  note: string | null;
  labels: Label[];
  /** member since (epoch ms) */
  since: number | null;
  lastSeen: string | number | null;
  hub: boolean;
  /** last 90 latency samples; null = sample with no direct latency */
  spark: (number | null)[];
  /** fraction 0..1 over the last 24 hours */
  uptime: number | null;
  /** 60 ticks of 24 minutes each: fraction online, null = no data */
  beats: (number | null)[];
  traffic: NodeTraffic | null;
  latency30: LatencyTrend | null;
}

export interface Pending {
  id: string;
  name: string | null;
  since: number | null;
  waitingSec: number | null;
  /** it was authorized and the authorization was revoked */
  deauthorized: boolean;
}

export type EventKind = 'offline' | 'online' | 'relay' | 'direct' | 'spike' | 'pending' | 'netdrop';

export interface NetEvent {
  t: number;
  id: string | null;
  name: string | null;
  kind: EventKind;
  detail?: string | null;
  /** only for 'netdrop': how many dropped together */
  count?: number;
}

export interface Route {
  target: string;
  via: string | null;
}

export interface Dns {
  domain: string | null;
  servers: string[];
}

/** network configuration as distributed by the controller */
export interface NetConfig {
  routes: Route[];
  pools: { start: string; end: string }[];
  dns: Dns | null;
  private: boolean | null;
  v6: string[] | null;
  mtu: number | null;
  broadcast: boolean | null;
  multicastLimit: number | null;
  creationTime: number | null;
}

/** the ZeroTier service of the node hosting Netmap (/status) */
export interface ZtStatus {
  online: boolean;
  version: string | null;
  tcpFallback: boolean;
  forceTcpRelay: boolean;
  allowTcpFallback: boolean;
  portMapping: boolean | null;
  port: number | null;
}

/** the network as seen by the local node (/network) */
export interface ZtLocalNetwork {
  status: string;
  statusLabel: string;
  ok: boolean;
  revision: number | null;
  portError: number;
  device: string | null;
  mtu: number | null;
  bridge: boolean;
  dns: Dns | null;
  addresses: string[];
  routes: Route[];
  allowManaged: boolean | null;
  allowGlobal: boolean | null;
  allowDefault: boolean | null;
  allowDNS: boolean | null;
}

export interface Health {
  zt: ZtStatus | null;
  local: ZtLocalNetwork | null;
  /** actual network bytes, 30 days; null if metrics are disabled */
  bytes: { udp: number; tcp: number; days: { udp: number; tcp: number }[] } | null;
  errors: { type: string; count: number }[] | null;
}

export interface QuickLink {
  name: string;
  url: string;
  // --- from services.json (optional: QUICK_LINKS only gives name and URL) ---
  description?: string | null;
  /** recommended app to use it with */
  app?: string | null;
  /** name of the member hosting it */
  host?: string | null;
  color?: string | null;
  // --- reachability check done by the server ---
  /** null = not checked yet */
  up?: boolean | null;
  ms?: number | null;
  /** start of the ongoing outage (epoch ms), null if it answers */
  downSince?: number | null;
  /** 24 hourly buckets: fraction of successful checks, null = no data */
  hours?: (number | null)[];
}

export interface Snapshot {
  updatedAt: string | null;
  networkId: string;
  networkName: string;
  net: NetConfig | null;
  links: QuickLink[];
  total?: number;
  pollSeconds?: number;
  pending?: Pending[];
  health?: Health;
  nodes: NetNode[];
  metrics?: boolean;
  events: NetEvent[];
  error: string | null;
}

export interface WhoAmI {
  ip: string;
  name?: string;
  id?: string;
}
