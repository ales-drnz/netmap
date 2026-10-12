// UI state shared across pages: theme, detail drawer, command palette, toasts.
import { t } from './i18n/index.svelte';

class Ui {
  theme = $state<'light' | 'dark' | null>(null);
  drawer = $state<string | null>(null);
  palette = $state(false);
  sidebar = $state(false);
  toast = $state<string | null>(null);
  #t: ReturnType<typeof setTimeout> | null = null;

  init() {
    try {
      const t = localStorage.getItem('nm-theme');
      if (t === 'light' || t === 'dark') this.theme = t;
    } catch {
      /* storage unavailable: follow the system */
    }
  }

  isDark() {
    return this.theme ? this.theme === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
  }

  toggleTheme() {
    this.theme = this.isDark() ? 'light' : 'dark';
    document.documentElement.dataset.theme = this.theme;
    try {
      localStorage.setItem('nm-theme', this.theme);
    } catch {
      /* kept for this visit only */
    }
  }

  say(msg: string) {
    this.toast = msg;
    if (this.#t) clearTimeout(this.#t);
    this.#t = setTimeout(() => (this.toast = null), 1600);
  }

  async copy(text: string) {
    // The page is opened over http on the ZeroTier IP, which the browser doesn't
    // treat as a secure context: navigator.clipboard is missing there, so fall back.
    try {
      if (navigator.clipboard && window.isSecureContext) await navigator.clipboard.writeText(text);
      else {
        const ta = document.createElement('textarea');
        ta.value = text;
        ta.setAttribute('readonly', '');
        ta.style.cssText = 'position:fixed;opacity:0;pointer-events:none';
        document.body.appendChild(ta);
        ta.select();
        const ok = document.execCommand('copy');
        ta.remove();
        if (!ok) throw new Error('execCommand');
      }
      this.say(t('toast.copied', { text }));
    } catch {
      this.say(t('toast.copyFailed'));
    }
  }
}

export const ui = new Ui();
