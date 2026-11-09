<script lang="ts">
  // Button (or link styled as a button when `href` is set).
  //   variant: 'secondary' (default: surface + hairline) | 'primary' (ink; at most
  //            ONE per view) | 'ghost' (transparent, hover --fill)
  //   size: 'md' 32px | 'sm' 28px · icon: sprite name shown before the label
  //   iconOnly: square icon button; then `label` is REQUIRED (aria-label + title)
  //   external: opens in a new tab with rel=noopener and an ↗ icon after the label
  //   <Button variant="ghost" size="sm" href={url} external>Open</Button>
  //   <Button iconOnly icon="i-dots" label="Menu" onclick={…} />
  import type { Snippet } from 'svelte';
  import type { HTMLButtonAttributes } from 'svelte/elements';
  import Icon from './Icon.svelte';

  let {
    variant = 'secondary',
    size = 'md',
    icon,
    iconOnly = false,
    label,
    href,
    external = false,
    type = 'button',
    children,
    class: cls = '',
    ...rest
  }: {
    variant?: 'primary' | 'secondary' | 'ghost';
    size?: 'md' | 'sm';
    icon?: string;
    iconOnly?: boolean;
    label?: string;
    href?: string;
    external?: boolean;
    type?: 'button' | 'submit';
    children?: Snippet;
    class?: string;
  } & Omit<HTMLButtonAttributes, 'type' | 'class' | 'children'> = $props();

  const iconSize = $derived(size === 'sm' ? 14 : 16);
  const classes = $derived(['btn', variant, size === 'sm' && 'sm', iconOnly && 'icon', cls].filter(Boolean).join(' '));
</script>

{#if href}
  <a
    {href}
    class={classes}
    aria-label={iconOnly ? label : undefined}
    title={iconOnly ? label : undefined}
    target={external ? '_blank' : undefined}
    rel={external ? 'noopener noreferrer' : undefined}
  >
    {#if icon}<Icon name={icon} size={iconSize} />{/if}
    {#if !iconOnly}{#if children}{@render children()}{:else}{label}{/if}{/if}
    {#if external && !iconOnly}<Icon name="i-ext" size={12} />{/if}
  </a>
{:else}
  <button {type} class={classes} aria-label={iconOnly ? label : undefined} title={iconOnly ? label : undefined} {...rest}>
    {#if icon}<Icon name={icon} size={iconSize} />{/if}
    {#if !iconOnly}{#if children}{@render children()}{:else}{label}{/if}{/if}
  </button>
{/if}
