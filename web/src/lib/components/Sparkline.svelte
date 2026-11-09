<script lang="ts">
  // Sparkline: a fixed-size line, NO carry-forward: a null sample is a gap
  // (the line breaks; an isolated sample is a dot). Neutral --series colour.
  //   <Sparkline values={d.node.spark} width={96} height={20} />
  //   domain: shared [min, max] so several sparklines compare on one scale
  //           (default: 0 … max of this series)
  // Use only where the trend carries information (no decorative sparklines).
  let {
    values,
    width = 96,
    height = 20,
    domain,
    label,
  }: {
    values: readonly (number | null)[];
    width?: number;
    height?: number;
    domain?: [number, number];
    label?: string;
  } = $props();

  const geo = $derived.by(() => {
    const pts = values.filter((v): v is number => v != null && Number.isFinite(v));
    if (!pts.length) return null;
    const [lo, hi] = domain ?? [0, Math.max(...pts)];
    const span = hi - lo || 1;
    const pad = 1.5;
    const sx = values.length > 1 ? (width - 2 * pad) / (values.length - 1) : 0;
    const y = (v: number) => pad + (1 - (Math.min(hi, Math.max(lo, v)) - lo) / span) * (height - 2 * pad);
    let d = '';
    const dots: [number, number][] = [];
    let run = 0;
    let lastPt: [number, number] = [0, 0];
    values.forEach((v, i) => {
      if (v == null || !Number.isFinite(v)) {
        if (run === 1) dots.push(lastPt);
        run = 0;
        return;
      }
      const p: [number, number] = [pad + i * sx, y(v)];
      d += `${run ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`;
      lastPt = p;
      run++;
    });
    if (run === 1) dots.push(lastPt);
    return { d, dots };
  });
</script>

{#if geo}
  <svg
    class="spark"
    {width}
    {height}
    viewBox="0 0 {width} {height}"
    role={label ? 'img' : undefined}
    aria-label={label}
    aria-hidden={label ? undefined : 'true'}
  >
    <path d={geo.d} />
    {#each geo.dots as p, i (i)}<circle cx={p[0]} cy={p[1]} r="1.5" />{/each}
  </svg>
{:else}
  <span class="text-4" style:display="inline-block" style:width="{width}px">—</span>
{/if}
