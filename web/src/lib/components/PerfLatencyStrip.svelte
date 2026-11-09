<script lang="ts">
  // Latency strip: one row per online DIRECT device, fastest first.
  //   x = log 1–500 ms (ticks 1/3/10/30/100/300), dot = median of the recent
  //   samples, segment = p10–p90 of the same samples; LAN = filled dot,
  //   internet = hollow dot; your devices in bold; dashed red line at SPIKE_MS.
  // Relayed devices have no direct latency: listed separately under the chart.
  import { base } from '$app/paths';
  import { LAT_DOMAIN, LAT_TICKS, latencyStrip, SPIKE_MS, type StripRow } from '$lib/charts/perf';
  import { log } from '$lib/charts/scale';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import ChartFrame from './ChartFrame.svelte';
  import ChartTip from './ChartTip.svelte';
  import EmptyState from './EmptyState.svelte';

  const mine = (d: { owner: string }) => !!live.myOwner && d.owner === live.myOwner;
  const rows = $derived(latencyStrip(live.devices, mine));
  const relayed = $derived(live.relay.slice().sort((a, b) => a.name.localeCompare(b.name)));

  const ROW = 22;
  const TOP = 22; // top axis labels
  const BOT = 22; // bottom axis labels
  const height = $derived(TOP + rows.length * ROW + BOT);
  let hover = $state<StripRow | null>(null);
  let hy = $state(0);
  const fmt = (v: number) => (v < 10 ? String(Math.round(v * 10) / 10) : String(Math.round(v)));
</script>

{#if !rows.length}
  <EmptyState icon="i-activity" title={t('perf.stripEmpty')} text={t('perf.stripEmptyText')} />
{:else}
  <div class="legend chart-legend">
    <span><svg width="10" height="10" aria-hidden="true"><circle cx="5" cy="5" r="4" fill="var(--series)" /></svg>{t('perf.lan')}</span>
    <span
      ><svg width="10" height="10" aria-hidden="true"><circle cx="5" cy="5" r="3.5" fill="var(--surface)" stroke="var(--series)" stroke-width="1.5" /></svg
      >{t('perf.wan')}</span
    >
    <span><svg width="18" height="10" aria-hidden="true"><line x1="2" x2="16" y1="5" y2="5" stroke="var(--series-3)" stroke-width="4" stroke-linecap="round" /></svg>{t('perf.p10p90')}</span>
    <span><svg width="18" height="10" aria-hidden="true"><line class="ref-spike" x1="9" x2="9" y1="0" y2="10" stroke="var(--err)" stroke-dasharray="3 2" /></svg>{t('perf.spikeLine', { ms: SPIKE_MS })}</span>
  </div>
  <div class="pad">
  <ChartFrame minWidth={300}>
    {#snippet children(w)}
      {@const narrow = w < 560}
      {@const L = narrow ? 100 : 168}
      {@const R = narrow ? 48 : 52}
      {@const x = log(LAT_DOMAIN, [L, w - R])}
      <svg
        class="chart"
        width={w}
        {height}
        role="img"
        aria-label={t('perf.stripAria', { n: rows.length })}
        onpointerleave={() => (hover = null)}
      >
        {#each LAT_TICKS as tk (tk)}
          <line class="gl" x1={x(tk)} x2={x(tk)} y1={TOP - 4} y2={height - BOT + 4} />
          {#if !narrow || [1, 10, 100].includes(tk)}
            <!-- narrow: label only the decades so neighbours never collide -->
            <text x={x(tk)} y={12} text-anchor="middle">{tk}</text>
            <text x={x(tk)} y={height - 6} text-anchor="middle">{tk}{tk === (narrow ? 100 : 300) ? ' ms' : ''}</text>
          {/if}
        {/each}
        <line class="ref-spike" x1={x(SPIKE_MS)} x2={x(SPIKE_MS)} y1={TOP - 4} y2={height - BOT + 4} />
        {#if !narrow}<text class="ref-label" x={x(SPIKE_MS) + 4} y={12}>{SPIKE_MS}</text>{/if}
        {#each rows as r, i (r.id)}
          {@const cy = TOP + i * ROW + ROW / 2}
          <g
            class="row"
            class:on={hover?.id === r.id}
            role="presentation"
            onpointerenter={() => {
              hover = r;
              hy = cy;
            }}
          >
            <rect class="band" x="0" y={cy - ROW / 2} width={w} height={ROW} />
            <a href="{base}/devices/{r.id}">
              <text class="name" class:mine={r.mine} x={L - 12} y={cy + 4} text-anchor="end">{r.name.length > (narrow ? 13 : 22) ? `${r.name.slice(0, narrow ? 12 : 21)}…` : r.name}</text>
            </a>
            <line x1={x(r.p10)} x2={Math.max(x(r.p90), x(r.p10) + 0.5)} y1={cy} y2={cy} stroke="var(--series-3)" stroke-width="4" stroke-linecap="round" />
            {#if r.lan}
              <circle cx={x(r.median)} cy={cy} r="4.5" fill="var(--series)" stroke="var(--surface)" stroke-width="1.5" />
            {:else}
              <circle cx={x(r.median)} cy={cy} r="4" fill="var(--surface)" stroke="var(--series)" stroke-width="1.75" />
            {/if}
            <text class="val" x={w - 4} y={cy + 4} text-anchor="end">{fmt(r.median)} ms</text>
          </g>
        {/each}
      </svg>
      {#if hover}
        <ChartTip x={x(hover.median)} y={hy - 6} maxX={w}>
          <b>{hover.name}</b>
          <div><span class="k">{t('perf.tipMedian')}</span><span>{fmt(hover.median)} ms</span></div>
          <div><span class="k">p10–p90</span><span>{fmt(hover.p10)}–{fmt(hover.p90)} ms</span></div>
          <div><span class="k">{t('perf.tipPath')}</span><span>{hover.lan ? t('perf.lan') : t('perf.wan')}</span></div>
          <div><span class="k">{t('perf.tipSamples')}</span><span>{hover.samples}</span></div>
        </ChartTip>
      {/if}
    {/snippet}
  </ChartFrame>
  </div>
{/if}
{#if relayed.length}
  <p class="relayed t-caption">
    <span class="text-3">{t('perf.noDirect', { n: relayed.length })}</span>
    {#each relayed as d, i (d.id)}<a class="link" href="{base}/devices/{d.id}">{d.name}</a>{i < relayed.length - 1 ? ', ' : ''}{/each}
  </p>
{/if}

<style>
  .legend {
    padding: 12px 16px 4px;
  }
  .row .band {
    fill: transparent;
  }
  .row.on .band {
    fill: var(--fill);
  }
  .name {
    font-size: 12px;
    font-weight: 400;
    fill: var(--text-2);
  }
  .name.mine {
    font-weight: 600;
    fill: var(--text);
  }
  a:hover .name {
    text-decoration: underline;
  }
  .val {
    font-size: 12px;
    font-weight: 400;
    fill: var(--text);
  }
  .relayed {
    padding: 10px 16px 12px;
    border-top: 1px solid var(--line);
    color: var(--text-2);
  }
  .relayed .link {
    font-weight: 400;
  }
  .pad {
    padding: 4px 16px 8px;
  }
</style>
