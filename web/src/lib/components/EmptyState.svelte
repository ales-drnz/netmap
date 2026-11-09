<script lang="ts">
  // Empty state: left-aligned in its section, 20px icon (text-3), a title,
  // ONE sentence (text-2), at most one action.
  //   <EmptyState icon="i-grid" title="No services yet" text="Add them in services.json.">
  //     {#snippet action()}<Button size="sm" href="…">Learn how</Button>{/snippet}
  //   </EmptyState>
  import type { Snippet } from 'svelte';
  import Icon from './Icon.svelte';

  let { icon = 'i-help', title, text, action }: { icon?: string; title: string; text?: string; action?: Snippet } = $props();
</script>

<div class="empty">
  <Icon name={icon} size={20} />
  <div>
    <b>{title}</b>
    {#if text}<p>{text}</p>{/if}
    {#if action}<div class="empty-act">{@render action()}</div>{/if}
  </div>
</div>
