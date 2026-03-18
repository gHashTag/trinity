---
sidebar_position: 18
sidebar_label: Farm
---

# tri farm — Training Farm Management

Manages the Railway training farm across 3 accounts (PRIMARY, FARM-2, FARM-3). Each account can hold up to 25 training services running HSLM experiments.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri farm status` | — | Show all services across 3 accounts with status icons |
| `tri farm idle` | — | Show only finished/idle services (candidates for recycling) |
| `tri farm recycle` | `[options]` | Set training vars + redeploy all idle/crashed services |
| `tri farm fill` | `[options]` | Create NEW services to fill empty slots (up to 25/account) |
| `tri farm evolve` | — | Run evolution step (ASHA+PBT hyperparameter search) |

## Options

### `tri farm recycle`

| Option | Default | Description |
|--------|---------|-------------|
| `--lr <value>` | `3e-4` | Learning rate |
| `--batch <value>` | `128` | Batch size |
| `--ctx <value>` | `81` | Context length |
| `--optimizer <type>` | `lamb` | Optimizer: lamb/adamw/adam |
| `--warmup <value>` | `2000` | Warmup steps |
| `--wd <value>` | `0.01` | Weight decay |
| `--steps <value>` | `100000` | Total training steps |
| `--include-primary` | off | Also include PRIMARY account |

### `tri farm fill`

Same options as `recycle`, plus:

| Option | Default | Description |
|--------|---------|-------------|
| `--max <N>` | `37` | Max new services to create |
| `--dry-run` | off | Show what would be created without doing it |
| `--include-primary` | off | Also include PRIMARY account |

## Examples

```bash
tri farm status                    # Dashboard of all training services
tri farm idle                      # Find recyclable services
tri farm recycle --lr 1e-4         # Recycle idle services with new LR
tri farm fill --max 5 --dry-run    # Preview filling 5 new slots
tri farm evolve                    # Run hyperparameter evolution
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `RAILWAY_TOKEN` | Yes | PRIMARY account token |
| `RAILWAY_TOKEN_2` | Yes | FARM-2 account token |
| `RAILWAY_TOKEN_3` | Yes | FARM-3 account token |

## Handler

**File:** `src/tri/tri_farm.zig`
