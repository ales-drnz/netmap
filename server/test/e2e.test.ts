// End-to-end: the real server (server/src) in front of the fake ZTNET and the
// fake ZeroTier service from mock/, checked through its public HTTP API.
//
// Determinism: the fakes' clock is not the real one, it advances one step per
// request to the same endpoint, so the second poll always sees the same data.
// From the third poll ZTNET answers 500: the snapshot stays frozen at the
// second poll (plus `error`), whatever the machine's speed.

import { type ChildProcess, spawn } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import type { AddressInfo } from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createFakeNetwork } from '../../mock/fake-services.js';
import type { NetNode, Snapshot } from '../../shared/api.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
// tsx compiles on the fly and CI machines can be slow: generous timeouts
const STARTUP_MS = 240_000;
const STEP_MS = 160_000; // enough for home-tv to go offline on the second poll
const BASE = Date.now() - 1_000_000; // in the past, so the ages the server computes stay positive

interface Fake {
  env: Record<string, string>;
  close: () => void;
}

/** fake services whose clock advances one step per request to the same endpoint */
async function startSteppedFake(): Promise<Fake> {
  let current = BASE;
  const fake = createFakeNetwork({ clock: () => current });
  const counters = new Map<string, number>();
  const step = (key: string) => {
    const n = counters.get(key) ?? 0;
    counters.set(key, n + 1);
    current = BASE + n * STEP_MS;
    return n;
  };
  const zt = http.createServer((req, res) => {
    step(`zt ${req.url}`);
    fake.ztHandler(req, res);
  });
  const ztnet = http.createServer((req, res) => {
    const n = step(`ztnet ${req.url}`);
    if (n >= 2) {
      res.writeHead(500);
      res.end('{}');
      return;
    }
    fake.ztnetHandler(req, res);
  });
  const listen = (s: http.Server) =>
    new Promise<number>((r) => s.listen(0, '127.0.0.1', () => r((s.address() as AddressInfo).port)));
  const [ztPort, ztnetPort] = [await listen(zt), await listen(ztnet)];
  return {
    env: {
      ZTNET_URL: `http://127.0.0.1:${ztnetPort}`,
      ZTNET_API_TOKEN: 'test-token',
      ZTNET_NETWORK_ID: 'abcdef1234567890',
      ZT_SERVICE_URL: `http://127.0.0.1:${ztPort}`,
      ZT_AUTHTOKEN: 'mock-zt-token',
    },
    close: () => {
      zt.closeAllConnections();
      ztnet.closeAllConnections();
      zt.close();
      ztnet.close();
    },
  };
}

const freePort = () =>
  new Promise<number>((r) => {
    const s = http.createServer();
    s.listen(0, '127.0.0.1', () => {
      const p = (s.address() as AddressInfo).port;
      s.close(() => r(p));
    });
  });

/** kill the server and all its children, and close the pipes to the test */
function stop(proc: ChildProcess): void {
  try {
    if (proc.pid) process.kill(-proc.pid, 'SIGKILL');
  } catch {
    proc.kill('SIGKILL');
  }
  proc.stdout?.destroy();
  proc.stderr?.destroy();
}

describe('end-to-end: server against the mock network', () => {
  let tmp: string;
  let fake: Fake;
  let proc: ChildProcess;
  let base: string;
  const log: string[] = [];
  let snap: Snapshot;
  let snapText: string;
  let nodesHeaders: Headers;

  beforeAll(async () => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'netmap-e2e-'));
    const web = path.join(tmp, 'web');
    fs.mkdirSync(web);
    fs.writeFileSync(path.join(web, 'index.html'), 'SPA');
    fake = await startSteppedFake();
    const port = await freePort();
    base = `http://127.0.0.1:${port}`;
    const env = {
      ...process.env,
      ...fake.env,
      PORT: String(port),
      BIND_HOST: '127.0.0.1',
      POLL_SECONDS: '5',
      HUB_NODE_NAME: 'nas',
      // local addresses only: a test must never probe real machines
      QUICK_LINKS: 'Jellyfin=http://127.0.0.1:9,Nextcloud=http://127.0.0.1:9/cloud/',
      WHOAMI_TEST_IP: '10.147.17.4',
      HISTORY_FILE: path.join(tmp, 'history.json'),
      SERVICES_FILE: path.join(tmp, 'no-such-file.json'),
      WEB_DIR: web,
    };
    // own process group: tsx starts an esbuild child that must die with it
    proc = spawn(process.execPath, ['--import', 'tsx', 'server/src/index.ts'], {
      cwd: ROOT,
      env,
      stdio: ['ignore', 'pipe', 'pipe'],
      detached: true,
    });
    proc.stdout?.on('data', (d) => log.push(String(d)));
    proc.stderr?.on('data', (d) => log.push(String(d)));

    const until = Date.now() + STARTUP_MS;
    for (;;) {
      if (Date.now() > until) throw new Error(`timeout; log:\n${log.join('')}`);
      try {
        const res = await fetch(`${base}/api/nodes`);
        const text = await res.text();
        const s = JSON.parse(text) as Snapshot;
        if (s.error != null && s.nodes.length > 0) {
          snap = s;
          snapText = text;
          nodesHeaders = res.headers;
          break;
        }
      } catch {
        // not listening yet
      }
      await new Promise((r) => setTimeout(r, 250));
    }
  }, STARTUP_MS + 30_000);

  afterAll(() => {
    if (proc) stop(proc);
    fake?.close();
    if (tmp) fs.rmSync(tmp, { recursive: true, force: true });
  });

  const node = (name: string) => snap.nodes.find((n) => n.name === name) as NetNode;

  it('/api/nodes: JSON, never cached', () => {
    expect(nodesHeaders.get('content-type')).toBe('application/json; charset=utf-8');
    expect(nodesHeaders.get('cache-control')).toBe('no-store');
    expect(snap.networkName).toBe('home-net');
  });

  it('devices: hub, direct, relay and offline as the mock describes them', () => {
    expect(node('nas').hub).toBe(true);
    expect(node('nas').online).toBe(true);
    expect(node('alice-pc')).toMatchObject({ online: true, relayed: false });
    expect(node('alice-pc').latencyMs).toEqual(expect.any(Number));
    expect(node('alice-phone')).toMatchObject({ online: true, relayed: true, latencyMs: null });
    expect(node('alice-laptop').online).toBe(false);
    // deleted in ZTNET: gone, not a ghost on the map
    expect(snap.nodes.some((n) => n.name === 'removed-node')).toBe(false);
  });

  it('the second poll produced events and traffic', () => {
    expect(snap.events.some((e) => e.kind === 'offline')).toBe(true);
    expect(snap.nodes.some((n) => (n.traffic?.packets ?? 0) > 0)).toBe(true);
  });

  it('access requests are listed apart, revoked ones flagged', () => {
    const p = snap.pending ?? [];
    expect(p.map((x) => x.name).sort()).toEqual(['guest-laptop', 'old-laptop']);
    expect(p.find((x) => x.name === 'old-laptop')?.deauthorized).toBe(true);
    expect(snap.nodes.some((n) => n.name === 'guest-laptop')).toBe(false);
  });

  it('privacy: no public addresses, no surfaceAddresses, no tokens', () => {
    expect(snapText).not.toMatch(/93\.45\./);
    expect(snapText).not.toMatch(/surfaceAddresses/);
    expect(snapText).not.toMatch(/test-token|mock-zt-token/);
  });

  it('services from QUICK_LINKS are probed', () => {
    expect(snap.links.map((l) => l.name)).toEqual(['Jellyfin', 'Nextcloud']);
    for (const l of snap.links) expect(l.up).toBe(false);
  });

  it('/api/whoami recognises the visitor by its ZeroTier address', async () => {
    const r = await fetch(`${base}/api/whoami`);
    expect(await r.json()).toEqual({ ip: '10.147.17.4', name: 'alice-phone', id: node('alice-phone').id });
  });

  it('serves the web UI with SPA fallback, and 404 for unknown APIs', async () => {
    for (const p of ['/', '/devices', '/map?d=x']) expect(await (await fetch(base + p)).text()).toBe('SPA');
    expect((await fetch(`${base}/api/nope`)).status).toBe(404);
  });
});
