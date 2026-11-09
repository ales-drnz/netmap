<script lang="ts">
  // The status pill in the top bar: the ONE global verdict (see $lib/status.ts
  // for the priority order). Click → popover with freshness and counts.
  // Rendered only by the app shell; pages must not repeat these numbers as KPIs.
  import { base } from '$app/paths';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { duration, hhmm, type StatusKind } from '$lib/model';
  import type { Verdict } from '$lib/status';
  import KeyValueList from './KeyValueList.svelte';
  import Popover from './Popover.svelte';
  import StatusMarker from './StatusMarker.svelte';

  const v = $derived(live.status);

  const ago = (s: number | null) => (s == null ? '—' : s < 60 ? t('time.sec', { n: s }) : duration(s, true));

  function labelOf(x: Verdict): string {
    const r = x.reason;
    switch (r.kind) {
      case 'loading':
        return t('layout.loading');
      case 'stale':
        if (r.source === 'ztnet') return t('pill.staleZtnet', { ago: ago(r.ageSec) });
        return r.ageSec == null ? t('pill.noServer') : t('pill.staleServer', { ago: ago(r.ageSec) });
      case 'netdrop':
        return r.count != null ? t('pill.netdrop', { count: r.count, time: hhmm(r.t) }) : t('pill.netdropMany', { time: hhmm(r.t) });
      case 'tcpFallback':
        return t('pill.tcpFallback');
      case 'forceTcp':
        return t('pill.forceTcp');
      case 'relay':
        return t('pill.relay', { count: r.count });
      case 'ok':
        return t('pill.ok');
    }
  }
  function explain(x: Verdict): string | null {
    const r = x.reason;
    switch (r.kind) {
      case 'stale':
        return r.source === 'ztnet' ? t('pill.staleZtnetText', { error: r.error ?? '' }) : t('pill.staleServerText');
      case 'netdrop':
        return t('ev.netdropSub');
      case 'tcpFallback':
        return t('alerts.tcpFallbackText');
      case 'forceTcp':
        return t('alerts.forceTcpText');
      case 'relay':
        return t('pill.relayText');
      default:
        return null;
    }
  }
  const MARK: Record<Verdict['tone'], StatusKind> = { ok: 'direct-wan', warn: 'relay', danger: 'fault', neutral: 'unknown' };

  const label = $derived(labelOf(v));
  const c = $derived(v.counts);
</script>

<Popover label={t('pill.aria', { status: label })} triggerClass="pill {v.tone}" panelClass="pill-pop" role="dialog">
  {#snippet trigger()}
    <StatusMarker kind={MARK[v.tone]} />
    <span class="pill-label ellipsis">{label}</span>
  {/snippet}
  {#snippet children(close)}
    <p class="t-label">{label}</p>
    {#if explain(v)}<p class="text-2" style:margin-top="-6px">{explain(v)}</p>{/if}
    <p class="text-3 t-caption">
      {#if live.offline}{t('layout.unreachable')}{:else if v.ageSec != null}{t('pill.fresh', { ago: ago(v.ageSec), every: v.pollSeconds })}{:else}{t('layout.loading')}{/if}
    </p>
    {#if live.snap}
      <KeyValueList
        rows={[
          { k: t('pill.online'), v: t('pill.onlineOf', { online: c.online, active: c.active }) },
          { k: t('pill.direct'), v: t('pill.directSplit', { n: c.direct, lan: c.lan, wan: c.wan }) },
          { k: t('pill.relayed'), v: c.relay },
          { k: t('pill.offline'), v: c.offline, hint: c.inactive ? t('pill.inactive', { count: c.inactive }) : null },
          { k: t('pill.typical'), v: v.typicalMs != null ? `${v.typicalMs} ms` : null },
        ]}
      />
      <div style:padding="8px 14px 6px" style:border-top="1px solid var(--line)">
        <a class="more" href="{base}/network#performance" onclick={close}>{t('pill.details')}</a>
      </div>
    {/if}
  {/snippet}
</Popover>
