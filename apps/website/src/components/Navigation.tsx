import { useState, useEffect, memo, useCallback } from 'react'
import { useI18n } from '../i18n/context'
import LanguageSwitcher from './LanguageSwitcher'

const sectionIds = ['hero', 'theorems', 'solution', 'benchmarks', 'calculator', 'depin', 'tech-tree', 'team', 'science', 'invest']
const BASE = import.meta.env.BASE_URL

export default memo(function Navigation() {
  const { t } = useI18n()
  const [active, setActive] = useState('hero')
  const [menuOpen, setMenuOpen] = useState(false)

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

  const scrollTo = useCallback((id: string) => {
    setMenuOpen(false)
    setTimeout(() => {
      document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })
    }, 100)
  }, [])

  // Handle escape key to close menu
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && menuOpen) {
        setMenuOpen(false)
      }
    }
    window.addEventListener('keydown', handleEscape)
    return () => window.removeEventListener('keydown', handleEscape)
  }, [menuOpen])

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
        <a
          href={`${BASE}dashboard`}
          style={{ color: '#00ccff', fontWeight: 600 }}
          aria-label="Go to Dashboard"
        >
          {t.navExtra?.dashboard || 'Dashboard'}
        </a>
        <a
          href={`${BASE}docs/`}
          target="_blank"
          rel="noopener noreferrer"
          style={{ color: 'var(--accent)', fontWeight: 600 }}
          aria-label="Open documentation in new tab"
        >
          {t.navExtra?.docs || 'Docs'}
        </a>
        <LanguageSwitcher />
      </nav>

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
              <a
                href={`${BASE}dashboard`}
                style={{ color: '#00ccff' }}
                onClick={() => setMenuOpen(false)}
                aria-label="Go to Dashboard"
              >
                {t.navExtra?.dashboard || 'Dashboard'}
              </a>
              <a
                href={`${BASE}docs/`}
                target="_blank"
                rel="noopener noreferrer"
                style={{ color: 'var(--accent)' }}
                onClick={() => setMenuOpen(false)}
                aria-label="Open documentation in new tab"
              >
                {t.navExtra?.docs || 'Docs'}
              </a>
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
