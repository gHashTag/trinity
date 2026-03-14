---
sidebar_position: 23
sidebar_label: Deploy
---

# tri deploy — Railway Deployment

Deploy and manage services on Railway.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri deploy push` | — | Deploy current code to Railway |
| `tri deploy status` | — | Show deployment status |
| `tri deploy logs` | — | View deployment logs |
| `tri deploy domain` | — | Domain management |

## Examples

```bash
tri deploy push                    # Deploy to Railway
tri deploy status                  # Check deployment status
tri deploy logs                    # View logs
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `RAILWAY_TOKEN` | Yes | Railway API token |

## Handler

**File:** `src/tri/tri_commands.zig:365`
