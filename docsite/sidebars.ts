import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Getting Started',
      items: [
        'getting-started/quickstart',
        'getting-started/tutorial',
        'getting-started/installation',
        'getting-started/development-setup',
      ],
    },
    {
      type: 'category',
      label: 'Concepts',
      items: [
        'concepts/index',
        'concepts/balanced-ternary',
        'concepts/trinity-identity',
        'concepts/glossary',
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
      label: 'Benchmarks',
      items: [
        'benchmarks/index',
        'benchmarks/gpu-inference',
        'benchmarks/jit-performance',
        'benchmarks/memory-efficiency',
        'benchmarks/competitor-comparison',
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
      label: 'API Reference',
      items: [
        'api/index',
        'api/vsa',
        'api/vm',
        'api/hybrid',
        'api/firebird',
        'api/vibee',
        'api/plugin',
        'api/sequence-hdc',
        'api/jit',
        'api/sparse',
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
      label: 'Mathematical Foundations',
      items: [
        'math-foundations/index',
        'math-foundations/formulas',
        'math-foundations/proofs',
      ],
    },
    {
      type: 'category',
      label: 'Research',
      items: [
        'research/index',
        'research/bitnet-report',
        'research/trinity-node-ffi',
      ],
    },
    'faq',
    'troubleshooting',
    'contributing',
  ],
};

export default sidebars;
