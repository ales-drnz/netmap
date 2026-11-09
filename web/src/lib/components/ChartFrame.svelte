<script lang="ts">
  // Chart container: measures the available width and renders the chart at
  // that REAL pixel width (no viewBox scaling, so 11px axis text stays 11px).
  // Below `minWidth` the chart keeps its minimum and scrolls horizontally
  // instead of squeezing. Height is fixed by the chart itself.
  //   <ChartFrame minWidth={520}>{#snippet children(w)}<svg width={w} height={160}>…</svg>{/snippet}</ChartFrame>
  // The inner box is position:relative: put a <ChartTip> inside the snippet.
  import type { Snippet } from 'svelte';

  let { minWidth = 0, children }: { minWidth?: number; children: Snippet<[number]> } = $props();
  let avail = $state(0);
  const width = $derived(Math.max(minWidth, Math.floor(avail)));
</script>

<div class="chart-frame" bind:clientWidth={avail}>
  <div class="chart-scroll" class:scrolls={width > avail}>
    <div class="chart-in" style:width="{width}px">
      {#if avail > 0}{@render children(width)}{/if}
    </div>
  </div>
</div>
