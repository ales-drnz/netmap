// Demo icons for the mock's fake services, drawn here as small PNGs (no image
// files in the repository, nothing downloaded): a coloured circle with a
// white mark, anti-aliased by sampling each pixel 4×4 times.
import { crc32, deflateSync } from 'node:zlib';

type Mark = (x: number, y: number) => boolean;

/** a [size]×[size] PNG: a circle in [rgb] with [mark] in white (coordinates 0..1) */
export function circleIcon(rgb: [number, number, number], mark: Mark, size = 128): Buffer {
  const raw = Buffer.alloc((size * 4 + 1) * size);
  const S = 4;
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0; // filter: none
    for (let x = 0; x < size; x++) {
      let inCircle = 0;
      let inMark = 0;
      for (let sy = 0; sy < S; sy++) {
        for (let sx = 0; sx < S; sx++) {
          const u = (x + (sx + 0.5) / S) / size;
          const v = (y + (sy + 0.5) / S) / size;
          if ((u - 0.5) ** 2 + (v - 0.5) ** 2 <= 0.25) {
            inCircle++;
            if (mark(u, v)) inMark++;
          }
        }
      }
      const a = inCircle / (S * S);
      const m = inCircle ? inMark / inCircle : 0;
      const o = y * (size * 4 + 1) + 1 + x * 4;
      raw[o] = Math.round(rgb[0] + (255 - rgb[0]) * m);
      raw[o + 1] = Math.round(rgb[1] + (255 - rgb[1]) * m);
      raw[o + 2] = Math.round(rgb[2] + (255 - rgb[2]) * m);
      raw[o + 3] = Math.round(a * 255);
    }
  }
  const chunk = (type: string, data: Buffer) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body) >>> 0);
    return Buffer.concat([len, body, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/** a "play" triangle, pointing right */
export const playMark: Mark = (u, v) => u > 0.38 && u < 0.72 && Math.abs(v - 0.5) < (0.72 - u) * 0.62;

/** three small dots in a row (a cloud of files, roughly) */
export const dotsMark: Mark = (u, v) => [0.3, 0.5, 0.7].some((cx) => (u - cx) ** 2 + (v - 0.5) ** 2 < 0.075 ** 2);
