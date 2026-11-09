<script lang="ts">
  // Device detail (DESIGN-v2 "Device detail"): the content of /devices/[id],
  // shown in the 440px side panel on desktop and as a full page on mobile.
  // Hairline sections, no inner cards:
  //   header (name h2 = focus target #detail-title, owner, badge, Copy IP, Show on map)
  //   one-way warning · latency · connection · last 24 h · traffic 30 days · recent events
  //   <DeviceDetail d={device} closeHref="/devices?…" mapHref="/devices/abc?view=map" />
  import type { NetEvent } from '$shared/api';
  import { i18n, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import {
    type Device,
    EVENT_META,
    dayLabel,
    elapsed,
    eventText,
    hhmm,
    packets,
    pathLabel,
    pct,
    since,
    timeAgo,
  } from '$lib/model';
  import { numbers } from '$lib/stats';
  import AvailabilityTrack from './AvailabilityTrack.svelte';
  import Button from './Button.svelte';
  import CopyButton from './CopyButton.svelte';
  import CopyText from './CopyText.svelte';
  import DeviceLatencyChart from './DeviceLatencyChart.svelte';
  import { cmpVersion } from './DevicesTable.svelte';
  import Icon from './Icon.svelte';
  import StatusBadge from './StatusBadge.svelte';
  import StatusMarker from './StatusMarker.svelte';

  let {
    d,
    closeHref,
    mapHref,
    onMap = false,
  }: {
    d: Device;
    closeHref: string;
    /** the other view of the same device: the map, or the table when already on the map */
    mapHref: string;
    onMap?: boolean;
  } = $props();

  const n = $derived(d.node);
  const now = $derived(live.now);
  const isMe = $derived(live.myDevice?.id === d.id);
  const mine = $derived(!!live.myOwner && d.owner === live.myOwner);

  // ---- latency
  const samples = $derived(numbers(n.spark ?? []));
  const l30 = $derived(n.latency30);
  const compare = $derived.by(() => {
    if (!l30 || l30.median == null || l30.prevMedian == null) return null;
    const ratio = l30.trend ?? (l30.prevMedian ? l30.median / l30.prevMedian : null);
    const change = ratio != null ? Math.round((ratio - 1) * 100) : null;
    return { recent: l30.median, prev: l30.prevMedian, change };
  });
  const changeText = (c: number) => `${c > 0 ? '+' : c < 0 ? '−' : '±'}${t('fmt.pct', { n: Math.abs(c) })}`;
  const spanMin = $derived(Math.max(1, Math.round(((n.spark?.length ?? 0) * live.pollSeconds) / 60)));

  // ---- connection
  const newest = $derived(
    live.nodes
      .map((x) => x.version)
      .filter((v): v is string => !!v)
      .sort(cmpVersion)
      .at(-1) ?? null,
  );
  const behind = $derived(!!n.version && !!newest && cmpVersion(n.version, newest) < 0);
  const lastPacket = $derived(
    n.idleSec == null ? null : n.idleSec < 90 ? t('time.sAgo', { n: Math.round(n.idleSec) }) : timeAgo(now - n.idleSec * 1000, now),
  );
  const memberSince = $derived(
    n.since
      ? `${new Date(n.since).toLocaleDateString(i18n.locale, { day: 'numeric', month: 'short', year: 'numeric' })} · ${t('detail.memberFor', { d: since(n.since, now) })}`
      : null,
  );

  // ---- traffic
  const tr = $derived(n.traffic);
  const dayMax = $derived(tr ? Math.max(1, ...tr.days) : 1);

  // ---- events: this device's own, plus incidents that name it
  const events = $derived(
    live.events
      .filter((e: NetEvent) => e.id === d.id || (e.kind === 'netdrop' && !!e.detail && e.detail.split(', ').includes(d.name)))
      .slice()
      .sort((a, b) => b.t - a.t)
      .slice(0, 8),
  );
  const when = (tm: number) => {
    const day = dayLabel(tm, now);
    return day === t('time.Today') ? hhmm(tm) : `${new Date(tm).toLocaleDateString(i18n.locale, { day: 'numeric', month: 'short' })} ${hhmm(tm)}`;
  };
</script>

<article class="dd" aria-labelledby="detail-title">
  <header class="dd-h">
    <a class="back show-mobile" href={closeHref}><Icon name="i-back" size={16} />{t('nav.devices')}</a>
    <div class="dd-title">
      <span class="dd-ic"><Icon name="i-{d.type}" size={20} /></span>
      <h2 id="detail-title" class="t-h2 ellipsis" tabindex="-1">{d.name}</h2>
      <span class="dd-close hide-mobile"><Button variant="ghost" iconOnly icon="i-x" label={t('detail.close')} href={closeHref} /></span>
    </div>
    <p class="dd-sub">
      {#if n.hub}
        <span class="tag">{t('dev.hubTag')}</span><span>{t('detail.hubSub')}</span>
      {:else}
        <span>{t('detail.owner', { name: d.ownerLabel })}</span>
        {#if isMe}<span class="you-tag">· {t('detail.youUsing')}</span>{:else if mine}<span class="you-tag">· {t('common.you')}</span>{/if}
      {/if}
    </p>
    <div class="dd-state">
      <StatusBadge kind={d.kind} detail={d.status === 'off' ? timeAgo(n.lastSeen, now) : null} />
      <span class="text-2">{d.status === 'off' ? t('detail.offlineFor', { d: elapsed(n.lastSeen, now) }) : d.status === 'relay' ? t('detail.noDirect') : pathLabel(d)}</span>
    </div>
    <div class="dd-act">
      {#if d.ip}<CopyButton text={d.ip} label={t('detail.copyIp', { ip: d.ip })} />{/if}
      <Button href={mapHref} icon={onMap ? 'i-list' : 'i-map'}>{onMap ? t('detail.showInTable') : t('detail.showOnMap')}</Button>
    </div>
  </header>

  {#if n.halfOpen}
    <div class="warn" role="alert">
      <StatusMarker kind="fault" size={10} />
      <div>
        <b>{t('detail.halfOpen')}</b>
        <p>{n.idleSec != null ? t('detail.halfOpenText', { d: n.idleSec < 90 ? t('time.sec', { n: Math.round(n.idleSec) }) : elapsed(now - n.idleSec * 1000, now) }) : t('detail.halfOpenTextNoIdle')}</p>
      </div>
    </div>
  {/if}

  <section class="dd-s" aria-labelledby="dd-lat">
    <h3 id="dd-lat" class="dd-s-h">{t('dev.thLatency')}</h3>
    {#if n.hub}
      <p class="text-2 lat-none">{t('detail.hubLatency')}</p>
    {:else if d.median != null}
      <div class="lat">
        <div class="lat-now">
          <span class="t-num-l">{d.median}</span><span class="lat-unit">ms</span>
          <span class="t-caption text-3 lat-cap">{t('detail.medianOf', { min: spanMin })}</span>
        </div>
        <p class="lat-cmp t-caption">
          {#if compare}
            {t('detail.recent2d', { ms: compare.recent })} · {t('detail.prevWeek', { ms: compare.prev })}
            {#if compare.change != null}<b class="num">({changeText(compare.change)})</b>{/if}
            {#if l30?.p95 != null}<span class="text-3"> · p95 {l30.p95} ms</span>{/if}
          {:else}
            <span class="text-3">{t('detail.needWeek', { count: l30?.samples ?? samples.length })}</span>
          {/if}
        </p>
      </div>
    {:else}
      <p class="text-2 lat-none">
        {d.status === 'relay' ? t('detail.noLatencyRelay') : d.status === 'off' ? t('detail.noLatencyOff') : t('detail.noLatency')}
      </p>
    {/if}
    {#if samples.length && !n.hub}
      <DeviceLatencyChart values={n.spark} stepSec={live.pollSeconds} label={t('detail.chartAria', { name: d.name })} />
    {/if}
  </section>

  <section class="dd-s" aria-labelledby="dd-conn">
    <h3 id="dd-conn" class="dd-s-h">{t('detail.connection')}</h3>
    <dl class="kv flush">
      <div><dt>{t('detail.path')}</dt><dd>{pathLabel(d)}</dd></div>
      <div>
        <dt>{t('detail.ips', { count: n.ips.length })}</dt>
        <dd class="ips">{#each n.ips as ip (ip)}<CopyText text={ip} />{:else}—{/each}</dd>
      </div>
      <div>
        <dt>{t('detail.paths')}</dt>
        <dd>
          {#if n.paths == null}—{:else}<span class="num">{n.paths}</span>{#if n.pathsDead}<span class="kv-hint">{t('detail.dead', { n: n.pathsDead })}</span>{/if}{#if n.paths === 1 && d.status !== 'off'}<span class="kv-hint">{t('detail.noFallback')}</span>{/if}{/if}
        </dd>
      </div>
      <div><dt>{t('detail.family')}</dt><dd>{n.family ? `IPv${n.family}` : '—'}</dd></div>
      <div><dt>{t('detail.lastPacket')}</dt><dd>{lastPacket ?? '—'}</dd></div>
      <div>
        <dt>{t('detail.client')}</dt>
        <dd>{n.version ?? '—'}{#if behind}<span class="kv-hint">{t('detail.newest', { v: newest ?? '' })}</span>{/if}</dd>
      </div>
      <div><dt>{t('detail.nodeId')}</dt><dd><CopyText text={n.id} /></dd></div>
      <div><dt>{t('detail.since')}</dt><dd>{memberSince ?? '—'}</dd></div>
      {#if n.note}<div><dt>{t('detail.note')}</dt><dd class="note">{n.note}</dd></div>{/if}
      {#if n.labels.length}
        <div>
          <dt>{t('detail.labels')}</dt>
          <dd class="labels">
            {#each n.labels as l (l.name)}<span class="tag">{#if l.color}<i class="sw" style:background={l.color}></i>{/if}{l.name}</span>{/each}
          </dd>
        </div>
      {/if}
    </dl>
  </section>

  <section class="dd-s" aria-labelledby="dd-24">
    <div class="dd-s-row">
      <h3 id="dd-24" class="dd-s-h">{t('home.last24')}</h3>
      <span class="t-label num">{n.uptime != null ? t('home.onlinePct', { pct: pct(n.uptime) }) : t('track.noData')}</span>
    </div>
    <AvailabilityTrack values={n.beats} {now} axis height={24} label={t('detail.trackAria', { pct: pct(n.uptime) })} />
  </section>

  <section class="dd-s" aria-labelledby="dd-tr">
    <div class="dd-s-row">
      <h3 id="dd-tr" class="dd-s-h">{t('detail.traffic')}</h3>
      {#if tr}<span class="t-label num">{t('detail.packets', { n: packets(tr.packets) })}</span>{/if}
    </div>
    {#if tr}
      <div class="bars" role="img" aria-label={t('detail.trafficAria', { n: packets(tr.packets) })}>
        {#each tr.days as v, i (i)}
          <i
            class:today={i === tr.days.length - 1}
            class:zero={v === 0}
            style:height="{v ? Math.max(2, (v / dayMax) * 40) : 1}px"
            title="{i === tr.days.length - 1 ? t('detail.todaySoFar') : t('detail.daysAgo', { count: tr.days.length - 1 - i })} · {t('detail.packets', { n: packets(v) })}"
          ></i>
        {/each}
      </div>
      <div class="bars-axis t-micro text-3"><span>{t('detail.daysAgo', { count: tr.days.length - 1 })}</span><span>{t('time.today')}</span></div>
      <p class="t-caption" class:err-text={tr.errors > 0} class:text-3={!tr.errors}>
        {tr.errors ? t('detail.errors', { count: tr.errors }) : t('detail.noErrors')}
      </p>
    {:else}
      <p class="text-3">{t('detail.noTraffic')}</p>
    {/if}
  </section>

  <section class="dd-s" aria-labelledby="dd-ev">
    <h3 id="dd-ev" class="dd-s-h">{t('detail.recent')}</h3>
    {#if events.length}
      <ol class="evs">
        {#each events as e (`${e.t}-${e.kind}`)}
          {@const tx = eventText(e)}
          <li>
            <time class="mono text-3" datetime={new Date(e.t).toISOString()}>{when(e.t)}</time>
            <StatusMarker kind={EVENT_META[e.kind].marker} />
            <span class="ev-t">
              <span>{tx.title}</span>
              {#if tx.sub && e.kind !== 'netdrop'}<span class="t-caption text-3">{tx.sub}</span>{/if}
            </span>
          </li>
        {/each}
      </ol>
    {:else}
      <p class="text-3">{t('detail.noEvents')}</p>
    {/if}
  </section>
</article>

<style>
  .dd {
    display: flex;
    flex-direction: column;
  }
  .dd-h {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 16px 20px 20px;
  }
  .back {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    align-self: flex-start;
    min-height: 44px;
    margin: -8px 0 0 -4px;
    padding: 0 4px;
    color: var(--text-2);
    font-weight: 500;
  }
  .dd-title {
    display: flex;
    align-items: center;
    gap: 10px;
    min-width: 0;
  }
  .dd-ic {
    display: inline-flex;
    color: var(--text-3);
  }
  .dd-title h2 {
    flex: 1;
    border-radius: var(--r-xs);
  }
  .dd-close {
    margin: -4px -8px -4px 0;
  }
  .dd-sub {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 6px;
    color: var(--text-2);
  }
  .dd-state {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
  }
  .dd-act {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 6px;
  }

  .warn {
    display: flex;
    gap: 10px;
    margin: 0 20px 16px;
    padding: 10px 12px;
    border-radius: var(--r-md);
    background: var(--err-bg);
    color: var(--err-fg);
  }
  .warn :global(.mk) {
    margin-top: 5px;
  }
  .warn b {
    font-weight: 600;
  }
  .warn p {
    color: var(--text-2);
  }

  .dd-s {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 16px 20px 20px;
    border-top: 1px solid var(--line);
  }
  .dd-s-h {
    color: var(--text-3);
    font-size: 11px;
    line-height: 16px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .dd-s-row {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 12px;
  }

  /* latency */
  .lat {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .lat-now {
    display: flex;
    align-items: baseline;
    gap: 4px;
  }
  .lat-unit {
    color: var(--text-2);
    font-size: 14px;
    font-weight: 500;
  }
  .lat-cap {
    margin-left: 8px;
  }
  .lat-cmp {
    color: var(--text-2);
  }
  .lat-cmp b {
    font-weight: 500;
    color: var(--text);
  }
  .lat-none {
    max-width: 52ch;
  }

  /* connection */
  .dd-s .kv > div {
    grid-template-columns: 128px minmax(0, 1fr);
    min-height: 36px;
    padding-top: 8px;
    padding-bottom: 8px;
  }
  .kv :global(.copytext) {
    margin-top: -2px;
    margin-bottom: -2px;
  }
  .ips {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
  }
  .note {
    color: var(--text-2);
  }
  .labels {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .labels .tag {
    gap: 6px;
  }
  .sw {
    width: 8px;
    height: 8px;
    border-radius: 2px;
  }

  /* traffic: 30 daily bars, neutral */
  .bars {
    display: flex;
    align-items: flex-end;
    gap: 2px;
    height: 40px;
    border-bottom: 1px solid var(--line-strong);
  }
  .bars i {
    flex: 1;
    min-width: 0;
    border-radius: 1.5px 1.5px 0 0;
    background: var(--series-2);
  }
  .bars i.today {
    background: none;
    box-shadow: inset 0 0 0 1px var(--series-2);
  }
  .bars i.zero {
    background: var(--line-strong);
  }
  .bars-axis {
    display: flex;
    justify-content: space-between;
    margin-top: -6px;
  }
  .err-text {
    color: var(--err-fg);
  }

  /* events */
  .evs {
    display: flex;
    flex-direction: column;
  }
  .evs li {
    display: grid;
    grid-template-columns: 92px 8px minmax(0, 1fr);
    align-items: baseline;
    gap: 10px;
    padding: 8px 0;
  }
  .evs li + li {
    border-top: 1px solid var(--line);
  }
  .evs time {
    font-size: 12px;
  }
  .evs :global(.mk) {
    align-self: center;
  }
  .ev-t {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  @media (max-width: 767px) {
    .dd-h,
    .dd-s {
      padding-left: 0;
      padding-right: 0;
    }
    .dd-h {
      padding-top: 0;
    }
    .back {
      margin-top: -16px;
    }
    .warn {
      margin-left: 0;
      margin-right: 0;
    }
  }
</style>
