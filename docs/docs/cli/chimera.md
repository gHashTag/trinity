# Chimera Commands

Fused multi-step command sequences. One invocation = complete workflow.

Based on the MACRO paper pattern: agents auto-discover repeated sequences and synthesize composite tools.

## Commands

| Chimera | Steps | Description |
|---------|-------|-------------|
| `tri chimera farm-cycle` | 4 | status → idle → recycle → evolve |
| `tri chimera train-cycle` | 5 | status → loss → diagnose → chart → leaderboard |
| `tri chimera deploy-full` | 5 | commit → push → deploy → verify → notify |
| `tri chimera doctor-full` | 4 | scan → mark → report → heal |
| `tri chimera research-deep` | 4 | query → recall → idempotency → dedup |

## Architecture

All chimeras follow the `StepResult` pattern from `tri_loop.zig`:

- Steps execute sequentially
- Failures don't break the chain
- Results accumulated into summary
- Experience episode auto-saved at end

## Usage

```bash
tri chimera farm-cycle        # Full farm maintenance cycle
tri chimera train-cycle       # Training analytics overview
tri chimera deploy-full "feat(x): msg"  # End-to-end deploy
tri chimera doctor-full       # Full health check + heal
tri chimera research-deep "query"  # Deep research with recall
```

## Experience Tracking

Every chimera auto-saves an experience episode with:
- Task: chimera name
- Verdict: PASS (all steps OK) or PARTIAL (some failures)
- Details: step-by-step results
