<script lang="ts">
  // Sparkline: gaps (samples without latency) carry the previous value forward,
  // so the line doesn't break; the end dot is the last real value.
  let {
    values,
    w = 120,
    h = 28,
    color = 'var(--text-3)',
    area = true,
  }: { values: (number | null)[]; w?: number; h?: number; color?: string; area?: boolean } = $props();
  const uid = `sp${Math.random().toString(36).slice(2, 8)}`;
  const geo = $derived.by(() => {
    const pts = values.filter((v): v is number => v != null);
    if (pts.length < 2) return null;
    const mx = Math.max(...pts) * 1.1 || 1;
    const sx = w / (values.length - 1);
    let last = pts[0] ?? 0;
    const c = values.map((v, i) => {
      if (v != null) last = v;
      return [i * sx, h - 2 - (last / mx) * (h - 4)] as const;
    });
    const line = c.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join('');
    return { line, end: c[c.length - 1] ?? [0, 0] };
  });
</script>

{#if geo}
  <svg width={w} height={h} viewBox="0 0 {w} {h}" preserveAspectRatio="none" style="display:block;width:100%;max-width:{w}px" aria-hidden="true">
    {#if area}
      <defs><linearGradient id={uid} x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color={color} stop-opacity=".18" /><stop offset="1" stop-color={color} stop-opacity="0" /></linearGradient></defs>
      <path d="{geo.line}L{w} {h}L0 {h}Z" fill="url(#{uid})" />
    {/if}
    <path d={geo.line} fill="none" stroke={color} stroke-width="1.5" vector-effect="non-scaling-stroke" />
    <circle cx={geo.end[0]} cy={geo.end[1]} r="2.5" fill={color} />
  </svg>
{:else}
  <span class="muted">—</span>
{/if}
