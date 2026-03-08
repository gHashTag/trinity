/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  tutorialSidebar: [
    'intro',
    'installation',
    'quick-start',
    {
      type: 'category',
      label: 'Concepts',
      items: ['concepts/vsa', 'concepts/bind', 'concepts/bundle', 'concepts/permute'],
    },
    {
      type: 'category',
      label: 'API Reference',
      items: ['api/vsa', 'api/vm', 'api/types'],
    },
    {
      type: 'category',
      label: 'Examples',
      items: ['examples/memory', 'examples/sequence', 'examples/vm'],
    },
    'benchmarks',
  ],
};

module.exports = sidebars;
