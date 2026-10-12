<script lang="ts">
  import { t } from '$lib/i18n/index.svelte';
  import { ui } from '$lib/ui.svelte';
  import Icon from './Icon.svelte';
  let { text, label }: { text: string; label?: string } = $props();
</script>

<button
  class="copy"
  title={t('common.copy')}
  onclick={(e) => {
    e.stopPropagation();
    ui.copy(text);
  }}>{label ?? text}<Icon name="i-copy" size={12} /></button
>
