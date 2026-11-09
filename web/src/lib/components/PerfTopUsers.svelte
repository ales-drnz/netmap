<script lang="ts">
  // Top users over 30 days, by person (default) or by device. ZeroTier counts
  // PACKETS per device, not bytes: the unit says so on every number.
  // Bar = packets (relative to the top row), share = % of all counted packets,
  // mini bars = 30 days on ONE scale shared by every row (so rows compare);
  // today is partial (lighter), a day without data has no bar (not zero).
  import { base } from '$app/paths';
  import { topUsers, type UsageRow } from '$lib/charts/perf';
  import { i18n, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { cap } from '$lib/naming';
  import { num, packets } from '$lib/model';
  import ChartTip from './ChartTip.svelte';
  import EmptyState from './EmptyState.svelte';
  import Segmented from './Segmented.svelte';

  let by = $state<'person' | 'device'>('person');
  const rows = $derived(topUsers(live.devices, by, 8));
  const top = $derived(Math.max(1, ...rows.filter((r) => r.key !== '__others').map((r) => r.packets)));
  // the scale is set by full days of the listed rows: today is partial and
  // "others" is a sum of many; whatever exceeds it is drawn clipped with a cap
  const dayMax = $derived(Math.max(1, ...rows.filter((r) => r.key !== '__others').flatMap((r) => r.days.slice(0, 29).filter((v): v is number => v != null))));
  const label = (r: UsageRow) => (r.key === '__others' ? t('perf.others', { count: r.devices }) : by === 'person' ? cap(r.label) : r.label);
  const share = (v: number) => (v < 0.001 ? '<0.1%' : `${num(v * 100, v < 0.1 ? 1 : 0)}%`);

  const MW = 120;
  const MH = 24;
  let hover = $state<{ key: string; i: number } | null>(null);
  const dayLabel = (i: number) => {
    const back = 29 - i;
    if (back === 0) return t('perf.todaySoFar');
    const d = new Date(live.now);
    d.setDate(d.getDate() - back);
    return d.toLocaleDateString(i18n.locale, { day: 'numeric', month: 'short' });
  };
  function move(e: PointerEvent, key: string) {
    const r = (e.currentTarget as SVGElement).getBoundingClientRect();
    const i = Math.max(0, Math.min(29, Math.floor(((e.clientX - r.left) / r.width) * 30)));
    hover = { key, i };
  }
</script>

<div class="head">
  <Segmented
    size="sm"
    label={t('perf.groupBy')}
    bind:value={by}
    options={[
      { value: 'person', label: t('perf.byPerson') },
      { value: 'device', label: t('perf.byDevice') },
    ]}
  />
  <span class="t-caption text-3">{t('perf.miniNote')}</span>
</div>
{#if !rows.length}
  <EmptyState icon="i-chart" title={live.snap?.metrics ? t('stats.topEmpty') : t('stats.needMetrics')} text={t('stats.packetsNote')} />
{:else}
  <ol class="rows">
    {#each rows as r (r.key)}
      <li class="row u">
        <span class="nm ellipsis">
          {#if r.id}<a class="link" href="{base}/devices/{r.id}">{label(r)}</a>{:else}<span class:text-2={r.key === '__others'}>{label(r)}</span>{/if}
          {#if by === 'person' && r.key !== '__others' && r.devices > 1}<span class="text-3 t-caption"> · {t('perf.nDevices', { count: r.devices })}</span>{/if}
        </span>
        <span class="bar" aria-hidden="true"><i style:width="{Math.min(100, (r.packets / top) * 100)}%" class:others={r.key === '__others'}></i></span>
        <span class="v num">{packets(r.packets)} <span class="text-3">{t('perf.pkts')}</span></span>
        <span class="sh num text-2">{share(r.share)}</span>
        <span class="mini">
          <svg
            width={MW}
            height={MH}
            role="img"
            aria-label={t('perf.miniAria', { name: label(r) })}
            onpointermove={(e) => move(e, r.key)}
            onpointerleave={() => (hover = null)}
          >
            {#each r.days as v, i (i)}
              {#if v != null}
                {@const h = Math.max(v > 0 ? 1 : 0, (Math.min(v, dayMax) / dayMax) * (MH - 2))}
                <rect x={i * (MW / 30) + 0.5} y={MH - h} width={MW / 30 - 1} height={h} rx="1" fill={i === 29 ? 'var(--series-3)' : hover?.key === r.key && hover.i === i ? 'var(--text)' : 'var(--series-2)'} />
                {#if v > dayMax}<path d="M{i * (MW / 30) + MW / 60} 0l-2.5 3h5Z" fill="var(--text-3)" />{/if}
              {/if}
            {/each}
            <line x1="0" x2={MW} y1={MH - 0.5} y2={MH - 0.5} stroke="var(--line)" />
          </svg>
          {#if hover?.key === r.key}
            {@const v = r.days[hover.i]}
            <ChartTip x={hover.i * (MW / 30) + MW / 60} y={0} maxX={MW}>
              <b>{dayLabel(hover.i)}</b>
              <div><span class="k">{label(r)}</span><span>{v == null ? t('track.noData') : `${packets(v)} ${t('perf.pkts')}`}</span></div>
            </ChartTip>
          {/if}
        </span>
      </li>
    {/each}
  </ol>
{/if}

<style>
  .head {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px 16px;
    padding: 12px 16px;
    border-bottom: 1px solid var(--line);
  }
  .u {
    display: grid;
    grid-template-columns: minmax(96px, 1.1fr) minmax(60px, 1fr) 96px 48px 120px;
    gap: 16px;
  }
  .nm {
    min-width: 0;
  }
  .nm .link {
    font-weight: 500;
  }
  .bar {
    height: 8px;
    background: var(--fill);
    border-radius: 2px;
    overflow: hidden;
  }
  .bar i {
    display: block;
    height: 100%;
    background: var(--series);
    border-radius: 2px;
  }
  .bar i.others {
    background: var(--series-2);
  }
  .v,
  .sh {
    text-align: right;
    white-space: nowrap;
  }
  .mini {
    position: relative;
    display: block;
    height: 24px;
  }
  .mini svg {
    display: block;
  }
  @media (max-width: 560px) {
    .u {
      grid-template-columns: minmax(0, 1fr) 88px 44px;
      row-gap: 4px;
      padding-top: 8px;
      padding-bottom: 8px;
    }
    .bar {
      grid-column: 1 / -1;
      grid-row: 2;
    }
    .mini {
      display: none;
    }
  }
</style>
