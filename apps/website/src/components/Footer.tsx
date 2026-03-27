"use client";
import { motion } from 'framer-motion'
import { Link } from 'react-router-dom'
import { useI18n } from '../i18n/context'

export default function Footer() {
  const { t } = useI18n()

  return (
    <footer
      style={{
        background: 'rgba(0,0,0,0.95)',
        borderTop: '1px solid var(--border)',
        padding: 'clamp(3rem, 8vw, 5rem) clamp(1rem, 5vw, 3rem)',
        marginTop: 'clamp(2rem, 6vw, 4rem)'
      }}
      role="contentinfo"
      aria-label="Site footer"
    >
      <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
        {/* Main Footer Content */}
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(clamp(120px, 30vw, 150px), 1fr))',
          gap: 'clamp(1rem, 5vw, 3rem)',
          marginBottom: 'clamp(1.5rem, 5vw, 3rem)'
        }}>
          {/* Brand */}
          <div>
            <h2 style={{ fontSize: 'clamp(1.2rem, 4vw, 1.5rem)', fontWeight: 700, marginBottom: '1rem', margin: 0 }}>
              <motion.div
                initial={{ opacity: 0 }}
                whileInView={{ opacity: 1 }}
                viewport={{ once: true }}
              >
                TRINITY
              </motion.div>
            </h2>
            <p style={{ color: 'var(--muted)', fontSize: '0.85rem', lineHeight: 1.6 }}>
              {t.footer?.tagline || 'Ternary Computing Revolution'}
            </p>
            <div
              style={{
                marginTop: '1rem',
                fontFamily: 'monospace',
                color: 'var(--accent)',
                fontSize: '0.9rem'
              }}
              aria-label="Phi squared plus one over phi squared equals three"
            >
              φ² + 1/φ² = 3
            </div>
          </div>

          {/* Links */}
          <div>
            <h4 style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '1rem', color: 'var(--muted)' }}>
              {t.footer?.linksTitle || 'Links'}
            </h4>
            <nav aria-label="Footer navigation">
              <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                <li><a href="#theorems" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7, transition: 'opacity 0.2s' }} aria-label="Navigate to Theorems section">{t.nav?.[1] || 'Theorems'}</a></li>
                <li><a href="#solution" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7, transition: 'opacity 0.2s' }} aria-label="Navigate to Solution section">{t.nav?.[2] || 'Solution'}</a></li>
                <li><a href="#benchmarks" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7, transition: 'opacity 0.2s' }} aria-label="Navigate to Benchmarks section">{t.nav?.[3] || 'Benchmarks'}</a></li>
                <li><a href="#invest" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7, transition: 'opacity 0.2s' }} aria-label="Navigate to Invest section">{t.nav?.[9] || 'Invest'}</a></li>
                <li>
                  <a href="https://ghashtag.github.io/trinity/docs/" target="_blank" rel="noopener noreferrer" style={{ color: 'var(--accent)', textDecoration: 'none', fontSize: '0.85rem', fontWeight: 600, transition: 'opacity 0.2s' }} aria-label="Open documentation in new tab">
                    {t.footer?.docs || 'Documentation'}
                  </a>
                </li>
              </ul>
            </nav>
          </div>

          {/* Quantum Lab */}
          <div>
            <h4 style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '1rem', color: 'var(--muted)' }}>
              {t.footer?.vizTitle || 'Quantum Lab'}
            </h4>
            <motion.div whileHover={{ scale: 1.02 }}>
              <Link
                to="/quantum"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.75rem',
                  padding: '1rem',
                  background: 'rgba(0, 229, 153, 0.1)',
                  border: '1px solid rgba(0, 229, 153, 0.2)',
                  borderRadius: '12px',
                  textDecoration: 'none',
                  marginBottom: '1rem'
                }}
                aria-label={`${t.footer?.vizLaunch || 'Launch Quantum Lab'} - ${t.footer?.vizDesc || '29 interactive visualizations'}`}
              >
                <span style={{ fontSize: 'clamp(1.5rem, 4vw, 2rem)' }} aria-hidden="true">🔮</span>
                <div>
                  <div style={{ color: 'var(--accent)', fontWeight: 600, fontSize: '1rem' }}>
                    {t.footer?.vizLaunch || 'Launch Quantum Lab'}
                  </div>
                  <div style={{ color: 'var(--muted)', fontSize: '0.75rem' }}>
                    {t.footer?.vizDesc || '29 interactive visualizations'}
                  </div>
                </div>
              </Link>
            </motion.div>
            <nav aria-label="Quantum visualization quick links" style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
              {['⚛️', '🧠', '🌊', '🔗', '🌀', '👁️', '🔺', '🔥'].map((icon, i) => (
                <Link
                  key={i}
                  to="/quantum"
                  style={{
                    padding: '0.5rem',
                    background: 'rgba(255,255,255,0.05)',
                    borderRadius: '8px',
                    textDecoration: 'none',
                    fontSize: '1.2rem'
                  }}
                  aria-label={`Open quantum lab - visualization ${i + 1}`}
                  aria-hidden={i > 0 ? undefined : 'false'}
                >
                  {icon}
                </Link>
              ))}
            </nav>
          </div>

          {/* Contact */}
          <div>
            <h4 style={{ fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '1rem', color: 'var(--muted)' }}>
              {t.footer?.contactTitle || 'Contact'}
            </h4>
            <nav aria-label="Contact links">
              <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                <li>
                  <a href="https://github.com/gHashTag/trinity" target="_blank" rel="noopener noreferrer" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7 }} aria-label="Visit GitHub repository (opens in new tab)">
                    GitHub
                  </a>
                </li>
                <li>
                  <a href="https://t.me/vibee_dev" target="_blank" rel="noopener noreferrer" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7 }} aria-label="Join Telegram group (opens in new tab)">
                    Telegram
                  </a>
                </li>
                <li>
                  <a href="mailto:raoffonom@icloud.com" style={{ color: 'var(--text)', textDecoration: 'none', fontSize: '0.85rem', opacity: 0.7 }} aria-label="Send email to raoffonom@icloud.com">
                    raoffonom@icloud.com
                  </a>
                </li>
              </ul>
            </nav>
          </div>
        </div>

        {/* Bottom Bar */}
        <div style={{ 
          borderTop: '1px solid var(--border)', 
          paddingTop: '2rem',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '1rem'
        }}>
          <div style={{ color: 'var(--muted)', fontSize: '0.75rem' }}>
            © 2024-2026 TRINITY. {t.footer?.rights || 'All rights reserved.'}
          </div>
          <div style={{ color: 'var(--muted)', fontSize: '0.75rem', fontFamily: 'monospace' }}>
            PHOENIX = 999 | KOSCHEI IS IMMORTAL
          </div>
        </div>
      </div>
    </footer>
  )
}
