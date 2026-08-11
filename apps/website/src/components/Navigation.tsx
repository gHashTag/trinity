import { useState, useEffect, memo, useCallback } from 'react'
import { useI18n } from '../i18n/context'
import LanguageSwitcher from './LanguageSwitcher'

const sectionIds = ['hero', 'theorems', 'publications', 'solution', 'benchmarks', 'calculator', 'depin', 'team', 'invest']
const BASE = import.meta.env.BASE_URL
// Docs points to t27.ai/docs/ (custom domain)
const DOCS_URL = 'https://t27.ai/docs/'

// The locale files have no keys for the commercial pages yet, so the labels
// live next to the links. Missing locales fall back to English.
const PAGES_LABEL: Record<string, string> = {
  ru: 'Страницы', de: 'Seiten', es: 'Páginas', zh: '页面',
}

type PageLink = { href: string; en: string; ru: string; note: string; noteRu: string; external?: boolean; color?: string }

// Every link that leaves the one-page scroll. These outgrew the dock — a single
// fixed-height row with no room left — so they live behind one disclosure
// instead of pushing each other off the right edge.
const PAGES: PageLink[] = [
  { href: '#/gft', en: 'GF-T format', ru: 'Формат GF-T', note: '2.84× and 5.53× more accurate than tekum16', noteRu: 'В 2.84 и 5.53 раза точнее tekum16' },
  { href: '#/start', en: 'Start here', ru: 'С чего начать', note: 'Four checks you can run yourself, in order', noteRu: 'Четыре проверки, которые запускаете сами, по порядку' },
  { href: '#/verification', en: 'Verification', ru: 'Верификация', note: 'Send RTL, get it measured on live silicon', noteRu: 'Присылаете RTL — измеряю на живом кремнии' },
  { href: '#/ip', en: 'Licensing', ru: 'Лицензирование', note: 'Arithmetic cores that have been to silicon', noteRu: 'Ядра, уже прошедшие кремний' },
  { href: '#/proof', en: 'Proof', ru: 'Доказательства', note: 'Every measured number, and its limits', noteRu: 'Все измеренные цифры и их границы' },
  { href: '#/cases', en: 'Case studies', ru: 'Работы', note: 'Verification runs on other people’s RTL', noteRu: 'Прогоны чужого RTL' },
  { href: '#/course', en: 'Course', ru: 'Курс', note: 'Train a neural network on an FPGA', noteRu: 'Обучите нейросеть прямо на FPGA' },
  { href: '#/about', en: 'About', ru: 'Об авторе', note: 'Background, papers, contact', noteRu: 'Биография, статьи, контакты' },
  { href: '#/resources', en: 'Resources', ru: 'Материалы', note: 'Papers and datasets, each with a DOI', noteRu: 'Статьи и датасеты, у каждого DOI' },
  { href: '#/blog', en: 'Blog', ru: 'Блог', note: 'Notes on the work as it happens', noteRu: 'Заметки по ходу работы' },
  { href: '#/dashboard', en: 'Dashboard', ru: 'Панель', note: 'Project metrics', noteRu: 'Метрики проекта', color: '#00ccff' },
  { href: '#/tree', en: 'Research Lab', ru: 'Исслед. лаб', note: 'Interactive visualisations', noteRu: 'Интерактивные визуализации', color: '#ffd700' },
  { href: DOCS_URL, en: 'Docs', ru: 'Документация', note: 'Full documentation', noteRu: 'Полная документация', external: true },
]

// Smooth scrolling is animation-driven, so it silently does nothing when
// animations are not running — a hidden or backgrounded tab, or a reader who has
// asked their system for reduced motion. Getting there instantly is always better
// than not getting there at all.
function scrollBehaviour(): ScrollBehavior {
  const reduced = typeof window.matchMedia === 'function'
    && window.matchMedia('(prefers-reduced-motion: reduce)').matches
  return reduced || document.hidden ? 'auto' : 'smooth'
}

// Find a section that may not have mounted yet, then scroll to it.
//
// Uses a timer rather than requestAnimationFrame on purpose: rAF is throttled to
// zero in a background or hidden tab, so a correctness path built on it simply
// never runs there. Sections further down the homepage are also lazily rendered,
// so the window has to be generous — 4 seconds of 80ms polls, which stops as soon
// as the element appears.
function scrollToSectionWhenReady(id: string) {
  let tries = 0
  const tick = () => {
    const el = document.getElementById(id)
    if (el) {
      el.scrollIntoView({ behavior: scrollBehaviour() })
      return
    }
    if (++tries < 50) setTimeout(tick, 80)
  }
  tick()
}

export default memo(function Navigation() {
  const { t, lang } = useI18n()
  const [active, setActive] = useState('hero')
  const [menuOpen, setMenuOpen] = useState(false)
  const [pagesOpen, setPagesOpen] = useState(false)
  const ru = lang === 'ru'

  useEffect(() => {
    const handleScroll = () => {
      const scrollY = window.scrollY
      for (const id of sectionIds) {
        const el = document.getElementById(id)
        if (el && scrollY >= (el as HTMLElement).offsetTop - 200) {
          setActive(id)
        }
      }
    }
    window.addEventListener('scroll', handleScroll)
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  // Lock body scroll when menu is open
  useEffect(() => {
    if (menuOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => { document.body.style.overflow = '' }
  }, [menuOpen])

  // These nine links point at sections of the one-page scroll, which do not
  // exist on any routed page. Until now the handler called preventDefault and
  // then scrollIntoView on null, so every one of them was silently dead on
  // /verification, /proof, /ip, /course, /cases and /about — the whole header,
  // on six pages. From a routed page it now goes home first and scrolls after
  // the homepage has mounted.
  const scrollTo = useCallback((id: string) => {
    setMenuOpen(false)
    setPagesOpen(false)
    const hash = window.location.hash
    const onHome = hash === '' || hash === '#' || hash === '#/'
    if (!onHome) {
      window.location.hash = '#/'
      scrollToSectionWhenReady(id)
      return
    }
    scrollToSectionWhenReady(id)
  }, [])

  // Handle escape key to close menu
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (menuOpen) setMenuOpen(false)
        if (pagesOpen) setPagesOpen(false)
      }
    }
    window.addEventListener('keydown', handleEscape)
    return () => window.removeEventListener('keydown', handleEscape)
  }, [menuOpen, pagesOpen])

  // A disclosure that stays open after you click past it is a trap; close it on
  // any click outside and on scroll, since the dock is fixed and the page is not.
  useEffect(() => {
    if (!pagesOpen) return
    const close = (e: Event) => {
      const target = e.target as HTMLElement | null
      if (target?.closest('.nav-pages-panel') || target?.closest('.nav-pages-toggle')) return
      setPagesOpen(false)
    }
    window.addEventListener('click', close)
    window.addEventListener('scroll', close, { passive: true })
    return () => {
      window.removeEventListener('click', close)
      window.removeEventListener('scroll', close)
    }
  }, [pagesOpen])

  return (
    <>
      {/* Desktop dock nav */}
      <nav className="nav-dock" aria-label="Main navigation">
        {t.nav?.map((item: string, i: number) => (
          <a
            key={i}
            href={`#${sectionIds[i]}`}
            className={active === sectionIds[i] ? 'active' : ''}
            onClick={(e) => { e.preventDefault(); scrollTo(sectionIds[i]) }}
            aria-label={`Navigate to ${item}`}
            aria-current={active === sectionIds[i] ? 'page' : undefined}
          >
            {item}
          </a>
        ))}
        <button
          type="button"
          className={`nav-pages-toggle ${pagesOpen ? 'open' : ''}`}
          onClick={() => setPagesOpen((v) => !v)}
          aria-expanded={pagesOpen}
          aria-haspopup="true"
          aria-controls="nav-pages-panel"
        >
          {PAGES_LABEL[lang] || 'Pages'}
          <span className="nav-pages-caret" aria-hidden="true">▾</span>
        </button>
        <LanguageSwitcher />
      </nav>

      {/* Fixed rather than absolute: the dock scrolls horizontally, and a panel
          positioned inside it would be clipped by that overflow. */}
      {pagesOpen && (
        <div className="nav-pages-panel" id="nav-pages-panel" role="menu" aria-label={PAGES_LABEL[lang] || 'Pages'}>
          {PAGES.map((p) => (
            <a
              key={p.href}
              href={p.href}
              role="menuitem"
              target={p.external ? '_blank' : undefined}
              rel={p.external ? 'noopener noreferrer' : undefined}
              onClick={() => setPagesOpen(false)}
            >
              <span className="nav-pages-name" style={p.color ? { color: p.color } : undefined}>
                {ru ? p.ru : p.en}
              </span>
              <span className="nav-pages-note">{ru ? p.noteRu : p.note}</span>
            </a>
          ))}
        </div>
      )}

      {/* Mobile hamburger button */}
      <button
        className={`hamburger-btn ${menuOpen ? 'open' : ''}`}
        onClick={() => setMenuOpen(!menuOpen)}
        aria-label={menuOpen ? 'Close menu' : 'Open menu'}
        aria-expanded={menuOpen}
        aria-controls="mobile-menu"
        aria-haspopup="true"
      >
        <span />
        <span />
        <span />
      </button>

      {/* Mobile fullscreen menu */}
      {menuOpen && (
        <div
          className="mobile-menu-overlay"
          onClick={() => setMenuOpen(false)}
          aria-hidden="true"
        >
          <div
            className="mobile-menu"
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
            aria-labelledby="mobile-menu-title"
          >
            <h2 id="mobile-menu-title" className="visually-hidden">
              Navigation Menu
            </h2>
            <div className="mobile-menu-links" role="navigation" aria-label="Mobile navigation">
              {t.nav?.map((item: string, i: number) => (
                <a
                  key={i}
                  href={`#${sectionIds[i]}`}
                  className={active === sectionIds[i] ? 'active' : ''}
                  onClick={(e) => { e.preventDefault(); scrollTo(sectionIds[i]) }}
                  aria-label={`Navigate to ${item}`}
                  aria-current={active === sectionIds[i] ? 'page' : undefined}
                >
                  {item}
                </a>
              ))}
              {/* Same source as the desktop disclosure, so the two can't drift apart */}
              {PAGES.map((p) => (
                <a
                  key={p.href}
                  href={p.href}
                  target={p.external ? '_blank' : undefined}
                  rel={p.external ? 'noopener noreferrer' : undefined}
                  style={{ color: p.color || 'var(--accent)' }}
                  onClick={() => setMenuOpen(false)}
                >
                  {ru ? p.ru : p.en}
                </a>
              ))}
            </div>
            <div className="mobile-menu-footer">
              <LanguageSwitcher />
            </div>
          </div>
        </div>
      )}
    </>
  )
})
