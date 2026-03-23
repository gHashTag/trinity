# AGENTS.md — Trinity Agent Swarm Documentation

Trinity S³AI implements a multi-agent swarm architecture using pure Zig. Each agent has a specific role and communicates through GitHub issues, JSONL events, and the unified `tri` CLI.

## Table of Contents

- [Agent Types](#agent-types)
- [Rigid Process Framework](#rigid-process-framework)
- [Agent Lifecycle](#agent-lifecycle)
- [Communication Protocol](#communication-protocol)
- [State Management](#state-management)
- [Cloud Dev Orchestration](#cloud-dev-orchestration)
- [Local Development](#local-development)

---

## Agent Types

### Ralph Agent (`ralph-agent`)

**Role**: Sleep-wake daemon, autonomous issue resolution

**Binary**: `zig build ralph-agent`

**Purpose**:
- Polls GitHub for labeled issues
- Spawns containers for `agent:spawn` labeled issues
- Monitors active containers
- Cleans up finished tasks

**Key Files**:
- `src/ralph/ralph_agent.zig` — Main daemon logic
- `.ralph/state.json` — Agent state persistence
- `.ralph/memory/` — Agent memory and handover data

**Commands**:
```bash
tri agent list          # List all agents
tri agent status        # Show agent status
tri agent run <N>       # Run autonomous issue resolution (8-step cycle)
tri agent spawn <N>     # Spawn agent for issue N
tri agent kill <N>      # Kill agent container
```

### Mu Agent (`mu-agent`)

**Role**: Memory and learning pattern updates

**Binary**: `zig build mu-agent`

**Purpose**:
- Analyzes completed tasks
- Extracts patterns and learnings
- Updates agent memory
- Provides recommendations for similar tasks

**Key Files**:
- `src/mu/mu_agent.zig` — Memory agent logic
- `.ralph/memory/` — Persistent memory storage

### Scholar Agent (`scholar-agent`)

**Role**: Research-focused agent

**Binary**: `zig build scholar-agent`

**Purpose**:
- Scans web for relevant technical information
- Evaluates findings against project requirements
- Proposes solutions based on research
- Uses Perplexity Sonar API via MCP

**Key Files**:
- `src/scholar/scholar_agent.zig` — Research agent logic

### Oracle Agent

**Role**: Decision validator, sacred constants guardian

**Purpose**:
- Validates agent decisions against project rules
- Enforces sacred constants (φ-mathematics)
- Prevents destructive actions
- Watchdog for MCP server operations

**Key Files**:
- `tools/mcp/trinity_mcp/oracle.zig` — Oracle logic

### Swarm Agent

**Role**: Multi-agent coordination

**Purpose**:
- Orchestrates parallel agent execution
- Manages agent pools
- Load balancing across agents
- Fault tolerance and recovery

---

## Rigid Process Framework

The **Rigid Process Framework** enforces structured development workflow for all agents.

### State Machine

```
                    ┌─────────────────┐
                    │     IDLE        │
                    └────────┬────────┘
                             │ start --issue <N>
                             ▼
                    ┌─────────────────┐
                    │     ACTIVE      │◄──────────────────┐
                    └────────┬────────┘                   │
                             │ file changes               │
                             ▼                            │
                    ┌─────────────────┐                   │
                    │     DIRTY       │                   │
                    └────────┬────────┘                   │
                             │ tests pass                 │
                             ▼                            │
                    ┌─────────────────┐                   │
                    │     TESTED      │                   │
                    └────────┬────────┘                   │
                             │ commit                     │
                             ▼                            │
                    ┌─────────────────┐                   │
                    │   COMMITTED     │                   │
                    └────────┬────────┘                   │
                             │ ship                       │
                             ▼                            │
                    ┌─────────────────┐                   │
                    │    SHIPPED      │                   │
                    └─────────────────┘                   │
                                                     reset │
                                                          ▼
                    ┌─────────────────┐    unblock     ┌──────▼─────┐
                    │    BLOCKED      │◄───────────────│   ACTIVE   │
                    └─────────────────┘                 └────────────┘
```

### Dev Commands

All agents use `tri dev` commands for workflow management:

```bash
tri dev              # Show dev session status
tri dev status        # Alias for status
tri dev start --issue <N>  # Start session for issue N
tri dev test          # Run tests and mark as passed
tri dev commit "msg"  # Commit changes with issue ID
tri dev ship          # Ship changes (mark as delivered)
tri dev reset         # Reset changes back to ACTIVE state
tri dev unblock       # Clear BLOCKED state
tri dev log           # Show state history
```

### Session State

**File**: `.trinity/dev_session.json`

```json
{
  "state": "ACTIVE",
  "issue_number": 357,
  "branch": "feat/issue-357",
  "issue_title_len": 22,
  "issue_title": "Training farm evolution",
  "files_count": 3,
  "tests_passed": false,
  "commit_hash": "",
  "started_at": 1234567890,
  "last_updated": 1234567890
}
```

### State Transitions

Each transition is validated by `canTransition()`:

| From   | To         | Allowed | Condition                     |
|--------|------------|---------|-------------------------------|
| IDLE   | ACTIVE     | ✅      | Issue number provided         |
| ACTIVE | DIRTY      | ✅      | File changes detected         |
| ACTIVE | ACTIVE     | ✅      | Reset (clear changes)         |
| DIRTY  | TESTED     | ✅      | Tests pass                    |
| TESTED | COMMITTED  | ✅      | Git commit succeeds           |
| COMMITTED | SHIPPED | ✅      | PR merged / deployed          |
| Any    | BLOCKED    | ✅      | Error / blocker detected      |
| BLOCKED | IDLE      | ✅      | Explicit unblock              |

---

## Agent Lifecycle

### 1. Issue Creation

```bash
gh issue create --title "Feature: X" --body "Description..."
# Label added automatically: agent:spawn
```

### 2. Container Spawn

GitHub Actions `agent-spawn.yml` triggers:
```yaml
- run: tri cloud spawn ${{ github.event.issue.number }}
```

### 3. Agent Execution

Container runs `deploy/agent-entrypoint.sh`:
1. Authenticate with GitHub
2. Clone repository
3. Read issue details
4. Run Claude Code agent loop
5. Self-review code
6. Create PR

### 4. Status Updates

Agent posts structured comments:
```
🤖 **Agent: ralph** | 2026-03-23T12:00:00Z
📋 **Step**: 3/8 — Implement feature X
🔄 **Status**: ACTING
**Thought**: Need to add handler in dev_commands.zig
**Action**: Modified src/tri/dev_commands.zig
**Result**: Added cmdNewFeature function
**Next**: Run tests
```

### 5. PR Creation

```bash
gh pr create --title "feat: Feature X (#N)" --body "Closes #N"
```

### 6. Cleanup

PR merge triggers `agent-cleanup.yml`:
```yaml
- run: tri cloud kill ${{ github.event.pull_request.number }}
```

---

## Communication Protocol

### GitHub Issue Comments

**Format**:
```markdown
{emoji} **Agent: {name}** | timestamp
📋 **Step**: {N}/{total} — {description}
🔄 **Status**: THINKING | ACTING | DONE | FAILED
**Thought**: why this step
**Action**: what was done
**Result**: what happened
**Next**: what comes next
```

### JSONL Events

**File**: `.trinity/agent_events.jsonl`

```jsonl
{"timestamp":"2026-03-23T12:00:00Z","agent":"ralph","event":"start","issue":357}
{"timestamp":"2026-03-23T12:01:00Z","agent":"ralph","event":"step","step":1,"description":"Read issue"}
{"timestamp":"2026-03-23T12:02:00Z","agent":"ralph","event":"heartbeat","status":"active"}
```

### Telegram Notifications

**Format** (via `ralph-hook`):
```
🤖 Ralph: Started issue #357
📦 Feature: Add X
🔗 https://github.com/gHashTag/trinity/issues/357
```

---

## State Management

### Agent State Directory: `.ralph/`

```
.ralph/
├── state.json           # Current agent state
├── identity.json        # Agent identity and capabilities
├── memory/              # Persistent learnings
│   ├── patterns.jsonl   # Learned patterns
│   └── handover.json    # Handover data between sessions
└── queue/               # Task queue
    └── pending.jsonl    # Pending tasks
```

### Dev Session State: `.trinity/`

```
.trinity/
├── dev_session.json     # Current dev workflow state
├── agent_events.jsonl   # Agent event log
├── fpga/                # FPGA hardware state
│   ├── hardware_state.json
│   └── experience.json
└── memory/              # Project memory
    └── phoenix/
        └── current.jsonl
```

---

## Cloud Dev Orchestration

### Railway Container Management

Each GitHub issue = one Railway container.

**Commands**:
```bash
tri cloud spawn <N>      # Spawn container for issue N
tri cloud kill <N>       # Destroy container
tri cloud agents         # List active containers (max 10)
tri cloud history <N>    # Event timeline for issue N
tri cloud cleanup        # Remove finished containers
tri cloud sync           # Reconcile with Railway API
tri cloud spawn-all      # Spawn for all agent:spawn issues
```

### Container Image

**Dockerfile**: `deploy/Dockerfile.agent`

Multi-stage build with prebuild caching:
1. **Build stage**: Zig 0.15.x, compile all binaries
2. **Runtime stage**: Minimal image with compiled binaries
3. **Entrypoint**: `agent-entrypoint.sh` handles auth → clone → solve → PR

### Monitor Endpoint

Each container posts heartbeats to:
```
POST https://monitor.example.com/agent/{issue}/heartbeat
Authorization: Bearer {token}
Content-Type: application/json

{
  "timestamp": "2026-03-23T12:00:00Z",
  "status": "active",
  "step": 3,
  "message": "Implementing feature X"
}
```

---

## Local Development

### Running Agents Locally

**Ralph Agent**:
```bash
zig build ralph-agent
./zig-out/bin/ralph-agent
# Polls GitHub, spawns containers, monitors status
```

**Mu Agent**:
```bash
zig build mu-agent
./zig-out/bin/mu-agent --analyze
# Analyzes completed tasks, updates memory
```

**Scholar Agent**:
```bash
zig build scholar-agent
./zig-out/bin/scholar-agent --query "ternary inference"
# Researches topic, proposes solutions
```

### Testing Agent Commands

```bash
# Test Rigid Process Framework
zig build test_dev_runner
./zig-out/bin/test_dev_runner cycle

# Test cloud orchestration
tri cloud spawn 999  # Test issue
tri cloud history 999
tri cloud kill 999
```

### Debugging

**Enable verbose logging**:
```bash
export TRI_DEBUG=1
export TRI_LOG_LEVEL=debug
tri agent run 123
```

**Check agent state**:
```bash
cat .ralph/state.json | jq
cat .trinity/dev_session.json | jq
```

---

## Repository layout (filesystem)

**Goal:** keep the repo root small; agents and humans follow the same rules.

1. **Verilog (`*.v`)** — not in the repository root. Put loose RTL in **`hardware/rtl-root/`**; curated flows under **`fpga/`** (e.g. `fpga/openxc7-synth/`).
2. **Binaries** — build with **`zig build`**; run from **`zig-out/bin/`**. Do not leave `a.out`, `*.o`, or ad-hoc test binaries in root (they are ignored or removed).
3. **Scripts & one-offs** — **`scripts/`**; long-lived experiments → **`archive/`** when obsolete.
4. **JTAG / hardware config** — **`hardware/jtag/`**.
5. **Historical note:** some old root executables live in **`bin/repo-root/`**; prefer `zig-out` for anything new.

---

## Agent Labels

GitHub issue labels control agent behavior:

| Label          | Purpose                          |
|----------------|----------------------------------|
| `agent:spawn`  | Trigger container spawn          |
| `agent:ralph`  | Assign to Ralph (default)        |
| `agent:scholar`| Assign to Scholar (research)     |
| `agent:mu`     | Assign to Mu (memory)            |
| `status:done`  | Mark as completed                |
| `status:in-progress` | Mark as active           |
| `status:queued` | Mark as pending                |

---

## Safety Guards

1. **Max 10 concurrent containers** — Railway billing guard
2. **1h timeout** — Configurable via `AGENT_TIMEOUT` env var
3. **Self-review before PR** — Build check, format, diff size
4. **Bearer auth** — Monitor endpoint requires token
5. **Retry wrapper** — 3x retry for git/gh operations
6. **Structured logging** — JSONL events for audit
7. **State validation** — `canTransition()` checks before state changes

---

## Quick Reference

### Agent Status Dashboard
```bash
tri agents             # Full agent swarm dashboard
tri faculty            # Alias for agent status
```

### Cloud Dev Dashboard
```bash
tri cloud              # Cloud Dev dashboard
tri cloud agents       # Active containers
tri cloud sync         # Reconcile with Railway
```

### Issue Workflow
```bash
tri issue list         # Task queue
tri issue comment <N>  # Comment on issue
tri agent run <N>      # Autonomous issue resolution (8-step cycle)
```

### Dev Workflow
```bash
tri dev start --issue <N>  # Start session
tri dev test              # Run tests
tri dev commit "msg"      # Commit changes
tri dev ship              # Ship changes
```

---

## φ² + 1/φ² = 3 = TRINITY
