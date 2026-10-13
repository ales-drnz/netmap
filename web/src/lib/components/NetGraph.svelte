<script lang="ts">
  // The map: the control hub in the middle, around it the "islands" of people
  // with several devices, plus single devices. Each device is a chip
  // (icon, name, latency, status); links start from the hub.
  //
  // The layout is computed ONCE per set of keys (people and devices): each poll
  // only changes colours and numbers, chips don't move, and the DOM is updated
  // by key instead of being rebuilt.
  import type { NetNode } from '$shared/api';
  import { t } from '$lib/i18n/index.svelte';
  import { type Device, type Person, statusLabel } from '$lib/model';

  let {
    people,
    hub,
    me = null,
    interactive = false,
    fill = false,
    selected = null,
    highlight = null,
    visible = null,
    onselect,
  }: {
    people: Person[];
    hub: NetNode | null;
    me?: string | null;
    interactive?: boolean;
    /** fill the parent's height too (the map page) instead of sizing by width */
    fill?: boolean;
    selected?: string | null;
    highlight?: string | null;
    visible?: ((d: Device) => boolean) | null;
    onselect?: (id: string) => void;
  } = $props();

  const CW = 156;
  const CH = 42;
  const GAP = 6;
  const PAD = 10;
  const HEAD = 30;
  const HUB_W = 172;
  const HUB_H = 52;

  interface Unit {
    key: string;
    multi: boolean;
    w: number;
    h: number;
    x: number;
    y: number;
    fixed?: boolean;
  }

  // stable layout key: changes only when people or devices change
  const layoutKey = $derived(people.map((p) => `${p.key}:${p.devices.map((d) => d.id).join(',')}`).join('|'));

  // Horizontal stretch of the rings: the map is drawn in a wide panel.
  const ASPECT = 1.7;
  const MARGIN = 16;

  /**
   * Concentric rings around the hub. People with several devices (the islands)
   * come first, biggest first, then single devices, online before offline: what
   * matters most stays closest to the centre. A ring takes units until its
   * perimeter is full, so the map grows outwards as compactly as the units allow
   * instead of spreading a few of them over one huge ellipse.
   */
  function computeLayout(ps: Person[]) {
    const units: Unit[] = ps.map((p) => {
      const multi = p.devices.length > 1;
      return {
        key: p.key,
        multi,
        w: CW + (multi ? PAD * 2 : 0),
        h: (multi ? HEAD + PAD * 2 - 4 : 0) + p.devices.length * (CH + GAP) - GAP,
        x: 0,
        y: 0,
      };
    });
    const rank = (p: Person) => (p.devices.length > 1 ? 0 : p.online ? 1 : 2);
    const order = units
      .map((u, i) => ({ u, p: ps[i] as Person }))
      .sort((a, b) => rank(a.p) - rank(b.p) || b.p.devices.length - a.p.devices.length)
      .map((x) => x.u);

    let r = Math.max(HUB_W, HUB_H) / 2 + 90;
    let i = 0;
    let ringNo = 0;
    while (i < order.length) {
      // approximate ellipse perimeter: plenty for spacing
      const rx = r * ASPECT;
      const per = 2 * Math.PI * Math.sqrt((rx * rx + r * r) / 2);
      const ring: Unit[] = [];
      let used = 0;
      let tallest = 0;
      while (i < order.length) {
        const u = order[i] as Unit;
        const size = (u.w + u.h) / 2 + 28;
        if (ring.length && used + size > per) break;
        ring.push(u);
        used += size;
        tallest = Math.max(tallest, u.h, u.w / ASPECT);
        i++;
      }
      // spread evenly; offset alternate rings so they don't line up radially
      const off = -Math.PI / 2 + (ringNo % 2 && ring.length > 1 ? Math.PI / ring.length : 0);
      ring.forEach((u, k) => {
        const a = off + (k * 2 * Math.PI) / ring.length;
        u.x = Math.cos(a) * r * ASPECT;
        u.y = Math.sin(a) * r;
      });
      r += tallest + 40;
      ringNo++;
    }
    relax([{ key: '__hub', multi: false, w: HUB_W, h: HUB_H, x: 0, y: 0, fixed: true }, ...units]);

    const boxes = new Map<string, { x: number; y: number; w: number; h: number; multi: boolean }>();
    let minX = -HUB_W / 2;
    let maxX = HUB_W / 2;
    let minY = -HUB_H / 2;
    let maxY = HUB_H / 2;
    for (const u of units) {
      const x = u.x - u.w / 2;
      const y = u.y - u.h / 2;
      boxes.set(u.key, { x, y, w: u.w, h: u.h, multi: u.multi });
      minX = Math.min(minX, x);
      maxX = Math.max(maxX, x + u.w);
      minY = Math.min(minY, y);
      maxY = Math.max(maxY, y + u.h);
    }
    const m = 24;
    return { boxes, vb: { x: minX - m, y: minY - m, w: maxX - minX + 2 * m, h: maxY - minY + 2 * m } };
  }

  /** pushes overlapping rectangles apart along the axis of least overlap */
  function relax(us: Unit[], iterations = 120) {
    for (let it = 0; it < iterations; it++) {
      let moved = false;
      for (let a = 0; a < us.length; a++) {
        for (let b = a + 1; b < us.length; b++) {
          const p = us[a] as Unit;
          const q = us[b] as Unit;
          const dx = q.x - p.x;
          const dy = q.y - p.y;
          const ox = (p.w + q.w) / 2 + MARGIN - Math.abs(dx);
          const oy = (p.h + q.h) / 2 + MARGIN - Math.abs(dy);
          if (ox <= 0 || oy <= 0) continue;
          moved = true;
          const [mx, my] = ox < oy ? [Math.sign(dx || 1) * ox, 0] : [0, Math.sign(dy || 1) * oy];
          if (p.fixed) {
            q.x += mx;
            q.y += my;
          } else if (q.fixed) {
            p.x -= mx;
            p.y -= my;
          } else {
            p.x -= mx / 2;
            p.y -= my / 2;
            q.x += mx / 2;
            q.y += my / 2;
          }
        }
      }
      if (!moved) break;
    }
  }

  const layout = $derived.by(() => {
    layoutKey; // explicit dependency: recompute only when the set changes
    return computeLayout(people);
  });

  function chipPos(p: Person, k: number) {
    const b = layout.boxes.get(p.key);
    if (!b) return { x: 0, y: 0 };
    return { x: b.x + (b.multi ? PAD : 0), y: b.y + (b.multi ? PAD - 2 + HEAD : 0) + k * (CH + GAP) };
  }

  function linkPath(x: number, y: number) {
    const left = x + CW / 2 < 0;
    const ax = left ? x + CW : x;
    const ay = y + CH / 2;
    const hx = left ? -HUB_W / 2 : HUB_W / 2;
    const mx = (hx + ax) / 2;
    return `M${hx} 0C${mx} 0 ${mx} ${ay} ${ax} ${ay}`;
  }

  const short = (s: string) => (s.length > 14 ? `${s.slice(0, 13)}…` : s);
  const sub = (d: Device) => (d.ms != null ? `${d.ms} ms` : d.status === 'relay' ? 'relay' : d.status === 'off' ? 'offline' : '—');

  // ---------- pan and zoom ----------
  let vp = $state({ k: 1, x: 0, y: 0 });
  let svgEl: SVGSVGElement | undefined = $state();
  let drag: { x: number; y: number; ox: number; oy: number; s: number } | null = null;
  let dragging = $state(false);

  export function zoom(f: number) {
    vp = { ...vp, k: Math.min(2.5, Math.max(0.5, vp.k * f)) };
  }
  export function fit() {
    vp = { k: 1, x: 0, y: 0 };
  }
  function down(e: PointerEvent) {
    if (!interactive || (e.target as Element).closest('.g-chip') || !svgEl) return;
    drag = { x: e.clientX, y: e.clientY, ox: vp.x, oy: vp.y, s: layout.vb.w / svgEl.getBoundingClientRect().width };
    dragging = true;
    (e.currentTarget as Element).setPointerCapture(e.pointerId);
  }
  function move(e: PointerEvent) {
    if (!drag) return;
    vp = { ...vp, x: drag.ox + (e.clientX - drag.x) * drag.s, y: drag.oy + (e.clientY - drag.y) * drag.s };
  }
  function up() {
    drag = null;
    dragging = false;
  }
  function wheel(e: WheelEvent) {
    // a plain wheel scrolls the page; with Ctrl/⌘ it zooms the map
    if (!interactive || !(e.ctrlKey || e.metaKey)) return;
    e.preventDefault();
    zoom(e.deltaY < 0 ? 1.1 : 1 / 1.1);
  }
</script>

<svg
  bind:this={svgEl}
  class="graph"
  class:fill
  class:drag={dragging}
  class:pannable={interactive}
  viewBox="{layout.vb.x} {layout.vb.y} {layout.vb.w} {layout.vb.h}"
  role="img"
  aria-label={t('graph.aria')}
  onpointerdown={down}
  onpointermove={move}
  onpointerup={up}
  onpointercancel={up}
  onwheel={wheel}
>
  <g transform="translate({vp.x} {vp.y}) scale({vp.k})">
    {#each people as p (p.key)}
      {#each p.devices as d, k (d.id)}
        {@const c = chipPos(p, k)}
        <path class="g-link {d.status}" d={linkPath(c.x, c.y)} />
      {/each}
    {/each}

    {#each people as p (p.key)}
      {@const b = layout.boxes.get(p.key)}
      {#if b?.multi}
        <rect class="g-island" class:mine={p.key === me} class:hl={p.key === highlight} x={b.x} y={b.y} width={b.w} height={b.h} rx="18" />
        <text class="g-iname" x={b.x + 14} y={b.y + 23}>{p.label}{p.key === me ? ` · ${t('common.you')}` : ''}</text>
        <text class="g-icount" text-anchor="end" x={b.x + b.w - 14} y={b.y + 23}>{p.online}/{p.devices.length}</text>
      {/if}
    {/each}

    <g class="g-hub">
      <rect x={-HUB_W / 2} y={-HUB_H / 2} width={HUB_W} height={HUB_H} rx="16" />
      <svg class="ic" x={-HUB_W / 2 + 14} y="-10" width="20" height="20"><use href="#i-server" /></svg>
      <text class="t1" x={-HUB_W / 2 + 44} y="-2">{short(hub?.name ?? t('graph.network'))}</text>
      <text class="t2" x={-HUB_W / 2 + 44} y="14">{hub?.ips[0] ? `hub · ${hub.ips[0]}` : t('graph.hub')}</text>
    </g>

    {#each people as p (p.key)}
      {#each p.devices as d, k (d.id)}
        {@const c = chipPos(p, k)}
        <g
          class="g-chip {d.status}"
          class:on={selected === d.id}
          class:dim={visible ? !visible(d) : false}
          tabindex={interactive || onselect ? 0 : -1}
          role="button"
          aria-label="{d.name}, {statusLabel(d.status)}"
          onclick={() => onselect?.(d.id)}
          onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && (e.preventDefault(), onselect?.(d.id))}
        >
          <title>{d.name}{d.ip ? ` · ${d.ip}` : ''}</title>
          <rect class="c" x={c.x} y={c.y} width={CW} height={CH} rx="12" />
          <svg class="ic" x={c.x + 11} y={c.y + 13} width="16" height="16"><use href="#i-{d.type}" /></svg>
          <text class="nm" x={c.x + 36} y={c.y + 18}>{short(d.name)}</text>
          <text class="sb" x={c.x + 36} y={c.y + 32}>{sub(d)}</text>
          {#if d.status === 'relay'}
            <circle cx={c.x + CW - 14} cy={c.y + CH / 2} r="4" fill="none" stroke="var(--relay)" stroke-width="1.5" />
            <path d="M{c.x + CW - 14} {c.y + CH / 2 - 4}a4 4 0 0 1 0 8z" fill="var(--relay)" />
          {:else}
            <circle class="g-st {d.status}" cx={c.x + CW - 14} cy={c.y + CH / 2} r="4" />
          {/if}
        </g>
      {/each}
    {/each}
  </g>
</svg>

<style>
  .graph {
    display: block;
    width: 100%;
    height: auto;
  }
  .fill {
    position: absolute;
    inset: 0;
    height: 100%;
  }
  .pannable {
    cursor: grab;
    touch-action: none;
  }
  .drag {
    cursor: grabbing;
  }
</style>
