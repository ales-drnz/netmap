<script lang="ts">
  // Latency of one device over its last samples (NetNode.spark, 90 × one poll).
  // Log scale shared by every device (1–600 ms, ticks 3/10/30/100/300), so two
  // devices compare at a glance and the SPIKE line always sits at the same height.
  // null sample = gap (the line breaks, never carried forward); samples above
  // the spike threshold are red dots (colour = state). Drawn in real pixels
  // (the width is measured) so the axis text never scales.
  //   <DeviceLatencyChart values={n.spark} stepSec={live.pollSeconds} />
  import { t } from '$lib/i18n/index.svelte';
  import { num } from '$lib/model';

  let {
    values,
    stepSec = 20,
    spikeMs = 150,
    height = 132,
    label,
  }: {
    values: readonly (number | null)[];
    /** seconds between two samples (the server poll) */
    stepSec?: number;
    /** server SPIKE_MS (README: default 150) */
    spikeMs?: number;
    height?: number;
    label?: string;
  } = $props();

  const LO = 1;
  const HI = 600;
  const TICKS = [3, 10, 30, 100, 300];
  const L = 48; // left gutter (tick labels)
  const R = 4;
  const T = 8;
  const B = 22; // bottom axis

  let width = $state(0);
  const plotW = $derived(Math.max(0, width - L - R));
  const plotH = $derived(height - T - B);

  const y = (v: number) => {
    const c = Math.min(HI, Math.max(LO, v));
    return T + (1 - Math.log(c / LO) / Math.log(HI / LO)) * plotH;
  };
  const x = (i: number) => L + (values.length > 1 ? (i / (values.length - 1)) * plotW : plotW / 2);

  const geo = $derived.by(() => {
    let d = '';
    const dots: { x: number; y: number; spike: boolean }[] = [];
    let run = 0;
    let last: { x: number; y: number; spike: boolean } | null = null;
    values.forEach((v, i) => {
      if (v == null || !Number.isFinite(v)) {
        if (run === 1 && last) dots.push(last);
        run = 0;
        return;
      }
      const p = { x: x(i), y: y(v), spike: v > spikeMs };
      d += `${run ? 'L' : 'M'}${p.x.toFixed(1)} ${p.y.toFixed(1)}`;
      if (p.spike) dots.push(p);
      last = p;
      run++;
    });
    if (run === 1 && last) dots.push(last);
    return { d, dots };
  });

  const spanMin = $derived(Math.max(1, Math.round((values.length * stepSec) / 60)));
</script>

<div class="lc" bind:clientWidth={width} style:height="{height}px">
  {#if width}
    <svg {width} {height} role="img" aria-label={label}>
      {#each TICKS as tk (tk)}
        <line class="grid" x1={L} x2={width - R} y1={y(tk)} y2={y(tk)} />
        <text class="tick" x={L - 6} y={y(tk)} dy="0.32em" text-anchor="end">{tk === 300 ? `${tk} ms` : tk}</text>
      {/each}
      <line class="spike" x1={L} x2={width - R} y1={y(spikeMs)} y2={y(spikeMs)} />
      <text class="spike-t" x={width - R} y={y(spikeMs) - 4} text-anchor="end">{t('detail.spikeLine', { ms: spikeMs })}</text>
      <path class="line" d={geo.d} />
      {#each geo.dots as p, i (i)}<circle class:spike={p.spike} cx={p.x} cy={p.y} r={p.spike ? 2.5 : 1.75} />{/each}
      <text class="tick" x={L} y={height - 6}>{t('detail.minAgo', { n: num(spanMin) })}</text>
      <text class="tick" x={width - R} y={height - 6} text-anchor="end">{t('time.nowShort')}</text>
    </svg>
  {/if}
</div>

<style>
  .lc {
    width: 100%;
  }
  svg {
    display: block;
    overflow: visible;
  }
  .grid {
    stroke: var(--grid);
    stroke-width: 1;
  }
  .tick,
  .spike-t {
    fill: var(--axis);
    font-size: 11px;
    font-weight: 500;
    font-variant-numeric: tabular-nums;
  }
  .spike {
    stroke: var(--err);
    stroke-width: 1;
    stroke-dasharray: 3 3;
  }
  .spike-t {
    fill: var(--err-fg);
  }
  .line {
    fill: none;
    stroke: var(--series);
    stroke-width: 1.5;
    stroke-linejoin: round;
    stroke-linecap: round;
  }
  circle {
    fill: var(--series);
  }
  circle.spike {
    fill: var(--err);
    stroke: var(--surface);
    stroke-width: 1;
    stroke-dasharray: none;
  }
</style>
