"use client";
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';

// Animated equation component with golden glow effect
function AnimatedEquation() {
  return (
    <motion.div 
      className="fade" 
      style={{ 
        fontSize: 'clamp(1.2rem, 5vw, 2rem)', 
        marginBottom: '2.5rem', 
        fontFamily: 'serif', 
        fontStyle: 'italic',
        position: 'relative',
        display: 'inline-block'
      }}
    >
      {/* Glow effect */}
      <motion.div
        animate={{ 
          opacity: [0.3, 0.6, 0.3],
          scale: [1, 1.02, 1]
        }}
        transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
        style={{
          position: 'absolute',
          inset: '-10px',
          background: 'radial-gradient(ellipse, rgba(218,165,32,0.15) 0%, transparent 70%)',
          borderRadius: '50%',
          filter: 'blur(8px)',
          zIndex: -1
        }}
      />
      
      {/* Equation parts with staggered animation */}
      <motion.span
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.5, duration: 0.6 }}
        style={{ color: 'var(--accent)' }}
      >
        φ²
      </motion.span>
      <motion.span
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.6 }}
        transition={{ delay: 0.8, duration: 0.4 }}
      >
        {' + '}
      </motion.span>
      <motion.span
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 1.0, duration: 0.6 }}
        style={{ color: 'var(--accent)' }}
      >
        1/φ²
      </motion.span>
      <motion.span
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.6 }}
        transition={{ delay: 1.3, duration: 0.4 }}
      >
        {' = '}
      </motion.span>
      <motion.span
        initial={{ opacity: 0, scale: 0.5 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 1.5, duration: 0.5, type: "spring" }}
        style={{ 
          color: 'var(--accent)', 
          fontWeight: 'bold',
          fontSize: '1.2em'
        }}
      >
        3
      </motion.span>
      
      {/* Floating animation for entire equation */}
      <motion.div
        animate={{ y: [0, -5, 0] }}
        transition={{ duration: 4, repeat: Infinity, ease: "easeInOut", delay: 2 }}
        style={{ position: 'absolute', inset: 0 }}
      />
    </motion.div>
  );
}

export default function HeroSection() {
  const { t: { hero: t } } = useI18n(); 
  
  return (
    <section id="hero">
      <div className="radial-glow" />
      
      <motion.div 
        className="fade" 
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        style={{ color: 'var(--accent)', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.3em', marginBottom: '1rem' }}
      >
        {t.tag}
      </motion.div>
      
      <motion.h1 
        className="fade" 
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.8, delay: 0.2 }}
        style={{ marginBottom: '1rem' }}
      >
        TRINITY
      </motion.h1>
      
      <AnimatedEquation />
      
      {/* Only show headline if it's not the φ equation (already shown above) */}
      {t.headline && !t.headline.includes('φ²') && (
        <motion.h2 
          className="fade" 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 1.8 }}
          style={{ fontSize: 'clamp(1.8rem, 6vw, 2.8rem)', marginBottom: '1.2rem', letterSpacing: '-0.03em' }} 
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
      >
        <motion.a 
          href="#theorems" 
          className="btn" 
          style={{ minWidth: '200px' }}
          whileHover={{ scale: 1.05, boxShadow: '0 0 20px rgba(218,165,32,0.3)' }}
          whileTap={{ scale: 0.95 }}
        >
          {t.cta}
        </motion.a>
        <motion.a 
          href="#calculator" 
          className="btn secondary" 
          style={{ minWidth: '200px' }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
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
      >
        ↓
      </motion.div>
    </section>
  )
}