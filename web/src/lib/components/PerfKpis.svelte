<script lang="ts">
  // Performance KPI strip: four numbers in ONE hairline strip (no cards).
  // Definitions are in lib/charts/perf.ts and lib/stats.ts (one each):
  //   Online now = online / active (inactive > 7 d excluded and stated)
  //   Direct     = direct / online, split LAN · internet · relay
  //   Typical latency = median of per-device medians (+ p95 of those medians,
  //                vs the previous week only when most devices have one)
  //   Outages 24 h = netdrop incidents + disconnections of active devices
  import { outages24h, p95OfMedians, typicalVsLastWeek } from '$lib/charts/perf';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { hhmm, num } from '$lib/model';

  const c = $derived(live.status.counts);
  const typical = $derived(live.typical);
  const p95 = $derived(p95OfMedians(live.nodes));
  const week = $derived(typicalVsLastWeek(live.nodes));
  const out = $derived(outages24h(live.events, live.nodes, live.now));
  const ms = (v: number | null) => (v == null ? '—' : String(Math.round(v)));
  const signed = (r: number) => {
    const p = Math.round((r - 1) * 100);
    return p === 0 ? t('perf.kSame') : t('perf.kVsWeek', { d: `${p > 0 ? '+' : '−'}${Math.abs(p)}` });
  };
</script>

<dl class="kpis">
  <div>
    <dt>{t('perf.kOnline')}</dt>
    <dd class="v"><span class="t-num-l">{c.online}</span><span class="of">/ {t('perf.kActive', { n: c.active })}</span></dd>
    <dd class="s">{c.inactive ? t('pill.inactive', { count: c.inactive }) : t('perf.kNoInactive')}</dd>
  </div>
  <div>
    <dt>{t('perf.kDirect')}</dt>
    <dd class="v"><span class="t-num-l">{c.online ? num((c.direct / c.online) * 100) : '—'}</span><span class="of">%</span></dd>
    <dd class="s">{t('perf.kDirectSplit', { lan: c.lan, wan: c.wan, relay: c.relay })}</dd>
  </div>
  <div>
    <dt>{t('pill.typical')}</dt>
    <dd class="v"><span class="t-num-l">{ms(typical)}</span><span class="of">ms</span></dd>
    <dd class="s">
      {#if p95 != null}{t('perf.kP95', { ms: ms(p95) })}{/if}{#if week}{' · '}<span title={t('perf.kWeekTitle', { now: ms(week.now), prev: ms(week.prev), n: week.n })}>{signed(week.ratio)}</span>{:else if typical != null}{' · '}<span class="text-3">{t('perf.kNoWeek')}</span>{/if}
    </dd>
  </div>
  <div>
    <dt>{t('perf.kOutages')}</dt>
    <dd class="v"><span class="t-num-l">{out.count}</span></dd>
    <dd class="s">{out.last != null ? t('perf.kLastAt', { time: hhmm(out.last) }) : t('perf.kNoOutages')}</dd>
  </div>
</dl>

<style>
  .kpis {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    border-top: 1px solid var(--line);
    border-bottom: 1px solid var(--line);
  }
  .kpis > div {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 16px 20px 16px 0;
    min-width: 0;
  }
  .kpis > div + div {
    padding-left: 20px;
    border-left: 1px solid var(--line);
  }
  dt {
    color: var(--text-3);
    font-size: 12px;
    line-height: 16px;
  }
  .v {
    display: flex;
    align-items: baseline;
    gap: 6px;
  }
  .of {
    color: var(--text-3);
    font-size: 13px;
    font-variant-numeric: tabular-nums;
  }
  .s {
    color: var(--text-2);
    font-size: 12px;
    line-height: 16px;
    font-variant-numeric: tabular-nums;
  }
  @media (max-width: 900px) {
    .kpis {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
    .kpis > div:nth-child(3) {
      padding-left: 0;
      border-left: 0;
    }
    .kpis > div:nth-child(n + 3) {
      border-top: 1px solid var(--line);
    }
  }
</style>
