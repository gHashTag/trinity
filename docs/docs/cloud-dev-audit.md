# Cloud Dev Audit — Competitive Analysis & Hardening

## Competitive Analysis

### 1. GitHub Codespaces
- **Architecture**: Docker container on GitHub-hosted VM, configured via `devcontainer.json`. Prebuilds run setup ahead of time.
- **Monitoring**: Usage dashboards (CPU, storage, hours). Lifecycle hooks emit telemetry.
- **Lifecycle**: Auto-stop after idle timeout (30min default). Stopped codespaces persist FS. Org retention policies for auto-deletion.
- **Better than us**: Prebuild snapshots eliminate cold-start. Deep VS Code integration. Encrypted secrets management.

### 2. Gitpod (now Ona)
- **Architecture**: Kubernetes-native. Each workspace = pod with Linux user namespace. `.gitpod.yml` defines image/tasks.
- **Monitoring**: Central management plane. Workspace status API. Self-hosted = Prometheus/Grafana.
- **Lifecycle**: Auto-stop ~30min. Hard lifetime 8h/36h. Auto-delete after 14d inactive.
- **Better than us**: True ephemeral-by-default. Prebuild + snapshot model. Self-hosted VPC option. Pivoting to "workspace = agent runtime".

### 3. SWE-agent (Princeton)
- **Architecture**: Python orchestrator + Docker container per issue. **Agent-Computer Interface (ACI)**: custom commands (`open`, `edit`, `search_dir`, `submit`). SWE-ReX for hundreds of parallel containers.
- **Monitoring**: Trajectory JSON logging (every prompt/response). Cost tracking per run.
- **Lifecycle**: Container created at start, destroyed on `submit` or cost limit. Sentinel kills containers >2h.
- **Better than us**: ACI abstraction (higher-level commands vs raw bash) improves success rates dramatically. SWE-bench evaluation framework. `mini-swe-agent` = 100 LOC, 74%+ on SWE-bench.

### 4. OpenHands (ex-OpenDevin)
- **Architecture**: Three layers: Agent abstraction → Event stream (immutable, append-only) → Sandboxed Docker runtime.
- **Monitoring**: Event stream IS the monitoring system. Deterministic replay. 32K+ stars, 188+ contributors.
- **Lifecycle**: Container per session, destroyed on close. Reset via re-initialize event.
- **Better than us**: **Event stream is the standout feature** — immutable audit trail enables replay, debugging. Agent-agnostic runtime. MCP integration built-in.

### 5. Factory.ai / Drafter (Droids)
- **Architecture**: Specialized Droids — Code, Knowledge, Reliability. Deep context engineering (file relationships, project history, dependency graphs).
- **Monitoring**: Enterprise dashboard. Full traceability ticket→code→PR.
- **Lifecycle**: SaaS managed. Task-scoped: activate on ticket, produce PR, complete.
- **Better than us**: **Specialization** (separate droids per task type). Context engineering = higher quality PRs. SOC-2 enterprise grade.

### 6. Sweep.dev
- **Architecture**: GitHub bot → JetBrains plugin pivot. Issue webhooks → code generation → PR.
- **Monitoring**: GitHub PR comments as primary status channel.
- **Lifecycle**: Triggered by webhook, runs to completion, no long-lived containers.
- **Better than us**: Tight GitHub integration. Pivot to IDE plugin = agents in editor, not external bots.

### 7. Devika
- **Architecture**: Python sub-agents: Planner → Researcher → Formatter → Coder → Patcher → Reporter. Web UI (Flask + Svelte).
- **Monitoring**: Real-time UI state. Project persistence in SQLite.
- **Lifecycle**: No container isolation. Session persists until task completes.
- **Better than us**: **Explicit planning phase** before code generation. Web research integration. Sub-agent decomposition.

### 8. claude-code-hooks-multi-agent-observability (disler)
- **Architecture**: Claude Code hooks → HTTP POST → Bun server → SQLite → WebSocket → Vue dashboard. Git worktrees for isolation.
- **Monitoring**: **Swim-lane dashboard** per agent. Activity pulse chart. SQLite for history.
- **Lifecycle**: Manual (start/stop Claude Code instances). Worktree cleanup.
- **Better than us**: Purpose-built for Claude Code swarms. Git worktrees = zero overhead isolation. SQLite+WS = simple observability.

---

## Lessons for Trinity

### L1: Event Stream as Core Primitive
OpenHands' immutable event stream enables replay + debugging. Trinity should adopt JSONL event log per agent session.

### L2: Git Worktrees for Local Isolation
disler project proves worktrees give per-agent branch isolation with zero container overhead. Perfect for `tri` philosophy.

### L3: `tri` CLI IS an ACI
SWE-agent's key insight: raw bash is terrible for LMs. Trinity's `tri` is already an ACI. Enforce structured JSON output.

### L4: SQLite + WebSocket Dashboard
disler shows Bun+SQLite+Vue gives real-time multi-agent observability with minimal code. Better than Telegram for debugging.

### L5: Lifecycle Timeouts Are Non-Negotiable
Every platform has auto-stop/auto-destroy. Trinity agents need: idle timeout, hard lifetime cap, cleanup on completion, orphan sentinel.

### L6: Specialize Agents
Factory's multi-Droid model outperforms general-purpose. Trinity already has Ralph/Mu/Scholar/Oracle — lean into role separation.

### L7: Prebuild Agent Environments
Codespaces/Gitpod show prebuilds eliminate cold-start. `tri agent prepare {issue}` should pre-populate context before LM starts.

### L8: Structured Trajectory Logging
SWE-agent saves every LM interaction as JSON trajectory. Trinity should log all `tri` commands + LM interactions for evaluation.

---

## Hardening Applied (P0)

| Fix | File | Status |
|-----|------|--------|
| 1h timeout for Claude Code | `agent-entrypoint.sh` | ✅ `timeout $AGENT_TIMEOUT` |
| SIGTERM handler | `agent-entrypoint.sh` | ✅ `trap cleanup TERM INT` |
| Max 10 concurrent containers | `cloud_orchestrator.zig` | ✅ `MAX_CONCURRENT_AGENTS` |
| Duplicate issue check | `cloud_orchestrator.zig` | ✅ `already_exists` status |
| Bearer auth on monitor | `cloud_monitor.zig` | ✅ `Authorization: Bearer` check |
| Heartbeat loop (30s) | `agent-entrypoint.sh` | ✅ Background process |
| Retry wrapper (3×) | `agent-entrypoint.sh` | ✅ `retry()` function |
| State reconciliation | `tri_cloud.zig` | ✅ `tri cloud sync` |
| Pre-built Docker image CI | `docker-agent.yml` | ✅ GHCR push on merge |
| Telegram alert on error | `cloud_monitor.zig` | ✅ `std.log.warn` on STUCK/ERROR |

## Backlog (P2)

- Agent self-review before PR (`zig build test` + diff check)
- Workspace caching (shared zig cache volume)
- Multi-repo support
- Dashboard UI (HTML/JS on :8765)
- Agent memory (`.ralph/memory.json` context)
- Parallel sub-agents (decompose large issues)
- JSONL event stream per session (L1)
- Git worktree mode for local agents (L2)
