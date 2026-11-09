<script lang="ts">
  // 24 h availability heatmap at the server's NATIVE resolution: 60 buckets of
  // 24 min × the devices active in the window, worst uptime first.
  //   cell = fraction online on the sequential scale (--seq-1..5, seqStep);
  //   null = outlined empty cell (no data), 0 = solid grey (offline all bucket).
  // Top: step area of the expected number of devices online per bucket (sum of
  // fractions; a bucket where nobody has data is a gap) with netdrop markers.
  // Absolute local hour axis, night (22–07) shaded. Devices offline for the
  // whole window collapse into one line.
  import { base } from '$app/paths';
  import { availabilityRows, type HeatRow, onlineCount } from '$lib/charts/perf';
  import { hourTicks, linear, nightBands, niceTicks, stepArea, stepLine } from '$lib/charts/scale';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { hhmm, num, pct } from '$lib/model';
  import { BEAT_MS, seqStep, seriesStart } from '$lib/stats';
  import ChartFrame from './ChartFrame.svelte';
  import ChartTip from './ChartTip.svelte';
  import EmptyState from './EmptyState.svelte';

  const N = 60;
  const mine = (d: { owner: string }) => !!live.myOwner && d.owner === live.myOwner;
  const data = $derived(availabilityRows(live.devices, live.now, mine));
  const rows = $derived(data.rows);
  const counts = $derived(onlineCount([...rows, ...data.allDayOff], N));
  const yTicks = $derived(niceTicks(Math.max(1, rows.length + data.allDayOff.length), 2));
  const start = $derived(seriesStart(N, BEAT_MS, live.now));
  const end = $derived(start + N * BEAT_MS);
  const drops = $derived(live.events.filter((e) => e.kind === 'netdrop' && e.t >= start && e.t < end));
  const ticks = $derived(hourTicks(start, end, [0, 6, 12, 18]));
  const nights = $derived(nightBands(start, end));

  const SUM_TOP = 10;
  const SUM_H = 64;
  const GAP = 14;
  const ROW = 14;
  const AX = 22;
  const gridTop = SUM_TOP + SUM_H + GAP;
  const height = $derived(gridTop + rows.length * ROW + AX);

  let showOff = $state(false);
  let hover = $state<{ i: number; row: HeatRow | null; x: number; y: number } | null>(null);
  let dropHover = $state<{ x: number; t: number; count: number | null; names: string | null } | null>(null);

  const STEP_FILL = ['var(--seq-0)', 'var(--seq-1)', 'var(--seq-2)', 'var(--seq-3)', 'var(--seq-4)', 'var(--seq-5)'];
  const range = (i: number) => `${hhmm(start + i * BEAT_MS)}–${hhmm(Math.min(start + (i + 1) * BEAT_MS, live.now))}`;

  function move(e: PointerEvent, w: number, L: number, R: number) {
    const svg = e.currentTarget as SVGSVGElement;
    const r = svg.getBoundingClientRect();
    const px = e.clientX - r.left;
    const py = e.clientY - r.top;
    const cw = (w - L - R) / N;
    const i = Math.floor((px - L) / cw);
    if (i < 0 || i >= N) return (hover = null);
    const cx = L + (i + 0.5) * cw;
    if (py >= SUM_TOP && py < SUM_TOP + SUM_H) return (hover = { i, row: null, x: cx, y: SUM_TOP });
    const k = Math.floor((py - gridTop) / ROW);
    const row = rows[k];
    if (py >= gridTop && row) return (hover = { i, row, x: cx, y: gridTop + k * ROW });
    hover = null;
  }
  const cut = (s: string, n: number) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);
</script>

{#if !rows.length && !data.allDayOff.length}
  <EmptyState icon="i-chart" title={t('perf.availEmpty')} text={t('perf.availEmptyText')} />
{:else}
  <div class="legend chart-legend" aria-hidden="true">
    <span><i class="sw" style:background="var(--seq-0)"></i>0%</span>
    <span><i class="sw" style:background="var(--seq-1)"></i>&lt;30%</span>
    <span><i class="sw" style:background="var(--seq-2)"></i>30–60%</span>
    <span><i class="sw" style:background="var(--seq-3)"></i>60–90%</span>
    <span><i class="sw" style:background="var(--seq-4)"></i>90–99%</span>
    <span><i class="sw" style:background="var(--seq-5)"></i>≥99.5%</span>
    <span><i class="sw" style:background="var(--fill)"></i>{t('track.noData')}</span>
    <span><i class="sw night-sw"></i>{t('perf.night')}</span>
    <span><svg width="10" height="10"><path d="M5 1 9.4 9H.6Z" fill="var(--err)" /></svg>{t('perf.netdrop')}</span>
  </div>
  <div class="pad">
    <ChartFrame minWidth={300}>
      {#snippet children(w)}
        {@const narrow = w < 640}
        {@const L = narrow ? 92 : 168}
        {@const R = narrow ? 44 : 52}
        {@const gw = w - L - R}
        {@const cw = gw / N}
        {@const gx = (f: number) => L + f * gw}
        {@const y = linear([0, yTicks.at(-1) ?? 1], [SUM_TOP + SUM_H, SUM_TOP])}
        {@const cg = cw >= 5 ? 1 : 0.5}
        <svg
          class="chart"
          width={w}
          {height}
          role="img"
          aria-label={t('perf.availAria', { n: rows.length })}
          onpointermove={(e) => move(e, w, L, R)}
          onpointerleave={() => {
            hover = null;
            dropHover = null;
          }}
        >
          <defs>
            <clipPath id="sum-clip"><rect x={L} y={SUM_TOP - 2} width={gw} height={SUM_H + 4} /></clipPath>
          </defs>
          <!-- night -->
          {#each nights as [a, b] (a)}
            <rect class="night" x={gx(a)} y={SUM_TOP} width={gx(b) - gx(a)} height={height - SUM_TOP - AX + 4} />
          {/each}
          <!-- summary: devices online -->
          {#each yTicks as tk (tk)}
            <line class="gl" x1={L} x2={w - R} y1={y(tk)} y2={y(tk)} />
            <text x={L - 8} y={y(tk) + 4} text-anchor="end">{tk === yTicks.at(-1) && !narrow ? `${tk} ${t('perf.onlineAxis')}` : tk}</text>
          {/each}
          <g clip-path="url(#sum-clip)">
            <path d={stepArea(counts, (i) => L + i * cw, y, y(0))} fill="var(--series)" fill-opacity="0.1" />
            <path d={stepLine(counts, (i) => L + i * cw, y)} fill="none" stroke="var(--series)" stroke-width="1.5" stroke-linejoin="round" />
          </g>
          {#each drops as d (d.t)}
            {@const dx = L + ((d.t - start) / (end - start)) * gw}
            <g
              role="presentation"
              onpointerenter={() => (dropHover = { x: dx, t: d.t, count: d.count ?? null, names: d.detail ?? null })}
              onpointerleave={() => (dropHover = null)}
            >
              <line x1={dx} x2={dx} y1={SUM_TOP + 6} y2={SUM_TOP + SUM_H} stroke="var(--err)" stroke-width="1" stroke-dasharray="2 2" />
              <path d="M{dx} {SUM_TOP + 7}l-5 -8h10Z" fill="var(--err)" stroke="var(--surface)" stroke-width="1" />
              <rect x={dx - 8} y={SUM_TOP - 4} width="16" height={SUM_H + 4} fill="transparent" />
            </g>
          {/each}
          <!-- rows -->
          {#each rows as r, k (r.id)}
            {@const ry = gridTop + k * ROW}
            <a href="{base}/devices/{r.id}"
              ><text class="name" class:mine={r.mine} x={L - 8} y={ry + 10.5} text-anchor="end">{cut(r.name, narrow ? 12 : 22)}</text></a
            >
            {#each r.beats as v, i (i)}
              {@const s = seqStep(v)}
              {@const cx = L + (i + N - r.beats.length) * cw}
              {#if s < 0}
                <rect x={cx + cg / 2 + 0.5} y={ry + 0.5} width={Math.max(0.5, cw - cg - 1)} height={ROW - 3} rx="1.5" fill="none" stroke="var(--line-strong)" stroke-width="1" />
              {:else}
                <rect x={cx + cg / 2} y={ry} width={Math.max(0.5, cw - cg)} height={ROW - 2} rx="1.5" fill={STEP_FILL[s]} />
              {/if}
            {/each}
            <text class="pc" x={w - 4} y={ry + 10.5} text-anchor="end">{r.uptime == null ? '—' : pct(r.uptime)}</text>
          {/each}
          {#if hover}
            <rect
              x={L + hover.i * cw}
              y={hover.row ? hover.y - 1 : SUM_TOP}
              width={cw}
              height={hover.row ? ROW : SUM_H}
              fill="none"
              stroke="var(--text)"
              stroke-width="1.5"
              rx="2"
            />
          {/if}
          <!-- axis -->
          {#each ticks.filter((tk) => gx(tk.f) < w - R - 36 && gx(tk.f) > L + 14) as tk (tk.t)}
            <line class="baseline" x1={gx(tk.f)} x2={gx(tk.f)} y1={height - AX + 2} y2={height - AX + 6} />
            <text x={gx(tk.f)} y={height - 4} text-anchor="middle">{hhmm(tk.t)}</text>
          {/each}
          <text x={w - R} y={height - 4} text-anchor="end">{t('time.nowShort')}</text>
        </svg>
        {#if dropHover}
          <ChartTip x={dropHover.x} y={SUM_TOP} maxX={w}>
            <b>{dropHover.count != null ? t('ev.netdrop', { count: dropHover.count }) : t('ev.netdropMany')}</b>
            <div><span class="k">{hhmm(dropHover.t)}</span><span>{dropHover.names ?? ''}</span></div>
          </ChartTip>
        {:else if hover}
          {@const v = hover.row ? (hover.row.beats[hover.i - (N - hover.row.beats.length)] ?? null) : counts[hover.i]}
          <ChartTip x={hover.x} y={hover.y - 2} maxX={w}>
            {#if hover.row}
              <b>{hover.row.name}</b>
              <div><span class="k">{range(hover.i)}</span><span>{v == null ? t('track.noData') : t('track.online', { pct: pct(v, 0) })}</span></div>
              <div><span class="k">{t('perf.uptime24')}</span><span>{pct(hover.row.uptime)}</span></div>
            {:else}
              <b>{range(hover.i)}</b>
              <div><span class="k">{t('perf.onlineAvg')}</span><span>{v == null ? t('track.noData') : num(v, 1)}</span></div>
            {/if}
          </ChartTip>
        {/if}
      {/snippet}
    </ChartFrame>
  </div>
  {#if data.allDayOff.length}
    <div class="alloff">
      <button type="button" class="alloff-b" aria-expanded={showOff} onclick={() => (showOff = !showOff)}>
        <svg class="chev" class:open={showOff} width="14" height="14" aria-hidden="true"><use href="#i-chev" /></svg>
        <i class="sw" style:background="var(--seq-0)"></i>
        {t('perf.allDayOff', { count: data.allDayOff.length })}
      </button>
      {#if showOff}
        <p class="t-caption alloff-list">
          {#each data.allDayOff as d, i (d.id)}<a class="link" href="{base}/devices/{d.id}">{d.name}</a>{i < data.allDayOff.length - 1 ? ', ' : ''}{/each}
        </p>
      {/if}
    </div>
  {/if}
{/if}

<style>
  .legend {
    padding: 12px 16px 4px;
  }
  .night-sw {
    background: var(--fill-strong);
  }
  .pad {
    padding: 4px 16px 8px;
  }
  .name {
    font-size: 11px;
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
  .pc {
    font-weight: 400;
    fill: var(--text-2);
  }
  .alloff {
    border-top: 1px solid var(--line);
  }
  .alloff-b {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    min-height: 40px;
    padding: 4px 16px;
    border: 0;
    background: none;
    color: var(--text-2);
    font: inherit;
    text-align: left;
    border-radius: 0 0 calc(var(--r-lg) - 1px) calc(var(--r-lg) - 1px);
  }
  .alloff-b:hover {
    background: var(--fill);
  }
  .chev {
    color: var(--text-3);
    transition: transform var(--d-fast) var(--ease);
  }
  .chev.open {
    transform: rotate(90deg);
  }
  .sw {
    width: 10px;
    height: 10px;
    border-radius: 2px;
  }
  .alloff-list {
    padding: 0 16px 12px 38px;
    color: var(--text-2);
  }
  .alloff-list .link {
    font-weight: 400;
  }
</style>
