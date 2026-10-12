<script lang="ts">
  // Ctrl/⌘ K: one index of devices, pages, services and actions.
  // Enter opens, Shift+Enter copies the IP (the most common action on a phone).
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { i18n, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { NAV } from '$lib/nav';
  import { ui } from '$lib/ui.svelte';
  import Icon from './Icon.svelte';

  interface Item {
    g: string;
    label: string;
    icon: string;
    dot?: string;
    small?: string;
    copy?: string;
    run: () => void;
  }

  let q = $state('');
  let sel = $state(0);
  let input: HTMLInputElement | undefined = $state();

  const items: Item[] = $derived.by(() => {
    const s = q.toLowerCase().trim();
    const has = (...xs: (string | null | undefined)[]) => !s || xs.some((x) => x?.toLowerCase().includes(s));
    const devs = live.devices
      .filter((d) => has(d.name, d.ip, d.ownerLabel, d.id))
      .map((d) => ({ g: t('nav.devices'), label: d.name, icon: `i-${d.type}`, dot: d.status, small: d.ip ?? undefined, copy: d.ip ?? undefined, run: () => (ui.drawer = d.id) }));
    const pages = NAV.filter((p) => has(t(p.label))).map((p) => ({ g: t('pal.pages'), label: t(p.label), icon: p.icon, run: () => goto(`${base}${p.path}`) }));
    const links = live.snap?.links ?? [];
    const svcs = links
      .filter((l) => has(l.name, l.url))
      .map((l) => ({ g: t('nav.services'), label: l.name, icon: 'i-grid', small: l.url.replace(/^https?:\/\//, ''), copy: l.url, run: () => goto(`${base}/services`) }));
    const other = i18n.lang === 'en' ? 'it' : 'en';
    const acts: Item[] = [
      { g: t('pal.actions'), label: t('pal.theme'), icon: 'i-moon', run: () => ui.toggleTheme() },
      { g: t('pal.actions'), label: t('pal.lang'), icon: 'i-net', small: t(`lang.${other}`), run: () => i18n.setLang(other) },
    ].filter((a) => has(a.label, a.small));
    return [...devs, ...pages, ...svcs, ...acts];
  });

  $effect(() => {
    if (ui.palette) {
      q = '';
      sel = 0;
      queueMicrotask(() => input?.focus());
    }
  });
  $effect(() => {
    if (sel >= items.length) sel = Math.max(0, items.length - 1);
  });

  function run(i: number, copy = false) {
    const it = items[i];
    if (!it) return;
    ui.palette = false;
    if (copy && it.copy) ui.copy(it.copy);
    else it.run();
  }
  function key(e: KeyboardEvent) {
    if (e.key === 'ArrowDown') {
      sel = Math.min(items.length - 1, sel + 1);
      e.preventDefault();
    } else if (e.key === 'ArrowUp') {
      sel = Math.max(0, sel - 1);
      e.preventDefault();
    } else if (e.key === 'Enter') run(sel, e.shiftKey);
  }
</script>

{#if ui.palette}
  <div class="pal open" role="dialog" aria-label={t('pal.search')} tabindex="-1" onclick={(e) => e.target === e.currentTarget && (ui.palette = false)} onkeydown={() => {}}>
    <div class="pal-box">
      <div class="pal-in">
        <Icon name="i-search" size={16} />
        <input bind:this={input} bind:value={q} oninput={() => (sel = 0)} onkeydown={key} placeholder={t('pal.placeholder')} autocomplete="off" aria-label={t('pal.search')} />
        <span class="kbd">Esc</span>
      </div>
      <div class="pal-list" role="listbox">
        {#each items as it, i (it.g + it.label)}
          {#if i === 0 || items[i - 1]?.g !== it.g}<div class="pal-g">{it.g}</div>{/if}
          <div class="pal-i" role="option" aria-selected={i === sel} tabindex="-1" onclick={() => run(i)} onkeydown={() => {}} onmouseenter={() => (sel = i)}>
            <Icon name={it.icon} />
            {#if it.dot}<span class="dot {it.dot}"></span>{/if}
            {it.label}
            {#if it.small}<small>{it.small}</small>{/if}
          </div>
        {:else}
          <div class="pal-g" style="padding:16px 10px">{t('pal.empty')}</div>
        {/each}
      </div>
      <div class="pal-f">
        <span><span class="kbd">↑↓</span> {t('pal.choose')}</span><span><span class="kbd">{t('common.enter')}</span> {t('pal.open')}</span><span
          ><span class="kbd">Shift {t('common.enter')}</span> {t('pal.copyIp')}</span
        >
      </div>
    </div>
  </div>
{/if}
