# Cloud Dev Architecture

## Overview

Trinity Cloud Dev turns GitHub issues into autonomous agent containers on Railway.

```
GitHub Issue (#42)
    │ label: agent:spawn
    ▼
GitHub Actions (agent-spawn.yml)
    │
    ▼
tri cloud spawn 42
    │
    ▼
cloud_orchestrator.zig
    ├── railway_api.createService("agent-42")
    ├── railway_api.connectServiceSource(AGENT_IMAGE)
    ├── railway_api.upsertVariable × 4 (ISSUE, GITHUB_TOKEN, API_KEY, WS_URL)
    └── save to .trinity/cloud_agents.json
    │
    ▼
Railway deploys Dockerfile.agent
    │
    ▼
agent-entrypoint.sh
    ├── gh auth login
    ├── git clone (depth=50)
    ├── sed SOUL.md → inject issue number
    ├── gh issue view → read task
    ├── git checkout -b feat/issue-42
    ├── timeout 3600 claude -p "solve issue #42"
    ├── git push → gh pr create
    └── report_status DONE
    │
    ▼
cloud_monitor.zig (port 8765)
    ├── POST /api/status ← heartbeats from agents
    ├── GET /api/agents  → JSON status dashboard
    └── GET /health      → OK
```

## Components

| Component | File | Purpose |
|-----------|------|---------|
| Railway API | `src/tri/railway_api.zig` | GraphQL client (create/delete/connect service) |
| Orchestrator | `src/tri/cloud_orchestrator.zig` | Spawn/kill/list lifecycle |
| CLI | `src/tri/tri_cloud.zig` | `tri cloud` commands |
| Dockerfile | `deploy/Dockerfile.agent` | Container image |
| Entrypoint | `deploy/agent-entrypoint.sh` | Agent boot sequence |
| MCP Tools | `tools/mcp/trinity_mcp/cloud_tools.zig` | 7 MCP tools |
| Monitor | `tools/mcp/trinity_mcp/cloud_monitor.zig` | HTTP status server |
| Soul | `SOUL.md` | Agent mission template |
| Auto-spawn | `.github/workflows/agent-spawn.yml` | Label → container |
| CI Image | `.github/workflows/docker-agent.yml` | Pre-build Docker image |

## Safety Guards

| Guard | Location | Purpose |
|-------|----------|---------|
| MAX_CONCURRENT=10 | orchestrator | Railway billing limit |
| Duplicate check | orchestrator | No two containers per issue |
| 1h timeout | entrypoint | Kill stuck Claude Code |
| SIGTERM handler | entrypoint | Clean shutdown on kill |
| Bearer auth | monitor | Reject fake heartbeats |
| Retry (3×) | entrypoint | Resilient git/gh operations |
| Heartbeat loop | entrypoint | 30s status pulse |

## State

- **Local**: `.trinity/cloud_agents.json` — array of `{issue, service_id, created_at}`
- **Monitor**: in-memory `AgentStatus[50]` — `{issue, status, detail, last_heartbeat}`
- **Railway**: actual service state (source of truth, synced via `tri cloud sync`)

## CLI Commands

```
tri cloud spawn <N>     — Create container for issue #N
tri cloud spawn-all     — Spawn for all agent:spawn labeled issues
tri cloud kill <N>      — Destroy container for issue #N
tri cloud agents        — List active containers (shows limit)
tri cloud sync          — Reconcile local state with Railway API
tri cloud cleanup       — Remove inactive entries
tri cloud status        — Railway infrastructure overview
```
