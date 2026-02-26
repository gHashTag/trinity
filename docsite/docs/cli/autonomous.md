---
sidebar_position: 11
sidebar_label: Autonomous
---

# Full Autonomous Health

Comprehensive system health report running 5 subsystem checks.

## full-autonomous

**Aliases:** `full_autonomous`, `health`

```bash
tri full-autonomous
```

Runs 5 independent health checks and produces a unified status report:

### Health Checks

| # | Check | Command | What it verifies |
|---|-------|---------|-----------------|
| 1 | Doctor | `tri doctor` | System diagnostics (8 checks: Zig compiler, build.zig, main.zig, colors, binary, specs, core tests, VM tests) |
| 2 | Tests | `tri test` | All test suites pass (VSA, VM, integration) |
| 3 | Strict | `tri strict` | VIBEE-first compliance (no manual code in protected dirs) |
| 4 | Swarm | `tri swarm` | Agent health (16 agents, CRDT sync, connectivity) |
| 5 | Marketplace | `tri marketplace` | Economy status ($TRI balance, listings, transactions) |

### Example Output

```
TRI FULL AUTONOMOUS — SYSTEM HEALTH REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [1/5] Doctor...          PASS
  [2/5] Tests...           PASS
  [3/5] Strict...          PASS
  [4/5] Swarm...           PASS
  [5/5] Marketplace...     PASS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Result: 5/5 ALL PASS

  phi^2 + 1/phi^2 = 3 = TRINITY
  System is FULLY AUTONOMOUS
```

### Exit Codes

| Result | Meaning |
|--------|---------|
| 5/5 PASS | System fully autonomous — all subsystems healthy |
| 4/5 or less | One or more subsystems need attention |

### When to Use

Run `tri full-autonomous` to:

- Verify system health after changes
- Confirm all subsystems are operational before deployment
- Check agent and economy status
- Validate VIBEE compliance across the codebase
