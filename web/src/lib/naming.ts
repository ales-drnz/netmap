// From the device name to "whose is it" and "what is it".
// Recommended convention: person-type[-qualifier], all lowercase
// (alice-pc, bob-phone-work). The type is recognised anywhere in the name, so
// PC-Carol or LAPTOP-Dave work too; the owner is the first segment that is
// neither a type nor a qualifier. Trailing digits are ignored when grouping:
// erin2-pc ends up with erin.
import { t } from './i18n/index.svelte';

export type DeviceType = 'pc' | 'laptop' | 'phone' | 'tablet' | 'tv' | 'server' | 'console' | 'iot';

const TYPE_SYNONYMS: Record<DeviceType, string[]> = {
  pc: ['pc', 'desktop', 'fisso', 'computer', 'workstation', 'imac'],
  laptop: ['laptop', 'notebook', 'portatile', 'macbook'],
  phone: ['phone', 'iphone', 'android', 'smartphone', 'tel', 'telefono', 'pixel', 'redmi', 'galaxy', 'oneplus'],
  tablet: ['tablet', 'ipad'],
  tv: ['tv', 'televisore', 'mediacenter', 'firestick', 'chromecast', 'appletv', 'shield'],
  server: ['server', 'nas', 'controller', 'pi', 'raspberry', 'raspberrypi', 'vm', 'proxmox', 'homelab'],
  console: ['console', 'playstation', 'ps3', 'ps4', 'ps5', 'xbox', 'switch', 'wii', 'steamdeck'],
  iot: ['iot', 'cam', 'camera', 'printer', 'stampante', 'sensor', 'esp', 'domotica'],
};

export const typeLabel = (type: DeviceType) => t(`type.${type}`);

const TOKEN2TYPE = new Map<string, DeviceType>();
for (const [type, words] of Object.entries(TYPE_SYNONYMS) as [DeviceType, string[]][]) {
  for (const w of words) TOKEN2TYPE.set(w, type);
}
const QUALIFIERS = new Set(['old', 'vecchio', 'new', 'nuovo', 'work', 'lavoro', 'gaming', 'studio', 'backup', 'main']);

const tokensOf = (name: string) =>
  String(name)
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter(Boolean);
const bare = (t: string) => t.replace(/\d+$/, '');

export function typeOf(name: string): DeviceType | null {
  for (const t of tokensOf(name)) {
    const ty = TOKEN2TYPE.get(t) ?? TOKEN2TYPE.get(bare(t));
    if (ty) return ty;
  }
  return null;
}

export function ownerOf(name: string): string | null {
  for (const t of tokensOf(name)) {
    const b = bare(t);
    if (!b || TOKEN2TYPE.has(t) || TOKEN2TYPE.has(b) || QUALIFIERS.has(b)) continue;
    return b;
  }
  return null;
}

export const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
