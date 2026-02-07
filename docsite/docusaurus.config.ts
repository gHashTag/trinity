import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';

const config: Config = {
  title: 'Trinity',
  tagline: 'Ternary Computing Framework with VSA, BitNet & VIBEE',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  // GitHub Pages deployment
  url: 'https://gHashTag.github.io',
  baseUrl: '/trinity/docs/',
  organizationName: 'gHashTag',
  projectName: 'trinity',
  deploymentBranch: 'gh-pages',
  trailingSlash: false,

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  // KaTeX stylesheet for mathematical rendering
  stylesheets: [
    {
      href: 'https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/katex.min.css',
      type: 'text/css',
      integrity: 'sha384-Xi8rHCmBmhbuyyhbI88391ZKP2dmfnOl4rT9ZfRI7mLTdk1wblIUnrIq35nqwEvC',
      crossorigin: 'anonymous',
    },
  ],

  themes: ['@docusaurus/theme-live-codeblock'],

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/gHashTag/trinity/tree/main/docsite/',
          remarkPlugins: [remarkMath],
          rehypePlugins: [rehypeKatex],
          routeBasePath: '/', // Docs at root of /trinity/docs/
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/trinity-social-card.png',
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: false,
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Trinity',
      logo: {
        alt: 'Trinity Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          href: 'https://github.com/gHashTag/trinity',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {label: 'Getting Started', to: '/getting-started/quickstart'},
            {label: 'API Reference', to: '/api/'},
            {label: 'Troubleshooting', to: '/troubleshooting'},
          ],
        },
        {
          title: 'Community',
          items: [
            {label: 'GitHub', href: 'https://github.com/gHashTag/trinity'},
            {label: 'Issues', href: 'https://github.com/gHashTag/trinity/issues'},
          ],
        },
        {
          title: 'More',
          items: [
            {label: 'Contributing', to: '/contributing'},
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Trinity Project. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'yaml', 'json'],
    },
    liveCodeBlock: {
      playgroundPosition: 'bottom',
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
