// Tech Tree Data
// Based on docs/TECH_TREE.md

export type NodeStatus = 'done' | 'in_progress' | 'locked';

export interface TechNode {
  id: string;
  name: string;
  description: string;
  status: NodeStatus;
  progress?: number; // 0-100 for in_progress items
  branch: string;
  prerequisites: string[];
  unlocks: string[];
  metrics?: string;
  x: number; // Grid position
  y: number;
}

export interface TechBranch {
  id: string;
  name: string;
  color: string;
  icon: string;
  nodes: TechNode[];
}

export const techBranches: TechBranch[] = [
  {
    id: 'core',
    name: 'CORE',
    color: '#00FF88',
    icon: '⚙️',
    nodes: [
      {
        id: 'core-001',
        name: 'Parser v2',
        description: 'Advanced VIBEE specification parser with multi-language support',
        status: 'done',
        branch: 'core',
        prerequisites: [],
        unlocks: ['core-002', 'inf-001'],
        metrics: '42 languages',
        x: 0,
        y: 0
      },
      {
        id: 'core-002',
        name: 'Multi-Lang Codegen',
        description: 'Code generation for Zig, Python, Rust, Verilog and 38 more',
        status: 'done',
        branch: 'core',
        prerequisites: ['core-001'],
        unlocks: ['core-003'],
        metrics: '42 targets',
        x: 1,
        y: 0
      },
      {
        id: 'core-003',
        name: 'Bytecode VM',
        description: 'Stack-based ternary virtual machine with 256 opcodes',
        status: 'done',
        branch: 'core',
        prerequisites: ['core-002'],
        unlocks: ['core-004', 'opt-t01'],
        metrics: '256 opcodes',
        x: 2,
        y: 0
      },
      {
        id: 'core-004',
        name: 'JIT Compilation',
        description: 'Just-in-time compilation for native performance',
        status: 'locked',
        branch: 'core',
        prerequisites: ['core-003', 'hw-001'],
        unlocks: [],
        x: 3,
        y: 0
      }
    ]
  },
  {
    id: 'inference',
    name: 'INFERENCE',
    color: '#FFD700',
    icon: '🧠',
    nodes: [
      {
        id: 'inf-001',
        name: 'GGUF Parser',
        description: 'Parse GGUF model files with quantization metadata',
        status: 'done',
        branch: 'inference',
        prerequisites: ['core-001'],
        unlocks: ['inf-002'],
        metrics: 'All quants',
        x: 0,
        y: 1
      },
      {
        id: 'inf-002',
        name: 'Transformer',
        description: 'Full transformer architecture with attention layers',
        status: 'done',
        branch: 'inference',
        prerequisites: ['inf-001'],
        unlocks: ['inf-003', 'opt-t02'],
        metrics: '32 layers',
        x: 1,
        y: 1
      },
      {
        id: 'inf-003',
        name: 'KV Cache',
        description: 'Key-Value cache for efficient autoregressive generation',
        status: 'done',
        branch: 'inference',
        prerequisites: ['inf-002'],
        unlocks: ['inf-004', 'opt-t03'],
        metrics: '16x speedup',
        x: 2,
        y: 1
      },
      {
        id: 'inf-004',
        name: 'Batch Processing',
        description: 'Parallel batch inference for multiple sequences',
        status: 'done',
        branch: 'inference',
        prerequisites: ['inf-003'],
        unlocks: ['dep-003', 'agent-001'],
        metrics: '8x throughput',
        x: 3,
        y: 1
      }
    ]
  },
  {
    id: 'optimization',
    name: 'OPTIMIZATION',
    color: '#FF6B6B',
    icon: '⚡',
    nodes: [
      {
        id: 'opt-t01',
        name: 'Ternary Quantization',
        description: 'BitNet b1.58 ternary weight quantization {-1, 0, +1}',
        status: 'done',
        branch: 'optimization',
        prerequisites: ['core-003'],
        unlocks: ['opt-t02'],
        metrics: '20x compression',
        x: 0,
        y: 2
      },
      {
        id: 'opt-t02',
        name: 'Ternary MatMul',
        description: 'Optimized matrix multiplication for ternary weights',
        status: 'done',
        branch: 'optimization',
        prerequisites: ['opt-t01', 'inf-002'],
        unlocks: ['opt-t03'],
        metrics: '10x speedup',
        x: 1,
        y: 2
      },
      {
        id: 'opt-t03',
        name: 'Ternary KV Cache',
        description: 'Compressed KV cache using ternary representation',
        status: 'done',
        branch: 'optimization',
        prerequisites: ['opt-t02', 'inf-003'],
        unlocks: ['opt-pc01'],
        metrics: '16x memory',
        x: 2,
        y: 2
      },
      {
        id: 'opt-pc01',
        name: 'Prefix Caching',
        description: 'Reuse computed prefixes across requests',
        status: 'in_progress',
        progress: 90,
        branch: 'optimization',
        prerequisites: ['opt-t03'],
        unlocks: ['hw-001'],
        x: 3,
        y: 2
      }
    ]
  },
  {
    id: 'deployment',
    name: 'DEPLOYMENT',
    color: '#4ECDC4',
    icon: '🚀',
    nodes: [
      {
        id: 'dep-001',
        name: 'Docker',
        description: 'Containerized deployment with optimized images',
        status: 'done',
        branch: 'deployment',
        prerequisites: [],
        unlocks: ['dep-002'],
        metrics: '< 500MB',
        x: 0,
        y: 3
      },
      {
        id: 'dep-002',
        name: 'Fly.io',
        description: 'Edge deployment on Fly.io infrastructure',
        status: 'done',
        branch: 'deployment',
        prerequisites: ['dep-001'],
        unlocks: ['dep-003'],
        metrics: '34 regions',
        x: 1,
        y: 3
      },
      {
        id: 'dep-003',
        name: 'Auto-Scaling',
        description: 'Automatic scaling based on request load',
        status: 'done',
        branch: 'deployment',
        prerequisites: ['dep-002', 'inf-004'],
        unlocks: ['dep-004'],
        metrics: '0→100 pods',
        x: 2,
        y: 3
      },
      {
        id: 'dep-004',
        name: 'Multi-Region',
        description: 'Global deployment with region-aware routing',
        status: 'done',
        branch: 'deployment',
        prerequisites: ['dep-003'],
        unlocks: ['dist-001'],
        metrics: '< 50ms latency',
        x: 3,
        y: 3
      }
    ]
  },
  {
    id: 'hardware',
    name: 'HARDWARE',
    color: '#9B59B6',
    icon: '🔧',
    nodes: [
      {
        id: 'hw-001',
        name: 'CUDA Backend',
        description: 'Native CUDA kernels for NVIDIA GPUs',
        status: 'in_progress',
        progress: 60,
        branch: 'hardware',
        prerequisites: ['opt-pc01'],
        unlocks: ['hw-002', 'core-004'],
        metrics: '+100x speed',
        x: 0,
        y: 4
      },
      {
        id: 'hw-002',
        name: 'Metal Backend',
        description: 'Apple Metal shaders for M-series chips',
        status: 'locked',
        branch: 'hardware',
        prerequisites: ['hw-001'],
        unlocks: ['hw-003'],
        metrics: '+80x speed',
        x: 1,
        y: 4
      },
      {
        id: 'hw-003',
        name: 'FPGA Synthesis',
        description: 'Verilog generation for FPGA deployment',
        status: 'locked',
        branch: 'hardware',
        prerequisites: ['hw-002'],
        unlocks: ['hw-004'],
        metrics: '1000x efficiency',
        x: 2,
        y: 4
      },
      {
        id: 'hw-004',
        name: 'ASIC Design',
        description: 'Custom ternary chip design for maximum efficiency',
        status: 'locked',
        branch: 'hardware',
        prerequisites: ['hw-003'],
        unlocks: [],
        metrics: '10000x efficiency',
        x: 3,
        y: 4
      }
    ]
  },
  {
    id: 'agents',
    name: 'AGENTS',
    color: '#FF1493',
    icon: '🤖',
    nodes: [
      {
        id: 'agent-001',
        name: 'IGLA Core',
        description: 'Instruction-based Generative Learning Architecture',
        status: 'done',
        branch: 'agents',
        prerequisites: ['inf-004'],
        unlocks: ['agent-002', 'agent-003'],
        metrics: 'v1.0 stable',
        x: 0,
        y: 5
      },
      {
        id: 'agent-002',
        name: 'Tool Use Engine',
        description: 'Local function calling and tool integration',
        status: 'done',
        branch: 'agents',
        prerequisites: ['agent-001'],
        unlocks: ['agent-004'],
        metrics: '50+ tools',
        x: 1,
        y: 5
      },
      {
        id: 'agent-003',
        name: 'Long Context',
        description: 'Unlimited history with adaptive context windows',
        status: 'done',
        branch: 'agents',
        prerequisites: ['agent-001'],
        unlocks: ['agent-004'],
        metrics: '∞ tokens',
        x: 2,
        y: 5
      },
      {
        id: 'agent-004',
        name: 'Multi-Agent',
        description: 'Coordinator + Specialist agent orchestration',
        status: 'in_progress',
        progress: 75,
        branch: 'agents',
        prerequisites: ['agent-002', 'agent-003'],
        unlocks: [],
        metrics: '8 specialists',
        x: 3,
        y: 5
      }
    ]
  },
  {
    id: 'knowledge',
    name: 'KNOWLEDGE',
    color: '#00CED1',
    icon: '📚',
    nodes: [
      {
        id: 'know-001',
        name: 'VSA Core',
        description: 'Vector Symbolic Architecture with bind/bundle ops',
        status: 'done',
        branch: 'knowledge',
        prerequisites: [],
        unlocks: ['know-002'],
        metrics: '10K dims',
        x: 0,
        y: 6
      },
      {
        id: 'know-002',
        name: 'Knowledge Graph',
        description: 'Triple-based semantic networks with VSA encoding',
        status: 'done',
        branch: 'knowledge',
        prerequisites: ['know-001'],
        unlocks: ['know-003'],
        metrics: '1M triples',
        x: 1,
        y: 6
      },
      {
        id: 'know-003',
        name: 'Semantic Search',
        description: 'Cosine similarity search over hypervectors',
        status: 'done',
        branch: 'knowledge',
        prerequisites: ['know-002'],
        unlocks: ['know-004'],
        metrics: '<1ms query',
        x: 2,
        y: 6
      },
      {
        id: 'know-004',
        name: 'RAG Engine',
        description: 'Retrieval Augmented Generation with VSA',
        status: 'in_progress',
        progress: 80,
        branch: 'knowledge',
        prerequisites: ['know-003'],
        unlocks: [],
        metrics: '95% accuracy',
        x: 3,
        y: 6
      }
    ]
  },
  {
    id: 'distributed',
    name: 'DISTRIBUTED',
    color: '#FFA500',
    icon: '🌐',
    nodes: [
      {
        id: 'dist-001',
        name: 'Node Network',
        description: 'Decentralized node discovery and routing',
        status: 'done',
        branch: 'distributed',
        prerequisites: ['dep-004'],
        unlocks: ['dist-002'],
        metrics: '1000+ nodes',
        x: 0,
        y: 7
      },
      {
        id: 'dist-002',
        name: 'TVC Sharding',
        description: 'Ternary Vector Computing distributed shards',
        status: 'in_progress',
        progress: 65,
        branch: 'distributed',
        prerequisites: ['dist-001'],
        unlocks: ['dist-003'],
        metrics: '256 shards',
        x: 1,
        y: 7
      },
      {
        id: 'dist-003',
        name: 'DePIN Network',
        description: 'Decentralized Physical Infrastructure with TRI rewards',
        status: 'locked',
        branch: 'distributed',
        prerequisites: ['dist-002'],
        unlocks: ['dist-004'],
        metrics: '$TRI mining',
        x: 2,
        y: 7
      },
      {
        id: 'dist-004',
        name: 'Global Consensus',
        description: 'Byzantine fault-tolerant consensus for ternary state',
        status: 'locked',
        branch: 'distributed',
        prerequisites: ['dist-003'],
        unlocks: [],
        metrics: '10K TPS',
        x: 3,
        y: 7
      }
    ]
  }
];

// Helper functions
export function getAllNodes(): TechNode[] {
  return techBranches.flatMap(b => b.nodes);
}

export function getNodeById(id: string): TechNode | undefined {
  return getAllNodes().find(n => n.id === id);
}

export function getCompletionStats() {
  const all = getAllNodes();
  const done = all.filter(n => n.status === 'done').length;
  const inProgress = all.filter(n => n.status === 'in_progress').length;
  const locked = all.filter(n => n.status === 'locked').length;

  return {
    total: all.length,
    done,
    inProgress,
    locked,
    percentage: Math.round((done / all.length) * 100)
  };
}

export function getBranchStats(branchId: string) {
  const branch = techBranches.find(b => b.id === branchId);
  if (!branch) return null;

  const done = branch.nodes.filter(n => n.status === 'done').length;
  return {
    total: branch.nodes.length,
    done,
    percentage: Math.round((done / branch.nodes.length) * 100)
  };
}

// Connection data for SVG lines
export interface Connection {
  from: string;
  to: string;
  status: 'active' | 'locked';
}

export function getConnections(): Connection[] {
  const connections: Connection[] = [];
  const allNodes = getAllNodes();

  allNodes.forEach(node => {
    node.unlocks.forEach(unlockId => {
      const targetNode = getNodeById(unlockId);
      const status = node.status === 'done' ? 'active' : 'locked';
      if (targetNode) {
        connections.push({ from: node.id, to: unlockId, status });
      }
    });
  });

  return connections;
}
