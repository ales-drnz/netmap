<script lang="ts">
  // The device as the Home sheet shows it (Find My style): a big icon with the
  // status ring, one verdict word, one plain sentence, "copy address", then
  // connection / speed / seen, the last 24 h, and the technical details
  // folded away. The full technical page stays at /devices/[id].
  //
  //   <DeviceSheet d={device} you={isMine} back={t('fm.tabPeople')} onclose={…} />
  import { base } from '$app/paths';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { type Device, pct, timeAgo } from '$lib/model';
  import { ui } from '$lib/ui.svelte';
  import AvailabilityTrack from './AvailabilityTrack.svelte';
  import Icon from './Icon.svelte';

  let { d, you = false, back, onclose }: { d: Device; you?: boolean; back: string; onclose: () => void } = $props();

  const off = $derived(d.status === 'off');
  const explain = $derived.by(() => {
    switch (d.kind) {
      case 'offline':
        return t('fm.offExplain', { ago: timeAgo(d.node.lastSeen, live.now) });
      case 'fault':
        return t('fm.faultExplain');
      case 'relay':
        return t('me.relay');
      case 'direct-lan':
        return t('me.lan');
      case 'direct-wan':
        return t('me.direct');
      default:
        return '';
    }
  });
  const speed = (ms: number) => (ms < 50 ? t('fm.fast') : ms < 120 ? t('fm.good') : t('fm.slowSpeed'));
  const seen = $derived.by(() => {
    const s = off ? timeAgo(d.node.lastSeen, live.now) : t('time.now');
    return s.slice(0, 1).toUpperCase() + s.slice(1);
  });

  // focus the title when a DIFFERENT device opens (not on every live update:
  // `d` is rebuilt each refresh, and stealing focus back would trap keyboard users)
  let title: HTMLHeadingElement | undefined = $state();
  const did = $derived(d.id);
  $effect(() => {
    void did;
    title?.focus({ preventScroll: true });
  });
</script>

<article class="ds k-{d.kind}" aria-labelledby="ds-title">
  <div class="nav">
    <button class="back" onclick={onclose}><Icon name="i-back" size={16} />{back}</button>
    <button class="close" onclick={onclose} aria-label={t('detail.close')}><Icon name="i-x" size={14} /></button>
  </div>

  <header class="head">
    <span class="big"><Icon name="i-{d.type}" size={32} /></span>
    <h2 id="ds-title" tabindex="-1" bind:this={title}>{d.name}</h2>
    <p class="owner">
      {t('fm.owner', { name: d.ownerLabel })}{#if you}&nbsp;· <b class="me">{t('fm.thisDevice')}</b>{/if}
    </p>
    <span class="verdict"><i class="dot"></i>{t(`fm.w.${d.kind}`)}</span>
    {#if explain}<p class="explain">{explain}</p>{/if}
  </header>

  {#if d.ip && !off}
    <button class="primary" onclick={() => d.ip && ui.copy(d.ip)}>
      <Icon name="i-copy" size={16} />{t('fm.copy')} <span class="mono ip">{d.ip}</span>
    </button>
  {/if}

  {#if !off}
    <div class="group">
      <div class="pair"><span class="k">{t('fm.connection')}</span><span class="v">{t(`fm.how.${d.kind}`)}</span></div>
      <div class="pair">
        <span class="k">{t('fm.speed')}</span>
        <span class="v">
          {#if d.median != null}{speed(d.median)}<span class="q num">{d.median} ms</span>{:else}{t('fm.slower')}<span class="q">{t('fm.notMeasured')}</span>{/if}
        </span>
      </div>
      <div class="pair"><span class="k">{t('fm.seen')}</span><span class="v">{seen}</span></div>
    </div>
  {/if}

  <div class="group avail">
    <div class="avail-h">
      <span>{t('fm.avail')}</span>
      <b class="num">{d.node.uptime != null ? pct(d.node.uptime) : '—'}</b>
    </div>
    <AvailabilityTrack values={d.node.beats} now={live.now} height={24} axis label={t('fm.avail')} />
  </div>

  <details class="group tech">
    <summary><span>{t('fm.tech')}</span><Icon name="i-chev" size={14} /></summary>
    {#if d.ip}<div class="pair"><span class="k">{t('fm.ip')}</span><span class="v mono">{d.ip}</span></div>{/if}
    <div class="pair"><span class="k">{t('fm.version')}</span><span class="v mono">{d.node.version ?? '—'}</span></div>
    <div class="pair"><span class="k">{t('fm.nodeId')}</span><span class="v mono">{d.id}</span></div>
    <a class="pair more" href="{base}/devices/{encodeURIComponent(d.id)}"><span>{t('fm.allDetails')}</span><Icon name="i-chev" size={14} /></a>
  </details>
</article>

<style>
  .ds {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .k-direct-lan,
  .k-direct-wan {
    --c: var(--ok);
    --c-fg: var(--ok-fg);
    --c-bg: var(--ok-bg);
  }
  .k-relay {
    --c: var(--relay);
    --c-fg: var(--relay-fg);
    --c-bg: var(--relay-bg);
  }
  .k-fault {
    --c: var(--err);
    --c-fg: var(--err-fg);
    --c-bg: var(--err-bg);
  }
  .k-offline,
  .k-unknown {
    --c: var(--off);
    --c-fg: var(--text-3);
    --c-bg: var(--off-bg);
  }

  .nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin: -8px 0 0;
  }
  .back {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 8px 6px;
    border: 0;
    border-radius: var(--r-md);
    background: none;
    color: var(--text-2);
    font: 500 15px/1 var(--font);
    cursor: pointer;
  }
  .back:hover {
    color: var(--text);
  }
  .close {
    display: grid;
    place-items: center;
    position: relative;
    width: 30px;
    height: 30px;
    border: 0;
    border-radius: 50%;
    background: var(--tint);
    color: var(--text-3);
    cursor: pointer;
  }
  /* a 44px tap area around the small round button */
  .close::after {
    content: '';
    position: absolute;
    inset: -7px;
  }

  .head {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    padding: 4px 8px 4px;
  }
  .big {
    display: grid;
    place-items: center;
    width: 80px;
    height: 80px;
    margin-bottom: 16px;
    border-radius: 50%;
    background: color-mix(in srgb, var(--c) 18%, var(--raised));
    color: var(--c-fg);
  }
  h2 {
    margin: 0;
    font: 600 26px/1.15 var(--font);
    letter-spacing: -0.02em;
    word-break: break-word;
    outline: none;
  }
  .owner {
    margin: 4px 0 0;
    color: var(--text-3);
    font-size: 13px;
  }
  .me {
    color: var(--you-fg);
    font-weight: 600;
  }
  .verdict {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    margin-top: 12px;
    padding: 6px 12px;
    border-radius: var(--r-full);
    background: var(--c-bg);
    color: var(--c-fg);
    font: 600 13px/16px var(--font);
  }
  .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--c);
  }
  .k-offline .dot {
    background: transparent;
    box-shadow: inset 0 0 0 1.5px var(--off);
  }
  .explain {
    max-width: 304px;
    margin: 12px auto 0;
    color: var(--text-2);
    font-size: 15px;
    line-height: 20px;
    text-wrap: pretty;
  }

  .primary {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    height: 44px;
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

  .group {
    overflow: hidden;
    border-radius: var(--r-lg);
    background: var(--raised);
  }
  .pair {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    min-height: 48px;
    padding: 12px 16px;
    font-size: 15px;
    line-height: 20px;
  }
  .pair + .pair::before,
  .tech summary + .pair::before {
    content: '';
    position: absolute;
    top: 0;
    left: 16px;
    right: 0;
    border-top: 0.5px solid var(--line);
  }
  .k {
    color: var(--text-2);
  }
  .v {
    font-weight: 500;
    text-align: right;
    min-width: 0;
    overflow-wrap: anywhere;
  }
  .q {
    margin-left: 6px;
    color: var(--text-3);
    font-weight: 400;
  }
  .mono {
    font-family: var(--mono);
    font-size: 13px;
  }

  .avail {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 16px;
  }
  .avail-h {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    color: var(--text-2);
  }
  .avail-h b {
    color: var(--text);
    font: 600 22px/1 var(--font);
    letter-spacing: -0.02em;
  }

  .tech summary {
    display: flex;
    align-items: center;
    justify-content: space-between;
    min-height: 48px;
    padding: 0 16px;
    color: var(--text-2);
    cursor: pointer;
    list-style: none;
  }
  .tech summary::-webkit-details-marker {
    display: none;
  }
  /* inside a clipped group: keep the focus ring visible */
  .tech summary:focus-visible,
  .more:focus-visible {
    outline-offset: -2px;
  }
  .tech summary :global(svg),
  .more :global(svg) {
    color: var(--text-4);
    transition: transform var(--d-base) var(--ease);
  }
  .tech[open] summary :global(svg) {
    transform: rotate(90deg);
  }
  .more {
    color: var(--text);
    text-decoration: none;
  }
  .more:hover {
    background: var(--tint);
  }
</style>
