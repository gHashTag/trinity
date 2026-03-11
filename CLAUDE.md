# CLAUDE.md

## Project

Trinity — Pure Zig autonomous AI agent swarm. 0 TypeScript, 0 Python, 0 bash dependencies.
Repository: https://github.com/gHashTag/trinity

## Binaries

5 binaries from one `build.zig` (Zig 0.15.x, std only, zero external deps):

| Binary | Build | Purpose |
|--------|-------|---------|
| `trinity-mcp` | `zig build` | MCP server, 47+ tools, Oracle watchdog |
| `ralph-agent` | `zig build` | Sleep-wake daemon, picks GitHub issues |
| `ralph-hook` | `zig build` | Hook events → Telegram notifications |
| `tri-bot` | `zig build tri-bot` | Telegram bot, SSE streaming to Anthropic API |
| `tri-api` | `zig build tri-api` | Standalone agentic loop (2,555 LOC, 11 files) |

## Commands

```bash
zig build              # All 5 binaries (only direct zig call allowed)
tri test               # Run tests
tri issue list         # See task queue
tri git status         # Working tree status
tri git commit "feat(scope): msg"  # Commit (zig fmt auto, format enforced)
tri faculty            # Agent status dashboard
tri notify "msg"       # Telegram notification
```

## Key Paths

| Path | What |
|------|------|
| `src/tri-api/` | Claude Code replacement (11 files, 2,555 LOC) |
| `src/vsa.zig` | Core VSA: bind, unbind, bundle, similarity |
| `src/vm.zig` | Ternary VM (stack-based bytecode) |
| `tools/mcp/trinity_mcp/` | MCP server + bot + agent |
| `specs/` | .tri specifications (source of truth for codegen) |
| `.ralph/` | Agent state, identity, memory, handover |
| `fpga/openxc7-synth/` | FPGA bitstreams and Verilog |

## Code Style

- Zig 0.15, `std` only, zero external dependencies
- Tests in same file (`test "description" { ... }`)
- Error handling: return error sets, never panic
- Memory: explicit allocators, no hidden allocations
- `zig fmt` before every commit
- Never edit generated files in `trinity/output/` or `generated/`

## Golden Rule

Every action in Trinity goes through the `tri` CLI. No exceptions.

```
❌ git status        → ✅ tri git status
❌ gh issue list     → ✅ tri issue list
❌ curl telegram     → ✅ tri notify "msg"
❌ zig build test    → ✅ tri test
❌ pgrep ralph-agent → ✅ tri agent list
```

Agents know ONE word: **`tri`**. Everything else is inside the binary.
New feature? → New `tri` command. No direct tool calls.

This gives: **safety** (tri git push blocks main), **audit** (every command logged), **testability** (test tri CLI, not 6 separate agents).

## Workflow

1. Issue on GitHub → branch `feat/issue-{N}`
2. Implement (spec first if .tri, then code)
3. `zig fmt src/ && zig build && zig build test`
4. Commit: `feat(scope): description (#N)`
5. Push, create PR with `Closes #N`
6. CI passes → merge

## Trinity Protocol v2 — GitHub = Thought Graph

EVERY agent step MUST be recorded in GitHub. No GitHub OK → NO next step.

### Step comment format:
```
{emoji} **Agent: {name}** | timestamp
📋 **Step**: {N}/{total} — {description}
🔄 **Status**: THINKING | ACTING | DONE | FAILED
**Thought**: why this step
**Action**: what was done
**Result**: what happened
**Next**: what comes next
```

### Rules:
1. Every task → create sub-issues (RESEARCH, PLAN, IMPLEMENT, TEST, VERIFY)
2. Every thought → comment on sub-issue
3. Every action → comment on sub-issue
4. `tri issue comment` must return exit 0 before next step
5. Close sub-issue → comment on parent with summary
6. All sub-issues closed → close parent issue
7. Never do >1 action without a comment
8. Never close issue with <2 comments
9. Every commit references issue (#N)

### Labels:
- `status:done` / `status:in-progress` / `status:queued` — workflow state
- `agent:ralph` / `agent:mu` / `agent:scholar` / `agent:swarm` / `agent:linter` / `agent:oracle` — owner

### Project Board:
- Board: TRINITY (project #6)
- Columns: Backlog → In Progress → In Review → Ready → Done
- Every issue MUST be on the board with correct column

## Architecture

### tri-api (Claude Code replacement)

```
src/tri-api/
  main.zig           — CLI + interactive TUI + agentic loop
  tui.zig            — ANSI colored terminal (tri> prompt)
  tool_executor.zig  — Built-in tools (read/write/bash/grep) + MCP routing
  tool_protocol.zig  — Anthropic Messages API JSON parse/build
  mcp_client.zig     — MCP stdio client (JSON-RPC 2.0)
  context.zig        — Token counting, auto-compaction at 80% of 180K
  permissions.zig    — deny > allow rule engine
  checkpoint.zig     — Git stash before writes
  session_store.zig  — Persistent sessions (~/.tri-api/sessions/)
  claude_md.zig      — CLAUDE.md hierarchy → system prompt
  memory.zig         — Persistent learnings (~/.tri-api/MEMORY.md)
```

### VSA Operations (src/vsa.zig)

```zig
bind(a, b)          // Associate two vectors
unbind(bound, key)  // Retrieve from binding
bundle2(a, b)       // Majority vote (2 vectors)
bundle3(a, b, c)    // Majority vote (3 vectors)
cosineSimilarity()  // Similarity [-1, 1]
permute(v, count)   // Cyclic permutation
```

### Mathematical Foundation

Ternary {-1, 0, +1}: 1.58 bits/trit, 20x memory savings vs float32, add-only compute.
Trinity Identity: `phi^2 + 1/phi^2 = 3` where phi = (1 + sqrt(5)) / 2.

## MCP Servers

| Server | Tools | Config |
|--------|-------|--------|
| **trinity** | 47+ (codegen, math, git, sacred) | `.mcp.json` |
| **needle** | 6 (structural_replace, search, quality_gates) | `.mcp.json` |
| **zig-docs** | 4 (builtins, std lib search) | `.mcp.json` |
| **railway** | deploy, logs, env vars, domains | `.mcp.json` |

## Skills

| Command | Purpose |
|---------|---------|
| `/fpga-synth` | FPGA synthesis pipeline |
| `/vsa-verify` | VSA math proof verification |
| `/vibee-gen` | Generate Zig/Verilog from .tri |
| `/trinity-test` | Run test suites |
| `/implement-issue` | Read issue → branch → implement → PR |
| `/review-code` | Review changes, find bugs |

## Hooks

- **Stop** → macOS notification + ralph-hook → Telegram
- **PreToolUse** (Write/Edit) → Block editing `trinity/output/`, `generated/`
- **PostToolUse** (.zig) → Auto `zig fmt`
- **PostToolUse** (Bash/Edit/Write) → ralph-hook → Telegram

## Telegram Bot

```
FORBIDDEN: InlineKeyboardMarkup
ONLY: ReplyKeyboardMarkup
```

## VIBEE Codegen

```bash
zig build vibee -- gen specs/tri/feature.tri  # Generate Zig
zig build vibee -- gen specs/tri/fpga.tri     # Generate Verilog
```

Never manually edit generated output. Edit the .tri spec, regenerate, test.

## Deploy (GitHub Pages)

ALWAYS deploy website + docs together, never separately.
Website: `gHashTag.github.io/trinity/` | Docs: `gHashTag.github.io/trinity/docs/`

Build docs: `cd docs && npm run build` (NOT `docsite/` — moved to `docs/`)
