<script lang="ts">
  // The app shell for the four pages (route group "(app)"): top bar with
  // logo + "Netmap", tabs, search (opens the command palette), the status
  // pill and the ⋯ menu; on mobile (<768px) a bottom tab bar instead of tabs.
  // No sidebar, no per-page alerts: the status pill is the global verdict.
  //
  // Global shortcuts (ignored while typing in a field):
  //   Ctrl/⌘ K  palette        /  focus the page filter ([data-page-search]) or the palette
  //   g h · g d · g a · g n     Home, Devices, Activity, Network
  //   Esc       close the palette / popovers; on /devices/[id] back to /devices (query kept)
  // Pages own j/k/Enter/c (table navigation) — see DESIGN-v2.
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { page } from '$app/state';
  import CommandPalette from '$lib/components/CommandPalette.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import Popover from '$lib/components/Popover.svelte';
  import Segmented from '$lib/components/Segmented.svelte';
  import StatusPill from '$lib/components/StatusPill.svelte';
  import { i18n, type Lang, LANGS, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { NAV, navOf } from '$lib/nav';
  import { ui } from '$lib/ui.svelte';

  let { children } = $props();

  const path = $derived(page.url.pathname.slice(base.length) || '/');
  const current = $derived(navOf(path));
  const pendingCount = $derived(live.pending.length);
  const netName = $derived(live.snap?.networkName ?? 'Netmap');

  type ThemeChoice = 'system' | 'light' | 'dark';
  const theme = $derived<ThemeChoice>(ui.theme ?? 'system');

  let gPending = false;
  let gTimer: ReturnType<typeof setTimeout> | null = null;
  function onkey(e: KeyboardEvent) {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      ui.palette = !ui.palette;
      return;
    }
    if (e.defaultPrevented || ui.palette) return;
    const target = e.target as HTMLElement;
    if (target.closest('input, textarea, select, [contenteditable="true"]') || e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key === 'Escape') {
      if (document.querySelector('[aria-expanded="true"]')) return; // a popover handles it
      // close the device detail (a route): back to the list/map, filters kept
      const m = path.match(/^\/devices\/[^/]+$/);
      if (m) goto(`${base}/devices${page.url.search}`, { keepFocus: true, noScroll: true });
      return;
    }
    if (e.key === '/') {
      e.preventDefault();
      const field = document.querySelector<HTMLInputElement>('[data-page-search]');
      if (field) field.focus();
      else ui.palette = true;
      return;
    }
    if (gPending) {
      gPending = false;
      const n = NAV.find((x) => x.key === e.key);
      if (n) {
        e.preventDefault();
        goto(`${base}${n.path}`);
      }
      return;
    }
    if (e.key === 'g') {
      gPending = true;
      if (gTimer) clearTimeout(gTimer);
      gTimer = setTimeout(() => (gPending = false), 1000);
    }
  }
</script>

<svelte:window onkeydown={onkey} />
<svelte:head><title>{current ? `${t(current.label)} · ` : ''}{netName} · Netmap</title></svelte:head>

<header class="topbar">
  <div class="topbar-in">
    <a class="brand" href="{base}/" aria-label={t('layout.homeAria', { name: 'Netmap' })}>
      <svg width="24" height="24" aria-hidden="true"><use href="#logo" /></svg>
      <span class="brand-name ellipsis">Netmap</span>
    </a>

    <nav class="tabs" aria-label={t('layout.nav')}>
      {#each NAV as n (n.path)}
        <a class="tab" href="{base}{n.path}" aria-current={current === n ? 'page' : undefined}>
          {t(n.label)}
          {#if n.path === '/activity' && pendingCount}<span class="count" title={t('layout.pendingBadge', { count: pendingCount })}>{pendingCount}</span>{/if}
        </a>
      {/each}
    </nav>

    <div class="topbar-r">
      <button class="searchbox" onclick={() => (ui.palette = true)} aria-label={t('layout.searchAria')}>
        <Icon name="i-search" size={16} /><span>{t('layout.search')}</span><span class="kbd">Ctrl K</span>
      </button>
      <StatusPill />
      <button class="btn ghost icon show-mobile" onclick={() => (ui.palette = true)} aria-label={t('layout.searchAria')}><Icon name="i-search" /></button>
      <Popover label={t('layout.menu')} triggerClass="btn ghost icon" panelClass="shell-menu" role="dialog">
        {#snippet trigger()}<Icon name="i-dots" />{/snippet}
        {#snippet children(close)}
          {#if live.myDevice}
            <a class="menu-item" href="{base}/devices/{live.myDevice.id}" onclick={close}>
              <Icon name="i-user" />
              <span class="ellipsis">{t('layout.you')} <b class="t-label">{live.myDevice.name}</b></span>
              <span class="mono text-3" style:margin-left="auto">{live.myDevice.ip ?? ''}</span>
            </a>
          {:else if live.me}
            <div class="menu-item"><Icon name="i-user" /><span class="text-2">{t('layout.notMember')}</span><span class="mono text-3" style:margin-left="auto">{live.me.ip}</span></div>
          {/if}
          <div class="menu-sep"></div>
          <div class="menu-item">
            <Icon name={ui.isDark() ? 'i-moon' : 'i-sun'} /><span>{t('layout.theme')}</span>
            <Segmented
              size="sm"
              label={t('layout.theme')}
              value={theme}
              onchange={(v) => ui.setTheme(v === 'system' ? null : v)}
              options={[
                { value: 'system', label: t('layout.themeSystem') },
                { value: 'light', label: t('layout.themeLight') },
                { value: 'dark', label: t('layout.themeDark') },
              ]}
            />
          </div>
          <div class="menu-item">
            <Icon name="i-lang" /><span>{t('layout.language')}</span>
            <Segmented
              size="sm"
              label={t('layout.language')}
              value={i18n.lang}
              onchange={(v: Lang) => i18n.setLang(v)}
              options={LANGS.map((l) => ({ value: l, label: l.toUpperCase(), title: t(`lang.${l}`) }))}
            />
          </div>
          <div class="menu-sep"></div>
          <a class="menu-item" href="{base}/join" onclick={close}><Icon name="i-join" />{t('nav.join')}</a>
          <button class="menu-item" onclick={() => { close(); ui.palette = true; }}>
            <Icon name="i-search" />{t('layout.searchAria')}<span class="kbd" style:margin-left="auto">Ctrl K</span>
          </button>
          <div class="menu-sep"></div>
          <p class="menu-version">Netmap {__APP_VERSION__}</p>
        {/snippet}
      </Popover>
    </div>
  </div>
</header>

<main class="content">
  {@render children()}
</main>

<nav class="tabbar" aria-label={t('layout.nav')}>
  {#each NAV as n (n.path)}
    <a href="{base}{n.path}" aria-current={current === n ? 'page' : undefined}>
      <Icon name={n.icon} size={20} />{t(n.label)}
      {#if n.path === '/activity' && pendingCount}<span class="count">{pendingCount}</span>{/if}
    </a>
  {/each}
</nav>

<CommandPalette />
