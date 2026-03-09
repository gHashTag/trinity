---
paths:
  - "docsite/**/*.md"
  - "docsite/**/*.mdx"
  - "docsite/sidebars.ts"
---

# Docsite (Docusaurus) Rules

- baseUrl is `/trinity/docs/` — NEVER change this, it breaks all asset paths
- No `src/pages/index.tsx` — conflicts with docs `slug: /` causing duplicate routes
- After adding a doc, update `docsite/sidebars.ts` with the new entry
- MDX escaping: `<Tag>` must be `\<Tag\>`, `{expr}` must be `\{expr\}` outside code blocks
- Build check: `cd docsite && npm run build`
- Deploy BOTH website + docsite together — never deploy one without the other
- Research reports go in `docsite/docs/research/`
- Benchmark data goes in `docsite/docs/benchmarks/`
