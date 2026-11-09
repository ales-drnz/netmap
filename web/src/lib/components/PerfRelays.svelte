<script lang="ts">
  // Devices going through a relay right now. When the hub itself prevents
  // direct paths (TCP fallback, forced TCP relay, port mapping off) that is the
  // likely common cause: one banner on top instead of blaming every device.
  // "Relayed since" = the device's latest 'relay' event (the event log is
  // capped, so older switches show as "before the history").
  import { base } from '$app/paths';
  import { commonVersion, relaySince } from '$lib/charts/perf';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { elapsed, hhmm } from '$lib/model';
  import EmptyState from './EmptyState.svelte';
  import Icon from './Icon.svelte';
  import StatusBadge from './StatusBadge.svelte';

  const zt = $derived(live.snap?.health?.zt ?? null);
  const causes = $derived(
    [
      zt?.tcpFallback ? t('alerts.tcpFallback') : null,
      zt?.forceTcpRelay ? t('alerts.forceTcp') : null,
      zt?.portMapping === false ? t('alerts.portMapping') : null,
    ].filter((x): x is string => !!x),
  );
  const since = $derived(relaySince(live.events));
  const common = $derived(commonVersion(live.nodes));
  const rows = $derived(live.relay.slice().sort((a, b) => (since.get(a.id) ?? 0) - (since.get(b.id) ?? 0) || a.name.localeCompare(b.name)));
</script>

{#if causes.length && rows.length}
  <div class="banner" role="note">
    <Icon name="i-warn" size={16} />
    <div>
      <b class="t-label">{t('perf.relayCause')}</b>
      <p class="text-2">{causes.join(' · ')}. {t('perf.relayCauseText')}</p>
    </div>
  </div>
{/if}
{#if !rows.length}
  <EmptyState icon="i-check" title={t('perf.relayNone')} text={t('perf.relayNoneText')} />
{:else}
  <div class="scroll">
    <table class="tbl">
      <thead>
        <tr>
          <th>{t('dev.thDevice')}</th>
          <th>{t('dev.thPerson')}</th>
          <th>{t('perf.thSince')}</th>
          <th>{t('perf.thOneWay')}</th>
          <th class="r">{t('perf.thPaths')}</th>
          <th>{t('perf.thFamily')}</th>
          <th>{t('perf.thVersion')}</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as d (d.id)}
          {@const s = since.get(d.id)}
          <tr>
            <td><a class="link" href="{base}/devices/{d.id}">{d.name}</a>{#if live.myOwner && d.owner === live.myOwner}<span class="you-tag ml">{t('common.you')}</span>{/if}</td>
            <td class="text-2">{d.ownerLabel}</td>
            <td class="num">{#if s}<span title={new Date(s).toLocaleString()}>{t('perf.sinceFor', { d: elapsed(s, live.now), time: hhmm(s) })}</span>{:else}<span class="text-3">{t('perf.beforeHistory')}</span>{/if}</td>
            <td>{#if d.node.halfOpen}<StatusBadge kind="fault" />{:else}<span class="text-3">{t('common.no')}</span>{/if}</td>
            <td class="r num">{d.node.paths ?? '—'}{#if d.node.pathsDead}{' · '}<span class="text-3">{t('drawer.dead', { n: d.node.pathsDead })}</span>{/if}</td>
            <td class="num">{d.node.family ? `IPv${d.node.family}` : '—'}</td>
            <td class="num">{#if d.node.version && common && d.node.version !== common}{d.node.version}{:else}<span class="text-3">{d.node.version ? t('perf.sameVersion') : '—'}</span>{/if}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}

<style>
  .banner {
    display: flex;
    gap: 12px;
    padding: 12px 16px;
    border-bottom: 1px solid var(--line);
    background: var(--relay-bg);
    border-radius: calc(var(--r-lg) - 1px) calc(var(--r-lg) - 1px) 0 0;
  }
  .banner > :global(svg) {
    color: var(--relay-fg);
    flex-shrink: 0;
    margin-top: 2px;
  }
  .banner p {
    margin-top: 2px;
  }
  .scroll {
    overflow-x: auto;
  }
  .tbl {
    width: 100%;
    min-width: 720px;
    border-collapse: collapse;
  }
  th {
    height: 32px;
    padding: 0 16px;
    text-align: left;
    color: var(--text-3);
    font-size: 11px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    white-space: nowrap;
    border-bottom: 1px solid var(--line);
  }
  td {
    height: var(--row-h);
    padding: 4px 16px;
    white-space: nowrap;
  }
  tbody tr + tr td {
    border-top: 1px solid var(--line);
  }
  .r {
    text-align: right;
  }
  .link {
    font-weight: 500;
  }
  .ml {
    margin-left: 6px;
  }
</style>
