// Netmap — a small proxy in front of the ZTNET API.
// Exposes /api/nodes with public fields only (name, IP, online status, history);
// the ZTNET token stays here and never reaches the browser.

import { serve } from '@hono/node-server';
import { ConfigError, loadConfig } from './config.js';
import { createState } from './history/state.js';
import { HistoryStore } from './history/store.js';
import { createApp } from './http.js';
import { mergeServices, readServicesFile, ServiceMonitor, servicesFilePath } from './services.js';
import { SnapshotService } from './snapshot.js';
import { MetricsSource } from './sources/metrics.js';
import { ZtService } from './sources/ztservice.js';

function main(): void {
  let config: ReturnType<typeof loadConfig>;
  try {
    config = loadConfig();
  } catch (err) {
    if (err instanceof ConfigError) {
      console.error(err.message);
      process.exit(1);
    }
    throw err;
  }

  const state = createState();
  const store = new HistoryStore(config.historyFile, state);
  const zt = new ZtService(config);
  const metrics = new MetricsSource(config, state);
  const services = new ServiceMonitor(mergeServices(config.quickLinks, readServicesFile(servicesFilePath())), state);
  const snapshots = new SnapshotService({ config, state, zt, metrics, services });

  // save on shutdown too: `docker compose restart` sends SIGTERM
  for (const sig of ['SIGTERM', 'SIGINT'] as const) {
    process.on(sig, () => {
      store.save();
      process.exit(0);
    });
  }

  const app = createApp({
    snapshot: () => snapshots.snapshot,
    subscribe: (fn) => snapshots.subscribe(fn),
    webDir: config.webDir,
    whoamiTestIp: config.whoamiTestIp,
  });

  store.load(); // before the first refresh: the initial poll must find the past
  void snapshots.refresh();
  setInterval(() => void snapshots.refresh(), config.pollSeconds * 1000);
  setInterval(() => store.save(), config.saveSeconds * 1000);
  serve({ fetch: app.fetch, port: config.port, hostname: config.bindHost }, () =>
    console.log(
      `Netmap listening on ${config.bindHost}:${config.port} (ZTNET: ${config.ztnetUrl}, network: ${config.networkId})`,
    ),
  );
}

main();
