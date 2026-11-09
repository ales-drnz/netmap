// Pure chart geometry: scales, "nice" ticks, time axes, gap-aware paths.
// No Svelte, no i18n: unit tested in scale.test.ts and shared by every Perf*/Chart* component.
//
// Chart rules (DESIGN-v2): fixed pixel heights, rounded ticks (1/2/5 × 10ⁿ),
// horizontal hairline grid only, null = gap (never carried forward), zero = zero.

export type Scale = ((v: number) => number) & { domain: [number, number]; range: [number, number] };

export function linear(domain: [number, number], range: [number, number]): Scale {
  const [d0, d1] = domain;
  const [r0, r1] = range;
  const k = d1 === d0 ? 0 : (r1 - r0) / (d1 - d0);
  const f = ((v: number) => r0 + (v - d0) * k) as Scale;
  f.domain = domain;
  f.range = range;
  return f;
}

/** log10 scale; values are clamped into the domain (so 0 ms or 2 s still land on the chart edge) */
export function log(domain: [number, number], range: [number, number]): Scale {
  const [d0, d1] = domain;
  const l0 = Math.log10(d0);
  const l1 = Math.log10(d1);
  const [r0, r1] = range;
  const f = ((v: number) => {
    const c = Math.min(d1, Math.max(d0, v));
    return r0 + ((Math.log10(c) - l0) / (l1 - l0)) * (r1 - r0);
  }) as Scale;
  f.domain = domain;
  f.range = range;
  return f;
}

/** the smallest 1/2/5 × 10ⁿ step that splits [0, max] in at most `count` intervals */
export function niceStep(max: number, count = 4): number {
  if (!(max > 0) || !Number.isFinite(max)) return 1;
  const raw = max / Math.max(1, count);
  const p = 10 ** Math.floor(Math.log10(raw));
  for (const m of [1, 2, 5, 10]) if (m * p >= raw - 1e-12) return m * p;
  return 10 * p;
}

/** ticks 0, step, 2·step … up to the first tick ≥ max (so the top tick bounds the data) */
export function niceTicks(max: number, count = 4): number[] {
  const step = niceStep(max, count);
  const top = Math.max(step, Math.ceil(max / step - 1e-9) * step);
  const out: number[] = [];
  for (let v = 0; v <= top + step / 2; v += step) out.push(Number(v.toPrecision(12)));
  return out;
}

/**
 * The best unit for a byte axis (decimal, like the bytes() formatter) given the
 * largest value: { div, unit }. Ticks are then niceTicks(max / div).
 */
export function byteUnit(max: number): { div: number; unit: 'B' | 'KB' | 'MB' | 'GB' | 'TB' } {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'] as const;
  let i = 0;
  let x = max;
  while (x >= 1000 && i < units.length - 1) {
    x /= 1000;
    i++;
  }
  return { div: 1000 ** i, unit: units[i] ?? 'B' };
}

/**
 * SVG path through `values` at x(i), y(v): a null breaks the line (gap), it is
 * never bridged or carried forward. Isolated samples are returned in `dots`.
 */
export function gapPath(
  values: readonly (number | null)[],
  x: (i: number) => number,
  y: (v: number) => number,
): { d: string; dots: [number, number][] } {
  let d = '';
  const dots: [number, number][] = [];
  let run = 0;
  let last: [number, number] = [0, 0];
  values.forEach((v, i) => {
    if (v == null || !Number.isFinite(v)) {
      if (run === 1) dots.push(last);
      run = 0;
      return;
    }
    const p: [number, number] = [x(i), y(v)];
    d += `${run ? 'L' : 'M'}${r1(p[0])} ${r1(p[1])}`;
    last = p;
    run++;
  });
  if (run === 1) dots.push(last);
  return { d, dots };
}

/**
 * Step area for bucketed values (bucket i spans x(i)…x(i+1)): one closed path per
 * run of non-null buckets, down to `base`. Nulls are gaps (no area at all).
 */
export function stepArea(
  values: readonly (number | null)[],
  x: (i: number) => number,
  y: (v: number) => number,
  base: number,
): string {
  let d = '';
  let open = false;
  let startX = 0;
  values.forEach((v, i) => {
    if (v == null || !Number.isFinite(v)) {
      if (open) d += `V${r1(base)}H${r1(startX)}Z`;
      open = false;
      return;
    }
    const x0 = x(i);
    const x1 = x(i + 1);
    const yy = r1(y(v));
    if (!open) {
      startX = x0;
      d += `M${r1(x0)} ${r1(base)}V${yy}`;
      open = true;
    } else d += `V${yy}`;
    d += `H${r1(x1)}`;
  });
  if (open) d += `V${r1(base)}H${r1(startX)}Z`;
  return d;
}

/** the matching top line of stepArea (no closing to the baseline) */
export function stepLine(
  values: readonly (number | null)[],
  x: (i: number) => number,
  y: (v: number) => number,
): string {
  let d = '';
  let open = false;
  values.forEach((v, i) => {
    if (v == null || !Number.isFinite(v)) {
      open = false;
      return;
    }
    const yy = r1(y(v));
    d += open ? `V${yy}` : `M${r1(x(i))} ${yy}`;
    d += `H${r1(x(i + 1))}`;
    open = true;
  });
  return d;
}

/** local-time ticks at the given hours of day inside [start, end) as fractions 0..1 */
export function hourTicks(start: number, end: number, hours: readonly number[]): { f: number; t: number }[] {
  const out: { f: number; t: number }[] = [];
  if (!(end > start)) return out;
  const d = new Date(start);
  d.setHours(0, 0, 0, 0);
  for (; d.getTime() < end; d.setDate(d.getDate() + 1)) {
    for (const h of hours) {
      const tm = new Date(d.getFullYear(), d.getMonth(), d.getDate(), h).getTime();
      if (tm >= start && tm < end) out.push({ f: (tm - start) / (end - start), t: tm });
    }
  }
  return out.sort((a, b) => a.t - b.t);
}

/**
 * Night bands (local `from`:00 → `to`:00, crossing midnight) inside [start, end),
 * as fractions [f0, f1] of the window.
 */
export function nightBands(start: number, end: number, from = 22, to = 7): [number, number][] {
  const out: [number, number][] = [];
  if (!(end > start)) return out;
  const span = end - start;
  const d = new Date(start);
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - 1);
  for (; d.getTime() < end; d.setDate(d.getDate() + 1)) {
    const a = new Date(d.getFullYear(), d.getMonth(), d.getDate(), from).getTime();
    const b = new Date(d.getFullYear(), d.getMonth(), d.getDate() + (to <= from ? 1 : 0), to).getTime();
    const s = Math.max(a, start);
    const e = Math.min(b, end);
    if (e > s) out.push([(s - start) / span, (e - start) / span]);
  }
  return out;
}

/** keeps a tooltip of width `w` inside [0, max] when anchored (centred) at x */
export const clampTip = (x: number, w: number, max: number) => Math.max(0, Math.min(max - w, x - w / 2));

const r1 = (v: number) => Math.round(v * 10) / 10;
