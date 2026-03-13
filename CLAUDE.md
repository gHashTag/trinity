# CLAUDE.md

## Project

Trinity — Pure Zig autonomous AI agent swarm. 0 TypeScript, 0 Python, 0 bash dependencies.
Repository: https://github.com/gHashTag/trinity

**ABSOLUTE BAN: No .sh/.bash scripts.** All tooling, entrypoints, deploy scripts MUST be Zig binaries.
PreToolUse hook enforces this — creating .sh files is blocked. See `.claude/rules/no-shell-scripts.md`.

**MANDATORY: GitHub Issue Tracking.** Every significant action MUST be logged in a GitHub issue:
- Training farm changes → update tracker issue (#357) with status comment
- Every deploy/redeploy/fix → comment with before/after state
- Every experiment result → comment with step, loss, PPL, tok/s
- Evolution status must be visible in issue comments at all times
- Use `gh issue comment <N> --body "..."` for updates

**SAFEGUARDS — Destructive Actions Blocked:**
1. NEVER delete a running Railway service — only crashed/finished
2. NEVER use `flat` LR schedule — cosine/sacred ONLY (flat = dead by 20K steps)
3. NEVER set startCommand on training services — must be null (Dockerfile ENTRYPOINT)
4. NEVER force-push to main
5. NEVER deploy without env vars set (HSLM_OPTIMIZER, HSLM_LR, HSLM_LR_SCHEDULE minimum)
5b. ALWAYS set `builder: NIXPACKS` via `serviceInstanceUpdate` — default `RAILPACK` ignores Dockerfiles!
5c. ALWAYS set `dockerfilePath: "Dockerfile.hslm-train"` via `serviceInstanceUpdate` (env var `RAILWAY_DOCKERFILE_PATH` does NOT override service config!)
6. ALWAYS `source .env` before Railway API calls — all tokens live there
7. ALWAYS record experiment results before deleting/replacing a service
8. ALWAYS cosine schedule — zero exceptions

## Binaries

6 binaries from one `build.zig` (Zig 0.15.x, std only, zero external deps):

| Binary | Build | Purpose |
|--------|-------|---------|
| `trinity-mcp` | `zig build` | MCP server, 47+ tools, Oracle watchdog |
| `ralph-agent` | `zig build` | Sleep-wake daemon, picks GitHub issues |
| `ralph-hook` | `zig build` | Hook events → Telegram notifications |
| `tri-bot` | `zig build tri-bot` | Telegram bot, SSE streaming to Anthropic API |
| `tri-api` | `zig build tri-api` | Standalone agentic loop (2,555 LOC, 11 files) |
| `hslm-entrypoint` | `zig build` | Railway training entrypoint (replaces bash) |

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
| `/cloud` | Cloud Dev dashboard: containers, events, issues, PRs |
| `/agents` | Agent swarm observatory: pools, queue, events, PRs, ETA |

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

## Default Development Workflow

Every issue → container → agent → PR → merge → cleanup.

1. Create issue (use templates) → label `agent:spawn` auto-added
2. GitHub Actions spawns Railway container `agent-{issue-number}`
3. Agent reads issue, codes, self-reviews, tests, creates PR
4. Live status in issue comments + Telegram + JSONL events
5. PR merge → container auto-destroyed → issue auto-closed

Manual development only when "manual (no agent)" is selected in issue template.

### Commands
```bash
tri cloud spawn <N>      # Manual spawn
tri cloud kill <N>       # Destroy container
tri cloud agents         # List active (max 10)
tri cloud history <N>    # Event timeline
tri cloud cleanup        # Remove finished
tri cloud sync           # Reconcile with Railway
tri cloud spawn-all      # Spawn for all agent:spawn issues
```

## Cloud Dev (Issue-Based Container Orchestration)

Each GitHub issue = one Docker container on Railway = one Claude Code agent.

### Flow
1. Issue created with template → `agent:spawn` label auto-added
2. GitHub Actions `agent-spawn.yml` runs `tri cloud spawn <N>`
3. Railway deploys `deploy/Dockerfile.agent` (multi-stage, prebuild cached)
4. `agent-entrypoint.sh`: auth → clone → read issue → Claude Code → self-review → PR
5. Agent emits structured events (JSONL) + heartbeats every 30s
6. Live dashboard comment updated in issue + Telegram alerts
7. PR merged → `agent-cleanup.yml` runs `tri cloud kill <N>` → issue auto-closed

### Key Files
| File | Purpose |
|------|---------|
| `SOUL.md` | Agent mission template (injected into container) |
| `src/tri/cloud_orchestrator.zig` | Spawn/kill/list lifecycle |
| `deploy/Dockerfile.agent` | Container image (multi-stage prebuild) |
| `deploy/agent-entrypoint.sh` | Boot: auth → clone → solve → self-review → PR |
| `tools/mcp/trinity_mcp/cloud_monitor.zig` | HTTP monitor + JSONL persistence |
| `.github/workflows/agent-spawn.yml` | Auto-spawn on issue open/label |
| `.github/workflows/agent-cleanup.yml` | Auto-cleanup on PR merge |

### Agent Roles
- **agent:ralph** (default) — Code implementation
- **agent:scholar** — Research first, then propose solution
- **agent:mu** — Memory/learning pattern updates

### Safety
- Max 10 concurrent containers (Railway billing guard)
- 1h timeout for Claude Code (configurable via AGENT_TIMEOUT)
- Self-review before PR: build check, format, diff size, generated files
- Bearer auth on monitor POST endpoint
- Retry wrapper (3x) for git/gh operations
- Structured JSONL event logging for audit

## Deploy (GitHub Pages)

ALWAYS deploy website + docs together, never separately.
Website: `gHashTag.github.io/trinity/` | Docs: `gHashTag.github.io/trinity/docs/`

Build docs: `cd docs && npm run build` (NOT `docsite/` — moved to `docs/`)

## Supervisor Mode

Doctor system enforces pipeline-first development. `tri doctor` is the single source of truth.

### Commands
```
tri doctor              One-line health status
tri doctor init         Scan + mark + report (all-in-one)
tri doctor scan         Classify all .zig files → .doctor/scan_results.json
tri doctor mark         Add @origin/@regen markers (reverts if build fails)
tri doctor report       Health score dashboard with emoji grades
tri doctor plan         Create migration queue → .doctor/migration_queue.json
tri doctor heal         Regenerate manual files through pipeline
tri doctor enforce      Show hook setup instructions
tri doctor enforce-check  Hook binary: reads JSON stdin, outputs permit/deny JSON stdout
```

### Health Formula
```
health = 100 × (0.4 × generated_ratio + 0.3 × compliance_rate
              + 0.2 × specs_coverage + 0.1 × tests_passing)
90+ → HEALTHY | 70-89 → RECOVERING | 50-69 → INFECTED | 0-49 → CRITICAL
```

### State Directory: `.doctor/`
- `scan_results.json` — last scan
- `violations.jsonl` — blocked writes
- `migration_queue.json` — pending regen
- `mark_history.jsonl` — mark operations
