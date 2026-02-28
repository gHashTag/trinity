/**
 * TRINITY i18n Framework v20.φ
 * Internationalization with φ-optimized string handling
 * 
 * φ² + 1/φ² = 3
 */

// Supported languages
export const LANGUAGES = {
  en: 'English',
  ru: 'Russkiy',
  zh: '中文',
  ja: '日本語',
  de: 'Deutsch',
  fr: 'Français',
  es: 'Español',
  pt: 'Português',
  ko: '한국어',
  ar: 'العربية'
};

// Translation strings
const translations = {
  en: {
    // Hero
    'hero.title': 'TRINITY',
    'hero.subtitle': 'Data Structures Optimized by Golden Ratio',
    'hero.formula': 'φ² + 1/φ² = 3',
    'hero.author': 'Dmitrii Vasilev',
    
    // Abstract
    'abstract.title': 'Abstract',
    'abstract.intro': 'Trinity: unified data structures based on φ = 1.618033988749895',
    'abstract.btree': 'Trinity B-Tree: O(log_φ n) search → -30.6% comparisons',
    'abstract.cuckoo': 'φ-Cuckoo Hash: O(1) lookup → 95.1% load factor',
    'abstract.radix': 'φ-Radix Sort: O(n) distribution → -22.6% time',
    
    // Sections
    'section.btree': 'Trinity B-Tree',
    'section.cuckoo': 'φ-Cuckoo Hash',
    'section.radix': 'φ-Radix Sort',
    'section.benchmarks': 'Benchmark Results',
    'section.summary': 'Summary',
    'section.architecture': 'Architecture',
    'section.code': 'Benchmark Code (Zig)',
    'section.conclusion': 'Conclusion',
    'section.references': 'References',
    
    // Navigation
    'nav.article': 'Article',
    'nav.selftest': 'Self-Test',
    'nav.modules': 'Modules',
    
    // UI
    'ui.scroll': 'Scroll',
    'ui.theme.light': 'Light',
    'ui.theme.dark': 'Dark',
    'ui.loading': 'Loading',
    'ui.error': 'Error',
    
    // Benchmarks
    'bench.comparisons': 'comparisons',
    'bench.loadFactor': 'load factor',
    'bench.time': 'time',
    'bench.improvement': 'improvement'
  },
  
  ru: {
    // Hero
    'hero.title': 'TROITsA',
    'hero.subtitle': 'Struktury dannykh, optimizirovannye zolotym secheniem',
    'hero.formula': 'φ² + 1/φ² = 3',
    'hero.author': 'Dmitriy Vasilev',
    
    // Abstract
    'abstract.title': 'Annotatsiya',
    'abstract.intro': 'Trinity: unifitsirovannye struktury dannykh na osnove φ = 1.618033988749895',
    'abstract.btree': 'Trinity B-Tree: O(log_φ n) poisk → -30.6% sravneniy',
    'abstract.cuckoo': 'φ-Cuckoo Hash: O(1) poisk → 95.1% koeffitsient zapolneniya',
    'abstract.radix': 'φ-Radix Sort: O(n) raspredelenie → -22.6% vremeni',
    
    // Sections
    'section.btree': 'Trinity B-derevo',
    'section.cuckoo': 'φ-Kukushkin khesh',
    'section.radix': 'φ-Porazryadnaya sortirovka',
    'section.benchmarks': 'Rezultaty testov',
    'section.summary': 'Itogi',
    'section.architecture': 'Arkhitektura',
    'section.code': 'Kod testov (Zig)',
    'section.conclusion': 'Zaklyuchenie',
    'section.references': 'Literatura',
    
    // Navigation
    'nav.article': 'Statya',
    'nav.selftest': 'Samotest',
    'nav.modules': 'Moduli',
    
    // UI
    'ui.scroll': 'Prokrutka',
    'ui.theme.light': 'Svetlaya',
    'ui.theme.dark': 'Tyomnaya',
    'ui.loading': 'Zagruzka',
    'ui.error': 'Oshibka',
    
    // Benchmarks
    'bench.comparisons': 'sravneniy',
    'bench.loadFactor': 'zapolnenie',
    'bench.time': 'vremya',
    'bench.improvement': 'uluchshenie'
  },
  
  zh: {
    'hero.title': '三位一体',
    'hero.subtitle': '黄金比例优化的数据结构',
    'hero.formula': 'φ² + 1/φ² = 3',
    'hero.author': '德米特里·瓦西里耶夫',
    'abstract.title': '摘要',
    'section.btree': 'Trinity B树',
    'section.cuckoo': 'φ-布谷鸟哈希',
    'section.radix': 'φ-基数排序',
    'nav.article': '文章',
    'ui.loading': '加载中'
  },
  
  ja: {
    'hero.title': 'トリニティ',
    'hero.subtitle': '黄金比で最適化されたデータ構造',
    'hero.formula': 'φ² + 1/φ² = 3',
    'abstract.title': '概要',
    'nav.article': '記事',
    'ui.loading': '読み込み中'
  }
};

// Current language
let currentLang = 'en';

/**
 * Initialize i18n
 * @param {string} lang - Language code
 */
export function init(lang = null) {
  // Detect language from browser or localStorage
  const stored = localStorage.getItem('trinity-lang');
  const browser = navigator.language?.split('-')[0];
  
  currentLang = lang || stored || (LANGUAGES[browser] ? browser : 'en');
  localStorage.setItem('trinity-lang', currentLang);
  
  console.log(`🌍 i18n initialized: ${currentLang}`);
  return currentLang;
}

/**
 * Get current language
 * @returns {string}
 */
export function getLang() {
  return currentLang;
}

/**
 * Set language
 * @param {string} lang - Language code
 */
export function setLang(lang) {
  if (LANGUAGES[lang]) {
    currentLang = lang;
    localStorage.setItem('trinity-lang', lang);
    // Dispatch event for UI update
    window.dispatchEvent(new CustomEvent('langchange', { detail: { lang } }));
    return true;
  }
  return false;
}

/**
 * Get translated string
 * @param {string} key - Translation key
 * @param {object} params - Interpolation parameters
 * @returns {string}
 */
export function t(key, params = {}) {
  // Get translation for current language, fallback to English
  let str = translations[currentLang]?.[key] || translations.en?.[key] || key;
  
  // Interpolate parameters
  for (const [param, value] of Object.entries(params)) {
    str = str.replace(`{${param}}`, value);
  }
  
  return str;
}

/**
 * Check if translation exists
 * @param {string} key - Translation key
 * @returns {boolean}
 */
export function hasTranslation(key) {
  return !!(translations[currentLang]?.[key] || translations.en?.[key]);
}

/**
 * Get all translations for current language
 * @returns {object}
 */
export function getAllTranslations() {
  return { ...translations.en, ...translations[currentLang] };
}

/**
 * Add custom translations
 * @param {string} lang - Language code
 * @param {object} strings - Translation strings
 */
export function addTranslations(lang, strings) {
  if (!translations[lang]) {
    translations[lang] = {};
  }
  Object.assign(translations[lang], strings);
}

// Export default instance
export default {
  LANGUAGES,
  init,
  getLang,
  setLang,
  t,
  hasTranslation,
  getAllTranslations,
  addTranslations
};
