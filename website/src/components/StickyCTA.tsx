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
          className="sticky-cta-bar"
          role="region"
          aria-label="Quick actions"
        >
          <motion.a
            href="#invest"
            className="btn sticky-cta-btn"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            aria-label="Go to investment section"
          >
            <span aria-hidden="true">💎</span> {t.stickyCta?.invest || 'Invest Now'}
          </motion.a>

          <motion.a
            href="#calculator"
            className="btn secondary sticky-cta-btn"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            aria-label="Go to calculator section"
          >
            <span aria-hidden="true">💰</span> {t.stickyCta?.calculator || 'Calculator'}
          </motion.a>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
