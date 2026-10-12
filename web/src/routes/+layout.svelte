<script lang="ts">
  import '@fontsource-variable/inter';
  import '@fontsource/geist-mono/400.css';
  import '@fontsource/geist-mono/500.css';
  import '$lib/styles/app.css';
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { page } from '$app/state';
  import CommandPalette from '$lib/components/CommandPalette.svelte';
  import DeviceDrawer from '$lib/components/DeviceDrawer.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import IconSprite from '$lib/components/IconSprite.svelte';
  import { live } from '$lib/live.svelte';
  import { i18n, LANGS, t } from '$lib/i18n/index.svelte';
  import { NAV, NAV_GROUP } from '$lib/nav';
  import { ui } from '$lib/ui.svelte';
  import { onMount } from 'svelte';

  let { children } = $props();

  onMount(() => {
    ui.init();
    live.start();
  });

  const path = $derived(page.url.pathname.slice(base.length) || '/');
  const current = $derived(NAV.find((n) => (n.path === '/' ? path === '/' : path.startsWith(n.path))) ?? null);
  // disconnections in the last hour: the counter on the Activity item
  const recentDrops = $derived(live.events.filter((e) => (e.kind === 'offline' || e.kind === 'netdrop') && live.now - e.t < 3600e3).length);

  $effect(() => {
    path;
    ui.sidebar = false;
    ui.drawer = null;
  });

  let gPending = false;
  function onkey(e: KeyboardEvent) {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      ui.palette = true;
      return;
    }
    if (e.key === 'Escape') {
      ui.palette = false;
      ui.drawer = null;
      ui.sidebar = false;
      return;
    }
    const t = e.target as HTMLElement;
    if (t.matches('input, textarea, select') || e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key === '/') {
      e.preventDefault();
      const field = document.querySelector<HTMLInputElement>('[data-page-search]');
      if (field) field.focus();
      else ui.palette = true;
      return;
    }
    if (e.key === 't') return ui.toggleTheme();
    if (gPending) {
      gPending = false;
      const n = NAV.find((x) => x.key === e.key);
      if (n) goto(`${base}${n.path}`);
      return;
    }
    if (e.key === 'g') {
      gPending = true;
      setTimeout(() => (gPending = false), 900);
    }
  }
</script>

<svelte:window onkeydown={onkey} />
<svelte:head><title>{current ? `${t(current.label)} · ` : ''}Netmap</title></svelte:head>

<IconSprite />

<div class="app">
  <aside class="side" class:open={ui.sidebar} aria-label={t('layout.nav')}>
    <div class="brand"><svg width="26" height="26"><use href="#logo" /></svg><b>netmap<i>·</i></b></div>
    <div class="netpick">
      <span class="dot {live.offline ? 'off' : 'direct'}"></span>
      <div><span>{t('layout.ztNetwork')}</span><strong>{live.snap?.networkName ?? '…'}</strong></div>
    </div>
    <nav style="display:flex;flex-direction:column;gap:2px">
      {#each NAV as n, i (n.path)}
        {#if n.group !== 'top' && NAV[i - 1]?.group !== n.group}<div class="navlabel">{t(NAV_GROUP[n.group])}</div>{/if}
        <a class="nav" href="{base}{n.path}" aria-current={current === n ? 'page' : undefined}>
          <Icon name={n.icon} />{t(n.label)}
          {#if n.path === '/activity' && recentDrops}<span class="badge" title={t('layout.dropsBadge')}>{recentDrops}</span>{/if}
        </a>
      {/each}
    </nav>
    <div class="side-foot">
      <div class="ctl">
        {#if live.offline}<span class="dot off"></span>{t('layout.unreachable')}
        {:else if live.ago != null}<span class="dot direct"></span>{t('layout.updatedPre')} <span class="num">{live.ago}</span> {t('layout.updatedPost')}
        {:else}<span class="dot off"></span>{t('layout.loading')}{/if}
      </div>
      <div class="me">
        <div class="avatar me-av">{(live.myDevice?.ownerLabel ?? '?').charAt(0)}</div>
        <div>
          <strong>{live.myDevice?.ownerLabel ?? t('layout.guest')}</strong>
          <small>{live.me?.name ? t('layout.from', { name: live.me.name }) : (live.me?.ip ?? t('layout.unknown'))}</small>
        </div>
        <button class="iconbtn" style="margin-left:auto" onclick={() => ui.toggleTheme()} aria-label={t('layout.theme')} title={t('layout.themeHint')}>
          <Icon name={ui.theme === 'dark' || (ui.theme == null && typeof matchMedia !== 'undefined' && matchMedia('(prefers-color-scheme: dark)').matches) ? 'i-sun' : 'i-moon'} size={15} />
        </button>
      </div>
      <div class="ctl langrow">
        <span id="lang-label">{t('layout.language')}</span>
        <div class="seg flat mini" role="group" aria-labelledby="lang-label">
          {#each LANGS as l (l)}
            <button aria-pressed={i18n.lang === l} lang={l} title={t(`lang.${l}`)} onclick={() => i18n.setLang(l)}>{l.toUpperCase()}</button>
          {/each}
        </div>
      </div>
    </div>
  </aside>

  <div class="main">
    <header class="top">
      <button class="iconbtn menu" onclick={() => (ui.sidebar = true)} aria-label={t('layout.openMenu')}><Icon name="i-menu" /></button>
      <div class="crumbs"><span>{live.snap?.networkName ?? 'netmap'}</span><span>/</span>{current ? t(current.label) : ''}</div>
      {#if live.snap}
        <div class="kpis-mini">
          <span><span class="dot direct"></span><b>{live.online.length}/{live.devices.length}</b> online</span>
          {#if live.latAvg != null}<span><b>{Math.round(live.latAvg)} ms</b> {t('layout.kpiAvg')}</span>{/if}
          <span><b>{live.direct.length}</b> {t('layout.kpiDirect')} · <b>{live.relay.length}</b> relay</span>
        </div>
      {/if}
      <button class="searchbtn" onclick={() => (ui.palette = true)}>
        <Icon name="i-search" size={14} /><span>{t('layout.search')}</span><span class="kbd">Ctrl K</span>
      </button>
    </header>
    <main class="content">
      {#if live.snap?.error}
        <div class="alert"><span class="ic"><Icon name="i-warn" /></span><div><b>{t('layout.ztnetDown')}</b><p>{t('layout.ztnetDownText', { error: live.snap.error })}</p></div></div>
      {/if}
      {@render children()}
    </main>
  </div>
</div>

{#if ui.sidebar}<div class="scrim open" onclick={() => (ui.sidebar = false)} role="presentation"></div>{/if}
<DeviceDrawer />
<CommandPalette />
<div class="toast" class:show={!!ui.toast} role="status" aria-live="polite">{ui.toast ?? ''}</div>
