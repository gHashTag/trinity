"use client";

import { useEffect, useRef, useState, useMemo, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  fetchMultiAgentEvolutionTree,
  fetchAgentMuEvolutionTree,
  type EvolutionTreeNode,
  type AgentSource,
  AGENT_COLORS,
} from "@/services/chatApi";

const FONT = "'Outfit', system-ui, sans-serif";
const MONO = "'JetBrains Mono', 'Fira Code', monospace";

const GOLD = '#ffd700';
const GOLD_DIM = 'rgba(255, 215, 0, 0.3)';
const CYAN = '#00ccff';
const PURPLE = '#aa66ff';
const GREEN = '#00ff88';

const glassStyle = (borderColor = 'rgba(255,255,255,0.08)'): React.CSSProperties => ({
  background: 'rgba(0,0,0,0.3)',
  backdropFilter: 'blur(12px)',
  border: `1px solid ${borderColor}`,
  borderRadius: 14,
});

interface Props {
  width?: number;
  height?: number;
  onNodeClick?: (node: EvolutionTreeNode) => void;
  multiAgent?: boolean;  // v8.20: Enable multi-agent mode
}

interface Transform {
  x: number;
  y: number;
  scale: number;
}

interface TreeNode extends EvolutionTreeNode {
  children: TreeNode[];
  x?: number;
  y?: number;
}

/**
 * Interactive Evolution Tree v8.20
 *
 * Features:
 * - Zoom in/out with mouse wheel
 * - Pan with drag
 * - Click node for details
 * - Highlight path from root
 * - Export subtree as SVG
 * - v8.20: Multi-agent support (AGENT_MU, PAS, PHI, VIBEE)
 * - v8.20: Agent filter checkboxes
 * - v8.20: Color-coded nodes by agent source
 * - v8.20: Cross-agent collaboration edges (dotted lines)
 */
export default function InteractiveEvolutionTree({
  width = 500,
  height = 350,
  onNodeClick,
  multiAgent = true  // v8.20: Default to multi-agent mode
}: Props) {
  const svgRef = useRef<SVGSVGElement>(null);
  const [data, setData] = useState<EvolutionTreeNode[]>([]);
  const [loading, setLoading] = useState(true);
  const [transform, setTransform] = useState<Transform>({ x: 0, y: 0, scale: 1 });
  const [dragging, setDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [selectedNode, setSelectedNode] = useState<string | null>(null);
  const [hoveredNode, setHoveredNode] = useState<string | null>(null);
  const [showTooltip, setShowTooltip] = useState(false);
  const [tooltipPos, setTooltipPos] = useState({ x: 0, y: 0 });
  const [tooltipData, setTooltipData] = useState<EvolutionTreeNode | null>(null);

  // v8.20: Agent filter state
  const [visibleAgents, setVisibleAgents] = useState<Set<AgentSource>>(
    new Set<AgentSource>(['AGENT_MU', 'PAS', 'PHI', 'VIBEE'])
  );
  const [showFilters, setShowFilters] = useState(false);

  // Fetch evolution tree data
  useEffect(() => {
    const fetchData = async () => {
      try {
        const result = multiAgent
          ? await fetchMultiAgentEvolutionTree()
          : await fetchAgentMuEvolutionTree();
        setData(result);
      } catch (error) {
        console.error("Failed to fetch evolution tree:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [multiAgent]);

  // Filter data by visible agents
  const filteredData = useMemo(() => {
    if (!multiAgent || visibleAgents.size === 4) return data;

    // Include nodes whose agent_source is in visibleAgents
    // Also include nodes if they have influence from visible agents
    return data.filter(node => {
      if (!node.agent_source) return true;  // Old format nodes
      if (visibleAgents.has(node.agent_source)) return true;
      // Check if this node is influenced by any visible agent
      if (node.influenced_by) {
        return node.influenced_by.some(id => {
          const influencer = data.find(n => n.node_id === id);
          return influencer?.agent_source && visibleAgents.has(influencer.agent_source);
        });
      }
      return false;
    });
  }, [data, visibleAgents, multiAgent]);

  // Toggle agent visibility
  const toggleAgent = useCallback((agent: AgentSource) => {
    setVisibleAgents(prev => {
      const newSet = new Set(prev);
      if (newSet.has(agent)) {
        if (newSet.size > 1) {  // Always keep at least one agent visible
          newSet.delete(agent);
        }
      } else {
        newSet.add(agent);
      }
      return newSet;
    });
  }, []);

  // Build tree hierarchy with positions
  const tree = useMemo(() => {
    if (filteredData.length === 0) return [];

    const nodeMap = new Map<string, TreeNode>();
    const roots: TreeNode[] = [];

    // Create tree nodes
    filteredData.forEach(n => {
      nodeMap.set(n.node_id, { ...n, children: [] });
    });

    // Build hierarchy
    filteredData.forEach(n => {
      const node = nodeMap.get(n.node_id)!;
      if (n.parent_id && nodeMap.has(n.parent_id)) {
        nodeMap.get(n.parent_id)!.children.push(node);
      } else {
        roots.push(node);
      }
    });

    // Calculate positions using simple tree layout
    const calculatePositions = (
      node: TreeNode,
      x: number,
      y: number,
      horizontalSpacing: number,
      verticalSpacing: number
    ): void => {
      node.x = x;
      node.y = y;

      if (node.children.length === 0) return;

      const totalWidth = (node.children.length - 1) * horizontalSpacing;
      let startX = x - totalWidth / 2;

      node.children.forEach((child, i) => {
        calculatePositions(
          child,
          startX + i * horizontalSpacing,
          y + verticalSpacing,
          horizontalSpacing,
          verticalSpacing
        );
      });
    };

    // Position each root tree
    const rootSpacing = width / (roots.length + 1);
    roots.forEach((root, i) => {
      calculatePositions(root, rootSpacing * (i + 1), 40, 50, 50);
    });

    return roots;
  }, [filteredData, width]);

  // Get path from root to node
  const getPathToRoot = useCallback((nodeId: string, nodes: EvolutionTreeNode[]): string[] => {
    const path: string[] = [];
    let current = nodes.find(n => n.node_id === nodeId);
    while (current) {
      path.push(current.node_id);
      if (!current.parent_id) break;
      current = nodes.find(n => n.node_id === current!.parent_id!);
    }
    return path;
  }, []);

  const selectedPath = selectedNode ? getPathToRoot(selectedNode, filteredData) : [];

  // Get all influence edges for rendering
  const influenceEdges = useMemo(() => {
    const edges: Array<{ from: string; to: string; color: string }> = [];
    filteredData.forEach(node => {
      if (node.influenced_by) {
        node.influenced_by.forEach(parentId => {
          const parent = filteredData.find(n => n.node_id === parentId);
          if (parent && parent.agent_source) {
            edges.push({
              from: parentId,
              to: node.node_id,
              color: AGENT_COLORS[parent.agent_source],
            });
          }
        });
      }
    });
    return edges;
  }, [filteredData]);

  // Get node position by ID
  const getNodePosition = useCallback((nodeId: string): { x: number; y: number } | null => {
    const findPos = (nodes: TreeNode[]): { x: number; y: number } | null => {
      for (const node of nodes) {
        if (node.node_id === nodeId && node.x !== undefined && node.y !== undefined) {
          return { x: node.x, y: node.y };
        }
        if (node.children.length > 0) {
          const found = findPos(node.children);
          if (found) return found;
        }
      }
      return null;
    };
    return findPos(tree);
  }, [tree]);

  // Zoom with mouse wheel
  const handleWheel = (e: React.WheelEvent) => {
    e.preventDefault();
    const newScale = Math.max(0.3, Math.min(3, transform.scale - e.deltaY * 0.001));
    setTransform({ ...transform, scale: newScale });
  };

  // Pan with drag
  const handleMouseDown = (e: React.MouseEvent) => {
    if (e.target instanceof SVGElement || e.target instanceof SVGGElement) {
      setDragging(true);
      setDragStart({ x: e.clientX - transform.x, y: e.clientY - transform.y });
    }
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (dragging) {
      setTransform({
        ...transform,
        x: e.clientX - dragStart.x,
        y: e.clientY - dragStart.y
      });
    }
  };

  const handleMouseUp = () => setDragging(false);

  const handleMouseLeave = () => {
    setDragging(false);
    setHoveredNode(null);
    setShowTooltip(false);
  };

  // Node click handler
  const handleNodeClick = (node: TreeNode, e: React.MouseEvent) => {
    e.stopPropagation();
    setSelectedNode(node.node_id === selectedNode ? null : node.node_id);
    onNodeClick?.(node);
  };

  // Hover handler for tooltip
  const handleNodeHover = (node: TreeNode, e: React.MouseEvent) => {
    setHoveredNode(node.node_id);
    setTooltipData(node);
    setTooltipPos({ x: e.clientX, y: e.clientY });
    setShowTooltip(true);
  };

  const handleNodeLeave = () => {
    setHoveredNode(null);
    setShowTooltip(false);
  };

  // Get agent color for a node
  const getAgentColor = useCallback((node: TreeNode): string => {
    if (!node.agent_source) return GOLD;
    return AGENT_COLORS[node.agent_source] || GOLD;
  }, []);

  // Render a single node and its children recursively
  const renderNode = (node: TreeNode): JSX.Element => {
    const isSelected = selectedNode === node.node_id;
    const isHighlighted = selectedPath.includes(node.node_id);
    const isHovered = hoveredNode === node.node_id;
    const agentColor = getAgentColor(node);

    // Color based on selection state and agent source
    let color = isSelected ? GREEN :
                isHighlighted ? agentColor :
                agentColor;

    if (isHovered) {
      color = GOLD;
    }

    const radius = 5 + node.fitness * 8;
    const x = node.x ?? 100;
    const y = node.y ?? 100;

    return (
      <g key={node.node_id}>
        {/* Connection to parent */}
        {node.parent_id && (
          <line
            x1={x}
            y1={y}
            x2={x}
            y2={y - 50}
            stroke={isHighlighted ? agentColor : GOLD_DIM}
            strokeWidth={isHighlighted ? 2 : 1}
            strokeDasharray={isHighlighted ? 'none' : '4 2'}
            opacity={isHighlighted ? 1 : 0.5}
          />
        )}

        {/* Node circle */}
        <motion.circle
          cx={x}
          cy={y}
          r={radius}
          fill={color}
          stroke={isSelected ? GOLD : (isHighlighted ? CYAN : `${agentColor}80`)}
          strokeWidth={isSelected ? 3 : (isHighlighted ? 2 : 1)}
          style={{ cursor: 'pointer' }}
          onClick={(e) => handleNodeClick(node, e)}
          onMouseEnter={(e) => handleNodeHover(node, e)}
          onMouseLeave={handleNodeLeave}
          initial={{ scale: 0, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: node.depth * 0.05, duration: 0.3 }}
          whileHover={{ scale: 1.2 }}
        />

        {/* Agent source indicator (small dot in center) */}
        {node.agent_source && (
          <circle
            cx={x}
            cy={y}
            r={radius * 0.3}
            fill="rgba(0,0,0,0.5)"
          />
        )}

        {/* Node label for selected/hovered nodes */}
        {(isSelected || isHovered) && (
          <motion.text
            x={x}
            y={y - radius - 5}
            textAnchor="middle"
            fill={agentColor}
            fontSize={8}
            fontFamily={MONO}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
          >
            {node.mutation_type}
          </motion.text>
        )}

        {/* Agent badge */}
        {isSelected && node.agent_source && (
          <motion.text
            x={x}
            y={y + radius + 10}
            textAnchor="middle"
            fill={agentColor}
            fontSize={6}
            fontFamily={FONT}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
          >
            {node.agent_source}
          </motion.text>
        )}

        {/* Render children */}
        {node.children.map(child => renderNode(child))}
      </g>
    );
  };

  // Reset view
  const resetView = () => {
    setTransform({ x: 0, y: 0, scale: 1 });
    setSelectedNode(null);
  };

  // Export SVG
  const exportSVG = () => {
    if (!svgRef.current) return;
    const svgData = new XMLSerializer().serializeToString(svgRef.current);
    const blob = new Blob([svgData], { type: 'image/svg+xml' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `evolution-tree-${Date.now()}.svg`;
    a.click();
    URL.revokeObjectURL(url);
  };

  if (loading) {
    return (
      <div
        style={{
          width,
          height,
          ...glassStyle('rgba(255,215,0,0.15)'),
          padding: '12px',
          fontFamily: FONT,
          color: GOLD,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: '10px'
        }}
      >
        <motion.div
          animate={{ opacity: [0.3, 1, 0.3] }}
          transition={{ duration: 1.5, repeat: Infinity }}
        >
          Loading Evolution Tree...
        </motion.div>
      </div>
    );
  }

  // Count nodes by agent
  const agentCounts = useMemo(() => {
    const counts: Record<AgentSource, number> = {
      AGENT_MU: 0,
      PAS: 0,
      PHI: 0,
      VIBEE: 0,
    };
    data.forEach(node => {
      if (node.agent_source) {
        counts[node.agent_source]++;
      } else {
        counts.AGENT_MU++;  // Default to AGENT_MU for old format
      }
    });
    return counts;
  }, [data]);

  return (
    <div style={{ position: 'relative' }}>
      {/* Header */}
      <div
        style={{
          position: 'absolute',
          top: 10,
          left: 10,
          zIndex: 10,
          fontFamily: FONT,
          color: GOLD,
          fontSize: '12px',
          fontWeight: 'bold',
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }}
      >
        <span>EVOLUTION TREE v8.20</span>
        {multiAgent && (
          <button
            onClick={() => setShowFilters(!showFilters)}
            style={{
              ...glassStyle('rgba(255,215,0,0.2)'),
              padding: '2px 6px',
              fontSize: '8px',
              fontFamily: FONT,
              color: GOLD,
              cursor: 'pointer',
              border: 'none',
            }}
          >
            Filters
          </button>
        )}
      </div>

      {/* Agent Filters Panel */}
      <AnimatePresence>
        {showFilters && multiAgent && (
          <motion.div
            initial={{ opacity: 0, x: -10 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -10 }}
            style={{
              position: 'absolute',
              top: 35,
              left: 10,
              zIndex: 10,
              ...glassStyle('rgba(255,215,0,0.2)'),
              padding: '8px',
              fontFamily: FONT,
              fontSize: '8px',
            }}
          >
            <div style={{ marginBottom: '6px', fontWeight: 'bold', opacity: 0.8 }}>
      Filter by Agent
            </div>
            {(['AGENT_MU', 'PAS', 'PHI', 'VIBEE'] as AgentSource[]).map(agent => (
              <div
                key={agent}
                onClick={() => toggleAgent(agent)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  padding: '3px 0',
                  cursor: 'pointer',
                  opacity: visibleAgents.has(agent) ? 1 : 0.4,
                }}
                onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(255,215,0,0.1)'}
                onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
              >
                <input
                  type="checkbox"
                  checked={visibleAgents.has(agent)}
                  onChange={() => toggleAgent(agent)}
                  style={{ accentColor: AGENT_COLORS[agent] }}
                />
                <div
                  style={{
                    width: '8px',
                    height: '8px',
                    borderRadius: '50%',
                    background: AGENT_COLORS[agent],
                  }}
                />
                <span style={{ color: AGENT_COLORS[agent] }}>{agent}</span>
                <span style={{ opacity: 0.6, marginLeft: 'auto' }}>
                  ({agentCounts[agent]})
                </span>
              </div>
            ))}
          </motion.div>
        )}
      </AnimatePresence>

      {/* Controls */}
      <div
        style={{
          position: 'absolute',
          top: 10,
          right: 10,
          zIndex: 10,
          display: 'flex',
          flexDirection: 'column',
          gap: '4px'
        }}
      >
        <button
          onClick={resetView}
          style={{
            ...glassStyle('rgba(255,215,0,0.2)'),
            padding: '4px 8px',
            fontSize: '8px',
            fontFamily: FONT,
            color: GOLD,
            cursor: 'pointer',
            border: 'none'
          }}
        >
          Reset
        </button>
        <button
          onClick={exportSVG}
          style={{
            ...glassStyle('rgba(255,215,0,0.2)'),
            padding: '4px 8px',
            fontSize: '8px',
            fontFamily: FONT,
            color: GOLD,
            cursor: 'pointer',
            border: 'none'
          }}
        >
          Export SVG
        </button>
        <div
          style={{
            ...glassStyle('rgba(255,215,0,0.1)'),
            padding: '4px 8px',
            fontSize: '8px',
            fontFamily: MONO,
            color: GOLD,
            textAlign: 'center'
          }}
        >
          Zoom: {transform.scale.toFixed(1)}×
        </div>
      </div>

      {/* Stats */}
      <div
        style={{
          position: 'absolute',
          bottom: 10,
          left: 10,
          zIndex: 10,
          fontFamily: FONT,
          color: GOLD,
          fontSize: '8px',
          opacity: 0.7
        }}
      >
        Nodes: {filteredData.length}/{data.length} | Selected: {selectedNode || 'None'}
      </div>

      {/* Legend */}
      <div
        style={{
          position: 'absolute',
          bottom: 10,
          right: 10,
          zIndex: 10,
          fontFamily: FONT,
          fontSize: '7px',
          display: 'flex',
          flexDirection: 'column',
          gap: '2px',
          opacity: 0.7
        }}
      >
        {multiAgent ? (
          <>
            {(['AGENT_MU', 'PAS', 'PHI', 'VIBEE'] as AgentSource[]).map(agent => (
              <div key={agent} style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: AGENT_COLORS[agent] }}></div>
                <span style={{ color: AGENT_COLORS[agent] }}>{agent}</span>
              </div>
            ))}
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px', marginTop: '2px' }}>
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: GREEN }}></div>
              <span style={{ color: GOLD }}>Selected</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
              <div style={{ width: '12px', height: '2px', background: GOLD, borderStyle: 'dashed' }}></div>
              <span style={{ color: GOLD }}>Collaboration</span>
            </div>
          </>
        ) : (
          <>
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: GREEN }}></div>
              <span style={{ color: GOLD }}>Selected</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: CYAN }}></div>
              <span style={{ color: GOLD }}>Path</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: GOLD }}></div>
              <span style={{ color: GOLD }}>Hovered</span>
            </div>
          </>
        )}
      </div>

      {/* Main SVG */}
      <svg
        ref={svgRef}
        width={width}
        height={height}
        style={{
          ...glassStyle('rgba(255,215,0,0.15)'),
          cursor: dragging ? 'grabbing' : 'grab'
        }}
        onWheel={handleWheel}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseLeave}
      >
        <g transform={`translate(${transform.x}, ${transform.y}) scale(${transform.scale})`}>
          {/* Grid background */}
          <defs>
            <pattern
              id="grid"
              width="40"
              height="40"
              patternUnits="userSpaceOnUse"
            >
              <path
                d="M 40 0 L 0 0 0 40"
                fill="none"
                stroke="rgba(255,215,0,0.05)"
                strokeWidth="1"
              />
            </pattern>
          </defs>
          <rect
            width="100%"
            height="100%"
            fill="url(#grid)"
          />

          {/* Render collaboration edges (dotted lines) */}
          {multiAgent && influenceEdges.map((edge, idx) => {
            const fromPos = getNodePosition(edge.from);
            const toPos = getNodePosition(edge.to);
            if (!fromPos || !toPos) return null;

            return (
              <line
                key={`influence-${idx}`}
                x1={fromPos.x}
                y1={fromPos.y}
                x2={toPos.x}
                y2={toPos.y}
                stroke={edge.color}
                strokeWidth={1}
                strokeDasharray="3 3"
                opacity={0.5}
              />
            );
          })}

          {/* Render tree */}
          {tree.map(root => renderNode(root))}
        </g>
      </svg>

      {/* Tooltip */}
      {showTooltip && tooltipData && (
        <motion.div
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          style={{
            position: 'fixed',
            left: tooltipPos.x + 15,
            top: tooltipPos.y + 15,
            ...glassStyle('rgba(255,215,0,0.3)'),
            padding: '8px 12px',
            fontFamily: FONT,
            fontSize: '9px',
            color: GOLD,
            zIndex: 1000,
            pointerEvents: 'none'
          }}
        >
          <div style={{ fontWeight: 'bold', marginBottom: '4px', fontFamily: MONO }}>
            {tooltipData.mutation_type}
          </div>
          {tooltipData.agent_source && (
            <div style={{ color: AGENT_COLORS[tooltipData.agent_source] }}>
              Agent: {tooltipData.agent_source}
            </div>
          )}
          <div>Fitness: {tooltipData.fitness.toFixed(3)}</div>
          <div>Depth: {tooltipData.depth}</div>
          {tooltipData.influenced_by && tooltipData.influenced_by.length > 0 && (
            <div style={{ fontSize: '7px', opacity: 0.7 }}>
              Influenced by: {tooltipData.influenced_by.length} agent(s)
            </div>
          )}
          <div style={{ fontSize: '7px', opacity: 0.6 }}>
            {new Date(tooltipData.timestamp * 1000).toLocaleString()}
          </div>
        </motion.div>
      )}
    </div>
  );
}
