<script lang="ts">
  // Alerts: the few things that call for a decision rather than a read.
  // Hidden when there's nothing to say: an alert that's always there is an
  // alert people learn to ignore.
  import { base } from '$app/paths';
  import { t } from '$lib/i18n/index.svelte';
  import { live } from '$lib/live.svelte';
  import { duration } from '$lib/model';
  import Icon from './Icon.svelte';

  const items = $derived.by(() => {
    const out: { icon: string; title: string; text: string; href?: string; action?: string }[] = [];
    const p = live.pending;
    if (p.length) {
      out.push({
        icon: 'i-key',
        title: t('alerts.pending', { count: p.length }),
        text: `${p
          .slice(0, 2)
          .map((x) => {
            const name = x.name ?? x.id;
            return x.deauthorized ? t('alerts.revoked', { name }) : t('alerts.waiting', { name, wait: duration(x.waitingSec) });
          })
          .join('; ')}. ${t('alerts.approveHint')}`,
        href: `${base}/activity?f=join`,
        action: t('alerts.seeRequests'),
      });
    }
    const zt = live.snap?.health?.zt;
    if (zt?.tcpFallback) out.push({ icon: 'i-warn', title: t('alerts.tcpFallback'), text: t('alerts.tcpFallbackText') });
    if (zt?.forceTcpRelay) out.push({ icon: 'i-warn', title: t('alerts.forceTcp'), text: t('alerts.forceTcpText') });
    if (zt?.portMapping === false) out.push({ icon: 'i-warn', title: t('alerts.portMapping'), text: t('alerts.portMappingText') });
    return out;
  });
</script>

{#each items as a (a.title)}
  <div class="alert" role="status">
    <span class="ic"><Icon name={a.icon} /></span>
    <div><b>{a.title}</b><p>{a.text}</p></div>
    {#if a.href}<a class="btn sm act" href={a.href}>{a.action}</a>{/if}
  </div>
{/each}
