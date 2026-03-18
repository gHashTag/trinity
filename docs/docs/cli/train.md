---
sidebar_position: 21
sidebar_label: Train
---

# tri train — HSLM Training Monitor

Monitor and control HSLM (Hyper-Sparse Language Model) training runs. Supports both local and Railway-hosted training.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri train status` | `[--json] [--host railway]` | Live dashboard or JSON status |
| `tri train start` | `[options] [--host railway]` | Launch training (local or remote) |
| `tri train logs` | `[--host railway]` | Tail training logs |
| `tri train loss [dir]` | `[checkpoint-dir]` | Parse checkpoint loss curve |
| `tri train diagnose [dir]` | `[checkpoint-dir]` | Auto-diagnose training anomalies |
| `tri train compare <d1> <d2>` | `<dir1> <dir2>` | Side-by-side run comparison |
| `tri train checkpoint list [dir]` | `[checkpoint-dir]` | List checkpoints with metrics |

## Options for `tri train start`

| Option | Default | Description |
|--------|---------|-------------|
| `--steps <N>` | `100000` | Total training steps |
| `--lr <value>` | `3e-4` (local), `1e-4` (railway) | Learning rate |
| `--warmup <N>` | `5000` | Warmup steps |
| `--batch <N>` | `64` | Batch size |
| `--optimizer <type>` | `adamw` | Optimizer: adamw/lamb |
| `--ste <mode>` | `none` | STE mode: none/vanilla/twn/progressive |
| `--wd <value>` | `0.1` | Weight decay |
| `--checkpoint-dir <path>` | `data/checkpoints` | Checkpoint directory |
| `--resume <path>` | — | Resume from checkpoint |
| `--data <path>` | `data/tinystories/real_tinystories.txt` | Training data file |
| `--grad-accum <N>` | `1` | Gradient accumulation steps |
| `--context <N>` | `81` | Context length |

## Examples

```bash
tri train status                   # Live training dashboard
tri train start --lr 1e-4          # Start local training
tri train start --host railway     # Start Railway training
tri train loss data/checkpoints    # Show loss curve
tri train diagnose data/checkpoints # Diagnose issues
tri train compare run1/ run2/      # Compare two runs
tri train checkpoint list          # List saved checkpoints
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `HSLM_OPTIMIZER` | Yes (remote) | Optimizer type |
| `HSLM_LR` | Yes (remote) | Learning rate |
| `HSLM_LR_SCHEDULE` | Yes (remote) | LR schedule (ALWAYS cosine) |

## Handler

**File:** `src/tri/tri_train.zig`
