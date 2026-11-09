import { describe, expect, it } from 'vitest';
import { HUB, type IslandInput, layoutIslands, MERGE_ABOVE, mergeSingles } from './islands';

const isl = (key: string, n: number): IslandInput => ({
  key,
  label: key,
  devices: Array.from({ length: n }, (_, i) => ({ id: `${key}-${i}` })),
});
const SMALL = [
  isl('alice', 3),
  isl('bob', 2),
  isl('carol', 2),
  isl('dave', 1),
  isl('erin', 1),
  isl('frank', 1),
  isl('home', 1),
];

type Box = { x: number; y: number; w: number; h: number };
const overlaps = (a: Box, b: Box) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;

describe('island layout', () => {
  it('puts the first island (the viewer) above the hub', () => {
    const L = layoutIslands(SMALL, { width: 1000, height: 800 });
    const me = L.islands[0];
    expect(me && me.y + me.h).toBeLessThan(L.cy);
    expect(me && Math.abs(me.x + me.w / 2 - L.cx)).toBeLessThan(40);
  });

  it('keeps islands apart, off the hub and inside the frame', () => {
    const L = layoutIslands(SMALL, { width: 1000, height: 800, inset: { left: 100 } });
    expect(L.crowded).toBe(false);
    expect(L.tile.size).toBe('full');
    const hub = { x: L.cx - HUB.w / 2, y: L.cy - HUB.h / 2, ...HUB };
    L.islands.forEach((a, i) => {
      expect(overlaps(a, hub)).toBe(false);
      expect(a.x).toBeGreaterThanOrEqual(100);
      expect(a.x + a.w).toBeLessThanOrEqual(1000);
      for (const b of L.islands.slice(i + 1)) expect(overlaps(a, b)).toBe(false);
    });
  });

  it('places every device inside its island', () => {
    const L = layoutIslands(SMALL, { width: 1000, height: 800 });
    for (const i of L.islands)
      for (const t of i.tiles) {
        expect(t.x).toBeGreaterThan(i.x);
        expect(t.x).toBeLessThan(i.x + i.w);
        expect(t.y).toBeGreaterThan(i.y);
        expect(t.y).toBeLessThan(i.y + i.h);
      }
  });

  it('shrinks the tiles when there is little room', () => {
    const many = Array.from({ length: 9 }, (_, i) => isl(`p${i}`, 4));
    const L = layoutIslands(many, { width: 375, height: 420, compact: true });
    expect(L.tile.size).not.toBe('full');
  });

  it('merges single-device people when there are many', () => {
    const lots = [isl('a', 3), ...Array.from({ length: MERGE_ABOVE + 2 }, (_, i) => isl(`s${i}`, 1))];
    const out = mergeSingles(lots, { key: 'others', label: 'Others' });
    expect(out.map((i) => i.key)).toEqual(['a', 'others']);
    expect(out[1]?.devices).toHaveLength(MERGE_ABOVE + 2);
    expect(mergeSingles(SMALL, { key: 'others', label: 'Others' })).toHaveLength(SMALL.length);
  });
});

describe('single devices', () => {
  it('get no island box', () => {
    const L = layoutIslands(SMALL, { width: 1000, height: 800 });
    expect(L.islands.filter((i) => i.bare).map((i) => i.key)).toEqual(['dave', 'erin', 'frank', 'home']);
    for (const i of L.islands.filter((x) => x.bare)) expect(i.w).toBe(L.tile.w);
  });
});
