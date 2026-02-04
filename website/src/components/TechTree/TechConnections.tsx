"use client";
import { motion } from 'framer-motion';
import { useMemo } from 'react';
import { getConnections, getNodeById, techBranches, type Connection } from './techTreeData';

interface TechConnectionsProps {
  nodeWidth: number;
  nodeHeight: number;
  gapX: number;
  gapY: number;
  offsetX: number;
  offsetY: number;
}

export default function TechConnections({
  nodeWidth,
  nodeHeight,
  gapX,
  gapY,
  offsetX,
  offsetY
}: TechConnectionsProps) {
  const connections = useMemo(() => getConnections(), []);

  const getNodePosition = (nodeId: string) => {
    const node = getNodeById(nodeId);
    if (!node) return null;

    const x = offsetX + node.x * (nodeWidth + gapX) + nodeWidth / 2;
    const y = offsetY + node.y * (nodeHeight + gapY) + nodeHeight / 2;

    return { x, y };
  };

  const getNodeColor = (nodeId: string) => {
    const node = getNodeById(nodeId);
    if (!node) return '#00FF88';
    const branch = techBranches.find(b => b.id === node.branch);
    return branch?.color || '#00FF88';
  };

  const renderConnection = (conn: Connection, index: number) => {
    const from = getNodePosition(conn.from);
    const to = getNodePosition(conn.to);

    if (!from || !to) return null;

    const isActive = conn.status === 'active';
    const color = isActive ? getNodeColor(conn.from) : 'rgba(255, 255, 255, 0.15)';

    // Calculate control points for curved lines
    const dx = to.x - from.x;
    const dy = to.y - from.y;

    // Create smooth bezier curve
    const midX = from.x + dx / 2;
    const midY = from.y + dy / 2;

    // Curve more for diagonal connections
    const curveOffset = Math.abs(dy) > 20 ? dx * 0.3 : 0;

    const path = `M ${from.x} ${from.y} Q ${midX + curveOffset} ${from.y} ${midX} ${midY} Q ${midX + curveOffset} ${to.y} ${to.x} ${to.y}`;

    return (
      <g key={`${conn.from}-${conn.to}-${index}`}>
        {/* Background glow for active connections */}
        {isActive && (
          <motion.path
            d={path}
            fill="none"
            stroke={color}
            strokeWidth="4"
            strokeOpacity="0.2"
            initial={{ pathLength: 0 }}
            animate={{ pathLength: 1 }}
            transition={{ duration: 1, delay: index * 0.1 }}
          />
        )}

        {/* Main line */}
        <motion.path
          d={path}
          fill="none"
          stroke={color}
          strokeWidth="2"
          strokeDasharray={isActive ? "none" : "5 5"}
          initial={{ pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ duration: 0.8, delay: index * 0.1 }}
        />

        {/* Animated flow particles for active connections */}
        {isActive && (
          <motion.circle
            r="3"
            fill={color}
            filter="url(#glow)"
            initial={{ offsetDistance: '0%' }}
            animate={{ offsetDistance: '100%' }}
            transition={{
              duration: 2,
              repeat: Infinity,
              ease: 'linear',
              delay: index * 0.3
            }}
            style={{
              offsetPath: `path('${path}')`,
            }}
          />
        )}

        {/* Arrow at end */}
        <motion.circle
          cx={to.x}
          cy={to.y}
          r="4"
          fill={isActive ? color : 'rgba(255, 255, 255, 0.2)'}
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ duration: 0.3, delay: index * 0.1 + 0.5 }}
        />
      </g>
    );
  };

  return (
    <svg
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        pointerEvents: 'none',
        zIndex: 0
      }}
    >
      <defs>
        {/* Glow filter */}
        <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="2" result="coloredBlur" />
          <feMerge>
            <feMergeNode in="coloredBlur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>

        {/* Gradient for active lines */}
        <linearGradient id="activeGradient" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stopColor="#00FF88" />
          <stop offset="100%" stopColor="#FFD700" />
        </linearGradient>
      </defs>

      {connections.map((conn, i) => renderConnection(conn, i))}
    </svg>
  );
}
