<script lang="ts">
  // Old v1 URL, kept so bookmarks keep working: /me → /
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { onMount } from 'svelte';

  onMount(() => {
    goto(`${base}/`, { replaceState: true });
  });
</script>
