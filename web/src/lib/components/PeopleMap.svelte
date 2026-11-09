<script lang="ts">
  // The Home map, "islands": the hub in the middle, every person with 2+
  // devices an island (a flat rounded box) holding them (a single device stands
  // on its own, no box), a line from the hub to each
  // ONLINE device. Line style = kind of link: solid green direct, dotted amber
  // relay (moving), dashed red one-way. Offline devices stay in their island,
  // dimmed, with no line. Geometry in $lib/map/islands.ts.
  //
  //   <PeopleMap devices={live.devices} hub={live.hub} me={live.myOwner} myId={id}
  //              selected={id} onselect={(id) => …} slow={hubIsSlow} inset={{ left: 432 }} />
  //
  // Every device is drawn, even one offline for weeks. With a selection the
  // rest of the map fades so the picked device and its line stand out.
  import type { NetNode } from '$shared/api';
  import { t } from '$lib/i18n/index.svelte';
  import { type IslandInput, layoutIslands, mergeSingles } from '$lib/map/islands';
  import type { Device, StatusKind } from '$lib/model';
  import Icon from './Icon.svelte';

  let {
    devices,
    hub,
    me = null,
    myId = null,
    selected = null,
    onselect,
    slow = false,
    inset = {},
  }: {
    devices: Device[];
    hub: NetNode | null;
    me?: string | null;
    myId?: string | null;
    selected?: string | null;
    onselect: (id: string) => void;
    slow?: boolean;
    inset?: { left?: number; top?: number; right?: number; bottom?: number };
  } = $props();

  let W = $state(0);
  let H = $state(0);
  const compact = $derived(W > 0 && W < 600);
  // every device, also the ones offline for more than 7 days (dimmed like any offline one)
  const shown = $derived(devices);
  const byId = $derived(new Map(shown.map((d) => [d.id, d])));

  // islands: the viewer first, then the people with more devices
  const input = $derived.by((): IslandInput[] => {
    const map = new Map<string, Device[]>();
    for (const d of shown) map.set(d.owner, [...(map.get(d.owner) ?? []), d]);
    const list = [...map.entries()]
      .map(([key, ds]) => ({
        key,
        label: ds[0]?.ownerLabel ?? key,
        devices: ds
          .slice()
          .sort((a, b) => Number(b.status !== 'off') - Number(a.status !== 'off') || a.name.localeCompare(b.name))
          .map((d) => ({ id: d.id })),
      }))
      .sort((a, b) => Number(b.key === me) - Number(a.key === me) || b.devices.length - a.devices.length || a.label.localeCompare(b.label));
    return mergeSingles(list, { key: '__others', label: t('fm.others') });
  });
  const L = $derived(layoutIslands(input, { width: W, height: H, inset, compact }));
  const tile = $derived(L.tile);
  const named = $derived(tile.size === 'full');

  const islandOf = $derived(new Map(L.islands.flatMap((i) => i.tiles.map((x) => [x.id, i.key] as const))));
  const selIsland = $derived(selected ? (islandOf.get(selected) ?? null) : null);

  const LINE: Record<StatusKind, string> = {
    'direct-lan': 'direct',
    'direct-wan': 'direct',
    relay: 'relay',
    fault: 'oneway',
    offline: 'relay',
    unknown: 'relay',
  };
  /** a gentle curve, so the lines feel drawn rather than plotted */
  const curve = (x: number, y: number) => {
    const mx = (L.cx + x) / 2 + (y - L.cy) * 0.06;
    const my = (L.cy + y) / 2 - (x - L.cx) * 0.06;
    return `M${L.cx} ${L.cy}Q${mx} ${my} ${x} ${y}`;
  };
</script>

<div
  class="pm t-{tile.size}"
  class:focus={!!selected}
  bind:clientWidth={W}
  bind:clientHeight={H}
  style:--pin="{tile.pin}px"
  style:--tw="{tile.w}px"
>
  {#if W && H}
    {#each L.islands.filter((x) => !x.bare) as i (i.key)}
      <div
        class="island"
        class:me={i.key === me}
        class:on={i.key === selIsland}
        style:left="{i.x}px"
        style:top="{i.y}px"
        style:width="{i.w}px"
        style:height="{i.h}px"
      >
        <span class="island-h ellipsis">{i.label}{#if i.key === me}&nbsp;· {t('common.you')}{/if}</span>
      </div>
    {/each}

    <svg class="links" width={W} height={H} aria-hidden="true">
      {#each L.islands as i (i.key)}
        {#each i.tiles as p (p.id)}
          {@const d = byId.get(p.id)}
          {#if d && d.status !== 'off'}<path class="link {LINE[d.kind]}" class:on={p.id === selected} d={curve(p.x, p.y)} />{/if}
        {/each}
      {/each}
    </svg>

    {#if hub}
      <div class="hub" style:left="{L.cx}px" style:top="{L.cy}px">
        <span class="hub-tile"><Icon name="i-server" size={compact ? 20 : 24} />{#if slow}<span class="badge">{t('fm.slow')}</span>{/if}</span>
        <span class="hub-label">{t('fm.hub', { name: hub.name })}</span>
      </div>
    {/if}

    {#each L.islands as i (i.key)}
      {#each i.tiles as p (p.id)}
        {@const d = byId.get(p.id)}
        {#if d}
          <button
            class="pin k-{d.kind}"
            class:you={d.id === myId}
            class:on={d.id === selected}
            style:left="{p.x}px"
            style:top="{p.y}px"
            title={named ? undefined : d.name}
            aria-label="{d.name}, {d.ownerLabel}: {t(`fm.w.${d.kind}`)}"
            aria-pressed={d.id === selected}
            onclick={() => onselect(d.id)}
          >
            <span class="bubble">{#if tile.size !== 'dot'}<Icon name="i-{d.type}" size={Math.round(tile.pin * 0.48)} />{/if}</span>
            {#if named}<span class="name ellipsis">{d.id === myId ? t('common.you') : d.name}</span>{/if}
          </button>
        {/if}
      {/each}
    {/each}
  {/if}
</div>

<style>
  .pm {
    position: absolute;
    inset: 0;
    overflow: hidden;
    background: var(--canvas);
  }

  /* islands: flat boxes, the person's name in the corner */
  /* opaque, and above the lines: a line stops at the island's edge
     instead of crossing it (the devices sit on top of both) */
  .island {
    position: absolute;
    z-index: 2;
    border-radius: 20px;
    background: color-mix(in srgb, var(--text) 7%, var(--canvas));
    transition: opacity var(--d-slow) var(--ease);
  }
  .island.me {
    background: color-mix(in srgb, var(--you) 9%, var(--canvas));
  }
  .island-h {
    transition: opacity var(--d-slow) var(--ease);
    display: block;
    padding: 12px 12px 0;
    color: var(--text-2);
    font: 600 13px/16px var(--font);
  }
  .island.me .island-h {
    color: color-mix(in srgb, var(--you-fg) 85%, var(--text));
  }
  .t-dot .island-h,
  .t-small .island-h {
    padding: 8px 12px 0;
    font-size: 12px;
  }

  .links {
    position: absolute;
    z-index: 1;
    inset: 0;
    overflow: visible;
    pointer-events: none;
  }
  .link {
    fill: none;
    stroke-linecap: round;
    stroke-width: 2;
    transition: opacity var(--d-slow) var(--ease);
  }
  .link.direct {
    stroke: var(--ok-fg);
    opacity: 0.8;
  }
  .link.relay {
    stroke: var(--relay-fg);
    stroke-dasharray: 1 6;
    opacity: 0.9;
    animation: flow 1.6s linear infinite;
  }
  .link.oneway {
    stroke: var(--err);
    stroke-dasharray: 6 5;
    opacity: 0.85;
  }
  @keyframes flow {
    to {
      stroke-dashoffset: -14;
    }
  }

  /* the hub: a dark rounded square, like the logo */
  .hub {
    position: absolute;
    z-index: 3;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    transform: translate(-50%, -28px);
  }
  .hub-tile {
    position: relative;
    display: grid;
    place-items: center;
    width: 56px;
    height: 56px;
    border-radius: 16px;
    background: var(--text);
    color: var(--canvas);
  }
  .hub-label {
    padding: 4px 8px;
    border-radius: var(--r-full);
    background: var(--canvas);
    color: var(--text);
    font: 600 12px/16px var(--font);
    white-space: nowrap;
  }
  .badge {
    position: absolute;
    top: -10px;
    left: 50%;
    transform: translateX(-50%);
    padding: 4px 6px;
    border-radius: var(--r-full);
    background: var(--relay);
    color: #111113; /* readable on amber in both themes */
    font: 650 10px/1 var(--font);
  }

  /* devices: a status-tinted circle (flat) and the name under it */
  .pin {
    position: absolute;
    z-index: 3;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 5px;
    width: var(--tw);
    padding: 0;
    border: 0;
    background: none;
    color: inherit;
    font: inherit;
    cursor: pointer;
    transform: translate(-50%, calc(var(--pin) / -2));
    transition: opacity var(--d-slow) var(--ease);
  }
  .pin:focus-visible {
    outline: none;
  }
  .pin:focus-visible .bubble {
    outline: 2px solid var(--focus);
    outline-offset: 3px;
  }
  .bubble {
    position: relative;
    display: grid;
    place-items: center;
    width: var(--pin);
    height: var(--pin);
    border-radius: 50%;
    background: color-mix(in srgb, var(--c, var(--off)) 20%, var(--canvas));
    color: var(--c-fg, var(--text-3));
    transition: transform var(--d-base) var(--ease);
  }
  .pin:hover .bubble {
    transform: scale(1.08);
  }
  .pin.on .bubble {
    transform: scale(1.15);
  }
  .t-dot .bubble {
    background: var(--c, var(--off));
  }
  .k-direct-lan,
  .k-direct-wan {
    --c: var(--ok);
    --c-fg: var(--ok-fg);
  }
  .k-relay {
    --c: var(--relay);
    --c-fg: var(--relay-fg);
  }
  .k-fault {
    --c: var(--err);
    --c-fg: var(--err-fg);
  }
  .k-offline,
  .k-unknown {
    --c: var(--off);
    --c-fg: var(--text-3);
  }
  .k-offline .bubble {
    background: var(--tint);
  }
  .k-offline .name {
    color: var(--text-3);
  }
  .name {
    max-width: 100%;
    color: var(--text-2);
    font: 500 12px/16px var(--font);
  }
  .you .name {
    color: color-mix(in srgb, var(--you-fg) 85%, var(--text));
    font-weight: 600;
    text-transform: capitalize;
  }
  /* you: a soft filled pulse behind your circle */
  .you .bubble::after {
    content: '';
    position: absolute;
    z-index: -1;
    inset: 0;
    border-radius: 50%;
    background: var(--you);
    animation: halo 2.4s var(--ease) infinite;
  }
  @keyframes halo {
    0% {
      transform: scale(1);
      opacity: 0.45;
    }
    100% {
      transform: scale(1.8);
      opacity: 0;
    }
  }

  /* a device picked: everything else steps back */
  /* islands stay opaque (so lines never show through): only their title fades */
  .focus .island:not(.on) .island-h,
  .focus .pin,
  .focus .link {
    opacity: 0.45;
  }
  .focus .pin.on,
  .focus .pin:hover,
  .focus .pin:focus-visible,
  .focus .link.on {
    opacity: 1;
  }
  /* dots: the hit area is the whole 24px tile */
  .t-dot .pin {
    height: 24px;
    justify-content: center;
    transform: translate(-50%, -12px);
  }

  @media (prefers-reduced-motion: reduce) {
    .link.relay,
    .you .bubble::after {
      animation: none;
    }
    /* no pulse: a still, soft halo keeps "you" visible */
    .you .bubble::after {
      transform: scale(1.35);
      opacity: 0.3;
    }
    .island,
    .pin,
    .bubble,
    .link {
      transition: none;
    }
  }
</style>
