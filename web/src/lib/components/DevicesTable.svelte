<script lang="ts" module>
  export type Grouping = 'person' | 'status' | 'none';

  /** numeric compare of "1.14.2"-style versions (missing parts = 0) */
  export function cmpVersion(a: string, b: string): number {
    const pa = a.split(/[.-]/).map((x) => Number.parseInt(x, 10) || 0);
    const pb = b.split(/[.-]/).map((x) => Number.parseInt(x, 10) || 0);
    for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
      const d = (pa[i] ?? 0) - (pb[i] ?? 0);
      if (d) return d;
    }
    return 0;
  }
</script>

<script lang="ts">
  // The devices table (DESIGN-v2 "Devices"): real <table> semantics, sticky
  // header, one <tbody> per group with a collapsible header row.
  //   group 'person': "you" first, then people with 2+ active devices (A→Z),
  //                   then "People with one device" (owner shown in the row)
  //   group 'status': one-way → direct → relay → offline
  //   group 'none'  : one flat list
  // Always: hub row tagged "hub" on top, devices offline > 7 days in a last
  // group (open, foldable). Order inside a group is by name ONLY (stable across polls:
  // a row never jumps because its latency changed).
  // compact: the detail panel is open → only name / status / latency.
  // Each row's name is a link (Tab / Enter); the page adds j/k/c on top
  // through [data-row-link] and tr[data-id].
  import { SvelteSet } from 'svelte/reactivity';
  import { t } from '$lib/i18n/index.svelte';
  import { type Device, type StatusKind, timeAgo } from '$lib/model';
  import AvailabilityTrack from './AvailabilityTrack.svelte';
  import CopyButton from './CopyButton.svelte';
  import CopyText from './CopyText.svelte';
  import EmptyState from './EmptyState.svelte';
  import Icon from './Icon.svelte';
  import Skeleton from './Skeleton.svelte';
  import StatusMarker from './StatusMarker.svelte';
  import StatusBadge from './StatusBadge.svelte';

  let {
    devices,
    all,
    hub = null,
    group = 'person',
    me = null,
    meDevice = null,
    selected = null,
    compact = false,
    searching = false,
    loading = false,
    now,
    href,
    onopen,
    empty,
  }: {
    /** the devices to show (already filtered), hub excluded */
    devices: Device[];
    /** every device (unfiltered): decides who has one or several devices */
    all: Device[];
    /** the hub, when it matches the filters */
    hub?: Device | null;
    group?: Grouping;
    /** the viewer's person key */
    me?: string | null;
    /** id of the device the viewer is using */
    meDevice?: string | null;
    selected?: string | null;
    compact?: boolean;
    /** a text filter is active: the inactive group opens so matches aren't hidden */
    searching?: boolean;
    loading?: boolean;
    now: number;
    href: (id: string) => string;
    onopen: (d: Device) => void;
    /** shown when nothing matches (e.g. an EmptyState with "Clear filters") */
    empty?: import('svelte').Snippet;
  } = $props();

  interface Group {
    key: string;
    label: string;
    you?: boolean;
    /** "2/3 online" or a count */
    note?: string;
    markers?: StatusKind[];
    /** no header row (the hub / the flat list) */
    bare?: boolean;
    showOwner: boolean;
    rows: Device[];
  }

  const byName = (a: Device, b: Device) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' });

  const groups = $derived.by((): Group[] => {
    const active = devices.filter((d) => d.active);
    const inactive = devices.filter((d) => !d.active).sort(byName);
    const out: Group[] = [];
    const hubRow: Group | null = hub ? { key: 'hub', label: '', bare: true, showOwner: false, rows: [hub] } : null;

    if (group === 'person') {
      if (hubRow) out.push(hubRow);
      // who has several active devices: decided on the unfiltered list
      const owned = new Map<string, Device[]>();
      for (const d of all) {
        if (!d.active) continue;
        const l = owned.get(d.owner) ?? [];
        l.push(d);
        owned.set(d.owner, l);
      }
      const shown = new Map<string, Device[]>();
      for (const d of active) {
        const l = shown.get(d.owner) ?? [];
        l.push(d);
        shown.set(d.owner, l);
      }
      const singles: Device[] = [];
      const persons: Group[] = [];
      for (const [key, rows] of shown) {
        const full = owned.get(key) ?? rows;
        if (full.length < 2 && key !== me) {
          singles.push(...rows);
          continue;
        }
        const online = full.filter((d) => d.status !== 'off').length;
        persons.push({
          key: `p:${key}`,
          label: rows[0]?.ownerLabel ?? key,
          you: key === me,
          note: t('dev.onlineOf', { online, total: full.length }),
          markers: full.slice().sort(byName).map((d) => d.kind),
          showOwner: false,
          rows: rows.sort(byName),
        });
      }
      persons.sort((a, b) => Number(!!b.you) - Number(!!a.you) || a.label.localeCompare(b.label));
      out.push(...persons);
      if (singles.length) {
        const online = singles.filter((d) => d.status !== 'off').length;
        out.push({
          key: 'singles',
          label: t('dev.groupSingles'),
          note: t('dev.onlineOf', { online, total: singles.length }),
          showOwner: true,
          rows: singles.sort(byName),
        });
      }
    } else if (group === 'status') {
      const buckets: { key: string; label: string; marker: StatusKind; test: (d: Device) => boolean }[] = [
        { key: 's:fault', label: t('dev.groupFault'), marker: 'fault', test: (d) => d.kind === 'fault' },
        { key: 's:direct', label: t('status.direct'), marker: 'direct-wan', test: (d) => d.status === 'direct' && d.kind !== 'fault' },
        { key: 's:relay', label: t('status.relay'), marker: 'relay', test: (d) => d.status === 'relay' },
        { key: 's:off', label: t('dev.groupOffline'), marker: 'offline', test: (d) => d.status === 'off' },
      ];
      const pool = hub ? [hub, ...active] : active;
      for (const b of buckets) {
        const rows = pool.filter(b.test).sort((x, y) => Number(y.node.hub) - Number(x.node.hub) || byName(x, y));
        if (rows.length) out.push({ key: b.key, label: b.label, note: String(rows.length), markers: [b.marker], showOwner: true, rows });
      }
    } else {
      out.push({ key: 'all', label: '', bare: true, showOwner: true, rows: [...(hub ? [hub] : []), ...active.sort(byName)] });
    }

    if (inactive.length) {
      out.push({ key: 'inactive', label: t('dev.groupInactive', { count: inactive.length }), showOwner: true, rows: inactive });
    }
    return out.filter((g) => g.rows.length);
  });

  // collapsed groups: all open at first, the viewer folds what they want
  const closed = new SvelteSet<string>();
  // a search opens the inactive group (so its matches are visible)
  $effect(() => {
    if (searching) closed.delete('inactive');
  });
  // the open device must be visible: open its group
  $effect(() => {
    if (!selected) return;
    const g = groups.find((x) => x.rows.some((d) => d.id === selected));
    if (g && closed.has(g.key)) closed.delete(g.key);
  });
  const toggle = (k: string) => (closed.has(k) ? closed.delete(k) : closed.add(k));

  const newest = $derived(
    all
      .concat(hub ? [hub] : [])
      .map((d) => d.node.version)
      .filter((v): v is string => !!v)
      .sort(cmpVersion)
      .at(-1) ?? null,
  );
  const behind = (v: string | null) => !!v && !!newest && cmpVersion(v, newest) < 0;

  // the whole row opens the device; clicks on the link / copy controls keep their own behaviour
  function rowClick(e: MouseEvent, d: Device) {
    if ((e.target as HTMLElement).closest('a, button')) return;
    if (window.getSelection()?.toString()) return; // the user is selecting text
    onopen(d);
  }

  // the hub measures everyone else: its own "latency" means nothing
  const latency = (d: Device) => (d.median != null && !d.node.hub ? `${d.median} ms` : '—');
  const latencyTitle = (d: Device) =>
    d.node.hub ? undefined : d.status === 'relay' ? t('common.noLatency') : d.median != null ? t('dev.latencyTitle') : undefined;
</script>

<div class="dt" class:compact>
  <table aria-label={t('dev.tableAria')} aria-busy={loading || undefined}>
    <thead>
      <tr>
        <th scope="col" class="c-name">{t('dev.thDevice')}</th>
        <th scope="col" class="c-st">{t('dev.thStatus')}</th>
        <th scope="col" class="c-lat">{t('dev.thLatency')}</th>
        <th scope="col" class="c-ip">IP</th>
        <th scope="col" class="c-24">{t('dev.th24h')}</th>
        <th scope="col" class="c-ver">{t('dev.thClient')}</th>
      </tr>
    </thead>
    {#if loading}
      <tbody>
        {#each { length: 8 } as _, i (i)}
          <tr class="sk-row">
            <td class="c-name"><Skeleton width="60%" height={14} /></td>
            <td class="c-st"><Skeleton width={72} height={20} radius={999} /></td>
            <td class="c-lat"><Skeleton width={40} height={14} /></td>
            <td class="c-ip"><Skeleton width={96} height={14} /></td>
            <td class="c-24"><Skeleton height={14} /></td>
            <td class="c-ver"><Skeleton width={40} height={14} /></td>
          </tr>
        {/each}
      </tbody>
    {:else}
      {#each groups as g (g.key)}
        {@const open = g.bare || !closed.has(g.key)}
        <tbody class:bare={g.bare}>
          {#if !g.bare}
            <tr class="grp">
              <th colspan={compact ? 3 : 6} scope="rowgroup">
                <button type="button" class="grp-b" aria-expanded={open} onclick={() => toggle(g.key)}>
                  <span class="chev" class:open><Icon name="i-chev" size={12} /></span>
                  {#if g.markers?.length === 1 && g.markers[0]}<StatusMarker kind={g.markers[0]} />{/if}
                  <span class="grp-l">{g.label}</span>
                  {#if g.you}<span class="you-tag">{t('common.you')}</span>{/if}
                  {#if g.note}<span class="grp-n">{g.note}</span>{/if}
                  {#if g.markers && g.markers.length > 1}
                    <span class="grp-mk" aria-hidden="true">{#each g.markers as k, i (i)}<StatusMarker kind={k} />{/each}</span>
                  {/if}
                </button>
              </th>
            </tr>
          {/if}
          {#if open}
            {#each g.rows as d (d.id)}
              {@const off = d.status === 'off'}
              <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
              <tr data-id={d.id} class:sel={d.id === selected} class:inactive={!d.active} onclick={(e) => rowClick(e, d)}>
                <td class="c-name">
                  <span class="nm">
                    <span class="ic"><Icon name="i-{d.type}" size={16} /></span>
                    <a class="nm-a" href={href(d.id)} data-row-link aria-current={d.id === selected ? 'true' : undefined}>{d.name}</a>
                    {#if d.id === meDevice}<span class="you-tag">{t('common.you')}</span>{/if}
                    {#if d.node.hub}<span class="tag">{t('dev.hubTag')}</span>{/if}
                    {#if g.showOwner && !d.node.hub && d.ownerLabel.toLowerCase() !== d.name.toLowerCase()}
                      <span class="own">{d.ownerLabel}</span>
                    {/if}
                  </span>
                </td>
                <td class="c-st"><StatusBadge kind={d.kind} detail={off ? timeAgo(d.node.lastSeen, now) : null} /></td>
                <td class="c-lat num" class:none={d.median == null || d.node.hub} title={latencyTitle(d)}>{latency(d)}</td>
                <td class="c-ip">
                  {#if d.ip}
                    <span class="ip-text"><CopyText text={d.ip} /></span>
                    <span class="ip-btn"><CopyButton text={d.ip} variant="ghost" /></span>
                  {:else}<span class="text-4">—</span>{/if}
                </td>
                <td class="c-24">
                  <AvailabilityTrack values={d.node.beats} {now} height={14} label={t('dev.trackAria', { name: d.name })} />
                </td>
                <td class="c-ver num" class:behind={behind(d.node.version)} title={behind(d.node.version) ? t('detail.newest', { v: newest ?? '' }) : undefined}>
                  {d.node.version ?? '—'}
                </td>
              </tr>
            {/each}
          {/if}
        </tbody>
      {/each}
    {/if}
  </table>
  {#if !loading && !groups.length}{@render empty?.()}{/if}
</div>

<style>
  .dt {
    background: var(--surface);
    border-radius: var(--r-lg);
  }
  table {
    width: 100%;
    border-collapse: separate;
    border-spacing: 0;
    table-layout: fixed;
  }
  th,
  td {
    padding: 0 12px;
    text-align: left;
    vertical-align: middle;
    white-space: nowrap;
  }
  th:first-child,
  td:first-child {
    padding-left: 16px;
  }
  th:last-child,
  td:last-child {
    padding-right: 16px;
  }

  /* sticky header: 32px, micro uppercase */
  thead th {
    position: sticky;
    top: var(--topbar-h);
    z-index: 2;
    height: 32px;
    background: var(--surface);
    border-bottom: 0.5px solid var(--line);
    color: var(--text-3);
    font-size: 11px;
    line-height: 16px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  thead th:first-child {
    border-top-left-radius: calc(var(--r-lg) - 1px);
  }
  thead th:last-child {
    border-top-right-radius: calc(var(--r-lg) - 1px);
  }

  /* column widths */
  .c-st {
    width: 184px;
  }
  .c-lat {
    width: 84px;
    text-align: right;
  }
  .c-ip {
    width: 156px;
  }
  .c-24 {
    width: 168px;
  }
  .c-ver {
    width: 92px;
  }

  /* rows */
  tbody tr:not(.grp) {
    height: var(--row-h);
    cursor: pointer;
    transition: background var(--d-fast) var(--ease);
  }
  tbody tr:not(.grp):hover {
    background: var(--fill);
  }
  tbody tr > * {
    border-top: 1px solid var(--line);
  }
  tbody:first-of-type tr:first-child > * {
    border-top: 0;
  }
  tr.sel {
    background: var(--fill);
  }
  tr.sel td:first-child {
    box-shadow: inset 2px 0 0 var(--text);
  }
  tbody:last-of-type tr:last-child td:first-child {
    border-bottom-left-radius: calc(var(--r-lg) - 1px);
  }
  tbody:last-of-type tr:last-child td:last-child {
    border-bottom-right-radius: calc(var(--r-lg) - 1px);
  }

  .nm {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
  }
  .ic {
    display: inline-flex;
    color: var(--text-3);
  }
  .nm-a {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    font-weight: 500;
    border-radius: var(--r-xs);
  }
  .nm-a:hover {
    text-decoration: underline;
    text-underline-offset: 3px;
  }
  .own {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    color: var(--text-3);
  }
  tr.inactive .nm-a {
    color: var(--text-2);
    font-weight: 400;
  }
  .c-lat {
    font-variant-numeric: tabular-nums;
  }
  .c-lat.none {
    color: var(--text-4);
  }
  .c-ver {
    color: var(--text-2);
  }
  .c-ver.behind {
    color: var(--text-3);
  }
  .ip-btn {
    display: none;
  }
  .c-24 :global(.track-wrap) {
    width: 144px;
  }

  /* group header rows: 32px, collapsible */
  tr.grp th {
    height: 32px;
    padding: 0;
    background: var(--surface-2);
    font-weight: 400;
    text-transform: none;
  }
  .grp-b {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    height: 32px;
    padding: 0 16px 0 12px;
    border: 0;
    background: none;
    color: var(--text-2);
    text-align: left;
  }
  .grp-b:hover {
    color: var(--text);
  }
  .grp-b:focus-visible {
    outline-offset: -2px;
  }
  .grp-l {
    color: var(--text);
    font-weight: 500;
  }
  .grp-n {
    color: var(--text-3);
    font-size: 12px;
    font-variant-numeric: tabular-nums;
  }
  .grp-mk {
    display: inline-flex;
    flex-wrap: wrap;
    gap: 3px;
    margin-left: 4px;
  }
  .chev {
    display: inline-flex;
    color: var(--text-3);
    transition: transform var(--d-fast) var(--ease);
  }
  .chev.open {
    transform: rotate(90deg);
  }
  tbody.bare + tbody tr.grp th,
  tbody:not(.bare) tr.grp th {
    border-top: 1px solid var(--line);
  }
  tbody:first-of-type tr.grp th {
    border-top: 0;
  }

  .sk-row td {
    height: var(--row-h);
  }

  /* compact: the detail panel is open → name / status / latency */
  .compact .c-ip,
  .compact .c-24,
  .compact .c-ver {
    display: none;
  }
  .compact th:nth-child(3),
  .compact td.c-lat {
    padding-right: 16px;
  }
  .compact .c-st {
    width: 136px;
  }
  .compact :global(.badge-detail) {
    display: none;
  }

  /* medium widths: drop the least important columns first */
  @media (max-width: 1180px) {
    .c-24 {
      width: 120px;
    }
    .c-24 :global(.track-wrap) {
      width: 96px;
    }
    .c-ver {
      display: none;
    }
  }
  @media (max-width: 980px) {
    .c-24 {
      display: none;
    }
  }

  /* mobile: 56px rows as a grid (name · badge · latency · 44px copy target) */
  @media (max-width: 767px) {
    table,
    tbody {
      display: block;
    }
    thead {
      display: none;
    }
    tbody tr:not(.grp) {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto 52px 44px;
      align-items: center;
      height: 56px;
    }
    tr.grp {
      display: block;
    }
    tr.grp th {
      display: block;
    }
    tbody tr > * {
      display: flex;
      align-items: center;
      height: 100%;
      padding: 0 6px;
      border-top: 0;
    }
    tbody tr:not(.grp) {
      border-top: 1px solid var(--line);
    }
    tbody:first-of-type tr:first-child {
      border-top: 0;
    }
    tbody tr > :first-child {
      padding-left: 16px;
    }
    td.c-lat {
      justify-content: flex-end;
    }
    td.c-ip {
      padding: 0;
      justify-content: center;
    }
    .c-24,
    .c-ver,
    .ip-text {
      display: none !important;
    }
    .ip-btn {
      display: inline-flex;
    }
    .ip-btn :global(.btn) {
      width: 44px;
      height: 44px;
    }
    td :global(.badge-detail) {
      display: none;
    }
    .nm {
      flex-wrap: wrap;
      row-gap: 0;
    }
    .own {
      flex-basis: 100%;
      padding-left: 24px;
      font-size: 12px;
      line-height: 16px;
    }
    .c-st,
    .c-lat,
    .c-ip {
      width: auto;
    }
    tr.sel td:first-child {
      box-shadow: none;
    }
    tr.sel {
      box-shadow: inset 2px 0 0 var(--text);
    }
  }
</style>
