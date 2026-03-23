# Pipeline-First Development

The Golden Chain pipeline (`tri pipeline run "<task>"`) is the primary way to create new code.

## Flow
1. `tri pipeline run "<task>"` — creates .tri spec, generates .zig, tests, commits
2. If pipeline fails 3x — diagnose the PIPELINE or the SPEC, not the generated code
3. To modify generated code — edit the .tri spec, then re-run pipeline

## Allowed Direct Edits
- `.tri` specs (`specs/**/*.tri`)
- Pipeline infrastructure (`src/tri/pipeline_executor.zig`, `src/tri/golden_chain.zig`)
- Build system (`build.zig`)
- Core library (`src/vsa.zig`, `src/vm.zig`, `src/hybrid.zig`, `src/sdk.zig`)
- Bot code (`tools/mcp/trinity_mcp/bot/*.zig`)
- MCP server (`tools/mcp/trinity_mcp/*.zig`)
- Config files (`.json`, `.toml`, `.md`)
- HSLM training (`src/hslm/*.zig`)
- BSD verification (`src/bsd/*.zig`)

## Forbidden
- Never manually create .zig files that should come from .tri specs
- Never edit files in `generated/` or `var/trinity/output/` — they are auto-generated
- If a .tri spec exists for a module, edit the spec and regenerate

## Agent Role
Supervisor, not coder. Run pipeline, observe, fix spec if needed, re-run.
