# Loss Oscillation Analysis: Local W7 Run

## Observation

Local W7 run (AdamW 3e-4 sacred) showed persistent oscillations:
- Loss range: 5.5 - 6.7 across 100K steps
- No convergence trend after 40K
- Best: loss 5.581 (PPL 265) at step 40K
- Worst: loss 6.703 (PPL 815) at step 80K

## Pattern

Step 40K: loss 5.581 (local minimum)
Step 60K: loss 6.499 (spike)
Step 80K: loss 6.703 (spike)
Step 100K: loss 5.792 (partial recovery)

## Root Cause

Not grad clip failure (clip=1.0 was active). The issue is:
1. AdamW with low LR (3e-4) lacks momentum for ternary landscape
2. Sacred schedule resets cause periodic destabilization
3. Batch size 64 creates noisy gradients without LAMB compensation

## Resolution

Use golden config (LAMB 1e-3 cosine) — achieves PPL 2.96 vs PPL 265.
