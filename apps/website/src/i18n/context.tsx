'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import en from '../../messages/en.json';

const LANGS = ['en', 'ru', 'de', 'zh', 'es'] as const;
type Lang = typeof LANGS[number];

// English stays static: it is the default and the fallback base for deepMerge,
// so it has to be there on the first render. The other four were static imports
// too, which put all five catalogues — 356 kB of JSON — in the entry chunk and
// made every visitor download four languages they had not asked for.
const loaders: Record<Exclude<Lang, 'en'>, () => Promise<{ default: any }>> = {
  ru: () => import('../../messages/ru.json'),
  de: () => import('../../messages/de.json'),
  zh: () => import('../../messages/zh.json'),
  es: () => import('../../messages/es.json'),
};

interface I18nContextType {
  t: any;
  lang: string;
  setLang: (lang: string) => void;
  switchLang: () => void;
  availableLangs: readonly string[];
}

const I18nContext = createContext<I18nContextType | null>(null);

// Reading localStorage is not always allowed. In a sandboxed iframe without
// allow-same-origin the property access itself throws SecurityError, and this
// one ran inside the useState initialiser — before the first render — so the
// throw took the whole tree down and the page was a black screen with one line
// in the console. A remembered language is a convenience; losing it is worth a
// paragraph of comment, and losing the site is not. Both directions are guarded
// and both fail silently back to the default.
const store = {
  get(key: string): string | null {
    try {
      return window.localStorage.getItem(key);
    } catch {
      return null;
    }
  },
  set(key: string, value: string): void {
    try {
      window.localStorage.setItem(key, value);
    } catch {
      /* no storage in this context; the choice simply is not remembered */
    }
  },
};

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>(() => {
    // Client-side only initialization
    if (typeof window !== 'undefined') {
      // 1. Check URL param - e.g., ?lang=ru
      const urlParams = new URLSearchParams(window.location.search);
      const urlLang = urlParams.get('lang');
      if (urlLang && LANGS.includes(urlLang as Lang)) {
        store.set('trinity-lang', urlLang);
        return urlLang as Lang;
      }
      
      // 2. Check localStorage
      const saved = store.get('trinity-lang');
      if (saved && LANGS.includes(saved as Lang)) {
        return saved as Lang;
      }
      
      // No browser auto-detection. It used to read navigator.language and pick
      // the language itself, so a visitor never chose one and could not tell that
      // choosing was possible: the page simply arrived in Russian, and the
      // switcher looked inert because it already agreed with the browser.
      // English is the default; another language is the reader's decision and is
      // remembered from then on. ?lang=ru still works, and the static landings
      // link to it.
    }
    return 'en';
  });
  const [mounted, setMounted] = useState(false);
  const [catalogues, setCatalogues] = useState<Record<string, any>>({ en });

  // Set mounted flag on client
  useEffect(() => {
    setMounted(true);
  }, []);

  // Pull in the selected catalogue on demand. Until it arrives the page renders
  // in English rather than blocking — deepMerge below already treats a missing
  // override as "use the base".
  useEffect(() => {
    if (lang === 'en' || catalogues[lang]) return;
    let cancelled = false;
    loaders[lang as Exclude<Lang, 'en'>]().then((mod) => {
      if (!cancelled) setCatalogues((prev) => ({ ...prev, [lang]: mod.default }));
    });
    return () => { cancelled = true; };
  }, [lang, catalogues]);

  // Save to localStorage when lang changes
  useEffect(() => {
    if (mounted) {
      store.set('trinity-lang', lang);
      document.documentElement.lang = lang;
    }
  }, [lang, mounted]);

  // Deep merge with English fallback to prevent crashes on missing keys
  const deepMerge = (base: any, override: any): any => {
    if (!override) return base;
    if (typeof base !== 'object' || typeof override !== 'object') return override;
    
    const merged = { ...base };
    for (const key in override) {
      if (typeof override[key] === 'object' && override[key] !== null && !Array.isArray(override[key])) {
        merged[key] = deepMerge(base[key] || {}, override[key]);
      } else {
        merged[key] = override[key];
      }
    }
    return merged;
  };

  const t = lang === 'en' ? en : deepMerge(en, catalogues[lang]);

  const setLang = (newLang: string) => {
    console.log('Setting language:', newLang, 'current:', lang);
    if (LANGS.includes(newLang as Lang)) {
      setLangState(newLang as Lang);
    } else {
      console.warn('Invalid language:', newLang);
    }
  };

  const switchLang = () => {
    const idx = LANGS.indexOf(lang);
    const nextIdx = (idx + 1) % LANGS.length;
    setLangState(LANGS[nextIdx]);
  };

  return (
    <I18nContext.Provider value={{ t, lang, setLang, switchLang, availableLangs: LANGS }}>
      {children}
    </I18nContext.Provider>
  );
}

export const useI18n = (): I18nContextType => {
  const context = useContext(I18nContext);
  if (!context) {
    return { t: en, lang: 'en', setLang: () => {}, switchLang: () => {}, availableLangs: LANGS };
  }
  return context;
};
