import type { Key } from './i18n/index.svelte';

export interface NavItem {
  path: string;
  label: Key;
  icon: string;
  /** shortcut: g + this letter */
  key?: string;
  group: 'top' | 'net' | 'hub';
}

export const NAV_GROUP: Record<Exclude<NavItem['group'], 'top'>, Key> = {
  net: 'nav.group.net',
  hub: 'nav.group.hub',
};

export const NAV: NavItem[] = [
  { path: '/', label: 'nav.overview', icon: 'i-home', key: 'o', group: 'top' },
  { path: '/me', label: 'nav.me', icon: 'i-user', key: 'i', group: 'top' },
  { path: '/map', label: 'nav.map', icon: 'i-map', key: 'm', group: 'net' },
  { path: '/devices', label: 'nav.devices', icon: 'i-list', key: 'd', group: 'net' },
  { path: '/activity', label: 'nav.activity', icon: 'i-activity', key: 'a', group: 'net' },
  { path: '/network', label: 'nav.network', icon: 'i-net', key: 'r', group: 'net' },
  { path: '/stats', label: 'nav.stats', icon: 'i-chart', key: 's', group: 'net' },
  { path: '/services', label: 'nav.services', icon: 'i-grid', key: 'v', group: 'hub' },
  { path: '/join', label: 'nav.join', icon: 'i-join', group: 'hub' },
];
