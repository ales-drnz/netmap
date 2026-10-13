<script lang="ts">
  import { page } from '$app/state';
  import Cells from '$lib/components/Cells.svelte';
  import DevTile from '$lib/components/DevTile.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import NetGraph from '$lib/components/NetGraph.svelte';
  import Pill from '$lib/components/Pill.svelte';
  import Spark from '$lib/components/Spark.svelte';
  import { type Key, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { type Device, type Status, pathLabel, pct } from '$lib/model';
  import { ui } from '$lib/ui.svelte';

  let q = $state('');
  let filter = $state<'all' | Status>('all');
  let selected = $state<string | null>(page.url.searchParams.get('d'));
  let highlight = $state<string | null>(null);
  let graph: NetGraph | undefined = $state();

  const sel = $derived(selected ? (live.devices.find((d) => d.id === selected) ?? null) : null);
  const visible = $derived.by(() => {
    const s = q.toLowerCase().trim();
    if (!s && filter === 'all') return null;
    return (d: Device) =>
      (filter === 'all' || d.status === filter) && (!s || [d.name, d.ip, d.ownerLabel, d.id].some((x) => x?.toLowerCase().includes(s)));
  });
  const count = (st: Status) => live.devices.filter((d) => d.status === st).length;
  const filters: { f: 'all' | Status; label: Key }[] = [
    { f: 'all', label: 'common.all' },
    { f: 'direct', label: 'filter.direct' },
    { f: 'relay', label: 'filter.relay' },
    { f: 'off', label: 'filter.off' },
  ];
</script>

<div class="pagehead">
  <div>
    <h1>{t('nav.map')}</h1>
    <p>{t('map.intro')}</p>
  </div>
  <span class="live"><i></i>{t('common.live')}</span>
</div>

<div class="card mapcard">
  <div class="mapcanvas">
    <div class="maptools">
      <label class="searchin">
        <Icon name="i-search" size={14} />
        <input bind:value={q} data-page-search placeholder={t('map.filterPh')} aria-label={t('map.filterAria')} />
        <span class="kbd">/</span>
      </label>
      <div class="seg" role="group" aria-label={t('common.filterByStatus')}>
        {#each filters as x (x.f)}
          <button aria-pressed={filter === x.f} onclick={() => (filter = x.f)}>
            {#if x.f !== 'all'}<span class="dot {x.f}"></span>{/if}{t(x.label)}
            {#if x.f !== 'all'}<span class="n">{count(x.f)}</span>{/if}
          </button>
        {/each}
      </div>
    </div>
    <div class="mapdraw">
      <NetGraph
        bind:this={graph}
        people={live.people}
        hub={live.hub}
        me={live.myOwner}
        interactive
        fill
        {selected}
        {highlight}
        {visible}
        onselect={(id) => (selected = id)}
      />
    </div>
    <div class="zoom">
      <button onclick={() => graph?.zoom(1.2)} aria-label={t('map.zoomIn')}>+</button>
      <button onclick={() => graph?.zoom(1 / 1.2)} aria-label={t('map.zoomOut')}>−</button>
      <button onclick={() => graph?.fit()} aria-label={t('map.fit')}><Icon name="i-map" size={15} /></button>
    </div>
  </div>

  <aside class="insp">
    {#if sel}
      <div class="insp-h">
        <button class="iconbtn" onclick={() => (selected = null)} aria-label={t('map.back')}><Icon name="i-x" size={14} /></button>
        <h2>{sel.name}</h2>
      </div>
      <div class="insp-b" style="padding:0 20px 20px;gap:16px">
        <div style="display:flex;gap:12px;align-items:center">
          <DevTile d={sel} />
          <div><div style="font-weight:600">{sel.ownerLabel}</div><div class="muted" style="font-size:12.5px">{pathLabel(sel)}</div></div>
        </div>
        <div class="dstatus">
          <div class="bigstat"><b style="font-size:34px">{sel.ms ?? '—'}</b>{#if sel.ms != null}<small>ms</small>{/if}</div>
          <Pill status={sel.status} />
        </div>
        {#if sel.node.spark?.some((v) => v != null)}<Spark values={sel.node.spark} w={280} h={44} />{/if}
        <div class="dlist">
          <div><span>IP</span><b class="mono">{sel.ip ?? '—'}</b></div>
          <div><span>Client</span><b>{sel.node.version ?? '—'}</b></div>
          <div><span>{t('common.last24h')}</span><b>{pct(sel.node.uptime)}</b></div>
        </div>
        <Cells cells={sel.hours} />
        <div class="dactions" style="margin-top:0">
          {#if sel.ip}<button class="btn primary" onclick={() => sel?.ip && ui.copy(sel.ip)}><Icon name="i-copy" size={14} />{t('common.copyIp')}</button>{/if}
          <button class="btn" onclick={() => (ui.drawer = sel?.id ?? null)}>{t('map.details')}</button>
        </div>
      </div>
    {:else}
      <div class="insp-h">
        <h2>{t('dev.people')}</h2>
        <span class="muted" style="font-size:12.5px;margin-left:auto">{t('map.count', { people: live.people.length, devices: live.devices.length })}</span>
      </div>
      <div class="insp-b">
        {#each live.people as p (p.key)}
          <details class="pp" open={p.key === live.myOwner}>
            <summary onmouseenter={() => (highlight = p.key)} onmouseleave={() => (highlight = null)}>
              <span class="avatar" class:me-av={p.key === live.myOwner}>{p.label.charAt(0)}</span>
              <b>{p.label}{#if p.key === live.myOwner}<em>{t('common.you')}</em>{/if}</b>
              <span class="pdots">{#each p.devices as d (d.id)}<span class="dot {d.status}"></span>{/each}</span>
              <span class="cnt">{p.online}/{p.devices.length}</span>
              <span class="chev"><Icon name="i-chev" size={12} /></span>
            </summary>
            <div class="pdevs">
              {#each p.devices as d (d.id)}
                <div class="pdev" role="button" tabindex="0" onclick={() => (selected = d.id)} onkeydown={(e) => e.key === 'Enter' && (selected = d.id)}>
                  <span class="dot {d.status}"></span><span class="n">{d.name}</span>
                  <span class="ms">{d.ms != null ? `${d.ms} ms` : d.status === 'relay' ? 'relay' : '—'}</span>
                </div>
              {/each}
            </div>
          </details>
        {/each}
      </div>
    {/if}
  </aside>
</div>
