---
sidebar_position: 28
sidebar_label: Job
---

# tri job — Async Job System

Run long-running commands asynchronously with status tracking, log collection, and artifact management.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri job start <command>` | `<command> [args...]` | Start async job |
| `tri job status <id>` | `<job-id>` | Check job status (pending/running/completed/failed) |
| `tri job logs <id>` | `<job-id>` | Get stdout/stderr logs |
| `tri job artifacts <id>` | `<job-id>` | Collect job output artifacts |
| `tri job cancel <id>` | `<job-id>` | Cancel running job |
| `tri job list` | — | List all jobs |

## Examples

```bash
tri job start "zig build"          # Start build job
tri job list                       # List all jobs
tri job status abc123              # Check specific job
tri job logs abc123                # Get job output
tri job artifacts abc123           # Collect outputs
tri job cancel abc123              # Cancel running job
```

## Handler

**File:** `src/tri/tri_job.zig`
