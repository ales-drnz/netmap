<script lang="ts">
  // Network: hub health, configuration chain, performance over time (#performance).
  // 1. header (name, id, private/public, pool, local status)
  // 2. hub checks · 3. what reaches the hub (configured → received → in use)
  // 4. Performance: KPI strip, latency strip | worse than last week,
  //    24 h availability, relays, top users | network bytes
  // 5. client versions | composition, technical details (collapsed)
  // Every chart's definitions live in lib/charts/perf.ts (unit tested).
  import { page } from '$app/state';
  import CopyText from '$lib/components/CopyText.svelte';
  import KeyValueList from '$lib/components/KeyValueList.svelte';
  import NetChain from '$lib/components/NetChain.svelte';
  import NetComposition from '$lib/components/NetComposition.svelte';
  import NetHub from '$lib/components/NetHub.svelte';
  import NetVersions from '$lib/components/NetVersions.svelte';
  import PerfAvailability from '$lib/components/PerfAvailability.svelte';
  import PerfBytes from '$lib/components/PerfBytes.svelte';
  import PerfKpis from '$lib/components/PerfKpis.svelte';
  import PerfLatencyStrip from '$lib/components/PerfLatencyStrip.svelte';
  import PerfRelays from '$lib/components/PerfRelays.svelte';
  import PerfTopUsers from '$lib/components/PerfTopUsers.svelte';
  import PerfWorse from '$lib/components/PerfWorse.svelte';
  import Section from '$lib/components/Section.svelte';
  import Skeleton from '$lib/components/Skeleton.svelte';
  import StatusBadge from '$lib/components/StatusBadge.svelte';
  import { i18n, type Key, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { tick } from 'svelte';

  const net = $derived(live.snap?.net ?? null);
  const loc = $derived(live.snap?.health?.local ?? null);
  const hubName = $derived(live.hub?.name ?? t('net.thisNode'));
  const netId = $derived(live.snap?.networkId ?? '');
  const relays = $derived(live.relay.length);

  const NET_STATUS = ['OK', 'ACCESS_DENIED', 'NOT_FOUND', 'REQUESTING_CONFIGURATION', 'PORT_ERROR', 'CLIENT_TOO_OLD', 'AUTHENTICATION_REQUIRED'];
  const netStatus = (l: { status: string; statusLabel: string }) =>
    NET_STATUS.includes(l.status) ? t(`netStatus.${l.status}` as Key) : l.statusLabel;
  const v6Label = (v: string) => (v === 'managed' ? t('net.v6managed') : v);
  const yesNo = (v: boolean | null | undefined, y = t('common.yes'), n = t('common.no')) => (v == null ? null : v ? y : n);
  const created = $derived(
    net?.creationTime ? new Date(net.creationTime).toLocaleDateString(i18n.locale, { day: 'numeric', month: 'long', year: 'numeric' }) : null,
  );
  const details = $derived([
    { k: 'MTU', v: net?.mtu ?? loc?.mtu ?? null },
    { k: 'Broadcast', v: yesNo(net?.broadcast, t('common.on'), t('common.off')) },
    { k: t('net.multicast'), v: net?.multicastLimit ?? null },
    { k: 'IPv6', v: net ? (net.v6?.length ? net.v6.map(v6Label).join(', ') : t('net.v6none')) : null },
    { k: t('net.created'), v: created },
    { k: t('net.revision'), v: loc?.revision ?? null },
    { k: t('net.interface'), v: loc?.device ?? null, mono: true },
    { k: t('net.bridge'), v: loc ? yesNo(loc.bridge) : null },
  ]);

  // /stats redirects to /network#performance: the anchor exists from the first
  // render, but re-scroll once the data has laid the page out
  let scrolled = false;
  $effect(() => {
    if (scrolled || !live.snap || page.url.hash !== '#performance') return;
    scrolled = true;
    tick().then(() => document.getElementById('performance')?.scrollIntoView());
  });
</script>

<header class="page-h">
  <div class="title">
    <h1>{live.snap?.networkName ?? t('nav.network')}</h1>
    <div class="meta">
      {#if netId}<CopyText text={netId} />{/if}
      {#if net?.private != null}
        <span class="badge" title={net.private ? t('net.private') : t('net.public')}>{net.private ? t('net.privateShort') : t('net.publicShort')}</span>
      {/if}
      {#each net?.pools ?? [] as p (p.start)}<span class="mono text-2">{p.start} – {p.end}</span>{/each}
      {#if loc}<StatusBadge kind={loc.ok ? 'direct-wan' : 'fault'} label={t('net.statusPill', { status: netStatus(loc) })} />{/if}
    </div>
  </div>
  <div class="act"><a class="more" href="#performance">{t('perf.title')} ↓</a></div>
</header>

<div class="stack">
  {#if !live.snap}
    <Skeleton height={120} radius={12} />
    <Skeleton height={200} radius={12} />
  {:else}
    <Section title={t('net.hub')} note={t('net.serviceNote')}>
      <NetHub />
    </Section>

    <Section title={t('net.reaches', { hub: hubName })} note={t('net.reachesNote')}>
      <NetChain />
    </Section>
  {/if}

  <section id="performance" class="perf" aria-labelledby="perf-h">
    <header class="perf-h">
      <h2 id="perf-h" class="t-h2">{t('perf.title')}</h2>
      <span class="t-caption text-3">{t('perf.intro')}</span>
    </header>
    {#if !live.snap}
      <Skeleton height={96} />
    {:else}
      <PerfKpis />

      <div class="grid2">
        <Section title={t('perf.strip')} note={t('perf.stripNote', { n: live.direct.length })}>
          <PerfLatencyStrip />
        </Section>
        <Section title={t('perf.worse')} note={t('perf.worseNote')}>
          <PerfWorse />
        </Section>
      </div>

      <Section title={t('perf.avail')} note={t('perf.availNote')}>
        <PerfAvailability />
      </Section>

      <Section title={t('perf.relays')} note={relays ? t('perf.relaysNote', { count: relays }) : null}>
        <PerfRelays />
      </Section>

      <div class="grid2">
        <Section title={t('stats.top')} note={t('perf.topNote')}>
          <PerfTopUsers />
        </Section>
        <Section title={t('perf.bytes')} note={t('perf.bytesNote')}>
          <PerfBytes />
        </Section>
      </div>
    {/if}
  </section>

  {#if live.snap}
    <div class="grid2">
      <Section title={t('net.versions')} note={t('net.versionsNote')}>
        <NetVersions />
      </Section>
      <Section title={t('net.composition')} note={t('perf.compNote', { count: live.devices.length })}>
        <NetComposition />
      </Section>
    </div>

    <details class="tech">
      <summary><span class="t-h3">{t('net.technical')}</span><span class="t-caption text-3">{t('net.technicalNote')}</span></summary>
      <div class="tech-b"><KeyValueList rows={details} /></div>
    </details>
  {/if}
</div>

<style>
  .title {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-width: 0;
  }
  .meta {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 6px 14px;
  }
  .perf {
    display: flex;
    flex-direction: column;
    gap: 24px;
  }
  .perf-h {
    display: flex;
    align-items: baseline;
    flex-wrap: wrap;
    gap: 4px 12px;
    padding-top: 8px;
    margin-bottom: -8px;
  }
  .grid2 {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: var(--gap);
    align-items: start;
  }
  .tech {
    background: var(--surface);
    border-radius: var(--r-lg);
  }
  .tech summary {
    display: flex;
    align-items: baseline;
    flex-wrap: wrap;
    gap: 4px 10px;
    padding: 12px 16px;
    cursor: pointer;
    list-style: none;
  }
  .tech summary::-webkit-details-marker {
    display: none;
  }
  .tech summary::before {
    content: '';
    width: 6px;
    height: 6px;
    margin-right: 4px;
    border-right: 1.5px solid var(--text-3);
    border-bottom: 1.5px solid var(--text-3);
    transform: translateY(-2px) rotate(-45deg);
    transition: transform var(--d-fast) var(--ease);
    align-self: center;
  }
  .tech[open] summary::before {
    transform: translateY(-2px) rotate(45deg);
  }
  .tech-b {
    border-top: 1px solid var(--line);
  }
  @media (max-width: 1100px) {
    .grid2 {
      grid-template-columns: minmax(0, 1fr);
    }
  }
</style>
