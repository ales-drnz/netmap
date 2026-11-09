<script lang="ts">
  // "Worse than last week": a dumbbell per device, hollow = previous-week
  // median, filled = recent median (latency30), sorted by how much worse.
  // Only devices with a previous week AND enough samples (perf.ts:
  // MIN_TREND_SAMPLES, WORSE_RATIO); your devices pinned first.
  import { base } from '$app/paths';
  import { MIN_TREND_SAMPLES, type TrendRow, worseThanLastWeek } from '$lib/charts/perf';
  import { linear, niceTicks } from '$lib/charts/scale';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import ChartFrame from './ChartFrame.svelte';
  import ChartTip from './ChartTip.svelte';
  import EmptyState from './EmptyState.svelte';

  const mine = (d: { owner: string }) => !!live.myOwner && d.owner === live.myOwner;
  const data = $derived(worseThanLastWeek(live.devices, mine));
  const rows = $derived(data.rows);
  const ticks = $derived(niceTicks(Math.max(1, ...rows.map((r) => Math.max(r.median, r.prev))), 4));

  const ROW = 26;
  const TOP = 8;
  const BOT = 22;
  const height = $derived(TOP + rows.length * ROW + BOT);
  let hover = $state<TrendRow | null>(null);
  let hy = $state(0);
  const pctUp = (r: TrendRow) => `+${Math.round((r.trend - 1) * 100)}%`;
</script>

{#if !data.candidates}
  <EmptyState icon="i-chart" title={t('perf.worseNoData')} text={t('perf.worseNoDataText', { n: MIN_TREND_SAMPLES })} />
{:else if !rows.length}
  <EmptyState icon="i-check" title={t('perf.worseNone')} text={t('perf.worseNoneText', { n: data.candidates })} />
{:else}
  <div class="legend chart-legend">
    <span><svg width="10" height="10" aria-hidden="true"><circle cx="5" cy="5" r="3.5" fill="var(--surface)" stroke="var(--series-2)" stroke-width="1.5" /></svg>{t('perf.prevWeek')}</span>
    <span><svg width="10" height="10" aria-hidden="true"><circle cx="5" cy="5" r="4" fill="var(--series)" /></svg>{t('perf.recent')}</span>
  </div>
  <div class="pad">
    <ChartFrame minWidth={300}>
      {#snippet children(w)}
        {@const L = w < 480 ? 100 : 150}
        {@const R = w < 480 ? 44 : 52}
        {@const x = linear([0, ticks.at(-1) ?? 1], [L, w - R])}
        <svg class="chart" width={w} {height} role="img" aria-label={t('perf.worseAria', { n: rows.length })} onpointerleave={() => (hover = null)}>
          {#each ticks as tk (tk)}
            <line class="gl" x1={x(tk)} x2={x(tk)} y1={TOP - 4} y2={height - BOT + 4} />
            <text x={x(tk)} y={height - 6} text-anchor="middle">{tk}{tk === ticks.at(-1) ? ' ms' : ''}</text>
          {/each}
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
              <a href="{base}/devices/{r.id}"
                ><text class="name" class:mine={r.mine} x={L - 12} y={cy + 4} text-anchor="end">{r.name.length > 18 ? `${r.name.slice(0, 17)}…` : r.name}</text></a
              >
              <line x1={x(r.prev)} x2={x(r.median)} y1={cy} y2={cy} stroke="var(--series-2)" stroke-width="2" />
              <circle cx={x(r.prev)} {cy} r="4" fill="var(--surface)" stroke="var(--series-2)" stroke-width="1.75" />
              <circle cx={x(r.median)} {cy} r="4.5" fill="var(--series)" stroke="var(--surface)" stroke-width="1.5" />
              <text class="val" x={w - 4} y={cy + 4} text-anchor="end">{pctUp(r)}</text>
            </g>
          {/each}
        </svg>
        {#if hover}
          <ChartTip x={x(hover.median)} y={hy - 6} maxX={w}>
            <b>{hover.name}</b>
            <div><span class="k">{t('perf.recent')}</span><span>{Math.round(hover.median)} ms</span></div>
            <div><span class="k">{t('perf.prevWeek')}</span><span>{Math.round(hover.prev)} ms</span></div>
            <div><span class="k">{t('perf.change')}</span><span>{pctUp(hover)}</span></div>
            <div><span class="k">{t('perf.tipSamples')}</span><span>{hover.samples}</span></div>
          </ChartTip>
        {/if}
      {/snippet}
    </ChartFrame>
  </div>
{/if}

<style>
  .legend {
    padding: 12px 16px 4px;
  }
  .pad {
    padding: 4px 16px 8px;
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
    font-weight: 500;
    fill: var(--text);
  }
</style>
