---
sidebar_position: 19
sidebar_label: Cloud
---

# tri cloud — Cloud Orchestration

Native Railway integration and Cloud Dev agent orchestration. Manages services, deployments, SSH sessions, and agent containers.

## Subcommands

### Infrastructure

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri cloud status` | — | Show Railway services + SSH server status |
| `tri cloud logs [service]` | `[service-name]` | Get deployment logs via GraphQL |
| `tri cloud vars [service]` | `[service-name]` or `set K=V [id]` | List or set environment variables |
| `tri cloud deploy [service]` | `[service-id]` | Trigger redeployment |
| `tri cloud redeploy` | — | Manual redeploy |
| `tri cloud restart [service]` | `[service-id]` | Restart service |
| `tri cloud delete-service <id>` | `<service-id>` | Delete Railway service (DESTRUCTIVE) |

### SSH & Remote

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri cloud exec <command>` | `<command string>` | Run command via SSH |
| `tri cloud pull` | — | Pull latest code on Railway server |
| `tri cloud ssh-status` | — | Quick SSH server status (tmux, git, oracle) |
| `tri cloud tmux` | — | Tmux session control |

### Agent Containers

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri cloud spawn <N>` | `<issue-number> [--account N]` | Spawn agent container for GitHub issue |
| `tri cloud spawn-all` | — | Spawn agents for all `agent:spawn` labeled issues |
| `tri cloud kill <N>` | `<issue-number>` | Kill agent container |
| `tri cloud agents` | — | List active agents (max 10) |
| `tri cloud cleanup` | — | Remove finished containers |
| `tri cloud sync` | — | Reconcile Railway state with local |
| `tri cloud history <N>` | `<issue-number>` | Event timeline for issue |

### Diagnostics & Metrics

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri cloud api-check` | — | Test API key + model routing |
| `tri cloud diagnose` | — | Diagnose Railway issues |
| `tri cloud metrics` | — | Aggregate fitness metrics |
| `tri cloud monitor` | — | Live monitoring dashboard |
| `tri cloud metal` | — | Metal infrastructure status |

### Delegation

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri cloud farm` | — | Delegates to `tri farm` |
| `tri cloud train` | — | Training-specific commands |
| `tri cloud train-batch` | — | Batch training operations |
| `tri cloud bridge` | — | Bridge protocol commands |
| `tri cloud issue-create` | — | Create GitHub issue |

## Examples

```bash
tri cloud status                   # Full service dashboard
tri cloud spawn 42                 # Spawn agent for issue #42
tri cloud agents                   # List active agent containers
tri cloud logs hslm-train          # Get training logs
tri cloud vars set LR=1e-4 abc123  # Set env var on service
tri cloud api-check                # Verify API connectivity
tri cloud cleanup                  # Remove finished containers
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `RAILWAY_TOKEN` | Yes | Railway API token |
| `AGENT_GH_TOKEN` | For agents | GitHub PAT for agent operations |

## Handler

**File:** `src/tri/tri_cloud.zig`
