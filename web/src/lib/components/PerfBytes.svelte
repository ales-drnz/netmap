<script lang="ts">
  // Network bytes, 30 days (the hub's real byte counters, UDP + TCP), then a
  // SEPARATE small chart of the TCP share (one axis per chart, never dual):
  // traffic over TCP gave up on the direct path, so > 1 % is a health signal.
  //   - daily bars, rounded ticks in the best decimal unit (usually GB)
  //   - today is partial: lighter bar + "in progress"
  //   - days before metrics were counting: hatched (no data ≠ zero)
  //   - hovering a day highlights it in both charts
  // Packet errors (by type) follow, only when there are any.
  import { byteDays, TCP_THRESHOLD } from '$lib/charts/perf';
  import { byteUnit, linear, niceTicks } from '$lib/charts/scale';
  import { i18n, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { bytes, num, pct } from '$lib/model';
  import ChartFrame from './ChartFrame.svelte';
  import ChartTip from './ChartTip.svelte';
  import EmptyState from './EmptyState.svelte';

  const h = $derived(live.snap?.health ?? null);
  const days = $derived(h?.bytes ? byteDays(h.bytes.days, live.now) : []);
  const max = $derived(Math.max(1, ...days.filter((d) => !d.missing).map((d) => d.total)));
  const unit = $derived(byteUnit(max));
  const ticks = $derived(niceTicks(max / unit.div, 4));
  const errors = $derived((h?.errors ?? []).filter((e) => e.count > 0).sort((a, b) => b.count - a.count));
  const totals = $derived(h?.bytes ? { all: h.bytes.udp + h.bytes.tcp, tcp: h.bytes.tcp } : null);

  const BH = 180;
  const B = { t: 12, b: 24, l: 44, r: 8 };
  const SH = 92;
  const S = { t: 10, b: 22 };
  const SMAX = 0.05;
  const sTicks = [0, 0.01, 0.05];
  let hover = $state<number | null>(null);
  const hd = $derived(hover != null ? (days[hover] ?? null) : null);

  const dateOf = (tm: number) => new Date(tm).toLocaleDateString(i18n.locale, { weekday: 'short', day: 'numeric', month: 'short' });
  const short = (tm: number) => new Date(tm).toLocaleDateString(i18n.locale, { day: 'numeric', month: 'short' });
  const tickLabel = (v: number) => (v === 0 ? '0' : `${num(v, v < 1 ? 1 : 0)}`);
  const b = (v: number) => {
    const x = bytes(v);
    return `${x.v} ${x.unit}`;
  };
  function move(e: PointerEvent, w: number) {
    const r = (e.currentTarget as SVGElement).getBoundingClientRect();
    const i = Math.floor(((e.clientX - r.left - B.l) / (w - B.l - B.r)) * days.length);
    hover = i >= 0 && i < days.length ? i : null;
  }
</script>

{#if !h?.bytes}
  <EmptyState icon="i-chart" title={t('perf.metricsOff')} text={t('perf.metricsOffText')} />
{:else}
  <div class="sum">
    {#if totals}
      <span class="t-num-l">{bytes(totals.all).v}</span><span class="text-3">{bytes(totals.all).unit} · {t('perf.in30')}</span>
      <span class="text-2">· TCP {pct(totals.tcp / Math.max(1, totals.all), 2)}</span>
    {/if}
    <span class="chart-legend legend">
      <span><i class="sw" style:background="var(--series-2)"></i>{t('perf.dayTotal')}</span>
      <span><i class="sw" style:background="var(--series-3)"></i>{t('perf.inProgress')}</span>
      <span><i class="sw hatch"></i>{t('track.noData')}</span>
    </span>
  </div>
  <div class="pad">
    <ChartFrame minWidth={300}>
      {#snippet children(w)}
        {@const n = Math.max(1, days.length)}
        {@const bw = (w - B.l - B.r) / n}
        {@const y = linear([0, ticks.at(-1) ?? 1], [BH - B.b, B.t])}
        {@const bx = (i: number) => B.l + i * bw + Math.max(1, (bw - Math.min(24, bw - 2)) / 2)}
        {@const barW = Math.max(2, Math.min(24, bw - 2))}
        <svg class="chart" width={w} height={BH} role="img" aria-label={t('perf.bytesAria')} onpointermove={(e) => move(e, w)} onpointerleave={() => (hover = null)}>
          <defs>
            <pattern id="bytes-hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
              <line x1="0" y1="0" x2="0" y2="6" stroke="var(--line-strong)" stroke-width="1.5" />
            </pattern>
          </defs>
          {#each ticks as tk (tk)}
            <line class={tk === 0 ? 'baseline' : 'gl'} x1={B.l} x2={w - B.r} y1={y(tk)} y2={y(tk)} />
            <text x={B.l - 8} y={y(tk) + 4} text-anchor="end">{tickLabel(tk)}{tk === ticks.at(-1) ? ` ${unit.unit}` : ''}</text>
          {/each}
          {#each days as d, i (d.t)}
            {#if d.missing}
              <rect x={bx(i)} y={B.t} width={barW} height={BH - B.b - B.t} fill="url(#bytes-hatch)" opacity="0.7" />
            {:else if d.total > 0}
              {@const top = y(d.total / unit.div)}
              {@const r = Math.min(4, barW / 2, BH - B.b - top)}
              <path
                d="M{bx(i)} {BH - B.b}V{top + r}a{r} {r} 0 0 1 {r} {-r}h{barW - 2 * r}a{r} {r} 0 0 1 {r} {r}V{BH - B.b}Z"
                fill={hover === i ? 'var(--series)' : d.partial ? 'var(--series-3)' : 'var(--series-2)'}
              />
            {/if}
          {/each}
          {#each days as d, i (d.t)}
            {#if (days.length - 1 - i) % 7 === 0}
              <text x={bx(i) + barW / 2} y={BH - 6} text-anchor={i === days.length - 1 ? 'end' : 'middle'}>{d.partial ? t('time.today') : short(d.t)}</text>
            {/if}
          {/each}
        </svg>
        {#if hover != null && hd}
          {@const d = hd}
          <ChartTip x={bx(hover) + barW / 2} y={d.missing ? B.t : y(d.total / unit.div)} maxX={w}>
            <b>{dateOf(d.t)}{d.partial ? ` · ${t('perf.inProgress')}` : ''}</b>
            {#if d.missing}
              <div><span class="k">{t('track.noData')}</span></div>
            {:else}
              <div><span class="k">{t('perf.total')}</span><span>{b(d.total)}</span></div>
              <div><span class="k">UDP</span><span>{b(d.udp)}</span></div>
              <div><span class="k">TCP</span><span>{b(d.tcp)} · {d.tcpShare == null ? '—' : pct(d.tcpShare, 2)}</span></div>
            {/if}
          </ChartTip>
        {/if}
      {/snippet}
    </ChartFrame>
  </div>

  <div class="tcp-h">
    <h4 class="t-label">{t('perf.tcpShare')}</h4>
    <span class="t-caption text-3">{t('perf.tcpShareNote', { pct: pct(TCP_THRESHOLD, 0) })}</span>
  </div>
  <div class="pad">
    <ChartFrame minWidth={300}>
      {#snippet children(w)}
        {@const n = Math.max(1, days.length)}
        {@const bw = (w - B.l - B.r) / n}
        {@const y = linear([0, SMAX], [SH - S.b, S.t])}
        {@const barW = Math.max(2, Math.min(24, bw - 2))}
        {@const bx = (i: number) => B.l + i * bw + Math.max(1, (bw - barW) / 2)}
        <svg class="chart" width={w} height={SH} role="img" aria-label={t('perf.tcpAria')} onpointermove={(e) => move(e, w)} onpointerleave={() => (hover = null)}>
          {#each sTicks as tk (tk)}
            <line class={tk === 0 ? 'baseline' : 'gl'} x1={B.l} x2={w - B.r} y1={y(tk)} y2={y(tk)} />
            <text x={B.l - 8} y={y(tk) + 4} text-anchor="end">{tk === 0 ? '0' : `${num(tk * 100)}%`}</text>
          {/each}
          <line class="thr" x1={B.l} x2={w - B.r} y1={y(TCP_THRESHOLD)} y2={y(TCP_THRESHOLD)} />
          {#each days as d, i (d.t)}
            {#if d.missing || d.tcpShare == null}
              <!-- no data: nothing drawn (a gap, not a zero) -->
            {:else}
              {@const v = Math.min(SMAX, d.tcpShare)}
              {@const top = Math.min(y(v), SH - S.b - 1)}
              <rect x={bx(i)} y={top} width={barW} height={SH - S.b - top} rx="1.5" fill={d.tcpShare > TCP_THRESHOLD ? 'var(--relay)' : hover === i ? 'var(--series)' : 'var(--series-2)'} />
              {#if d.tcpShare > SMAX}<path d="M{bx(i) + barW / 2} {S.t - 8}l-4 6h8Z" fill="var(--relay)" />{/if}
            {/if}
          {/each}
          {#if hover != null}
            <rect x={B.l + hover * bw} y={S.t - 2} width={bw} height={SH - S.b - S.t + 2} fill="none" stroke="var(--line-strong)" rx="2" />
          {/if}
        </svg>
        {#if hover != null && hd}
          {@const d = hd}
          <ChartTip x={bx(hover) + barW / 2} y={S.t} maxX={w}>
            <b>{dateOf(d.t)}</b>
            <div><span class="k">{t('perf.tcpShare')}</span><span>{d.tcpShare == null || d.missing ? t('track.noData') : pct(d.tcpShare, 2)}</span></div>
          </ChartTip>
        {/if}
      {/snippet}
    </ChartFrame>
  </div>

  {#if errors.length}
    <div class="err-h">
      <h4 class="t-label">{t('stats.errors')}</h4>
      <span class="t-caption text-3">{t('stats.errorsNote')}</span>
    </div>
    <ul class="rows errs">
      {#each errors as e (e.type)}
        <li class="row"><span class="mono">{e.type}</span><span class="num">{e.count}</span></li>
      {/each}
    </ul>
  {/if}
{/if}

<style>
  .sum {
    display: flex;
    align-items: baseline;
    flex-wrap: wrap;
    gap: 4px 8px;
    padding: 14px 16px 4px;
  }
  .legend {
    margin-left: auto;
  }
  .hatch {
    background: repeating-linear-gradient(45deg, var(--line-strong) 0 1.5px, transparent 1.5px 4px);
  }
  .pad {
    padding: 8px 16px 8px;
  }
  .tcp-h,
  .err-h {
    display: flex;
    align-items: baseline;
    flex-wrap: wrap;
    gap: 4px 10px;
    padding: 12px 16px 0;
    border-top: 1px solid var(--line);
  }
  .thr {
    stroke: var(--relay);
    stroke-width: 1;
    stroke-dasharray: 4 3;
  }
  .errs {
    margin-top: 6px;
    border-top: 1px solid var(--line);
  }
  .errs .row {
    justify-content: space-between;
  }
</style>
