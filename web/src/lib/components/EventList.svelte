<script lang="ts">
  // Event rows (hairline list): time (mono) · status marker · text with the
  // device name linking to /devices/[id] · sub-text · tags.
  //   <EventList events={evs} stillOff={keys} />
  // - netdrop: ONE row "3 devices dropped together: a, b, c", expandable to the
  //   list of devices (with their status now) + the "single cause" hint
  // - stillOff: keys (eventKey) of 'offline' events whose device is still
  //   offline → "still offline" tag (see stillOffline in charts/activity.ts)
  // - empty: text when there are no events
  import type { NetEvent } from '$shared/api';
  import { base } from '$app/paths';
  import { eventKey, netdropNames } from '$lib/charts/activity';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { EVENT_META, eventText, hhmm } from '$lib/model';
  import Icon from './Icon.svelte';
  import StatusBadge from './StatusBadge.svelte';
  import StatusMarker from './StatusMarker.svelte';

  let { events, empty, stillOff }: { events: NetEvent[]; empty?: string; stillOff?: Set<string> } = $props();

  const known = (id: string | null) => !!id && live.nodes.some((n) => n.id === id);
  const byName = (name: string) => live.devices.find((d) => d.name === name) ?? null;
  /** splits the title around the device name so only the name is a link */
  function split(title: string, name: string | null): [string, string, string] | null {
    if (!name) return null;
    const i = title.indexOf(name);
    return i < 0 ? null : [title.slice(0, i), name, title.slice(i + name.length)];
  }
  let open = $state<Record<string, boolean>>({});
</script>

{#if events.length}
  <ol class="rows evl">
    {#each events as e (eventKey(e))}
      {@const m = EVENT_META[e.kind]}
      {@const tx = eventText(e)}
      {@const k = eventKey(e)}
      <li class="row ev" data-k={m.filter}>
        <time class="mono text-3" datetime={new Date(e.t).toISOString()} title={new Date(e.t).toLocaleString()}>{hhmm(e.t)}</time>
        <span class="mk-c"><StatusMarker kind={m.marker} /></span>
        <div class="body">
          {#if e.kind === 'netdrop'}
            {@const nd = netdropNames(e)}
            <p>
              <span class="t-label">{e.count != null ? t('ev.netdrop', { count: e.count }) : t('ev.netdropMany')}</span>{#if nd.names.length}<span class="text-2">: {nd.names.join(', ')}{nd.more ? '…' : ''}</span>{/if}
            </p>
            <button type="button" class="more-b" aria-expanded={!!open[k]} onclick={() => (open[k] = !open[k])}>
              <Icon name={open[k] ? 'i-chev-down' : 'i-chev'} size={12} />{open[k] ? t('act.hide') : t('act.showWho')}
            </button>
            {#if open[k]}
              <div class="drop">
                <ul>
                  {#each nd.names as n (n)}
                    {@const d = byName(n)}
                    <li>
                      {#if d}<a class="link" href="{base}/devices/{d.id}">{n}</a><StatusBadge kind={d.kind} />{:else}<span>{n}</span>{/if}
                    </li>
                  {/each}
                </ul>
                {#if nd.more}<p class="t-caption text-3">{t('act.dropMore', { count: Math.max(0, (e.count ?? nd.names.length) - nd.names.length) })}</p>{/if}
                <p class="t-caption text-2">{tx.sub}</p>
              </div>
            {/if}
          {:else}
            {@const sp = known(e.id) ? split(tx.title, e.name) : null}
            <p>
              {#if sp}{sp[0]}<a class="link" href="{base}/devices/{e.id}">{sp[1]}</a>{sp[2]}{:else}{tx.title}{/if}
              {#if stillOff?.has(k)}<span class="tag still">{t('act.stillOff')}</span>{/if}
            </p>
            {#if tx.sub}<p class="t-caption text-3 sub">{tx.sub}</p>{/if}
          {/if}
        </div>
      </li>
    {/each}
  </ol>
{:else}
  <p class="none text-3">{empty ?? t('events.empty')}</p>
{/if}

<style>
  .ev {
    display: grid;
    grid-template-columns: 44px 12px minmax(0, 1fr);
    align-items: start;
    column-gap: 10px;
    padding-top: 10px;
    padding-bottom: 10px;
  }
  .ev time {
    font-size: 12px;
    line-height: 20px;
  }
  .mk-c {
    display: inline-flex;
    align-items: center;
    height: 20px;
  }
  .body {
    min-width: 0;
  }
  .body .link {
    font-weight: 500;
  }
  .sub {
    margin-top: 2px;
  }
  .tag.still {
    margin-left: 8px;
    vertical-align: 1px;
    color: var(--off-fg);
    background: var(--off-bg);
  }
  .more-b {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    margin-top: 4px;
    padding: 0;
    border: 0;
    background: none;
    color: var(--text-2);
    font: inherit;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
  }
  .more-b:hover {
    color: var(--text);
  }
  .drop {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-top: 8px;
    padding: 10px 12px;
    border-left: 2px solid var(--err);
    background: var(--surface-2);
    border-radius: 0 var(--r-sm) var(--r-sm) 0;
  }
  .drop ul {
    display: flex;
    flex-wrap: wrap;
    gap: 6px 16px;
  }
  .drop li {
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }
  .none {
    padding: 12px 16px;
  }
</style>
