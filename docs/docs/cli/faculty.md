---
sidebar_position: 29
sidebar_label: Faculty
---

# tri faculty — Agent Faculty Board

Display the agent faculty board — a real-time dashboard showing agent health, voice analysis, and recommended next actions.

## Usage

```bash
tri faculty [options]
```

## Options

| Flag | Description |
|------|-------------|
| *(default)* | Compact faculty board |
| `full` | Full detailed board with all metrics |
| `--raw` | Raw JSON output |
| `--lang ru` | Override language (ru/en) |

## Output

The faculty board shows:
- **Agent status** — health, wake count, last activity
- **Voice analysis** — current operational state
- **Fitness score** — V metric (pure phi * r^2)
- **Delta tracking** — changes since last run (frozen/improved/regressed)
- **Three paths** — recommended next actions based on current state

## Examples

```bash
tri faculty                        # Compact board
tri faculty full                   # Full detailed view
tri faculty --raw                  # JSON for parsing
tri faculty --lang en              # English output
```

## Handler

**File:** `src/tri/faculty_board.zig`
