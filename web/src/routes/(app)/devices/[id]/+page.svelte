<script lang="ts">
  // /devices/[id]: the device detail. Rendered by ../+layout.svelte inside the
  // side panel (desktop) or as a full page (mobile). The hub is a device too.
  // Esc (shell) and the close/back links return to /devices with the filters kept.
  import { base } from '$app/paths';
  import { page } from '$app/state';
  import Button from '$lib/components/Button.svelte';
  import DeviceDetail from '$lib/components/DeviceDetail.svelte';
  import EmptyState from '$lib/components/EmptyState.svelte';
  import Skeleton from '$lib/components/Skeleton.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { toDevice } from '$lib/model';

  const id = $derived(page.params.id ?? '');
  const d = $derived.by(() => {
    const n = live.nodes.find((x) => x.id === id);
    return n ? toDevice(n, live.receivedAt || Date.now()) : null;
  });
  const closeHref = $derived(`${base}/devices${page.url.search}`);
  const mapHref = $derived(`${base}/?d=${encodeURIComponent(id)}`);
</script>


{#if d}
  <DeviceDetail {d} {closeHref} {mapHref} />
{:else if !live.snap}
  <div class="nf" aria-busy="true">
    <Skeleton width="50%" height={24} />
    <Skeleton width="30%" height={20} />
    <Skeleton height={120} />
  </div>
{:else}
  <div class="nf">
    <h2 id="detail-title" class="t-h2" tabindex="-1">{t('detail.notFound')}</h2>
    <EmptyState icon="i-search" title={t('detail.notFoundTitle')} text={t('detail.notFoundText', { id })}>
      {#snippet action()}<Button size="sm" href={closeHref}>{t('detail.backToList')}</Button>{/snippet}
    </EmptyState>
  </div>
{/if}

<style>
  .nf {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 20px;
  }
  .nf :global(.empty) {
    padding: 0;
  }
  @media (max-width: 767px) {
    .nf {
      padding: 0;
    }
  }
</style>
