"use client";
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';
import { TrinityLogo } from '../TrinityLogo';

// Animated equation component - LaTeX-style math
function AnimatedEquation() {
  return (
    <motion.div
      className="fade"
      style={{
        fontSize: 'clamp(1.1rem, 4.2vw, 2rem)',
        marginBottom: '1.5rem',
        fontFamily: '"Times New Roman", Times, serif',
        fontStyle: 'italic',
        color: '#00ff88',
        position: 'relative',
        display: 'inline-block'
      }}
    >
      <motion.span
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.5, duration: 0.8 }}
      >
        <span style={{ fontFamily: 'inherit' }}>φ</span>
        <sup>2</sup>
        <span style={{ margin: '0 0.1em' }}> + </span>
        <span style={{ fontFamily: 'inherit' }}>1/φ</span>
        <sup>2</sup>
        <span style={{ margin: '0 0.1em' }}> = </span>
        <span style={{ fontWeight: 500 }}>3</span>
      </motion.span>
    </motion.div>
  );
}

export default function HeroSection() {
  const { t: { hero: t } } = useI18n();

  return (
    <section id="hero" aria-labelledby="hero-heading">
      <div className="radial-glow" aria-hidden="true" />

      {/* Eyebrow banner */}
      <motion.div
        className="fade"
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        style={{
          display: 'inline-block',
          padding: '0.35em 1em',
          border: '1px solid var(--accent)',
          borderRadius: '999px',
          fontSize: '0.78rem',
          letterSpacing: '0.08em',
          color: 'var(--accent)',
          marginBottom: '1.2rem',
          opacity: 0.85,
        }}
      >
        v5.1.0 — 7 DOI-verified publications on Zenodo
      </motion.div>

      {/* h1, not h2: this line is the page's primary heading and the homepage had
          no h1 at all -- 40 headings and none of them first. Every static landing
          has exactly one; only the route everyone actually lands on was missing it,
          which costs both screen-reader orientation and the main heading signal. */}
      <h1 style={{ color: 'var(--accent)', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: 'clamp(0.1em, 2vw, 0.3em)', marginBottom: '0', margin: 0 }}>
        <motion.div
          className="fade"
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.1 }}
        >
          {t.tag}
        </motion.div>
      </h1>
      
      <motion.div
        className="fade"
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.8, delay: 0.2 }}
        style={{ marginBottom: '0', display: 'flex', justifyContent: 'center' }}
      >
        <TrinityLogo />
      </motion.div>
      
      <AnimatedEquation />

      {/* Code snippet — visible immediately, no delay */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.8 }}
        transition={{ duration: 0.5, delay: 1.0 }}
        style={{
          background: 'rgba(0,0,0,0.4)',
          border: '1px solid rgba(255,255,255,0.1)',
          borderRadius: '8px',
          padding: '0.8em 1.4em',
          fontFamily: '"SF Mono", "Fira Code", monospace',
          fontSize: 'clamp(0.72rem, 1.6vw, 0.88rem)',
          color: '#c9d1d9',
          textAlign: 'left',
          maxWidth: '480px',
          margin: '0 auto 1.5rem',
          lineHeight: 1.6,
        }}
      >
        <div style={{ color: '#8b949e' }}>$ brew tap gHashTag/trinity && brew install tri</div>
        <div style={{ color: '#79c0ff' }}>$ tri agent run 420 <span style={{ color: '#8b949e' }}># autonomous 8-step cycle</span></div>
        <div style={{ color: '#7ee787' }}>$ tri cloud deploy <span style={{ color: '#8b949e' }}># push to Railway</span></div>
      </motion.div>
      
      {/* Only show headline if it's not the φ equation (already shown above) */}
      {t.headline && !t.headline.includes('φ²') && (
        <motion.h2
          className="fade"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 1.8 }}
          style={{ fontSize: 'clamp(1.8rem, 6vw, 2.8rem)', marginBottom: '1.2rem', letterSpacing: '-0.03em' }}
          id="hero-heading"
          dangerouslySetInnerHTML={{ __html: t.headline }}
        />
      )}
      
      <motion.p
        className="fade"
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.7 }}
        transition={{ duration: 0.6, delay: 2.0 }}
        style={{ fontSize: 'clamp(1rem, 2.5vw, 1.15rem)', marginBottom: '3rem', maxWidth: '800px' }}
      >
        {t.quote}
      </motion.p>

      <motion.div
        className="fade"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, delay: 2.2 }}
        style={{ display: 'flex', gap: '1rem', marginTop: '2.5rem', justifyContent: 'center', flexWrap: 'wrap' }}
        role="group"
        aria-label="Call to action buttons"
      >
        {/* These were "Install CLI" and "Read Papers", both scrolling to a section
            — the first mislabelled, and neither leading to anything that can be
            bought. The primary action is now the service; the secondary is the
            evidence behind it, which is what a sceptical reader wants next. */}
        <motion.a
          href="#/ip"
          className="btn"
          style={{ minWidth: 'clamp(140px, 40vw, 200px)' }}
          whileHover={{ scale: 1.05, boxShadow: '0 0 20px rgba(0,255,136,0.3)' }}
          whileTap={{ scale: 0.95 }}
          aria-label="License the GF-T format"
        >
          {t.cta}
        </motion.a>
        <motion.a
          href="#/proof"
          className="btn secondary"
          style={{ minWidth: 'clamp(140px, 40vw, 200px)' }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          aria-label="Measured evidence behind every claim"
        >
          {t.ctaSecondary}
        </motion.a>
      </motion.div>

      {/* Scroll indicator */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.4, y: [0, 10, 0] }}
        transition={{ opacity: { delay: 3 }, y: { duration: 2, repeat: Infinity } }}
        style={{
          position: 'absolute',
          bottom: '2rem',
          left: '50%',
          transform: 'translateX(-50%)',
          fontSize: '1.5rem'
        }}
        aria-hidden="true"
        tabIndex={-1}
      >
        ↓
      </motion.div>
    </section>
  )
}