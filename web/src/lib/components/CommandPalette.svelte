<script lang="ts">
  // Ctrl/⌘ K (or the search field in the top bar): one index of devices,
  // people, services, pages and actions. Enter opens, Shift+Enter copies the
  // IP/address (the most common action on a phone). Opened via `ui.palette = true`.
  // Devices open /devices/[id]; people open /devices filtered by their name.
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { i18n, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import type { StatusKind } from '$lib/model';
  import { NAV } from '$lib/nav';
  import { ui } from '$lib/ui.svelte';
  import Icon from './Icon.svelte';
  import StatusMarker from './StatusMarker.svelte';

  interface Item {
    g: string;
    key: string;
    label: string;
    icon: string;
    marker?: StatusKind;
    small?: string;
    mono?: boolean;
    you?: boolean;
    copy?: string;
    run: () => void;
  }

  let q = $state('');
  let sel = $state(0);
  let input: HTMLInputElement | undefined = $state();
  let list: HTMLDivElement | undefined = $state();

  const items: Item[] = $derived.by(() => {
    const s = q.toLowerCase().trim();
    const has = (...xs: (string | null | undefined)[]) => !s || xs.some((x) => x?.toLowerCase().includes(s));
    const go = (path: string) => () => goto(`${base}${path}`);
    // without a query: your devices first, then the active ones; inactive only when searched
    const devs = live.devices
      .filter((d) => (s ? has(d.name, d.ip, d.ownerLabel, d.id) : d.active))
      .sort((a, b) => Number(b.owner === live.myOwner) - Number(a.owner === live.myOwner))
      .slice(0, s ? 50 : 8)
      .map(
        (d): Item => ({
          g: t('nav.devices'),
          key: `d-${d.id}`,
          label: d.name,
          icon: `i-${d.type}`,
          marker: d.kind,
          small: d.ip ?? undefined,
          mono: true,
          you: d.owner === live.myOwner,
          copy: d.ip ?? undefined,
          run: go(`/devices/${d.id}`),
        }),
      );
    const people = s
      ? live.people
          .filter((p) => p.devices.length > 1 && has(p.label))
          .map(
            (p): Item => ({
              g: t('pal.people'),
              key: `p-${p.key}`,
              label: p.label,
              icon: 'i-user',
              small: t('pal.personDevices', { online: p.online, count: p.devices.length }),
              run: go(`/devices?q=${encodeURIComponent(p.key)}`),
            }),
          )
      : [];
    const svcs = (live.snap?.links ?? [])
      .filter((l) => has(l.name, l.url, l.description))
      .map(
        (l): Item => ({
          g: t('pal.services'),
          key: `s-${l.url}`,
          label: l.name,
          icon: 'i-grid',
          small: l.url.replace(/^https?:\/\//, ''),
          mono: true,
          copy: l.url,
          run: go('/#services'),
        }),
      );
    const pages = [...NAV, { path: '/join', label: 'nav.join' as const, icon: 'i-join', key: '' }]
      .filter((p) => has(t(p.label)))
      .map((p): Item => ({ g: t('pal.pages'), key: `n-${p.path}`, label: t(p.label), icon: p.icon, small: p.key ? `g ${p.key}` : undefined, run: go(p.path) }));
    const other = i18n.lang === 'en' ? 'it' : 'en';
    const acts: Item[] = [
      { g: t('pal.actions'), key: 'a-theme', label: t('pal.theme'), icon: ui.isDark() ? 'i-sun' : 'i-moon', run: () => ui.toggleTheme() },
      { g: t('pal.actions'), key: 'a-lang', label: t('pal.lang'), icon: 'i-lang', small: t(`lang.${other}`), run: () => i18n.setLang(other) },
    ].filter((a) => has(a.label, a.small));
    return [...devs, ...people, ...svcs, ...pages, ...acts];
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
  function move(d: number) {
    sel = Math.max(0, Math.min(items.length - 1, sel + d));
    queueMicrotask(() => list?.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: 'nearest' }));
  }
  function key(e: KeyboardEvent) {
    if (e.key === 'ArrowDown') {
      move(1);
      e.preventDefault();
    } else if (e.key === 'ArrowUp') {
      move(-1);
      e.preventDefault();
    } else if (e.key === 'Enter') {
      e.preventDefault();
      run(sel, e.shiftKey);
    } else if (e.key === 'Escape') {
      e.stopPropagation();
      ui.palette = false;
    }
  }
</script>

{#if ui.palette}
  <div class="pal" role="presentation" onclick={(e) => e.target === e.currentTarget && (ui.palette = false)}>
    <div class="pal-box" role="dialog" aria-modal="true" aria-label={t('pal.search')}>
      <div class="pal-in">
        <Icon name="i-search" size={18} />
        <input
          bind:this={input}
          bind:value={q}
          oninput={() => (sel = 0)}
          onkeydown={key}
          placeholder={t('pal.placeholder')}
          autocomplete="off"
          spellcheck="false"
          role="combobox"
          aria-expanded="true"
          aria-controls="pal-list"
          aria-activedescendant={items[sel] ? `pal-${sel}` : undefined}
          aria-label={t('pal.search')}
        />
        <button class="btn ghost sm show-mobile" onclick={() => (ui.palette = false)}>{t('common.close')}</button>
        <span class="kbd hide-mobile">Esc</span>
      </div>
      <div class="pal-list" id="pal-list" role="listbox" bind:this={list}>
        {#each items as it, i (it.key)}
          {#if i === 0 || items[i - 1]?.g !== it.g}<div class="pal-g" role="presentation">{it.g}</div>{/if}
          <div
            class="pal-i"
            id="pal-{i}"
            role="option"
            aria-selected={i === sel}
            tabindex="-1"
            onclick={(e) => run(i, e.shiftKey)}
            onkeydown={() => {}}
            onmousemove={() => (sel = i)}
          >
            <Icon name={it.icon} />
            {#if it.marker}<StatusMarker kind={it.marker} />{/if}
            <span class="ellipsis">{it.label}</span>
            {#if it.you}<span class="you-tag">{t('common.you')}</span>{/if}
            {#if it.small}<span class="pal-small" class:mono={it.mono}>{it.small}</span>{/if}
          </div>
        {:else}
          <div class="empty"><Icon name="i-search" size={20} /><div><b>{t('pal.empty')}</b><p>{t('pal.emptyText')}</p></div></div>
        {/each}
      </div>
      <div class="pal-f">
        <span><span class="kbd">↑↓</span>{t('pal.choose')}</span>
        <span><span class="kbd">{t('common.enter')}</span>{t('pal.open')}</span>
        <span><span class="kbd">Shift {t('common.enter')}</span>{t('pal.copyIp')}</span>
      </div>
    </div>
  </div>
{/if}
