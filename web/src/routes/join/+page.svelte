<script lang="ts">
  import Icon from '$lib/components/Icon.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { ownerOf, typeLabel, typeOf } from '$lib/naming';
  import { ui } from '$lib/ui.svelte';

  const netId = $derived(live.snap?.networkId ?? '');
  let name = $state('alice-laptop');
  const owner = $derived(name.trim() ? ownerOf(name) : null);
  const type = $derived(name.trim() ? typeOf(name) : null);
  const OS = ['Windows', 'macOS', 'Linux', 'Android', 'iOS'];
</script>

<div class="pagehead">
  <div>
    <h1>{t('join.title')}</h1>
    <p>{t('join.intro')}</p>
  </div>
</div>

<div class="card steps">
  <div class="step">
    <div>
      <h3>{t('join.s1')}</h3>
      <p>{t('join.s1Text')}</p>
      <div class="osrow">{#each OS as o (o)}<a class="btn" href="https://www.zerotier.com/download/" target="_blank" rel="noopener">{o}</a>{/each}</div>
    </div>
  </div>
  <div class="step">
    <div>
      <h3>{t('join.s2')}</h3>
      <p>{t('join.s2Text')}</p>
      <div class="addr" style="max-width:520px">
        <span>zerotier-cli join {netId || '…'}</span>
        <button class="btn sm" onclick={() => netId && ui.copy(netId)}><Icon name="i-copy" size={13} />{t('common.copyId')}</button>
      </div>
    </div>
  </div>
  <div class="step">
    <div>
      <h3>{t('join.s3')}</h3>
      <p>{t('join.s3Text')}</p>
    </div>
  </div>
  <div class="step">
    <div>
      <h3>{t('join.s4')}</h3>
      <p>{t('join.s4A')} <span class="mono">{t('join.pattern')}</span>{t('join.s4B')}</p>
      <div class="field">
        <input bind:value={name} aria-label={t('join.try')} spellcheck="false" autocomplete="off" />
        {#if !name.trim()}<span class="muted">{t('join.typeName')}</span>
        {:else}
          <span class="pill {owner ? 'neutral' : 'off'}"><Icon name="i-user" size={12} />{owner ?? t('join.noOwner')}</span>
          <span class="pill {type ? 'neutral' : 'off'}"><Icon name="i-{type ?? 'iot'}" size={12} />{type ? typeLabel(type) : t('join.noType')}</span>
        {/if}
      </div>
    </div>
  </div>
</div>
