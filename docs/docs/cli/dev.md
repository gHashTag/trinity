---
sidebar_position: 20
sidebar_label: Dev
---

# tri dev — SWE Agent Farm

SWE agent cloud development farm. Each GitHub issue maps to one Railway service running one autonomous Claude Code agent.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri dev status` | — | Table of all dev agents with status |
| `tri dev spawn <N>` | `<issue-number>` | Spawn agent for GitHub issue |
| `tri dev kill <N>` | `<issue-number>` | Kill agent for issue |
| `tri dev recycle` | — | Reassign idle agents to new work |
| `tri dev fill` | — | Spawn agents for all `agent:dev` labeled issues |
| `tri dev metrics` | — | Aggregate fitness metrics across agents |
| `tri dev leaderboard` | — | Rank agents by fitness score |
| `tri dev evolve` | — | ASHA+PBT evolution step (hyperparameter search) |
| `tri dev scan` | — | Scan for new work items |
| `tri dev pick` | — | Pick next task from queue |

## Examples

```bash
tri dev status                     # Show all agents
tri dev spawn 123                  # Start agent on issue #123
tri dev leaderboard                # Rank agents by fitness
tri dev evolve                     # Run evolution step
tri dev fill                       # Spawn for all unassigned issues
```

## Handler

**File:** `src/tri/tri_dev.zig`
