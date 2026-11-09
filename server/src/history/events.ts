import type { NetEvent, Pending } from '../../../shared/api.js';
import type { SampleNode } from './samples.js';
import { EVENT_MAX, type HistoryState, type NodeState } from './state.js';

export const median = (xs: readonly number[]): number | null => {
  const s = xs.slice().sort((a, b) => a - b);
  return s.length ? (s[s.length >> 1] as number) : null;
};

export function pushEvent(state: HistoryState, ev: NetEvent): void {
  state.events.unshift(ev);
  if (state.events.length > EVENT_MAX) state.events.length = EVENT_MAX;
}

// Who asked to join. Already reported ids are remembered (and saved in the
// history), otherwise on every server restart the same request would jump back
// to the top of the timeline as if it had just arrived.
export function detectPending(state: HistoryState, pending: readonly Pending[], now: number): void {
  const { pendingSeen } = state;
  for (const p of pending) {
    if (pendingSeen.has(p.id)) continue;
    pendingSeen.add(p.id);
    pushEvent(state, {
      t: now,
      id: p.id,
      name: p.name || p.id,
      kind: 'pending',
      detail: p.deauthorized ? 'authorization revoked in the past' : null,
    });
  }
  // once a member is authorized (or deleted) it leaves the pending list: forget
  // it, so a future new request will be news again
  const live = new Set(pending.map((p) => p.id));
  for (const id of [...pendingSeen]) if (!live.has(id)) pendingSeen.delete(id);
}

// compares the poll with the previous one and records state changes
export function detectEvents(state: HistoryState, nodes: readonly SampleNode[], now: number, spikeMs: number): void {
  const { prevStates, spiking } = state;
  const first = prevStates.size === 0;
  const next = new Map<string, NodeState>();
  // Simultaneous drops: if three or more go away in the same poll, it is not
  // three devices having a problem — it is ONE, and it is the network. Logging an
  // event for each would fill the timeline with rows that look like independent
  // failures, hiding the only fact that matters.
  const dropped: SampleNode[] = [];
  for (const n of nodes) {
    const cur: NodeState = !n.online ? 'off' : n.relayed ? 'relay' : 'on';
    next.set(n.id, cur);
    const prev = prevStates.get(n.id);
    if (!first && prev && prev !== cur && cur === 'off') dropped.push(n);
  }
  const grouped = dropped.length >= 3;
  if (grouped) {
    pushEvent(state, {
      t: now,
      id: null,
      name: null,
      kind: 'netdrop',
      count: dropped.length,
      detail:
        dropped
          .slice(0, 6)
          .map((n) => n.name)
          .join(', ') + (dropped.length > 6 ? '…' : ''),
    });
  }

  for (const n of nodes) {
    const cur = next.get(n.id) as NodeState;
    const prev = prevStates.get(n.id);
    // on the first round there is no "before": logging everything would produce
    // a wall of fake events at startup
    if (!first && prev && prev !== cur && !(grouped && cur === 'off')) {
      const kind = cur === 'off' ? 'offline' : prev === 'off' ? 'online' : cur === 'relay' ? 'relay' : 'direct';
      pushEvent(state, { t: now, id: n.id, name: n.name, kind });
    }
    // spike: latency above the threshold AND at least three times the recent
    // median (so a chronically slow node is not a "spike", it is just slow).
    // The event is logged only on the EDGE, i.e. when the node *enters* a spike:
    // otherwise a spike lasting a minute would fill the timeline with identical
    // rows.
    if (n.online && !n.relayed && n.latencyMs != null) {
      const past = (state.history.get(n.id)?.lat || []).filter((v): v is number => v != null);
      const med = median(past.slice(0, -1));
      const isSpike = n.latencyMs > spikeMs && med != null && n.latencyMs > med * 3;
      if (isSpike && !spiking.has(n.id)) {
        pushEvent(state, { t: now, id: n.id, name: n.name, kind: 'spike', detail: `${n.latencyMs} ms` });
      }
      if (isSpike) spiking.add(n.id);
      else spiking.delete(n.id);
    } else {
      spiking.delete(n.id);
    }
  }
  state.prevStates = next;
}
