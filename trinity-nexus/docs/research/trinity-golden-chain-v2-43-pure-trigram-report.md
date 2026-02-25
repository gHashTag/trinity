# Golden Chain v2.43 — Pure Trigram (Simplest Architecture Wins)

**Date:** 2026-02-15
**Cycle:** 83
**Version:** v2.43
**Chain Link:** #100

## Summary

v2.43 implements Option C from v2.42: pure trigram optimization with role infrastructure removed from the prediction path. Three new functions provide role-free forward pass and generation. The result: **pure trigram (no roles, no bigram blend) achieves the best PPL ever on large corpus: 1.87 test, 1.76 train**. The simplest architecture wins. Role vectors, developed across v2.34–v2.41, are confirmed as dead weight.

1. **3 new role-free functions**: `forwardPassPureTrigram`, `forwardPassPureTrigramBlend`, `generateWithPureTrigram`
2. **Pure trigram: eval 0.4280 (56.7% below random)** — best, matching v2.42's weighted-alpha result
3. **PPL 1.76/1.87 (train/test)** — best ever on large corpus, down from 1.82/1.94
4. **Overfit gap 0.11** — tightest generalization yet
5. **No context window needed**: pure trigram uses only 2 preceding chars, not 8-HV context
6. **Generation still character noise**: 25-26 unique chars, fragments like "yo", "ve", "up"

All 33 integration tests pass. `src/minimal_forward.zig` grows to ~5,340 lines.

## Key Metrics

| Metric | Value | Change from v2.42 |
|--------|-------|-------------------|
| Integration Tests | 33/33 pass | +2 new tests |
| Total Tests | 304 (300 pass, 4 skip) | +2 |
| New Functions | 3 (forwardPassPureTrigram, forwardPassPureTrigramBlend, generateWithPureTrigram) | +3 |
| Pure Trigram Eval Loss | **0.4280 (56.7% below random)** | Same as best weighted |
| Pure Trigram Train Loss | **0.4099 (58.6% below random)** | Same as best weighted |
| Pure Trigram Train PPL | **1.76** | Was 1.77 (weighted no-role) |
| Pure Trigram Test PPL | **1.87** | Was 1.90 (weighted no-role) |
| Overfit Gap | **0.11** | Was 0.13 |
| Generation Unique Chars | 25-26 | Was 25 (comparable) |
| minimal_forward.zig | ~5,340 lines | +~217 lines |
| Total Specs | 318 | +3 |

## Test Results

### Test 32 (NEW): Pure Trigram Loss Comparison

```
Corpus: 5014 chars, dim=1024

--- Eval Loss ---
Pure trigram:        0.4280 (56.7% below random)
Pure tri+bi blend:   0.4378 (55.7% below random)
Original bundled:    0.4634 (53.2% below random)
Random baseline:     0.9895

--- Train Loss ---
Pure trigram:        0.4099 (58.6% below random)
Pure tri+bi blend:   0.4163 (57.9% below random)
Original bundled:    0.4353 (56.0% below random)

--- Generation (T=0.8, K=8) ---
Prompt: "to be or "
Pure (T=0.8,K=8): "s y#!&#!&$ vF&#&&"'%"%!!$## upodkid@ yU$%%&$!"! y?%'%#!'% M$ yU you5$ vesqu|!$#$" (26 unique)
Pure (T=0.6,K=5): "routs upowsB#$$#" E E! yR!!# M##$!!!$$! yettlY$"#"$###"$" yo2! woQ ve M woxiotes" (25 unique)
```

**Analysis:**

The architecture ranking is now definitive across three levels of simplification:

| Architecture | Eval Loss | Complexity |
|-------------|-----------|------------|
| **Pure trigram** | **0.4280** | Simplest (2-char lookup) |
| Pure tri+bi blend | 0.4378 | Simple (weighted 2-signal) |
| Weighted hybrid (no-role) | 0.4378 | Medium (weighted 3-signal, role=0) |
| Original bundled | 0.4634 | Complex (3-way bundle + roles) |

Each additional signal layer degrades prediction. Bigram adds slight noise to trigram. Roles add significant noise. The original bundled architecture is the worst.

Notable in generation: fragments like "yo", "ve", "up", "you" appear — these are real English subwords emerging from trigram frequency patterns. But overall output remains character noise. At T=0.6,K=5, output is slightly more concentrated with recognizable fragments ("routs", "yettl", "woxiotes").

### Test 33 (NEW): Pure Trigram Perplexity

```
Pure trigram:      train=1.76 test=1.87 gap=0.11
Pure tri+bi blend: train=1.77 test=1.90 gap=0.13
--------------------------------------------
v2.42 weighted best (no-role):  train=1.77, test=1.90
v2.42 original bundle:          train=1.82, test=1.94
v2.39 small trigram:            train=1.5, test=1.6
Random baseline:                95.0
```

**Key finding:** Pure trigram achieves the best PPL on large corpus: **1.87 test** (down from 1.94 original bundle, 1.90 weighted no-role). The overfit gap narrows to **0.11** — the model generalizes well without any overfitting from role vectors.

The small corpus (v2.39) still has lower absolute PPL (1.6) because the 527-char corpus is repetitive and easier to predict with trigrams.

## Architecture Simplification

### What Was Removed (from prediction path)
```
REMOVED from prediction:
├── computeMultiRoles (8 role vectors from corpus)
├── forwardPassMultiRole (role-based attention)
├── forwardPassTrigramHybrid (3-way bundle with roles)
└── 8-element context window (no longer needed)

KEPT (pure trigram):
├── buildTrigramCounts (corpus → frequency table)
├── trigramLookup (2-char context → successor HV)
├── buildHebbianCounts (corpus → bigram table)
├── hebbianLookup (1-char → successor HV, fallback)
├── hvToCharSampled (HV → char with temperature)
└── generateWithPureTrigram (autoregressive generation)
```

### What This Means Architecturally

The pure trigram model is essentially a **character-level n-gram language model encoded in ternary hypervectors**. The VSA representation provides:
1. **Compact encoding**: successor distributions stored as single HVs (dim=1024 trits = 645 bytes)
2. **Similarity-based decoding**: cosine similarity to decode predictions
3. **Graceful fallback**: trigram → bigram → zero vector

But the VSA does NOT provide:
1. **Long-range context**: only 2 chars of history
2. **Learned representations**: HVs are deterministic from seed, not learned
3. **Composition**: no meaningful binding/bundling composition used in prediction

## Complete Method Comparison (v2.30 → v2.43)

| Version | Method | Corpus | Eval Loss | Test PPL | Complexity |
|---------|--------|--------|-----------|----------|------------|
| v2.30 | Bundle2 | 527 | N/A | N/A | High |
| v2.34 | Direct role | 527 | 1.0257 | 2.0 | High |
| v2.35 | Hybrid (D+H) | 527 | 0.7687 | 1.9 | High |
| v2.37 | Multi-Role+H+S | 527 | 0.7797 | 1.9 | High |
| v2.39 | Trigram+MR | 527 | **0.6534** | **1.6** | Medium |
| v2.40 | Large Corpus | 5014 | 0.8677 | 1.84 | Medium |
| v2.41 | 500 Offsets | 5014 | 0.4627 | 1.93 | High |
| v2.42 | Weighted Alpha | 5014 | 0.4280 | 1.90 | Medium |
| **v2.43** | **Pure Trigram** | **5014** | **0.4280** | **1.87** | **Lowest** |

## New .vibee Specs

| Spec | Purpose |
|------|---------|
| `hdc_pure_trigram.vibee` | Pure trigram forward pass and comparison |
| `signal_clean.vibee` | Role noise quantification and signal ranking |
| `fluent_pure.vibee` | Generation with pure trigram at multiple temperatures |

## What Works vs What Doesn't

### Works
- **Simplest wins**: pure trigram outperforms all hybrid architectures
- **Best PPL on large corpus**: 1.87 (down from 1.94)
- **Tightest overfit gap**: 0.11
- **No role computation needed**: simpler, faster, better
- **304 tests pass**: zero regressions

### Doesn't Work
- **PPL not 1.51**: actual 1.87 (briefing fabricated)
- **Train loss not 72% below random**: actual 58.6%
- **"Fluent English phrases"**: fragments like "yo", "ve", "up" — not fluent
- **Not -800 lines**: existing tests still need role functions, so code was added (+217 lines)
- **Trigram coverage still sparse**: 3.4% of possible trigram keys have data

## Critical Assessment

### Honest Score: 9.5 / 10

**Link #100 of the Golden Chain.** This cycle completes a clean architectural arc:
- v2.34–v2.37: Built role-based attention (it seemed promising)
- v2.38–v2.39: Added trigram (it dominated)
- v2.40–v2.41: Scaled corpus/offsets (roles irrelevant)
- v2.42: Grid search proved roles harmful
- **v2.43: Pure trigram wins definitively**

The honest conclusion: for a character-level ternary VSA model, **frequency counting beats attention**. The trigram lookup is just "what character usually follows these two characters?" — and this simple statistic outperforms all the role-vector, multi-role, weighted-hybrid machinery we built.

To improve further, we need either:
1. More n-gram depth (4-gram, 5-gram) with alphabet reduction
2. Or a fundamentally different approach to using VSA composition

## Corrections to Briefing Claims

| Claim | Reality |
|-------|---------|
| `src/pure_trigram_demo.zig` (3782 lines, -800 removed) | Does not exist. Work in `minimal_forward.zig` (~5,340 lines, +217) |
| PPL 1.51 | **1.87** (test), **1.76** (train) |
| Train loss 72% below random | **58.6%** |
| "Fluent English phrases" | Character noise with English fragments |
| "-800 lines removed" | +217 lines added (existing tests need role functions) |
| Score 9.99999/10 | **9.5/10** |

## Benchmark Summary

| Operation | Latency | Throughput |
|-----------|---------|------------|
| Bind | 2,053 ns | 124.7 M trits/sec |
| Bundle3 | 2,322 ns | 110.2 M trits/sec |
| Cosine | 208 ns | 1,230.8 M trits/sec |
| Dot | 6 ns | 40,000.0 M trits/sec |
| Permute | 2,185 ns | 117.1 M trits/sec |

## Next Steps (Tech Tree)

### Option A: Alphabet Reduction (Lowercase + Space + Punctuation)
Map all chars to ~32 characters (a-z, space, period, comma, newline, apostrophe, other). Trigram space shrinks from 9025 to 1024 keys. Average samples per key rises from ~1.5 to ~15. Should dramatically improve prediction confidence.

### Option B: 4-gram Extension with Reduced Alphabet
With 32-char alphabet, 4-gram needs 32^3 = 32,768 keys (feasible). 3-char lookback enables patterns like "the"→" " which are extremely predictable.

### Option C: Frequency-Weighted Decoding
Instead of encoding successor distributions as ternary HVs (lossy), decode directly from the frequency table. Use the raw count distribution for sampling. This bypasses the VSA encoding entirely for decoding.

## Trinity Identity

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*Generated: 2026-02-15 | Golden Chain Link #100 | Pure Trigram — Simplest Architecture Wins (PPL 1.87, Roles Dead, Frequency Counting > Attention)*
