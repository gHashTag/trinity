# Level 11.6 — 1000+ Shared-Relation Analogies Benchmark

**Date:** 2026-02-16
**Cycle:** Level 11 Cycle 7
**Version:** Level 11.6
**Chain Link:** #116

## Summary

Level 11.6 implements a **1200-query shared-relation analogies benchmark** — the classic VSA strength. Given word pairs sharing an underlying relation R (where B_i = bind(R, A_i)), extract R from exemplar pairs and apply to new queries. Three key results:

1. **Clean Analogies: 100%** at all exemplar counts (1 through 11). Bipolar bind is exact self-inverse: bind(B, A) = bind(bind(R,A), A) = R. With clean extraction, every analogy resolves perfectly.

2. **Noise Degradation Curve**: 0 noise=100%, 1=100%, 2=100%, 3=99.2%, 5=40.8%. Critical threshold at signal fraction ~25% (matching Level 11.4's finding). 1200 total queries.

3. **Multi-Step Chains: 100% at 4 hops, similarity=1.0000**. Bipolar vectors form a perfect algebraic group under componentwise multiply. Composite relations compose and decompose without any loss, regardless of chain length.

344 total tests (340 pass, 4 skip). Zero regressions.

## Key Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Integration Tests | 72/72 pass | +3 new (Tests 70-72) |
| Total Tests | 344 (340 pass, 4 skip) | +3 from Level 11.5 |
| Total Analogy Queries | **1200** | 10 relations × 12 pairs × 10 configs |
| Clean 1-Exemplar | **100.0%** | Exact self-inverse |
| Clean 11-Exemplar | **100.0%** | Tree-bundled identical R's |
| Noisy 3-Components | **99.2%** | Signal fraction 25% |
| Noisy 5-Components | **40.8%** | Signal fraction 17% |
| Multi-Step 1-Hop | **100.0%** | sim=1.0000 |
| Multi-Step 4-Hop | **100.0%** | sim=1.0000 |
| Tree R-sim (15-ex) | **0.4240** | vs flat 0.2582 |
| Flat R-sim (15-ex) | **0.2582** | 64% less signal |
| minimal_forward.zig | ~12,050 lines | +~350 lines |

## Test Results

### Test 70: 1000+ Shared-Relation Analogies Benchmark

```
=== 1000+ SHARED-RELATION ANALOGIES (Level 11.6) ===
Relations: 10, Pairs/rel: 12, Dim: 1024

--- Phase 1: Clean Analogies by Exemplar Count ---
Exemplars | Correct | Total | Accuracy
----------|---------|-------|--------
        1 |     120 |   120 | 100.0%
        3 |     120 |   120 | 100.0%
        5 |     120 |   120 | 100.0%
        9 |     120 |   120 | 100.0%
       11 |     120 |   120 | 100.0%

--- Phase 2: Noisy Analogies (1-exemplar + noise) ---
Noise | Correct | Total | Accuracy
------|---------|-------|--------
    0 |     120 |   120 | 100.0%
    1 |     120 |   120 | 100.0%
    2 |     120 |   120 | 100.0%
    3 |     119 |   120 | 99.2%
    5 |      49 |   120 | 40.8%

Per-Relation: All 10 relations at 100% (11-exemplar, clean)
Total: 1128/1200 (94.0%)
```

**Analysis:**

Phase 1 confirms the theoretical prediction: bipolar bind is a perfect self-inverse operation. Extracting `R' = bind(B, A) = bind(bind(R,A), A) = R` gives the exact relation vector. Bundling multiple copies of R via tree bundling still gives R. Result: 100% across the board.

Phase 2 is more revealing. Adding noise to the extracted relation simulates real-world imperfection. The noise degradation curve matches Level 11.4's finding:

| Signal Fraction | Accuracy | Regime |
|----------------|----------|--------|
| 100% (0 noise) | 100% | Perfect |
| 50% (1 noise) | 100% | Robust |
| 33% (2 noise) | 100% | Still robust (search space only 12) |
| **25% (3 noise)** | **99.2%** | **Threshold** |
| 17% (5 noise) | 40.8% | Degraded |

The threshold is slightly higher here (99.2% vs 45% in Level 11.4) because the search space is smaller (12 candidates vs 50) and the underlying relation is exact (vs overlapping class features).

### Test 71: Multi-Exemplar Noisy Relation — Tree vs Flat

```
=== MULTI-EXEMPLAR NOISY RELATION: TREE vs FLAT (Level 11.6) ===
Pairs: 20, Test: 5, Dim: 1024, Noise/rel: 3

Exemplars | Tree Acc | Flat Acc | Tree R-sim | Flat R-sim
----------|----------|----------|------------|----------
        1 |   100.0% |   100.0% |    0.1801 |   0.1801
        2 |   100.0% |   100.0% |    0.2169 |   0.2169
        3 |   100.0% |   100.0% |    0.2240 |   0.2240
        5 |   100.0% |   100.0% |    0.2742 |   0.2670
        7 |   100.0% |   100.0% |    0.3167 |   0.2768
       10 |   100.0% |   100.0% |    0.3415 |   0.2968
       15 |   100.0% |   100.0% |    0.4240 |   0.2582
```

**Analysis:**

Classification accuracy is 100% for both methods (search space of 20 is easy at dim=1024). But the **R-sim column** reveals the underlying signal quality difference:

- At 1-5 exemplars: tree and flat are similar (noise dominates)
- At 7+ exemplars: tree pulls ahead
- **At 15 exemplars: Tree R-sim=0.4240 vs Flat R-sim=0.2582** — tree recovers **64% more** of the true relation signal

This means that in a harder setting (larger search space, more noise), tree bundling would maintain accuracy where flat bundling fails. The R-sim measures the fundamental signal quality independent of the task difficulty.

Why flat R-sim *decreases* from 10 to 15: flat progressive bundling gives exponentially decaying weight to early exemplars. Adding more exemplars pushes early ones below the noise floor, degrading the aggregate.

### Test 72: Multi-Step Relation Chains

```
=== MULTI-STEP RELATION CHAINS (Level 11.6) ===
Total chains: 50, Max hops: 4, Dim: 1024

  Hops | Correct | Total | Accuracy | Avg Sim
  -----|---------|-------|----------|--------
     1 |      50 |    50 |   100.0% | 1.0000
     2 |      50 |    50 |   100.0% | 1.0000
     3 |      50 |    50 |   100.0% | 1.0000
     4 |      50 |    50 |   100.0% | 1.0000

Overall: 200/200 (100.0%)
```

**Analysis:**

This is the definitive result for bipolar VSA algebra: **perfect composition at arbitrary depth**.

The math: For bipolar {-1, +1} vectors under componentwise multiply:
- `bind(A, A) = [1, 1, ..., 1]` (identity vector, all +1)
- Every element is its own inverse
- `bind(bind(R1, R2), bind(R1, R2)) = identity`
- Chain: `composite = bind(R1, bind(R2, bind(R3, R4)))` composes cleanly
- Recovery: `bind(composite, start) = target` with sim=1.0000

50 chains × 4 hop counts = 200 queries, all correct. The similarity to target is exactly 1.0000 (not approximately — exactly). This is a mathematical guarantee, not an empirical finding.

## Initial Bug Fix: Random B Words

The first implementation generated random A and B words independently (no shared relation). Result: ~10% accuracy (near random for 12-choice). This is expected — without a shared relation, `bind(B_j, A_j)` produces different random vectors for each pair. Bundling random vectors gives noise.

**Fix:** Generate `B_i = bind(R, A_i)` where R is a shared relation vector. This ensures all pairs share the same underlying structure, and extraction via bind returns exactly R.

This bug is pedagogically important: it demonstrates that VSA analogies require **actual structural similarity** between pairs. Random correlation doesn't work.

## Corrections to Briefing Claims

| Claim | Reality |
|-------|---------|
| `src/analogies_benchmark_demo.zig` | **Does not exist** |
| `specs/sym/` | **Does not exist** |
| `benchmarks/level11.6/` | **Does not exist** |
| "99.7% structured, 98.2% noisy, 99.1% multi-step" | **Clean 100%, noisy 99.2%/40.8%, multi-step 100%** |
| Score 10/10 | **8.5/10** — clean analogies too easy, noise curve is real |

## Critical Assessment

### Honest Score: 8.5 / 10

**What works:**
- **1200 analogy queries** — exceeds the 1000 target
- **100% clean accuracy** — theoretically guaranteed and empirically confirmed
- **Noise curve matches Level 11.4** — 25% signal fraction threshold consistent
- **Multi-step chains: 100% at 4 hops, sim=1.0** — perfect algebraic composition
- **Tree vs Flat R-sim** reveals signal quality even when accuracy is saturated
- **Bug fix teaches real lesson** — shared relations required for analogies
- 344 tests, zero regressions

**What doesn't:**
- **Clean analogies are trivially easy** — 100% is expected from theory, not an achievement
- **Search space is small** (12-20 candidates) — real analogies search over thousands
- **Multi-step chains are exact by construction** — no degradation to study
- **No comparison to ternary** — bipolar advantage assumed but not measured here
- **Synthetic pairs** — not real word embeddings

**Deductions:** -0.5 for trivial clean task, -0.5 for small search space, -0.5 for no ternary comparison.

The noise degradation curve and the tree-vs-flat R-sim comparison are the genuinely useful results. The multi-step chain result, while beautiful mathematically, is a theorem rather than an experiment.

## Architecture

```
Level 11.6: 1000+ Shared-Relation Analogies
├── Test 70: Shared-Relation Benchmark                [NEW]
│   ├── 10 relations × 12 pairs × 10 configs = 1200 queries
│   ├── Phase 1: Clean — 100% all exemplar counts
│   ├── Phase 2: Noisy — 0=100%, 3=99.2%, 5=40.8%
│   └── All 10 relations: 100% (11-exemplar clean)
├── Test 71: Multi-Exemplar Noisy — Tree vs Flat      [NEW]
│   ├── Accuracy: 100% both (task too easy)
│   ├── R-sim: Tree 0.42 vs Flat 0.26 at 15 exemplars
│   └── Tree recovers 64% more true relation signal
├── Test 72: Multi-Step Relation Chains               [NEW]
│   ├── 50 chains × 4 hop counts = 200 queries
│   ├── 100% accuracy, sim=1.0000 all hops
│   └── Bipolar group: perfect algebraic composition
└── Foundation (Level 11.0-11.5)
```

## New .vibee Specs

| Spec | Purpose |
|------|---------|
| `shared_relation_analogies.vibee` | 1200-query benchmark + noise degradation |
| `analogy_noise_scaling.vibee` | Signal fraction threshold + search space effects |
| `multistep_chain_analogies.vibee` | Composite relations + group property proof |

## Benchmark Summary

| Operation | Latency | Throughput |
|-----------|---------|------------|
| Bind | 1,996 ns | 128.3 M trits/sec |
| Bundle3 | 2,560 ns | 100.0 M trits/sec |
| Cosine | 186 ns | 1,376.3 M trits/sec |
| Dot | 24 ns | 10,666.7 M trits/sec |
| Permute | 2,135 ns | 119.9 M trits/sec |

## Next Steps (Tech Tree)

### Option A: Dimension Scaling Study
Test analogies at dim=256, 512, 1024, 2048, 4096. Identify how dimension affects noise tolerance and search space capacity. Find the minimum dimension for reliable analogies with 1000+ candidates.

### Option B: Large Search Space Stress Test
Increase search space to 100, 500, 1000 candidates. At what point do noisy analogies fail? This measures the practical capacity of VSA analogies.

### Option C: Ternary vs Bipolar Analogy Comparison
Run the same 1200-query benchmark with ternary {-1,0,+1} vectors. Measure the cost of zero trits (non-self-inverse) on analogy accuracy and chain composition.

## Trinity Identity

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*Generated: 2026-02-16 | Golden Chain Link #116 | Level 11.6 Shared-Relation Analogies — 1200 queries, Clean 100%, Noisy 99.2%/40.8%, Multi-Step 100% sim=1.0, Tree R-sim 64% better*
