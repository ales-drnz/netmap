<script lang="ts">
  import { t } from '$lib/i18n/index.svelte';
  import type { Cell } from '$lib/model';
  let { cells, axis = false }: { cells: Cell[]; axis?: boolean } = $props();
</script>

<div class="cells">
  {#each cells as c, i (i)}<i class={c === 'k' ? '' : c} title="{t('time.hAgo', { n: 24 - i })}: {t(`cells.${c}`)}"></i>{/each}
</div>
{#if axis}<div class="axis"><span>{t('time.hAgo', { n: 24 })}</span><span>{t('time.nowShort')}</span></div>{/if}
