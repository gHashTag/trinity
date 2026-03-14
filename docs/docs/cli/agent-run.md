# Agent Run

Flagship chimera: full autonomous issue cycle in one command.

## Usage

```bash
tri agent run <issue-number>
```

## 8-Step Sequence

| Step | Command | Description |
|------|---------|-------------|
| 1 | `issue view` | Fetch issue title and body |
| 2 | `experience recall` | Check for related past episodes |
| 3 | `spec create` | Create .tri spec from issue |
| 4 | `gen` | Generate Zig code from spec |
| 5 | `verify` | Run tests |
| 6 | `verdict` | Toxic verdict check |
| 7 | `experience save` | Record episode with results |
| 8 | `git commit` | Commit with issue reference |

## Behavior

- Each step calls existing handler functions directly (no subprocess)
- Failures at steps 3-6 save episode with `verdict=FAIL`
- Success saves with `verdict=PASS` and learnings
- Non-fatal steps (experience recall) continue on failure
- Summary shows step-by-step results with OK/FAIL

## Example

```bash
tri agent run 42
# 🤖 AGENT RUN — Issue #42
# [1/8] Issue view... OK
# [2/8] Experience recall... OK
# [3/8] Spec create... OK
# ...
# Result: PASS
```
