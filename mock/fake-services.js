// Local development and tests only: a fake ZTNET and a fake ZeroTier service
// with demo data. Used by mock/dev.ts (development server) and by the
// end-to-end test (server/test/e2e.test.ts).

import http from 'node:http';

/**
 * @typedef {object} FakeOptions
 * @property {number} [nodes] number of nodes to generate (on top of the fixed ones)
 * @property {() => number} [clock] clock; the e2e test drives it to get deterministic data
 */

/** @param {FakeOptions} [opts] */
export function createFakeNetwork(opts = {}) {
  const clock = opts.clock ?? Date.now;
  const now = clock();
  // MOCK_NODES=50 (or `npx tsx mock/dev.ts 50`) to try the graph with many nodes.
  const TARGET = Number(opts.nodes || 0);

  let seq = 0;
  // conStatus: 2 = direct (online), 1 = relayed (online but no latency), 0 = offline
  /** @param {string} name @param {number} conStatus @param {number} [daysAgo] @returns {Record<string, any>} */
  const mk = (name, conStatus, daysAgo = 0) => ({
    id: (++seq).toString(16).padStart(10, '0'),
    name,
    authorized: true,
    ipAssignments: [`10.147.17.${seq + 1}`],
    lastSeen: new Date(now - (conStatus > 0 ? 30e3 : daysAgo * 864e5)).toISOString(),
    conStatus,
    // how long it has been a member: spread-out dates, so "member since…" makes sense
    creationTime: now - (60 + seq * 17) * 864e5,
  });

  /** @type {Record<string, any>[]} */
  const members = [
    // the controller "doesn't see itself": conStatus 0 on purpose, the server forces it online
    mk('nas', 0),
    // alice's island (3 devices, person-type names) — phone via relay
    mk('alice-pc', 2),
    mk('alice-phone', 1),
    mk('alice-laptop', 0, 2),
    // bob's island (2 devices)
    mk('bob-phone', 2),
    mk('bob-tablet', 0, 5),
    // carol's island: also tests merging "carol2"
    mk('carol-pc', 2),
    mk('carol2-pc', 0, 1),
    // singles, with TYPE-person style names as in a real network
    mk('PC-Dave', 2),
    mk('LAPTOP-Erin', 2),
    mk('frank-console', 1), // via relay
    mk('home-tv', 2),
    mk('lab-pi', 0, 12),
    // NOT authorized: they are not devices of the network and must not appear
    // among the devices — but the page must say that someone asked to join.
    // Two different cases on purpose: one knocking for the first time, and one
    // that had been authorized and then revoked.
    {
      id: 'ffffffffff',
      name: 'guest-laptop',
      authorized: false,
      ipAssignments: [],
      lastSeen: null,
      conStatus: 0,
      creationTime: now - 3 * 3600e3,
    },
    {
      id: 'eeeeeeeeee',
      name: 'old-laptop',
      authorized: false,
      ipAssignments: [],
      lastSeen: null,
      conStatus: 0,
      creationTime: now - 40 * 864e5,
      lastDeauthorizedTime: now - 5 * 864e5,
    },
    // deleted in ZTNET but still on the controller: it must disappear, not linger
    // as a ghost on the map
    {
      id: 'dddddddddd',
      name: 'removed-node',
      authorized: true,
      ipAssignments: ['10.147.17.99'],
      lastSeen: new Date(now).toISOString(),
      conStatus: 2,
      deleted: true,
    },
  ];

  // Some members carry notes and labels written by hand in ZTNET: the page shows
  // them instead of ignoring them, because they are the only data someone entered
  // on purpose.
  /** @param {string} n */
  const byName = (n) => members.find((m) => m.name === n);
  Object.assign(byName('alice-pc') ?? {}, {
    description: 'Main workstation, stays on overnight for backups',
    notations: [{ label: { name: 'always on', color: '#8b5cf6' } }],
  });
  Object.assign(byName('lab-pi') ?? {}, {
    notations: [{ label: { name: 'lab', color: '#f59e0b' } }],
  });
  // version reported to the controller: it exists for relayed nodes too, where
  // /peer doesn't know it
  for (const m of members) {
    if (m.conStatus === 1) {
      m.vMajor = 1;
      m.vMinor = 12;
      m.vRev = 2;
    }
  }

  const kinds = ['PC', 'Laptop', 'iPhone', 'Android', 'TV', 'Tablet', 'Server', 'Console'];
  for (let i = members.length; members.length < TARGET + 1; i++) {
    // cycle 0=offline,1=relay,2..: mostly direct, a few relayed and offline
    const cs = i % 5 === 0 ? 0 : i % 7 === 0 ? 1 : 2;
    members.push(mk(`${kinds[i % kinds.length]}-${String.fromCharCode(65 + (i % 26))}${i}`, cs, (i % 9) + 1));
  }

  // The fake network is "alive": without changes over time the sparkline would be
  // a flat line and the event timeline would stay empty, so you couldn't tell
  // whether the frontend really draws them.
  //  - latency oscillates around a per-node base value;
  //  - `PC-Dave` spikes now and then (it must show up in the timeline);
  //  - `home-tv` turns off and on again (generates offline/online events).
  const t0 = clock();
  /** @param {number} i */
  const baseLatency = (i) => 8 + ((i * 37) % 90);
  /** @param {Record<string, any>} m @param {number} i */
  function latencyNow(m, i) {
    const t = (clock() - t0) / 1000;
    const wave = Math.sin(t / 23 + i) * 9 + Math.sin(t / 7 + i * 2) * 4;
    const spike = m.name === 'PC-Dave' && Math.sin(t / 40) > 0.93 ? 260 : 0;
    return Math.max(1, Math.round(baseLatency(i) + wave + spike));
  }
  function tick() {
    const t = (clock() - t0) / 1000;
    const tv = members.find((m) => m.name === 'home-tv');
    if (tv) {
      const up = Math.sin(t / 45) > -0.3;
      tv.conStatus = up ? 2 : 0;
      if (up) tv.lastSeen = new Date(clock()).toISOString();
    }
  }

  // Fake local ZeroTier service. It reproduces the real shape of /peer:
  //  - direct links (conStatus 2) have latency, version and a `paths[]` with the
  //    physical address; if that address is private the node is on the same LAN,
  //    otherwise it is direct over the internet;
  //  - relayed ones (conStatus 1) have NO paths: the absence of paths is exactly
  //    how ZeroTier says "I reach this peer only through a relay", and the
  //    version stays unknown (-1);
  //  - ZeroTier network roots show up with role PLANET: they are not devices and
  //    the server must discard them.
  const VERSIONS = ['1.14.2', '1.14.0', '1.12.2', '1.10.6'];
  /** @type {http.RequestListener} */
  const ztHandler = (req, res) => {
    tick();
    const now = clock();
    /** @type {Record<string, any>[]} */
    const peers = members
      .map((m, i) => /** @type {[Record<string, any>, number]} */ ([m, i]))
      .filter(([m]) => m.conStatus > 0)
      .map(([m, i]) => {
        if (m.conStatus === 1) {
          // `tunneled` is the field with which ZeroTier explicitly says "I reach
          // this peer only through a relay". The absence of paths says the same
          // thing, but by inference.
          return {
            address: m.id,
            role: 'LEAF',
            latency: -1,
            version: '-1.-1.-1',
            versionMajor: -1,
            tunneled: true,
            paths: [],
          };
        }
        const lan = i % 4 === 0; // a few nodes on the same home network
        const v = /** @type {string} */ (VERSIONS[i % VERSIONS.length]);
        const [maj] = v.split('.').map(Number);
        return {
          address: m.id,
          role: 'LEAF',
          latency: latencyNow(m, i),
          version: v,
          versionMajor: maj,
          tunneled: false,
          paths: [
            {
              address: lan ? `192.168.1.${20 + i}/9993` : `93.45.${i}.${10 + i}/9993`,
              preferred: true,
              expired: false,
              active: true,
              // a few "quiet" nodes: last packet received minutes ago
              lastReceive: now - (i % 6 === 0 ? 240e3 : 3e3),
              lastSend: now - 2e3,
            },
          ],
        };
      });
    peers.push({ address: 'planet0000', role: 'PLANET', latency: 12, version: '1.14.2', versionMajor: 1, paths: [] });

    // /metrics: Prometheus format, as ZeroTier exposes it since 1.12. CUMULATIVE
    // packet counters per peer; each node "consumes" at a different rate, so the
    // traffic ranking actually has a winner.
    // /status: the local node. `tcpFallbackActive` comes and goes, so you can see
    // the page flag it and then clear it instead of showing it permanently.
    if (req.url === '/status') {
      const t = (clock() - t0) / 1000;
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          address: '0123456789',
          online: true,
          tcpFallbackActive: Math.sin(t / 25) > 0.55,
          version: '1.14.2',
          versionMajor: 1,
          versionMinor: 14,
          versionRev: 2,
          clock: clock(),
          planetWorldId: 149604618,
          config: {
            settings: {
              allowTcpFallbackRelay: true,
              forceTcpRelay: false,
              portMappingEnabled: true,
              primaryPort: 9993,
              // the server must NEVER send this to the browser: it is the home's public IP
              surfaceAddresses: [['93.45.12.10/9993']],
            },
          },
        }),
      );
      return;
    }

    // /network: our network as seen by the local node
    if (req.url === '/network') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify([
          {
            id: 'abcdef1234567890',
            nwid: 'abcdef1234567890',
            name: 'home-net',
            status: 'OK',
            type: 'PRIVATE',
            mac: '32:11:22:33:44:55',
            mtu: 2800,
            dhcp: false,
            bridge: false,
            broadcastEnabled: true,
            portError: 0,
            netconfRevision: 42,
            portDeviceName: 'ztabcdef01',
            // The configuration AS IT ARRIVED at this node: identical to the
            // controller's, because propagation worked. What fails is the next
            // stage — `allowDNS` is off, which is the real-world case where DNS is
            // configured correctly and works nowhere.
            dns: { domain: 'home.zt', servers: ['10.147.17.176'] },
            routes: [
              { target: '10.147.17.0/24', via: null },
              { target: '192.168.1.0/24', via: '10.147.17.176' },
            ],
            // allowDNS OFF on purpose: it is ZeroTier's default, and it is the
            // real-world case where DNS is configured on the network but no device
            // applies it. The page must notice and say so, not leave it invisible.
            allowManaged: true,
            allowGlobal: false,
            allowDefault: false,
            allowDNS: false,
            assignedAddresses: ['10.147.17.176/24'],
          },
        ]),
      );
      return;
    }

    if (req.url === '/metrics') {
      const t = (clock() - t0) / 1000;
      let body = '# HELP zt_peer_packets Number of packets to/from a peer\n# TYPE zt_peer_packets counter\n';
      members
        .filter((m) => m.conStatus > 0)
        .forEach((m, i) => {
          const rate = 40 + i * 55; // packets per second, different per node
          const rx = Math.round(t * rate + i * 1000);
          const tx = Math.round(rx * 0.6);
          body += `zt_peer_packets{direction="rx",node_id="${m.id}"} ${rx}\n`;
          body += `zt_peer_packets{direction="tx",node_id="${m.id}"} ${tx}\n`;
        });
      // packet errors: only on a few nodes, so the page has something to report
      // without making it look like everything is broken
      body += '# HELP zt_peer_packet_errors Number of incoming packet errors from a peer\n';
      body += '# TYPE zt_peer_packet_errors counter\n';
      members
        .filter((m) => m.conStatus > 0)
        .forEach((m, i) => {
          if (i % 4 !== 1) return;
          body += `zt_peer_packet_errors{node_id="${m.id}"} ${Math.round(t / 12) + i}\n`;
        });
      // alive and dead paths per peer: a snapshot (gauge), not a counter
      body += '# HELP zt_peer_path_count Number of paths to peer\n# TYPE zt_peer_path_count gauge\n';
      members
        .filter((m) => m.conStatus > 0)
        .forEach((m, i) => {
          body += `zt_peer_path_count{node_id="${m.id}",status="alive"} ${m.conStatus === 1 ? 0 : 1 + (i % 2)}\n`;
          body += `zt_peer_path_count{node_id="${m.id}",status="dead"} ${i % 5 === 2 ? 2 : 0}\n`;
        });
      // The node's BYTES, split by protocol. TCP traffic grows only while the
      // fallback is active: that is how you see a network has stopped going over
      // UDP.
      const tcpOn = Math.sin(t / 25) > 0.55;
      body += '# HELP zt_data number of bytes ZeroTier has transmitted or received\n';
      body += '# TYPE zt_data counter\n';
      body += `zt_data{protocol="udp",direction="rx"} ${Math.round(t * 82000)}\n`;
      body += `zt_data{protocol="udp",direction="tx"} ${Math.round(t * 51000)}\n`;
      body += `zt_data{protocol="tcp",direction="rx"} ${Math.round(t * (tcpOn ? 9000 : 40))}\n`;
      body += `zt_data{protocol="tcp",direction="tx"} ${Math.round(t * (tcpOn ? 6000 : 25))}\n`;
      // errors by type: "network_access_denied" grows while an unauthorized node
      // keeps knocking — it ties in with the list of access requests
      body += '# HELP zt_packet_error ZeroTier packet errors\n# TYPE zt_packet_error counter\n';
      body += `zt_packet_error{error_type="network_access_denied",direction="rx"} ${Math.round(t / 8)}\n`;
      body += `zt_packet_error{error_type="authentication_required",direction="rx"} ${Math.round(t / 55)}\n`;
      body += `zt_packet_error{error_type="obj_not_found",direction="rx"} ${Math.round(t / 130)}\n`;
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(body);
      return;
    }

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(peers));
  };

  /** @type {http.RequestListener} */
  const ztnetHandler = (req, res) => {
    if (req.headers['x-ztnet-auth'] !== 'test-token') {
      res.writeHead(401);
      res.end('{}');
      return;
    }
    tick();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    if ((req.url ?? '').endsWith('/member')) res.end(JSON.stringify(members));
    else
      res.end(
        JSON.stringify({
          id: 'abcdef1234567890',
          config: {
            name: 'home-net',
            private: true,
            v6AssignMode: { rfc4193: true, '6plane': false, zt: false },
            mtu: 2800,
            enableBroadcast: true,
            multicastLimit: 32,
            creationTime: now - 412 * 864e5,
            routes: [
              { target: '10.147.17.0/24', via: null }, // the network's managed route
              { target: '192.168.1.0/24', via: '10.147.17.176' }, // home subnet via the NAS
            ],
            ipAssignmentPools: [{ ipRangeStart: '10.147.17.1', ipRangeEnd: '10.147.17.254' }],
            dns: { domain: 'home.zt', servers: ['10.147.17.176'] },
          },
        }),
      );
  };

  return { members, ztHandler, ztnetHandler };
}

/** @param {http.Server} server @param {number} port @param {string} host @returns {Promise<number>} */
function listen(server, port, host) {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, host, () => {
      const addr = server.address();
      resolve(typeof addr === 'object' && addr ? addr.port : port);
    });
  });
}

/**
 * Starts the two fake services. Port 0 = chosen by the OS (for tests).
 * @param {FakeOptions & { ztnetPort?: number, ztPort?: number, host?: string }} [opts]
 */
export async function startFakeServices(opts = {}) {
  const fake = createFakeNetwork(opts);
  // the mock listens ONLY on localhost: it must never be exposed on ZeroTier/LAN
  const host = opts.host ?? '127.0.0.1';
  const zt = http.createServer(fake.ztHandler);
  const ztnet = http.createServer(fake.ztnetHandler);
  const ztPort = await listen(zt, opts.ztPort ?? 39993, host);
  const ztnetPort = await listen(ztnet, opts.ztnetPort ?? 3999, host);
  return {
    members: fake.members,
    ztPort,
    ztnetPort,
    /** environment variables pointing the netmap server at these fake services */
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
      return Promise.all([
        new Promise((r) => zt.close(() => r(undefined))),
        new Promise((r) => ztnet.close(() => r(undefined))),
      ]);
    },
  };
}
