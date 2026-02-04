"use client";
import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useI18n } from '../i18n/context';

export default function StickyCTA() {
  const [visible, setVisible] = useState(false);
  const { t } = useI18n();

  useEffect(() => {
    const handleScroll = () => {
      // Show after scrolling past 30% of viewport
      const scrollPercent = (window.scrollY / (document.body.scrollHeight - window.innerHeight)) * 100;
      setVisible(scrollPercent > 30);
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          initial={{ y: 100, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 100, opacity: 0 }}
          transition={{ duration: 0.3 }}
          style={{
            position: 'fixed',
            bottom: 0,
            left: 0,
            right: 0,
            background: 'rgba(10, 10, 15, 0.95)',
            backdropFilter: 'blur(10px)',
            borderTop: '1px solid var(--border)',
            padding: '1rem 2rem',
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            gap: '1rem',
            zIndex: 1000
          }}
        >
          <span style={{ 
            color: 'var(--text-secondary)', 
            fontSize: '0.9rem',
            display: 'none'
          }} className="sticky-text">
            φ² + 1/φ² = 3 = TRINITY
          </span>
          
          <motion.a
            href="#invest"
            className="btn"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            style={{ minWidth: '160px', textAlign: 'center' }}
          >
            💎 {t.stickyCta?.invest || 'Invest Now'}
          </motion.a>
          
          <motion.a
            href="#calculator"
            className="btn secondary"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            style={{ minWidth: '160px', textAlign: 'center' }}
          >
            💰 {t.stickyCta?.calculator || 'Savings Calculator'}
          </motion.a>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
