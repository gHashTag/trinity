---
sidebar_position: 24
sidebar_label: Loop
---

# tri loop — Autonomous Development Loop

Autonomous development loop following the Ralph pattern: wake, scan, decide, act, report, sleep.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri loop` | — | Run single iteration (default: `once`) |
| `tri loop once` | — | Run single iteration |
| `tri loop step` | — | Alias for `once` |
| `tri loop status` | — | Show last loop state |
| `tri loop continuous` | `[-i <seconds>]` | Run continuously (default: 5min interval) |
| `tri loop daemon` | — | Alias for `continuous` |
| `tri loop retry` | `[options]` | Build-test-retry with experience tracking |

## Options for `tri loop retry`

| Option | Default | Description |
|--------|---------|-------------|
| `--issue <N>` | — | GitHub issue number (for progress comments) |
| `--max-iter <N>` | `10` | Maximum retry iterations |
| `--task "<desc>"` | — | Task description |

## Iteration Steps

Each loop iteration performs:
1. **Build + Test** — compile and run test suite
2. **Farm collect** — gather training metrics from Railway
3. **Fitness sync** — sync SWE agent fitness scores
4. **Arena baseline** — run local benchmark

## Examples

```bash
tri loop                           # Single iteration
tri loop status                    # Check last state
tri loop continuous -i 600         # Run every 10 minutes
tri loop retry --task "fix build"  # Retry until build passes
tri loop retry --issue 42 --max-iter 5  # Retry with GitHub tracking
```

## Handler

**File:** `src/tri/tri_loop.zig`
