---
sidebar_position: 31
sidebar_label: Doctor
---

# tri doctor — Pipeline Health System

Enforces pipeline-first development. Scans, classifies, and heals the codebase to ensure generated code stays in sync with .tri specs.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri doctor` | — | One-line health status |
| `tri doctor init` | — | Scan + mark + report (all-in-one) |
| `tri doctor scan` | — | Classify all .zig files to `.doctor/scan_results.json` |
| `tri doctor mark` | — | Add `@origin`/`@regen` markers (reverts if build fails) |
| `tri doctor report` | — | Health score dashboard with emoji grades |
| `tri doctor plan` | — | Create migration queue to `.doctor/migration_queue.json` |
| `tri doctor heal` | — | Regenerate manual files through pipeline |
| `tri doctor enforce` | — | Show hook setup instructions |
| `tri doctor enforce-check` | — | Hook binary: reads JSON stdin, outputs permit/deny |

## Health Formula

```
health = 100 * (0.4 * generated_ratio + 0.3 * compliance_rate
              + 0.2 * specs_coverage + 0.1 * tests_passing)
```

| Score | Grade |
|-------|-------|
| 90+ | HEALTHY |
| 70-89 | RECOVERING |
| 50-69 | INFECTED |
| 0-49 | CRITICAL |

## State Directory

All doctor state lives in `.doctor/`:
- `scan_results.json` — last scan output
- `violations.jsonl` — blocked writes
- `migration_queue.json` — pending regeneration
- `mark_history.jsonl` — mark operations

## Examples

```bash
tri doctor                         # Quick health check
tri doctor init                    # Full scan + mark + report
tri doctor report                  # Detailed health dashboard
tri doctor heal                    # Auto-fix via pipeline
tri doctor plan                    # Show migration queue
```

## Handler

**File:** `src/tri/tri_commands.zig:1706`
