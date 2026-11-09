<script lang="ts">
  // Home, "Find My" style: the map fills the page and a sheet floats on its
  // left (desktop) or sits under it (phone, < 768px).
  //   sheet: hello + one verdict sentence · your device + copy your address ·
  //   "8 of 11 online" · the admin's to-do (folded) · People / Services / Activity
  //   map: hub in the middle, one island per person ($lib/map/islands.ts)
  // A device picked on the map or in the lists opens in the sheet (?d=<id>,
  // shareable); Esc or "‹ People" goes back. The full technical page stays at
  // /devices/[id] ("All details").
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { page } from '$app/state';
  import { tick } from 'svelte';
  import type { QuickLink } from '$shared/api';
  import Button from '$lib/components/Button.svelte';
  import DeviceSheet from '$lib/components/DeviceSheet.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import PeopleMap from '$lib/components/PeopleMap.svelte';
  import Skeleton from '$lib/components/Skeleton.svelte';
  import StatusMarker from '$lib/components/StatusMarker.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { type Device, EVENT_META, elapsed, eventText, hhmm, pct, type StatusKind, timeAgo, toDevice } from '$lib/model';
  import { ui } from '$lib/ui.svelte';

  const my = $derived(live.myDevice);
  const links = $derived(live.snap?.links ?? []);
  const c = $derived(live.status.counts);
  const zt = $derived(live.snap?.health?.zt);
  const hubSlow = $derived(!!(zt?.tcpFallback || zt?.forceTcpRelay));

  // ---- the verdict about you, in plain words
  const hero = $derived.by(() => {
    if (!my) return null;
    switch (my.kind) {
      case 'offline':
        return { title: t('fm.offTitle'), line: t('me.off', { d: elapsed(my.node.lastSeen, live.now) }) };
      case 'fault':
        return { title: t('fm.faultTitle'), line: t('fm.faultExplain') };
      case 'relay':
        return { title: t('fm.connected'), line: t('fm.relayLine') };
      case 'direct-lan':
        return { title: t('fm.connected'), line: t('fm.lanLine') };
      default:
        return { title: t('fm.connected'), line: t('fm.directLine') };
    }
  });

  // ---- people: every device, online first
  const people = $derived(
    live.people
      .filter((p) => p.devices.length)
      .map((p) => ({
        ...p,
        devices: p.devices.slice().sort((a, b) => Number(b.status !== 'off') - Number(a.status !== 'off') || a.name.localeCompare(b.name)),
      })),
  );
  const word = (d: Device) => (d.status === 'off' ? timeAgo(d.node.lastSeen, live.now) : t(`fm.w.${d.kind}`));

  // ---- services
  function reach(l: QuickLink): { kind: StatusKind; label: string } {
    if (l.up == null) return { kind: 'unknown', label: t('fm.svcChecking') };
    if (l.up) return { kind: 'direct-wan', label: t('fm.svcOk') };
    return { kind: 'fault', label: t('fm.svcDown') };
  }

  // ---- activity
  const latest = $derived(live.events.slice(0, 8));
  const known = (id: string | null) => !!id && live.nodes.some((n) => n.id === id);

  // ---- things only the admin can act on (folded by default)
  interface Decision {
    key: string;
    href: string;
    marker?: StatusKind;
    icon?: string;
    title: string;
    sub: string;
  }
  const decisions = $derived.by(() => {
    const out: Decision[] = [];
    const p = live.pending;
    if (p.length) {
      out.push({
        key: 'pending',
        href: `${base}/activity?f=join`,
        icon: 'i-key',
        title: t('alerts.pending', { count: p.length }),
        sub: `${p
          .slice(0, 2)
          .map((x) => x.name ?? x.id)
          .join(', ')}${p.length > 2 ? ' …' : ''}. ${t('alerts.approveHint')}`,
      });
    }
    const net = `${base}/network`;
    if (zt?.tcpFallback) out.push({ key: 'tcp', href: net, marker: 'relay', title: t('alerts.tcpFallback'), sub: t('alerts.tcpFallbackText') });
    if (zt?.forceTcpRelay) out.push({ key: 'force', href: net, marker: 'relay', title: t('alerts.forceTcp'), sub: t('alerts.forceTcpText') });
    if (zt?.portMapping === false) out.push({ key: 'upnp', href: net, marker: 'relay', title: t('alerts.portMapping'), sub: t('alerts.portMappingText') });
    const half = live.devices.filter((x) => x.kind === 'fault');
    if (half.length > 2) {
      out.push({ key: 'half', href: `${base}/devices`, marker: 'fault', title: t('home.halfOpenMany', { count: half.length }), sub: half.map((d) => d.name).join(', ') });
    } else {
      for (const d of half) out.push({ key: `half-${d.id}`, href: hrefWith(d.id), marker: 'fault', title: t('home.halfOpen', { name: d.name }), sub: t('home.halfOpenSub') });
    }
    for (const l of links.filter((x) => x.up === false)) {
      out.push({
        key: `svc-${l.url}`,
        href: hrefWith(null, { tab: 'services' }),
        marker: 'fault',
        title: l.downSince ? t('svc.downFor', { name: l.name, d: elapsed(l.downSince, live.now) }) : t('svc.down', { name: l.name }),
        sub: l.host ? t('home.svcDownSub', { host: l.host }) : l.url,
      });
    }
    return out;
  });

  // ---- tabs (?tab=, so a link can open Services directly)
  type Tab = 'people' | 'services' | 'activity';
  const TABS: Tab[] = ['people', 'services', 'activity'];
  const tab = $derived<Tab>(((v) => (v === 'services' || v === 'activity' ? v : 'people'))(page.url.searchParams.get('tab')));
  const tabLabel = { people: 'fm.tabPeople', services: 'fm.tabServices', activity: 'fm.tabActivity' } as const;

  // ---- the device open in the sheet (?d=)
  const selId = $derived(page.url.searchParams.get('d'));
  const sel = $derived.by(() => {
    if (!selId) return null;
    const n = live.nodes.find((x) => x.id === selId);
    return n ? toDevice(n, live.receivedAt || Date.now()) : null;
  });
  function hrefWith(id: string | null, patch: Record<string, string | null> = {}) {
    const u = new URL(page.url);
    if (id) u.searchParams.set('d', id);
    else u.searchParams.delete('d');
    for (const [k, v] of Object.entries(patch)) {
      if (v) u.searchParams.set(k, v);
      else u.searchParams.delete(k);
    }
    return `${u.pathname}${u.search}`;
  }
  let sheetEl: HTMLElement | undefined = $state();
  /** what had focus when a device was opened: it gets it back on close */
  let opener: HTMLElement | null = null;
  async function select(id: string | null) {
    if (id && !selId) opener = document.activeElement as HTMLElement | null;
    await goto(hrefWith(id), { noScroll: true, keepFocus: true, replaceState: !!selId && !!id });
    await tick();
    sheetEl?.scrollTo({ top: 0 });
    // phone: the sheet is under the map, bring it into view
    const smooth = !matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (id && matchMedia('(max-width: 767px)').matches) sheetEl?.scrollIntoView({ behavior: smooth ? 'smooth' : 'auto', block: 'start' });
    if (!id) {
      const back = opener?.isConnected ? opener : document.querySelector<HTMLElement>('.seg [aria-pressed="true"]');
      back?.focus({ preventScroll: true });
      opener = null;
    }
  }
  const setTab = (v: Tab) => goto(hrefWith(selId, { tab: v === 'people' ? null : v }), { noScroll: true, keepFocus: true, replaceState: true });

  function onkey(e: KeyboardEvent) {
    if (e.key !== 'Escape' || !selId || e.defaultPrevented) return;
    if ((e.target as HTMLElement).closest('input, textarea, select') || document.querySelector('.menu, .pal')) return;
    e.preventDefault();
    select(null);
  }

  // desktop: the map's free area starts right of the sheet
  let wide = $state(true);
  $effect(() => {
    const mq = matchMedia('(min-width: 768px)');
    wide = mq.matches;
    const on = () => (wide = mq.matches);
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  });
</script>

<svelte:window onkeydown={onkey} />

<h1 class="sr-only">{t('nav.home')}</h1>

<div class="fm">
  <aside class="sheet" bind:this={sheetEl} aria-label={sel ? sel.name : t('nav.home')}>
    <span class="grabber" aria-hidden="true"></span>
    {#if sel}
      <DeviceSheet d={sel} you={sel.id === my?.id} back={t(tabLabel[tab])} onclose={() => select(null)} />
    {:else}
      <!-- hello + verdict -->
      {#if !live.snap}
        <div class="hero" aria-busy="true"><Skeleton width="40%" height={14} /><Skeleton width="70%" height={32} /><Skeleton height={40} /></div>
      {:else if my && hero}
        <div class="hero">
          <p class="eyebrow">{t('fm.hello', { name: my.ownerLabel })}</p>
          <h2 class="large">{hero.title}</h2>
          <p class="line">{hero.line}</p>
        </div>

        <div class="group you">
          <div class="you-top">
            <span class="you-ic"><Icon name="i-{my.type}" size={20} /></span>
            <span class="you-t">
              <b class="ellipsis">{my.name}<span class="tag-you">{t('common.you')}</span></b>
              <span class="status k-{my.kind}"><i class="dot"></i>{word(my)}</span>
              {#if my.node.uptime != null}<span class="sub">{t('fm.uptime', { pct: pct(my.node.uptime) })}</span>{/if}
            </span>
          </div>
          {#if my.ip}
            <button class="primary" onclick={() => my?.ip && ui.copy(my.ip)}>
              <Icon name="i-copy" size={16} />{t('fm.copyMine')} <span class="mono ip">{my.ip}</span>
            </button>
          {/if}
        </div>
      {:else}
        <div class="hero">
          <h2 class="large">{live.me ? t('home.notMember') : t('home.unknownYou')}</h2>
          <p class="line">
            {#if live.me}{t('home.notMemberA')} <span class="mono">{live.me.ip}</span>{t('home.notMemberB')}{:else}{t('home.unknownYouText')}{/if}
          </p>
          <div class="join"><Button href="{base}/join">{t('home.howToJoin')}<Icon name="i-arrow" size={14} /></Button></div>
        </div>
      {/if}

      <!-- who's online -->
      {#if live.snap}
        <div class="group summary">
          <p class="big num">{t('fm.onlineOf', { online: c.online, active: c.active })} <span>{t('fm.devicesOnline')}</span></p>
          <div class="bar" role="img" aria-label={t('home.barAria', { direct: c.direct, relay: c.relay, offline: c.offline })}>
            {#if c.direct}<i class="b-direct" style:flex={c.direct}></i>{/if}
            {#if c.relay}<i class="b-relay" style:flex={c.relay}></i>{/if}
            {#if c.offline}<i class="b-off" style:flex={c.offline}></i>{/if}
          </div>
          <p class="words">
            <span><b class="c-ok num">{c.direct}</b> {t('fm.wDirect')}</span>
            <span><b class="c-relay num">{c.relay}</b> {t('fm.wRelay')}</span>
            <span><b class="num">{c.offline}</b> {t('fm.wOff')}</span>
          </p>
        </div>
      {/if}

      <!-- the admin's to-do, folded -->
      {#if decisions.length}
        <details class="group attn">
          <summary class="row">
            <span class="ico warn"><Icon name="i-warn" size={18} /></span>
            <span class="main">
              <span class="t">{t('fm.admin', { count: decisions.length })}</span>
              <span class="s ellipsis">{decisions.map((x) => x.title).join(' · ')}</span>
            </span>
            <span class="chev"><Icon name="i-chev" size={14} /></span>
          </summary>
          {#each decisions as x (x.key)}
            <a class="row" href={x.href}>
              <span class="mini">{#if x.marker}<StatusMarker kind={x.marker} />{:else if x.icon}<Icon name={x.icon} size={14} />{/if}</span>
              <span class="main"><span class="t wrap">{x.title}</span><span class="s">{x.sub}</span></span>
            </a>
          {/each}
        </details>
      {/if}

      <!-- People / Services / Activity -->
      <div class="seg" role="group" aria-label={t('nav.home')} style:--i={TABS.indexOf(tab)}>
        <span class="thumb" aria-hidden="true"></span>
        {#each TABS as v (v)}
          <button aria-pressed={tab === v} onclick={() => setTab(v)}>{t(tabLabel[v])}</button>
        {/each}
      </div>

      {#if tab === 'people'}
        {#if !live.snap}
          <div class="group"><div class="row"><Skeleton height={32} /></div><div class="row"><Skeleton height={32} /></div></div>
        {/if}
        {#each people as p (p.key)}
          {@const mine = p.key === live.myOwner}
          <div class="section-h">
            <span class="avatar" class:me={mine}>{p.label.slice(0, 1).toUpperCase()}</span>
            <span class="ellipsis">{p.label}</span>
            {#if mine}<span class="me-word">· {t('common.you')}</span>{/if}
            {#if p.devices.length > 1}<span class="sub num">{t('fm.ofOnline', { online: p.devices.filter((d) => d.status !== 'off').length, count: p.devices.length })}</span>{/if}
          </div>
          <div class="group">
            {#each p.devices as d (d.id)}
              <button class="row" class:dim={d.status === 'off'} onclick={() => select(d.id)}>
                <span class="ico"><Icon name="i-{d.type}" size={18} /></span>
                <span class="main"><span class="t">{d.name}{#if d.id === my?.id}<span class="tag-you">{t('common.you')}</span>{/if}</span></span>
                <span class="status k-{d.kind}"><i class="dot"></i>{word(d)}</span>
                <span class="chev"><Icon name="i-chev" size={14} /></span>
              </button>
            {/each}
          </div>
        {/each}
      {:else if tab === 'services'}
        {#if links.length}
          <div class="group">
            {#each links as l (l.url)}
              {@const r = reach(l)}
              <div class="row">
                <span class="ico letter" aria-hidden="true">{l.name.slice(0, 1).toUpperCase()}</span>
                <span class="main">
                  <span class="t">{l.description ?? l.name}</span>
                  <span class="s"><span class="status k-{r.kind}"><i class="dot"></i>{r.label}</span>{#if l.description} · {l.name}{/if}</span>
                </span>
                <a class="open" href={l.url} target="_blank" rel="noopener noreferrer">{t('common.open')}</a>
              </div>
            {/each}
          </div>
          <p class="foot">{t('fm.svcFoot')}</p>
        {:else}
          <p class="foot">{t('home.svcEmptyText')}</p>
        {/if}
      {:else}
        {#if latest.length}
          <div class="group">
            {#each latest as e (`${e.t}-${e.kind}-${e.id}`)}
              {@const tx = eventText(e)}
              {#if known(e.id)}
                <button class="row ev" onclick={() => e.id && select(e.id)}>
                  <time class="time">{hhmm(e.t)}</time><StatusMarker kind={EVENT_META[e.kind].marker} /><span class="main"><span class="t wrap">{tx.title}</span></span>
                </button>
              {:else}
                <a class="row ev" href="{base}/activity">
                  <time class="time">{hhmm(e.t)}</time><StatusMarker kind={EVENT_META[e.kind].marker} /><span class="main"><span class="t wrap">{tx.title}</span></span>
                </a>
              {/if}
            {/each}
          </div>
        {:else}
          <p class="foot">{t('home.noEvents')}</p>
        {/if}
        <p class="foot"><a href="{base}/activity">{t('home.allActivity')}</a></p>
      {/if}
    {/if}
  </aside>

  <section class="map" aria-label={t('map.aria')}>
    <PeopleMap
      devices={live.devices}
      hub={live.hub}
      me={live.myOwner}
      myId={my?.id ?? null}
      selected={selId}
      onselect={(id) => select(id === selId ? null : id)}
      slow={hubSlow}
      inset={wide ? { left: 432, top: 68, bottom: 48 } : { bottom: 32 }}
    />
    <p class="note" aria-hidden="true">
      <span><svg width="18" height="6"><path class="lg direct" d="M1 3h16" /></svg>{t('fm.w.direct-wan')}</span>
      <span><svg width="18" height="6"><path class="lg relay" d="M1 3h16" /></svg>{t('fm.w.relay')}</span>
      <span><svg width="18" height="6"><path class="lg oneway" d="M1 3h16" /></svg>{t('fm.w.fault')}</span>
      <span><i class="lg-off"></i>{t('fm.w.offline')}</span>
    </p>
  </section>
</div>

<style>
  /* the map fills the whole window, under the floating nav pill too; the
     sheet floats on it, below the pill */
  .fm {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: var(--tabbar-h);
  }
  .map {
    position: absolute;
    inset: 0;
  }
  .note {
    position: absolute;
    right: 16px;
    bottom: 16px;
    margin: 0;
    display: flex;
    align-items: center;
    gap: 16px;
    height: 32px;
    padding: 0 12px;
    border-radius: var(--r-full);
    background: var(--tray);
    color: var(--text-2);
    font: 500 12px/16px var(--font);
    pointer-events: none;
  }
  .lg-off {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    box-shadow: inset 0 0 0 1.5px var(--off);
  }
  .note span {
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }
  .lg {
    fill: none;
    stroke-width: 2;
    stroke-linecap: round;
  }
  .lg.direct {
    stroke: var(--ok-fg);
  }
  .lg.relay {
    stroke: var(--relay-fg);
    stroke-dasharray: 1 5;
  }
  .lg.oneway {
    stroke: var(--err);
    stroke-dasharray: 5 4;
  }

  .sheet {
    position: absolute;
    z-index: 2;
    top: var(--topbar-h);
    left: 16px;
    bottom: 16px;
    width: 400px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 24px 16px;
    overflow-y: auto;
    overscroll-behavior: contain;
    border-radius: var(--r-xl);
    background: var(--tray);
    scrollbar-width: thin;
    scrollbar-color: var(--line-strong) transparent;
  }
  .grabber {
    display: none;
  }

  /* hero */
  .hero {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 0 8px;
  }
  .hero p,
  .hero h2 {
    margin: 0;
  }
  .eyebrow {
    color: var(--text-3);
    font: 500 12px/1.3 var(--font);
  }
  .large {
    font: 600 30px/1.1 var(--font);
    letter-spacing: -0.025em;
  }
  .line {
    color: var(--text-2);
    font-size: 15px;
    line-height: 1.4;
  }
  .join {
    margin-top: 8px;
  }

  /* grouped lists */
  .group {
    flex-shrink: 0;
    overflow: hidden;
    border-radius: var(--r-lg);
    background: var(--raised);
  }
  .row {
    position: relative;
    display: flex;
    align-items: center;
    gap: 12px;
    width: 100%;
    min-height: 52px;
    padding: 12px 16px;
    border: 0;
    background: none;
    color: var(--text);
    font: inherit;
    text-align: left;
    text-decoration: none;
    transition: background var(--d-fast);
  }
  .row + .row::before {
    content: '';
    position: absolute;
    top: 0;
    right: 0;
    left: 60px;
    border-top: 0.5px solid var(--line);
  }
  button.row,
  a.row,
  summary.row {
    cursor: pointer;
  }
  button.row:hover,
  a.row:hover,
  summary.row:hover {
    background: var(--tint);
  }
  button.row:active {
    background: var(--tint-strong);
  }
  /* rows sit in clipped groups: keep the focus ring inside */
  button.row:focus-visible,
  a.row:focus-visible,
  summary.row:focus-visible {
    outline-offset: -2px;
    border-radius: inherit;
  }
  .ico {
    display: grid;
    place-items: center;
    flex: none;
    width: 32px;
    height: 32px;
    border-radius: 8px;
    background: var(--tint);
    color: var(--text-2);
  }
  .ico.letter {
    font-weight: 600;
    font-size: 14px;
  }
  .ico.warn {
    background: var(--relay-bg);
    color: var(--relay-fg);
  }
  .main {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-width: 0;
  }
  .t {
    overflow: hidden;
    font: 500 15px/1.25 var(--font);
    white-space: nowrap;
    text-overflow: ellipsis;
  }
  .t.wrap {
    white-space: normal;
  }
  .s {
    margin-top: 1px;
    color: var(--text-3);
    font-size: 13px;
    line-height: 1.35;
  }
  .row.dim .t {
    color: var(--text-3);
  }
  .row.dim .ico {
    opacity: 0.55;
  }
  .chev {
    display: inline-flex;
    flex: none;
    color: var(--text-4);
    transition: transform var(--d-base) var(--ease);
  }
  .tag-you {
    margin-left: 6px;
    padding: 3px 6px;
    border-radius: var(--r-full);
    background: var(--you-bg);
    color: var(--you-fg);
    font: 600 11px/1 var(--font);
    text-transform: capitalize;
    vertical-align: 2px;
  }

  /* status: one dot + one word */
  .status {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    flex: none;
    color: var(--c-fg, var(--text-3));
    font: 500 13px/1 var(--font);
    white-space: nowrap;
  }
  .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--c, var(--off));
  }
  .k-direct-lan,
  .k-direct-wan {
    --c: var(--ok);
    --c-fg: var(--ok-fg);
  }
  .k-relay {
    --c: var(--relay);
    --c-fg: var(--relay-fg);
  }
  .k-fault {
    --c: var(--err);
    --c-fg: var(--err-fg);
  }
  .k-offline,
  .k-unknown {
    --c: var(--off);
    --c-fg: var(--text-3);
  }
  .k-offline .dot,
  .k-unknown .dot {
    background: transparent;
    box-shadow: inset 0 0 0 1.5px var(--off);
  }

  /* you */
  .you {
    padding: 16px;
  }
  .you-top {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .you-ic {
    display: grid;
    place-items: center;
    flex: none;
    width: 40px;
    height: 40px;
    border-radius: 12px;
    background: var(--you-bg);
    color: var(--you-fg);
  }
  .you-t {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-width: 0;
  }
  .you-t b {
    font: 600 16px/1.25 var(--font);
  }
  .sub {
    color: var(--text-3);
    font-size: 13px;
  }
  .you-t {
    gap: 4px;
  }
  .primary {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    width: 100%;
    height: 44px;
    margin-top: 16px;
    border: 0;
    border-radius: 12px;
    background: var(--text);
    color: var(--canvas);
    font: 600 15px/20px var(--font);
    cursor: pointer;
    transition:
      opacity var(--d-fast),
      transform var(--d-fast) var(--ease);
  }
  .primary:hover {
    opacity: 0.9;
  }
  .primary:active {
    transform: scale(0.98);
  }
  .ip {
    opacity: 0.7;
    font-size: 13px;
    font-weight: 500;
  }

  /* summary */
  .summary {
    padding: 16px;
  }
  .summary p {
    margin: 0;
  }
  .big {
    font: 600 17px/1.2 var(--font);
  }
  .big span {
    color: var(--text-3);
    font-weight: 450;
  }
  .bar {
    display: flex;
    gap: 3px;
    height: 8px;
    margin: 12px 0 10px;
  }
  .bar i {
    border-radius: 3px;
  }
  .b-direct {
    background: var(--ok);
  }
  .b-relay {
    background: var(--relay);
  }
  .b-off {
    background: var(--tint-strong);
  }
  .words {
    display: flex;
    flex-wrap: wrap;
    gap: 14px;
    color: var(--text-3);
    font-size: 13px;
  }
  .words b {
    color: var(--text);
    font-weight: 600;
  }
  .words .c-ok {
    color: var(--ok-fg);
  }
  .words .c-relay {
    color: var(--relay-fg);
  }

  /* admin */
  .attn summary {
    list-style: none;
  }
  .attn summary::-webkit-details-marker {
    display: none;
  }
  .attn[open] summary .chev {
    transform: rotate(90deg);
  }
  .attn .row + .row::before,
  .attn summary + .row::before {
    content: '';
    position: absolute;
    top: 0;
    right: 0;
    left: 60px;
    border-top: 0.5px solid var(--line);
  }
  .mini {
    display: inline-flex;
    justify-content: center;
    flex: none;
    width: 32px;
    color: var(--text-3);
  }

  /* segmented control with a sliding thumb */
  .seg {
    position: relative;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    flex-shrink: 0;
    margin-top: 8px;
    padding: 2px;
    border-radius: 10px;
    background: var(--tint);
  }
  .seg button {
    position: relative;
    z-index: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    height: 30px;
    padding: 0 8px;
    border: 0;
    border-radius: 8px;
    background: none;
    color: var(--text-2);
    font: 500 13px/1 var(--font);
    cursor: pointer;
  }
  .seg button[aria-pressed='true'] {
    color: var(--text);
    font-weight: 600;
  }
  .thumb {
    position: absolute;
    top: 2px;
    bottom: 2px;
    left: 2px;
    width: calc((100% - 4px) / 3);
    border-radius: 8px;
    background: var(--thumb);
    transform: translateX(calc(var(--i) * 100%));
    transition: transform var(--d-slow) var(--ease);
  }

  /* people */
  .section-h {
    display: flex;
    align-items: center;
    gap: 10px;
    margin: 8px 8px -8px;
    font: 600 15px/1.3 var(--font);
  }
  .avatar {
    display: grid;
    place-items: center;
    flex: none;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: var(--tint-strong);
    color: var(--text-2);
    font: 650 12px/1 var(--font);
  }
  .avatar.me {
    background: var(--you-bg);
    color: var(--you-fg);
  }
  .me-word {
    color: var(--you-fg);
    font: 400 13px/1 var(--font);
  }
  .section-h .sub {
    margin-left: auto;
    font-weight: 400;
    white-space: nowrap;
  }

  .foot {
    margin: -8px 8px 0;
    color: var(--text-3);
    font-size: 13px;
    line-height: 1.4;
  }
  .foot a {
    color: inherit;
  }
  .foot a:hover {
    color: var(--text);
  }
  .open {
    flex: none;
    padding: 8px 14px;
    border-radius: var(--r-full);
    background: var(--tint);
    color: var(--text);
    font: 600 13px/1 var(--font);
    text-decoration: none;
  }
  .open:hover {
    background: var(--tint-strong);
  }
  .ev {
    min-height: 46px;
  }
  .ev .t {
    font-weight: 450;
  }
  .time {
    flex: none;
    width: 40px;
    color: var(--text-3);
    font: 500 12.5px/1 var(--mono);
  }
  .ev + .ev::before {
    left: 14px;
  }

  @media (prefers-reduced-motion: reduce) {
    .thumb,
    .chev,
    .primary {
      transition: none;
    }
  }

  /* phone: map on top, the sheet under it */
  @media (max-width: 767px) {
    .fm {
      position: static;
      display: flex;
      flex-direction: column;
      margin: -24px calc(-1 * var(--page-x)) 0;
    }
    .map {
      position: relative;
      height: 56vh;
      min-height: 320px;
      order: -1;
    }
    .note {
      right: 12px;
      bottom: 36px;
      gap: 10px;
    }
    .sheet {
      position: relative;
      top: auto;
      left: auto;
      bottom: auto;
      width: auto;
      margin-top: -24px;
      padding: 8px 16px 24px;
      overflow: visible;
      border-radius: var(--r-xl) var(--r-xl) 0 0;
      background: var(--tray);
      scroll-margin-top: calc(var(--topbar-h) + 8px);
    }
    .grabber {
      display: block;
      width: 38px;
      height: 5px;
      margin: 0 auto 6px;
      border-radius: 3px;
      background: var(--line-strong);
    }
    .large {
      font-size: 28px;
    }
  }
</style>
