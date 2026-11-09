<script lang="ts">
  // The hub's ZeroTier service: "nas · ZeroTier 1.14.2 · port 9993" and a row
  // of checks, each ✓ (fine) / ⚠ (needs attention) / – (unknown: the service
  // didn't report it — null is not false). A failing check adds its
  // explanation underneath, so nobody has to guess what to do.
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import Icon from './Icon.svelte';

  type St = 'ok' | 'warn' | 'bad' | 'na';
  interface Check {
    key: string;
    label: string;
    st: St;
    value: string;
    alert?: string;
  }

  const zt = $derived(live.snap?.health?.zt ?? null);
  const hubName = $derived(live.hub?.name ?? t('net.thisNode'));
  const metrics = $derived(live.snap?.metrics);

  const checks: Check[] = $derived.by(() => {
    const unknown = t('perf.unknown');
    if (!zt) {
      return [
        { key: 'svc', label: t('net.svc'), st: 'na', value: unknown },
        { key: 'tcp', label: t('net.tcpFallback'), st: 'na', value: unknown },
        { key: 'upnp', label: t('net.portMapping'), st: 'na', value: unknown },
        { key: 'force', label: t('net.forcedRelay'), st: 'na', value: unknown },
        { key: 'metrics', label: t('net.metrics'), st: metrics == null ? 'na' : metrics ? 'ok' : 'na', value: metrics == null ? unknown : metrics ? t('common.on') : t('common.off') },
      ];
    }
    return [
      { key: 'svc', label: t('net.svc'), st: zt.online ? 'ok' : 'bad', value: zt.online ? t('net.svcOnline') : t('net.svcOffline'), alert: zt.online ? undefined : t('net.svcOfflineText') },
      {
        key: 'tcp',
        label: t('net.tcpFallback'),
        st: zt.tcpFallback ? 'warn' : 'ok',
        value: zt.tcpFallback ? t('net.fallbackActive') : t('net.fallbackInactive'),
        alert: zt.tcpFallback ? t('alerts.tcpFallbackText') : undefined,
      },
      {
        key: 'upnp',
        label: t('net.portMapping'),
        st: zt.portMapping == null ? 'na' : zt.portMapping ? 'ok' : 'warn',
        value: zt.portMapping == null ? unknown : zt.portMapping ? t('common.on') : t('common.off'),
        alert: zt.portMapping === false ? t('alerts.portMappingText') : undefined,
      },
      {
        key: 'force',
        label: t('net.forcedRelay'),
        st: zt.forceTcpRelay ? 'warn' : 'ok',
        value: zt.forceTcpRelay ? t('common.yes') : t('common.no'),
        alert: zt.forceTcpRelay ? t('alerts.forceTcpText') : undefined,
      },
      // metrics off isn't a fault: it only means the traffic charts stay empty
      {
        key: 'metrics',
        label: t('net.metrics'),
        st: metrics ? 'ok' : 'na',
        value: metrics == null ? unknown : metrics ? t('common.on') : t('common.off'),
      },
    ];
  });
  const alerts = $derived(checks.filter((c) => c.alert));
  const ICON: Record<St, string> = { ok: 'i-check', warn: 'i-warn', bad: 'i-x', na: 'i-minus' };
  const WORD: Record<St, string> = { ok: 'perf.chkOk', warn: 'perf.chkWarn', bad: 'perf.chkBad', na: 'perf.chkNa' };
</script>

<div class="hub-h">
  <span class="t-label">{hubName}</span>
  <span class="text-3">·</span>
  <span class="text-2">ZeroTier {zt?.version ?? '—'}</span>
  <span class="text-3">·</span>
  <span class="text-2">{t('perf.port', { port: zt?.port ?? '—' })}</span>
  {#if !zt}<span class="t-caption text-3">— {t('net.svcUnavailable')}</span>{/if}
</div>
<ul class="checks">
  {#each checks as c (c.key)}
    <li class="chk">
      <span class="ic {c.st}" role="img" aria-label={t(WORD[c.st] as 'perf.chkOk')}><Icon name={ICON[c.st]} size={14} /></span>
      <span class="txt">
        <span class="t-caption text-3">{c.label}</span>
        <span class="t-label">{c.value}</span>
      </span>
    </li>
  {/each}
</ul>
{#each alerts as a (a.key)}
  <div class="alert" class:bad={checks.find((c) => c.key === a.key)?.st === 'bad'}>
    <Icon name="i-warn" size={16} />
    <p><b class="t-label">{a.label}:</b> <span class="text-2">{a.alert}</span></p>
  </div>
{/each}

<style>
  .hub-h {
    display: flex;
    align-items: baseline;
    flex-wrap: wrap;
    gap: 4px 8px;
    padding: 12px 16px;
    border-bottom: 1px solid var(--line);
  }
  .checks {
    display: grid;
    grid-template-columns: repeat(5, minmax(0, 1fr));
  }
  .chk {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    min-width: 0;
  }
  .chk + .chk {
    border-left: 1px solid var(--line);
  }
  .txt {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .ic {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    border-radius: var(--r-full);
    flex-shrink: 0;
  }
  .ic.ok {
    color: var(--ok-fg);
    background: var(--ok-bg);
  }
  .ic.warn {
    color: var(--relay-fg);
    background: var(--relay-bg);
  }
  .ic.bad {
    color: var(--err-fg);
    background: var(--err-bg);
  }
  .ic.na {
    color: var(--text-3);
    background: var(--fill);
  }
  .alert {
    display: flex;
    gap: 10px;
    padding: 10px 16px;
    border-top: 1px solid var(--line);
    background: var(--relay-bg);
  }
  .alert.bad {
    background: var(--err-bg);
  }
  .alert > :global(svg) {
    flex-shrink: 0;
    margin-top: 2px;
    color: var(--relay-fg);
  }
  .alert.bad > :global(svg) {
    color: var(--err-fg);
  }
  .alert:last-child {
    border-radius: 0 0 calc(var(--r-lg) - 1px) calc(var(--r-lg) - 1px);
  }
  @media (max-width: 900px) {
    .checks {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
    .chk + .chk {
      border-left: 0;
    }
    .chk {
      border-top: 1px solid var(--line);
    }
    .chk:nth-child(-n + 2) {
      border-top: 0;
    }
    .chk:nth-child(even) {
      border-left: 1px solid var(--line);
    }
  }
</style>
