import { motion } from 'framer-motion';
import { memo } from 'react';
import { useI18n } from '../../i18n/context';
import type { TechNode as TechNodeType, NodeStatus } from './techTreeData';

interface TechNodeProps {
  node: TechNodeType;
  branchColor: string;
  isSelected: boolean;
  onClick: () => void;
}

const statusConfig: Record<NodeStatus, { icon: string; bg: string }> = {
  done: {
    bg: '#07140f', // Solid dark green tint
    icon: '✅'
  },
  in_progress: {
    bg: '#0a1914', // Solid dark slate
    icon: '🔄'
  },
  locked: {
    bg: '#050a08', // Solid near-black
    icon: '🔒'
  }
};

const TechNode = memo(function TechNode({ node, branchColor, isSelected, onClick }: TechNodeProps) {
  const { t } = useI18n();
  const config = statusConfig[node.status];
  const isActive = node.status !== 'locked';

  // Localized content
  const localized = t.techTree.nodes?.[node.id] || {};
  const name = localized.name || node.name;
  const metrics = localized.metrics || node.metrics;

  return (
    <motion.div
      onClick={isActive ? onClick : undefined}
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{
        opacity: isActive ? 1 : 0.6,
        scale: isSelected ? 1.1 : 1,
        boxShadow: isSelected 
          ? `0 0 20px ${branchColor}aa` 
          : isActive 
            ? `0 0 10px ${branchColor}22` 
            : 'none'
      }}
      whileHover={isActive ? { scale: 1.05, boxShadow: `0 0 25px ${branchColor}` } : undefined}
      whileTap={isActive ? { scale: 0.98 } : undefined}
      transition={{ duration: 0.3, type: 'spring', stiffness: 200 }}
      style={{
        width: '130px',
        height: '130px',
        padding: '1rem',
        background: config.bg,
        border: `2px solid ${isSelected ? branchColor : isActive ? `${branchColor}66` : 'rgba(255, 255, 255, 0.1)'}`,
        borderRadius: '12px',
        cursor: isActive ? 'pointer' : 'not-allowed',
        position: 'relative',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
      }}
    >
      {/* Status indicator */}
      <div style={{
        position: 'absolute',
        top: '-10px',
        right: '-10px',
        fontSize: '1.1rem',
        zIndex: 20,
        filter: 'drop-shadow(0 0 3px rgba(0,0,0,0.5))',
        background: 'rgba(0,0,0,0.6)',
        borderRadius: '50%',
        width: '26px',
        height: '26px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        backdropFilter: 'blur(2px)'
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
        color: isActive ? `${branchColor}aa` : 'rgba(255, 255, 255, 0.3)',
        textTransform: 'uppercase',
        letterSpacing: '0.1em',
        marginBottom: '0.3rem',
        fontWeight: 700
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
        {name}
      </div>

      {/* Metrics badge */}
      {metrics && node.status !== 'locked' && (
        <div style={{
          fontSize: '0.65rem',
          color: branchColor,
          fontWeight: 700,
          background: `${branchColor}22`,
          padding: '0.15rem 0.4rem',
          borderRadius: '4px',
          display: 'inline-block',
          border: `1px solid ${branchColor}44`
        }}>
          {metrics}
        </div>
      )}

      {/* Progress percentage for in_progress */}
      {node.status === 'in_progress' && node.progress !== undefined && (
        <div style={{
          fontSize: '0.6rem',
          color: '#FFD700',
          marginTop: '0.3rem',
          fontWeight: 600
        }}>
          {node.progress}% {t.techTree.complete}
        </div>
      )}
    </motion.div>
  );
});

export default TechNode;
