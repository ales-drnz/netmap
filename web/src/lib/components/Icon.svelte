<script lang="ts">
  // <Icon name="i-copy" size={16} />: a symbol from IconSprite.svelte (the
  // sprite is rendered once by the root layout). Colour = currentColor.
  // Decorative by default (aria-hidden): put the meaning in text or aria-label.
  let { name, size = 16, class: cls = '' }: { name: string; size?: number; class?: string } = $props();
</script>

<svg width={size} height={size} class={cls} aria-hidden="true"><use href="#{name}" /></svg>
