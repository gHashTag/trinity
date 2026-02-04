import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Getting Started',
      items: [
        'getting-started/quickstart',
        'getting-started/installation',
        'getting-started/development-setup',
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
      ],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/overview',
      ],
    },
    'troubleshooting',
    'contributing',
  ],
};

export default sidebars;
