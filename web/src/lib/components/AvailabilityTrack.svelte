<script lang="ts">
  // Availability track: one cell per server bucket, NATIVE resolution (no resampling).
  //   devices: <AvailabilityTrack values={d.node.beats} />            60 × 24 min
  //   services: <AvailabilityTrack values={l.hours} bucketMs={HOUR_MS} />  24 × 1 h
  // Cell colour = fraction online on the sequential scale (--seq-1..5, see
  // seqStep in stats.ts); null = outlined empty cell (no data), 0 = solid grey.
  // axis: absolute local hour labels (00:00 / 06:00 / 12:00 / 18:00) under the track.
  // Fixed height (default 16px); width = the parent's (set it on a wrapper).
  // `now` should be live.now (or receivedAt) so it re-aligns as time passes.
  import { hhmm, pct } from '$lib/model';
  import { BEAT_MS, seqStep, seriesStart } from '$lib/stats';
  import { t } from '$lib/i18n/index.svelte';

  let {
    values,
    bucketMs = BEAT_MS,
    now = Date.now(),
    axis = false,
    height = 16,
    ticks = [0, 6, 12, 18],
    label,
  }: {
    values: readonly (number | null)[];
    bucketMs?: number;
    now?: number;
    axis?: boolean;
    height?: number;
    /** local hours to label on the axis */
    ticks?: number[];
    /** accessible summary, e.g. "99 % online in the last 24 h" */
    label?: string;
  } = $props();

  const n = $derived(values.length);
  const start = $derived(seriesStart(n, bucketMs, now));
  const cls = (v: number | null) => {
    const s = seqStep(v);
    return s < 0 ? 'n' : `s${s}`;
  };
  const title = (v: number | null, i: number) => {
    const a = start + i * bucketMs;
    const range = `${hhmm(a)}–${hhmm(Math.min(a + bucketMs, now))}`;
    return v == null ? `${range} · ${t('track.noData')}` : `${range} · ${t('track.online', { pct: pct(v, 0) })}`;
  };
  const axisTicks = $derived.by(() => {
    if (!axis || !n) return [];
    const end = start + n * bucketMs;
    const out: { x: number; text: string }[] = [];
    const d = new Date(start);
    d.setHours(0, 0, 0, 0);
    for (; d.getTime() < end; d.setDate(d.getDate() + 1)) {
      for (const h of ticks) {
        const tm = new Date(d.getFullYear(), d.getMonth(), d.getDate(), h).getTime();
        const x = (tm - start) / (end - start);
        if (x > 0.04 && x < 0.9) out.push({ x, text: hhmm(tm) });
      }
    }
    return out;
  });
</script>

<div class="track-wrap">
  <div
    class="track"
    style:grid-template-columns="repeat({n}, minmax(0, 1fr))"
    style:--track-h="{height}px"
    role={label ? 'img' : undefined}
    aria-label={label}
    aria-hidden={label ? undefined : 'true'}
  >
    {#each values as v, i (i)}<i class={cls(v)} title={title(v, i)}></i>{/each}
  </div>
  {#if axis}
    <div class="track-axis" aria-hidden="true">
      {#each axisTicks as tk (tk.x)}<span style:left="{tk.x * 100}%">{tk.text}</span>{/each}
      <span class="end" style:left="100%">{t('time.nowShort')}</span>
    </div>
  {/if}
</div>
