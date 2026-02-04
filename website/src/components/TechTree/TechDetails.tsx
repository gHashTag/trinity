"use client";
import { motion, AnimatePresence } from 'framer-motion';
import type { TechNode } from './techTreeData';
import { getNodeById, techBranches } from './techTreeData';

interface TechDetailsProps {
  node: TechNode | null;
  onClose: () => void;
}

const statusLabels = {
  done: { label: 'COMPLETE', color: '#00FF88', icon: '✅' },
  in_progress: { label: 'RESEARCHING', color: '#FFD700', icon: '🔄' },
  locked: { label: 'LOCKED', color: '#666', icon: '🔒' }
};

export default function TechDetails({ node, onClose }: TechDetailsProps) {
  if (!node) return null;

  const status = statusLabels[node.status];
  const branch = techBranches.find(b => b.id === node.branch);
  const prerequisites = node.prerequisites.map(id => getNodeById(id)).filter(Boolean);
  const unlocks = node.unlocks.map(id => getNodeById(id)).filter(Boolean);

  return (
    <AnimatePresence>
      {node && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            style={{
              position: 'fixed',
              inset: 0,
              background: 'rgba(0, 0, 0, 0.6)',
              backdropFilter: 'blur(4px)',
              zIndex: 100
            }}
          />

          {/* Panel */}
          <motion.div
            initial={{ opacity: 0, x: 300 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 300 }}
            transition={{ type: 'spring', damping: 25, stiffness: 200 }}
            style={{
              position: 'fixed',
              top: 0,
              right: 0,
              bottom: 0,
              width: 'min(400px, 90vw)',
              background: 'linear-gradient(135deg, rgba(10, 26, 15, 0.98), rgba(0, 0, 0, 0.98))',
              borderLeft: `2px solid ${branch?.color || '#00FF88'}`,
              boxShadow: `-10px 0 40px rgba(0, 0, 0, 0.5)`,
              zIndex: 101,
              overflowY: 'auto',
              padding: '2rem'
            }}
          >
            {/* Close button */}
            <motion.button
              onClick={onClose}
              whileHover={{ scale: 1.1 }}
              whileTap={{ scale: 0.9 }}
              style={{
                position: 'absolute',
                top: '1rem',
                right: '1rem',
                background: 'rgba(255, 255, 255, 0.1)',
                border: 'none',
                borderRadius: '50%',
                width: '40px',
                height: '40px',
                cursor: 'pointer',
                color: '#fff',
                fontSize: '1.2rem'
              }}
            >
              ✕
            </motion.button>

            {/* Header */}
            <div style={{ marginBottom: '2rem' }}>
              {/* Branch badge */}
              <div style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.5rem',
                padding: '0.3rem 0.8rem',
                background: `${branch?.color}22`,
                border: `1px solid ${branch?.color}`,
                borderRadius: '20px',
                fontSize: '0.75rem',
                fontWeight: 600,
                color: branch?.color,
                marginBottom: '1rem'
              }}>
                <span>{branch?.icon}</span>
                <span>{branch?.name}</span>
              </div>

              {/* Node ID */}
              <div style={{
                fontSize: '0.7rem',
                color: 'rgba(255, 255, 255, 0.4)',
                textTransform: 'uppercase',
                letterSpacing: '0.15em',
                marginBottom: '0.5rem'
              }}>
                {node.id.toUpperCase()}
              </div>

              {/* Node name */}
              <h2 style={{
                fontSize: '1.8rem',
                fontWeight: 700,
                color: '#fff',
                marginBottom: '0.5rem',
                lineHeight: 1.2
              }}>
                {node.name}
              </h2>

              {/* Status */}
              <motion.div
                initial={{ scale: 0.9 }}
                animate={{ scale: 1 }}
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.4rem',
                  padding: '0.4rem 1rem',
                  background: `${status.color}22`,
                  border: `1px solid ${status.color}`,
                  borderRadius: '6px',
                  fontSize: '0.8rem',
                  fontWeight: 600,
                  color: status.color
                }}
              >
                <span>{status.icon}</span>
                <span>{status.label}</span>
                {node.status === 'in_progress' && node.progress && (
                  <span style={{ marginLeft: '0.3rem' }}>({node.progress}%)</span>
                )}
              </motion.div>
            </div>

            {/* Description */}
            <div style={{ marginBottom: '2rem' }}>
              <h3 style={{
                fontSize: '0.75rem',
                color: 'rgba(255, 255, 255, 0.5)',
                textTransform: 'uppercase',
                letterSpacing: '0.1em',
                marginBottom: '0.5rem'
              }}>
                Description
              </h3>
              <p style={{
                fontSize: '0.95rem',
                color: 'rgba(255, 255, 255, 0.8)',
                lineHeight: 1.6
              }}>
                {node.description}
              </p>
            </div>

            {/* Metrics */}
            {node.metrics && (
              <div style={{ marginBottom: '2rem' }}>
                <h3 style={{
                  fontSize: '0.75rem',
                  color: 'rgba(255, 255, 255, 0.5)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.1em',
                  marginBottom: '0.5rem'
                }}>
                  Performance
                </h3>
                <div style={{
                  fontSize: '2rem',
                  fontWeight: 700,
                  color: branch?.color || '#00FF88',
                  textShadow: `0 0 20px ${branch?.color}44`
                }}>
                  {node.metrics}
                </div>
              </div>
            )}

            {/* Progress bar for in_progress */}
            {node.status === 'in_progress' && node.progress !== undefined && (
              <div style={{ marginBottom: '2rem' }}>
                <h3 style={{
                  fontSize: '0.75rem',
                  color: 'rgba(255, 255, 255, 0.5)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.1em',
                  marginBottom: '0.5rem'
                }}>
                  Research Progress
                </h3>
                <div style={{
                  background: 'rgba(255, 255, 255, 0.1)',
                  borderRadius: '8px',
                  height: '12px',
                  overflow: 'hidden'
                }}>
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${node.progress}%` }}
                    transition={{ duration: 1, ease: 'easeOut' }}
                    style={{
                      height: '100%',
                      background: `linear-gradient(90deg, ${branch?.color}, #FFD700)`,
                      borderRadius: '8px'
                    }}
                  />
                </div>
                <div style={{
                  fontSize: '0.8rem',
                  color: 'rgba(255, 255, 255, 0.5)',
                  marginTop: '0.3rem',
                  textAlign: 'right'
                }}>
                  {node.progress}% complete
                </div>
              </div>
            )}

            {/* Prerequisites */}
            {prerequisites.length > 0 && (
              <div style={{ marginBottom: '2rem' }}>
                <h3 style={{
                  fontSize: '0.75rem',
                  color: 'rgba(255, 255, 255, 0.5)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.1em',
                  marginBottom: '0.5rem'
                }}>
                  Prerequisites
                </h3>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                  {prerequisites.map(prereq => prereq && (
                    <div
                      key={prereq.id}
                      style={{
                        padding: '0.4rem 0.8rem',
                        background: prereq.status === 'done' ? 'rgba(0, 255, 136, 0.1)' : 'rgba(255, 255, 255, 0.05)',
                        border: `1px solid ${prereq.status === 'done' ? '#00FF88' : 'rgba(255, 255, 255, 0.2)'}`,
                        borderRadius: '6px',
                        fontSize: '0.8rem',
                        color: prereq.status === 'done' ? '#00FF88' : 'rgba(255, 255, 255, 0.5)'
                      }}
                    >
                      {prereq.status === 'done' ? '✅' : '🔒'} {prereq.name}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Unlocks */}
            {unlocks.length > 0 && (
              <div style={{ marginBottom: '2rem' }}>
                <h3 style={{
                  fontSize: '0.75rem',
                  color: 'rgba(255, 255, 255, 0.5)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.1em',
                  marginBottom: '0.5rem'
                }}>
                  Unlocks
                </h3>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                  {unlocks.map(unlock => unlock && (
                    <div
                      key={unlock.id}
                      style={{
                        padding: '0.4rem 0.8rem',
                        background: 'rgba(255, 215, 0, 0.1)',
                        border: '1px solid rgba(255, 215, 0, 0.3)',
                        borderRadius: '6px',
                        fontSize: '0.8rem',
                        color: '#FFD700'
                      }}
                    >
                      → {unlock.name}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Locked message */}
            {node.status === 'locked' && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                style={{
                  padding: '1rem',
                  background: 'rgba(255, 100, 100, 0.1)',
                  border: '1px solid rgba(255, 100, 100, 0.3)',
                  borderRadius: '8px',
                  fontSize: '0.85rem',
                  color: '#FF6B6B',
                  textAlign: 'center'
                }}
              >
                🔒 Complete prerequisites to unlock this research
              </motion.div>
            )}

            {/* X-COM style footer */}
            <div style={{
              marginTop: '3rem',
              padding: '1rem',
              background: 'rgba(0, 255, 136, 0.05)',
              borderRadius: '8px',
              border: '1px solid rgba(0, 255, 136, 0.2)',
              textAlign: 'center'
            }}>
              <div style={{
                fontSize: '0.65rem',
                color: 'rgba(255, 255, 255, 0.4)',
                textTransform: 'uppercase',
                letterSpacing: '0.15em',
                marginBottom: '0.3rem'
              }}>
                TRINITY RESEARCH LABORATORY
              </div>
              <div style={{
                fontSize: '0.8rem',
                fontFamily: 'monospace',
                color: '#FFD700'
              }}>
                φ² + 1/φ² = 3
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
