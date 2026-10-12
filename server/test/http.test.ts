import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { serve } from '@hono/node-server';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { Snapshot } from '../../shared/api.js';
import { createApp, resolveStatic } from '../src/http.js';

const snap = (n: number): Snapshot => ({
  updatedAt: `t${n}`,
  networkId: 'x',
  networkName: 'x',
  net: null,
  links: [],
  nodes: [],
  events: [],
  error: null,
});

/** HTTP request with the EXACT path (fetch would normalize the `..`) */
function rawGet(port: number, p: string): Promise<{ status: number; headers: http.IncomingHttpHeaders; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, path: p, method: 'GET' }, (res) => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (d) => {
        body += d;
      });
      res.on('end', () => resolve({ status: res.statusCode ?? 0, headers: res.headers, body }));
    });
    req.on('error', reject);
    req.end();
  });
}

describe('HTTP', () => {
  let dir: string;
  let port: number;
  let server: ReturnType<typeof serve>;
  let current = snap(0);
  const listeners = new Set<(s: Snapshot) => void>();
  const push = (s: Snapshot) => {
    current = s;
    for (const l of listeners) l(s);
  };

  beforeAll(async () => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'netmap-http-'));
    const web = path.join(dir, 'app', 'web');
    fs.mkdirSync(path.join(web, '_app/immutable/chunks'), { recursive: true });
    fs.writeFileSync(path.join(web, 'index.html'), 'SPA');
    fs.writeFileSync(path.join(web, 'favicon.ico'), 'ico');
    fs.writeFileSync(path.join(web, 'manifest.webmanifest'), '{}');
    fs.writeFileSync(path.join(web, '_app/immutable/chunks/a.js'), 'chunk');
    fs.writeFileSync(path.join(web, '_app/version.json'), '{}');
    // secrets outside the served folder
    fs.writeFileSync(path.join(dir, 'secret.txt'), 'SECRET');
    fs.writeFileSync(path.join(dir, 'app', 'secret.txt'), 'SECRET');
    fs.symlinkSync(path.join(dir, 'secret.txt'), path.join(web, 'link.txt'));

    const app = createApp({
      snapshot: () => current,
      subscribe: (fn) => {
        listeners.add(fn);
        return () => listeners.delete(fn);
      },
      webDir: web,
      whoamiTestIp: '',
      heartbeatMs: 200,
    });
    await new Promise<void>((r) => {
      server = serve({ fetch: app.fetch, port: 0, hostname: '127.0.0.1' }, (info) => {
        port = info.port;
        r();
      });
    });
  });

  afterAll(() => {
    server?.close();
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('/api/nodes and /api/whoami: uncached JSON', async () => {
    const r = await rawGet(port, '/api/nodes?x=1');
    expect(r.headers['content-type']).toBe('application/json; charset=utf-8');
    expect(r.headers['cache-control']).toBe('no-store');
    expect(JSON.parse(r.body).updatedAt).toBe('t0');
    const w = await rawGet(port, '/api/whoami');
    expect(JSON.parse(w.body)).toEqual({ ip: '127.0.0.1' });
  });

  it.each([
    '/../secret.txt',
    '/../../secret.txt',
    '/%2e%2e/secret.txt',
    '/%2e%2e%2fsecret.txt',
    '/..%2fsecret.txt',
    '/a/../../secret.txt',
    '/%2e%2e/%2e%2e/secret.txt',
    '/..%2f..%2fsecret.txt',
    '/..%5c..%5csecret.txt',
    '/%00index.html',
    '/link.txt',
    '/%E0%A4%A',
  ])('no path traversal: %s', async (p) => {
    const r = await rawGet(port, p);
    expect(r.body).not.toContain('SECRET');
  });

  it('static files: right type, immutable only for hashed bundles', async () => {
    const chunk = await rawGet(port, '/_app/immutable/chunks/a.js');
    expect(chunk.body).toBe('chunk');
    expect(chunk.headers['content-type']).toBe('text/javascript; charset=utf-8');
    expect(chunk.headers['cache-control']).toBe('public, max-age=31536000, immutable');
    const ico = await rawGet(port, '/favicon.ico');
    expect(ico.headers['content-type']).toBe('image/x-icon');
    expect(ico.headers['cache-control']).toBe('no-cache');
    const mf = await rawGet(port, '/manifest.webmanifest');
    expect(mf.headers['content-type']).toBe('application/manifest+json');
    const v = await rawGet(port, '/_app/version.json');
    expect(v.headers['content-type']).toBe('application/json; charset=utf-8');
  });

  it('SPA fallback for paths that are not files', async () => {
    for (const p of ['/', '/devices', '/map?d=abc']) {
      const r = await rawGet(port, p);
      expect(r.status, p).toBe(200);
      expect(r.body, p).toBe('SPA');
      expect(r.headers['content-type']).toBe('text/html; charset=utf-8');
      expect(r.headers['cache-control']).not.toContain('immutable');
    }
    const missing = await rawGet(port, '/missing.js');
    expect(missing.body).toBe('SPA');
  });

  it('unknown API paths are a 404, not the SPA', async () => {
    const r = await rawGet(port, '/api/nope');
    expect(r.status).toBe(404);
    expect(r.body).toBe('Not found');
  });

  it('missing web folder: 404 with an explanation', async () => {
    const app = createApp({
      snapshot: () => current,
      subscribe: () => () => {},
      webDir: path.join(dir, 'nope'),
      whoamiTestIp: '',
    });
    const r = await app.request('/');
    expect(r.status).toBe(404);
    expect(await r.text()).toMatch(/web/i);
  });

  it('/api/stream: snapshot right away, then on every refresh, heartbeat, cleanup on close', async () => {
    const ac = new AbortController();
    const res = await fetch(`http://127.0.0.1:${port}/api/stream`, { signal: ac.signal });
    expect(res.headers.get('content-type')).toBe('text/event-stream');
    const reader = (res.body as ReadableStream<Uint8Array>).getReader();
    const dec = new TextDecoder();
    let buf = '';
    const readUntil = async (needle: string) => {
      while (!buf.includes(needle)) {
        const { value, done } = await reader.read();
        if (done) throw new Error('stream closed');
        buf += dec.decode(value);
      }
    };
    await readUntil('\n\n');
    expect(buf).toMatch(/^event: snapshot\ndata: \{"updatedAt":"t0"/);
    expect(listeners.size).toBe(1);
    push(snap(1));
    await readUntil('"t1"');
    await readUntil(': ping');
    ac.abort();
    await reader.cancel().catch(() => {});
    for (let i = 0; i < 50 && listeners.size; i++) await new Promise((r) => setTimeout(r, 20));
    expect(listeners.size).toBe(0);
  });
});

describe('path resolution (pure)', () => {
  it('resolveStatic rejects .., NUL, backslashes and broken encodings', () => {
    expect(resolveStatic('/srv/web', '../x')).toBeNull();
    expect(resolveStatic('/srv/web', '%2e%2e/x')).toBeNull();
    expect(resolveStatic('/srv/web', 'a\\..\\x')).toBeNull();
    expect(resolveStatic('/srv/web', '%00')).toBeNull();
    expect(resolveStatic('/srv/web', '%E0%A4%A')).toBeNull();
    expect(resolveStatic('/srv/web', '')).toBe('fallback');
    expect(resolveStatic('/srv/web', 'route/x')).toBe('fallback');
  });
});
