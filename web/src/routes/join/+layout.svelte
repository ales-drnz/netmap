<script lang="ts">
  // /join is OUTSIDE the app shell (it's a page to send to a newcomer who
  // isn't on the network yet): a minimal header with the logo, the network
  // name and the language toggle, then a single printable column.
  import { base } from '$app/paths';
  import Segmented from '$lib/components/Segmented.svelte';
  import { i18n, type Lang, LANGS, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';

  let { children } = $props();
  const netName = $derived(live.snap?.networkName ?? 'Netmap');
</script>

<svelte:head><title>{t('nav.join')} · {netName}</title></svelte:head>

<header class="topbar join-top">
  <div class="topbar-in">
    <a class="brand" href="{base}/">
      <svg width="24" height="24" aria-hidden="true"><use href="#logo" /></svg>
      <span class="brand-name ellipsis">Netmap</span>
    </a>
    <div class="topbar-r">
      <Segmented
        size="sm"
        label={t('layout.language')}
        value={i18n.lang}
        onchange={(v: Lang) => i18n.setLang(v)}
        options={LANGS.map((l) => ({ value: l, label: l.toUpperCase(), title: t(`lang.${l}`) }))}
      />
    </div>
  </div>
</header>

<main class="join-main">
  {@render children()}
</main>

<style>
  .join-main {
    max-width: 720px;
    margin: 0 auto;
    padding: 32px 16px 64px;
  }
</style>
