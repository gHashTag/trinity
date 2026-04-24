# T-JEPA Next Experiments

This document describes planned experiments for T-JEPA (Ternary Joint Embedding Predictive Architecture) based on findings from J-000.

## J-001: T-JEPA 50K Steps

**Status:** Planned

**Goal:** Run T-JEPA with the same configuration as J-000 but for 50K steps instead of 5K.

**Configuration:**
- JEPA objective only
- TinyStories dataset
- LAMB optimizer, LR 1e-3
- Batch size: 66
- Context window: 27
- Warmup: 500 steps

**Expected outcomes:**
- Converged MSE below 0.30
- Stable representation variance
- Better understanding of long-term training dynamics

**Reference:** J-000 achieved MSE 0.302 at step 3965 in 179 seconds.

## H-001: Hybrid 100K Steps

**Status:** Planned

**Goal:** Run hybrid training (JEPA + NTP) for 100K steps and compare PPL with R5=2.96 baseline.

**Configuration:**
- Stage 1: JEPA 50K steps
- Stage 2: NTP 50K steps (resume from JEPA checkpoint)
- TinyStories dataset
- LAMB optimizer, LR 1e-3
- Batch size: 66
- Context window: 27

**Expected outcomes:**
- PPL competitive with pure NTP baseline
- Better sample efficiency due to JEPA pre-training
- Understanding of hybrid objective balance

## ctx=81: Square Attention Theorem

**Status:** Planned

**Goal:** Test T-JEPA with context length 81 (3^4) to validate the Square Attention Theorem prediction.

**Context:** 81 = 3^4 is a natural power-of-3 dimension in the Trinity architecture (following the sequence 3, 9, 27, 81, 243...).

**Configuration:**
- JEPA objective
- Context window: 81 (vs 27 in J-000)
- Adjusted batch size for memory constraints
- Same optimizer and learning rate

**Expected outcomes:**
- Validate scaling laws for ternary models
- Understanding of attention patterns at larger contexts
- Potential for better long-range dependencies

## Related Documentation

- [Parameters: ./parameters.md](./parameters.md) - Training configuration details
- [J-000 Results: ./experiments.md](./experiments.md) - Baseline experimental data
- [Daily Report: ../../../lab/papers/2026-03-15-hslm-tjepa.md](../../../lab/papers/2026-03-15-hslm-tjepa.md) - Implementation details and original next steps
