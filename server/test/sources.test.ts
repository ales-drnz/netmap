import { describe, expect, it } from 'vitest';
import { createState } from '../src/history/state.js';
import { counterDelta, MetricsSource, parseProm, trafficOf } from '../src/sources/metrics.js';
import { memberAddress, networkInfo, parseMembers } from '../src/sources/ztnet.js';
import { isPrivateAddr, localNetworkInfo, parsePeerList, peerInfo, statusInfo } from '../src/sources/ztservice.js';

describe('isPrivateAddr', () => {
  it.each([
    ['10.0.0.1/9993', true],
    ['127.0.0.1/1', true],
    ['169.254.3.4/9993', true],
    ['192.168.1.20/9993', true],
    ['172.16.0.1/9993', true],
    ['172.31.255.1/9993', true],
    ['172.32.0.1/9993', false],
    ['172.15.0.1/9993', false],
    ['93.45.1.11/9993', false],
    ['::1', true],
    ['[fe80::1]/9993', true],
    ['fd12:3456::1/9993', true],
    ['2001:db8::1/9993', false],
    ['', false],
    [null, false],
  ])('%s → %s', (addr, expected) => {
    expect(isPrivateAddr(addr)).toBe(expected);
  });
});

describe('peerInfo: privacy and shape', () => {
  const peer = parsePeerList([
    {
      address: 'aaaaaaaaaa',
      role: 'LEAF',
      latency: 23,
      version: '1.14.2',
      versionMajor: 1,
      tunneled: false,
      paths: [
        { address: '93.45.1.11/9993', preferred: false, expired: false, active: true, lastReceive: 5, lastSend: 6 },
        { address: '2001:db8::7/9993', preferred: true, expired: false, active: true, lastReceive: 10, lastSend: 11 },
        { address: '81.2.3.4/9993', preferred: true, expired: true, active: false },
      ],
    },
  ])[0];

  it('contains no address, only derived facts', () => {
    if (!peer) throw new Error('peer not read');
    const info = peerInfo(peer);
    expect(info).toEqual({
      latency: 23,
      version: '1.14.2',
      link: 'wan',
      tunneled: false,
      paths: 3,
      pathsAlive: 2,
      family: 6,
      lastRecv: 10,
      lastSend: 11,
    });
    const text = JSON.stringify(info);
    for (const ip of ['93.45', '2001:db8', '81.2.3.4', '9993']) expect(text).not.toContain(ip);
  });

  it('relay, unknown version and latency -1 become null', () => {
    const [p] = parsePeerList([{ address: 'b', latency: -1, version: '-1.-1.-1', versionMajor: -1, paths: [] }]);
    expect(peerInfo(p as NonNullable<typeof p>)).toMatchObject({
      latency: null,
      version: null,
      link: 'relay',
      family: null,
      tunneled: null,
    });
  });

  it('unexpected shapes degrade instead of throwing', () => {
    expect(parsePeerList({ not: 'an array' })).toEqual([]);
    const list = parsePeerList([null, 3, 'x', { address: 'c', paths: [null, { address: 42 }] }]);
    expect(list).toHaveLength(1);
    expect(() => peerInfo(list[0] as NonNullable<(typeof list)[0]>)).not.toThrow();
  });
});

describe('statusInfo / localNetworkInfo', () => {
  it('surfaceAddresses never leaks', () => {
    const s = statusInfo({
      online: true,
      version: '1.14.2',
      config: { settings: { surfaceAddresses: [['93.45.12.10/9993']], primaryPort: 9993 } },
    });
    expect(JSON.stringify(s)).not.toContain('93.45');
    expect(s).toEqual({
      online: true,
      version: '1.14.2',
      tcpFallback: false,
      forceTcpRelay: false,
      allowTcpFallback: true,
      portMapping: null,
      port: 9993,
    });
  });

  it('missing fields = null, not false', () => {
    const n = localNetworkInfo([{ nwid: 'ABC', status: 'OK' }], 'abc');
    expect(n?.allowDNS).toBeNull();
    expect(n?.statusLabel).toBe('active');
    expect(localNetworkInfo([{ id: 'zzz' }], 'abc')).toBeNull();
    expect(localNetworkInfo('garbage', 'abc')).toBeNull();
  });
});

describe('ZTNET', () => {
  it('members: an unreadable element is dropped, it does not break the poll', () => {
    const list = parseMembers([null, { id: 'ABCDEF0123', name: 7, lastSeen: { x: 1 } }, 'x']);
    expect(list).toHaveLength(1);
    const m = list[0];
    if (!m) throw new Error();
    expect(memberAddress(m)).toBe('abcdef0123');
    expect(m.name).toBeUndefined();
    expect(m.lastSeen).toBeNull();
    expect(parseMembers({ error: 'x' })).toEqual([]);
  });

  it('networkInfo reads nested or flattened config', () => {
    const flat = networkInfo({ mtu: 2800, private: true, routes: [{ target: '10.0.0.0/24' }, null] });
    expect(flat).toMatchObject({ mtu: 2800, private: true, routes: [{ target: '10.0.0.0/24', via: null }] });
    expect(networkInfo(null)).toBeNull();
  });
});

describe('metrics', () => {
  it('parseProm reads escaped labels', () => {
    const out = [...parseProm('# c\nzt_x{a="1",b="q\\"x"} 4\nbad line\nzt_y 2.5\n')];
    expect(out).toEqual([
      { name: 'zt_x', labels: { a: '1', b: 'q"x' }, value: 4 },
      { name: 'zt_y', labels: {}, value: 2.5 },
    ]);
  });

  it('counterDelta: first sample zero, restart = new value', () => {
    expect(counterDelta(10, null)).toBe(0);
    expect(counterDelta(15, 10)).toBe(5);
    expect(counterDelta(3, 10)).toBe(3);
  });

  it('accumulates daily deltas only for known members', () => {
    const s = createState();
    s.history.set('aaaaaaaaaa', {
      name: 'a',
      lat: [],
      latDays: {},
      beats: [],
      traf: { lastRx: null, lastTx: null, lastErr: null, days: {} },
    });
    const m = new MetricsSource({ ztServiceUrl: '', ztToken: 't', log: () => {} }, s);
    const now = Date.UTC(2026, 3, 1);
    const body = (rx: number) =>
      `zt_peer_packets{direction="rx",node_id="AAAAAAAAAA"} ${rx}\nzt_peer_packets{direction="rx",node_id="ffffffffff"} 1\n`;
    m.ingest(body(100), now);
    m.ingest(body(160), now + 1000);
    expect(m.seen).toBe(true);
    expect(trafficOf(s, 'aaaaaaaaaa', now)?.packets).toBe(60);
    expect(s.history.has('ffffffffff')).toBe(false);
  });

  it('200 without counters = metrics disabled', () => {
    const m = new MetricsSource({ ztServiceUrl: '', ztToken: 't', log: () => {} }, createState());
    m.ingest('', 0);
    expect(m.off).toBe(true);
    expect(m.seen).toBe(false);
  });
});
