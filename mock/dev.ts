// Local development only: a fake ZTNET and a fake ZeroTier service in front of
// the real server, with generic demo data. Usage:
//   npx tsx mock/dev.ts [N]     (N = extra generated nodes, to try a big network)
//   MOCK_NO_ZT_TOKEN=1 npm run dev   (the ZeroTier token unreadable, as on a misconfigured host)
import { chmodSync, rmSync, writeFileSync } from 'node:fs';
import http from 'node:http';
import type net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { writeDemoHistory } from './demo-history.js';
import { startFakeServices } from './fake-services.js';
import { circleIcon, dotsMark, playMark } from './icons.js';

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

/**
 * A fake service: a tiny web server on localhost. [routes] maps paths to a
 * content type and body; other paths answer 404.
 */
function fakeService(
  routes: Record<string, [string, string | Buffer] | { redirect: string }>,
  port = 0,
): Promise<http.Server> {
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      const r = routes[req.url ?? ''];
      if (!r) res.writeHead(404).end();
      else if ('redirect' in r) res.writeHead(302, { Location: r.redirect }).end();
      else res.writeHead(200, { 'Content-Type': r[0] }).end(r[1]);
    });
    srv.listen(port, '127.0.0.1', () => resolve(srv));
  });
}
const portOf = (srv: net.Server) => (srv.address() as net.AddressInfo).port;

// Services: Jellyfin always up, Nextcloud coming and going every minute (so you
// can see `downSince` appear and disappear). The URLs point to localhost: the
// mock must never probe someone else's real ports. Both have an icon, found
// the two usual ways: declared in the page (Jellyfin, behind a redirect) and
// /favicon.ico (Nextcloud).
const jellyfin = await fakeService({
  '/': { redirect: '/web/' },
  '/web/': [
    'text/html',
    '<!doctype html><link rel="icon" href="touchicon.png" sizes="128x128"><title>Jellyfin</title>',
  ],
  '/web/touchicon.png': ['image/png', circleIcon([0x6b, 0x4d, 0xc4], playMark)],
});
const nextcloudRoutes = {
  '/': ['text/html', '<!doctype html><title>Nextcloud</title>'] as [string, string],
  '/favicon.ico': ['image/png', circleIcon([0x00, 0x82, 0xc9], dotsMark)] as [string, Buffer],
};
let nextcloud: http.Server | null = await fakeService(nextcloudRoutes);
const nextcloudPort = portOf(nextcloud);
setInterval(() => {
  if (nextcloud) {
    nextcloud.close();
    nextcloud = null;
  } else {
    void fakeService(nextcloudRoutes, nextcloudPort).then((s) => {
      nextcloud = s;
    });
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

// The fake ZTNET, like the real REST API, sends no `conStatus`: online/offline
// comes from `lastSeen` and the window. One minute instead of five, so home-tv
// (off for about two minutes at a time) actually shows up as offline.
process.env.ONLINE_WINDOW_MINUTES = process.env.ONLINE_WINDOW_MINUTES || '1';

const fake = await startFakeServices({ nodes: Number(process.env.MOCK_NODES || process.argv[2] || 0) });
Object.assign(process.env, fake.env);
// MOCK_NO_ZT_TOKEN=1: behave like the common broken install, the zerotier
// volume mounted but its root-only authtoken unreadable. The token points at a
// file with mode 000, so the server takes the real EACCES path; no latency,
// no relay/direct, health.localReason = 'token-unreadable'.
if (process.env.MOCK_NO_ZT_TOKEN) {
  delete process.env.ZT_AUTHTOKEN;
  const unreadable = path.join(os.tmpdir(), 'netmap-dev-authtoken.secret');
  rmSync(unreadable, { force: true }); // mode 000 from a previous run: not even writable
  writeFileSync(unreadable, 'mock-zt-token');
  chmodSync(unreadable, 0o000);
  process.env.ZT_AUTHTOKEN_FILE = unreadable;
  // root reads anything: there the token would be found after all
  if (process.getuid?.() === 0) console.warn('MOCK_NO_ZT_TOKEN: running as root, the token file is still readable');
}
if (!ownHistory && !process.env.MOCK_EMPTY_HISTORY) {
  writeDemoHistory(process.env.HISTORY_FILE, fake.members as Parameters<typeof writeDemoHistory>[1], [
    'Jellyfin',
    'Nextcloud',
  ]);
}
console.log(`mock ZTNET on :${fake.ztnetPort}, ZeroTier service on :${fake.ztPort}`);
await import('../server/src/index.js');
