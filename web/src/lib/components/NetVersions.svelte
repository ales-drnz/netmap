<script lang="ts">
  // Client versions across the network, newest first. Never "outdated" in
  // absolute terms (the network may have no internet): only "someone here runs
  // x", which is verifiable. The newest is marked neutrally (no colour).
  import { versionCounts } from '$lib/charts/perf';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import EmptyState from './EmptyState.svelte';

  const versions = $derived(versionCounts(live.nodes));
  const max = $derived(Math.max(1, ...versions.map((v) => v.n)));
  const total = $derived(versions.reduce((s, v) => s + v.n, 0));
  const mine = $derived(live.myDevice?.node.version ?? null);
</script>

{#if !versions.length}
  <EmptyState icon="i-net" title={t('net.noVersions')} />
{:else}
  <ul class="rows">
    {#each versions as v, i (v.v)}
      <li class="row ver" class:newest={i === 0}>
        <span class="mono">{v.v}</span>
        <span class="tags">
          {#if i === 0 && versions.length > 1}<span class="tag">{t('net.latest')}</span>{/if}
          {#if mine === v.v}<span class="you-tag">{t('common.you')}</span>{/if}
        </span>
        <span class="bar" aria-hidden="true"><i style:width="{(v.n / max) * 100}%"></i></span>
        <span class="num n" title={t('net.verTitle', { n: v.n, total })}>{v.n}</span>
      </li>
    {/each}
  </ul>
  {#if versions.length > 1}
    <p class="foot t-caption text-3">{t('net.latestText', { v: versions[0]?.v ?? '' })}</p>
  {/if}
{/if}

<style>
  .ver {
    display: grid;
    grid-template-columns: 72px 88px minmax(40px, 1fr) 32px;
    gap: 12px;
  }
  .tags {
    display: inline-flex;
    gap: 6px;
    align-items: center;
  }
  .bar {
    height: 8px;
    background: var(--fill);
    border-radius: 2px;
    overflow: hidden;
  }
  .bar i {
    display: block;
    height: 100%;
    background: var(--series-2);
    border-radius: 2px;
  }
  .newest .bar i {
    background: var(--series);
  }
  .newest .mono {
    font-weight: 600;
  }
  .n {
    text-align: right;
  }
  .foot {
    padding: 10px 16px 12px;
    border-top: 1px solid var(--line);
  }
</style>
