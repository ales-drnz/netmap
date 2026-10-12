<script lang="ts">
  import type { Route } from '$shared/api';
  import Alerts from '$lib/components/Alerts.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { i18n, type Key, t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { typeLabel } from '$lib/naming';
  import type { DeviceType } from '$lib/naming';
  import { ui } from '$lib/ui.svelte';

  const net = $derived(live.snap?.net ?? null);
  const loc = $derived(live.snap?.health?.local ?? null);
  const zt = $derived(live.snap?.health?.zt ?? null);
  const hubName = $derived(live.hub?.name ?? t('net.thisNode'));
  const netId = $derived(live.snap?.networkId ?? '');

  // raw ZeroTier network status → translated label; unknown codes keep the server's label
  const NET_STATUS = ['OK', 'ACCESS_DENIED', 'NOT_FOUND', 'REQUESTING_CONFIGURATION', 'PORT_ERROR', 'CLIENT_TOO_OLD', 'AUTHENTICATION_REQUIRED'];
  const netStatus = (l: { status: string; statusLabel: string }) =>
    NET_STATUS.includes(l.status) ? t(`netStatus.${l.status}` as Key) : l.statusLabel;
  const v6Label = (v: string) => (v === 'managed' ? t('net.v6managed') : v);

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
  const verdict = (r: Row) => {
    if (!r.configured) return { cls: 'neutral', txt: t('net.notConfigured') };
    const hard = r.cells.filter((c) => !c.soft);
    if (hard.some((c) => c.st === 'ko')) return { cls: 'off', txt: t('net.notPropagated') };
    if (hard.some((c) => c.st === 'na')) return { cls: 'relay', txt: t('net.unverifiable') };
    return { cls: 'direct', txt: r.okLabel ?? t('net.distributed') };
  };
  const stIcon = (st: St) => (st === 'ok' ? 'i-check' : st === 'ko' ? 'i-x' : 'i-minus');

  // --- composition and versions ---------------------------------------------
  const types = $derived.by(() => {
    const m = new Map<DeviceType, number>();
    for (const d of live.devices) m.set(d.type, (m.get(d.type) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[1] - a[1]);
  });
  const shades = [
    'var(--bar-strong)',
    'color-mix(in srgb, var(--bar-strong) 70%, var(--sunken))',
    'color-mix(in srgb, var(--bar-strong) 48%, var(--sunken))',
    'color-mix(in srgb, var(--bar-strong) 30%, var(--sunken))',
    'var(--bar)',
    'color-mix(in srgb, var(--bar) 60%, var(--sunken))',
    'var(--sunken)',
    'var(--sunken)',
  ];
  // Never "outdated" in absolute terms (the network may have no internet): only
  // a comparison across nodes — "someone has 1.14.2", which is verifiable.
  const versions = $derived.by(() => {
    const m = new Map<string, number>();
    for (const n of live.nodes) if (n.version) m.set(n.version, (m.get(n.version) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[0].localeCompare(a[0], undefined, { numeric: true }));
  });
  const vmax = $derived(Math.max(1, ...versions.map((v) => v[1])));
  const created = $derived(net?.creationTime ? new Date(net.creationTime).toLocaleDateString(i18n.locale, { day: 'numeric', month: 'short', year: 'numeric' }) : '—');
  const yesNo = (v: boolean | null | undefined, y = t('common.yes'), n = t('common.no')) => (v == null ? '—' : v ? y : n);
</script>

<div class="pagehead">
  <div>
    <h1>{t('nav.network')}</h1>
    <p>{t('net.intro', { hub: hubName })}</p>
  </div>
</div>

<Alerts />

<div class="card nethero">
  <div class="l">
    <span class="eyebrow">{t('layout.ztNetwork')}</span>
    <h2>{live.snap?.networkName ?? '…'}</h2>
    <div style="display:flex;gap:8px;flex-wrap:wrap">
      {#if net?.private != null}<span class="pill neutral"><Icon name="i-lock" size={12} />{net.private ? t('net.private') : t('net.public')}</span>{/if}
      {#each net?.pools ?? [] as p (p.start)}<span class="pill neutral mono">{p.start} – {p.end}</span>{/each}
      {#if loc}<span class="pill {loc.ok ? 'direct' : 'off'}"><span class="dot {loc.ok ? 'direct' : 'off'}"></span>{t('net.statusPill', { status: netStatus(loc) })}</span>{/if}
    </div>
    {#if netId}
      <div class="addr" style="max-width:420px"><span>{netId}</span><button class="btn sm" onclick={() => ui.copy(netId)}><Icon name="i-copy" size={13} />{t('common.copyId')}</button></div>
    {/if}
  </div>
  <div class="r">
    <div class="kvi"><span>MTU</span><b class="num">{net?.mtu ?? '—'}</b></div>
    <div class="kvi"><span>Broadcast</span><b>{yesNo(net?.broadcast, t('common.on'), t('common.off'))}</b></div>
    <div class="kvi"><span>IPv6</span><b>{net?.v6?.map(v6Label).join(', ') ?? t('net.v6none')}</b></div>
    <div class="kvi"><span>{t('net.created')}</span><b>{created}</b></div>
    <div class="kvi"><span>{t('net.revision')}</span><b class="num">{loc?.revision ?? '—'}</b></div>
    <div class="kvi"><span>{t('net.interface')}</span><b class="mono" style="font-size:13.5px">{loc?.device ?? '—'}</b></div>
  </div>
</div>

<div class="grid">
  <div class="card s12">
    <div class="card-h"><h2>{t('net.reaches', { hub: hubName })}</h2><span class="note">{t('net.reachesNote')}</span></div>
    {#if !loc}
      <div class="card-b"><p class="muted" style="margin:0">{t('net.noLocalA')} <span class="mono">zerotier</span> {t('net.noLocalB')}</p></div>
    {:else}
      <div class="pipe head"><span></span><span>{t('net.configured')}</span><span>{t('net.received')}</span><span>{t('net.inUseOn', { hub: hubName })}</span></div>
      {#each rows as r (r.name)}
        {@const v = verdict(r)}
        <div class="pipe">
          <div class="subj"><b>{r.name}</b><span class="pill {v.cls}" style="height:20px;margin-top:4px"><span class="dot {v.cls}"></span>{v.txt}</span></div>
          {#if r.configured}
            {#each r.cells as c, i (i)}
              <div class="stage {c.st === 'ok' ? '' : c.st === 'ko' ? 'ko' : 'n'}">
                <span class="sc"><Icon name={stIcon(c.st)} size={14} /></span>
                <span class="mono" style="font-size:11.5px;text-align:center;overflow-wrap:anywhere">{c.text}</span>
                {#if c.note}<button class="copy" style="margin:0;font-size:11px" onclick={() => c.note && ui.copy(c.note)}>{c.note}</button>{/if}
              </div>
            {/each}
          {:else}
            <div class="muted" style="grid-column:span 3;text-align:center;font-size:13px">{r.empty}</div>
          {/if}
        </div>
      {/each}
      <div class="card-b" style="padding-top:14px;border-top:1px solid var(--divider)">
        <p class="t2" style="margin:0;font-size:13px;max-width:80ch">
          {t('net.footnote', { hub: hubName })}
        </p>
      </div>
    {/if}
  </div>

  <div class="card s6">
    <div class="card-h"><h2>{t('net.composition')}</h2><span class="note">{t('net.byName')}</span></div>
    <div class="card-b">
      <div class="stack">{#each types as [ty, n], i (ty)}<i style="width:{(n / Math.max(1, live.devices.length)) * 100}%;background:{shades[i]}"></i>{/each}</div>
      <div class="legendlist">
        {#each types as [ty, n], i (ty)}<div><i style="background:{shades[i]}"></i><Icon name="i-{ty}" size={14} />{typeLabel(ty)}<b>{n}</b></div>{/each}
      </div>
    </div>
  </div>
  <div class="card s6">
    <div class="card-h"><h2>{t('net.versions')}</h2><span class="note">{t('net.versionsNote')}</span></div>
    <div class="card-b">
      {#each versions as [v, n], i (v)}
        <div class="verrow" class:latest={i === 0}>
          <span class="mono">{v}</span><div class="bar"><i style="width:{(n / vmax) * 100}%"></i></div><b class="mono" style="text-align:right;font-weight:500">{n}</b>
        </div>
      {:else}<p class="muted" style="margin:0">{t('net.noVersions')}</p>{/each}
      {#if versions.length > 1}
        <p class="t2" style="margin:12px 0 0;font-size:13px"><span class="pill accent" style="height:20px">{t('net.latest')}</span> {t('net.latestText', { v: versions[0]?.[0] ?? '' })}</p>
      {/if}
    </div>
  </div>

  <div class="card s12">
    <div class="card-h"><h2>{t('net.service', { hub: hubName })}</h2><span class="note">{t('net.serviceNote')}</span></div>
    {#if zt}
      <div class="checks">
        <div class="check"><span class="ci {zt.online ? '' : 'n'}"><Icon name={zt.online ? 'i-check' : 'i-x'} size={14} /></span><div><span>{t('net.svc')}</span><b>{zt.online ? 'Online' : 'Offline'}</b></div></div>
        <div class="check"><span class="ci {zt.tcpFallback ? 'n' : ''}"><Icon name={zt.tcpFallback ? 'i-warn' : 'i-check'} size={14} /></span><div><span>{t('net.tcpFallback')}</span><b>{zt.tcpFallback ? t('net.fallbackActive') : t('net.fallbackInactive')}</b></div></div>
        <div class="check"><span class="ci {zt.portMapping === false ? 'n' : ''}"><Icon name={zt.portMapping === false ? 'i-warn' : 'i-check'} size={14} /></span><div><span>{t('net.portMapping')}</span><b>{yesNo(zt.portMapping, t('common.on'), t('common.off'))}</b></div></div>
        <div class="check"><span class="ci {zt.forceTcpRelay ? 'n' : ''}"><Icon name={zt.forceTcpRelay ? 'i-warn' : 'i-check'} size={14} /></span><div><span>{t('net.forcedRelay')}</span><b>{zt.forceTcpRelay ? t('common.yes') : t('common.no')}</b></div></div>
        <div class="check"><span class="ci n"><Icon name="i-net" size={14} /></span><div><span>{t('net.versionPort')}</span><b>{zt.version ?? '—'} · {zt.port ?? '—'}</b></div></div>
        <div class="check"><span class="ci {live.snap?.metrics ? '' : 'n'}"><Icon name={live.snap?.metrics ? 'i-check' : 'i-minus'} size={14} /></span><div><span>{t('net.metrics')}</span><b>{live.snap?.metrics ? t('common.on') : t('common.off')}</b></div></div>
      </div>
    {:else}
      <div class="card-b"><p class="muted" style="margin:0">{t('net.svcUnavailable')}</p></div>
    {/if}
  </div>
</div>
