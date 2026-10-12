<script lang="ts">
  import Icon from '$lib/components/Icon.svelte';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import type { Cell } from '$lib/model';
  import { elapsed } from '$lib/model';
  import Cells from '$lib/components/Cells.svelte';
  import { ui } from '$lib/ui.svelte';

  const links = $derived(live.snap?.links ?? []);
  const probed = $derived(links.filter((l) => l.up != null));
  const up = $derived(probed.filter((l) => l.up).length);
  const C = 2 * Math.PI * 22;
  // card colour: the one set in services.json, otherwise a stable one from the name
  const PALETTE = ['#7b4bc9', '#d29a00', '#3f8a3a', '#2563eb', '#db2777', '#0d9488', '#ea580c'];
  const colorOf = (name: string, c?: string | null) => c ?? PALETTE[[...name].reduce((a, ch) => a + ch.charCodeAt(0), 0) % PALETTE.length];
  const cells = (h?: (number | null)[]): Cell[] => (h ?? []).map((v) => (v == null ? 'n' : v >= 0.98 ? 'k' : v > 0 ? 'p' : 'o'));
  const hostOf = (name?: string | null) => (name ? (live.nodes.find((n) => n.name === name) ?? null) : null);
</script>

<div class="pagehead">
  <div>
    <h1>{t('nav.services')}</h1>
    <p>{t('svc.intro')}</p>
  </div>
</div>

{#if !links.length}
  <div class="card" style="padding:40px;text-align:center;color:var(--text-3)">
    {t('svc.emptyA')} <span class="mono">services.json</span> {t('svc.emptyB')} <span class="mono">QUICK_LINKS</span>{t('svc.emptyC')}
  </div>
{:else}
  {#if probed.length}
    <div class="card svcsum">
      <svg class="ring" viewBox="0 0 54 54" aria-hidden="true">
        <circle cx="27" cy="27" r="22" fill="none" stroke="var(--sunken)" stroke-width="6" />
        <circle cx="27" cy="27" r="22" fill="none" stroke="var(--online)" stroke-width="6" stroke-linecap="round" stroke-dasharray="{(C * up) / probed.length} {C}" transform="rotate(-90 27 27)" />
      </svg>
      <div>
        <b>{t('svc.summary', { up, total: probed.length })}</b>
        <span class="t2" style="font-size:13px">{probed
            .filter((l) => !l.up)
            .map((l) => (l.downSince ? t('svc.downFor', { name: l.name, d: elapsed(l.downSince, live.now) }) : t('svc.down', { name: l.name })))
            .join(' · ') || t('svc.allGood')}</span>
      </div>
      <div class="chips">{#each probed as l (l.url)}<span class="pill {l.up ? 'direct' : 'off'}"><span class="dot {l.up ? 'direct' : 'off'}"></span>{l.name}</span>{/each}</div>
    </div>
  {/if}

  <div class="svcgrid">
    {#each links as l (l.url)}
      {@const c = colorOf(l.name, l.color)}
      {@const host = hostOf(l.host)}
      <div class="card svc" style="--c:{c}">
        <div class="svc-top">
          <span class="svc-logo" style="background:{c}">{l.name.charAt(0)}</span>
          <div style="min-width:0;flex:1"><strong>{l.name}</strong>{#if l.description}<span>{l.description}</span>{/if}</div>
        </div>
        <div class="svc-b">
          {#if l.up != null}
            <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
              {#if l.up}<span class="pill direct"><span class="dot direct"></span>{t('svc.up')}{l.ms != null ? ` · ${l.ms} ms` : ''}</span>
              {:else}<span class="pill off"><span class="dot off"></span>{l.downSince ? t('svc.notUpFor', { d: elapsed(l.downSince, live.now) }) : t('svc.notUp')}</span>{/if}
            </div>
            {#if l.hours?.length}<Cells cells={cells(l.hours)} />{/if}
          {/if}
          <div class="addr">
            <span>{l.url.replace(/^https?:\/\//, '')}</span>
            <button class="iconbtn" style="width:30px;height:30px;background:var(--surface)" onclick={() => ui.copy(l.url)} aria-label={t('svc.copyAddr')}><Icon name="i-copy" size={13} /></button>
          </div>
          {#if l.app || l.host}
            <dl class="meta2">
              {#if l.app}<dt>App</dt><dd>{l.app}</dd>{/if}
              {#if l.host}<dt>{t('svc.hostedBy')}</dt><dd>{#if host}<span class="dot {host.online ? 'direct' : 'off'}"></span>{/if} {l.host}</dd>{/if}
            </dl>
          {/if}
          <div class="svc-f"><a class="btn primary" href={l.url} target="_blank" rel="noopener">{t('common.open')} <Icon name="i-ext" size={13} /></a></div>
        </div>
      </div>
    {/each}
  </div>
{/if}
