// Tiny dependency-free i18n. `i18n.lang` is reactive state, so anything that
// calls `t()` (templates, $derived, helpers in model.ts) re-runs when it changes.
import { en, type Key, type Messages, type Plural } from './en';
import { it } from './it';

export type { Key } from './en';
export type Lang = 'en' | 'it';
export type Params = Record<string, string | number>;

export const LANGS: Lang[] = ['en', 'it'];
const DICTS: Record<Lang, Messages> = { en, it };
const LOCALES: Record<Lang, string> = { en: 'en-GB', it: 'it-IT' };
const PLURALS: Record<Lang, Intl.PluralRules> = {
  en: new Intl.PluralRules(LOCALES.en),
  it: new Intl.PluralRules(LOCALES.it),
};
const STORE = 'nm-lang';

const isLang = (v: unknown): v is Lang => v === 'en' || v === 'it';

function detect(): Lang {
  try {
    const saved = localStorage.getItem(STORE);
    if (isLang(saved)) return saved;
  } catch {
    /* storage unavailable: fall back to the browser */
  }
  if (typeof navigator === 'undefined') return 'en';
  const first = navigator.languages?.[0] ?? navigator.language ?? '';
  return first.toLowerCase().startsWith('it') ? 'it' : 'en';
}

class I18n {
  lang = $state<Lang>('en');

  /** BCP 47 locale for dates and times */
  get locale() {
    return LOCALES[this.lang];
  }

  constructor() {
    if (typeof window === 'undefined') return;
    this.lang = detect();
    document.documentElement.lang = this.lang;
  }

  setLang(l: Lang) {
    this.lang = l;
    document.documentElement.lang = l;
    try {
      localStorage.setItem(STORE, l);
    } catch {
      /* kept for this visit only */
    }
  }

  toggle() {
    this.setLang(this.lang === 'en' ? 'it' : 'en');
  }

  t(key: Key, params?: Params): string {
    const msg: string | Plural = DICTS[this.lang][key] ?? en[key];
    const s =
      typeof msg === 'string'
        ? msg
        : PLURALS[this.lang].select(Number(params?.count ?? 0)) === 'one'
          ? msg.one
          : msg.other;
    if (!params) return s;
    return s.replace(/\{(\w+)\}/g, (m, k: string) => (k in params ? String(params[k]) : m));
  }

  /** decimal string in the current language: "1.5" in English, "1,5" in Italian */
  decimal(v: number, digits = 0) {
    const s = v.toFixed(digits);
    return this.lang === 'it' ? s.replace('.', ',') : s;
  }
}

export const i18n = new I18n();
export const t = (key: Key, params?: Params) => i18n.t(key, params);
