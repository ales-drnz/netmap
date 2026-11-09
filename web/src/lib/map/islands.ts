// Layout of the Home map: "islands". The hub sits in the middle of the free
// area; every person is an island (a flat rounded box) holding their devices
// as tiles, and the islands are arranged around the hub, the viewer's at 12
// o'clock. Pure geometry, no DOM.
//
// - island size follows its devices (up to `cols` per row); a person with a
//   single device gets no island: the device stands on its own (`bare`)
// - islands start on an ellipse around the hub (angle share ∝ width) and are
//   then pushed apart until none overlaps another, the hub or the frame edge
// - when they don't fit, the tiles shrink: full (icon + name) → small (icon)
//   → dot; with many people the single-device ones merge into one island

export interface IslandDevice {
  id: string;
}

export interface IslandInput {
  key: string;
  label: string;
  devices: IslandDevice[];
}

export interface Frame {
  width: number;
  height: number;
  inset?: { left?: number; top?: number; right?: number; bottom?: number };
  /** phone: start from the small tiles */
  compact?: boolean;
}

export type TileSize = 'full' | 'small' | 'dot';

interface Preset {
  size: TileSize;
  /** tile box */
  w: number;
  h: number;
  /** circle diameter */
  pin: number;
  cols: number;
  gap: number;
  pad: number;
  title: number;
}

export const PRESETS: Record<TileSize, Preset> = {
  full: { size: 'full', w: 80, h: 72, pin: 44, cols: 4, gap: 4, pad: 12, title: 32 },
  small: { size: 'small', w: 38, h: 38, pin: 30, cols: 4, gap: 4, pad: 8, title: 24 },
  // dots look small but keep a 24px tap target (WCAG 2.5.8)
  dot: { size: 'dot', w: 24, h: 24, pin: 14, cols: 6, gap: 0, pad: 8, title: 24 },
};

export interface PlacedTile {
  id: string;
  /** centre of the circle */
  x: number;
  y: number;
}

export interface PlacedIsland {
  key: string;
  label: string;
  x: number;
  y: number;
  w: number;
  h: number;
  /** one device only: drawn without the island box and title */
  bare: boolean;
  tiles: PlacedTile[];
}

export interface IslandLayout {
  cx: number;
  cy: number;
  tile: Preset;
  islands: PlacedIsland[];
  /** true when even the smallest tiles could not avoid every overlap */
  crowded: boolean;
}

/** the hub's box (tile + label), kept clear of islands */
export const HUB = { w: 96, h: 96 };
const SPACE = 14;
/** above this many islands, people with one device share an island */
export const MERGE_ABOVE = 9;

export function mergeSingles(islands: readonly IslandInput[], others: { key: string; label: string }): IslandInput[] {
  if (islands.length <= MERGE_ABOVE) return islands.slice();
  const multi = islands.filter((i) => i.devices.length > 1);
  const single = islands.filter((i) => i.devices.length === 1);
  if (single.length < 2) return islands.slice();
  return [...multi, { key: others.key, label: others.label, devices: single.flatMap((i) => i.devices) }];
}

const isBare = (isl: IslandInput) => isl.devices.length < 2;

function sizeOf(isl: IslandInput, t: Preset) {
  const n = isl.devices.length;
  if (isBare(isl)) return { cols: 1, w: t.w, h: t.h };
  const cols = Math.max(1, Math.min(n, t.cols));
  const rows = Math.max(1, Math.ceil(n / cols));
  // wide enough for the person's name (~7.5px a letter at 12–13px)
  const title = isl.label.length * (t.size === 'full' ? 8 : 7.4) + 24;
  return {
    cols,
    w: Math.max(t.pad * 2 + cols * t.w + (cols - 1) * t.gap, title),
    h: t.title + rows * t.h + (rows - 1) * t.gap + t.pad,
  };
}

interface Box {
  x: number;
  y: number;
  w: number;
  h: number;
}
const overlapX = (a: Box, b: Box) => Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x) + SPACE;
const overlapY = (a: Box, b: Box) => Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y) + SPACE;

function place(islands: readonly IslandInput[], t: Preset, f: Frame) {
  const left = f.inset?.left ?? 0;
  const top = f.inset?.top ?? 0;
  const W = Math.max(1, f.width - left - (f.inset?.right ?? 0));
  const H = Math.max(1, f.height - top - (f.inset?.bottom ?? 0));
  const cx = left + W / 2;
  const cy = top + H / 2;
  const sizes = islands.map((i) => sizeOf(i, t));
  const maxW = Math.max(0, ...sizes.map((s) => s.w));
  const maxH = Math.max(0, ...sizes.map((s) => s.h));
  const rx = Math.max(HUB.w / 2 + maxW / 2 + SPACE, W / 2 - maxW / 2 - SPACE);
  const ry = Math.max(HUB.h / 2 + maxH / 2 + SPACE, H / 2 - maxH / 2 - SPACE);

  // target angles: each island gets a share of the turn ∝ its width; the first
  // (the viewer's) is centred at 12 o'clock
  const shares = sizes.map((s) => s.w + SPACE * 2);
  const total = shares.reduce((a, b) => a + b, 0) || 1;
  let acc = -(shares[0] ?? 0) / 2;
  const targets = sizes.map((s, i) => {
    const a = -Math.PI / 2 + ((acc + (shares[i] ?? 0) / 2) / total) * 2 * Math.PI;
    acc += shares[i] ?? 0;
    // fewer islands: pull them in, they don't need the whole frame
    const k = islands.length <= 3 ? 0.7 : islands.length <= 6 ? 0.85 : 1;
    return { x: cx + Math.cos(a) * rx * k - s.w / 2, y: cy + Math.sin(a) * ry * k - s.h / 2 };
  });
  const boxes: Box[] = sizes.map((s, i) => ({ x: targets[i]?.x ?? 0, y: targets[i]?.y ?? 0, w: s.w, h: s.h }));
  const hub: Box = { x: cx - HUB.w / 2, y: cy - HUB.h / 2, w: HUB.w, h: HUB.h };
  const clamp = (b: Box) => {
    b.x = Math.min(left + W - b.w - 4, Math.max(left + 4, b.x));
    b.y = Math.min(top + H - b.h - 4, Math.max(top + 4, b.y));
  };

  // relax: push overlapping boxes apart along the shorter axis, keep off the hub
  for (let it = 0; it < 240; it++) {
    let moved = false;
    for (let i = 0; i < boxes.length; i++) {
      const a = boxes[i];
      if (!a) continue;
      for (let j = i + 1; j < boxes.length; j++) {
        const b = boxes[j];
        if (!b) continue;
        const ox = overlapX(a, b);
        const oy = overlapY(a, b);
        if (ox > 0 && oy > 0) {
          moved = true;
          if (ox < oy) {
            const d = (ox / 2) * (a.x + a.w / 2 < b.x + b.w / 2 ? -1 : 1);
            a.x += d;
            b.x -= d;
          } else {
            const d = (oy / 2) * (a.y + a.h / 2 < b.y + b.h / 2 ? -1 : 1);
            a.y += d;
            b.y -= d;
          }
        }
      }
      const ox = overlapX(a, hub);
      const oy = overlapY(a, hub);
      if (ox > 0 && oy > 0) {
        moved = true;
        if (ox < oy) a.x += ox * (a.x + a.w / 2 < cx ? -1 : 1);
        else a.y += oy * (a.y + a.h / 2 < cy ? -1 : 1);
      }
      clamp(a);
    }
    if (!moved) break;
  }
  const clash = boxes.some(
    (a, i) =>
      (overlapX(a, hub) > SPACE && overlapY(a, hub) > SPACE) ||
      boxes.some((b, j) => j > i && overlapX(a, b) > SPACE && overlapY(a, b) > SPACE),
  );

  const placed: PlacedIsland[] = islands.map((isl, i) => {
    const b = boxes[i] ?? { x: 0, y: 0, w: 0, h: 0 };
    const cols = sizes[i]?.cols ?? 1;
    // tiles centred in the island (it may be wider than them, for the name)
    const used = cols * t.w + (cols - 1) * t.gap;
    const x0 = b.x + (b.w - used) / 2;
    const bare = isBare(isl);
    return {
      key: isl.key,
      label: isl.label,
      x: b.x,
      y: b.y,
      w: b.w,
      h: b.h,
      bare,
      tiles: isl.devices.map((d, k) => ({
        id: d.id,
        x: x0 + (k % cols) * (t.w + t.gap) + t.w / 2,
        y:
          b.y +
          (bare ? 0 : t.title) +
          Math.floor(k / cols) * (t.h + t.gap) +
          t.pin / 2 +
          (t.h - t.pin) * (t.size === 'full' ? 0.15 : 0.5),
      })),
    };
  });
  return { cx, cy, islands: placed, clash };
}

export function layoutIslands(islands: readonly IslandInput[], f: Frame): IslandLayout {
  const order: TileSize[] = f.compact ? ['small', 'dot'] : ['full', 'small', 'dot'];
  let last: ReturnType<typeof place> | null = null;
  let tile = PRESETS.dot;
  for (const size of order) {
    tile = PRESETS[size];
    last = place(islands, tile, f);
    if (!last.clash) return { cx: last.cx, cy: last.cy, tile, islands: last.islands, crowded: false };
  }
  const l = last ?? place(islands, tile, f);
  return { cx: l.cx, cy: l.cy, tile, islands: l.islands, crowded: true };
}
