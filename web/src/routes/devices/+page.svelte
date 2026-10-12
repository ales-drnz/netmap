<script lang="ts">
  import Alerts from '$lib/components/Alerts.svelte';
  import Cells from '$lib/components/Cells.svelte';
  import CopyIp from '$lib/components/CopyIp.svelte';
  import DevTile from '$lib/components/DevTile.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import Pill from '$lib/components/Pill.svelte';
  import Spark from '$lib/components/Spark.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { type Device, type Status, pathLabel, pct } from '$lib/model';
  import { ui } from '$lib/ui.svelte';

  let q = $state('');
  let filter = $state<'all' | Status>('all');
  let view = $state<'people' | 'table'>('people');
  try {
    if (localStorage.getItem('nm-devview') === 'table') view = 'table';
  } catch {
    /* preference can't be saved */
  }
  $effect(() => {
    try {
      localStorage.setItem('nm-devview', view);
    } catch {
      /* same */
    }
  });

  const match = (d: Device) => {
    const s = q.toLowerCase().trim();
    return (filter === 'all' || d.status === filter) && (!s || [d.name, d.ip, d.ownerLabel, d.id].some((x) => x?.toLowerCase().includes(s)));
  };
  const list = $derived(live.devices.filter(match));
  const people = $derived(live.people.map((p) => ({ ...p, shown: p.devices.filter(match) })).filter((p) => p.shown.length));
  const hubStats = $derived({
    talk: live.online.length,
    direct: live.direct.length,
    relay: live.relay.length,
  });
  const count = (st: Status) => live.devices.filter((d) => d.status === st).length;
  const open = (d: Device) => (ui.drawer = d.id);
</script>

<div class="pagehead">
  <div>
    <h1>{t('nav.devices')}</h1>
    <p>{t('dev.intro', { devices: live.devices.length, people: live.people.length })}</p>
  </div>
</div>

<Alerts />

{#if live.hub}
  <div class="hero-hub">
    <div class="mk"><Icon name="i-server" size={24} /></div>
    <div>
      <small>{t('dev.hub')}</small><strong>{live.hub.name}</strong>
      <small class="mono">{live.hub.ips[0] ?? ''}{live.hub.version ? ` · client ${live.hub.version}` : ''}</small>
    </div>
    <div class="st"><b>{hubStats.talk}</b><small>{t('dev.talk')}</small></div>
    <div class="st"><b>{hubStats.direct}</b><small>{t('dev.direct')}</small></div>
    <div class="st"><b>{hubStats.relay}</b><small>{t('dev.relay')}</small></div>
  </div>
{/if}

<div class="toolbar">
  <label class="searchin">
    <Icon name="i-search" size={14} />
    <input bind:value={q} data-page-search placeholder={t('dev.searchPh')} aria-label={t('dev.searchAria')} />
  </label>
  <div class="seg" role="group" aria-label={t('common.filterByStatus')}>
    <button aria-pressed={filter === 'all'} onclick={() => (filter = 'all')}>{t('common.all')} <span class="n">{live.devices.length}</span></button>
    <button aria-pressed={filter === 'direct'} onclick={() => (filter = 'direct')}>{t('filter.direct')} <span class="n">{count('direct')}</span></button>
    <button aria-pressed={filter === 'relay'} onclick={() => (filter = 'relay')}>{t('filter.relay')} <span class="n">{count('relay')}</span></button>
    <button aria-pressed={filter === 'off'} onclick={() => (filter = 'off')}>{t('filter.off')} <span class="n">{count('off')}</span></button>
  </div>
  <span class="spacer"></span>
  <div class="seg flat" role="group" aria-label={t('dev.view')}>
    <button aria-pressed={view === 'people'} onclick={() => (view = 'people')}><Icon name="i-user" size={14} />{t('dev.people')}</button>
    <button aria-pressed={view === 'table'} onclick={() => (view = 'table')}><Icon name="i-list" size={14} />{t('dev.list')}</button>
  </div>
</div>

{#if !list.length}
  <div class="card" style="padding:40px;text-align:center;color:var(--text-3)">{t('dev.noMatch')}</div>
{:else if view === 'people'}
  <div class="people">
    {#each people as p (p.key)}
      <div class="card">
        <div class="pcard-h">
          <span class="avatar" class:me-av={p.key === live.myOwner}>{p.label.charAt(0)}</span>
          <div>
            <b>{p.label}</b>{#if p.key === live.myOwner}&nbsp;<span class="pill accent" style="height:20px">{t('common.you')}</span>{/if}
            <small>{t('dev.onlineOf', { online: p.online, total: p.devices.length })}</small>
          </div>
          <div class="dots">{#each p.devices as d (d.id)}<span class="dot {d.status}"></span>{/each}</div>
        </div>
        {#each p.shown as d (d.id)}
          <div class="drow" role="button" tabindex="0" onclick={() => open(d)} onkeydown={(e) => e.key === 'Enter' && open(d)}>
            <DevTile {d} />
            <div style="min-width:0">
              <div class="nm">{d.name}</div>
              <div class="sb">{#if d.ip}<CopyIp text={d.ip} />{/if}<span class="hide-sm">· {pathLabel(d)}</span></div>
            </div>
            <div class="lat">
              {#if d.ms != null}<b>{d.ms} ms</b><Spark values={d.node.spark} w={80} h={16} area={false} />
              {:else}<span>{t('dev.uptime24', { pct: pct(d.node.uptime) })}</span>{/if}
            </div>
            <Pill status={d.status} />
          </div>
        {/each}
      </div>
    {/each}
  </div>
{:else}
  <div class="card">
    <div class="tablewrap">
      <table>
        <thead>
          <tr>
            <th>{t('dev.thDevice')}</th><th>{t('dev.thPerson')}</th><th>{t('dev.thStatus')}</th><th>IP</th><th class="r">{t('dev.thLatency')}</th><th>{t('common.last24h')}</th><th class="hide-sm"
              >Client</th
            >
          </tr>
        </thead>
        <tbody>
          {#each list as d (d.id)}
            <tr class="dev" onclick={() => open(d)}>
              <td><span style="display:inline-flex;gap:10px;align-items:center"><span class="t2"><Icon name="i-{d.type}" /></span><b style="font-weight:600">{d.name}</b></span></td>
              <td class="t2">{d.ownerLabel}</td>
              <td><Pill status={d.status} /></td>
              <td>{#if d.ip}<CopyIp text={d.ip} />{/if}</td>
              <td class="r mono">{d.ms != null ? `${d.ms} ms` : '—'}</td>
              <td style="width:200px"><Cells cells={d.hours} /></td>
              <td class="hide-sm">{d.node.version ?? '—'}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </div>
{/if}
