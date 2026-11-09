<script lang="ts">
  // Status badge: marker + word, 20px pill, `*-fg` on `*-bg`.
  //   <StatusBadge kind={d.kind} />                     → "● LAN"
  //   <StatusBadge kind="offline" detail="2 d ago" />   → "○ Offline · 2 d ago"
  //   <StatusBadge kind="direct-wan" label="answers · 3 ms" />  (custom word)
  // kind: direct-lan | direct-wan | relay | offline | fault | unknown
  // (Device.kind from model.ts; statusKindOf(node) for a raw NetNode).
  import { kindLabel, type StatusKind } from '$lib/model';
  import StatusMarker from './StatusMarker.svelte';

  let { kind, label, detail, title }: { kind: StatusKind; label?: string; detail?: string | null; title?: string } = $props();

  const TONE: Record<StatusKind, string> = {
    'direct-lan': 'ok',
    'direct-wan': 'ok',
    relay: 'relay',
    offline: 'off',
    fault: 'err',
    unknown: '',
  };
</script>

<span class="badge {TONE[kind]}" {title}>
  <StatusMarker {kind} />{label ?? kindLabel(kind)}{#if detail}<span class="badge-detail">· {detail}</span>{/if}
</span>
