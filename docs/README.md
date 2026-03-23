# Trinity Documentation

This directory contains the Docusaurus documentation site for Trinity.

## Quick Start

```bash
cd docs
yarn install
yarn start
```

Visit http://localhost:3000 to view the documentation locally.

## Build

```bash
yarn build
```

Static files are generated in `build/`.

## Deploy to GitHub Pages

**IMPORTANT:** Website and docs share ONE gh-pages branch. ALWAYS deploy BOTH together.

See `/Users/playra/.claude/projects/-Users-playra-trinity-w1/memory/MEMORY.md` for the deployment protocol.

```bash
# From docs/ directory
USE_SSH=true yarn deploy
```

## Configuration

- **Config:** `docusaurus.config.ts`
- **Sidebars:** `sidebars.ts`
- **baseUrl:** `/trinity/docs/` (NEVER change - breaks all asset paths)
- **routeBasePath:** `/` (Docs at root of /trinity/docs/)

## Documentation Structure

```
docs/
├── docs/                    # Actual documentation content
│   ├── intro.md             # Introduction
│   ├── getting-started/     # Quick start guides
│   ├── api/                 # API reference
│   ├── architecture/        # System architecture
│   ├── benchmarks/          # Performance benchmarks
│   ├── research/            # Research papers and reports
│   ├── depin/               # DePIN network documentation
│   ├── development/         # Development workflow
│   ├── fpga/                # FPGA documentation
│   └── internal/            # Internal documentation
├── src/                     # Docusaurus source files
├── static/                  # Static assets
├── sidebars.ts              # Sidebar navigation
└── docusaurus.config.ts     # Site configuration
```

## Key Documentation Files

| File | Purpose |
|------|---------|
| `brain-architecture.md` | Brain module architecture |
| `SOUL.md` | Agent mission template |
| `BRAIN_ARCHITECTURE.md` | Complete brain architecture overview |
| `TRINITY_TAMAGOTCHI_*.md` | Queen daemon growth stages |
| `docs/concepts/phi-distance-formats.md` (+ native-f16, positioning) | Format/stack analysis (Docusaurus **Explanations**); no duplicate copies at `docs/` root |

## Adding New Documentation

1. Create `.md` file in appropriate `docs/docs/` subdirectory
2. Add entry to `sidebars.ts` in correct category
3. Test locally with `yarn start`
4. Build with `yarn build`
5. Deploy following the shared deployment protocol

## Mathematical Rendering

Documentation supports KaTeX for mathematical formulas.

```markdown
Inline: $E = mc^2$

Block:
$$
\phi^2 + \frac{1}{\phi^2} = 3
$$
```

## Mermaid Diagrams

Documentation supports Mermaid diagrams.

\`\`\`mermaid
graph TD
    A[Start] --> B[End]
\`\`\`

## Resources

- [Docusaurus Documentation](https://docusaurus.io/)
- [KaTeX Documentation](https://katex.org/)
- [Mermaid Documentation](https://mermaid-js.github.io/)
