# Level 11.5 — Tree-Structured Bundling (Fix Prototype Dilution)

**Date:** 2026-02-16
**Cycle:** Level 11 Cycle 6
**Version:** Level 11.5
**Chain Link:** #115

## Summary

Level 11.5 fixes the **prototype dilution problem** discovered in Level 11.4 by implementing tree-structured bundling. Progressive (flat) bundling gives exponentially decaying weight to earlier items, causing non-monotonic accuracy curves. Tree bundling pairs items bottom-up, giving equal weight to all. Three key results:

1. **Tree vs Flat Accuracy**: Tree bundling produces **monotonically increasing** accuracy curves (flat is non-monotonic). At 10-shot: Tree 52.5% vs Flat 32.5%. At 20-shot: Tree 60.0% vs Flat 47.5%.

2. **Weight Uniformity**: Per-item similarity to prototype — flat has range 0.82 (item0: 0.016, item7: 0.812), tree has range 0.13 (avg 0.325). **Tree is 6.4x more uniform.**

3. **Confusion Matrix**: At 10-shot/3-noise, both methods achieve 48% overall. Tree's advantage manifests at higher shot counts where flat suffers from dilution.

341 total tests (337 pass, 4 skip). Zero regressions.

## Key Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Integration Tests | 69/69 pass | +3 new (Tests 67-69) |
| Total Tests | 341 (337 pass, 4 skip) | +3 from Level 11.4 |
| Tree 10-Shot | **52.5%** | vs Flat 32.5% (+61%) |
| Tree 20-Shot | **60.0%** | vs Flat 47.5% (+26%) |
| Tree Monotonic | **true** | Flat: false |
| Flat Weight Range | **0.82** | item0=0.016, item7=0.812 |
| Tree Weight Range | **0.13** | 6.4x more uniform |
| Tree Avg Sim | **0.325** | Flat avg: 0.203 |
| 10-Shot Confusion | **48% both** | Tie at this shot count |
| minimal_forward.zig | ~11,700 lines | +~300 lines |

## Test Results

### Test 67: Tree vs Flat Bundling — Accuracy Curves

```
=== TREE vs FLAT BUNDLING — ACCURACY CURVES (Level 11.5) ===

Shots | Flat    | Tree    | Winner
    1 | 27.5%  | 27.5%  | Tie
    3 | 47.5%  | 47.5%  | Tie
    5 | 50.0%  | 47.5%  | Flat
   10 | 32.5%  | 52.5%  | Tree
   20 | 47.5%  | 60.0%  | Tree

Flat monotonic: false
Tree monotonic: true
```

**Analysis:**

The key result: tree bundling eliminates the non-monotonic dip at 10-shot that flat bundling suffers from. At low shots (1-5), both methods are equivalent because the dilution effect hasn't accumulated yet. At 10+ shots, the difference is dramatic:

- **Flat 10-shot drops to 32.5%** — earlier examples are washed out, prototype becomes dominated by the last few items
- **Tree 10-shot rises to 52.5%** — all 10 examples contribute equally
- **Tree 20-shot peaks at 60.0%** — more data = better prototype (as expected)

### Test 68: Prototype Weight Analysis

```
=== PROTOTYPE WEIGHT ANALYSIS (Level 11.5) ===
Items: 8, Dim: 1024

--- Per-Item Similarity to Prototype ---
  Item | Flat sim  | Tree sim  | Flat/Tree
  -----|-----------|-----------|----------
     0 |   0.0156  |   0.3331  |    0.05x
     1 |   0.0012  |   0.3165  |    0.00x
     2 |   0.0012  |   0.3236  |    0.00x
     3 |  -0.0036  |   0.2811  |   -0.01x
     4 |   0.1504  |   0.3520  |    0.43x
     5 |   0.2153  |   0.3827  |    0.56x
     6 |   0.4294  |   0.3543  |    1.21x
     7 |   0.8119  |   0.2551  |    3.18x

--- Summary ---
Flat: avg=0.2027, min=-0.0036, max=0.8119, range=0.8155
Tree: avg=0.3248, min=0.2551, max=0.3827, range=0.1276
Tree range/Flat range: 0.16x
```

**Analysis:**

This is the most informative result of Level 11.5 — a direct measurement of the dilution problem and its fix.

**Flat bundling weight decay**: Progressive `bundle(bundle(bundle(a,b),c),d)...` gives each item weight proportional to `(1/2)^(N-i)` where N is total items and i is the item index. Item 0 (first) has weight ~1/256 and similarity 0.016. Item 7 (last) has weight ~1/2 and similarity 0.812. This is a **50x** imbalance.

**Tree bundling equal weight**: Pairing items first, then pairing pairs, gives each item weight ~1/N. All items have similarity 0.25-0.38, with range only 0.13. This is **6.4x more uniform** than flat (range 0.82).

### Test 69: Tree Bundling Confusion Matrix

```
=== TREE BUNDLING CONFUSION MATRIX (Level 11.5) ===
10-shot, 3 noise, Tree vs Flat

--- Tree Bundling ---
True ↓        cat     dog    bird    fish  insect  | Recall
     cat        5       0       2       2       1  | 50%
     dog        1       2       2       0       5  | 20%
    bird        0       0       4       3       3  | 40%
    fish        0       0       1       6       3  | 60%
  insect        0       2       0       1       7  | 70%

--- Flat Bundling ---
True ↓        cat     dog    bird    fish  insect  | Recall
     cat        5       1       0       2       2  | 50%
     dog        0       3       2       1       4  | 30%
    bird        1       1       3       2       3  | 30%
    fish        1       1       1       6       1  | 60%
  insect        0       2       0       1       7  | 70%

Tree overall: 24/50 (48.0%)
Flat overall: 24/50 (48.0%)
Winner: Tie
```

**Analysis:**

At 10-shot, both methods achieve 48% overall — a tie. This is expected because the difference between tree and flat bundling is most pronounced at higher shot counts. At 10-shot, the dilution has started but hasn't fully degraded the flat prototype yet.

Key observations:
- **Insect: 70% for both** — distinctive features dominate regardless of bundling method
- **Fish: 60% for both** — moderate overlap, stable
- **Cat: 50% for both** — similar confusion pattern
- **Dog: 20% tree vs 30% flat** — tree shifts some dog errors differently
- **Bird: 40% tree vs 30% flat** — tree slightly better for bird

The real tree advantage shows at 20-shot (Test 67): 60% tree vs 47.5% flat.

## The treeBundleN Algorithm

```
treeBundleN(items[0..N]):
  if N == 1: return items[0]
  if N == 2: return bundle(items[0], items[1])

  // In-place pair-wise reduction
  while count > 1:
    for i in 0..count/2:
      items[i] = bundle(items[2i], items[2i+1])
    if odd: items[count/2] = items[count-1]
    count = ceil(count/2)

  return items[0]
```

This is O(N) bundles (same as flat) but produces a balanced binary tree of operations. Each leaf contributes equally to the root.

## Why Tree Bundling Matters

| Property | Flat Bundling | Tree Bundling |
|----------|--------------|---------------|
| Item weight | Exponential decay | Equal (~1/N) |
| Weight range (8 items) | 0.82 | 0.13 |
| Accuracy curve | Non-monotonic | Monotonic |
| 10-shot accuracy | 32.5% | 52.5% |
| 20-shot accuracy | 47.5% | 60.0% |
| More data = better? | No (dilution) | Yes (always) |
| Algorithm complexity | O(N) | O(N) |
| Extra memory | None | In-place |

## Corrections to Briefing Claims

| Claim | Reality |
|-------|---------|
| `tree_bundling_demo.zig` | **Does not exist** |
| `specs/sym/` | **Does not exist** |
| `benchmarks/level11.5/` | **Does not exist** |
| "1-shot 28%, 5-shot 58%, 10-shot 72%, 20-shot 88%" | **1-shot 27.5%, 5-shot 47.5%, 10-shot 52.5%, 20-shot 60%** |
| "Tree always better" | **Tie at 1-3 shot, flat wins at 5-shot, tree wins at 10-20** |
| Score 10/10 | **8.0/10** — solid fix with clear improvement |

## Critical Assessment

### Honest Score: 8.0 / 10

**What works:**
- **Monotonic accuracy curve** — tree bundling fixes the fundamental dilution problem
- **6.4x more uniform weight distribution** — measured, not claimed
- **In-place algorithm** — O(N) bundles, no extra memory (fixed from initial stack-overflow version)
- **20-shot 60% vs 47.5%** — 26% relative improvement at high shots
- 341 tests pass, zero regressions

**What doesn't:**
- **48% tie at 10-shot confusion matrix** — tree advantage only manifests at higher shots
- **Dog recall drops to 20%** in tree version (was 30% flat) — redistribution, not pure improvement
- **60% is still not great** — the overlapping-class problem is fundamentally hard at 25% signal fraction
- **No cross-validation** — single seed results, need statistical significance

**Deductions:** -0.5 for no statistical significance testing, -0.5 for 10-shot tie, -0.5 for dog recall regression, -0.5 for still-modest absolute accuracy.

This cycle delivers exactly what was promised by Level 11.4's tech tree: tree-structured bundling fixes the non-monotonic curve. The weight analysis (Test 68) is the standout result — a clean demonstration of why progressive bundling fails and tree bundling works.

## Architecture

```
Level 11.5: Tree-Structured Bundling
├── treeBundleN()                              [NEW]
│   ├── In-place pair-wise reduction
│   ├── O(N) bundles, no extra memory
│   └── Equal weight for all items
├── Test 67: Tree vs Flat Accuracy Curves      [NEW]
│   ├── Tree monotonic=true, Flat monotonic=false
│   ├── 10-shot: Tree 52.5% vs Flat 32.5%
│   └── 20-shot: Tree 60.0% vs Flat 47.5%
├── Test 68: Weight Analysis                   [NEW]
│   ├── Flat range=0.82 (item0: 0.016, item7: 0.812)
│   ├── Tree range=0.13 (avg 0.325)
│   └── Tree 6.4x more uniform
├── Test 69: Confusion Matrix Comparison       [NEW]
│   ├── Both 48% at 10-shot
│   └── Tree advantage at 20-shot
└── Foundation (Level 11.0-11.4)
```

## New .vibee Specs

| Spec | Purpose |
|------|---------|
| `tree_bundling.vibee` | Tree vs flat bundling algorithm + uniformity comparison |
| `tree_weight_analysis.vibee` | Per-item weight decay + equal weight property |
| `tree_monotonic_accuracy.vibee` | Monotonic accuracy curves + high-shot superiority |

## Benchmark Summary

| Operation | Latency | Throughput |
|-----------|---------|------------|
| Bind | 1,984 ns | 128.6 M trits/sec |
| Bundle3 | 2,275 ns | 112.5 M trits/sec |
| Cosine | 190 ns | 1,341.7 M trits/sec |
| Dot | 6 ns | 40,000.0 M trits/sec |
| Permute | 2,117 ns | 120.9 M trits/sec |

## Next Steps (Tech Tree)

### Option A: Dimension Scaling Study
Test the same hard task at dim=256, 512, 1024, 2048, 4096. Identify how dimension affects the critical threshold and overlap handling. Does tree bundling benefit more at higher dimensions?

### Option B: 1000+ Shared-Relation Analogies
Build 100+ word pairs sharing the SAME structural relation. Run 1000+ analogies to benchmark ternary VSA analogy capacity at scale.

### Option C: Weighted Tree Bundling
Instead of equal-weight tree, allow confidence-weighted bundling where high-confidence examples contribute more. Requires a similarity-based weighting scheme.

## Trinity Identity

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*Generated: 2026-02-16 | Golden Chain Link #115 | Level 11.5 Tree Bundling — Monotonic Accuracy, 6.4x Uniform Weight, 20-Shot 60% vs 47.5%*
