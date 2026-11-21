// HTTP: the two public APIs, the SSE stream and the web UI (a static SPA).

import fs from 'node:fs';
import path from 'node:path';
import { Hono } from 'hono';
import { streamSSE } from 'hono/streaming';
import type { Snapshot, WhoAmI } from '../../shared/api.js';

export interface HttpDeps {
  snapshot: () => Snapshot;
  subscribe: (fn: (s: Snapshot) => void) => () => void;
  /** the built web UI (app/build/web) */
  webDir: string;
  /** '' = use the connection's real address */
  whoamiTestIp: string;
  /** the icon of the service at an index of the configuration, if any */
  serviceIcon?: (index: number) => { type: string; bytes: Buffer } | null;
  heartbeatMs?: number;
}

/** the part of `c.env` that @hono/node-server provides */
interface NodeBindings {
  incoming?: { url?: string; socket?: { remoteAddress?: string } };
}

const JSON_HEADERS = { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' };

const MIME: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.webmanifest': 'application/manifest+json',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  // Flutter web: the Wasm build must be application/wasm to compile while it
  // downloads; fonts, shaders and asset manifests are plain bytes
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.bin': 'application/octet-stream',
  '.frag': 'application/octet-stream',
  '.symbols': 'text/plain; charset=utf-8',
};

/**
 * Cross-origin isolation, so the Wasm renderer can use threads. Harmless here:
 * the page loads nothing from other origins.
 */
const ISOLATION_HEADERS = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
};

const isFile = (p: string): boolean => {
  try {
    return fs.statSync(p).isFile();
  } catch {
    return false;
  }
};
const isDir = (p: string): boolean => {
  try {
    return fs.statSync(p).isDirectory();
  } catch {
    return false;
  }
};

/**
 * Web UI: `rest` is the request path without the leading `/`, still encoded.
 * Returns the file to serve, 'fallback' for the SPA, or null when the request
 * tries to leave the folder (or does not decode).
 */
export function resolveStatic(webDir: string, rest: string): string | 'fallback' | null {
  let decoded: string;
  try {
    decoded = decodeURIComponent(rest.split('?')[0] as string);
  } catch {
    return null;
  }
  if (decoded.includes('\0') || decoded.includes('\\')) return null;
  const segs = decoded.split('/').filter((s) => s !== '' && s !== '.');
  if (segs.some((s) => s === '..')) return null;
  if (!segs.length) return 'fallback';
  const root = path.resolve(webDir);
  const full = path.resolve(root, ...segs);
  if (!full.startsWith(root + path.sep)) return null;
  if (!isFile(full)) return 'fallback';
  // a symlink must not lead outside the folder
  try {
    const real = fs.realpathSync(full);
    const realRoot = fs.realpathSync(root);
    if (!real.startsWith(realRoot + path.sep)) return null;
  } catch {
    return null;
  }
  return full;
}

/** raw request path, before any URL-parser normalization */
function rawPathOf(env: NodeBindings | undefined, url: string): string {
  const raw = env?.incoming?.url;
  if (raw) return raw;
  const u = new URL(url);
  return u.pathname + u.search;
}

export function createApp(deps: HttpDeps): Hono<{ Bindings: NodeBindings }> {
  const app = new Hono<{ Bindings: NodeBindings }>();
  const heartbeatMs = deps.heartbeatMs ?? 25_000;

  app.all('/api/nodes', (c) => c.body(JSON.stringify(deps.snapshot()), 200, JSON_HEADERS));

  app.all('/api/whoami', (c) => {
    // traffic arrives over the ZeroTier interface, so the connection's source IP
    // IS the visitor's ZeroTier IP: matching it against the members is enough
    const ip = (deps.whoamiTestIp || c.env?.incoming?.socket?.remoteAddress || '').replace(/^::ffff:/, '');
    const me = deps.snapshot().nodes.find((n) => n.ips.includes(ip)) || null;
    const body: WhoAmI = me ? { ip, name: me.name, id: me.id } : { ip };
    return c.body(JSON.stringify(body), 200, JSON_HEADERS);
  });

  // Server-Sent Events: the current snapshot as soon as a client connects, then
  // a new one after every poll. The periodic comment keeps the connection alive
  // through proxies that close idle ones.
  app.get('/api/stream', (c) =>
    streamSSE(c, async (stream) => {
      let unsubscribe = () => {};
      let heartbeat: ReturnType<typeof setInterval> | undefined;
      const closed = new Promise<void>((resolve) => {
        stream.onAbort(() => {
          clearInterval(heartbeat);
          unsubscribe();
          resolve();
        });
      });
      const send = (s: Snapshot) => {
        stream.writeSSE({ event: 'snapshot', data: JSON.stringify(s) }).catch(() => {});
      };
      send(deps.snapshot());
      if (stream.aborted || stream.closed) return;
      unsubscribe = deps.subscribe(send);
      heartbeat = setInterval(() => {
        stream.write(': ping\n\n').catch(() => {});
      }, heartbeatMs);
      await closed;
    }),
  );

  // service icons, fetched by the server from each service (see icons.ts):
  // the URL carries a content hash, so the browser may keep them
  app.get('/api/services/:index/icon', (c) => {
    const index = Number(c.req.param('index'));
    const icon = Number.isInteger(index) && index >= 0 ? deps.serviceIcon?.(index) : null;
    if (!icon) return c.body('Not found', 404, { 'Content-Type': 'text/plain; charset=utf-8' });
    return c.body(new Uint8Array(icon.bytes), 200, {
      'Content-Type': icon.type,
      'Cache-Control': 'public, max-age=86400',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'",
      'Cross-Origin-Resource-Policy': 'same-origin',
    });
  });

  // unknown API paths are a real 404, never the SPA page
  app.all('/api/*', (c) => c.body('Not found', 404, { 'Content-Type': 'text/plain; charset=utf-8' }));

  app.get('*', (c) => {
    const root = deps.webDir;
    if (!isDir(root)) {
      return c.text('Web UI not installed (missing folder: build the Flutter app first: npm run build:web).', 404);
    }
    const rest = rawPathOf(c.env, c.req.url).replace(/^\/+/, '');
    const resolved = resolveStatic(root, rest);
    if (resolved === null) return c.text('Not found', 404);
    const index = path.join(root, 'index.html');
    const file = resolved === 'fallback' ? index : resolved;
    if (!isFile(file)) return c.text('Not found', 404);
    // Flutter's file names are not content-hashed: the browser keeps them but
    // revalidates every time, so a new release is picked up on the next load
    return c.body(fs.readFileSync(file), 200, {
      'Content-Type': MIME[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-cache',
      ...ISOLATION_HEADERS,
    });
  });

  return app;
}
