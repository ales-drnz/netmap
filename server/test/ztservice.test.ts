// Why the local ZeroTier service is unavailable, end to end through the
// snapshot: the page needs the cause, not just "no data".

import http from 'node:http';
import type { AddressInfo } from 'node:net';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createFakeNetwork } from '../../mock/fake-services.js';
import { loadConfig } from '../src/config.js';
import { createState } from '../src/history/state.js';
import { ServiceMonitor } from '../src/services.js';
import { SnapshotService } from '../src/snapshot.js';
import { MetricsSource } from '../src/sources/metrics.js';
import { classifyZtError, HttpStatusError, ZtService } from '../src/sources/ztservice.js';

const servers: http.Server[] = [];
function serve(handler: http.RequestListener): Promise<string> {
  const s = http.createServer(handler);
  servers.push(s);
  return new Promise((r) => s.listen(0, '127.0.0.1', () => r(`http://127.0.0.1:${(s.address() as AddressInfo).port}`)));
}
afterAll(() => {
  for (const s of servers) {
    s.closeAllConnections();
    s.close();
  }
});

const quiet = { log: () => {}, error: () => {} };
const opts = (ztServiceUrl: string, ztToken = 'tok') => ({ ztServiceUrl, ztToken, networkId: 'abcdef1234567890' });

describe('classifyZtError', () => {
  it.each([
    [new HttpStatusError(401), 'unauthorized'],
    [new HttpStatusError(403), 'unauthorized'],
    [new HttpStatusError(500), 'error'],
    [new DOMException('timed out', 'TimeoutError'), 'timeout'],
    [new DOMException('aborted', 'AbortError'), 'timeout'],
    [Object.assign(new TypeError('fetch failed'), { cause: { code: 'ECONNREFUSED' } }), 'refused'],
    [Object.assign(new TypeError('fetch failed'), { cause: { code: 'UND_ERR_CONNECT_TIMEOUT' } }), 'timeout'],
    [new Error('x'), 'error'],
    [null, 'error'],
  ])('%s → %s', (err, reason) => {
    expect(classifyZtError(err)).toBe(reason);
  });
});

describe('ZtService.reason', () => {
  let ok: string;
  let denied: string;
  let closed: string;
  beforeAll(async () => {
    ok = await serve(createFakeNetwork().ztHandler);
    denied = await serve((_req, res) => res.writeHead(401).end());
    // a port that was just free: nothing listens there any more
    const s = http.createServer();
    await new Promise<void>((r) => s.listen(0, '127.0.0.1', () => r()));
    closed = `http://127.0.0.1:${(s.address() as AddressInfo).port}`;
    await new Promise((r) => s.close(r));
  });

  it('no token: the config error, without asking anything', async () => {
    const zt = new ZtService({ ...opts('http://127.0.0.1:1', ''), ztTokenError: 'token-unreadable', ...quiet });
    expect(zt.reason).toBe('token-unreadable');
    await zt.refreshStatus();
    expect(zt.reason).toBe('token-unreadable');
    expect(new ZtService({ ...opts('', ''), ...quiet }).reason).toBe('token-missing');
  });

  it('ok, unauthorized, refused', async () => {
    const a = new ZtService({ ...opts(ok), ...quiet });
    expect(a.reason).toBeNull();
    await a.refreshStatus();
    expect(a.reason).toBe('ok');
    const b = new ZtService({ ...opts(denied), ...quiet });
    await b.refreshStatus();
    expect(b.reason).toBe('unauthorized');
    const c = new ZtService({ ...opts(closed), ...quiet });
    await c.refreshStatus();
    expect(c.reason).toBe('refused');
  });

  it('logs when the reason changes, not on every poll', async () => {
    let up = false;
    const flappy = await serve((req, res) => {
      if (up) createFakeNetwork().ztHandler(req, res);
      else res.writeHead(403).end();
    });
    const lines: string[] = [];
    const push = (...a: unknown[]) => lines.push(a.join(' '));
    const zt = new ZtService({ ...opts(flappy), log: push, error: push });
    for (let i = 0; i < 3; i++) await zt.refreshStatus();
    expect(lines).toHaveLength(1);
    expect(lines[0]).toMatch(/rejected/);
    up = true;
    for (let i = 0; i < 3; i++) await zt.refreshStatus();
    expect(lines).toHaveLength(2);
    expect(lines[1]).toMatch(/answering again/);
  });
});

describe('snapshot: health.localReason', () => {
  async function snapshotWith(env: NodeJS.ProcessEnv, readAuthtoken?: (f: string) => string) {
    const fake = createFakeNetwork();
    const ztnet = await serve(fake.ztnetHandler);
    const ztsvc = await serve(fake.ztHandler);
    const config = loadConfig(
      {
        ZTNET_URL: ztnet,
        ZTNET_API_TOKEN: 'test-token',
        ZTNET_NETWORK_ID: 'abcdef1234567890',
        ZT_SERVICE_URL: ztsvc,
        HUB_NODE_NAME: 'nas',
        ...env,
      },
      { readAuthtoken, log: () => {} },
    );
    const state = createState();
    const snapshots = new SnapshotService({
      config,
      state,
      zt: new ZtService({ ...config, ...quiet }),
      metrics: new MetricsSource({ ...config, ...quiet }, state),
      services: new ServiceMonitor([], state),
      error: () => {},
    });
    await snapshots.refresh();
    return snapshots.snapshot;
  }

  it('token unreadable: the reason reaches the page, and relay/link are unknown, not guessed', async () => {
    const snap = await snapshotWith({}, () => {
      throw Object.assign(new Error('EACCES'), { code: 'EACCES' });
    });
    expect(snap.error).toBeNull();
    expect(snap.health?.localReason).toBe('token-unreadable');
    expect(snap.health?.zt).toBeNull();
    // the REST member list has no conStatus: without the service nobody knows
    const phone = snap.nodes.find((n) => n.name === 'alice-phone');
    expect(phone).toMatchObject({ online: true, relayed: false, link: null, latencyMs: null });
  });

  it('token present: ok, and relay comes from the service', async () => {
    const snap = await snapshotWith({ ZT_AUTHTOKEN: 'mock-zt-token' });
    expect(snap.health?.localReason).toBe('ok');
    expect(snap.nodes.find((n) => n.name === 'alice-phone')).toMatchObject({ relayed: true, link: 'relay' });
    expect(snap.nodes.find((n) => n.name === 'alice-pc')?.link).toMatch(/^(lan|wan)$/);
  });
});
