import { useState, useEffect, memo, useCallback } from 'react'
import { useI18n } from '../i18n/context'
import LanguageSwitcher from './LanguageSwitcher'

const sectionIds = ['hero', 'theorems', 'solution', 'benchmarks', 'calculator', 'depin', 'tech-tree', 'team', 'science', 'invest']

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

  return (
    <>
      {/* Desktop dock nav */}
      <nav className="nav-dock">
        {t.nav?.map((item: string, i: number) => (
          <a
            key={i}
            href={`#${sectionIds[i]}`}
            className={active === sectionIds[i] ? 'active' : ''}
            onClick={(e) => { e.preventDefault(); scrollTo(sectionIds[i]) }}
          >
            {item}
          </a>
        ))}
        <a
          href="/trinity/dashboard"
          style={{ color: '#00ccff', fontWeight: 600 }}
        >
          {t.navExtra?.dashboard || 'Dashboard'}
        </a>
        <a
          href="/trinity/docs/"
          target="_blank"
          rel="noopener noreferrer"
          style={{ color: 'var(--accent)', fontWeight: 600 }}
        >
          {t.navExtra?.docs || 'Docs'}
        </a>
        <LanguageSwitcher />
      </nav>

      {/* Mobile hamburger button */}
      <button
        className={`hamburger-btn ${menuOpen ? 'open' : ''}`}
        onClick={() => setMenuOpen(!menuOpen)}
        aria-label="Menu"
      >
        <span />
        <span />
        <span />
      </button>

      {/* Mobile fullscreen menu */}
      {menuOpen && (
        <div className="mobile-menu-overlay" onClick={() => setMenuOpen(false)}>
          <div className="mobile-menu" onClick={(e) => e.stopPropagation()}>
            <div className="mobile-menu-links">
              {t.nav?.map((item: string, i: number) => (
                <a
                  key={i}
                  href={`#${sectionIds[i]}`}
                  className={active === sectionIds[i] ? 'active' : ''}
                  onClick={(e) => { e.preventDefault(); scrollTo(sectionIds[i]) }}
                >
                  {item}
                </a>
              ))}
              <a
                href="/trinity/dashboard"
                style={{ color: '#00ccff' }}
                onClick={() => setMenuOpen(false)}
              >
                {t.navExtra?.dashboard || 'Dashboard'}
              </a>
              <a
                href="/trinity/docs/"
                target="_blank"
                rel="noopener noreferrer"
                style={{ color: 'var(--accent)' }}
                onClick={() => setMenuOpen(false)}
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
