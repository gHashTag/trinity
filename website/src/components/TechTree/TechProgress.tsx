"use client";
import { motion } from 'framer-motion';
import { getCompletionStats, getBranchStats, techBranches } from './techTreeData';

export default function TechProgress() {
  const stats = getCompletionStats();

  return (
    <div style={{ marginBottom: '2rem' }}>
      {/* Overall progress */}
      <div style={{
        background: 'rgba(0, 0, 0, 0.5)',
        border: '1px solid rgba(0, 255, 136, 0.2)',
        borderRadius: '12px',
        padding: '1.5rem',
        marginBottom: '1.5rem'
      }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '1rem'
        }}>
          <div>
            <div style={{
              fontSize: '0.7rem',
              color: 'rgba(255, 255, 255, 0.5)',
              textTransform: 'uppercase',
              letterSpacing: '0.15em',
              marginBottom: '0.3rem'
            }}>
              RESEARCH PROGRESS
            </div>
            <div style={{
              fontSize: '2rem',
              fontWeight: 700,
              color: '#00FF88',
              textShadow: '0 0 20px rgba(0, 255, 136, 0.3)'
            }}>
              {stats.percentage}%
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{
              fontSize: '0.8rem',
              color: 'rgba(255, 255, 255, 0.7)'
            }}>
              <span style={{ color: '#00FF88' }}>{stats.done}</span>
              <span style={{ color: 'rgba(255, 255, 255, 0.4)' }}> / {stats.total}</span>
            </div>
            <div style={{
              fontSize: '0.7rem',
              color: 'rgba(255, 255, 255, 0.4)'
            }}>
              {stats.inProgress > 0 && (
                <span style={{ color: '#FFD700', marginRight: '0.5rem' }}>
                  🔄 {stats.inProgress} in progress
                </span>
              )}
              {stats.locked > 0 && (
                <span>
                  🔒 {stats.locked} locked
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Overall progress bar */}
        <div style={{
          background: 'rgba(255, 255, 255, 0.1)',
          borderRadius: '8px',
          height: '16px',
          overflow: 'hidden',
          position: 'relative'
        }}>
          {/* Done section */}
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${stats.percentage}%` }}
            transition={{ duration: 1.5, ease: 'easeOut' }}
            style={{
              position: 'absolute',
              left: 0,
              top: 0,
              height: '100%',
              background: 'linear-gradient(90deg, #00CC66, #00FF88)',
              borderRadius: '8px',
              boxShadow: '0 0 20px rgba(0, 255, 136, 0.4)'
            }}
          />

          {/* In progress section */}
          {stats.inProgress > 0 && (
            <motion.div
              initial={{ width: 0 }}
              animate={{
                width: `${(stats.inProgress / stats.total) * 100}%`,
                opacity: [0.5, 1, 0.5]
              }}
              transition={{
                width: { duration: 1.5, ease: 'easeOut' },
                opacity: { duration: 1.5, repeat: Infinity }
              }}
              style={{
                position: 'absolute',
                left: `${stats.percentage}%`,
                top: 0,
                height: '100%',
                background: 'linear-gradient(90deg, #FFD700, #FFA500)',
                borderRadius: '0 8px 8px 0'
              }}
            />
          )}

          {/* Animated shine effect */}
          <motion.div
            animate={{ x: ['-100%', '200%'] }}
            transition={{ duration: 2, repeat: Infinity, repeatDelay: 1 }}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '30%',
              height: '100%',
              background: 'linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent)',
              borderRadius: '8px'
            }}
          />
        </div>
      </div>

      {/* Per-branch progress */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
        gap: '0.75rem'
      }}>
        {techBranches.map(branch => {
          const branchStats = getBranchStats(branch.id);
          if (!branchStats) return null;

          return (
            <motion.div
              key={branch.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: techBranches.indexOf(branch) * 0.1 }}
              style={{
                background: 'rgba(0, 0, 0, 0.3)',
                border: `1px solid ${branch.color}44`,
                borderRadius: '8px',
                padding: '0.75rem'
              }}
            >
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.4rem',
                marginBottom: '0.5rem'
              }}>
                <span>{branch.icon}</span>
                <span style={{
                  fontSize: '0.7rem',
                  color: branch.color,
                  fontWeight: 600
                }}>
                  {branch.name}
                </span>
                <span style={{
                  fontSize: '0.65rem',
                  color: 'rgba(255, 255, 255, 0.4)',
                  marginLeft: 'auto'
                }}>
                  {branchStats.done}/{branchStats.total}
                </span>
              </div>

              <div style={{
                background: 'rgba(255, 255, 255, 0.1)',
                borderRadius: '4px',
                height: '6px',
                overflow: 'hidden'
              }}>
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${branchStats.percentage}%` }}
                  transition={{ duration: 1, delay: techBranches.indexOf(branch) * 0.1 }}
                  style={{
                    height: '100%',
                    background: branch.color,
                    borderRadius: '4px'
                  }}
                />
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
