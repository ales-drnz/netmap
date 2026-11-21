// Service icons, fetched by the server so the browser never leaves Netmap's
// own origin (the page is cross-origin isolated, and Flutter needs the pixels:
// an icon loaded straight from the service would be blocked).
//
// The same rules as the reachability check, plus limits:
// - only the scheme, host and port of the configured URL (its origin); a
//   redirect is followed only when it stays on that origin, at most 3 times;
// - the page is read for <link rel="icon"> / apple-touch-icon, then
//   /favicon.ico is tried; nothing else is requested;
// - at most 128 KB of HTML and 256 KB per image, 3 s per request;
// - an image counts only if its first bytes say PNG, ICO, JPEG, GIF or WebP:
//   SVG (which can carry scripts) and anything else is refused;
// - fetched once a day per service; a failure is retried after an hour.
//
// An `icon` in services.json (an http(s) URL, or a file next to
// services.json) replaces the automatic search for that service.

import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

export const ICON_MAX_BYTES = 256 * 1024;
export const HTML_MAX_BYTES = 128 * 1024;
export const ICON_TIMEOUT_MS = 3000;
export const ICON_REFRESH_MS = 24 * 3600e3;
export const ICON_RETRY_MS = 3600e3;
const MAX_REDIRECTS = 3;

export type IconType = 'image/png' | 'image/x-icon' | 'image/jpeg' | 'image/gif' | 'image/webp';

export interface Icon {
  type: IconType;
  bytes: Buffer;
  /** short content hash, used in the URL so browsers can cache it for good */
  hash: string;
}

/** The image type from its first bytes; null if it is not one we accept. */
export function sniffImage(b: Uint8Array): IconType | null {
  const at = (i: number, ...xs: number[]) => xs.every((x, k) => b[i + k] === x);
  if (b.length >= 8 && at(0, 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)) return 'image/png';
  if (b.length >= 4 && at(0, 0x00, 0x00, 0x01, 0x00)) return 'image/x-icon';
  if (b.length >= 3 && at(0, 0xff, 0xd8, 0xff)) return 'image/jpeg';
  if (b.length >= 6 && (at(0, 0x47, 0x49, 0x46, 0x38, 0x37, 0x61) || at(0, 0x47, 0x49, 0x46, 0x38, 0x39, 0x61)))
    return 'image/gif';
  if (b.length >= 12 && at(0, 0x52, 0x49, 0x46, 0x46) && at(8, 0x57, 0x45, 0x42, 0x50)) return 'image/webp';
  return null;
}

/**
 * Icon candidates declared by an HTML page, best first: apple-touch-icon,
 * then icons by declared size (largest first); SVG ones are skipped.
 */
export function iconLinks(html: string, base: string): string[] {
  const found: { href: string; score: number }[] = [];
  for (const m of html.matchAll(/<link\b[^>]*>/gi)) {
    const tag = m[0];
    const attr = (name: string) =>
      new RegExp(`\\b${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s"'>]+))`, 'i')
        .exec(tag)
        ?.slice(1)
        .find((x) => x != null) ?? null;
    const rel = (attr('rel') ?? '').toLowerCase().split(/\s+/);
    if (!rel.includes('icon') && !rel.includes('apple-touch-icon') && !rel.includes('apple-touch-icon-precomposed'))
      continue;
    const href = attr('href');
    if (!href) continue;
    if ((attr('type') ?? '').includes('svg') || /\.svg(\?|#|$)/i.test(href)) continue;
    let url: string;
    try {
      url = new URL(href, base).toString();
    } catch {
      continue;
    }
    const size = Math.max(0, ...[...(attr('sizes') ?? '').matchAll(/(\d+)x\d+/gi)].map((s) => Number(s[1])));
    const touch = rel.some((r) => r.startsWith('apple-touch-icon'));
    found.push({ href: url, score: (touch ? 1000 : 0) + (size || (touch ? 180 : 16)) });
  }
  return [...new Set(found.sort((a, b) => b.score - a.score).map((f) => f.href))];
}

/** Reads a response body, stopping (and failing) past [max] bytes. */
async function readCapped(res: Response, max: number): Promise<Buffer | null> {
  if (!res.body) return null;
  const reader = res.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > max) {
      await reader.cancel().catch(() => {});
      return null;
    }
    chunks.push(value);
  }
  return Buffer.concat(chunks);
}

/** GET [url], following redirects only while they stay on [origin]. */
async function getSameOrigin(
  url: string,
  origin: string,
  max: number,
  timeoutMs: number,
): Promise<{ url: string; body: Buffer } | null> {
  let current = url;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    if (new URL(current).origin !== origin) return null;
    let res: Response;
    try {
      res = await fetch(current, {
        redirect: 'manual',
        signal: AbortSignal.timeout(timeoutMs),
        headers: { Accept: '*/*' },
      });
    } catch {
      return null;
    }
    if (res.status >= 300 && res.status < 400) {
      const loc = res.headers.get('location');
      await res.body?.cancel().catch(() => {});
      if (!loc) return null;
      current = new URL(loc, current).toString();
      continue;
    }
    if (!res.ok) {
      await res.body?.cancel().catch(() => {});
      return null;
    }
    try {
      const body = await readCapped(res, max);
      return body ? { url: current, body } : null;
    } catch {
      return null;
    }
  }
  return null;
}

function asIcon(bytes: Buffer): Icon | null {
  const type = sniffImage(bytes);
  if (!type) return null;
  return { type, bytes, hash: createHash('sha256').update(bytes).digest('hex').slice(0, 12) };
}

/** Finds the icon of the service at [serviceUrl], or null. Never leaves its origin. */
export async function discoverIcon(serviceUrl: string, timeoutMs = ICON_TIMEOUT_MS): Promise<Icon | null> {
  let origin: string;
  try {
    const u = new URL(serviceUrl);
    if (u.protocol !== 'http:' && u.protocol !== 'https:') return null;
    origin = u.origin;
  } catch {
    return null;
  }
  const page = await getSameOrigin(serviceUrl, origin, HTML_MAX_BYTES, timeoutMs);
  const candidates = page ? iconLinks(page.body.toString('utf8'), page.url) : [];
  candidates.push(new URL('/favicon.ico', origin).toString());
  for (const c of candidates) {
    if (new URL(c).origin !== origin) continue; // an icon elsewhere is not followed
    const got = await getSameOrigin(c, origin, ICON_MAX_BYTES, timeoutMs);
    const icon = got && asIcon(got.body);
    if (icon) return icon;
  }
  return null;
}

/** An icon set by hand in services.json: an http(s) URL, or a file next to it. */
export async function configuredIcon(
  icon: string,
  servicesDir: string,
  timeoutMs = ICON_TIMEOUT_MS,
): Promise<Icon | null> {
  if (/^https?:\/\//i.test(icon)) {
    const got = await getSameOrigin(icon, new URL(icon).origin, ICON_MAX_BYTES, timeoutMs);
    return got ? asIcon(got.body) : null;
  }
  const file = path.resolve(servicesDir, icon);
  try {
    const stat = fs.statSync(file);
    if (!stat.isFile() || stat.size > ICON_MAX_BYTES) return null;
    return asIcon(fs.readFileSync(file));
  } catch {
    return null;
  }
}

export type IconFinder = (service: { url: string; icon?: string }) => Promise<Icon | null>;

/** One icon per service, refreshed in the background; never blocks a poll. */
export class IconCache {
  private icons = new Map<string, Icon>();
  private tried = new Map<string, { at: number; ok: boolean }>();
  private busy = new Set<string>();

  constructor(private readonly find: IconFinder) {}

  /** Starts a fetch for [name] if it is due. Returns the pending work (tests await it). */
  refresh(name: string, service: { url: string; icon?: string }, now: number): Promise<void> {
    const last = this.tried.get(name);
    const due = !last || now - last.at >= (last.ok ? ICON_REFRESH_MS : ICON_RETRY_MS);
    if (!due || this.busy.has(name)) return Promise.resolve();
    this.busy.add(name);
    return this.find(service)
      .catch(() => null)
      .then((icon) => {
        this.tried.set(name, { at: now, ok: icon != null });
        if (icon) this.icons.set(name, icon);
      })
      .finally(() => this.busy.delete(name));
  }

  get(name: string): Icon | null {
    return this.icons.get(name) ?? null;
  }

  forgetAllBut(names: Set<string>): void {
    for (const n of [...this.icons.keys()]) if (!names.has(n)) this.icons.delete(n);
    for (const n of [...this.tried.keys()]) if (!names.has(n)) this.tried.delete(n);
  }
}
