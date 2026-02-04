"use client";
import { motion } from 'framer-motion';
import type { TechNode as TechNodeType, NodeStatus } from './techTreeData';

interface TechNodeProps {
  node: TechNodeType;
  branchColor: string;
  isSelected: boolean;
  onClick: () => void;
}

const statusConfig: Record<NodeStatus, { glow: string; border: string; bg: string; icon: string }> = {
  done: {
    glow: '0 0 20px rgba(0, 255, 136, 0.5)',
    border: '#00FF88',
    bg: 'rgba(0, 255, 136, 0.15)',
    icon: '✅'
  },
  in_progress: {
    glow: '0 0 20px rgba(255, 215, 0, 0.5)',
    border: '#FFD700',
    bg: 'rgba(255, 215, 0, 0.15)',
    icon: '🔄'
  },
  locked: {
    glow: 'none',
    border: 'rgba(255, 255, 255, 0.2)',
    bg: 'rgba(255, 255, 255, 0.05)',
    icon: '🔒'
  }
};

export default function TechNode({ node, branchColor, isSelected, onClick }: TechNodeProps) {
  const config = statusConfig[node.status];
  const isActive = node.status !== 'locked';

  return (
    <motion.div
      onClick={isActive ? onClick : undefined}
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{
        opacity: 1,
        scale: isSelected ? 1.1 : 1,
        boxShadow: isSelected ? `0 0 30px ${branchColor}` : config.glow
      }}
      whileHover={isActive ? { scale: 1.05, boxShadow: `0 0 25px ${branchColor}` } : undefined}
      whileTap={isActive ? { scale: 0.98 } : undefined}
      transition={{ duration: 0.3, type: 'spring', stiffness: 200 }}
      style={{
        width: '140px',
        padding: '0.8rem',
        background: isSelected ? `${branchColor}22` : config.bg,
        border: `2px solid ${isSelected ? branchColor : config.border}`,
        borderRadius: '12px',
        cursor: isActive ? 'pointer' : 'not-allowed',
        position: 'relative',
        opacity: node.status === 'locked' ? 0.5 : 1
      }}
    >
      {/* Status indicator */}
      <div style={{
        position: 'absolute',
        top: '-8px',
        right: '-8px',
        fontSize: '1rem',
        filter: node.status === 'in_progress' ? 'none' : 'none'
      }}>
        {node.status === 'in_progress' ? (
          <motion.span
            animate={{ rotate: 360 }}
            transition={{ duration: 2, repeat: Infinity, ease: 'linear' }}
            style={{ display: 'inline-block' }}
          >
            {config.icon}
          </motion.span>
        ) : config.icon}
      </div>

      {/* Progress bar for in_progress items */}
      {node.status === 'in_progress' && node.progress !== undefined && (
        <div style={{
          position: 'absolute',
          bottom: '0',
          left: '0',
          right: '0',
          height: '3px',
          background: 'rgba(255, 255, 255, 0.1)',
          borderRadius: '0 0 10px 10px',
          overflow: 'hidden'
        }}>
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${node.progress}%` }}
            transition={{ duration: 1, ease: 'easeOut' }}
            style={{
              height: '100%',
              background: `linear-gradient(90deg, ${branchColor}, #FFD700)`,
              borderRadius: '0 0 10px 10px'
            }}
          />
        </div>
      )}

      {/* Node ID */}
      <div style={{
        fontSize: '0.6rem',
        color: 'rgba(255, 255, 255, 0.4)',
        textTransform: 'uppercase',
        letterSpacing: '0.1em',
        marginBottom: '0.3rem'
      }}>
        {node.id.toUpperCase()}
      </div>

      {/* Node name */}
      <div style={{
        fontSize: '0.85rem',
        fontWeight: 600,
        color: node.status === 'locked' ? 'rgba(255, 255, 255, 0.5)' : '#fff',
        marginBottom: '0.3rem',
        lineHeight: 1.2
      }}>
        {node.name}
      </div>

      {/* Metrics badge */}
      {node.metrics && node.status !== 'locked' && (
        <div style={{
          fontSize: '0.65rem',
          color: branchColor,
          fontWeight: 600,
          background: `${branchColor}22`,
          padding: '0.15rem 0.4rem',
          borderRadius: '4px',
          display: 'inline-block'
        }}>
          {node.metrics}
        </div>
      )}

      {/* Progress percentage for in_progress */}
      {node.status === 'in_progress' && node.progress !== undefined && (
        <div style={{
          fontSize: '0.6rem',
          color: '#FFD700',
          marginTop: '0.3rem'
        }}>
          {node.progress}% complete
        </div>
      )}
    </motion.div>
  );
}
