<script lang="ts">
  // Key/value list with hairline rows (device detail, network technical details…).
  //   <KeyValueList rows={[
  //     { k: 'Node ID', v: n.id, mono: true },
  //     { k: 'Client', v: n.version, hint: 'newest is 1.14.2' },
  //   ]} />
  // v null/undefined/'' → "—". For rich values use the snippet form:
  //   <KeyValueList><div><dt>Path</dt><dd><StatusBadge … /></dd></div></KeyValueList>
  // flush: no side padding (when the list sits in an already padded box).
  import type { Snippet } from 'svelte';

  interface Row {
    k: string;
    v: string | number | null | undefined;
    mono?: boolean;
    hint?: string | null;
  }

  let { rows = [], flush = false, children }: { rows?: Row[]; flush?: boolean; children?: Snippet } = $props();
</script>

<dl class="kv" class:flush>
  {#each rows as r (r.k)}
    <div>
      <dt>{r.k}</dt>
      <dd class:mono={r.mono}>{r.v == null || r.v === '' ? '—' : r.v}{#if r.hint}<span class="kv-hint">{r.hint}</span>{/if}</dd>
    </div>
  {/each}
  {#if children}{@render children()}{/if}
</dl>
