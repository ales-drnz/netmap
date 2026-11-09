<script lang="ts">
  // What the network is made of: device types recognised from the names, as
  // one compact proportional bar (neutral shades, largest first) + counts.
  import { live } from '$lib/live.svelte';
  import { type DeviceType, typeLabel } from '$lib/naming';
  import Icon from './Icon.svelte';

  const types = $derived.by(() => {
    const m = new Map<DeviceType, number>();
    for (const d of live.devices) m.set(d.type, (m.get(d.type) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[1] - a[1]);
  });
  const total = $derived(Math.max(1, live.devices.length));
  // neutral steps from --series to --series-3 (no hue: types aren't states)
  const shade = (i: number) => `color-mix(in srgb, var(--series) ${Math.max(0, 100 - i * 16)}%, var(--series-3))`;
</script>

<div class="comp">
  <div class="stack" role="img" aria-label={types.map(([ty, n]) => `${typeLabel(ty)} ${n}`).join(', ')}>
    {#each types as [ty, n], i (ty)}<i style:width="{(n / total) * 100}%" style:background={shade(i)} title="{typeLabel(ty)} · {n}"></i>{/each}
  </div>
  <ul class="list">
    {#each types as [ty, n], i (ty)}
      <li>
        <i class="sw" style:background={shade(i)}></i>
        <Icon name="i-{ty}" size={14} />
        <span class="ellipsis">{typeLabel(ty)}</span>
        <b class="num">{n}</b>
      </li>
    {/each}
  </ul>
</div>

<style>
  .comp {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 16px;
  }
  .stack {
    display: flex;
    gap: 2px;
    height: 8px;
  }
  .stack i {
    border-radius: 2px;
    min-width: 3px;
  }
  .list {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: 6px 20px;
  }
  .list li {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--text-2);
    min-width: 0;
  }
  .list :global(svg) {
    color: var(--text-3);
    flex-shrink: 0;
  }
  .list b {
    margin-left: auto;
    font-weight: 500;
    color: var(--text);
  }
  .sw {
    width: 8px;
    height: 8px;
    border-radius: 2px;
    flex-shrink: 0;
  }
</style>
