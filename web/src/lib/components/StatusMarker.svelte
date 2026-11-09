<script lang="ts">
  // Status marker: the SHAPE half of "shape + colour + word" (WCAG: never colour alone).
  //   direct-lan  filled circle with an inner ring (same physical network)
  //   direct-wan  filled circle (direct over the internet)
  //   relay       ring with the lower half filled
  //   offline     1.5px ring
  //   fault       small triangle (half-open, netdrop, service down, spike)
  //   unknown     dashed ring (no data: null ≠ false)
  // <StatusMarker kind="relay" />  · size defaults to 8px (min 8).
  // Pass `label` when the marker stands alone (no word next to it).
  import type { StatusKind } from '$lib/model';

  let { kind, size = 8, label }: { kind: StatusKind; size?: number; label?: string } = $props();
</script>

<svg
  class="mk mk-{kind}"
  width={size}
  height={size}
  viewBox="0 0 8 8"
  role={label ? 'img' : undefined}
  aria-label={label}
  aria-hidden={label ? undefined : 'true'}
>
  {#if kind === 'direct-lan'}
    <path fill="currentColor" fill-rule="evenodd" d="M4 0a4 4 0 1 1 0 8 4 4 0 0 1 0-8Zm0 1.6a2.4 2.4 0 1 0 0 4.8 2.4 2.4 0 0 0 0-4.8Zm0 1.15a1.25 1.25 0 1 1 0 2.5 1.25 1.25 0 0 1 0-2.5Z" />
  {:else if kind === 'direct-wan'}
    <circle cx="4" cy="4" r="4" fill="currentColor" />
  {:else if kind === 'relay'}
    <circle cx="4" cy="4" r="3.25" fill="none" stroke="currentColor" stroke-width="1.5" />
    <path d="M0.75 4a3.25 3.25 0 0 0 6.5 0Z" fill="currentColor" />
  {:else if kind === 'offline'}
    <circle cx="4" cy="4" r="3.25" fill="none" stroke="currentColor" stroke-width="1.5" />
  {:else if kind === 'fault'}
    <path d="M4 0.4 7.8 7.4H0.2Z" fill="currentColor" stroke="currentColor" stroke-width="0.6" stroke-linejoin="round" />
  {:else}
    <circle cx="4" cy="4" r="3.25" fill="none" stroke="currentColor" stroke-width="1.5" stroke-dasharray="1.7 1.7" />
  {/if}
</svg>
