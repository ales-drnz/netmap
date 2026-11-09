<script lang="ts">
  // Old v1 URL, kept so bookmarks keep working:
  // /map → / (the Home is the map), /map?d=X → /?d=X
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { page } from '$app/state';
  import { onMount } from 'svelte';

  onMount(() => {
    const d = page.url.searchParams.get('d');
    goto(`${base}/${d ? `?d=${encodeURIComponent(d)}` : ''}`, { replaceState: true });
  });
</script>
