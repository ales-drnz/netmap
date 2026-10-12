<script lang="ts">
  import { base } from '$app/paths';
  import Cells from '$lib/components/Cells.svelte';
  import DevTile from '$lib/components/DevTile.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import Pill from '$lib/components/Pill.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { type Device, elapsed, pctValue } from '$lib/model';
  import { ui } from '$lib/ui.svelte';

  const mine = $derived(live.devices.filter((d) => d.owner === live.myOwner));
  const cur = $derived(live.myDevice);
  // plain words: this is the page non-technical people read too
  const why = (d: Device) =>
    d.status === 'off'
      ? t('me.off', { d: elapsed(d.node.lastSeen, live.now) })
      : d.node.halfOpen
        ? t('me.halfOpen')
        : d.node.link === 'lan'
          ? t('me.lan')
          : d.status === 'relay'
            ? t('me.relay')
            : t('me.direct');
</script>

<div class="pagehead">
  <div>
    <h1>{t('nav.me')}</h1>
    <p>{live.myOwner ? t('me.intro', { owner: live.myOwner }) : t('me.unknown')}</p>
  </div>
</div>

{#if cur}
  <div class="card mehero">
    <DevTile d={cur} size={24} />
    <div style="flex:1;min-width:0">
      <span class="eyebrow">{t('me.using')}</span>
      <h2>{cur.name}</h2>
      <p>{why(cur)}</p>
    </div>
    {#if cur.ip}<button class="btn primary" onclick={() => cur.ip && ui.copy(cur.ip)}><Icon name="i-copy" size={14} />{t('me.copyMyIp', { ip: cur.ip })}</button>{/if}
  </div>
{:else if live.me}
  <div class="card mehero">
    <div style="flex:1;min-width:0">
      <h2>{t('me.notZt')}</h2>
      <p>{t('me.notZtA')} <span class="mono">{live.me.ip}</span>{t('me.notZtB')}</p>
    </div>
    <a class="btn primary" href="{base}/join">{t('nav.join')}</a>
  </div>
{/if}

{#if mine.length}
  <div class="mycards">
    {#each mine as d (d.id)}
      <div class="card mycard" role="button" tabindex="0" onclick={() => (ui.drawer = d.id)} onkeydown={(e) => e.key === 'Enter' && (ui.drawer = d.id)}>
        <div class="mycard-h">
          <DevTile {d} />
          <div><b>{d.name}</b><small class="mono">{d.ip ?? '—'}</small></div>
          <Pill status={d.status} />
        </div>
        <div class="bigstat">
          {#if d.ms != null}<b style="font-size:36px">{d.ms}</b><small>ms</small>
          {:else if d.status === 'relay'}<b style="font-size:36px">—</b><small>{t('common.noLatency')}</small>
          {:else}<b style="font-size:36px">{d.node.uptime != null ? pctValue(d.node.uptime) : '—'}</b><small>{t('me.uptime')}</small>{/if}
        </div>
        <div class="why">{why(d)}</div>
        <Cells cells={d.hours} axis />
      </div>
    {/each}
  </div>
{/if}
