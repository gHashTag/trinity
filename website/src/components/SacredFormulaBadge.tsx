"use client";
import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

interface Props {
  position?: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right';
}

export default function SacredFormulaBadge({ position = 'bottom-right' }: Props) {
  const [expanded, setExpanded] = useState(false);
  const [hovered, setHovered] = useState(false);

  const positionStyles: Record<string, { bottom?: string; top?: string; left?: string; right?: string }> = {
    'top-left': { top: '20px', left: '20px' },
    'top-right': { top: '20px', right: '20px' },
    'bottom-left': { bottom: '20px', left: '20px' },
    'bottom-right': { bottom: '20px', right: '20px' },
  };

  const pos = positionStyles[position];

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ delay: 0.5, duration: 0.5 }}
      style={{
        position: 'fixed',
        zIndex: 1000,
        ...pos,
        fontFamily: 'monospace',
        fontSize: '11px',
      }}
    >
      {/* Badge */}
      <motion.div
        onClick={() => setExpanded(!expanded)}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        style={{
          background: 'rgba(0, 0, 0, 0.8)',
          backdropFilter: 'blur(10px)',
          border: '1px solid rgba(0, 255, 136, 0.3)',
          borderRadius: '8px',
          padding: '8px 12px',
          cursor: 'pointer',
          transition: 'all 0.3s',
        }}
      >
        {/* Collapsed state - shows formula */}
        <AnimatePresence mode="wait">
          {!expanded ? (
            <motion.div
              key="collapsed"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              style={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: '4px',
              }}
            >
              {/* Main formula - always visible */}
              <div style={{ color: 'var(--accent)', fontWeight: 600, whiteSpace: 'nowrap' }}>
                V = n × 3<sup>k</sup> × π<sup>m</sup> × φ<sup>p</sup> × e<sup>q</sup>
              </div>

              {/* Hover shows Trinity identity */}
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{
                  opacity: hovered ? 1 : 0,
                  height: hovered ? 'auto' : 0,
                }}
                style={{ color: '#ffd700', fontSize: '10px', overflow: 'hidden' }}
              >
                φ² + 1/φ² = 3 = TRINITY
              </motion.div>
            </motion.div>
          ) : (
            <motion.div
              key="expanded"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 10 }}
              style={{
                padding: '12px',
                minWidth: '280px',
                color: 'var(--text)',
              }}
            >
              {/* Header */}
              <div style={{ marginBottom: '8px', paddingBottom: '8px', borderBottom: '1px solid var(--border)' }}>
                <div style={{ color: 'var(--accent)', fontSize: '12px', fontWeight: 600, marginBottom: '4px' }}>
                  TRINITY SACRED FORMULA
                </div>
                <div style={{ fontSize: '10px', color: 'var(--muted)' }}>
                  The fundamental equation of the universe
                </div>
              </div>

              {/* Main Formula */}
              <div style={{ marginBottom: '8px', fontSize: '13px', textAlign: 'center', fontWeight: 500 }}>
                V = n × 3<sup>k</sup> × π<sup>m</sup> × φ<sup>p</sup> × e<sup>q</sup>
              </div>

              {/* Components */}
              <div style={{ fontSize: '10px', display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '4px 8px', color: 'var(--muted)' }}>
                <div style={{ color: 'var(--accent)' }}>n</div>
                <div>Multiplier (1-9)</div>

                <div style={{ color: 'var(--accent)' }}>3</div>
                <div>Trinity (φ² + 1/φ² = 3)</div>

                <div style={{ color: 'var(--accent)' }}>π</div>
                <div>Pi (3.14159...) circle constant</div>

                <div style={{ color: 'var(--accent)' }}>φ</div>
                <div>Golden ratio (1.61803...) = (1+√5)/2</div>

                <div style={{ color: 'var(--accent)' }}>e</div>
                <div>Euler's number (2.71828...)</div>
              </div>

              {/* Try it */}
              <div style={{ marginTop: '8px', paddingTop: '8px', borderTop: '1px solid var(--border)', fontSize: '9px', color: 'var(--muted)' }}>
                Try: <code style={{ color: 'var(--text)' }}>tri sacred</code>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </motion.div>
  );
}
