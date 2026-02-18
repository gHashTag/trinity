import { motion, AnimatePresence } from 'framer-motion';
import { useI18n } from '../../i18n/context';
import type { TechNode } from './techTreeData';
import { getNodeById, techBranches } from './techTreeData';

interface TechDetailsProps {
  node: TechNode | null;
  onClose: () => void;
}

export default function TechDetails({ node, onClose }: TechDetailsProps) {
  const { t } = useI18n();
  
  if (!node) return null;

  const statusLabels = {
    done: { label: t.techTree.legend.done, color: '#00FF88', icon: '✅' },
    in_progress: { label: t.techTree.legend.progress, color: '#FFD700', icon: '🔄' },
    locked: { label: t.techTree.legend.locked, color: '#666', icon: '🔒' }
  };

  const status = statusLabels[node.status];
  const branch = techBranches.find(b => b.id === node.branch);
  const prerequisites = node.prerequisites.map(id => getNodeById(id)).filter(Boolean);
  const unlocks = node.unlocks.map(id => getNodeById(id)).filter(Boolean);

  // Localized content
  const localized = t.techTree.nodes?.[node.id] || {};
  const name = localized.name || node.name;
  const description = localized.description || node.description;
  const metrics = localized.metrics || node.metrics;

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
              width: 'min(450px, 95vw)',
              background: 'linear-gradient(135deg, rgba(8, 20, 12, 0.99), rgba(0, 0, 0, 0.99))',
              borderLeft: `2px solid ${branch?.color || '#00FF88'}`,
              boxShadow: `-10px 0 40px rgba(0, 0, 0, 0.6)`,
              zIndex: 101,
              overflowY: 'auto',
              padding: '80px 2rem 100px 2rem', // Added top and bottom padding
              scrollbarWidth: 'thin',
              scrollbarColor: `${branch?.color}44 transparent`
            }}
          >
            {/* Close button - Fixed at top */}
            <div style={{
              position: 'absolute',
              top: '1.5rem',
              right: '1.5rem',
              zIndex: 102
            }}>
              <motion.button
                onClick={onClose}
                whileHover={{ scale: 1.1, backgroundColor: 'rgba(255, 255, 255, 0.2)' }}
                whileTap={{ scale: 0.9 }}
                style={{
                  background: 'rgba(255, 255, 255, 0.1)',
                  border: 'none',
                  borderRadius: '50%',
                  width: '40px',
                  height: '40px',
                  cursor: 'pointer',
                  color: '#fff',
                  fontSize: '1.2rem',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  backdropFilter: 'blur(10px)'
                }}
              >
                ✕
              </motion.button>
            </div>

            {/* Header */}
            <div style={{ marginBottom: '2.5rem' }}>
              {/* Branch badge */}
              <div style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.5rem',
                padding: '0.3rem 0.8rem',
                background: `${branch?.color}15`,
                border: `1px solid ${branch?.color}66`,
                borderRadius: '20px',
                fontSize: '0.7rem',
                fontWeight: 700,
                color: branch?.color,
                marginBottom: '1rem',
                textTransform: 'uppercase',
                letterSpacing: '0.05em'
              }}>
                <span>{branch?.icon}</span>
                <span>{t.techTree.branches?.[branch?.id || ''] || branch?.name}</span>
              </div>

              {/* Node ID */}
              <div style={{
                fontSize: '0.65rem',
                color: 'rgba(255, 255, 255, 0.3)',
                textTransform: 'uppercase',
                letterSpacing: '0.2em',
                marginBottom: '0.5rem',
                fontWeight: 600
              }}>
                {node.id.toUpperCase()}
              </div>

              {/* Node name */}
              <h2 style={{
                fontSize: '1.6rem', // Slightly smaller
                fontWeight: 800,
                color: '#fff',
                marginBottom: '0.75rem',
                lineHeight: 1.1,
                letterSpacing: '-0.02em'
              }}>
                {name}
              </h2>

              {/* Status */}
              <motion.div
                initial={{ opacity: 0, y: 5 }}
                animate={{ opacity: 1, y: 0 }}
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.4rem',
                  padding: '0.4rem 0.8rem',
                  background: `${status.color}15`,
                  border: `1px solid ${status.color}44`,
                  borderRadius: '8px',
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  color: status.color
                }}
              >
                <span>{status.icon}</span>
                <span>{status.label}</span>
                {node.status === 'in_progress' && node.progress && (
                  <span style={{ opacity: 0.8, marginLeft: '0.2rem' }}>{node.progress}%</span>
                )}
              </motion.div>
            </div>

            {/* Description */}
            <div style={{ marginBottom: '2rem' }}>
              <h3 style={{
                fontSize: '0.65rem',
                color: 'rgba(255, 255, 255, 0.3)',
                textTransform: 'uppercase',
                letterSpacing: '0.2em',
                marginBottom: '0.75rem',
                fontWeight: 700
              }}>
                {t.techTree.labels.description}
              </h3>
              <p style={{
                fontSize: '0.88rem', // Compact
                color: 'rgba(255, 255, 255, 0.7)',
                lineHeight: 1.6,
                fontWeight: 400
              }}>
                {description}
              </p>
            </div>

            {/* Metrics */}
            {metrics && (
              <div style={{ marginBottom: '2.5rem' }}>
                <h3 style={{
                  fontSize: '0.65rem',
                  color: 'rgba(255, 255, 255, 0.3)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.2em',
                  marginBottom: '0.75rem',
                  fontWeight: 700
                }}>
                  {t.techTree.labels.performance}
                </h3>
                <div style={{
                  fontSize: '2.4rem',
                  fontWeight: 900,
                  color: branch?.color || '#00FF88',
                  textShadow: `0 0 30px ${branch?.color}33`,
                  lineHeight: 1
                }}>
                  {metrics}
                </div>
              </div>
            )}

            {/* Progress bar for in_progress */}
            {node.status === 'in_progress' && node.progress !== undefined && (
              <div style={{ marginBottom: '2.5rem' }}>
                <h3 style={{
                  fontSize: '0.65rem',
                  color: 'rgba(255, 255, 255, 0.3)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.2em',
                  marginBottom: '0.75rem',
                  fontWeight: 700
                }}>
                  {t.techTree.labels.progress}
                </h3>
                <div style={{
                  background: 'rgba(255, 255, 255, 0.05)',
                  borderRadius: '10px',
                  height: '10px',
                  overflow: 'hidden',
                  border: '1px solid rgba(255, 255, 255, 0.1)'
                }}>
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${node.progress}%` }}
                    transition={{ duration: 1, ease: 'easeOut' }}
                    style={{
                      height: '100%',
                      background: `linear-gradient(90deg, ${branch?.color}, #FFD700)`,
                      borderRadius: '10px'
                    }}
                  />
                </div>
                <div style={{
                  fontSize: '0.75rem',
                  color: 'rgba(255, 255, 255, 0.3)',
                  marginTop: '0.5rem',
                  textAlign: 'right',
                  fontWeight: 600
                }}>
                  {node.progress}% {t.techTree.complete}
                </div>
              </div>
            )}

            {/* Prerequisites */}
            {prerequisites.length > 0 && (
              <div style={{ marginBottom: '2rem' }}>
                <h3 style={{
                  fontSize: '0.65rem',
                  color: 'rgba(255, 255, 255, 0.3)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.2em',
                  marginBottom: '0.75rem',
                  fontWeight: 700
                }}>
                  {t.techTree.labels.prerequisites}
                </h3>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                  {prerequisites.map(prereq => {
                    if (!prereq) return null;
                    const localizedPrereq = t.techTree.nodes?.[prereq.id] || {};
                    return (
                      <div
                        key={prereq.id}
                        style={{
                          padding: '0.4rem 0.7rem',
                          background: prereq.status === 'done' ? 'rgba(0, 255, 136, 0.05)' : 'rgba(255, 255, 255, 0.03)',
                          border: `1px solid ${prereq.status === 'done' ? '#00FF8844' : 'rgba(255, 255, 255, 0.1)'}`,
                          borderRadius: '6px',
                          fontSize: '0.75rem',
                          color: prereq.status === 'done' ? '#00FF88' : 'rgba(255, 255, 255, 0.4)',
                          fontWeight: 500
                        }}
                      >
                        {prereq.status === 'done' ? '✅' : '🔒'} {localizedPrereq.name || prereq.name}
                      </div>
                    );
                  })}
                </div>
              </div>
            )}

            {/* Unlocks */}
            {unlocks.length > 0 && (
              <div style={{ marginBottom: '2.5rem' }}>
                <h3 style={{
                  fontSize: '0.65rem',
                  color: 'rgba(255, 255, 255, 0.3)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.2em',
                  marginBottom: '0.75rem',
                  fontWeight: 700
                }}>
                  {t.techTree.labels.unlocks}
                </h3>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                  {unlocks.map(unlock => {
                    if (!unlock) return null;
                    const localizedUnlock = t.techTree.nodes?.[unlock.id] || {};
                    return (
                      <div
                        key={unlock.id}
                        style={{
                          padding: '0.4rem 0.7rem',
                          background: `${branch?.color}11`,
                          border: `1px solid ${branch?.color}33`,
                          borderRadius: '6px',
                          fontSize: '0.75rem',
                          color: branch?.color,
                          fontWeight: 500
                        }}
                      >
                        → {localizedUnlock.name || unlock.name}
                      </div>
                    );
                  })}
                </div>
              </div>
            )}

            {/* Locked message */}
            {node.status === 'locked' && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                style={{
                  padding: '1.2rem',
                  background: 'rgba(255, 107, 107, 0.05)',
                  border: '1px solid rgba(255, 107, 107, 0.2)',
                  borderRadius: '12px',
                  fontSize: '0.8rem',
                  color: '#FF6B6B',
                  textAlign: 'center',
                  fontWeight: 500,
                  lineHeight: 1.4
                }}
              >
                🔒 {t.techTree.labels.locked}
              </motion.div>
            )}

            {/* Research footer */}
            <div style={{
              marginTop: '4rem',
              padding: '1.5rem',
              background: 'rgba(255, 255, 255, 0.02)',
              borderRadius: '12px',
              border: '1px solid rgba(255, 255, 255, 0.05)',
              textAlign: 'center'
            }}>
              <div style={{
                fontSize: '0.6rem',
                color: 'rgba(255, 255, 255, 0.2)',
                textTransform: 'uppercase',
                letterSpacing: '0.3em',
                marginBottom: '0.5rem',
                fontWeight: 700
              }}>
                {t.techTree.title.replace(/<[^>]*>?/gm, '')}
              </div>
              <div style={{
                fontSize: '0.9rem',
                fontFamily: 'monospace',
                color: branch?.color || '#FFD700',
                opacity: 0.8
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
