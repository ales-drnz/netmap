<script lang="ts">
  import { base } from '$app/paths';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { eventText, hhmm, pathLabel, packets, pct, seen, since } from '$lib/model';
  import { ui } from '$lib/ui.svelte';
  import Cells from './Cells.svelte';
  import DevTile from './DevTile.svelte';
  import Icon from './Icon.svelte';
  import Pill from './Pill.svelte';
  import Spark from './Spark.svelte';

  const d = $derived(ui.drawer ? (live.devices.find((x) => x.id === ui.drawer) ?? null) : null);
  // newest version on the network: never "outdated" in absolute terms, only compared across nodes
  const newest = $derived(
    live.nodes
      .map((n) => n.version)
      .filter((v): v is string => !!v)
      .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))[0] ?? null,
  );
  const evs = $derived(d ? live.events.filter((e) => e.id === d.id).slice(0, 5) : []);
  const close = () => (ui.drawer = null);
</script>

<div class="scrim" class:open={!!d} onclick={close} role="presentation"></div>
<aside class="drawer" class:open={!!d} aria-label={t('drawer.aria')} aria-hidden={!d}>
  {#if d}
    {@const n = d.node}
    <div class="dhead">
      <DevTile {d} size={22} />
      <div style="min-width:0;flex:1">
        <h3>{d.name}</h3>
        <small
          >{t('drawer.owner', { name: d.ownerLabel })}{d.owner === live.myOwner ? ` (${t('common.you')})` : ''}{n.since ? ` · ${t('drawer.memberFor', { d: since(n.since, live.now) })}` : ''}</small
        >
      </div>
      <button class="iconbtn" onclick={close} aria-label={t('drawer.close')}><Icon name="i-x" size={14} /></button>
    </div>
    <div class="dbody">
      <div class="dsec">
        <div class="dstatus">
          <div class="bigstat">
            <b>{d.ms ?? '—'}</b><small>{d.ms != null ? 'ms' : d.status === 'relay' ? t('common.noLatency') : seen(n.lastSeen, live.now)}</small>
          </div>
          <Pill status={d.status} />
        </div>
        {#if n.spark?.some((v) => v != null)}
          <div style="margin-top:14px"><Spark values={n.spark} w={400} h={54} /></div>
        {/if}
        {#if n.latency30}
          <div class="muted" style="font-size:12.5px;margin-top:8px">
            {t('drawer.latency30', { median: n.latency30.median ?? '—', p95: n.latency30.p95 ?? '—' })}{#if n.latency30.prevMedian != null}
              · {t('drawer.prevWeek', { ms: n.latency30.prevMedian })}{/if}
          </div>
        {/if}
        {#if n.halfOpen}
          <div class="alert" style="margin-top:14px;box-shadow:none;background:var(--danger-bg)">
            <div><b>{t('drawer.halfOpen')}</b><p>{t('drawer.halfOpenText', { s: n.idleSec ?? '—' })}</p></div>
          </div>
        {/if}
        <div class="dactions">
          {#if d.ip}<button class="btn primary" onclick={() => d.ip && ui.copy(d.ip)}><Icon name="i-copy" size={14} />{t('common.copyIp')}</button>{/if}
          <a class="btn" href="{base}/map?d={d.id}" onclick={close}><Icon name="i-map" size={14} />{t('drawer.onMap')}</a>
        </div>
      </div>

      <div class="dsec">
        <h4>{t('drawer.connection')}</h4>
        <div class="dlist">
          <div><span>IP</span><b class="mono">{n.ips.join(', ') || '—'}</b></div>
          <div><span>{t('drawer.path')}</span><b>{pathLabel(d)}</b></div>
          {#if n.paths != null}<div><span>{t('drawer.activePaths')}</span><b>{n.paths}{n.family ? ` · IPv${n.family}` : ''}{n.pathsDead ? ` (${t('drawer.dead', { n: n.pathsDead })})` : ''}</b></div>{/if}
          {#if n.idleSec != null}<div><span>{t('drawer.lastPacket')}</span><b>{t('time.sAgo', { n: n.idleSec })}</b></div>{/if}
          <div><span>{t('drawer.nodeId')}</span><b class="mono">{n.id}</b></div>
          <div>
            <span>{t('drawer.client')}</span><b>{n.version ?? '—'}{#if n.version && newest && n.version !== newest}<span class="muted"> · {t('drawer.newest', { v: newest })}</span>{/if}</b>
          </div>
          {#if n.note}<div><span>{t('drawer.note')}</span><b>{n.note}</b></div>{/if}
        </div>
        {#if n.labels.length}
          <div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:12px">
            {#each n.labels as l (l.name)}<span class="pill neutral"><span class="dot" style="background:{l.color ?? 'var(--text-3)'}"></span>{l.name}</span>{/each}
          </div>
        {/if}
      </div>

      <div class="dsec">
        <h4>{t('drawer.last24', { pct: pct(n.uptime) })}</h4>
        <Cells cells={d.hours} axis />
      </div>

      {#if n.traffic}
        <div class="dsec">
          <h4>{t('drawer.traffic30')}</h4>
          <div class="bigstat"><b style="font-size:28px">{packets(n.traffic.packets)}</b><small>{t('drawer.packets')}</small></div>
          {#if n.traffic.errors}<p class="muted" style="margin:8px 0 0;font-size:12.5px">{t('drawer.errors', { count: n.traffic.errors })}</p>{/if}
        </div>
      {/if}

      {#if evs.length}
        <div class="dsec">
          <h4>{t('drawer.recent')}</h4>
          {#each evs as e (e.t + e.kind)}
            <div class="dlist"><div><span>{eventText(e).title}</span><b class="mono">{hhmm(e.t)}</b></div></div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}
</aside>
