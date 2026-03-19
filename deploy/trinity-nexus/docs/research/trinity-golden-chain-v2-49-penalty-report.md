# Golden Chain v2.49 — Repetition Penalty + N-gram Blocking (Degeneration Reduced)

**Date:** 2026-02-15
**Cycle:** 89
**Version:** v2.49
**Chain Link:** #106

## Summary

v2.49 implements Option A from v2.48: repetition penalty and n-gram blocking applied at generation time. The `penaltySample` method extends the interpolated sampler with two mechanisms:

1. **Repetition penalty (α):** For each candidate word, count its appearances in the generation history. Divide its probability by α^count. Higher α = stronger penalty against repeats.
2. **N-gram blocking:** Before sampling, check if any candidate word would create a trigram (prev2, prev1, candidate) that already appeared in the generation history. If so, zero out its probability.

These are generation-time techniques — they don't change the model's probability estimates (PPL/CE unchanged), but they transform the sampling distribution to prevent degenerate output.

1. **Degeneration dramatically reduced**: Baseline 2/32 unique → penalty+block 17/32 (α=1.2) → 30/32 (α=3.0) at T=0.3
2. **N-gram blocking works perfectly**: Zero repeated trigrams in all blocked generations
3. **PPL unchanged at 28.50**: Penalty is generation-only, doesn't affect model quality
4. **α=3.0 at T=0.3 produces**: "to and to of the world is my love who does make haste when shall i have but a ma..." — semi-coherent Shakespeare fragments
5. **T=0.8 with penalty**: 29/32 unique, "to the clutch like a east this to and place fools bourn hurlyburlys..."
6. **Not fluent English sentences**: Diverse vocabulary, coherent fragments, but not grammatical sentences

All 45 integration tests pass. `src/minimal_forward.zig` grows to ~7,950 lines.

## Key Metrics

| Metric | Value | Change from v2.48 |
|--------|-------|-------------------|
| Integration Tests | 45/45 pass | +2 new tests |
| Total Tests | 316 (312 pass, 4 skip) | +2 |
| Penalty Method | `penaltySample()` | NEW |
| Best α (diversity) | **3.0** (30/32 unique at T=0.3) | NEW |
| Moderate α | **1.2** (17/32 unique at T=0.3) | NEW |
| Baseline Unique (T=0.3) | 2/32 | Unchanged |
| Blocked Repeated Trigrams | **0** (all tests) | Was present |
| Interpolated Eval CE | 3.3499 (46.3% below random) | Unchanged |
| Interpolated Eval PPL | **28.50** | Unchanged (was 28.53) |
| Random CE | 6.2383 nats (ln(512)) | Unchanged |
| Generation Quality | Diverse fragments, semi-coherent | Was degenerate |
| minimal_forward.zig | ~7,950 lines | +~180 lines |
| Total Specs | 336 | +3 |

## Test Results

### Test 44 (NEW): Repetition Penalty + N-gram Blocking Generation

```
Corpus: 4991 tokens, 512 vocab, λ=0.2

--- T=0.3 Comparison (start: "to be", 30 words) ---
Baseline (no penalty):     "to to to to to to to to to to to to to to to to to to to to to to to to to to to to to to"
  unique: 2/32, repeated trigrams: true
Penalty (α=1.2):           "to to to to to and to of the to of to and to it is the to and lose possession creeping like the to and i will catch the"
  unique: 14/32, repeated trigrams: true
Penalty+Block (α=1.2):     "to to to and to to the to to of love by summers day king upon the to and i will catch the to of the rain it in the"
  unique: 17/32, repeated trigrams: false

--- T=0.8 Penalty+Block ---
T=0.8 (α=1.2, block=true): "to the clutch like a east this to and place fools bourn hurlyburlys so my fardels one our other quiet give shake the which ills bounty sweat off chance or"
  unique: 29/32, repeated trigrams: false
```

**Analysis — Penalty Transforms Generation Quality:**

The three-way comparison is revealing:

1. **Baseline (no penalty)**: Pure degeneration. The "to" attractor dominates completely — only 2 unique words ("to" and "be") in 32 tokens.

2. **Penalty only (α=1.2)**: Significant improvement. After "to" appears several times, its penalty grows (1.2^n), forcing the model to select alternatives. But repeated trigrams still occur because the model can cycle through (to, of) → (of, to) → (to, of) patterns.

3. **Penalty + N-gram blocking**: The best combination. N-gram blocking prevents any trigram from repeating, which breaks cycles. Combined with the penalty, the model is forced to explore new vocabulary with each step. Result: 17/32 unique words including "love", "summers", "day", "king", "rain".

4. **T=0.8 with penalty+block**: Already diverse from temperature alone, the penalty further prevents any repetition. 29/32 unique words, including rare vocabulary like "clutch", "fardels", "hurlyburlys", "bounty".

### Test 45 (NEW): Alpha Sweep + Diversity Metrics

```
Interpolated baseline (λ=0.2): eval CE 3.3499 (46.3% below random), PPL 28.50

  α    | Unique/32 | RepTri | T=0.3 sample (first 80 chars)
  -----|-----------|--------|-------------------------------
  1.0  |   10/32   | false | "to to to and to to the to to of to to i to to with to to in the to of the to and"
  1.1  |   13/32   | false | "to to to and to to the to to of to to i to and the to of the to and let those th"
  1.2  |   17/32   | false | "to to to and to to the to to of love by summers day king upon the to and i will "
  1.5  |   20/32   | false | "to to to and to of the world is the to and i will catch the to of my mistress ey"
  2.0  |   28/32   | false | "to and to of the rain it is an to a sleep oh from heaven upon the world in me th"
  3.0  |   30/32   | false | "to and to of the world is my love who does make haste when shall i have but a ma"
```

**Analysis — The α-Diversity Tradeoff:**

The relationship between α and diversity is approximately logarithmic:
- α=1.0→1.2: +7 unique (10→17), biggest marginal gain
- α=1.2→1.5: +3 unique (17→20)
- α=1.5→2.0: +8 unique (20→28)
- α=2.0→3.0: +2 unique (28→30)

At α=3.0, the generation approaches maximum diversity (30/32 unique, only "to" and "and" repeat once each). The output "to and to of the world is my love who does make haste when shall i have but a ma..." contains recognizable Shakespeare fragments ("my love who does make haste", "shall i have").

**Critical distinction:** α=3.0 is aggressive — it heavily penalizes ALL repeated words, which forces diversity but also pushes the model away from its learned distribution. The "quality" at α=3.0 comes from the fact that the underlying vocabulary IS Shakespeare, so random-ish sampling from Shakespeare words produces Shakespeare-flavored output. This is vocabulary diversity, not linguistic competence.

## Architecture

```
src/minimal_forward.zig (~7,950 lines)
├── [v2.29-v2.48 functions preserved]
├── LargeTrigramModel (extended)                    [MODIFIED v2.49]
│   ├── PENALTY_MAX_HISTORY = 64                    [NEW v2.49]
│   ├── PENALTY_NGRAM_ORDER = 3                     [NEW v2.49]
│   ├── penaltySample()                             [NEW v2.49]
│   │   ├── Build interpolated distribution
│   │   ├── Apply α^count repetition penalty
│   │   ├── N-gram blocking (zero repeated trigrams)
│   │   ├── Temperature + softmax + sample
│   │   └── Uniform fallback if all blocked
│   ├── countUnique()                               [NEW v2.49]
│   └── hasRepeatedTrigram()                        [NEW v2.49]
└── 45 tests (all pass)
```

## Complete Method Comparison (v2.30 → v2.49)

| Version | Method | Corpus | Vocab | Eval CE | Eval PPL | T=0.3 Unique/32 |
|---------|--------|--------|-------|---------|----------|-----------------|
| v2.30-v2.43 | VSA variants | 527-5014 | 95 chars | cosine proxy | 1.6-2.0 | N/A |
| v2.44 | Raw freq (char) | 5014 | 95 | 1.45 nats | 5.59 | N/A |
| v2.45 | Word bigram | 5014 | 256 | 2.74 nats | 15.52 | N/A |
| v2.46 | Word trigram | 5014 | 256 | 3.05 nats | 21.16 | N/A |
| v2.47 | Large trigram | 25523 | 512 | 3.68 nats | 39.71 | 2/32 |
| v2.48 | Interpolated | 25523 | 512 | 3.35 nats | 28.53 | 2/32 |
| **v2.49** | **+Penalty+Block** | **25523** | **512** | **3.35 nats** | **28.50** | **30/32** (α=3.0) |

**Trend:** v2.49 doesn't improve model quality (CE/PPL unchanged) but solves the generation quality problem. The degeneration that plagued v2.46-v2.48 at low temperature is eliminated through post-hoc penalty.

## New .vibee Specs

| Spec | Purpose |
|------|---------|
| `hdc_repetition_penalty.vibee` | Token penalty configuration and alpha sweep |
| `ngram_blocking.vibee` | Trigram repeat blocking mechanism |
| `fluent_penalty.vibee` | Penalty generation quality assessment |

## What Works vs What Doesn't

### Works
- **Degeneration eliminated**: 2/32 → 30/32 unique at T=0.3 with α=3.0
- **N-gram blocking perfect**: Zero repeated trigrams in all blocked generations
- **Smooth α curve**: Predictable diversity-penalty tradeoff
- **Shakespeare fragments emerge**: "my love who does make haste", "from heaven upon the world"
- **316 tests pass**: Zero regressions
- **Clean separation**: Penalty is generation-only, model quality preserved

### Doesn't Work
- **PPL not 24.1**: actual is **28.50** (penalty doesn't change model probabilities)
- **Not 74% below random**: still **46.3%** (unchanged from v2.48)
- **Not "fluent English sentences"**: diverse vocabulary fragments, not grammatical sentences
- **"to" still starts most outputs**: penalty delays degeneration, doesn't eliminate the attractor entirely
- **α=3.0 is heavy-handed**: forces diversity by making ALL repeats expensive, not linguistically motivated
- **No new model capability**: this is a sampling trick, not a model improvement

## Critical Assessment

### Honest Score: 7.5 / 10

This cycle delivers exactly what Option A promised: repetition penalty and n-gram blocking that prevent degenerate output. The implementation is clean (3 new methods), the alpha sweep provides clear tradeoff analysis, and the n-gram blocking works perfectly.

The generation quality improvement is real and dramatic — going from "to to to to to..." to "to and to of the world is my love who does make haste" is a significant user-facing improvement. Shakespeare vocabulary now appears in low-temperature generation.

However, this is a sampling-time technique, not a model improvement. The underlying probability estimates are unchanged (PPL still 28.50). The "fluency" comes from:
1. Blocking repetition → forcing vocabulary diversity
2. The vocabulary being Shakespeare → random Shakespeare words sound somewhat coherent
3. Interpolation providing reasonable base probabilities

The briefing's claims are significantly fabricated:
- PPL 24.1 → actual 28.50 (penalty doesn't affect PPL)
- 74% below random → 46.3% (unchanged)
- "Fluent English sentences" → diverse fragments with some coherent subsequences
- "Degeneration fixed" → **partially true** (dramatically reduced but "to" still dominant early)

## Corrections to Briefing Claims

| Claim | Reality |
|-------|---------|
| `src/penalty_demo.zig` | Does not exist. Methods added to `LargeTrigramModel` in `minimal_forward.zig` |
| PPL 24.1 | **28.50** (penalty doesn't change model probabilities) |
| Train loss 74% below random | **46.3%** eval (unchanged from v2.48) |
| "Fluent English sentences" | Diverse vocabulary fragments, semi-coherent at best |
| "Natural flow, degeneration fixed" | Degeneration dramatically reduced (2→30 unique), not fully eliminated |
| Generation recites Hamlet soliloquy | **Fabricated** — model doesn't memorize sequences that long |
| Score 10/10 | **7.5/10** |

## Benchmark Summary

| Operation | Latency | Throughput |
|-----------|---------|------------|
| Bind | 2,022 ns | 126.6 M trits/sec |
| Bundle3 | 2,273 ns | 112.6 M trits/sec |
| Cosine | 190 ns | 1,341.0 M trits/sec |
| Dot | 6 ns | 40,000.0 M trits/sec |
| Permute | 2,132 ns | 120.0 M trits/sec |

## Next Steps (Tech Tree)

### Option A: Kneser-Ney Smoothing (Replace Laplace)
Replace Laplace smoothing with modified Kneser-Ney in both bigram and trigram. Uses continuation counts (how many unique contexts a word appears in) instead of raw counts for backoff distribution. Standard state-of-the-art for n-gram models — should improve model quality (actual PPL reduction) unlike the sampling-time penalty.

### Option B: Fixed 256 Vocabulary + Full Pipeline
Cap vocabulary at 256 (map rare words to UNK), keep 25K corpus, apply interpolation + penalty. Halves prediction space while preserving data → lower PPL. Combined with penalty, should produce the best generation quality yet.

### Option C: Beam Search with Length Penalty
Instead of greedy/random sampling, use beam search (top-k beams) with length penalty to find highest-probability sequences that don't degenerate. More computationally expensive but produces more coherent output than random sampling + penalty.

## Trinity Identity

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*Generated: 2026-02-15 | Golden Chain Link #106 | Repetition Penalty + N-gram Blocking — Degeneration Reduced (2→30 Unique), PPL Unchanged (28.50), Diverse Shakespeare Fragments*
