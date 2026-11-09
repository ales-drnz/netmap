<script lang="ts">
  // "What reaches <hub>": DNS, managed routes and addresses followed through
  // configured (controller) → received (the hub's /network) → in use on the hub.
  // The logic below is carried over unchanged from v1.
  import type { Route } from '$shared/api';
  import { type Key, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import type { StatusKind } from '$lib/model';
  import CopyText from './CopyText.svelte';
  import EmptyState from './EmptyState.svelte';
  import Icon from './Icon.svelte';
  import StatusBadge from './StatusBadge.svelte';

  const net = $derived(live.snap?.net ?? null);
  const loc = $derived(live.snap?.health?.local ?? null);
  const hubName = $derived(live.hub?.name ?? t('net.thisNode'));
  const netId = $derived(live.snap?.networkId ?? '');

  // raw ZeroTier network status → translated label; unknown codes keep the server's label
  const NET_STATUS = ['OK', 'ACCESS_DENIED', 'NOT_FOUND', 'REQUESTING_CONFIGURATION', 'PORT_ERROR', 'CLIENT_TOO_OLD', 'AUTHENTICATION_REQUIRED'];
  const netStatus = (l: { status: string; statusLabel: string }) =>
    NET_STATUS.includes(l.status) ? t(`netStatus.${l.status}` as Key) : l.statusLabel;

  // --- the chain: configured → received → in use ----------------------------
  // Everything a ZeroTier network distributes goes through three stages. The
  // third (local consent) is DENIED by default in ZeroTier and is a per-device
  // setting: from here we only see the one of the node hosting Netmap. That's
  // why it's "soft": informational, it doesn't count toward the row's verdict.
  type St = 'ok' | 'ko' | 'na';
  interface Cell { st: St; text: string; soft?: boolean; note?: string | null }
  interface Row { name: string; configured: boolean; empty: string; cells: Cell[]; okLabel?: string }

  const sameList = (a: string[], b: string[]) => a.length === b.length && a.every((x) => b.includes(x));
  // tri-state: a missing field is not a "no"
  const consent = (v: boolean | null | undefined): St => (v == null ? 'na' : v ? 'ok' : 'ko');
  const routesText = (rs: Route[]) => rs.map((r) => (r.via ? `${r.target} via ${r.via}` : r.target)).join(', ') || '—';

  const rows: Row[] = $derived.by(() => {
    if (!loc) return [];
    const out: Row[] = [];
    {
      const cfg = net?.dns ?? null;
      const rec = loc.dns ?? null;
      const val = (d: typeof cfg) => [d?.domain, d?.servers.join(', ')].filter(Boolean).join(' · ') || '—';
      // "received" = arrived IDENTICAL: same domain but different servers is stale config
      const arrived = !!rec && rec.domain === cfg?.domain && sameList(rec.servers, cfg?.servers ?? []);
      const ap = consent(loc.allowDNS);
      out.push({
        name: 'DNS',
        configured: !!cfg,
        empty: t('net.dnsEmpty'),
        cells: [
          { st: 'ok', text: val(cfg) },
          { st: arrived ? 'ok' : 'ko', text: rec ? val(rec) : t('net.noData') },
          {
            soft: true,
            st: ap === 'ok' ? 'ok' : 'na',
            text: ap === 'ok' ? t('net.inUse') : ap === 'na' ? t('net.consentUnknown') : t('net.consentNo'),
            note: ap === 'ko' ? `zerotier-cli set ${netId} allowDNS=1` : null,
          },
        ],
      });
    }
    {
      const cfg = net?.routes ?? [];
      const rec = loc.routes ?? [];
      const arrived = sameList(rec.map((r) => r.target), cfg.map((r) => r.target));
      const ap = consent(loc.allowManaged);
      out.push({
        name: t('net.routes'),
        configured: cfg.length > 0,
        empty: t('net.routesEmpty'),
        cells: [
          { st: 'ok', text: routesText(cfg) },
          { st: arrived ? 'ok' : 'ko', text: rec.length ? routesText(rec) : t('net.noData') },
          {
            soft: true,
            st: ap === 'ok' ? 'ok' : 'na',
            text: ap === 'ok' ? t('net.installed') : ap === 'na' ? t('net.consentUnknown') : t('net.notInstalled'),
            note: ap === 'ko' ? `zerotier-cli set ${netId} allowManaged=1` : null,
          },
        ],
      });
    }
    {
      const pools = net?.pools ?? [];
      const got = loc.addresses ?? [];
      out.push({
        name: t('net.ip'),
        okLabel: t('net.active'),
        configured: pools.length > 0 || got.length > 0,
        empty: t('net.poolsEmpty'),
        cells: [
          { st: 'ok', text: pools.map((p) => `${p.start} – ${p.end}`).join(', ') || '—' },
          { st: got.length ? 'ok' : 'ko', text: got.join(', ') || t('net.noAddress') },
          { st: loc.ok ? 'ok' : 'ko', text: loc.device ? t('net.iface', { dev: loc.device }) : netStatus(loc) },
        ],
      });
    }
    return out;
  });

  // the verdict only looks at configured and propagated: the first stage that fails
  const verdict = (r: Row): { kind: StatusKind; txt: string } => {
    if (!r.configured) return { kind: 'unknown', txt: t('net.notConfigured') };
    const hard = r.cells.filter((c) => !c.soft);
    if (hard.some((c) => c.st === 'ko')) return { kind: 'fault', txt: t('net.notPropagated') };
    if (hard.some((c) => c.st === 'na')) return { kind: 'relay', txt: t('net.unverifiable') };
    return { kind: 'direct-wan', txt: r.okLabel ?? t('net.distributed') };
  };
  const stIcon = (st: St) => (st === 'ok' ? 'i-check' : st === 'ko' ? 'i-x' : 'i-minus');
  const STAGES = $derived([t('net.configured'), t('net.received'), t('net.inUseOn', { hub: hubName })]);
</script>

{#if !loc}
  <EmptyState icon="i-net" title={t('net.noLocal')} text="{t('net.noLocalA')} zerotier {t('net.noLocalB')}" />
{:else}
  <div class="chain" role="table" aria-label={t('net.reaches', { hub: hubName })}>
    <div class="ch-row head" role="row">
      <span role="columnheader"></span>
      {#each STAGES as s, i (i)}<span role="columnheader"><span class="step num">{i + 1}</span>{s}</span>{/each}
    </div>
    {#each rows as r (r.name)}
      {@const v = verdict(r)}
      <div class="ch-row" role="row">
        <div class="subj" role="rowheader">
          <span class="t-label">{r.name}</span>
          <StatusBadge kind={v.kind} label={v.txt} />
        </div>
        {#if r.configured}
          {#each r.cells as c, i (i)}
            <div class="cell {c.st}" class:soft={c.soft} role="cell">
              <span class="stage-l t-micro t-upper text-3">{STAGES[i]}</span>
              <span class="cv">
                <span class="ic"><Icon name={stIcon(c.st)} size={14} /></span>
                <span class="mono val">{c.text}</span>
              </span>
              {#if c.note}<span class="note"><CopyText text={c.note} /></span>{/if}
            </div>
          {/each}
        {:else}
          <div class="cell empty text-3" role="cell">{r.empty}</div>
        {/if}
      </div>
    {/each}
  </div>
  <p class="foot t-caption text-3">{t('net.footnote', { hub: hubName })}</p>
{/if}

<style>
  .ch-row {
    display: grid;
    grid-template-columns: 200px repeat(3, minmax(0, 1fr));
    column-gap: 16px;
    padding: 12px 16px;
    align-items: start;
  }
  .ch-row + .ch-row {
    border-top: 1px solid var(--line);
  }
  .head {
    padding-top: 8px;
    padding-bottom: 8px;
    background: var(--surface-2);
    color: var(--text-3);
    font-size: 11px;
    line-height: 16px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    border-radius: calc(var(--r-lg) - 1px) calc(var(--r-lg) - 1px) 0 0;
  }
  .head > span {
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }
  .step {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 16px;
    height: 16px;
    border-radius: var(--r-full);
    background: var(--fill-strong);
    color: var(--text-2);
    font-size: 10px;
  }
  .subj {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 6px;
  }
  .cell {
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-width: 0;
  }
  .cell.empty {
    grid-column: 2 / -1;
    padding-top: 2px;
  }
  .stage-l {
    display: none;
  }
  .cv {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    min-width: 0;
  }
  .val {
    overflow-wrap: anywhere;
    line-height: 20px;
  }
  .ic {
    display: inline-flex;
    margin-top: 3px;
    flex-shrink: 0;
  }
  .ok .ic {
    color: var(--ok-fg);
  }
  .ko .ic {
    color: var(--err-fg);
  }
  .na .ic {
    color: var(--text-4);
  }
  .soft .val {
    color: var(--text-2);
  }
  .note {
    padding-left: 22px;
    max-width: 100%;
  }
  .foot {
    padding: 10px 16px 12px;
    border-top: 1px solid var(--line);
    max-width: 96ch;
  }
  @media (max-width: 860px) {
    .head {
      display: none;
    }
    .ch-row {
      grid-template-columns: minmax(0, 1fr);
      row-gap: 10px;
    }
    .stage-l {
      display: block;
    }
    .cell.empty {
      grid-column: 1;
    }
  }
</style>
