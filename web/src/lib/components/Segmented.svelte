<script lang="ts" generics="T extends string">
  // Segmented control (single choice). Active = raised --surface, never a dark block.
  // On narrow screens it scrolls horizontally instead of wrapping.
  //   <Segmented label="Status" bind:value={status} options={[
  //     { value: 'all', label: 'All', count: 47 },
  //     { value: 'relay', label: 'Relay', count: 6, marker: 'relay' },
  //   ]} />
  // Options can carry an icon (sprite name), a status marker and a count (tnum).
  // `onchange` fires after a user pick (handy to sync the URL).
  import type { StatusKind } from '$lib/model';
  import Icon from './Icon.svelte';
  import StatusMarker from './StatusMarker.svelte';

  interface Option {
    value: T;
    label: string;
    count?: number | null;
    icon?: string;
    marker?: StatusKind;
    title?: string;
  }

  let {
    options,
    value = $bindable(),
    label,
    size = 'md',
    onchange,
  }: { options: Option[]; value: T; label: string; size?: 'md' | 'sm'; onchange?: (v: T) => void } = $props();

  function pick(v: T) {
    value = v;
    onchange?.(v);
  }
  function key(e: KeyboardEvent) {
    const i = options.findIndex((o) => o.value === value);
    const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
    if (!d || i < 0) return;
    e.preventDefault();
    const next = options[(i + d + options.length) % options.length];
    if (!next) return;
    pick(next.value);
    (e.currentTarget as HTMLElement).querySelector<HTMLElement>(`[data-v="${CSS.escape(next.value)}"]`)?.focus();
  }
</script>

<div class="seg" class:sm={size === 'sm'} role="radiogroup" aria-label={label} tabindex="-1" onkeydown={key}>
  {#each options as o (o.value)}
    <button
      type="button"
      role="radio"
      aria-checked={o.value === value}
      tabindex={o.value === value ? 0 : -1}
      data-v={o.value}
      title={o.title}
      onclick={() => pick(o.value)}
    >
      {#if o.icon}<Icon name={o.icon} size={14} />{/if}
      {#if o.marker}<StatusMarker kind={o.marker} />{/if}
      {o.label}
      {#if o.count != null}<span class="seg-n">{o.count}</span>{/if}
    </button>
  {/each}
</div>
