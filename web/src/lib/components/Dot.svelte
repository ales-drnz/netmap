<script lang="ts">
  import type { Status } from '$lib/model';
  let { status }: { status: Status } = $props();
</script>

<span class="dot {status}"></span>
