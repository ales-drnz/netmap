<script lang="ts">
  // Activity: what changed + who waits for authorization.
  // - period: the server keeps the latest N events (EVENT_MAX), so the page
  //   states how many and since when instead of pretending "7 days"
  // - filter chips with counts, persisted in ?f= (off | path | spike | join)
  // - "Waiting for authorization" only when someone waits (approve in ZTNET)
  // - timeline grouped by day; netdrop = one expandable row; "still offline" tag
  // - new events while scrolled down don't shift the page: a "N new events ↑"
  //   chip shows them on click (the list is pinned to the newest event seen)
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { untrack } from 'svelte';
  import { countBy, groupByDay, stillOffline } from '$lib/charts/activity';
  import CopyText from '$lib/components/CopyText.svelte';
  import EmptyState from '$lib/components/EmptyState.svelte';
  import EventList from '$lib/components/EventList.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import Section from '$lib/components/Section.svelte';
  import Segmented from '$lib/components/Segmented.svelte';
  import Skeleton from '$lib/components/Skeleton.svelte';
  import { i18n, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { dayLabel, duration, EVENT_META } from '$lib/model';

  type F = 'all' | 'off' | 'path' | 'spike' | 'join';
  const FILTERS: F[] = ['all', 'off', 'path', 'spike', 'join'];
  const fromUrl = (): F => {
    const f = page.url.searchParams.get('f');
    return FILTERS.includes(f as F) ? (f as F) : 'all';
  };
  let filter = $state<F>(fromUrl());
  // back/forward or a link to ?f=join while on the page
  $effect(() => {
    filter = fromUrl();
  });
  function setFilter(f: F) {
    const u = new URL(page.url);
    if (f === 'all') u.searchParams.delete('f');
    else u.searchParams.set('f', f);
    goto(u, { replaceState: true, keepFocus: true, noScroll: true });
  }

  // ---- pinning: while scrolled down, newer events wait behind the chip
  let pin = $state<number | null>(null);
  let scrollY = $state(0);
  const newest = $derived(live.events.reduce((m, e) => Math.max(m, e.t), 0));
  // pin when NEW events arrive while the reader is scrolled down (read the live
  // window.scrollY: it's what the reader sees right now)
  let lastNewest = 0;
  $effect(() => {
    const n = newest;
    untrack(() => {
      if (pin == null && lastNewest && n > lastNewest && window.scrollY > 160) pin = lastNewest;
      lastNewest = n;
    });
  });
  // back at the top: everything shows
  $effect(() => {
    if (scrollY <= 160) untrack(() => (pin = null));
  });
  const visible = $derived(pin == null ? live.events : live.events.filter((e) => e.t <= (pin ?? 0)));
  const fresh = $derived(pin == null ? 0 : live.events.filter((e) => e.t > (pin ?? 0)).length);
  function showNew() {
    pin = null;
    // an instant jump: a smooth scroll would re-pin the list on its way up
    window.scrollTo(0, 0);
  }

  const filterOf = (e: { kind: keyof typeof EVENT_META }) => EVENT_META[e.kind].filter;
  const counts = $derived(countBy(visible, filterOf));
  const shown = $derived(filter === 'all' ? visible : visible.filter((e) => filterOf(e) === filter));
  const days = $derived(groupByDay(shown));
  const still = $derived(stillOffline(live.events, live.nodes));
  const oldest = $derived(live.events.length ? Math.min(...live.events.map((e) => e.t)) : null);
  const since = (tm: number) =>
    new Date(tm).toLocaleString(i18n.locale, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });

  const LABEL: Record<F, 'common.all' | 'act.fOff' | 'act.fPath' | 'act.fSpike' | 'act.fJoin'> = {
    all: 'common.all',
    off: 'act.fOff',
    path: 'act.fPath',
    spike: 'act.fSpike',
    join: 'act.fJoin',
  };
  const options = $derived(
    FILTERS.map((f) => ({ value: f, label: t(LABEL[f]), count: f === 'all' ? visible.length : (counts.get(f) ?? 0) })),
  );
  const pending = $derived(live.pending.slice().sort((a, b) => (b.waitingSec ?? 0) - (a.waitingSec ?? 0)));
</script>

<svelte:window bind:scrollY />

<div class="act-page">
<header class="page-h">
  <div class="title">
    <h1>{t('nav.activity')}</h1>
    <p class="t-caption">
      {#if oldest != null}{t('act.period', { count: live.events.length, since: since(oldest) })}{:else}{t('act.periodNone')}{/if}
    </p>
  </div>
</header>

<div class="filters">
  <Segmented label={t('act.filterAria')} value={filter} onchange={setFilter} {options} />
</div>

{#if fresh > 0}
  <button type="button" class="fresh" onclick={showNew}>
    <Icon name="i-up" size={14} />{t('act.newEvents', { count: fresh })}
  </button>
{/if}

<div class="stack">
  {#if pending.length && (filter === 'all' || filter === 'join')}
    <Section title={t('act.waitingAuth')} note={t('act.waitingNote')}>
      <ul class="rows">
        {#each pending as p (p.id)}
          <li class="row pend">
            <span class="ic"><Icon name="i-key" size={16} /></span>
            <span class="pend-n">
              <span class="t-label ellipsis">{p.name ?? p.id}</span>
              <span class="t-caption text-3">{p.deauthorized ? t('act.revoked') : t('act.first')}</span>
            </span>
            <span class="pend-id"><CopyText text={p.id} /></span>
            <span class="num text-2 pend-w">{p.waitingSec != null ? t('act.waitingFor', { d: duration(p.waitingSec) }) : '—'}</span>
          </li>
        {/each}
      </ul>
    </Section>
  {/if}

  {#if !live.snap}
    <Skeleton height={240} radius={12} />
  {:else if !days.length}
    <div class="section-b">
      <EmptyState icon="i-activity" title={filter === 'all' ? t('act.emptyTitle') : t('act.emptyFilter')} text={filter === 'all' ? t('act.empty') : t('act.emptyFilterText')} />
    </div>
  {:else}
    {#each days as d (d.key)}
      <Section title={dayLabel(d.t, live.now)} note={t('act.events', { count: d.events.length })}>
        <EventList events={d.events} stillOff={still} />
      </Section>
    {/each}
  {/if}
</div>
</div>

<style>
  .act-page {
    max-width: 960px;
  }
  .title {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .title p {
    color: var(--text-3);
  }
  .filters {
    margin: -8px 0 24px;
    max-width: 100%;
    overflow-x: auto;
  }
  .fresh {
    position: fixed;
    z-index: 20;
    top: calc(var(--topbar-h) + 12px);
    left: 50%;
    transform: translateX(-50%);
    display: inline-flex;
    align-items: center;
    gap: 6px;
    height: 32px;
    padding: 0 14px;
    border: 0;
    border-radius: var(--r-full);
    background: var(--surface);
    box-shadow: var(--sh-pop);
    color: var(--text);
    font: inherit;
    font-weight: 500;
    cursor: pointer;
    animation: fresh-in var(--d-base) var(--ease);
  }
  .fresh:hover {
    background: var(--fill);
  }
  @keyframes fresh-in {
    from {
      opacity: 0;
      transform: translate(-50%, -6px);
    }
  }
  .pend {
    display: grid;
    grid-template-columns: 16px minmax(0, 1fr) max-content 150px;
    gap: 12px;
    padding-top: 8px;
    padding-bottom: 8px;
  }
  .pend .ic {
    display: inline-flex;
    color: var(--text-3);
  }
  .pend-n {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .pend-w {
    text-align: right;
  }
  /* ids are short: show them whole (CopyText caps itself at 100% minus its negative margins) */
  .pend-id :global(.copytext) {
    max-width: none;
  }
  @media (max-width: 767px) {
    .pend {
      grid-template-columns: 16px minmax(0, 1fr) auto;
    }
    .pend-id {
      grid-column: 2 / -1;
      grid-row: 2;
    }
  }
</style>
