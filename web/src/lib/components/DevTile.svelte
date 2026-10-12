<script lang="ts">
  import type { Device } from '$lib/model';
  import Icon from './Icon.svelte';
  let { d, size = 18 }: { d: Device; size?: number } = $props();
</script>

<span class="devtile"><Icon name="i-{d.type}" {size} /><span class="dot {d.status}"></span></span>
