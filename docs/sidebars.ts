import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'intro',
    // ═══════════════════════════════════════════════════════════════════════════
    // DIATAXIS FRAMEWORK: Tutorials → How-to Guides → Reference → Explanation
    // ═══════════════════════════════════════════════════════════════════════════
    {
      type: 'category',
      label: 'Tutorials',
      description: 'Step-by-step learning for newcomers',
      items: [
        'tutorials/quick-start',
        'tutorials/first-project',
        'tutorials/fpga-blink',
        'tutorials/sacred-math',
        'tutorials/bitnet-inference',
        'tutorials/contributing',
      ],
    },
    {
      type: 'category',
      label: 'How-to Guides',
      description: 'Practical solutions to specific problems',
      items: [
        'getting-started/installation',
        'getting-started/development-setup',
        'guides/performance-tuning',
        'guides/security',
        'guides/testing',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      description: 'Technical specifications and API documentation',
      items: [
        {
          type: 'category',
          label: 'TRI CLI',
          items: [
            'cli/index',
            'cli/categories',
            'cli/core',
            'cli/devtools',
            'cli/analysis',
            'cli/pipeline',
            'cli/math',
            'cli/git',
            'cli/vibee-tools',
            'cli/swarm',
            'cli/demos',
            'cli/autonomous',
            'cli/audit',
            'cli/repl',
            'cli/tvc',
            'cli/constants',
            'cli/visual-guide',
            // Infrastructure
            'cli/farm',
            'cli/cloud',
            'cli/dev',
            'cli/train',
            // Operations
            'cli/notify',
            'cli/deploy',
            'cli/loop',
            'cli/job',
            // Research & Agents
            'cli/research',
            'cli/experiment',
            'cli/zenodo',
            'cli/faculty',
            'cli/experience',
            'cli/issue',
            'cli/doctor',
            'cli/fpga',
            // Chimera & DePIN
            'cli/chimera',
            'cli/agent-run',
            'cli/depin',
            'cli/all-commands',
          ],
        },
        {
          type: 'category',
          label: 'API',
          items: [
            'api/index',
            'api/vsa',
            'api/bigint',
            'api/vm',
            'api/hybrid',
            'api/sdk',
            'api/firebird',
            'api/vibee',
            'api/plugin',
            'api/sequence-hdc',
            'api/jit',
            'api/sparse',
            'api/c-api',
            'api/python-sdk',
          ],
        },
        {
          type: 'category',
          label: 'Cheatsheets',
          collapsed: true,
          items: [
            'cheatsheets/cli-commands',
            'cheatsheets/vsa-operations',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'Explanations',
      description: 'Conceptual understanding and discussions',
      items: [
        'concepts/index',
        'concepts/balanced-ternary',
        'concepts/trinity-identity',
        'concepts/glossary',
        {
          type: 'category',
          label: 'Mathematical Foundations',
          items: [
            'math-foundations/index',
            'math-foundations/formulas',
            'math-foundations/sacred-formulas',
            'math-foundations/proofs',
            'math-foundations/poincare-conjecture',
            'math-foundations/algebraic-structure',
            'math-foundations/concentration-jl',
            'math-foundations/special-functions',
            'math-foundations/number-sequences',
            'math-foundations/sacred-geometry',
            'math-foundations/quantum-information',
            'math-foundations/cosmology-constants',
            'math-foundations/holographic-quantum-gravity',
            'math-foundations/harmony-gematria',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'Architecture Decisions',
      description: 'ADR: Historical record of architectural choices',
      items: [
        'adr/template',
        'adr/vibee-compiler',
        'adr/ternary-representation',
        'adr/sacred-constants-unified',
      ],
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // END DIATAXIS FRAMEWORK
    // ═══════════════════════════════════════════════════════════════════════════
    {
      type: 'category',
      label: 'Overview',
      items: [
        'overview/introduction',
        'overview/roadmap',
        'overview/tech-tree',
      ],
    },
    {
      type: 'category',
      label: 'BitNet Integration',
      items: [
        'bitnet/index',
        'bitnet/inference',
        'bitnet/model-format',
      ],
    },
    {
      type: 'category',
      label: 'HDC Applications',
      items: [
        'hdc/index',
        'hdc/applications',
        'hdc/igla-glove-comparison',
      ],
    },
    {
      type: 'category',
      label: 'VIBEE Language',
      items: [
        'vibee/index',
        'vibee/specification',
        'vibee/examples',
        'vibee/theorems',
      ],
    },
    {
      type: 'category',
      label: 'DePIN Network',
      items: [
        'depin/index',
        'depin/quickstart',
        'depin/rewards',
        'depin/tokenomics',
        'depin/api',
        'depin/architecture',
      ],
    },
    {
      type: 'category',
      label: 'FPGA',
      collapsed: true,
      items: [
        'fpga/TECHNOLOGY_TREE_ACTION_PLAN',
        'fpga/TECHNOLOGY_TREE_EXECUTION_REPORT',
        'fpga/TECHNOLOGY_TREE_BENCHMARKS',
        'fpga/TECHNOLOGY_TREE_TOXIC_VERDICT',
        'fpga/HARDWARE_PROOF_PHASE2',
      ],
    },
    {
      type: 'category',
      label: 'Benchmarks',
      items: [
        'benchmarks/index',
        'benchmarks/tri-math-v36-performance',
        'benchmarks/gpu-inference',
        'benchmarks/jit-performance',
        'benchmarks/memory-efficiency',
        'benchmarks/competitor-comparison',
        'benchmarks/compression-comparison',
      ],
    },
    {
      type: 'category',
      label: 'Development',
      items: [
        'development/ralph',
      ],
    },
    {
      type: 'category',
      label: 'Deployment',
      items: [
        'deployment/index',
        'deployment/runpod',
        'deployment/local',
      ],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/overview',
      ],
    },
    {
      type: 'category',
      label: 'Research Archive',
      collapsed: true,
      items: [{type: 'autogenerated', dirName: 'research'}],
    },
    {
      type: 'category',
      label: 'Internal',
      collapsed: true,
      items: [{type: 'autogenerated', dirName: 'internal'}],
    },
    {
      type: 'category',
      label: 'Community',
      items: [
        'community/guidelines',
      ],
    },
    'faq',
    'troubleshooting',
    'contributing',
  ],
};

export default sidebars;
