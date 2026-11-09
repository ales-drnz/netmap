// Local development only: a fake ZTNET and a fake ZeroTier service in front of
// the real server, with generic demo data. Usage:
//   npx tsx mock/dev.ts [N]     (N = extra generated nodes, to try a big network)
import { writeFileSync } from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { writeDemoHistory } from './demo-history.js';
import { startFakeServices } from './fake-services.js';

process.env.PORT = process.env.PORT || '8082';
// the mock listens ONLY on localhost: it must never be exposed on ZeroTier/LAN
// (otherwise anyone reaching this machine over ZT would see the fake data)
process.env.BIND_HOST = process.env.BIND_HOST || '127.0.0.1';
process.env.POLL_SECONDS = '5';
process.env.HUB_NODE_NAME = 'nas';
process.env.WHOAMI_TEST_IP = '10.147.17.4'; // pretend the visitor is alice-phone
// the development history goes to /tmp, not into the project folder
// unless told otherwise, start from a fresh demo history (see demo-history.ts);
// MOCK_EMPTY_HISTORY=1 starts from nothing, like a brand-new install
const ownHistory = !!process.env.HISTORY_FILE;
process.env.HISTORY_FILE = process.env.HISTORY_FILE || path.join(os.tmpdir(), 'netmap-dev-history.json');

/** a fake service: a TCP port that accepts and closes right away */
function tcpListener(): Promise<net.Server> {
  return new Promise((resolve) => {
    const srv = net.createServer((sock) => sock.end());
    srv.listen(0, '127.0.0.1', () => resolve(srv));
  });
}
const portOf = (srv: net.Server) => (srv.address() as net.AddressInfo).port;

// Services: Jellyfin always up, Nextcloud coming and going every minute (so you
// can see `downSince` appear and disappear). The URLs point to localhost: the
// mock must never probe someone else's real ports.
const jellyfin = await tcpListener();
let nextcloud: net.Server | null = await tcpListener();
const nextcloudPort = portOf(nextcloud);
setInterval(() => {
  if (nextcloud) {
    nextcloud.close();
    nextcloud = null;
  } else {
    nextcloud = net.createServer((sock) => sock.end()).listen(nextcloudPort, '127.0.0.1');
  }
}, 60_000).unref();
const servicesFile = path.join(os.tmpdir(), 'netmap-dev-services.json');
writeFileSync(
  servicesFile,
  JSON.stringify([
    {
      name: 'Jellyfin',
      url: `http://127.0.0.1:${portOf(jellyfin)}`,
      description: 'Movies and shows',
      app: 'Jellyfin for iOS, Android and TV',
      host: 'nas',
      color: '#aa5cc3',
    },
    {
      name: 'Nextcloud',
      url: `http://127.0.0.1:${nextcloudPort}/`,
      description: 'Shared files and photos',
      app: 'Nextcloud',
      host: 'alice-pc',
      color: '#0082c9',
    },
  ]),
);
process.env.SERVICES_FILE = servicesFile;

const fake = await startFakeServices({ nodes: Number(process.env.MOCK_NODES || process.argv[2] || 0) });
Object.assign(process.env, fake.env);
if (!ownHistory && !process.env.MOCK_EMPTY_HISTORY) {
  writeDemoHistory(process.env.HISTORY_FILE, fake.members as Parameters<typeof writeDemoHistory>[1], [
    'Jellyfin',
    'Nextcloud',
  ]);
}
console.log(`mock ZTNET on :${fake.ztnetPort}, ZeroTier service on :${fake.ztPort}`);
await import('../server/src/index.js');
