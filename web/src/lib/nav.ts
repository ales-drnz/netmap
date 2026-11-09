import type { Key } from './i18n/index.svelte';

/** The four pages of the app shell (Home is the map) (top tabs on desktop, bottom tab bar on mobile). */
export interface NavItem {
  path: string;
  label: Key;
  icon: string;
  /** keyboard shortcut: g + this letter */
  key: string;
}

export const NAV: NavItem[] = [
  { path: '/', label: 'nav.home', icon: 'i-map', key: 'h' },
  { path: '/devices', label: 'nav.devices', icon: 'i-list', key: 'd' },
  { path: '/activity', label: 'nav.activity', icon: 'i-activity', key: 'a' },
  { path: '/network', label: 'nav.network', icon: 'i-net', key: 'n' },
];

/** the nav item a path belongs to (/devices/abc → Devices) */
export const navOf = (path: string): NavItem | null =>
  NAV.find((n) => (n.path === '/' ? path === '/' : path === n.path || path.startsWith(`${n.path}/`))) ?? null;
