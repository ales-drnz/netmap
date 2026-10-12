<script lang="ts">
  import Cells from '$lib/components/Cells.svelte';
  import DevTile from '$lib/components/DevTile.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { avg, bytes, jitter, median, networkLatencySeries, num, packets, pct, quantile } from '$lib/model';
  import { ui } from '$lib/ui.svelte';

  // ---------- network latency ----------
  const series = $derived(networkLatencySeries(live.devices));
  const vals = $derived(series.filter((v): v is number => v != null));
  const allSamples = $derived(live.direct.flatMap((d) => (d.node.spark ?? []).filter((v): v is number => v != null)));
  const now = $derived(vals.at(-1) ?? null);
  const jit = $derived(jitter(series));
  const LW = 760;
  const LH = 230;
  const LP = { l: 34, r: 8, t: 10, b: 26 };
  const lmax = $derived(Math.max(20, Math.ceil((Math.max(0, ...vals) * 1.15) / 20) * 20));
  const lx = (i: number) => LP.l + (i * (LW - LP.l - LP.r)) / Math.max(1, series.length - 1);
  const ly = (v: number) => LP.t + (1 - v / lmax) * (LH - LP.t - LP.b);
  const ticks = $derived(Array.from({ length: 5 }, (_, i) => (lmax / 4) * i));
  const path = $derived.by(() => {
    let last: number | null = null;
    const pts: string[] = [];
    series.forEach((v, i) => {
      if (v != null) last = v;
      if (last != null) pts.push(`${pts.length ? 'L' : 'M'}${lx(i).toFixed(1)} ${ly(last).toFixed(1)}`);
    });
    return pts.join('');
  });
  const span = $derived(Math.round((series.length * live.pollSeconds) / 60));
  let hover = $state<number | null>(null);
  let latEl: SVGSVGElement | undefined = $state();
  function latMove(e: PointerEvent) {
    if (!latEl || series.length < 2) return;
    const r = latEl.getBoundingClientRect();
    const x = ((e.clientX - r.left) * LW) / r.width;
    let i = Math.round(((x - LP.l) / (LW - LP.l - LP.r)) * (series.length - 1));
    i = Math.max(0, Math.min(series.length - 1, i));
    while (i > 0 && series[i] == null) i--;
    hover = series[i] == null ? null : i;
  }

  // ---------- distribution ----------
  const BIN = 10;
  const bins = $derived.by(() => {
    const b = new Array(12).fill(0) as number[];
    for (const v of allSamples) {
      const k = Math.min(11, Math.floor(v / BIN));
      b[k] = (b[k] ?? 0) + 1;
    }
    return b;
  });
  const bmax = $derived(Math.max(1, ...bins));
  const medBin = $derived.by(() => {
    const m = median(allSamples);
    return m == null ? -1 : Math.min(11, Math.floor(m / BIN));
  });

  // ---------- traffic ----------
  const traffic = $derived(live.snap?.health?.bytes ?? null);
  const TW = 760;
  const TH = 220;
  const TP = { l: 34, r: 6, t: 10, b: 26 };
  const tdays = $derived(traffic?.days ?? []);
  const tmax = $derived(Math.max(1, ...tdays.map((d) => d.udp + d.tcp)));
  const tby = (v: number) => TH - TP.b - (v / tmax) * (TH - TP.t - TP.b);
  const tbw = $derived((TW - TP.l - TP.r) / Math.max(1, tdays.length));
  // any day where TCP exceeds 1% gave up on the direct path
  const tcpHigh = (d: { udp: number; tcp: number }) => d.udp + d.tcp > 0 && d.tcp / (d.udp + d.tcp) > 0.01;
  let thover = $state<number | null>(null);

  const top = $derived(
    live.devices
      .filter((d) => d.node.traffic && d.node.traffic.packets > 0)
      .sort((a, b) => (b.node.traffic?.packets ?? 0) - (a.node.traffic?.packets ?? 0))
      .slice(0, 6),
  );
  const pmax = $derived(top[0]?.node.traffic?.packets ?? 1);
  const errors = $derived(live.snap?.health?.errors ?? null);
  const dayAgo = (i: number) => {
    const back = tdays.length - 1 - i;
    return back === 0 ? t('time.today') : back === 1 ? t('time.yesterday') : t('time.daysAgo', { n: back });
  };
</script>

<div class="pagehead">
  <div>
    <h1>{t('nav.stats')}</h1>
    <p>{t('stats.intro')}</p>
  </div>
</div>

<div class="grid">
  <div class="card s8">
    <div class="card-h"><h2>{t('stats.latency')}</h2><span class="note">{t('stats.latencyNote', { n: span })}</span></div>
    <div class="card-b">
      <div class="bigstat">
        <b>{hover != null ? Math.round(series[hover] ?? 0) : now != null ? Math.round(now) : '—'}</b>
        <small>{hover != null ? t('stats.msAgo', { n: Math.round(((series.length - 1 - hover) * live.pollSeconds) / 60) }) : t('stats.msNow')}</small>
        {#if live.latP95 != null}<span class="pill neutral" style="margin-left:8px">p95 {live.latP95} ms</span>{/if}
        {#if jit != null}<span class="pill neutral">jitter {num(jit, 1)} ms</span>{/if}
      </div>
      {#if vals.length > 1}
        <div class="chartwrap" style="margin-top:18px">
          <svg bind:this={latEl} class="chart" viewBox="0 0 {LW} {LH}" role="img" aria-label={t('stats.latencyAria')} onpointermove={latMove} onpointerleave={() => (hover = null)}>
            <defs><linearGradient id="la" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="var(--text)" stop-opacity=".10" /><stop offset="1" stop-color="var(--text)" stop-opacity="0" /></linearGradient></defs>
            {#each ticks as t (t)}
              <line class="gl" x1={LP.l} x2={LW - LP.r} y1={ly(t)} y2={ly(t)} /><text x={LP.l - 8} y={ly(t) + 4} text-anchor="end">{Math.round(t)}</text>
            {/each}
            <path d="{path}L{lx(series.length - 1)} {LH - LP.b}L{LP.l} {LH - LP.b}Z" fill="url(#la)" />
            <path d={path} fill="none" stroke="var(--text)" stroke-width="1.6" stroke-linejoin="round" />
            {#if hover != null && series[hover] != null}
              <line x1={lx(hover)} x2={lx(hover)} y1={LP.t} y2={LH - LP.b} stroke="var(--text-3)" stroke-dasharray="3 3" />
              <circle cx={lx(hover)} cy={ly(series[hover] ?? 0)} r="4.5" fill="var(--surface)" stroke="var(--text)" stroke-width="2" />
            {/if}
            <text x={LP.l} y={LH - 6}>{t('time.minAgo', { n: span })}</text><text x={LW - LP.r} y={LH - 6} text-anchor="end">{t('time.nowShort')}</text>
          </svg>
        </div>
      {:else}
        <p class="muted">{t('stats.needTwo')}</p>
      {/if}
    </div>
  </div>

  <div class="card s4">
    <div class="card-h"><h2>{t('stats.distribution')}</h2><span class="note">{t('stats.recentSamples')}</span></div>
    <div class="card-b" style="display:flex;flex-direction:column;gap:18px;flex:1">
      <div class="hist">{#each bins as v, i (i)}<i class:med={i === medBin} style="height:{(v / bmax) * 100}%" title={t('stats.binTitle', { range: `${i * BIN}${i === 11 ? '+' : `–${i * BIN + BIN}`}`, n: v })}></i>{/each}</div>
      <div class="axis" style="margin-top:-10px"><span>0</span><span>60</span><span>120+ ms</span></div>
      <div class="minis">
        <div class="tile"><span>{t('stats.median')}</span><b>{median(allSamples) != null ? Math.round(median(allSamples) ?? 0) : '—'} <small>ms</small></b></div>
        <div class="tile"><span>{t('stats.mean')}</span><b>{avg(allSamples) != null ? Math.round(avg(allSamples) ?? 0) : '—'} <small>ms</small></b></div>
        <div class="tile"><span>{t('stats.p95')}</span><b>{quantile(allSamples, 0.95) ?? '—'} <small>ms</small></b></div>
        <div class="tile"><span>{t('stats.min')}</span><b>{allSamples.length ? Math.min(...allSamples) : '—'} <small>ms</small></b></div>
        <div class="tile"><span>{t('stats.max')}</span><b>{allSamples.length ? Math.max(...allSamples) : '—'} <small>ms</small></b></div>
        <div class="tile"><span>Jitter</span><b>{jit != null ? num(jit, 1) : '—'} <small>ms</small></b></div>
      </div>
    </div>
  </div>

  <div class="card s7">
    <div class="card-h">
      <h2>{t('stats.traffic')}</h2><span class="note">{t('stats.trafficNote')}</span>
      <span style="margin-left:auto;display:flex;gap:12px;font-size:12px;color:var(--text-3)">
        <span class="legend-chip"><i style="width:10px;height:10px;border-radius:3px;background:var(--bar)"></i>{t('stats.total')}</span>
        <span class="legend-chip"><i style="width:10px;height:10px;border-radius:3px;background:var(--accent)"></i>{t('stats.tcpOver')}</span>
      </span>
    </div>
    <div class="card-b">
      {#if traffic}
        {@const tot = bytes(traffic.udp + traffic.tcp)}
        <div class="bigstat" style="margin-bottom:14px">
          <b style="font-size:30px">{thover != null ? bytes((tdays[thover]?.udp ?? 0) + (tdays[thover]?.tcp ?? 0)).v : tot.v}</b>
          <small>{thover != null ? `${bytes((tdays[thover]?.udp ?? 0) + (tdays[thover]?.tcp ?? 0)).unit}, ${dayAgo(thover)}` : t('stats.in30', { unit: tot.unit, pct: pct(traffic.tcp / Math.max(1, traffic.udp + traffic.tcp), 2) })}</small>
        </div>
        <svg class="chart" viewBox="0 0 {TW} {TH}" role="img" aria-label={t('stats.trafficAria')}>
          {#each [0, 0.25, 0.5, 0.75, 1] as f (f)}
            {@const b = bytes(tmax * f)}
            <line class="gl" x1={TP.l} x2={TW - TP.r} y1={tby(tmax * f)} y2={tby(tmax * f)} /><text x={TP.l - 6} y={tby(tmax * f) + 4} text-anchor="end">{f === 0 ? 0 : b.v}</text>
          {/each}
          {#each tdays as d, i (i)}
            {@const x = TP.l + i * tbw + 3}
            {@const w = Math.max(2, tbw - 6)}
            {@const y = tby(d.udp + d.tcp)}
            {@const r = Math.min(5, w / 2, TH - TP.b - y)}
            <path
              role="presentation"
              d="M{x} {TH - TP.b}V{y + r}a{r} {r} 0 0 1 {r}-{r}h{w - 2 * r}a{r} {r} 0 0 1 {r} {r}V{TH - TP.b}Z"
              fill={tcpHigh(d) ? 'var(--accent)' : i === tdays.length - 1 ? 'var(--bar-strong)' : 'var(--bar)'}
              opacity={thover == null || thover === i ? 1 : 0.6}
              onpointerenter={() => (thover = i)}
              onpointerleave={() => (thover = null)}
            />
          {/each}
          <text x={TP.l} y={TH - 6}>{t('time.daysAgo', { n: 30 })}</text><text x={TW - TP.r} y={TH - 6} text-anchor="end">{t('time.today')}</text>
        </svg>
      {:else}
        <p class="t2" style="margin:0;max-width:60ch">
          {t('stats.metricsOffA')} <span class="mono">{'{ "settings": { "enableMetrics": true } }'}</span>
          {t('stats.metricsOffB')}
          <span class="mono">local.conf</span>.
        </p>
      {/if}
    </div>
  </div>

  <div class="card s5">
    <div class="card-h"><h2>{t('stats.top')}</h2><span class="note">{t('stats.topNote')}</span></div>
    <div style="padding-bottom:12px">
      {#each top as d, i (d.id)}
        <div class="rank" role="button" tabindex="0" style="cursor:pointer" onclick={() => (ui.drawer = d.id)} onkeydown={(e) => e.key === 'Enter' && (ui.drawer = d.id)}>
          <span class="no">{i + 1}</span><DevTile {d} />
          <div style="min-width:0"><span class="nm">{d.name}</span><div class="bar"><i style="width:{((d.node.traffic?.packets ?? 0) / pmax) * 100}%"></i></div></div>
          <span class="v">{packets(d.node.traffic?.packets ?? 0)}</span>
        </div>
      {:else}
        <p class="muted" style="margin:4px 22px">{live.snap?.metrics ? t('stats.topEmpty') : t('stats.needMetrics')}</p>
      {/each}
      <p class="muted" style="margin:6px 22px 0;font-size:12.5px">{t('stats.packetsNote')}</p>
    </div>
  </div>

  <div class="card s12">
    <div class="card-h">
      <h2>{t('stats.reliability')}</h2><span class="note">{t('stats.reliabilityNote')}</span>
      <div class="heatlegend" style="margin-left:auto">
        <span><i style="background:var(--online)"></i>{t('cells.k')}</span>
        <span><i style="background:color-mix(in srgb, var(--online) 45%, var(--sunken))"></i>{t('cells.partial')}</span>
        <span><i style="background:var(--sunken)"></i>{t('cells.o')}</span>
        <span><i style="background:var(--grid);box-shadow:inset 0 0 0 1px var(--border)"></i>{t('cells.n')}</span>
      </div>
    </div>
    <div class="card-b">
      <div class="heat">
        {#each live.devices as d (d.id)}
          <div class="nm"><span class="dot {d.status}"></span>{d.name}</div>
          <Cells cells={d.hours} />
          <div class="pc">{pct(d.node.uptime)}</div>
        {/each}
        <div></div>
        <div class="axis" style="margin-top:2px"><span>{t('time.hAgo', { n: 24 })}</span><span>{t('time.hAgo', { n: 12 })}</span><span>{t('time.nowShort')}</span></div>
        <div></div>
      </div>
    </div>
  </div>

  {#if errors?.length}
    <div class="card s12">
      <div class="card-h"><h2>{t('stats.errors')}</h2><span class="note">{t('stats.errorsNote')}</span></div>
      <div class="checks">
        {#each errors as e (e.type)}<div class="check"><span class="ci n"><span class="mono" style="font-size:11px">{e.count}</span></span><div><span>{t('stats.type')}</span><b class="mono">{e.type}</b></div></div>{/each}
      </div>
    </div>
  {/if}
</div>
