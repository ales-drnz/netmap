// --- history persistence ---------------------------------------------------
// A JSON file, read back at startup. The path must be on a writable volume: in
// the Portainer deployment the app folder is mounted READ-ONLY, so writing next
// to server.js would fail. If the path is not writable, persistence turns itself
// off and the app keeps working (as before, everything in RAM): better to lose
// the history than to not start at all.

import fs from 'node:fs';
import path from 'node:path';
import type { NetEvent } from '../../../shared/api.js';
import {
  EVENT_MAX,
  emptyTraf,
  type HistoryState,
  type NodeHistory,
  type ServiceHistory,
  SPARK_SAMPLES,
} from './state.js';

/**
 * File format version. Files written by the old server.js lack the field: they
 * count as version 0, which has exactly the same shape.
 */
export const SCHEMA_VERSION = 1;

type Rec = Record<string, unknown>;
const isRec = (v: unknown): v is Rec => typeof v === 'object' && v !== null;

export interface HistoryFile {
  schemaVersion: number;
  savedAt: number;
  history: Record<string, NodeHistory>;
  events: NetEvent[];
  netTraffic: { days: HistoryState['netTraffic']['days'] };
  netErrors: { days: HistoryState['netErrors']['days'] };
  pendingSeen: string[];
  /** since version 1: service checks */
  services: Record<string, ServiceHistory>;
}

export interface Logger {
  log: (...args: unknown[]) => void;
  error: (...args: unknown[]) => void;
}

export class HistoryStore {
  canPersist = false;

  constructor(
    private readonly file: string,
    private readonly state: HistoryState,
    private readonly logger: Logger = console,
  ) {}

  /** Call before the first refresh: the initial poll must find the past. */
  load(now: number = Date.now()): void {
    const { file, state, logger } = this;
    try {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.accessSync(path.dirname(file), fs.constants.W_OK);
      this.canPersist = true;
    } catch {
      logger.log(
        `history not persistent: ${path.dirname(file)} is not writable ` +
          '(mount a volume and set HISTORY_FILE, otherwise uptime and charts restart from zero on every restart)',
      );
      return;
    }
    try {
      const raw: unknown = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (!isRec(raw)) throw new Error('unrecognized format');
      this.apply(raw, now);
      logger.log(`history restored from ${file}: ${state.history.size} nodes, ${state.events.length} events`);
    } catch (err) {
      // missing file on first start: that's normal, not an error
      const e = err as NodeJS.ErrnoException;
      if (e.code !== 'ENOENT') logger.error(`history not readable (${file}):`, e.message || err);
    }
  }

  /** Applies an already-read file to the state. Tolerates files without `schemaVersion` (old server.js). */
  apply(raw: Rec, now: number = Date.now()): void {
    const { state } = this;
    const version = typeof raw.schemaVersion === 'number' ? raw.schemaVersion : 0;
    if (version > SCHEMA_VERSION) {
      this.logger.log(`history written by a newer version (schema ${version}): trying to read the known fields`);
    }
    const cutoff = now - 24 * 3600e3;
    for (const [id, h] of Object.entries(isRec(raw.history) ? raw.history : {})) {
      if (!isRec(h)) continue;
      const traf = isRec(h.traf) ? h.traf : null;
      state.history.set(id, {
        name: (h.name as string) || id,
        lat: Array.isArray(h.lat) ? (h.lat.slice(-SPARK_SAMPLES) as (number | null)[]) : [],
        // windows older than 24h expired while the service was down
        beats: (Array.isArray(h.beats) ? h.beats : []).filter(
          (b): b is NodeHistory['beats'][number] => isRec(b) && (b.t as number) >= cutoff,
        ),
        // the daily latency histograms: they are what makes it possible to say
        // "worse than before", and without persistence they would never cover
        // enough days to say it
        latDays: isRec(h.latDays) ? (h.latDays as NodeHistory['latDays']) : {},
        // daily traffic is the part that makes persistence worthwhile: without it
        // the 30-day ranking would never get to cover them.
        // `lastRx/lastTx` are reset: ZeroTier has restarted from scratch meanwhile,
        // and comparing with the old value would produce a made-up delta.
        traf: { ...emptyTraf(), days: (traf?.days as NodeHistory['traf']['days']) || {} },
      });
    }
    // same logic for the network counters: keep the days, reset the references
    // to the cumulative counters
    const nt = isRec(raw.netTraffic) ? raw.netTraffic.days : null;
    if (nt) Object.assign(state.netTraffic.days, nt);
    const ne = isRec(raw.netErrors) ? raw.netErrors.days : null;
    if (ne) Object.assign(state.netErrors.days, ne);
    // access requests already reported: without this, every restart would put
    // them back at the top of the timeline as if they had just arrived
    for (const id of Array.isArray(raw.pendingSeen) ? raw.pendingSeen : []) state.pendingSeen.add(id as string);
    if (Array.isArray(raw.events)) state.events.push(...(raw.events.slice(0, EVENT_MAX) as NetEvent[]));
    // service checks (missing from old server.js files): same rules as the
    // node ticks, buckets older than 24h have expired
    for (const [name, sv] of Object.entries(isRec(raw.services) ? raw.services : {})) {
      if (!isRec(sv)) continue;
      state.services.set(name, {
        beats: (Array.isArray(sv.beats) ? sv.beats : []).filter(
          (b): b is ServiceHistory['beats'][number] => isRec(b) && (b.t as number) >= cutoff,
        ),
        downSince: typeof sv.downSince === 'number' ? sv.downSince : null,
      });
    }
  }

  serialize(now: number = Date.now()): HistoryFile {
    const { state } = this;
    const data: HistoryFile = {
      schemaVersion: SCHEMA_VERSION,
      savedAt: now,
      history: {},
      events: state.events,
      netTraffic: { days: state.netTraffic.days },
      netErrors: { days: state.netErrors.days },
      pendingSeen: [...state.pendingSeen],
      services: Object.fromEntries(state.services),
    };
    for (const [id, h] of state.history) data.history[id] = h;
    return data;
  }

  save(): void {
    if (!this.canPersist) return;
    try {
      // atomic write: if the container dies halfway, the good file stays the old
      // one instead of becoming a truncated, unreadable JSON
      const tmp = `${this.file}.tmp`;
      fs.writeFileSync(tmp, JSON.stringify(this.serialize()));
      fs.renameSync(tmp, this.file);
    } catch (err) {
      this.logger.error('saving history failed:', (err as Error).message || err);
      this.canPersist = false; // don't retry on every round, flooding the logs
    }
  }
}
