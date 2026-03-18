---
sidebar_position: 25
sidebar_label: Research
---

# tri research — Scholar Agent

Web research via Perplexity API, offline error analysis, and code quality verification tools.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri research "<query>"` | `<search-query>` | Web research via Perplexity (results cached) |
| `tri research explain "<error>"` | `<error-message>` | Offline error pattern analysis |
| `tri research --cache` | — | Show all cached research answers |
| `tri research idempotency` | — | 100-cycle idempotency audit |
| `tri research idem` | — | Alias for `idempotency` |
| `tri research duplication` | — | Code duplication scan |
| `tri research dup` | — | Alias for `duplication` |
| `tri research sacred` | — | Sacred constants verification |
| `tri research constants` | — | Alias for `sacred` |

## Examples

```bash
tri research "ternary neural network training"  # Web search
tri research explain "SIGBUS at 0x104"           # Error analysis
tri research --cache                             # View cached results
tri research idempotency                         # Audit all 100 cycles
tri research duplication                         # Find duplicate code
tri research sacred                              # Verify constants
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PERPLEXITY_API_KEY` | No | Enables web research (offline analysis works without it) |

## Handler

**File:** `src/tri/tri_research.zig`
