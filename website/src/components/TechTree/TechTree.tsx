"use client";
import { useState, useRef, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';
import Section from '../Section';
import TechNode from './TechNode';
import TechConnections from './TechConnections';
import TechDetails from './TechDetails';
import TechProgress from './TechProgress';
import { techBranches, type TechNode as TechNodeType } from './techTreeData';

// Layout constants
const NODE_WIDTH = 140;
const NODE_HEIGHT = 100;
const GAP_X = 40;
const GAP_Y = 30;
const PADDING = 40;

export default function TechTree() {
  const { t } = useI18n();
  const [selectedNode, setSelectedNode] = useState<TechNodeType | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [, setDimensions] = useState({ width: 0, height: 0 });

  // Calculate grid dimensions
  const maxX = Math.max(...techBranches.flatMap(b => b.nodes.map(n => n.x)));
  const maxY = Math.max(...techBranches.flatMap(b => b.nodes.map(n => n.y)));

  const gridWidth = (maxX + 1) * (NODE_WIDTH + GAP_X) + PADDING * 2;
  const gridHeight = (maxY + 1) * (NODE_HEIGHT + GAP_Y) + PADDING * 2;

  useEffect(() => {
    const updateDimensions = () => {
      if (containerRef.current) {
        setDimensions({
          width: containerRef.current.offsetWidth,
          height: containerRef.current.offsetHeight
        });
      }
    };

    updateDimensions();
    window.addEventListener('resize', updateDimensions);
    return () => window.removeEventListener('resize', updateDimensions);
  }, []);

  // Default i18n fallback
  const techTree = t.techTree || {
    title: 'TRINITY <span style="color: var(--accent)">RESEARCH</span> LABORATORY',
    sub: 'Technology Development Tree',
    hint: 'Click on nodes to view details'
  };

  return (
    <Section id="tech-tree">
      <div className="tight fade" style={{ textAlign: 'center', marginBottom: '2rem' }}>
        <span className="badge">X-COM STYLE</span>
        <h2 dangerouslySetInnerHTML={{ __html: techTree.title }} />
        <p className="sub">{techTree.sub}</p>
      </div>

      {/* Progress bars */}
      <TechProgress />

      {/* Main tech tree container */}
      <motion.div
        ref={containerRef}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.5 }}
        style={{
          position: 'relative',
          width: '100%',
          overflowX: 'auto',
          background: 'linear-gradient(135deg, rgba(10, 26, 15, 0.8), rgba(0, 0, 0, 0.9))',
          border: '1px solid rgba(0, 255, 136, 0.2)',
          borderRadius: '16px',
          boxShadow: '0 0 40px rgba(0, 0, 0, 0.5), inset 0 0 60px rgba(0, 255, 136, 0.03)'
        }}
      >
        {/* Header */}
        <div style={{
          padding: '1rem 1.5rem',
          borderBottom: '1px solid rgba(0, 255, 136, 0.15)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          background: 'rgba(0, 0, 0, 0.3)'
        }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem'
          }}>
            <motion.div
              animate={{ opacity: [0.5, 1, 0.5] }}
              transition={{ duration: 2, repeat: Infinity }}
              style={{
                width: '10px',
                height: '10px',
                borderRadius: '50%',
                background: '#00FF88',
                boxShadow: '0 0 10px #00FF88'
              }}
            />
            <span style={{
              fontSize: '0.8rem',
              fontWeight: 600,
              color: '#00FF88',
              textTransform: 'uppercase',
              letterSpacing: '0.1em'
            }}>
              RESEARCH ACTIVE
            </span>
          </div>
          <div style={{
            fontSize: '0.7rem',
            color: 'rgba(255, 255, 255, 0.4)'
          }}>
            {techTree.hint}
          </div>
        </div>

        {/* Scrollable tree area */}
        <div style={{
          minWidth: `${gridWidth}px`,
          minHeight: `${gridHeight}px`,
          position: 'relative',
          padding: `${PADDING}px`
        }}>
          {/* Connection lines (SVG) */}
          <TechConnections
            nodeWidth={NODE_WIDTH}
            nodeHeight={NODE_HEIGHT}
            gapX={GAP_X}
            gapY={GAP_Y}
            offsetX={PADDING + NODE_WIDTH / 2}
            offsetY={PADDING + NODE_HEIGHT / 2}
          />

          {/* Branch labels on left */}
          {techBranches.map((branch, idx) => (
            <motion.div
              key={branch.id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: idx * 0.1 }}
              style={{
                position: 'absolute',
                left: '8px',
                top: `${PADDING + idx * (NODE_HEIGHT + GAP_Y) + NODE_HEIGHT / 2}px`,
                transform: 'translateY(-50%)',
                writingMode: 'vertical-rl',
                textOrientation: 'mixed',
                fontSize: '0.65rem',
                fontWeight: 700,
                color: branch.color,
                letterSpacing: '0.15em',
                opacity: 0.7
              }}
            >
              {branch.icon} {branch.name}
            </motion.div>
          ))}

          {/* Nodes */}
          {techBranches.map(branch =>
            branch.nodes.map((node, nodeIdx) => (
              <motion.div
                key={node.id}
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: nodeIdx * 0.05 + techBranches.indexOf(branch) * 0.1 }}
                style={{
                  position: 'absolute',
                  left: `${PADDING + node.x * (NODE_WIDTH + GAP_X)}px`,
                  top: `${PADDING + node.y * (NODE_HEIGHT + GAP_Y)}px`,
                  zIndex: 10
                }}
              >
                <TechNode
                  node={node}
                  branchColor={branch.color}
                  isSelected={selectedNode?.id === node.id}
                  onClick={() => setSelectedNode(node)}
                />
              </motion.div>
            ))
          )}
        </div>

        {/* Footer */}
        <div style={{
          padding: '1rem 1.5rem',
          borderTop: '1px solid rgba(0, 255, 136, 0.15)',
          background: 'rgba(0, 0, 0, 0.3)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center'
        }}>
          <div style={{
            fontSize: '0.7rem',
            color: 'rgba(255, 255, 255, 0.4)'
          }}>
            TRINITY RESEARCH LABORATORY v1.0
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

      {/* Legend */}
      <div className="fade" style={{
        marginTop: '1.5rem',
        display: 'flex',
        justifyContent: 'center',
        gap: '2rem',
        flexWrap: 'wrap'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <div style={{
            width: '12px',
            height: '12px',
            borderRadius: '4px',
            background: '#00FF88',
            boxShadow: '0 0 8px rgba(0, 255, 136, 0.5)'
          }} />
          <span style={{ fontSize: '0.8rem', color: 'rgba(255, 255, 255, 0.6)' }}>Complete</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <motion.div
            animate={{ opacity: [0.5, 1, 0.5] }}
            transition={{ duration: 1.5, repeat: Infinity }}
            style={{
              width: '12px',
              height: '12px',
              borderRadius: '4px',
              background: '#FFD700',
              boxShadow: '0 0 8px rgba(255, 215, 0, 0.5)'
            }}
          />
          <span style={{ fontSize: '0.8rem', color: 'rgba(255, 255, 255, 0.6)' }}>In Progress</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <div style={{
            width: '12px',
            height: '12px',
            borderRadius: '4px',
            background: 'rgba(255, 255, 255, 0.2)',
            border: '1px solid rgba(255, 255, 255, 0.3)'
          }} />
          <span style={{ fontSize: '0.8rem', color: 'rgba(255, 255, 255, 0.6)' }}>Locked</span>
        </div>
      </div>

      {/* Details panel */}
      <TechDetails node={selectedNode} onClose={() => setSelectedNode(null)} />
    </Section>
  );
}
