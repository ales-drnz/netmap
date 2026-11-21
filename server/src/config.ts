// Configuration: every environment variable is read in one place, with the
// same names and defaults as the original server.js.

import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { QuickLink } from '../../shared/api.js';

export interface Config {
  port: number;
  bindHost: string;
  ztnetUrl: string;
  apiToken: string;
  networkId: string;
  pollSeconds: number;
  /** already lowercase; '' = no hub */
  hubNodeName: string;
  showOffline: boolean;
  quickLinks: QuickLink[];
  onlineWindowMs: number;
  ztServiceUrl: string;
  /** '' = ZeroTier service cannot be queried */
  ztToken: string;
  /** why `ztToken` is empty; null when there is a token */
  ztTokenError: ZtTokenError | null;
  spikeMs: number;
  historyFile: string;
  saveSeconds: number;
  /** '' = use the connection's real address */
  whoamiTestIp: string;
  /** the built web UI */
  webDir: string;
}

export class ConfigError extends Error {}

/**
 * Why the ZeroTier token could not be read. Kept apart because each one needs a
 * different fix: a missing file means the volume is not mounted, an unreadable
 * one means it IS mounted but the process lacks the rights (ZeroTier writes it
 * root:root 0600).
 */
export type ZtTokenError = 'token-unreadable' | 'token-missing' | 'token-error';

export const AUTHTOKEN_FILE = '/var/lib/zerotier-one/authtoken.secret';

// App folder: in the bundle (`dist/server.mjs`) it is the bundle's own folder,
// which holds `web/`; running the sources with tsx it is the repo root, two
// levels above `server/src/`. Paths are always relative to this file, never to
// the working directory.
declare const __NETMAP_BUNDLE__: boolean | undefined;
const inBundle = () => typeof __NETMAP_BUNDLE__ !== 'undefined' && __NETMAP_BUNDLE__;
export function appDir(): string {
  const here = dirname(fileURLToPath(import.meta.url));
  return inBundle() ? here : resolve(here, '../..');
}

export interface LoadOptions {
  /** reads the token file; replaceable so tests can simulate EACCES/ENOENT */
  readAuthtoken?: (file: string) => string;
  /** uid of this process, only for the log message */
  getuid?: () => number | undefined;
  log?: (msg: string) => void;
}

/** Maps a failed read of the token file to the cause the user has to fix. */
export function classifyTokenError(err: unknown): ZtTokenError {
  const code = (err as NodeJS.ErrnoException | null)?.code;
  if (code === 'EACCES' || code === 'EPERM') return 'token-unreadable';
  if (code === 'ENOENT' || code === 'ENOTDIR') return 'token-missing';
  return 'token-error';
}

// One message per cause, each saying what to do: the old single "not found"
// sent people with a correctly mounted volume to go and mount it again.
function tokenErrorMessage(kind: ZtTokenError, file: string, uid: number | undefined, err: unknown): string {
  const off = 'latency, relay/direct links and the local ZeroTier status are disabled';
  const who = uid === undefined ? 'this process' : `uid ${uid}`;
  if (kind === 'token-unreadable') {
    return (
      `ZeroTier authtoken ${file} exists but is not readable by ${who} (permission denied): ${off}. ` +
      'ZeroTier writes it root-only: run Netmap as root (the image starts as root, reads it and drops to ' +
      'uid 1000 by itself; do not set `user:` in compose), or pass the token with ZT_AUTHTOKEN.'
    );
  }
  if (kind === 'token-missing') {
    return (
      `ZeroTier authtoken not found at ${file}: ${off}. Mount the zerotier volume ` +
      '(zerotier:/var/lib/zerotier-one:ro), point ZT_AUTHTOKEN_FILE at the file, or set ZT_AUTHTOKEN.'
    );
  }
  const why = (err as NodeJS.ErrnoException | null)?.code || (err as Error | null)?.message || String(err);
  return `reading ZeroTier authtoken ${file} as ${who} failed (${why}): ${off}. Set ZT_AUTHTOKEN to bypass the file.`;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env, opts: LoadOptions = {}): Config {
  const log = opts.log ?? ((m: string) => console.log(m));
  const PORT = Number(env.PORT || 8082);
  // Interface to listen on. In production 0.0.0.0 (all interfaces, needed to be
  // reachable over ZeroTier/LAN); in development the mock sets 127.0.0.1 so the
  // fake server is NOT exposed to the network.
  const BIND_HOST = env.BIND_HOST || '0.0.0.0';
  const ZTNET_URL = (env.ZTNET_URL || 'http://ztnet:3000').replace(/\/+$/, '');
  const API_TOKEN = env.ZTNET_API_TOKEN || '';
  const NETWORK_ID = env.ZTNET_NETWORK_ID || '';
  const POLL_SECONDS = Math.max(5, Number(env.POLL_SECONDS || 20));
  // Name (or address) of the member to show at the center of the graph, e.g. the NAS.
  const HUB_NODE_NAME = (env.HUB_NODE_NAME || '').trim().toLowerCase();
  // Offline nodes are shown by default; SHOW_OFFLINE=false hides them (they are
  // not even sent to the browser).
  const SHOW_OFFLINE = !/^(0|false|no)$/i.test(env.SHOW_OFFLINE || '');
  // Quick links in the header, format: "Jellyfin=http://ip:8096,Plex=http://ip:32400/web"
  const QUICK_LINKS = (env.QUICK_LINKS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
    .map((s): QuickLink | null => {
      const i = s.indexOf('=');
      return i > 0 ? { name: s.slice(0, i).trim(), url: s.slice(i + 1).trim() } : null;
    })
    .filter((l): l is QuickLink => l !== null);
  const ONLINE_WINDOW_MS = Number(env.ONLINE_WINDOW_MINUTES || 5) * 60 * 1000;

  if (!API_TOKEN || !NETWORK_ID) {
    throw new ConfigError('Error: the ZTNET_API_TOKEN and ZTNET_NETWORK_ID variables are required.');
  }

  // Controller->peer latency: read from the local ZeroTier service, reachable
  // because netmap shares the zerotier container's network namespace. The token
  // comes from the zerotier volume mounted read-only (or from ZT_AUTHTOKEN).
  // This runs BEFORE privileges are dropped (see privileges.ts): the file is
  // root-only, so this is the one moment the process can read it.
  const ZT_SERVICE_URL = (env.ZT_SERVICE_URL || 'http://127.0.0.1:9993').replace(/\/+$/, '');
  const ZT_AUTHTOKEN_FILE = env.ZT_AUTHTOKEN_FILE || AUTHTOKEN_FILE;
  let ztToken = (env.ZT_AUTHTOKEN || '').trim();
  let ztTokenError: ZtTokenError | null = null;
  if (!ztToken) {
    const read = opts.readAuthtoken ?? ((f: string) => readFileSync(f, 'utf8'));
    const uid = (opts.getuid ?? (() => process.getuid?.()))();
    try {
      ztToken = read(ZT_AUTHTOKEN_FILE).trim();
      if (!ztToken) throw new Error('the file is empty');
    } catch (err) {
      ztToken = '';
      ztTokenError = classifyTokenError(err);
      log(tokenErrorMessage(ztTokenError, ZT_AUTHTOKEN_FILE, uid, err));
    }
  }

  // a latency is a "spike" if it exceeds this threshold AND is much worse than the recent median
  const SPIKE_MS = Number(env.SPIKE_MS || 150);

  // History persistence: see history/store.ts for why /data.
  const HISTORY_FILE = env.HISTORY_FILE || '/data/history.json';
  const SAVE_SECONDS = Math.max(30, Number(env.SAVE_SECONDS || 120));

  const app = appDir();
  return {
    port: PORT,
    bindHost: BIND_HOST,
    ztnetUrl: ZTNET_URL,
    apiToken: API_TOKEN,
    networkId: NETWORK_ID,
    pollSeconds: POLL_SECONDS,
    hubNodeName: HUB_NODE_NAME,
    showOffline: SHOW_OFFLINE,
    quickLinks: QUICK_LINKS,
    onlineWindowMs: ONLINE_WINDOW_MS,
    ztServiceUrl: ZT_SERVICE_URL,
    ztToken,
    ztTokenError,
    spikeMs: SPIKE_MS,
    historyFile: HISTORY_FILE,
    saveSeconds: SAVE_SECONDS,
    whoamiTestIp: env.WHOAMI_TEST_IP || '',
    webDir: env.WEB_DIR ? resolve(env.WEB_DIR) : join(app, inBundle() ? 'web' : 'app/build/web'),
  };
}
