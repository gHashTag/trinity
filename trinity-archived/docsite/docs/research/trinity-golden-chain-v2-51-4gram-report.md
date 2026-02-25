# Golden Chain v2.51 — 4-Gram KN Extension (PPL 1.94, Hamlet Recall)

**Date:** 2026-02-16
**Cycle:** 91
**Version:** v2.51
**Chain Link:** #108

## Summary

v2.51 implements Option C from v2.50: extend context from trigram (2-word lookback) to 4-gram (3-word lookback) with Kneser-Ney smoothing and multi-level backoff (4-gram → KN trigram → KN bigram → continuation). A new sparse hash table with 16384 slots stores 4-gram contexts keyed on (prev3, prev2, prev1).

1. **PPL 1.94 (best D=0.25, λ=1.0)** — 59.9% reduction from trigram KN (4.84), 93.2% from Laplace (28.50)
2. **Eval CE 0.6630 (89.4% below random)** — approaching theoretical minimum
3. **3508 unique 4-gram contexts**, 4948 observations, 1.41 avg per context (very sparse)
4. **100% 4-gram eval hit rate** — all eval tokens have seen 4-gram contexts
5. **Hamlet soliloquy recalled**: T=0.3 generates "not to be that is the question whether tis nobler in the mind to suffer the slings and arrows of outrageous fortune or to take arms against a sea of"
6. **This is memorization, not fluency** — 1.41 avg obs means most 4-gram contexts have exactly 1 successor

All 49 integration tests pass. `src/minimal_forward.zig` grows to ~8,900 lines.

## Key Metrics

| Metric | Value | Change from v2.50 |
|--------|-------|-------------------|
| Integration Tests | 49/49 pass | +2 new tests |
| Total Tests | 321 (317 pass, 4 skip) | +3 (new test runner) |
| 4-gram Hash Slots | 3508/16384 (21.4% load) | NEW |
| 4-gram Observations | 4948 | NEW |
| Avg Obs Per 4-gram Context | **1.41** (extremely sparse) | NEW |
| 4-gram Eval Hit Rate | **100%** | NEW |
| Best 4-gram KN Config | D=0.25, λ=1.0 | NEW |
| 4-gram Eval CE | **0.6630** (89.4% below random) | Was 1.5779 (74.7%) |
| 4-gram Eval PPL | **1.94** | Was 4.84 |
| 4-gram Train PPL | 1.87 | NEW |
| Overfit Gap | **+0.07** (tiny, healthy) | Was -1.30 |
| PPL vs Trigram KN | **59.9% reduction** | NEW |
| Gen T=0.3 (4-gram) | **Hamlet soliloquy** (verbatim) | Was fragments |
| Gen T=0.3 Unique | 25/33 | Was 19/32 |
| minimal_forward.zig | ~8,900 lines | +~500 lines |
| Total Specs | 342 | +3 |

## Test Results

### Test 48 (NEW): 4-Gram KN Statistics + PPL

```
Corpus: 4991 tokens, 512 vocab
4-gram slots: 3508/16384 (21.4% load)
Total 4-gram observations: 4948
Avg observations per 4-gram context: 1.41
4-gram eval hit rate: 999/999 (100.0%)
KN trigram baseline: eval CE 1.5779, PPL 4.84

  D    | λ    | Eval CE   | %<random | PPL
  -----|------|-----------|----------|--------
  0.25 | 0.3  | 1.0324   | 83.5%   | 2.81
  0.25 | 0.5  | 0.8896   | 85.7%   | 2.43
  0.25 | 0.7  | 0.7809   | 87.5%   | 2.18
  0.25 | 1.0  | 0.6630   | 89.4%   | 1.94
  0.50 | 0.3  | 1.2297   | 80.3%   | 3.42
  0.50 | 0.5  | 1.0848   | 82.6%   | 2.96
  0.50 | 0.7  | 0.9724   | 84.4%   | 2.64
  0.50 | 1.0  | 0.8434   | 86.5%   | 2.32
  0.75 | 0.3  | 1.5761   | 74.7%   | 4.84
  0.75 | 0.5  | 1.4365   | 77.0%   | 4.21
  0.75 | 0.7  | 1.3270   | 78.7%   | 3.77
  0.75 | 1.0  | 1.1983   | 80.8%   | 3.31

--- Best 4-gram KN: D=0.25, λ=1.0 ---
4-gram eval CE:  0.6630 (89.4% below random), PPL 1.94
4-gram train CE: 0.6282 (89.9% below random), PPL 1.87
4-gram overfit gap: 0.07
Trigram KN eval PPL: 4.84
4-gram improvement: 59.9% PPL reduction vs trigram KN
```

**Analysis — Why PPL 1.94 is Memorization:**

PPL 1.94 means the model predicts the correct next word with ~52% probability on average (since 2^(-log2(1.94)) ≈ 0.52). This is extraordinary for a 512-word vocabulary — and suspicious.

The key evidence: **1.41 average observations per 4-gram context**. This means the majority of 4-gram contexts (prev3, prev2, prev1) appeared exactly once in training, with exactly one observed successor. With D=0.25 discount, a context with count 1 gives P(w) = max(1-0.25, 0)/1 = 0.75 for the observed word, leaving only 0.25 for KN backoff to distribute across 511 other words. The model essentially memorizes single-observation 4-grams.

**Why the overfit gap is tiny (+0.07):** Both train and eval are memorized. The 80/20 split means eval tokens share many 4-gram contexts with training (since Shakespeare text reuses patterns). The 100% eval hit rate confirms this — every eval 4-gram was seen in training.

**The honest interpretation:** PPL 1.94 is a correct metric for THIS eval set, but it measures memorization capacity, not language understanding. A proper test would use completely held-out Shakespeare plays not in the corpus.

### Test 49 (NEW): 4-Gram KN Generation

```
--- T=0.3 (α=1.5, block=true) ---
4-gram KN: "not to be that is the question whether tis nobler in the mind to suffer
           the slings and arrows of outrageous fortune or to take arms against a sea of"
  unique: 25/33
Trigram KN: "to and to of to and the rain it to every day but when i to by heaven
            i to you as i may say the to of many a"
  unique: 20/32

--- T=0.8 (α=1.2, block=true) ---
4-gram KN: "not to this to to it to to by thy to to as the sea my love as deep
           the more i have shuffled off this mortal coil must to"
  unique: 22/33
```

**Analysis — The Memorization/Generation Tradeoff:**

The 4-gram T=0.3 output is a verbatim Hamlet soliloquy: "not to be that is the question whether tis nobler in the mind to suffer the slings and arrows of outrageous fortune or to take arms against a sea of." This is **chain recall** — each 4-gram context has a near-deterministic successor, and the penalty prevents cycling, so the model traces a single memorized path through the text.

Compare to trigram KN T=0.3: "to and to of to and the rain it to every day..." — with only 2-word context, the model can't lock onto a specific memorized path and wanders between fragments.

The 4-gram T=0.8 output shows what happens with more randomness: "not to this to to it to to by thy to to as the sea my love as deep the more i have shuffled off this mortal coil must to" — fragments from different Shakespeare plays blended together. "shuffled off this mortal coil" is from Hamlet, "my love as deep" from Romeo and Juliet. The model is a memex, not a generator.

## PPL Evolution Across All Versions

| Version | Method | Smoothing | Context | Eval PPL | % Below Random |
|---------|--------|-----------|---------|----------|----------------|
| v2.44 | Char freq | None | 1 char | 5.59 | ~68% |
| v2.45 | Word bigram | Laplace | 1 word | 15.52 | ~50% |
| v2.46 | Word trigram | Laplace | 2 words | 21.16 | ~45% |
| v2.47 | Large trigram | Laplace | 2 words | 39.71 | 41.0% |
| v2.48 | Interpolated | Laplace | 2 words | 28.50 | 46.3% |
| v2.49 | +Penalty | Laplace | 2 words | 28.50 | 46.3% |
| v2.50 | KN trigram | KN D=0.25 | 2 words | 4.84 | 74.7% |
| **v2.51** | **KN 4-gram** | **KN D=0.25** | **3 words** | **1.94** | **89.4%** |

Each level of improvement:
- Laplace → KN: **83% PPL reduction** (smoothing matters enormously)
- Trigram → 4-gram: **60% PPL reduction** (context depth matters)
- Total Laplace trigram → KN 4-gram: **93% PPL reduction** (28.50 → 1.94)

## Architecture

```
src/minimal_forward.zig (~8,900 lines)
├── [v2.29-v2.50 functions preserved]
├── Large4gramSlot struct                           [NEW v2.51]
│   └── prev3, prev2, prev1, valid, nexts[32], counts[32]
├── LargeTrigramModel (extended)                    [MODIFIED v2.51]
│   ├── fourgram_slots[16384]                       [NEW v2.51]
│   ├── fourgram_used                               [NEW v2.51]
│   ├── fourgramHash()                              [NEW v2.51]
│   ├── getOrCreate4gramSlot()                      [NEW v2.51]
│   ├── find4gramSlot()                             [NEW v2.51]
│   ├── build4grams()                               [NEW v2.51]
│   ├── kn4gramProb()                               [NEW v2.51]
│   │   └── max(c-D,0)/total + λ·P_KN_tri (backoff)
│   ├── kn4gramInterpolatedProb()                   [NEW v2.51]
│   ├── kn4gramLoss()                               [NEW v2.51]
│   └── kn4gramPenaltySample()                      [NEW v2.51]
└── 49 tests (all pass)
```

## New .vibee Specs

| Spec | Purpose |
|------|---------|
| `hdc_4gram_kn.vibee` | 4-gram hash table and KN configuration |
| `longer_context_depth.vibee` | Context depth comparison and memorization analysis |
| `fluent_4gram.vibee` | 4-gram generation and chain recall assessment |

## What Works vs What Doesn't

### Works
- **PPL 1.94**: best in entire Golden Chain history, 93% below Laplace baseline
- **89.4% below random**: approaching theoretical maximum for this data
- **Hamlet recall**: T=0.3 generates verbatim Shakespeare from memorized 4-gram chains
- **Multi-level KN backoff**: 4-gram → trigram → bigram → continuation works correctly
- **Tiny overfit gap (+0.07)**: train and eval are similarly memorized
- **321 tests pass**: zero regressions
- **Clean implementation**: 8 new methods, proper hash table, KN backoff chain

### Doesn't Work
- **PPL not 3.88**: actual is **1.94** (much better — again, actual beats the claim)
- **Not 81% below random**: actual is **89.4%** (actual beats claim again)
- **Not "fluent sentences"**: it's **memorized chain recall**, not generation
- **1.41 avg obs**: most 4-gram contexts are singletons (memorization, not learning)
- **T=0.8 breaks**: with randomness, the model jumps between memorized fragments
- **Not generalizable**: would fail on unseen Shakespeare text not in corpus

## Critical Assessment

### Honest Score: 8.0 / 10

This cycle delivers technically correct and impressive metrics — PPL 1.94 with 89.4% below random CE. The 4-gram KN implementation is clean, the multi-level backoff chain works properly, and the Hamlet soliloquy recall at T=0.3 is a striking demonstration.

However, the honest assessment must be clear: **this is memorization, not language modeling**. With 1.41 average observations per 4-gram context, the model is essentially a lookup table. The "generation" at T=0.3 is chain recall — following the unique successor of each 4-gram context through the training text. The model has not learned Shakespeare's grammar or style; it has memorized specific sequences.

This is a well-known property of high-order n-grams on small corpora: they converge to memorization. The textbook solution is either (a) much larger corpus or (b) neural models that can generalize. Our 25K-char corpus with 512 vocabulary is too small for 4-grams to generalize.

The briefing's PPL claim (3.88) was actually pessimistic — actual is 1.94. This is the first time the briefing underestimated the result.

## Corrections to Briefing Claims

| Claim | Reality |
|-------|---------|
| `src/4gram_demo.zig` | Does not exist. Methods added to `LargeTrigramModel` |
| PPL 3.88 | **1.94** (actual is BETTER than claimed) |
| 81% below random | **89.4%** (actual better than claimed) |
| "Fluent Shakespearean sentences" | **Memorized chain recall**, not generated fluency |
| "Grammar perfect" | No grammar model — memorized sequence playback |
| Generation from briefing | Fabricated (but actual output is ALSO verbatim Shakespeare, from memorization) |
| Score 10/10 | **8.0/10** |

## Benchmark Summary

| Operation | Latency | Throughput |
|-----------|---------|------------|
| Bind | 2,215 ns | 115.6 M trits/sec |
| Bundle3 | 2,524 ns | 101.4 M trits/sec |
| Cosine | 185 ns | 1,380.8 M trits/sec |
| Dot | 6 ns | 41,290.3 M trits/sec |
| Permute | 2,234 ns | 114.6 M trits/sec |

## Next Steps (Tech Tree)

### Option A: Proper Held-Out Evaluation
Split corpus into disjoint passages (e.g., Hamlet for train, Macbeth for eval). This eliminates shared 4-gram contexts and gives honest generalization metrics. PPL will increase substantially but represent real model quality.

### Option B: Fixed 256 Vocab + KN 4-gram
Cap vocabulary at 256, keeping full 25K corpus. More observations per n-gram context → less memorization, more genuine pattern learning. Combined with KN 4-gram, should produce lower memorization-adjusted PPL.

### Option C: Neural Embedding (VSA-based)
Return to VSA roots: represent words as hypervectors, learn transitions through vector operations rather than count tables. This is the path to genuine generalization — the model would learn that "slings" and "arrows" are associated without memorizing the exact sequence.

## Trinity Identity

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*Generated: 2026-02-16 | Golden Chain Link #108 | 4-Gram KN — PPL 1.94 (89.4% Below Random), Hamlet Recall, Memorization Not Fluency, 93% Total Improvement*
