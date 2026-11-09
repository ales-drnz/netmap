<script lang="ts">
  // Devices (DESIGN-v2 "Devices"): header, filters, then the table (the map is the Home);
  // /devices/[id] renders INTO this layout as the side panel, so the list (and
  // its filters) stays visible, compressed to name / status / latency.
  // Mobile (<768px): the detail is a full page (the list is hidden behind it).
  //
  // URL is the state: ?q= search · ?s= all|direct|relay|off · ?g= person|status|none
  // Defaults are omitted. Every device link keeps the query. The old ?view=map
  // (v2 bookmarks) goes to the Home map, keeping the open device as ?d=.
  //
  // Keys (not while typing): j/k move between rows (with the panel open they
  // also switch the open device), Enter opens (native link), c copies the IP of
  // the focused row (or of the open device). `/` and Esc are handled by the shell.
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { page } from '$app/state';
  import { tick, untrack } from 'svelte';
  import Button from '$lib/components/Button.svelte';
  import DevicesTable, { type Grouping } from '$lib/components/DevicesTable.svelte';
  import EmptyState from '$lib/components/EmptyState.svelte';
  import SearchInput from '$lib/components/SearchInput.svelte';
  import Segmented from '$lib/components/Segmented.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { type Device, type Status, toDevice } from '$lib/model';
  import { ui } from '$lib/ui.svelte';

  let { children } = $props();

  type StatusFilter = 'all' | Status;

  const sp = $derived(page.url.searchParams);
  $effect(() => {
    if (sp.get('view') !== 'map') return;
    const id = page.params.id;
    goto(`${base}/${id ? `?d=${encodeURIComponent(id)}` : ''}`, { replaceState: true });
  });
  const s = $derived<StatusFilter>(((v) => (v === 'direct' || v === 'relay' || v === 'off' ? v : 'all'))(sp.get('s')));
  const g = $derived<Grouping>(((v) => (v === 'status' || v === 'none' ? v : 'person'))(sp.get('g')));
  const openId = $derived(page.params.id ?? null);

  // ---- URL state
  const DEFAULTS: Record<string, string> = { q: '', s: 'all', g: 'person' };
  function setParams(patch: Record<string, string>, push = false) {
    const url = new URL(page.url);
    for (const [k, v] of Object.entries(patch)) {
      if (v === DEFAULTS[k] || v === '') url.searchParams.delete(k);
      else url.searchParams.set(k, v);
    }
    if (url.search === page.url.search) return;
    goto(url, { replaceState: !push, keepFocus: true, noScroll: true });
  }

  // the search box is local state mirrored to ?q= (debounced); an external
  // change of the URL (back button, a link from the palette) flows back in
  let q = $state(page.url.searchParams.get('q') ?? '');
  let written = page.url.searchParams.get('q') ?? '';
  let qTimer: ReturnType<typeof setTimeout> | null = null;
  function onSearch(v: string) {
    if (qTimer) clearTimeout(qTimer);
    qTimer = setTimeout(() => {
      written = v.trim();
      setParams({ q: written });
    }, 160);
  }
  $effect(() => {
    const uq = sp.get('q') ?? '';
    if (uq !== written) {
      written = uq;
      untrack(() => (q = uq));
    }
  });

  // ---- data + filters
  const hubDevice = $derived(live.hub ? toDevice(live.hub, live.receivedAt || Date.now()) : null);
  const needle = $derived(q.trim().toLowerCase());
  const textMatch = (d: Device) =>
    !needle ||
    [d.name, d.ip, d.ownerLabel, d.id, ...d.node.ips, ...d.node.labels.map((l) => l.name)].some((x) =>
      x?.toLowerCase().includes(needle),
    );
  const statusMatch = (d: Device) => s === 'all' || d.status === s;
  const matches = (d: Device) => textMatch(d) && statusMatch(d);

  const textHits = $derived(live.devices.filter(textMatch));
  const shown = $derived(textHits.filter(statusMatch));
  const hubShown = $derived(hubDevice && matches(hubDevice) ? hubDevice : null);
  const counts = $derived({
    all: textHits.length,
    direct: textHits.filter((d) => d.status === 'direct').length,
    relay: textHits.filter((d) => d.status === 'relay').length,
    off: textHits.filter((d) => d.status === 'off').length,
  });
  const filtered = $derived(!!needle || s !== 'all');

  // ---- links
  const href = (id: string) => `${base}/devices/${encodeURIComponent(id)}${page.url.search}`;
  const open = (d: Device) => goto(href(d.id), { noScroll: true, keepFocus: openId != null });

  // ---- focus: panel title on open, the row again on close
  let prevId: string | null = null;
  let switching = false;
  $effect(() => {
    const id = openId;
    const was = prevId;
    prevId = id;
    if (id && !was) tick().then(() => document.getElementById('detail-title')?.focus({ preventScroll: true }));
    else if (id && was && id !== was && !switching) tick().then(() => document.getElementById('detail-title')?.focus({ preventScroll: true }));
    else if (!id && was) tick().then(() => rowLink(was)?.focus({ preventScroll: false }));
    switching = false;
  });

  const rowLink = (id: string) =>
    document.querySelector<HTMLElement>(`tr[data-id="${CSS.escape(id)}"] [data-row-link]`);

  // ---- keyboard: j/k/c on the table
  function onkey(e: KeyboardEvent) {
    if (e.defaultPrevented || ui.palette || e.ctrlKey || e.metaKey || e.altKey) return;
    if ((e.target as HTMLElement).closest('input, textarea, select, [contenteditable="true"]')) return;
    // Esc closes the panel. The shell does it too, but it skips whenever any
    // [aria-expanded=true] exists, and our open group headers are exactly that.
    // preventDefault keeps the two from both navigating.
    if (e.key === 'Escape') {
      if (openId && !document.querySelector('.menu, .pal')) {
        e.preventDefault();
        goto(`${base}/devices${page.url.search}`, { keepFocus: true, noScroll: true });
      }
      return;
    }
    const k = e.key;
    if (k !== 'j' && k !== 'k' && k !== 'c') return;
    const links = [...document.querySelectorAll<HTMLElement>('[data-row-link]')];
    const focusedRow = (document.activeElement as HTMLElement | null)?.closest<HTMLElement>('tr[data-id]');
    const curId = focusedRow?.dataset.id ?? openId;
    if (k === 'c') {
      const dev = curId ? (curId === hubDevice?.id ? hubDevice : live.devices.find((d) => d.id === curId)) : null;
      if (dev?.ip) {
        e.preventDefault();
        ui.copy(dev.ip);
      }
      return;
    }
    if (!links.length) return;
    e.preventDefault();
    const i = curId ? links.findIndex((a) => a.closest<HTMLElement>('tr')?.dataset.id === curId) : -1;
    const next = links[i < 0 ? 0 : Math.min(links.length - 1, Math.max(0, i + (k === 'j' ? 1 : -1)))];
    if (!next) return;
    next.focus();
    next.closest('tr')?.scrollIntoView({ block: 'nearest' });
    // with the panel open, moving also switches the device shown
    const nid = next.closest<HTMLElement>('tr')?.dataset.id;
    if (openId && nid && nid !== openId) {
      switching = true;
      goto(href(nid), { replaceState: true, keepFocus: true, noScroll: true });
    }
  }

  // search: Enter opens the first match, ↓ moves into the table
  function searchKey(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      const first = document.querySelector<HTMLAnchorElement>('[data-row-link]');
      if (first) {
        e.preventDefault();
        first.click();
      }
    } else if (e.key === 'ArrowDown') {
      const first = document.querySelector<HTMLElement>('[data-row-link]');
      if (first) {
        e.preventDefault();
        first.focus();
      }
    }
  }

  function clearFilters() {
    q = '';
    written = '';
    setParams({ q: '', s: 'all' });
  }
</script>

<svelte:window onkeydown={onkey} />

<div class="dv" class:open={!!openId}>
  <div class="dv-main">
    <div class="page-h dv-h">
      <h1>{t('nav.devices')} <span class="dv-count num">{live.snap ? live.devices.length : ''}</span></h1>
      <div class="act">
        <Button variant="ghost" href="{base}/{openId ? `?d=${encodeURIComponent(openId)}` : ''}" icon="i-map">{t('dev.viewMap')}</Button>
      </div>
    </div>

    <div class="dv-f" role="search" aria-label={t('dev.filtersAria')}>
      <SearchInput
        bind:value={q}
        page
        label={t('dev.searchAria')}
        placeholder={t('dev.searchPh')}
        width="clamp(200px, 26vw, 300px)"
        oninput={onSearch}
        onkeydown={searchKey}
      />
      <Segmented
        label={t('common.filterByStatus')}
        value={s}
        onchange={(v) => setParams({ s: v })}
        options={[
          { value: 'all', label: t('common.all'), count: counts.all },
          { value: 'direct', label: t('filter.direct'), count: counts.direct, marker: 'direct-wan' },
          { value: 'relay', label: t('filter.relay'), count: counts.relay, marker: 'relay' },
          { value: 'off', label: t('filter.off'), count: counts.off, marker: 'offline' },
        ]}
      />
      <div class="dv-group">
          <span class="t-caption text-3" aria-hidden="true">{t('dev.groupBy')}</span>
          <Segmented
            label={t('dev.groupBy')}
            size="sm"
            value={g}
            onchange={(v) => setParams({ g: v })}
            options={[
              { value: 'person', label: t('dev.groupPerson') },
              { value: 'status', label: t('dev.groupStatus') },
              { value: 'none', label: t('dev.groupNone') },
            ]}
          />
        </div>
    </div>

    <DevicesTable
        devices={shown}
        all={live.devices}
        hub={hubShown}
        group={g}
        me={live.myOwner}
        meDevice={live.myDevice?.id ?? null}
        selected={openId}
        compact={!!openId}
        searching={!!needle}
        loading={!live.snap}
        now={live.now}
        {href}
        onopen={open}
      >
        {#snippet empty()}
          <EmptyState icon="i-search" title={t('dev.noMatch')} text={filtered ? t('dev.noMatchText') : undefined}>
            {#snippet action()}
              {#if filtered}<Button size="sm" onclick={clearFilters}>{t('dev.clearFilters')}</Button>{/if}
            {/snippet}
          </EmptyState>
        {/snippet}
      </DevicesTable>
  </div>

  {#if openId}
    <aside class="dv-panel" aria-label={t('detail.title')}>
      {@render children()}
    </aside>
  {:else}
    {@render children()}
  {/if}
</div>

<style>
  .dv-h h1 {
    display: flex;
    align-items: baseline;
    gap: 10px;
  }
  .dv-count {
    color: var(--text-3);
    font-weight: 400;
    font-size: 22px;
  }
  .dv-h {
    margin-bottom: 16px;
    align-items: center;
  }
  .dv-f {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 12px 16px;
    margin-bottom: 16px;
  }
  .dv-group {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-left: auto;
  }

  /* side panel: docked to the right edge, under the top bar */
  .dv-panel {
    position: fixed;
    z-index: 20;
    top: var(--topbar-h);
    right: 16px;
    bottom: 16px;
    width: 440px;
    border-radius: var(--r-xl);
    overflow-y: auto;
    overscroll-behavior: contain;
    background: var(--tray);
    box-shadow: var(--sh-overlay);
    animation: panel-in var(--d-slow) var(--ease);
  }
  @keyframes panel-in {
    from {
      opacity: 0;
      transform: translateX(16px);
    }
  }
  /* the list makes room for the panel (minus what the centred page already leaves free) */
  .dv.open .dv-main {
    padding-right: max(0px, calc(440px + 40px - var(--page-x) - max(0px, (100vw - var(--page-max)) / 2)));
  }
  .dv.open .dv-group {
    display: none;
  }

  @media (max-width: 767px) {
    .dv-f {
      gap: 8px;
    }
    .dv-f :global(.search) {
      width: 100% !important;
    }
    .dv-group {
      margin-left: 0;
    }
    /* the detail is a full page: hide the list behind it */
    .dv.open .dv-main {
      display: none;
    }
    .dv-panel {
      position: static;
      width: auto;
      border-radius: 0;
      overflow: visible;
      background: none;
      border: 0;
      box-shadow: none;
      animation: none;
    }
  }
</style>
