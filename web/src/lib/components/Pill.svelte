<script lang="ts">
  import { type Status, statusLabel } from '$lib/model';
  let { status, label }: { status: Status; label?: string } = $props();
</script>

<span class="pill {status}"><span class="dot {status}"></span>{label ?? statusLabel(status)}</span>
