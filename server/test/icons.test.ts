import fs from 'node:fs';
import http from 'node:http';
import type { AddressInfo } from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../src/http.js';
import { configuredIcon, discoverIcon, ICON_MAX_BYTES, IconCache, iconLinks, sniffImage } from '../src/icons.js';

const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.from('png body')]);
const ICO = Buffer.concat([Buffer.from([0x00, 0x00, 0x01, 0x00]), Buffer.from('ico body')]);
const SVG = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>');

type Routes = Record<string, (res: http.ServerResponse) => void>;

/** a tiny HTTP server answering [routes]; records every path asked */
async function serve(routes: Routes): Promise<{ origin: string; asked: string[]; close: () => void }> {
  const asked: string[] = [];
  const srv = http.createServer((req, res) => {
    asked.push(req.url ?? '');
    const route = routes[req.url ?? ''];
    if (route) route(res);
    else res.writeHead(404).end();
  });
  await new Promise<void>((r) => srv.listen(0, '127.0.0.1', r));
  const { port } = srv.address() as AddressInfo;
  return { origin: `http://127.0.0.1:${port}`, asked, close: () => srv.close() };
}

const send = (type: string, body: Buffer | string) => (res: http.ServerResponse) =>
  res.writeHead(200, { 'Content-Type': type }).end(body);
const redirect = (to: string) => (res: http.ServerResponse) => res.writeHead(302, { Location: to }).end();

describe('icons: recognising images', () => {
  it('accepts PNG, ICO, JPEG, GIF and WebP by their first bytes, nothing else', () => {
    expect(sniffImage(PNG)).toBe('image/png');
    expect(sniffImage(ICO)).toBe('image/x-icon');
    expect(sniffImage(Buffer.from([0xff, 0xd8, 0xff, 0xe0]))).toBe('image/jpeg');
    expect(sniffImage(Buffer.from('GIF89a...'))).toBe('image/gif');
    expect(sniffImage(Buffer.from('RIFF\0\0\0\0WEBPVP8 '))).toBe('image/webp');
    expect(sniffImage(SVG)).toBeNull();
    expect(sniffImage(Buffer.from('<html>'))).toBeNull();
  });

  it('reads icon links from a page: touch icon first, then the largest, no SVG', () => {
    const html = `<head>
      <link rel="icon" href="/small.png" sizes="16x16">
      <link rel="shortcut icon" href='/big.png' sizes="64x64">
      <link rel="icon" type="image/svg+xml" href="/logo.svg">
      <link rel="apple-touch-icon" href="touch.png">
      <link rel="stylesheet" href="/style.css">
    </head>`;
    expect(iconLinks(html, 'http://svc:8096/web/')).toEqual([
      'http://svc:8096/web/touch.png',
      'http://svc:8096/big.png',
      'http://svc:8096/small.png',
    ]);
  });
});

describe('icons: fetching from a service', () => {
  it('follows a same-origin redirect and takes the icon the page declares', async () => {
    const s = await serve({
      '/': redirect('/web/'),
      '/web/': send('text/html', '<link rel="icon" href="icon.png">'),
      '/web/icon.png': send('image/png', PNG),
    });
    const icon = await discoverIcon(`${s.origin}/`);
    s.close();
    expect(icon?.type).toBe('image/png');
    expect(icon?.bytes.equals(PNG)).toBe(true);
    expect(icon?.hash).toMatch(/^[0-9a-f]{12}$/);
  });

  it('falls back to /favicon.ico, whatever its declared type', async () => {
    const s = await serve({
      '/': send('text/html', '<h1>no icon here</h1>'),
      '/favicon.ico': send('application/octet-stream', ICO),
    });
    const icon = await discoverIcon(`${s.origin}/`);
    s.close();
    expect(icon?.type).toBe('image/x-icon');
  });

  it('never leaves the configured origin: not for a redirect, not for an icon link', async () => {
    const other = await serve({ '/evil.png': send('image/png', PNG), '/': send('text/html', '') });
    const s = await serve({
      '/': send('text/html', `<link rel="icon" href="${other.origin}/evil.png">`),
      '/favicon.ico': redirect(`${other.origin}/evil.png`),
    });
    const icon = await discoverIcon(`${s.origin}/`);
    s.close();
    other.close();
    expect(icon).toBeNull();
    expect(other.asked).toEqual([]);
  });

  it('refuses SVG, HTML and images over the size limit', async () => {
    const big = Buffer.concat([PNG, Buffer.alloc(ICON_MAX_BYTES)]);
    const s = await serve({
      '/': send('text/html', '<link rel="icon" href="/a.png"><link rel="icon" href="/b.png">'),
      '/a.png': send('image/png', SVG),
      '/b.png': send('image/png', big),
      '/favicon.ico': send('text/html', '<html>'),
    });
    const icon = await discoverIcon(`${s.origin}/`);
    s.close();
    expect(icon).toBeNull();
  });

  it('a service that does not answer has no icon, and no error', async () => {
    expect(await discoverIcon('http://127.0.0.1:9/', 500)).toBeNull();
    expect(await discoverIcon('ftp://example/')).toBeNull();
  });

  it('an icon set by hand: a file next to services.json, or a URL', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'netmap-icons-'));
    fs.writeFileSync(path.join(dir, 'jelly.png'), PNG);
    fs.writeFileSync(path.join(dir, 'fake.png'), SVG);
    expect((await configuredIcon('jelly.png', dir))?.type).toBe('image/png');
    expect(await configuredIcon('fake.png', dir)).toBeNull();
    expect(await configuredIcon('missing.png', dir)).toBeNull();
    const s = await serve({ '/i.ico': send('image/x-icon', ICO) });
    expect((await configuredIcon(`${s.origin}/i.ico`, dir))?.type).toBe('image/x-icon');
    s.close();
    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('icons: cache', () => {
  it('fetches once a day, retries a failure after an hour', async () => {
    let calls = 0;
    let give: Buffer | null = null;
    const cache = new IconCache(async () => {
      calls++;
      return give ? { type: 'image/png', bytes: give, hash: 'h' } : null;
    });
    const svc = { url: 'http://svc/' };
    await cache.refresh('a', svc, 0);
    expect(calls).toBe(1);
    expect(cache.get('a')).toBeNull();
    await cache.refresh('a', svc, 30 * 60e3); // failed 30 min ago: not yet
    expect(calls).toBe(1);
    give = PNG;
    await cache.refresh('a', svc, 61 * 60e3);
    expect(calls).toBe(2);
    expect(cache.get('a')?.type).toBe('image/png');
    await cache.refresh('a', svc, 5 * 3600e3); // found: next try tomorrow
    expect(calls).toBe(2);
    cache.forgetAllBut(new Set());
    expect(cache.get('a')).toBeNull();
  });
});

describe('icons: HTTP', () => {
  let server: http.Server;
  let origin = '';
  beforeAll(async () => {
    const app = createApp({
      snapshot: () => ({
        updatedAt: null,
        networkId: 'x',
        networkName: 'x',
        net: null,
        links: [],
        nodes: [],
        events: [],
        error: null,
      }),
      subscribe: () => () => {},
      webDir: '/nonexistent',
      whoamiTestIp: '',
      serviceIcon: (i) => (i === 0 ? { type: 'image/png', bytes: PNG } : null),
    });
    const { serve: honoServe } = await import('@hono/node-server');
    await new Promise<void>((r) => {
      server = honoServe({ fetch: app.fetch, port: 0, hostname: '127.0.0.1' }, (info) => {
        origin = `http://127.0.0.1:${info.port}`;
        r();
      }) as unknown as http.Server;
    });
  });
  afterAll(() => server?.close());

  it('serves a known icon with safe headers, 404 otherwise', async () => {
    const ok = await fetch(`${origin}/api/services/0/icon?v=abc`);
    expect(ok.status).toBe(200);
    expect(ok.headers.get('content-type')).toBe('image/png');
    expect(ok.headers.get('x-content-type-options')).toBe('nosniff');
    expect(Buffer.from(await ok.arrayBuffer()).equals(PNG)).toBe(true);
    for (const p of ['/api/services/1/icon', '/api/services/-1/icon', '/api/services/x/icon']) {
      expect((await fetch(origin + p)).status, p).toBe(404);
    }
  });
});
