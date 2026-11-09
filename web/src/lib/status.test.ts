import { describe, expect, it } from 'vitest';
import type { NetNode, Snapshot } from '$shared/api';
import { availability, isActive, typicalLatency } from './stats';
import { verdict } from './status';

const NOW = Date.parse('2026-10-19T12:00:00Z');

const node = (o: Partial<NetNode> = {}): NetNode => ({
  id: Math.random().toString(16).slice(2, 12),
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

const snap = (o: Partial<Snapshot> = {}): Snapshot => ({
  updatedAt: new Date(NOW).toISOString(),
  networkId: 'abc',
  networkName: 'home',
  net: null,
  links: [],
  pollSeconds: 20,
  nodes: [node(), node({ link: 'lan' })],
  events: [],
  error: null,
  ...o,
});

const v = (s: Snapshot | null, o: { receivedAt?: number; offline?: boolean } = {}) =>
  verdict({ snap: s, receivedAt: o.receivedAt ?? NOW - 2000, now: NOW, offline: o.offline ?? false });

describe('status verdict', () => {
  it('is loading before the first snapshot', () => {
    expect(v(null, { receivedAt: 0 }).reason.kind).toBe('loading');
  });

  it('is ok when nothing is wrong', () => {
    const r = v(snap());
    expect(r.tone).toBe('ok');
    expect(r.counts).toMatchObject({ online: 2, direct: 2, lan: 1, wan: 1, relay: 0 });
    expect(r.ageSec).toBe(2);
  });

  it('follows the priority order', () => {
    const relay = snap({ nodes: [node({ relayed: true, link: 'relay' })] });
    expect(v(relay).reason).toEqual({ kind: 'relay', count: 1 });

    const fallback = {
      ...relay,
      health: {
        zt: {
          online: true,
          version: null,
          tcpFallback: true,
          forceTcpRelay: false,
          allowTcpFallback: true,
          portMapping: true,
          port: 9993,
        },
        local: null,
        bytes: null,
        errors: null,
      },
    };
    expect(v(fallback).reason.kind).toBe('tcpFallback');

    const dropEvent = { t: NOW - 600e3, id: null, name: null, kind: 'netdrop' as const, count: 3 };
    const drop = { ...fallback, events: [dropEvent] };
    expect(v(drop).reason).toEqual({ kind: 'netdrop', count: 3, t: NOW - 600e3 });
    // an old netdrop doesn't count
    expect(v({ ...drop, events: [{ ...dropEvent, t: NOW - 2 * 3600e3 }] }).reason.kind).toBe('tcpFallback');

    const ztnet = { ...drop, error: 'ECONNREFUSED', updatedAt: new Date(NOW - 180e3).toISOString() };
    expect(v(ztnet).reason).toEqual({ kind: 'stale', source: 'ztnet', ageSec: 180, error: 'ECONNREFUSED' });
    expect(v(ztnet).tone).toBe('danger');

    expect(v(snap(), { offline: true }).reason.kind).toBe('stale');
    expect(v(snap(), { receivedAt: NOW - 120e3 }).reason).toMatchObject({
      kind: 'stale',
      source: 'server',
      ageSec: 120,
    });
  });

  it('keeps inactive devices out of the counts', () => {
    const r = v(
      snap({
        nodes: [
          node(),
          node({ online: false, lastSeen: NOW - 3 * 864e5 }),
          node({ online: false, lastSeen: NOW - 30 * 864e5 }),
          node({ online: false, lastSeen: null }),
        ],
      }),
    );
    expect(r.counts).toMatchObject({ active: 2, online: 1, offline: 1, inactive: 2 });
  });
});

describe('stats', () => {
  it('typical latency is the median of per-device medians', () => {
    const nodes = [
      node({ spark: [1, 1, 100] }), // median 1
      node({ spark: [null, 20, 20] }), // median 20
      node({ spark: [50, 50, 50] }), // median 50
      node({ spark: [500], relayed: true }), // relayed: excluded
      node({ spark: [500], hub: true }), // hub: excluded
    ];
    expect(typicalLatency(nodes)).toBe(20);
    expect(typicalLatency([])).toBeNull();
  });

  it('availability averages the devices active in the window, not only the online ones', () => {
    const nodes = [
      node({ uptime: 1 }),
      node({ online: false, uptime: 0.5, lastSeen: NOW - 3600e3 }),
      node({ online: false, uptime: 0, lastSeen: NOW - 5 * 864e5 }),
    ];
    expect(availability(nodes, NOW)).toBe(0.75);
    expect(availability([node({ uptime: null })], NOW)).toBeNull();
  });

  it('active = online or seen within 7 days', () => {
    expect(isActive(node({ online: false, lastSeen: NOW - 6 * 864e5 }), NOW)).toBe(true);
    expect(isActive(node({ online: false, lastSeen: new Date(NOW - 8 * 864e5).toISOString() }), NOW)).toBe(false);
  });
});
