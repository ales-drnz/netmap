import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { createState } from '../src/history/state.js';
import { HistoryStore } from '../src/history/store.js';
import { mergeServices, probeTarget, readServicesFile, ServiceMonitor, tcpProbe } from '../src/services.js';

describe('services: configuration', () => {
  it('the file wins over QUICK_LINKS with the same name, in the same position', () => {
    const merged = mergeServices(
      [
        { name: 'A', url: 'http://a' },
        { name: 'B', url: 'http://b' },
      ],
      [
        { name: 'B', url: 'http://b2', app: 'X' },
        { name: 'C', url: 'http://c' },
      ],
    );
    expect(merged).toEqual([
      { name: 'A', url: 'http://a' },
      { name: 'B', url: 'http://b2', app: 'X' },
      { name: 'C', url: 'http://c' },
    ]);
  });

  it('missing file: silent; broken JSON or wrong shape: one message and no services', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'netmap-svc-'));
    const logs: unknown[] = [];
    const log = (...a: unknown[]) => logs.push(a);
    expect(readServicesFile(path.join(dir, 'nope.json'), log)).toEqual([]);
    expect(logs).toHaveLength(0);
    fs.writeFileSync(path.join(dir, 'bad.json'), '[{');
    expect(readServicesFile(path.join(dir, 'bad.json'), log)).toEqual([]);
    fs.writeFileSync(path.join(dir, 'shape.json'), '[{"name": 3}]');
    expect(readServicesFile(path.join(dir, 'shape.json'), log)).toEqual([]);
    expect(logs).toHaveLength(2);
    fs.writeFileSync(path.join(dir, 'ok.json'), '[{"name":"J","url":"http://x:1","color":"#fff"}]');
    expect(readServicesFile(path.join(dir, 'ok.json'), log)).toEqual([{ name: 'J', url: 'http://x:1', color: '#fff' }]);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('probeTarget: default port per scheme, no odd schemes', () => {
    expect(probeTarget('http://10.0.0.1/x')).toEqual({ host: '10.0.0.1', port: 80 });
    expect(probeTarget('https://h.local')).toEqual({ host: 'h.local', port: 443 });
    expect(probeTarget('http://[fd00::1]:8096')).toEqual({ host: 'fd00::1', port: 8096 });
    expect(probeTarget('ftp://x')).toBeNull();
    expect(probeTarget('not a url')).toBeNull();
  });
});

describe('services: checks', () => {
  it('tcpProbe: time if it answers, null if refused', async () => {
    const srv = net.createServer((s) => s.end());
    await new Promise<void>((r) => srv.listen(0, '127.0.0.1', () => r()));
    const port = (srv.address() as net.AddressInfo).port;
    expect(await tcpProbe('127.0.0.1', port)).toEqual(expect.any(Number));
    await new Promise((r) => srv.close(r));
    expect(await tcpProbe('127.0.0.1', port)).toBeNull();
  });

  it('downSince = first failure of the ongoing outage; hourly buckets; persistence', async () => {
    const state = createState();
    let up = false;
    const probed: string[] = [];
    const mon = new ServiceMonitor(
      [
        { name: 'J', url: 'http://10.0.0.9:8096' },
        { name: 'K', url: 'mailto:x' },
      ],
      state,
      async (h, p) => {
        probed.push(`${h}:${p}`);
        return up ? 7 : null;
      },
    );
    const t0 = Date.UTC(2026, 0, 1, 10, 5);
    expect(mon.links(t0)[0]).toMatchObject({ up: null, ms: null, downSince: null, description: null });
    await mon.probeAll(t0);
    await mon.probeAll(t0 + 60e3);
    expect(probed).toEqual(['10.0.0.9:8096', '10.0.0.9:8096']); // only the configured URL
    expect(mon.links(t0 + 60e3)[0]).toMatchObject({ up: false, ms: null, downSince: t0 });
    up = true;
    await mon.probeAll(t0 + 3600e3);
    const l = mon.links(t0 + 3600e3)[0];
    expect(l).toMatchObject({ up: true, ms: 7, downSince: null });
    expect(l?.hours).toHaveLength(24);
    expect(l?.hours?.slice(-2)).toEqual([0, 1]);
    expect(mon.links(t0)[1]?.up).toBeNull(); // mailto: is not checked

    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'netmap-svc-'));
    const file = path.join(dir, 'h.json');
    const store = new HistoryStore(file, state, { log: () => {}, error: () => {} });
    store.load(t0);
    store.save();
    const again = createState();
    new HistoryStore(file, again, { log: () => {}, error: () => {} }).load(t0 + 3600e3);
    expect(again.services.get('J')?.beats).toHaveLength(2);
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
