<script lang="ts">
  // Root layout: what EVERY page needs, shell or not (fonts, tokens, icon
  // sprite, theme, live data, toast). The app shell (top bar, tabs, palette,
  // shortcuts) lives in (app)/+layout.svelte; /join sits outside the (app)
  // group so it renders without the shell (its own minimal layout).
  import '@fontsource-variable/geist';
  import '@fontsource-variable/geist-mono';
  import '$lib/styles/app.css';
  import IconSprite from '$lib/components/IconSprite.svelte';
  import { live } from '$lib/live.svelte';
  import { ui } from '$lib/ui.svelte';
  import { onMount } from 'svelte';

  let { children } = $props();

  onMount(() => {
    ui.init();
    live.start();
  });
</script>

<IconSprite />
{@render children()}
<div class="toast" class:show={!!ui.toast} role="status" aria-live="polite">{ui.toast ?? ''}</div>
