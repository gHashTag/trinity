"use client";
import { motion } from "framer-motion";
import { useEffect, useRef, useState } from "react";

/**
 * Evolution Tree Visualization for AGENT MU v8.18
 *
 * Displays AGENT MU's evolution as a tree:
 * - Root: Initial state
 * - Branches: Successful mutations
 * - Color: Fitness gradient (red → gold)
 * - Size: Node fitness
 * - Animation: Grow from root
 */

export interface EvolutionNode {
  node_id: string;
  parent_id: string | null;
  mutation_type: string;
  timestamp: number;
  fitness: number;
  depth: number;
}

interface Props {
  data: EvolutionNode[];
  currentFitness: number;
  width?: number;
  height?: number;
}

const GOLD = '#ffd700';
const GOLD_DIM = 'rgba(255, 215, 0, 0.3)';
const RED = 'rgba(255, 100, 100, 0.8)';
const GREEN = 'rgba(100, 255, 100, 0.8)';

interface TreeNode extends EvolutionNode {
  children: TreeNode[];
  x: number;
  y: number;
}

function buildTreeHierarchy(nodes: EvolutionNode[]): TreeNode[] {
  const nodeMap = new Map<string, TreeNode>();
  const roots: TreeNode[] = [];

  // First pass: create map with x,y positions
  nodes.forEach((n) => {
    nodeMap.set(n.node_id, {
      ...n,
      children: [],
      x: 0,
      y: n.depth * 50,
    });
  });

  // Second pass: build hierarchy and assign x positions
  nodes.forEach((n) => {
    const node = nodeMap.get(n.node_id)!;
    if (n.parent_id && nodeMap.has(n.parent_id)) {
      nodeMap.get(n.parent_id)!.children.push(node);
    } else {
      roots.push(node);
    }
  });

  // Calculate x positions using simple tree layout
  let nextX = 0;
  const calculateX = (node: TreeNode, depth: number) => {
    if (node.children.length === 0) {
      node.x = nextX;
      nextX += 80;
    } else {
      node.children.forEach((child) => calculateX(child, depth + 1));
      // Parent x is average of first and last child
      const firstChild = node.children[0];
      const lastChild = node.children[node.children.length - 1];
      node.x = (firstChild.x + lastChild.x) / 2;
    }
  };

  roots.forEach((root) => calculateX(root, 0));

  // Center the tree
  if (roots.length > 0) {
    const minX = Math.min(...roots.flatMap(r => getAllNodes(r).map(n => n.x)));
    const maxX = Math.max(...roots.flatMap(r => getAllNodes(r).map(n => n.x)));
    const treeWidth = maxX - minX;
    const shiftX = (treeWidth > 0 ? (400 - treeWidth) / 2 : 200) - minX;

    const shiftNodes = (node: TreeNode) => {
      node.x += shiftX;
      node.children.forEach(shiftNodes);
    };
    roots.forEach(shiftNodes);
  }

  return roots;
}

function getAllNodes(node: TreeNode): TreeNode[] {
  return [node, ...node.children.flatMap(getAllNodes)];
}

export default function EvolutionTreeChart({
  data,
  currentFitness,
  width = 400,
  height = 300,
}: Props) {
  const svgRef = useRef<SVGSVGElement>(null);
  const [dimensions, setDimensions] = useState({ width, height });

  // Build tree hierarchy from flat list
  const tree = buildTreeHierarchy(data);

  // Calculate fitness color
  const getFitnessColor = (fitness: number): string => {
    // Fitness ranges from 0 to 1
    // Low (0-0.3): Red
    // Medium (0.3-0.7): Gold
    // High (0.7-1.0): Green
    if (fitness < 0.3) {
      return `rgba(255, ${100 + fitness * 500}, 100, 0.8)`;
    } else if (fitness < 0.7) {
      return `rgba(255, 215, ${100 + (fitness - 0.3) * 387}, 0.8)`;
    } else {
      return `rgba(${100 + (1 - fitness) * 155}, 255, ${100 + (1 - fitness) * 155}, 0.8)`;
    }
  };

  // Render tree node recursively
  const renderNode = (
    node: TreeNode,
    level: number,
    offsetX: number,
  ): JSX.Element => {
    const x = node.x + offsetX;
    const y = node.y + 30;
    const color = getFitnessColor(node.fitness);
    const radius = 5 + node.fitness * 12;

    return (
      <g key={node.node_id}>
        {/* Connection to parent */}
        {node.parent_id && data.find(p => p.node_id === node.parent_id) && (
          <line
            x1={x}
            y1={y}
            x2={x - (Math.random() - 0.5) * 40}
            y2={y - 30}
            stroke={GOLD_DIM}
            strokeWidth={1}
            strokeDasharray="3 3"
          />
        )}

        {/* Node circle */}
        <motion.circle
          cx={x}
          cy={y}
          r={radius}
          fill={color}
          stroke={GOLD}
          strokeWidth={1.5}
          initial={{ scale: 0, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: level * 0.15, duration: 0.5 }}
          style={{ cursor: 'pointer' }}
        >
          <title>
            {node.mutation_type}
            Fitness: {(node.fitness * 100).toFixed(1)}%
            Depth: {node.depth}
          </title>
        </motion.circle>

        {/* Mutation type label (for important nodes) */}
        {node.fitness > 0.8 && (
          <motion.text
            x={x}
            y={y - radius - 5}
            textAnchor="middle"
            fill={GOLD}
            fontSize="8"
            fontFamily="monospace"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: level * 0.15 + 0.3 }}
          >
            {node.mutation_type.slice(0, 15)}
            {node.mutation_type.length > 15 ? '...' : ''}
          </motion.text>
        )}

        {/* Render children */}
        {node.children.map((child) => renderNode(child, level + 1, offsetX))}
      </g>
    );
  };

  // Calculate tree bounds for centering
  const allNodes = tree.flatMap(root => getAllNodes(root));
  const minX = allNodes.length > 0 ? Math.min(...allNodes.map(n => n.x)) : 0;
  const maxX = allNodes.length > 0 ? Math.max(...allNodes.map(n => n.x)) : 0;
  const treeWidth = maxX - minX;

  return (
    <div style={{ position: 'relative' }}>
      <svg
        ref={svgRef}
        width={dimensions.width}
        height={dimensions.height}
        style={{
          background: 'rgba(0, 0, 0, 0.4)',
          borderRadius: '8px',
          border: `1px solid ${GOLD_DIM}`,
        }}
        viewBox={`0 0 ${dimensions.width} ${dimensions.height}`}
      >
        {/* Title */}
        <text
          x={10}
          y={20}
          fill={GOLD}
          fontSize="11"
          fontFamily="Outfit, sans-serif"
          fontWeight="600"
        >
          EVOLUTION TREE
        </text>

        {/* Legend */}
        <g transform={`translate(${dimensions.width - 120}, 15)`}>
          <circle cx="0" cy="0" r="4" fill="rgba(255, 100, 100, 0.8)" />
          <text x="8" y="3" fill="#aaa" fontSize="8">Low</text>

          <circle cx="30" cy="0" r="4" fill={GOLD} />
          <text x="38" y="3" fill="#aaa" fontSize="8">Med</text>

          <circle cx="60" cy="0" r="4" fill="rgba(100, 255, 100, 0.8)" />
          <text x="68" y="3" fill="#aaa" fontSize="8">High</text>
        </g>

        {/* Tree */}
        <g transform={`translate(${(dimensions.width - treeWidth) / 2 - minX}, 0)`}>
          {tree.map(root => renderNode(root, 0, 0))}
        </g>

        {/* Current fitness indicator */}
        <g transform={`translate(10, ${dimensions.height - 30})`}>
          <text x="0" y="0" fill={GOLD} fontSize="9" fontFamily="monospace">
            Current: ×{currentFitness.toFixed(2)}
          </text>
          <text x="0" y="12" fill="#888" fontSize="8" fontFamily="monospace">
            Nodes: {data.length}
          </text>
        </g>

        {/* Empty state */}
        {data.length === 0 && (
          <text
            x={dimensions.width / 2}
            y={dimensions.height / 2}
            textAnchor="middle"
            fill={GOLD_DIM}
            fontSize="12"
          >
            No evolution data yet
          </text>
        )}
      </svg>

      {/* Tooltip on hover */}
      {data.length > 0 && (
        <div style={{
          position: 'absolute',
          bottom: '5px',
          right: '5px',
          fontSize: '7px',
          color: GOLD_DIM,
        }}>
          Hover nodes for details
        </div>
      )}
    </div>
  );
}

/**
 * Generate mock evolution data for testing
 */
export function generateMockEvolutionData(count: number = 20): EvolutionNode[] {
  const nodes: EvolutionNode[] = [];
  const mutations = [
    'SYNTAX_FIX',
    'TYPE_FIX',
    'ALLOCATOR_FIX',
    'META_LEARN',
    'SELF_MOD',
    'PREDICT',
    'COLLAB',
  ];

  let parentId: string | null = null;
  for (let i = 0; i < count; i++) {
    const depth = Math.floor(Math.random() * 4);
    parentId = i > 0 && Math.random() > 0.3
      ? `node_${Math.floor(Math.random() * i)}`
      : null;

    nodes.push({
      node_id: `node_${i}`,
      parent_id: parentId,
      mutation_type: mutations[Math.floor(Math.random() * mutations.length)],
      timestamp: Date.now() - (count - i) * 3600000,
      fitness: 0.3 + Math.random() * 0.6,
      depth: depth,
    });
  }

  return nodes;
}
