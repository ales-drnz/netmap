// Network services (Jellyfin, Plex, ...): the header's quick links, plus a
// reachability check done by the server.
//
// Two sources: QUICK_LINKS (name and URL only, as before) and a SERVICES_FILE
// with the details. The file wins over entries with the same name.
//
// The check is a plain TCP connection to the host:port of the configured URL,
// and ONLY to that: no redirects are followed, nothing is discovered, no other
// address is touched. It says "the port answers", not "the service works" —
// which is the question that matters when someone asks "is Jellyfin down?".

import fs from 'node:fs';
import net from 'node:net';
import { join } from 'node:path';
import { z } from 'zod';
import type { QuickLink } from '../../shared/api.js';
import { appDir } from './config.js';
import type { HistoryState, ServiceHistory } from './history/state.js';

export const ServiceSchema = z.object({
  name: z.string().min(1),
  url: z.string().min(1),
  description: z.string().optional(),
  app: z.string().optional(),
  /** name of the member hosting it */
  host: z.string().optional(),
  color: z.string().optional(),
});
export const ServicesFileSchema = z.array(ServiceSchema);
export type ServiceDef = z.infer<typeof ServiceSchema>;

export const HOUR_MS = 3600e3;
export const HOUR_BUCKETS = 24;
export const PROBE_TIMEOUT_MS = 2000;

/** File path: SERVICES_FILE, otherwise `services.json` in the app folder. */
export function servicesFilePath(env: NodeJS.ProcessEnv = process.env): string {
  return env.SERVICES_FILE || join(appDir(), 'services.json');
}

/**
 * Reads the services file. Missing: silently skipped (it is optional).
 * Unreadable or invalid: logged once and skipped.
 */
export function readServicesFile(file: string, log: (...a: unknown[]) => void = console.error): ServiceDef[] {
  let text: string;
  try {
    text = fs.readFileSync(file, 'utf8');
  } catch {
    return [];
  }
  try {
    const parsed = ServicesFileSchema.safeParse(JSON.parse(text));
    if (!parsed.success) {
      log(
        `services: ${file} does not have the expected shape (${parsed.error.issues[0]?.message ?? 'invalid'}), ignored`,
      );
      return [];
    }
    return parsed.data;
  } catch (err) {
    log(`services: ${file} is not valid JSON (${(err as Error).message}), ignored`);
    return [];
  }
}

/** QUICK_LINKS + file: file entries replace those with the same name, in the same position. */
export function mergeServices(quick: readonly QuickLink[], file: readonly ServiceDef[]): ServiceDef[] {
  const out: ServiceDef[] = quick.map((l) => ({ name: l.name, url: l.url }));
  for (const s of file) {
    const i = out.findIndex((x) => x.name === s.name);
    if (i >= 0) out[i] = s;
    else out.push(s);
  }
  return out;
}

/** host and port to check; null if the URL is not http(s) or cannot be parsed */
export function probeTarget(url: string): { host: string; port: number } | null {
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return null;
  }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') return null;
  const port = u.port ? Number(u.port) : u.protocol === 'https:' ? 443 : 80;
  const host = u.hostname.replace(/^\[|\]$/g, '');
  return host ? { host, port } : null;
}

/** Connection time in ms, or null if there is no answer within the timeout. */
export function tcpProbe(host: string, port: number, timeoutMs = PROBE_TIMEOUT_MS): Promise<number | null> {
  return new Promise((resolve) => {
    const start = performance.now();
    const sock = net.connect({ host, port });
    let done = false;
    const finish = (ms: number | null) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      sock.destroy();
      resolve(ms);
    };
    const timer = setTimeout(() => finish(null), timeoutMs);
    sock.once('connect', () => finish(Math.max(0, Math.round(performance.now() - start))));
    sock.once('error', () => finish(null));
  });
}

type Prober = (host: string, port: number) => Promise<number | null>;

export class ServiceMonitor {
  /** result of this process's last check: null = not checked yet */
  private last = new Map<string, { up: boolean; ms: number | null }>();

  constructor(
    readonly services: readonly ServiceDef[],
    private readonly state: HistoryState,
    private readonly prober: Prober = tcpProbe,
  ) {}

  private histOf(name: string): ServiceHistory {
    let h = this.state.services.get(name);
    if (!h) {
      h = { beats: [], downSince: null };
      this.state.services.set(name, h);
    }
    return h;
  }

  /** Checks all services in parallel and records the results. */
  async probeAll(now: number = Date.now()): Promise<void> {
    await Promise.all(
      this.services.map(async (s) => {
        const target = probeTarget(s.url);
        if (!target) return; // nothing to check: stays "not checked"
        const ms = await this.prober(target.host, target.port);
        this.record(s.name, ms != null, ms, now);
      }),
    );
    // forget services removed from the configuration
    const names = new Set(this.services.map((s) => s.name));
    for (const name of [...this.state.services.keys()]) if (!names.has(name)) this.state.services.delete(name);
  }

  record(name: string, up: boolean, ms: number | null, now: number): void {
    this.last.set(name, { up, ms: up ? ms : null });
    const h = this.histOf(name);
    // outage start: the FIRST failed attempt, not the latest
    if (up) h.downSince = null;
    else if (h.downSince == null) h.downSince = now;
    const slot = Math.floor(now / HOUR_MS) * HOUR_MS;
    const last = h.beats[h.beats.length - 1];
    if (last && last.t === slot) {
      last.tot++;
      if (up) last.up++;
    } else h.beats.push({ t: slot, up: up ? 1 : 0, tot: 1 });
    const cutoff = now - HOUR_BUCKETS * HOUR_MS;
    while (h.beats.length && (h.beats[0] as { t: number }).t < cutoff) h.beats.shift();
  }

  /** 24 hourly buckets, from the oldest to the current hour */
  hoursOf(name: string, now: number): (number | null)[] {
    const byT = new Map((this.state.services.get(name)?.beats || []).map((b) => [b.t, b]));
    const cur = Math.floor(now / HOUR_MS) * HOUR_MS;
    const out: (number | null)[] = [];
    for (let i = HOUR_BUCKETS - 1; i >= 0; i--) {
      const b = byT.get(cur - i * HOUR_MS);
      out.push(b?.tot ? Math.round((b.up / b.tot) * 100) / 100 : null);
    }
    return out;
  }

  /** The links as sent to the browser. */
  links(now: number): QuickLink[] {
    return this.services.map((s) => {
      const last = this.last.get(s.name);
      return {
        name: s.name,
        url: s.url,
        description: s.description ?? null,
        app: s.app ?? null,
        host: s.host ?? null,
        color: s.color ?? null,
        up: last ? last.up : null,
        ms: last ? last.ms : null,
        downSince: last && !last.up ? (this.state.services.get(s.name)?.downSince ?? null) : null,
        hours: this.hoursOf(s.name, now),
      };
    });
  }
}
