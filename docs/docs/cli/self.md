# tri self

Dogfooding self-check — Trinity CLI tests itself.

## Commands

| Command | Description |
|---------|-------------|
| `tri self test [--ci]` | Run 5 quality gates |
| `tri self health` | Doctor health report (alias) |
| `tri self benchmark` | Performance benchmark (stub) |
| `tri self help` | Show sub-commands |

## Quality Gates

| Gate | Check | Threshold |
|------|-------|-----------|
| BUILD | `zig build` | exit 0 |
| TEST | `zig build test` | exit 0 |
| FORMAT | `zig fmt --check src/` | exit 0 |
| HEALTH | doctor scan → health score | ≥ 70 |
| VERDICT | toxic verdict score | ≥ SOLID (70+) |

## CI Mode

`tri self test --ci` exits with non-zero code (number of failed gates) for CI pipeline integration.

## Example Output

```
🔬 TRI SELF TEST — Dogfooding Quality Gates
════════════════════════════════════════════

[1/5] BUILD  — zig build ... ✅ PASS (exit 0)
[2/5] TEST   — zig build test ... ✅ PASS (exit 0)
[3/5] FORMAT — zig fmt --check src/ ... ❌ FAIL (exit 1)
[4/5] HEALTH — doctor scan (threshold ≥ 70) ... ❌ FAIL (score=67/100 (INFECTED))
[5/5] VERDICT — toxic verdict (threshold ≥ SOLID) ... ❌ FAIL (score=65/100 (MEDIOCRE))

════════════════════════════════════════════
📊 RESULT: 2/5 passed, 3/5 failed
```
