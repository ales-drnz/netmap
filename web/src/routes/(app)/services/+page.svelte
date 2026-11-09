<script lang="ts">
  // Old v1 URL, kept so bookmarks keep working: /services → the Services tab of the map page
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { onMount } from 'svelte';

  onMount(() => {
    goto(`${base}/?tab=services`, { replaceState: true });
  });
</script>
