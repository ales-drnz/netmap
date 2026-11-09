<script lang="ts">
  // Search / filter field: 32px, icon, clear ×, Esc clears (then blurs).
  //   <SearchInput bind:value={q} label="Search devices" placeholder="Name, person or IP" page />
  // `page` marks it as THE filter of the page: the global `/` shortcut
  // focuses it (data-page-search). Only one per page.
  import { t } from '$lib/i18n/index.svelte';
  import Icon from './Icon.svelte';

  let {
    value = $bindable(''),
    label,
    placeholder,
    page = false,
    width,
    oninput,
    onkeydown,
  }: {
    value: string;
    label: string;
    placeholder?: string;
    page?: boolean;
    /** CSS width, default 280px (max 100%) */
    width?: string;
    oninput?: (v: string) => void;
    onkeydown?: (e: KeyboardEvent) => void;
  } = $props();

  let el: HTMLInputElement | undefined = $state();

  function clear() {
    value = '';
    oninput?.('');
    el?.focus();
  }
  function key(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      e.stopPropagation();
      if (value) clear();
      else el?.blur();
      return;
    }
    onkeydown?.(e);
  }
</script>

<label class="search" style:width>
  <Icon name="i-search" size={16} />
  <input
    bind:this={el}
    bind:value
    class="input"
    type="search"
    {placeholder}
    aria-label={label}
    autocomplete="off"
    spellcheck="false"
    data-page-search={page ? '' : undefined}
    oninput={() => oninput?.(value)}
    onkeydown={key}
  />
  <span class="search-end">
    {#if value}
      <button type="button" class="search-clear" onclick={clear} aria-label={t('common.clear')}><Icon name="i-x" size={14} /></button>
    {:else if page}
      <span class="kbd" aria-hidden="true">/</span>
    {/if}
  </span>
</label>
