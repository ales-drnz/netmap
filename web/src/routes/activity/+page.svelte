<script lang="ts">
  import { page } from '$app/state';
  import Alerts from '$lib/components/Alerts.svelte';
  import EventList from '$lib/components/EventList.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { dayLabel, duration, EVENT_META } from '$lib/model';

  const TILES = [
    { f: 'off', icon: 'i-down', tone: 'off', label: 'act.off' },
    { f: 'path', icon: 'i-relay', tone: 'relay', label: 'act.path' },
    { f: 'spike', icon: 'i-bolt', tone: 'spike', label: 'act.spike' },
    { f: 'join', icon: 'i-key', tone: 'join', label: 'act.join' },
  ] as const;

  let filter = $state<string | null>(page.url.searchParams.get('f'));
  const count = (f: string) => live.events.filter((e) => EVENT_META[e.kind].filter === f).length;
  const shown = $derived(filter ? live.events.filter((e) => EVENT_META[e.kind].filter === filter) : live.events);
  const days = $derived.by(() => {
    const m = new Map<string, typeof shown>();
    for (const e of shown) {
      const k = dayLabel(e.t, live.now);
      m.set(k, [...(m.get(k) ?? []), e]);
    }
    return [...m.entries()];
  });
</script>

<div class="pagehead">
  <div>
    <h1>{t('nav.activity')}</h1>
    <p>{t('act.intro')}</p>
  </div>
</div>

<Alerts />

<div class="evsum">
  {#each TILES as tile (tile.f)}
    <button class="evtile" aria-pressed={filter === tile.f} onclick={() => (filter = filter === tile.f ? null : tile.f)}>
      <span class="evico {tile.tone}"><Icon name={tile.icon} size={15} /></span>
      <div><b>{count(tile.f)}</b><span>{t(tile.label)}</span></div>
    </button>
  {/each}
</div>

{#if live.pending.length && (!filter || filter === 'join')}
  <div class="card">
    <div class="card-h"><h2>{t('act.waiting')}</h2><span class="note">{t('act.waitingNote')}</span></div>
    <div class="rows">
      {#each live.pending as p (p.id)}
        <div class="row" style="cursor:default">
          <span class="evico join"><Icon name="i-key" size={15} /></span>
          <div style="min-width:0">
            <div class="name">{p.name ?? p.id}</div>
            <div class="meta">{p.deauthorized ? t('act.revoked') : t('act.first')} · <span class="mono">{p.id}</span></div>
          </div>
          <div class="mono t2">{t('act.waitingFor', { d: duration(p.waitingSec, true) })}</div>
        </div>
      {/each}
    </div>
  </div>
{/if}

{#each days as [label, evs] (label)}
  <div class="card">
    <div class="card-h"><h2>{label}</h2><span class="note">{t('act.events', { count: evs.length })}</span></div>
    <EventList events={evs} />
  </div>
{:else}
  <div class="card" style="padding:40px;text-align:center;color:var(--text-3)">
    {filter ? t('act.emptyFilter') : t('act.empty')}
  </div>
{/each}
