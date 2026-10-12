<script lang="ts">
  import type { NetEvent } from '$shared/api';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { EVENT_META, eventText, hhmm } from '$lib/model';
  import { ui } from '$lib/ui.svelte';
  import Icon from './Icon.svelte';

  let { events, empty }: { events: NetEvent[]; empty?: string } = $props();
  const known = (id: string | null) => !!id && live.devices.some((d) => d.id === id);
</script>

<div class="tl">
  {#each events as e (`${e.t}-${e.kind}-${e.id}`)}
    {@const m = EVENT_META[e.kind]}
    {@const tx = eventText(e)}
    <div class="tl-item" data-k={m.filter}>
      <span class="evico {m.tone}"><Icon name={m.icon} size={15} /></span>
      <div style="min-width:0">
        <p>
          {#if known(e.id)}<button class="linkish" onclick={() => (ui.drawer = e.id)}>{tx.title}</button>{:else}{tx.title}{/if}
        </p>
        {#if e.kind === 'netdrop' && e.detail}
          <div class="incident">
            <div style="font-size:12.5px;font-weight:600;color:var(--danger-fg)">{t('events.droppedTogether')}</div>
            <div class="who">{#each e.detail.split(', ') as n (n)}<span class="pill off" style="background:var(--surface)"><span class="dot off"></span>{n}</span>{/each}</div>
          </div>
          <small>{tx.sub}</small>
        {:else if tx.sub}<small>{tx.sub}</small>{/if}
      </div>
      <time>{hhmm(e.t)}</time>
    </div>
  {:else}
    <p class="muted" style="margin:6px 0 4px">{empty ?? t('events.empty')}</p>
  {/each}
</div>

<style>
  .linkish {
    all: unset;
    cursor: pointer;
  }
  .linkish:hover {
    text-decoration: underline;
    text-underline-offset: 3px;
  }
</style>
