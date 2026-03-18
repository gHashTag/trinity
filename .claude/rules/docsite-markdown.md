---
paths:
  - "docs/**/*.md"
  - "docs/**/*.mdx"
  - "docs/sidebars.ts"
---

# Docsite (Docusaurus) Rules

- baseUrl is `/trinity/docs/` — NEVER change this, it breaks all asset paths
- No `src/pages/index.tsx` — conflicts with docs `slug: /` causing duplicate routes
- After adding a doc, update `docs/sidebars.ts` with the new entry
- MDX escaping: `<Tag>` must be `\<Tag\>`, `{expr}` must be `\{expr\}` outside code blocks
- Build check: `cd docs && npm run build`
- Deploy BOTH website + docs together — never deploy one without the other
- Research reports go in `docs/docs/research/`
- Benchmark data goes in `docs/docs/benchmarks/`
