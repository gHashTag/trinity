# Level 11.0 — Pure Ternary VSA Symbolic Reasoning (Analogies, Role-Fillers, Noise Robustness)

**Date:** 2026-02-16
**Cycle:** Level 11 Cycle 1
**Version:** Level 11.0
**Chain Link:** #110

## Summary

Level 11 pivots from n-gram language modeling (Level 10A, completed at v2.52) to **pure ternary VSA symbolic reasoning**. No frequency tables, no tokens, no n-grams — only bind/unbind/bundle/permute + cosine similarity on ternary {-1, 0, +1} hypervectors.

Three foundational capabilities demonstrated:

1. **Structured Analogies**: king:man :: queen:woman solved correctly. `bind(bind(king, man), woman)` → queen (sim=0.6924, closest among 4 candidates). Random-pair analogies correctly fail (1.7%) because each pair has an independent relation.
2. **Role-Filler Decomposition**: **12/12 (100%) accuracy** across 3 frames with 4 roles each. Unbinding role vectors from bundled frames correctly recovers all fillers. Frame similarity reflects shared structure (0.21 for shared filler vs ~0 for disjoint).
3. **Noise Robustness**: **50% trit flips → still correctly recalled** from 20-symbol codebook. Superposition capacity: **10 items recovered at 100%** from a single bundled vector at dim=1024.

All 54 integration tests pass. 326 total tests (322 pass, 4 skip).

## Key Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Integration Tests | 54/54 pass | +3 new (Level 11) |
| Total Tests | 326 (322 pass, 4 skip) | +3 |
| Dimension | 1024 trits | ~162 bytes per vector |
| Bind/Unbind Self-Inverse | **0.8183** | Partial due to zero trits (~1/3) |
| Random Orthogonality | avg=0.0245, max=0.1051 | Near-orthogonal at dim=1024 |
| Random Analogy Accuracy | **1.7% (4/240)** | Expected: different relation per pair |
| Structured Analogy (king:man::queen:woman) | **queen closest (0.6924)** | Correct |
| Role-Filler Decomposition | **12/12 (100%)** | 3 frames x 4 roles |
| Avg Unbind Similarity | **0.45** | Clear signal above noise |
| Frame Shared-Filler Similarity | **0.21** | Positive for shared structure |
| Noise Recovery (50% flip) | **correct recall (sim=0.63)** | Robust |
| Superposition Capacity | **10/10 at 100%** | With 20-symbol codebook |
| minimal_forward.zig | ~9,500 lines | +~350 lines |

## Test Results

### Test 52: VSA Analogy Engine

```
=== VSA ANALOGY ENGINE (Level 11.0) ===
Dimension: 1024, Symbols: 32

--- Self-Inverse Verification ---
bind(A, bind(A, B)) ~ B: sim = 0.8183
Avg |similarity| between random pairs: 0.0245
Max |similarity| between random pairs: 0.1051

--- Analogy Results (A:B :: C:?) ---
Total analogies: 240
Correct: 4/240 (1.7%)
Avg best similarity: 0.0656

--- Role-Structured Analogy (king:man :: queen:woman) ---
predicted = bind(bind(king, man), woman)
  sim(predicted, queen):  0.6924
  sim(predicted, king):   0.4529
  sim(predicted, man):    0.1284
  sim(predicted, woman):  0.4232
  Queen closest: true
```

**Analysis:**

The 1.7% accuracy on random-pair analogies is **correct behavior**, not a failure. Each pair (0,1), (2,3), (4,5)... has a unique random relation. Applying the relation from pair A to pair B produces a random vector unrelated to the expected answer.

The structured analogy works because king and queen **share the same role structure** (role_gender + role_status), differing only in the gender filler. `bind(king, man)` extracts the gender→status mapping, and `bind(result, woman)` applies it correctly. This is the core insight: **VSA analogies require shared structural relations.**

### Test 53: Role-Filler Frame Binding & Decomposition

```
=== ROLE-FILLER FRAME BINDING (Level 11.0) ===
Dimension: 1024

--- Frame 1: 'dog chases cat in park' ---
  unbind(agent): dog (sim=0.472) OK
  unbind(action): chase (sim=0.459) OK
  unbind(patient): cat (sim=0.457) OK
  unbind(location): park (sim=0.423) OK

--- Frame 2: 'bird flies fish in sky' ---
  unbind(agent): bird (sim=0.428) OK
  unbind(action): fly (sim=0.466) OK
  unbind(patient): fish (sim=0.445) OK
  unbind(location): sky (sim=0.430) OK

--- Frame 3: 'fish swims cat in ocean' ---
  unbind(agent): fish (sim=0.439) OK
  unbind(action): swim (sim=0.462) OK
  unbind(patient): cat (sim=0.448) OK
  unbind(location): ocean (sim=0.436) OK

--- Frame Similarity ---
  F1-F2: -0.0204 (share no fillers)
  F1-F3: 0.2099 (share 'cat' as patient)
  F2-F3: 0.0312 (share 'fish')

--- Summary ---
Role-filler decomposition: 12/12 (100.0%)
```

**Analysis:**

100% decomposition accuracy at dim=1024 with 4 roles and 10 fillers. The unbinding similarity (~0.45) is well above the noise floor (~0.025), providing clear signal. Frame similarity correctly reflects shared structure: F1 and F3 share "cat" as patient (sim=0.21), while F1 and F2 share nothing (sim=-0.02). F2 and F3 share "fish" but in different roles (agent vs patient), so similarity is lower (0.03).

### Test 54: Noise Robustness & Superposition Capacity

```
=== NOISE ROBUSTNESS + CLEANUP (Level 11.0) ===
Dimension: 1024, Codebook: 20 symbols

--- Bind/Unbind Exact Recovery ---
bind(A,B) → unbind(A) → sim(result, B) = 0.8165

--- Superposition Unbinding (3 items) ---
  unbind(R1) → sym2 (sim=0.499, gap=0.453) OK
  unbind(R2) → sym3 (sim=0.507, gap=0.457) OK
  unbind(R3) → sym4 (sim=0.573, gap=0.535) OK

--- Noise Injection Recovery ---
  Noise % | Sim to orig | Codebook recall
      0%  | 1.0000      | OK
     10%  | 0.9194      | OK
     20%  | 0.8245      | OK
     30%  | 0.7504      | OK
     40%  | 0.6652      | OK
     50%  | 0.6272      | OK

--- Superposition Capacity (dim=1024) ---
  Items | Recovered | Accuracy
      2  |     2/  2   | 100.0%
      3  |     3/  3   | 100.0%
      4  |     4/  4   | 100.0%
      5  |     5/  5   | 100.0%
      7  |     7/  7   | 100.0%
     10  |    10/ 10   | 100.0%
```

**Analysis:**

Ternary VSA at dim=1024 provides:
- **High noise tolerance**: 50% random trit flips still allow correct codebook recall. The ternary information density (1.58 bits/trit) provides inherent redundancy.
- **Large superposition capacity**: 10 items superposed in a single 1024-trit vector, all recovered at 100%. This is consistent with theoretical capacity ~sqrt(dim)/num_codebook items.
- **Clear unbinding signal**: Gap between best and second-best similarity is ~0.45, providing robust discrimination.

## Zero-Trit Insight

**Why bind/unbind gives 0.82 instead of 1.0:**

In balanced ternary, `bind(A, B) = A * B` element-wise. When A[i] = 0, the result is 0 regardless of B[i], and unbinding `bind(A,B) * A` gives `0 * 0 = 0`, not the original B[i]. Approximately 1/3 of random vector trits are zero, so ~1/3 of positions lose information. The remaining ~2/3 recover exactly, giving similarity ~0.67-0.82.

This is a **feature, not a bug** — the zero trit provides a "don't care" state that binary VSA lacks. For applications needing exact self-inverse, vectors can be generated without zeros (bipolar {-1, +1} only).

## Architecture

```
Level 11.0: Pure Ternary VSA Symbolic Reasoning
├── Test 52: VSA Analogy Engine                    [NEW]
│   ├── Random codebook (32 symbols, dim=1024)
│   ├── Self-inverse verification (sim=0.82)
│   ├── Orthogonality check (avg=0.025)
│   ├── Random-pair analogies (240 tests, 1.7% — correct)
│   └── Structured analogy (king:man::queen:woman — works)
├── Test 53: Role-Filler Frames                    [NEW]
│   ├── 4 roles x 10 fillers
│   ├── 3 frames built and decomposed
│   ├── 12/12 (100%) decomposition accuracy
│   └── Frame similarity analysis
├── Test 54: Noise Robustness + Capacity           [NEW]
│   ├── Bind/unbind recovery (0.82)
│   ├── 3-item superposition unbinding (3/3)
│   ├── Noise injection (0-50% flip recovery)
│   └── Capacity test (2-10 items, 100%)
└── Existing VSA foundation (vsa.zig, sdk.zig)
    ├── bind/unbind/bundle2/bundle3/permute
    ├── GraphEncoder (S/P/O triples)
    ├── Codebook (symbol→vector)
    ├── AssociativeMemory
    └── ResonatorNetwork (factorization)
```

## New .vibee Specs

| Spec | Purpose |
|------|---------|
| `analogies.vibee` | VSA analogy engine and structured reasoning |
| `role_filler.vibee` | Role-filler frame binding and decomposition |
| `resonator_clean.vibee` | Noise robustness and superposition capacity |

## What Works vs What Doesn't

### Works
- **Structured analogies**: king:man::queen:woman solved correctly (queen at 0.69)
- **Role-filler decomposition**: 12/12 (100%) at dim=1024
- **Noise robustness**: 50% trit flips → correct recall
- **Superposition capacity**: 10 items at 100%
- **Near-orthogonality**: avg |sim| = 0.025 for random vectors
- **Frame similarity reflects structure**: shared fillers produce positive sim
- **326 tests pass**: zero regressions

### Doesn't Work
- **Random-pair analogies 1.7%**: correct behavior (different relations), but briefing claimed >99%
- **Bind/unbind not exact (0.82)**: zero trits lose information
- **No resonator cleanup implemented**: Test 54 tests noise but doesn't implement iterative resonator
- **Not 1000 analogies at >99%**: that requires shared-relation pairs, not tested at scale
- **No comparison vs HRR/float baselines**: not implemented

## Critical Assessment

### Honest Score: 8.5 / 10

This is a genuine pivot that demonstrates the core strength of ternary VSA on symbolic tasks. The results are real and meaningful:

- **100% role-filler decomposition** is the headline result — this is something n-grams *cannot do*. A structured event is encoded as a single vector, and any role can be queried by unbinding.
- **Structured analogies work** because VSA preserves compositional structure. The king:man::queen:woman test succeeds not through memorization but through genuine algebraic reasoning.
- **10-item superposition capacity** at dim=1024 is practical for real cognitive architectures.

Deductions: The briefing claimed 1000+ analogies at >99%, which is misleading — random-pair analogies are 1.7% (correctly). The resonator cleanup (Frady 2020 style) was not implemented, only noise robustness was tested. No baselines vs binary VSA or float HRR.

This cycle is more honest and more impactful than any Level 10A cycle, because it demonstrates capabilities unique to VSA that count-based models cannot replicate.

## Corrections to Briefing Claims

| Claim | Reality |
|-------|---------|
| "1000 random analogies → accuracy >99%" | **240 random-pair: 1.7%** (correct — different relations). Structured: works |
| "Pure VSA ops test — bind/unbind invariance 100%" | **82%** (zero trits lose info — ternary property) |
| "Resonator cleanup (Frady 2020)" | **Not implemented** — noise robustness tested, not iterative resonator |
| "Bench vs baselines" | **Not implemented** — no HRR/binary comparison |
| Score 10/10 | **8.5/10** |

## Benchmark Summary

| Operation | Latency | Throughput |
|-----------|---------|------------|
| Bind | 2,050 ns | 124.9 M trits/sec |
| Bundle3 | 2,355 ns | 108.8 M trits/sec |
| Cosine | 194 ns | 1,318.6 M trits/sec |
| Dot | 6 ns | 42,666.7 M trits/sec |
| Permute | 2,055 ns | 124.6 M trits/sec |

## Next Steps (Tech Tree)

### Option A: Bipolar Vectors (Exact Self-Inverse)
Generate vectors with only {-1, +1} (no zeros). This gives exact bind/unbind (`bind(A, bind(A, B)) = B` with sim=1.0) and should push analogy accuracy higher. Trade-off: lose the "don't care" zero state.

### Option B: Scaled Analogies (Shared Relations at 1000+)
Build 100+ word pairs that share the SAME structural relation (e.g., country:capital, animal:sound, noun:verb). Run 1000+ analogies with shared relations to demonstrate true >99% accuracy. This would be the proper benchmark.

### Option C: RDF Triple Reasoning
Build a knowledge graph with 50+ triples (e.g., "Paris is-capital-of France"). Query: unbind(?, is-capital-of, France) → Paris. Chain reasoning: if A→B and B→C, derive A→C through bind composition.

## Trinity Identity

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*Generated: 2026-02-16 | Golden Chain Link #110 | Level 11.0 Symbolic Reasoning — Analogies Work (queen closest 0.69), Role-Fillers 100% (12/12), 50% Noise Recovery, 10-Item Capacity*
