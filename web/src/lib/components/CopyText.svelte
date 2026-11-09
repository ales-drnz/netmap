<script lang="ts">
  // Inline copyable value (IP, ID, address): mono text, copy icon on hover /
  // focus (always visible on touch). Click copies via ui.copy (which has the
  // non-secure-context fallback) and shows a toast. Doesn't bubble the click,
  // so it's safe inside clickable rows.
  //   <CopyText text={d.ip} />     <CopyText text={url} label="nas.home.zt" />
  import { t } from '$lib/i18n/index.svelte';
  import { ui } from '$lib/ui.svelte';
  import Icon from './Icon.svelte';

  let { text, label, mono = true }: { text: string; label?: string; mono?: boolean } = $props();
</script>

<button
  type="button"
  class="copytext"
  style:font-family={mono ? undefined : 'inherit'}
  title={t('common.copyThing', { text })}
  onclick={(e) => {
    e.stopPropagation();
    e.preventDefault();
    ui.copy(text);
  }}><span class="ellipsis">{label ?? text}</span><Icon name="i-copy" size={12} /></button
>
