<script lang="ts">
  // Hover tooltip for charts: exact values, never a replacement for the axis.
  // Anchored at (x, y) inside the nearest position:relative box (ChartFrame's
  // inner box), centred above the point, kept inside [0, maxX], flipped below
  // when there's no room above.
  //   {#if hover}<ChartTip x={hx} y={hy} maxX={w}><b>alice-pc</b> 12 ms</ChartTip>{/if}
  import type { Snippet } from 'svelte';
  import { clampTip } from '$lib/charts/scale';

  let { x, y, maxX, children }: { x: number; y: number; maxX: number; children: Snippet } = $props();
  let tw = $state(0);
  let th = $state(0);
  const left = $derived(clampTip(x, tw, maxX));
  const below = $derived(y - th - 10 < 0);
</script>

<div
  class="chart-tip"
  role="tooltip"
  bind:offsetWidth={tw}
  bind:offsetHeight={th}
  style:left="{left}px"
  style:top="{below ? y + 14 : y - th - 10}px"
>
  {@render children()}
</div>
