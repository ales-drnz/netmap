<script lang="ts">
  let { name, size = 16 }: { name: string; size?: number } = $props();
</script>

<svg width={size} height={size} aria-hidden="true"><use href="#{name}" /></svg>
