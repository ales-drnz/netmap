import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { detectEvents, detectPending } from '../src/history/events.js';
import { LAT_EDGES, latBucket, latencyTrend, latQuantile } from '../src/history/latency.js';
import { recordSample, type SampleNode } from '../src/history/samples.js';
import { createState, dayKey } from '../src/history/state.js';
import { HistoryStore, SCHEMA_VERSION } from '../src/history/store.js';
import { beatsOf, uptimeOf } from '../src/history/uptime.js';

const quiet = { log: () => {}, error: () => {} };

describe('latBucket / latQuantile', () => {
  it('assigns buckets with inclusive edges', () => {
    expect(latBucket(0)).toBe(0);
    expect(latBucket(5)).toBe(0);
    expect(latBucket(5.1)).toBe(1);
    expect(latBucket(150)).toBe(7);
    expect(latBucket(701)).toBe(LAT_EDGES.length - 1);
    expect(latBucket(1e9)).toBe(LAT_EDGES.length - 1);
  });

  it('interpolates within the bucket', () => {
    const c = new Array(LAT_EDGES.length).fill(0);
    expect(latQuantile(c, 0.5)).toBeNull();
    c[2] = 10; // all between 10 and 20 ms
    expect(latQuantile(c, 0.5)).toBe(15);
    expect(latQuantile(c, 1)).toBe(20);
    expect(latQuantile(c, 0)).toBe(10);
  });

  it('the last (infinite) bucket uses 1.5× the lower edge', () => {
    const c = new Array(LAT_EDGES.length).fill(0);
    c[LAT_EDGES.length - 1] = 4;
    expect(latQuantile(c, 1)).toBe(1050);
  });
});

describe('latencyTrend', () => {
  const now = Date.UTC(2026, 5, 15, 12);
  it('null below 20 recent samples', () => {
    const s = createState();
    s.history.set('a', {
      name: 'a',
      lat: [],
      beats: [],
      traf: { lastRx: null, lastTx: null, lastErr: null, days: {} },
      latDays: {},
    });
    expect(latencyTrend(s, 'a', now)).toBeNull();
    expect(latencyTrend(s, 'missing', now)).toBeNull();
  });

  it('compares the recent median with the week before', () => {
    const s = createState();
    const today = new Array(LAT_EDGES.length).fill(0);
    today[3] = 30; // 20–35 ms
    const lastWeek = new Array(LAT_EDGES.length).fill(0);
    lastWeek[1] = 30; // 5–10 ms
    s.history.set('a', {
      name: 'a',
      lat: [],
      beats: [],
      traf: { lastRx: null, lastTx: null, lastErr: null, days: {} },
      latDays: { [dayKey(now)]: today, [dayKey(now - 4 * 864e5)]: lastWeek },
    });
    const t = latencyTrend(s, 'a', now);
    expect(t).toEqual({ median: 28, p95: 34, prevMedian: 8, trend: 3.5, samples: 30 });
  });
});

const node = (id: string, online = true, latencyMs: number | null = 20, relayed = false): SampleNode => ({
  id,
  name: id,
  online,
  relayed,
  latencyMs,
});

describe('detectEvents', () => {
  it('records nothing on the first poll', () => {
    const s = createState();
    detectEvents(s, [node('a', false), node('b')], 1, 150);
    expect(s.events).toEqual([]);
  });

  it('one or two drops: one event per node', () => {
    const s = createState();
    detectEvents(s, [node('a'), node('b'), node('c')], 1, 150);
    detectEvents(s, [node('a', false), node('b', false), node('c')], 2, 150);
    expect(s.events.map((e) => [e.kind, e.id])).toEqual([
      ['offline', 'b'],
      ['offline', 'a'],
    ]);
  });

  it('three or more drops in the same poll: a single netdrop event', () => {
    const s = createState();
    const ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    detectEvents(s, [...ids.map((i) => node(i)), node('x', true, 20, true)], 1, 150);
    // all down, and meanwhile x goes from relay to direct: that stays a separate event
    detectEvents(s, [...ids.map((i) => node(i, false)), node('x')], 2, 150);
    expect(s.events).toHaveLength(2);
    const drop = s.events.find((e) => e.kind === 'netdrop');
    expect(drop).toEqual({ t: 2, id: null, name: null, kind: 'netdrop', count: 8, detail: 'a, b, c, d, e, f…' });
    expect(s.events.find((e) => e.kind === 'direct')?.id).toBe('x');
  });

  it('spike only on the rising edge', () => {
    const s = createState();
    const feed = (t: number, ms: number) => {
      const n = node('a', true, ms);
      recordSample(s, n, t);
      detectEvents(s, [n], t, 150);
    };
    for (let t = 0; t < 5; t++) feed(t, 20);
    feed(5, 300); // enters spike
    feed(6, 310); // stays in spike: no new event
    feed(7, 20); // leaves
    feed(8, 400); // re-enters: new event
    const spikes = s.events.filter((e) => e.kind === 'spike');
    expect(spikes.map((e) => [e.t, e.detail])).toEqual([
      [8, '400 ms'],
      [5, '300 ms'],
    ]);
  });

  it('a chronically slow node is not a spike', () => {
    const s = createState();
    for (let t = 0; t < 6; t++) {
      const n = node('a', true, 200);
      recordSample(s, n, t);
      detectEvents(s, [n], t, 150);
    }
    expect(s.events).toEqual([]);
  });
});

describe('detectPending', () => {
  it('reports only once and forgets those no longer waiting', () => {
    const s = createState();
    const p = { id: 'p1', name: null, since: null, waitingSec: null, deauthorized: true };
    detectPending(s, [p], 1);
    detectPending(s, [p], 2);
    expect(s.events).toEqual([
      { t: 1, id: 'p1', name: 'p1', kind: 'pending', detail: 'authorization revoked in the past' },
    ]);
    detectPending(s, [], 3);
    expect(s.pendingSeen.size).toBe(0);
  });
});

describe('uptime / beats', () => {
  it('null ticks where there is no data', () => {
    const s = createState();
    const now = Date.UTC(2026, 0, 1, 10);
    recordSample(s, node('a'), now);
    recordSample(s, node('a', false), now + 1000);
    expect(uptimeOf(s, 'a')).toBe(0.5);
    const beats = beatsOf(s, 'a', now + 1000);
    expect(beats).toHaveLength(60);
    expect(beats.at(-1)).toBe(0.5);
    expect(beats.slice(0, -1).every((b) => b === null)).toBe(true);
  });
});

describe('HistoryStore', () => {
  const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'netmap-store-'));

  it('reads a file from the old server.js (no schemaVersion)', () => {
    const dir = tmp();
    const file = path.join(dir, 'history.json');
    const now = Date.now();
    fs.writeFileSync(
      file,
      JSON.stringify({
        savedAt: now,
        history: {
          aaaaaaaaaa: {
            name: 'pc',
            lat: [1, null, 3],
            beats: [
              { t: now - 25 * 3600e3, up: 1, tot: 1 },
              { t: now - 3600e3, up: 2, tot: 3 },
            ],
            traf: { lastRx: 99, lastTx: 99, lastErr: 1, days: { '2026-01-01': { rx: 1, tx: 2 } } },
            // no latDays: an even older version
          },
        },
        events: [{ t: 1, id: 'aaaaaaaaaa', name: 'pc', kind: 'online' }],
        netTraffic: { days: { '2026-01-01': { udpRx: 1, udpTx: 2, tcpRx: 3, tcpTx: 4 } } },
        netErrors: { days: { '2026-01-01': { x: 1 } } },
        pendingSeen: ['bbbbbbbbbb'],
      }),
    );
    const s = createState();
    const store = new HistoryStore(file, s, quiet);
    store.load(now);
    expect(store.canPersist).toBe(true);
    const h = s.history.get('aaaaaaaaaa');
    expect(h?.lat).toEqual([1, null, 3]);
    expect(h?.beats).toHaveLength(1); // the tick from 25 hours ago has expired
    expect(h?.latDays).toEqual({});
    // references to cumulative counters are reset, the days stay
    expect(h?.traf).toEqual({ lastRx: null, lastTx: null, lastErr: null, days: { '2026-01-01': { rx: 1, tx: 2 } } });
    expect(s.events).toHaveLength(1);
    expect([...s.pendingSeen]).toEqual(['bbbbbbbbbb']);
    expect(s.netTraffic.days['2026-01-01']?.tcpTx).toBe(4);
    expect(s.services.size).toBe(0);

    // and saving writes the schema version, atomically
    store.save();
    const saved = JSON.parse(fs.readFileSync(file, 'utf8'));
    expect(saved.schemaVersion).toBe(SCHEMA_VERSION);
    expect(fs.existsSync(`${file}.tmp`)).toBe(false);
    const again = createState();
    new HistoryStore(file, again, quiet).load(now);
    expect(again.history.get('aaaaaaaaaa')?.name).toBe('pc');
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('missing file: no error; non-writable folder: persistence off', () => {
    const dir = tmp();
    const errors: unknown[] = [];
    const store = new HistoryStore(path.join(dir, 'x.json'), createState(), {
      log: () => {},
      error: (...a) => errors.push(a),
    });
    store.load();
    expect(store.canPersist).toBe(true);
    expect(errors).toEqual([]);
    // the "folder" is a file: mkdir fails right away with ENOTDIR. (Not /proc:
    // in Node 22 a recursive mkdirSync in there never returns.)
    const notDir = path.join(dir, 'a-file');
    fs.writeFileSync(notDir, '');
    const ro = new HistoryStore(path.join(notDir, 'history.json'), createState(), quiet);
    ro.load();
    expect(ro.canPersist).toBe(false);
    ro.save(); // does nothing, doesn't throw
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('broken JSON: reports it and starts empty', () => {
    const dir = tmp();
    const file = path.join(dir, 'h.json');
    fs.writeFileSync(file, '{"history": {');
    const errors: unknown[] = [];
    const s = createState();
    new HistoryStore(file, s, { log: () => {}, error: (...a) => errors.push(a) }).load();
    expect(errors).toHaveLength(1);
    expect(s.history.size).toBe(0);
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
