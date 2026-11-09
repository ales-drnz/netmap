<script lang="ts">
  // Skeleton block with the FINAL dimensions of what it stands in for.
  // Shown only on the first load: it fades in after 200 ms (so fast loads never
  // flash), and must never replace content on live updates.
  //   {#if !live.snap}<Skeleton height={40} />{:else}…{/if}
  let {
    width = '100%',
    height = 16,
    radius,
    delay = 200,
  }: { width?: string | number; height?: number; radius?: number; delay?: number } = $props();
  const px = (v: string | number) => (typeof v === 'number' ? `${v}px` : v);
</script>

<span
  class="sk"
  aria-hidden="true"
  style:width={px(width)}
  style:height="{height}px"
  style:border-radius={radius != null ? `${radius}px` : undefined}
  style:--sk-delay="{delay}ms"
></span>
