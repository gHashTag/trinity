# Level 11.3 — Few-Shot HDC Classifier (Bundle Prototypes, No Backprop)

**Date:** 2026-02-16
**Cycle:** Level 11 Cycle 4
**Version:** Level 11.3
**Chain Link:** #113

## Summary

Level 11.3 implements a **few-shot HDC classifier** using bundle prototypes and cosine classification — no backpropagation, no gradient descent, purely algebraic. Three capabilities demonstrated:

1. **1/3/5/10-Shot Classification**: 5 classes, 4 test items each → **20/20 (100%) at all shot counts**. Even 1-shot achieves perfect classification because the class concept signal is preserved through bind+bundle.

2. **Bipolar vs Ternary Comparison**: Both achieve **100%** (tie). The classification task with clean concept vectors is equally solvable by both encodings.

3. **Interpretable Attribution**: Classification is correct (mammal predicted at sim=0.70). Direct similarity to training examples shows clear class separation (same-class avg=0.51, other-class avg=0.01). Unbind-based attribution is noisy (~-0.08) — a known VSA limitation for bundles.

335 total tests (331 pass, 4 skip). Zero regressions.

## Key Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Integration Tests | 63/63 pass | +3 new (Tests 61-63) |
| Total Tests | 335 (331 pass, 4 skip) | +3 from Level 11.2 |
| 1-Shot Accuracy | **100%** (20/20) | 5 classes |
| 3-Shot Accuracy | **100%** (20/20) | 5 classes |
| 5-Shot Accuracy | **100%** (20/20) | 5 classes |
| 10-Shot Accuracy | **100%** (20/20) | 5 classes |
| Bipolar vs Ternary | **Tie (100% both)** | Clean signals |
| Classification Margin | **0.70 vs ~0.01** | Strong separation |
| Same-Class Contribution | **avg=0.509** | Clear signal |
| Other-Class Contribution | **avg~0.01** | Near zero |
| Unbind Attribution | **-0.08** | Noisy (bundle limitation) |
| minimal_forward.zig | ~11,000 lines | +~400 lines |

## Test Results

### Test 61: Few-Shot HDC Classifier (1/3/5/10-Shot)

```
=== FEW-SHOT HDC CLASSIFIER (Level 11.3) ===
Dimension: 1024, Classes: 5, Test per class: 4

--- 1-Shot Classification ---
  Accuracy: 20/20 (100.0%)

--- 3-Shot Classification ---
  Accuracy: 20/20 (100.0%)

--- 5-Shot Classification ---
  Accuracy: 20/20 (100.0%)

--- 10-Shot Classification ---
  Accuracy: 20/20 (100.0%)

--- Accuracy Curve ---
  1-shot: 100.0%
  3-shot: 100.0%
  5-shot: 100.0%
  10-shot: 100.0%
```

**Analysis:**

The classifier achieves 100% at all shot counts. This is because each training/test example is constructed as `bundle(bind(role_class, concept), instance)`, where the concept vector uniquely identifies the class. The bind operation creates a class-specific signal that survives bundling with random instance noise. At dim=1024, the class signal (~0.5 after bundle of 2 components) is well above the noise floor (~0.03 between unrelated classes).

**Why this matters:** This is a **genuine few-shot classifier** that:
- Requires **zero training iterations** (no backprop, no SGD)
- Works with **1 example per class** (true one-shot)
- Runs in **O(N×K×D)** time (N classes, K shots, D dimension)
- Is **fully interpretable** (similarity scores explain decisions)

**Honest caveat:** The 100% accuracy is achievable because the class concepts are clean random vectors. With real-world data where class boundaries are fuzzy, accuracy would be lower. This tests the VSA *mechanism*, not a real dataset.

### Test 62: Bipolar vs Ternary Few-Shot Comparison

```
=== BIPOLAR vs TERNARY FEW-SHOT (Level 11.3) ===
Dimension: 1024, Classes: 5, Shots: 5, Test/class: 4

Bipolar 5-shot accuracy: 20/20 (100.0%)
Ternary 5-shot accuracy: 20/20 (100.0%)
Winner: Tie
```

**Analysis:**

Both bipolar and ternary achieve 100% — no advantage for either encoding on this task. The classification relies on the **bundle** operation (majority voting), which works well for both. The bipolar advantage (exact self-inverse) doesn't matter for classification since we never unbind from prototypes — we only compute cosine similarity.

### Test 63: Interpretable Attribution

```
=== INTERPRETABLE ATTRIBUTION (Level 11.3) ===
Dimension: 1024, Classes: 3, Shots: 5

--- Classification ---
  sim(query, mammal): 0.6973 ← PREDICTED
  sim(query, bird): -0.0141
  sim(query, fish): 0.0169
Correct: true

--- Attribution Analysis ---
  attribution ~ mammal_concept:  -0.0814
  attribution ~ test_instance:   0.0365
  attribution ~ role_class:      0.0056
  attribution ~ bird_concept:    0.0449 (wrong class)
  attribution ~ fish_concept:    0.0028 (wrong class)

--- Training Example Contributions ---
  mammal: avg=0.5090, max=0.5272
  bird: avg=0.0018, max=0.0239
  fish: avg=0.0068, max=0.0336
```

**Analysis:**

**Classification:** Correct (mammal at 0.70, others ~0.01). The margin is enormous — 0.70 vs 0.02 gives a 35x signal-to-noise ratio.

**Unbind-based attribution is noisy.** Unbinding a query from a bundled prototype gives near-random similarity to concepts (-0.08). This is expected: unbind(A, bundle(B1,B2,...B5)) ≠ clean recovery because the bundle is a lossy superposition. **This is a genuine limitation** — HDC classifiers are interpretable at the class level (similarity scores), but not at the feature attribution level via unbinding.

**Direct contribution analysis works.** Computing similarity of the test query against individual training examples gives clear class separation:
- Same class (mammal): avg=0.51, max=0.53
- Other classes: avg~0.01

This is the correct way to interpret HDC classifications — compare against individual training examples, not unbind from prototypes.

## How HDC Few-Shot Classification Works

```
Training Phase (per class):
  example_i = bundle(bind(role_class, concept_c), instance_i)
  prototype_c = bundle(example_1, example_2, ..., example_K)

Classification:
  predicted_class = argmax_c cosine(test_item, prototype_c)

Why it works:
  1. bind(role_class, concept_c) creates a unique class signature
  2. bundle with instance noise dilutes but doesn't destroy the signature
  3. prototype = bundle of K examples amplifies the shared class signal
  4. test items from the same class share the same class signal
  5. cosine similarity detects the shared signal
```

## Corrections to Briefing Claims

| Claim | Reality |
|-------|---------|
| `src/few_shot_classifier.zig` | **Does not exist** |
| `specs/sym/*.vibee` | **Does not exist** |
| `benchmarks/level11.3/` | **Does not exist** |
| "1-shot 96%, 5-shot 99%, 10-shot 99.8%" | **All 100%** (clean concept vectors) |
| "Bipolar shines" | **Tie** — both 100%, no advantage |
| "Interpretable attribution exact" | **Noisy** — unbind from bundle is lossy |
| Score 10/10 | **7.5/10** — works but too-easy benchmark |

## Critical Assessment

### Honest Score: 7.5 / 10

**What works:**
- **Few-shot classification works** — 100% accuracy, no backprop, pure algebra
- **Runs in one pass** — no training iterations needed
- **Interpretable at class level** — similarity scores explain decisions
- **Both bipolar and ternary work** — encoding choice doesn't matter for classification
- 335 tests pass, zero regressions

**What doesn't work:**
- **Benchmark is too easy** — clean random concept vectors are trivially separable. Real data has overlapping class boundaries, noise, and higher intrinsic dimensionality.
- **Unbind attribution is noisy** — can't extract feature-level explanations from bundled prototypes
- **No real dataset** — synthetic data doesn't prove real-world capability
- **No hard baselines** — need comparison vs. k-NN, prototypical networks, etc.
- **100% at 1-shot reveals a too-simple task** — accuracy should increase with more shots if the task is realistic

**Deductions:** -1.5 for too-easy benchmark, -0.5 for noisy attribution, -0.5 for no real data.

**To make this meaningful:** Need either (a) a harder synthetic task where classes overlap, or (b) a real dataset (e.g., encoding text/images as VSA vectors and classifying).

## Architecture

```
Level 11.3: Few-Shot HDC Classifier
├── Test 61: 1/3/5/10-Shot Accuracy                [NEW]
│   ├── 5 classes, 4 test items each
│   ├── bundle(bind(role, concept), instance) examples
│   ├── 100% at all shot counts
│   └── O(N×K×D) classification
├── Test 62: Bipolar vs Ternary Comparison          [NEW]
│   ├── Both 100% (tie)
│   └── Bundle-based classification is encoding-agnostic
├── Test 63: Interpretable Attribution              [NEW]
│   ├── Classification: correct (mammal, 0.70 vs 0.01)
│   ├── Unbind attribution: noisy (-0.08, bundle limitation)
│   └── Direct contribution: clear (0.51 vs 0.01)
└── Foundation (Level 11.0-11.2)
```

## New .vibee Specs

| Spec | Purpose |
|------|---------|
| `few_shot_classifier.vibee` | Bundle prototypes + cosine classification |
| `cosine_few_shot.vibee` | Bipolar vs ternary comparison |
| `interpretable_few_shot.vibee` | Attribution analysis |

## Benchmark Summary

| Operation | Latency | Throughput |
|-----------|---------|------------|
| Bind | 2,016 ns | 127.0 M trits/sec |
| Bundle3 | 2,459 ns | 104.1 M trits/sec |
| Cosine | 262 ns | 977.1 M trits/sec |
| Dot | 6 ns | 40,000.0 M trits/sec |
| Permute | 2,335 ns | 109.6 M trits/sec |

## Next Steps (Tech Tree)

### Option A: Hard Few-Shot Benchmark
Create a harder synthetic task where class concepts overlap (e.g., shared features between classes). Test accuracy degradation with increasing overlap. This would reveal the true capacity of the classifier.

### Option B: 1000+ Shared-Relation Analogies
Build 100+ word pairs sharing the SAME structural relation (country:capital). Run 1000+ analogies to demonstrate >99% accuracy with ternary VSA. Completes the Level 11.0 missing benchmark.

### Option C: Hybrid Bipolar/Ternary System
Automatically select bipolar for bind chains (RDF, multi-hop) and ternary for bundle operations (classification, memory). A unified system that uses the best encoding per operation.

## Trinity Identity

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*Generated: 2026-02-16 | Golden Chain Link #113 | Level 11.3 Few-Shot Classifier — 1-Shot 100%, 5-Shot 100%, Bipolar/Ternary Tie, Attribution Noisy (bundle limitation)*
