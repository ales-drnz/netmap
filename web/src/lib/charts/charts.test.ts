import { describe, expect, it } from 'vitest';
import type { NetEvent, NetNode } from '$shared/api';
import { countBy, eventKey, groupByDay, netdropNames, stillOffline } from './activity';
import {
  availabilityRows,
  byteDays,
  commonVersion,
  type DevLike,
  latencyStrip,
  onlineCount,
  outages24h,
  relaySince,
  topUsers,
  typicalVsLastWeek,
  versionCounts,
  worseThanLastWeek,
} from './perf';
import {
  byteUnit,
  clampTip,
  gapPath,
  hourTicks,
  linear,
  log,
  niceStep,
  niceTicks,
  nightBands,
  stepArea,
} from './scale';

const NOW = new Date(2026, 9, 19, 12, 0, 0).getTime();
const H = 3600e3;

let seq = 0;
const node = (o: Partial<NetNode> = {}): NetNode => ({
  id: `n${seq++}`,
  name: 'alice-pc',
  ips: ['10.0.0.1'],
  online: true,
  relayed: false,
  latencyMs: 10,
  link: 'wan',
  version: '1.14.2',
  idleSec: 1,
  halfOpen: false,
  family: 4,
  paths: 1,
  pathsDead: 0,
  note: null,
  labels: [],
  since: null,
  lastSeen: NOW,
  hub: false,
  spark: [10, 10, 10],
  uptime: 1,
  beats: [],
  traffic: null,
  latency30: null,
  ...o,
});
const dev = (o: Partial<NetNode> = {}, owner = 'alice'): DevLike => {
  const n = node(o);
  return { id: n.id, name: n.name, owner, node: n };
};
const no = () => false;

describe('scale', () => {
  it('linear and log map domains to ranges', () => {
    const l = linear([0, 10], [0, 100]);
    expect(l(5)).toBe(50);
    const g = log([1, 100], [0, 200]);
    expect(g(10)).toBeCloseTo(100);
    expect(g(0)).toBe(0); // clamped
    expect(g(1e6)).toBe(200);
  });
  it('nice steps are 1/2/5 × 10ⁿ', () => {
    expect(niceStep(7.3, 4)).toBe(2);
    expect(niceStep(42, 4)).toBe(20);
    expect(niceStep(0.03, 3)).toBe(0.01);
    expect(niceTicks(7.3, 4)).toEqual([0, 2, 4, 6, 8]);
    expect(niceTicks(0)).toEqual([0, 1]);
  });
  it('byte unit is decimal', () => {
    expect(byteUnit(5.2e9)).toEqual({ div: 1e9, unit: 'GB' });
    expect(byteUnit(800)).toEqual({ div: 1, unit: 'B' });
  });
  it('gapPath breaks on null and keeps isolated points as dots', () => {
    const p = gapPath(
      [1, 2, null, 4, null, 5, 6],
      (i) => i,
      (v) => v,
    );
    expect(p.d).toBe('M0 1L1 2M3 4M5 5L6 6'); // a lone M draws nothing: the dot does
    expect(p.dots).toEqual([[3, 4]]);
  });
  it('stepArea leaves gaps for nulls', () => {
    const d = stepArea(
      [1, null, 2],
      (i) => i * 10,
      (v) => v,
      0,
    );
    expect(d).toBe('M0 0V1H10V0H0ZM20 0V2H30V0H20Z');
  });
  it('hour ticks and night bands are local and inside the window', () => {
    const start = NOW - 24 * H; // 12:00 yesterday
    const ticks = hourTicks(start, NOW, [0, 6, 12, 18]);
    expect(ticks.map((x) => new Date(x.t).getHours())).toEqual([12, 18, 0, 6]);
    const bands = nightBands(start, NOW, 22, 7);
    expect(bands).toHaveLength(1);
    const [a, b] = bands[0] ?? [0, 0];
    expect(a).toBeCloseTo(10 / 24);
    expect(b).toBeCloseTo(19 / 24);
  });
  it('clampTip keeps the tooltip inside', () => {
    expect(clampTip(5, 100, 400)).toBe(0);
    expect(clampTip(395, 100, 400)).toBe(300);
    expect(clampTip(200, 100, 400)).toBe(150);
  });
});

describe('performance', () => {
  it('outages count netdrops and disconnections of active devices in 24 h only', () => {
    const a = node({ id: 'a', online: false, lastSeen: NOW - 2 * H });
    const old = node({ id: 'old', online: false, lastSeen: NOW - 30 * 24 * H });
    const ev: NetEvent[] = [
      { t: NOW - H, id: 'a', name: 'a', kind: 'offline' },
      { t: NOW - 3 * H, id: null, name: null, kind: 'netdrop', count: 3 },
      { t: NOW - 2 * H, id: 'old', name: 'old', kind: 'offline' },
      { t: NOW - 30 * H, id: 'a', name: 'a', kind: 'offline' },
      { t: NOW - H, id: 'a', name: 'a', kind: 'spike' },
    ];
    expect(outages24h(ev, [a, old], NOW)).toEqual({ count: 2, last: NOW - H });
  });

  it('week comparison needs most devices to have a previous week', () => {
    const lt = (m: number, p: number | null) => ({
      median: m,
      p95: m,
      prevMedian: p,
      trend: p ? m / p : null,
      samples: 100,
    });
    const some = [node({ latency30: lt(20, 10) }), node({ latency30: lt(20, null) })];
    expect(typicalVsLastWeek(some)).toBeNull();
    const most = [node({ latency30: lt(20, 10) }), node({ latency30: lt(30, 20) }), node({ latency30: lt(20, null) })];
    const w = typicalVsLastWeek(most);
    expect(w?.n).toBe(2);
    expect(w?.ratio).toBeGreaterThan(1);
  });

  it('latency strip: online direct only, sorted by median, with p10/p90', () => {
    const rows = latencyStrip(
      [
        dev({ name: 'slow', spark: [50, 60, 70, null] }),
        dev({ name: 'fast', spark: [1, 2, 3], link: 'lan' }),
        dev({ name: 'relay', relayed: true }),
        dev({ name: 'off', online: false }),
        dev({ name: 'empty', spark: [null, null] }),
      ],
      no,
    );
    expect(rows.map((r) => r.name)).toEqual(['fast', 'slow']);
    expect(rows[0]?.lan).toBe(true);
    expect(rows[1]).toMatchObject({ median: 60, p10: 50, p90: 70, samples: 3 });
  });

  it('worse than last week: enough samples, ≥ 10 % slower, mine pinned', () => {
    const lt = (m: number, p: number | null, samples = 100) => ({
      median: m,
      p95: m,
      prevMedian: p,
      trend: p ? m / p : null,
      samples,
    });
    const devs = [
      dev({ name: 'a', latency30: lt(30, 10) }),
      dev({ name: 'b', latency30: lt(12, 10) }),
      dev({ name: 'same', latency30: lt(10, 10) }),
      dev({ name: 'few', latency30: lt(90, 10, 5) }),
      dev({ name: 'new', latency30: lt(90, null) }),
    ];
    const r = worseThanLastWeek(devs, (d) => d.name === 'b');
    expect(r.candidates).toBe(3);
    expect(r.rows.map((x) => x.name)).toEqual(['b', 'a']);
    expect(worseThanLastWeek([dev({ latency30: lt(5, null) })], no).candidates).toBe(0);
  });

  it('availability rows: worst first, all-day-offline collapsed, inactive skipped', () => {
    const { rows, allDayOff } = availabilityRows(
      [
        dev({ name: 'good', uptime: 1, beats: [1, 1] }),
        dev({ name: 'bad', uptime: 0.5, beats: [0, 1] }),
        dev({ name: 'dark', online: false, uptime: 0, beats: [0, 0], lastSeen: NOW - 2 * 24 * H }),
        dev({ name: 'gone', online: false, uptime: null, beats: [null, null], lastSeen: NOW - 9 * 24 * H }),
        dev({ name: 'hub', hub: true }),
      ],
      NOW,
      no,
    );
    expect(rows.map((r) => r.name)).toEqual(['bad', 'good']);
    expect(allDayOff.map((r) => r.name)).toEqual([]);
    // 'dark' was seen 2 days ago and has no online bucket → not active in 24 h at all
    const r2 = availabilityRows(
      [dev({ name: 'dark', online: false, uptime: 0, beats: [0, 0], lastSeen: NOW - 3 * H })],
      NOW,
      no,
    );
    expect(r2.allDayOff.map((r) => r.name)).toEqual(['dark']);
  });

  it('online count sums fractions, null where nobody has data', () => {
    expect(onlineCount([{ beats: [1, null, 0.5] }, { beats: [1, null, 1] }], 3)).toEqual([2, null, 1.5]);
    expect(onlineCount([{ beats: [1] }], 3)).toEqual([null, null, 1]);
  });

  it('relay since = latest relay event of the device', () => {
    const m = relaySince([
      { t: 5, id: 'a', name: 'a', kind: 'relay' },
      { t: 9, id: 'a', name: 'a', kind: 'relay' },
      { t: 7, id: 'b', name: 'b', kind: 'direct' },
    ]);
    expect(m.get('a')).toBe(9);
    expect(m.has('b')).toBe(false);
  });

  it('versions: most common, newest first with numeric compare', () => {
    const ns = [
      node({ version: '1.9.0' }),
      node({ version: '1.10.0' }),
      node({ version: '1.10.0' }),
      node({ version: null }),
    ];
    expect(commonVersion(ns)).toBe('1.10.0');
    expect(versionCounts(ns).map((v) => v.v)).toEqual(['1.10.0', '1.9.0']);
  });

  it('top users group by person, share sums to 1, others row past the limit', () => {
    const tr = (p: number) => ({ packets: p, days: [p / 2, p / 2], errors: 0 });
    const devs = [
      dev({ traffic: tr(60) }, 'alice'),
      dev({ traffic: tr(20) }, 'alice'),
      dev({ traffic: tr(10) }, 'bob'),
      dev({ traffic: tr(6) }, 'carol'),
      dev({ traffic: tr(4) }, 'dave'),
      dev({ traffic: null }, 'erin'),
    ];
    const byP = topUsers(devs, 'person', 2);
    expect(byP.map((r) => r.key)).toEqual(['alice', 'bob', '__others']);
    expect(byP[0]?.packets).toBe(80);
    expect(byP[0]?.days[29]).toBe(40);
    expect(byP[0]?.days[0]).toBeNull();
    expect(byP.reduce((s, r) => s + r.share, 0)).toBeCloseTo(1);
    expect(byP[2]?.devices).toBe(2);
    expect(topUsers(devs, 'device', 8)).toHaveLength(5);
  });

  it('byte days: leading zeros are missing, today partial, later zeros are real', () => {
    const d = byteDays(
      [
        { udp: 0, tcp: 0 },
        { udp: 100, tcp: 0 },
        { udp: 0, tcp: 0 },
        { udp: 90, tcp: 10 },
      ],
      NOW,
    );
    expect(d.map((x) => x.missing)).toEqual([true, false, false, false]);
    expect(d.map((x) => x.partial)).toEqual([false, false, false, true]);
    expect(d[3]?.tcpShare).toBeCloseTo(0.1);
    expect(d[2]?.tcpShare).toBeNull();
    expect(new Date(d[3]?.t ?? 0).getDate()).toBe(19);
  });
});

describe('activity', () => {
  const ev: NetEvent[] = [
    { t: NOW - 25 * H, id: 'a', name: 'a', kind: 'offline' },
    { t: NOW - H, id: 'a', name: 'a', kind: 'online' },
    { t: NOW - 2 * H, id: 'b', name: 'b', kind: 'offline' },
    { t: NOW - 3 * H, id: 'b', name: 'b', kind: 'spike' },
    { t: NOW - 4 * H, id: null, name: null, kind: 'netdrop', count: 9, detail: 'x, y, z, a, b, c…' },
  ];
  it('groups by local day, newest first', () => {
    const g = groupByDay(ev);
    expect(g).toHaveLength(2);
    expect(g[0]?.events[0]?.kind).toBe('online');
    expect(g[1]?.events).toHaveLength(1);
  });
  it('still offline only for the latest event of a device that is offline now', () => {
    const nodes = [node({ id: 'a', online: false }), node({ id: 'b', online: false })];
    const s = stillOffline(ev, nodes);
    expect(s.has(eventKey(ev[2] as NetEvent))).toBe(true);
    expect(s.has(eventKey(ev[0] as NetEvent))).toBe(false);
  });
  it('parses netdrop names', () => {
    expect(netdropNames(ev[4] as NetEvent)).toEqual({ names: ['x', 'y', 'z', 'a', 'b', 'c'], more: true });
  });
  it('counts by filter', () => {
    expect(countBy(ev, (e) => e.kind).get('offline')).toBe(2);
  });
});
