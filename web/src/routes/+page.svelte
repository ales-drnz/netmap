<script lang="ts">
  import { base } from '$app/paths';
  import Alerts from '$lib/components/Alerts.svelte';
  import DevTile from '$lib/components/DevTile.svelte';
  import EventList from '$lib/components/EventList.svelte';
  import NetGraph from '$lib/components/NetGraph.svelte';
  import Pill from '$lib/components/Pill.svelte';
  import Spark from '$lib/components/Spark.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { bytes, networkLatencySeries, pathLabel, pct, pctValue } from '$lib/model';
  import { ui } from '$lib/ui.svelte';

  const hour = new Date().getHours();
  const greet = $derived(
    t(hour < 6 ? 'home.night' : hour < 13 ? 'home.morning' : hour < 18 ? 'home.afternoon' : 'home.evening'),
  );
  const mine = $derived(live.devices.filter((d) => d.owner === live.myOwner));
  const latSeries = $derived(networkLatencySeries(live.devices));
  const uptimeSeries = $derived(
    Array.from({ length: 60 }, (_, i) => {
      const v = live.online.map((d) => d.node.beats?.[i]).filter((x): x is number => x != null);
      return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null;
    }),
  );
  const bytesToday = $derived(live.snap?.health?.bytes?.days.at(-1) ?? null);
  const bytesSeries = $derived(live.snap?.health?.bytes?.days.map((d) => d.udp + d.tcp) ?? []);
  const summary = $derived.by(() => {
    if (!live.snap) return t('home.loading');
    const off = live.devices.length - live.online.length;
    const base = t('home.summary', { online: live.online.length, total: live.devices.length });
    if (live.relay.length) return t('home.summaryRelay', { base, count: live.relay.length });
    return off ? t('home.summaryEnd', { base }) : t('home.summaryAll', { base });
  });
  const links = $derived(live.snap?.links ?? []);
</script>

<div class="pagehead">
  <div>
    <h1>{greet}{live.myDevice ? `, ${live.myDevice.ownerLabel}` : ''}</h1>
    <p>{summary}</p>
  </div>
  <span class="live"><i></i>{t('common.liveEvery', { s: live.pollSeconds })}</span>
</div>

<Alerts />

<div class="kpistrip">
  <div class="card kpi">
    <span class="eyebrow">Online</span>
    <div class="val">{live.online.length}<small>/ {live.devices.length}</small></div>
    <div class="sub">{t('home.onlineSub', { direct: live.direct.length, relay: live.relay.length })}</div>
    <div class="viz">
      <div class="stack" style="height:10px;margin-top:10px">
        <i style="width:{(live.direct.length / Math.max(1, live.devices.length)) * 100}%;background:var(--online)"></i>
        <i style="width:{(live.relay.length / Math.max(1, live.devices.length)) * 100}%;background:var(--relay)"></i>
        <i style="flex:1;background:var(--sunken)"></i>
      </div>
    </div>
  </div>
  <div class="card kpi">
    <span class="eyebrow">{t('home.avgLatency')}</span>
    <div class="val">{live.latAvg != null ? Math.round(live.latAvg) : '—'}<small>ms</small></div>
    <div class="sub">{t('home.latSub', { m: live.latMedian ?? '—', p: live.latP95 ?? '—' })}</div>
    <div class="viz"><Spark values={latSeries} w={300} h={30} /></div>
  </div>
  <div class="card kpi">
    <span class="eyebrow">{t('home.availability')}</span>
    <div class="val">{live.uptimeAvg != null ? pctValue(live.uptimeAvg) : '—'}<small>%</small></div>
    <div class="sub">{t('home.availSub')}</div>
    <div class="viz"><Spark values={uptimeSeries} w={300} h={30} /></div>
  </div>
  <div class="card kpi">
    <span class="eyebrow">{t('home.trafficToday')}</span>
    {#if bytesToday}
      {@const b = bytes(bytesToday.udp + bytesToday.tcp)}
      <div class="val">{b.v}<small>{b.unit}</small></div>
      <div class="sub">TCP {pct(bytesToday.tcp / Math.max(1, bytesToday.udp + bytesToday.tcp), 2)}</div>
      <div class="viz"><Spark values={bytesSeries} w={300} h={30} /></div>
    {:else}
      <div class="val">—</div>
      <div class="sub">{t('home.metricsOff')}</div>
    {/if}
  </div>
</div>

<div class="grid">
  <div class="card s7" style="overflow:hidden">
    <div class="card-h"><h2>{t('nav.map')}</h2><a class="act" href="{base}/map">{t('home.openArrow')}</a></div>
    <div style="background:var(--stage);flex:1;display:flex;align-items:center;border-radius:0 0 var(--r-md) var(--r-md)">
      <NetGraph people={live.people} hub={live.hub} me={live.myOwner} onselect={(id) => (ui.drawer = id)} />
    </div>
  </div>
  <div class="s5" style="display:flex;flex-direction:column;gap:20px;min-width:0">
    <div class="card">
      <div class="card-h"><h2>{mine.length ? t('home.yourDevices') : t('home.onlineDevices')}</h2><a class="act" href="{base}/me">{t('home.allArrow')}</a></div>
      <div class="rows">
        {#each (mine.length ? mine : live.online.slice(0, 4)) as d (d.id)}
          <div class="row" role="button" tabindex="0" onclick={() => (ui.drawer = d.id)} onkeydown={(e) => e.key === 'Enter' && (ui.drawer = d.id)}>
            <DevTile {d} />
            <div style="min-width:0"><div class="name">{d.name}</div><div class="meta">{pathLabel(d)}</div></div>
            <div class="mono t2">{#if d.ms != null}{d.ms} ms{:else}<Pill status={d.status} />{/if}</div>
          </div>
        {/each}
      </div>
    </div>
    {#if links.length}
      <div class="card">
        <div class="card-h"><h2>{t('nav.services')}</h2><a class="act" href="{base}/services">{t('home.allArrow')}</a></div>
        <div class="rows">
          {#each links as l (l.url)}
            <a class="svc-mini" href={l.url} target="_blank" rel="noopener">
              <span class="svc-logo" style="background:var(--inv-bg);color:var(--inv-text)">{l.name.charAt(0)}</span>
              <div style="flex:1;min-width:0"><b style="font-weight:600">{l.name}</b><div class="muted mono" style="font-size:12px">{l.url.replace(/^https?:\/\//, '')}</div></div>
            </a>
          {/each}
        </div>
      </div>
    {/if}
  </div>
  <div class="card s12">
    <div class="card-h"><h2>{t('home.latestEvents')}</h2><a class="act" href="{base}/activity">{t('home.historyArrow')}</a></div>
    <EventList events={live.events.slice(0, 4)} empty={t('home.noEvents')} />
  </div>
</div>
