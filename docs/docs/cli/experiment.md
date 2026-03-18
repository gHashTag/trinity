---
sidebar_position: 26
sidebar_label: Experiment
---

# tri experiment — Experiment Tracking

HSLM experiment visualization and leaderboard. Scans checkpoint directories for training metrics and generates charts, comparisons, and reports.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri experiment chart [dirs...]` | `[checkpoint-dirs...]` | ASCII PPL vs Step chart (log scale) |
| `tri experiment list [dirs...]` | `[checkpoint-dirs...]` | List experiments sorted by best PPL |
| `tri experiment compare <d1> <d2>` | `<dir1> <dir2>` | Side-by-side experiment comparison |
| `tri experiment export` | — | Generate `docs/EXPERIMENTS.md` |

## Auto-Detection

When no directories are specified, these paths are scanned automatically:
- `data/checkpoints`
- `data/checkpoints/real`
- `data/checkpoints_v3`
- `data/checkpoints_v13_lamb128`

## Examples

```bash
tri experiment chart                               # Chart all experiments
tri experiment list                                # Leaderboard by PPL
tri experiment compare data/v4r data/v7            # Compare two runs
tri experiment export                              # Generate markdown report
tri experiment chart data/checkpoints/my_run       # Chart specific run
```

## Handler

**File:** `src/tri/tri_experiment.zig`
