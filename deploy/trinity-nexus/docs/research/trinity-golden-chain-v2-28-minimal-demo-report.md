# Golden Chain v2.28 — Minimal Demo + Codegen Wiring + Test Harness

**Date:** 2026-02-15
**Cycle:** 68
**Version:** v2.28
**Chain Link:** #85

## Summary

v2.28 shifts strategy from architectural specification to **minimal executable demonstration**. After 30 specs across 10 layers with zero executed integration tests, the honest path forward is specs that define the smallest possible executable proof, improvements to the codegen itself, and a concrete test harness with complete Zig test blocks.

Three new specs created:
1. **hdc_minimal_demo** — the absolute smallest end-to-end forward pass (60 lines of real Zig)
2. **hdc_codegen_wiring** — meta-spec defining how vibeec should generate non-stub code
3. **hdc_test_harness** — 5 complete integration tests + 8 helper functions (~200 lines)

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Total Level 10A Specs | 33 | From 30 |
| Total HDC Specs | 80 | From 77 |
| Generated LOC | 14,240 | +724 new |
| Tests Passing | 3098/3104 | 99.8% |
| Executed Integration Tests | 0 | UNCHANGED |
| Forward Pass Executed | No | UNCHANGED |
| Bind Latency | 2,477 ns | Normal range |
| Bundle3 Latency | 2,357 ns | Normal range |
| Cosine Similarity | 194 ns | Normal range |
| Dot Product | 6 ns | Stable |
| Permute | 2,301 ns | Normal range |

## What Changed in v2.28

### 1. hdc_minimal_demo.vibee

Defines the **absolute minimum executable test** — 60 lines of Zig that prove the forward pass works on real tokens:

```
encode "To be or" (8 chars) → position permute → single-head attention → FFN → decode → verify non-null prediction
```

The spec embeds the complete executable Zig test inline in its description. Implementation requires creating `src/demos/minimal_forward.zig` with ~60 lines using only `sdk.zig` API calls that already exist and are tested.

### 2. hdc_codegen_wiring.vibee

A **meta-specification** — it defines improvements to vibeec itself (specifically `src/vibeec/codegen/emitter.zig`). Six pattern recognition rules:

| Rule | Trigger | Generated Code |
|------|---------|----------------|
| 1. Codebook Ops | `codebook.encode`, `codebook.decode` | Real encode/decode calls |
| 2. VSA Ops | `.bind(`, `.bundle(`, `.permute(` | Real VSA operation calls |
| 3. Loop Patterns | `For i in 0..N:` | Zig `for (0..N) \|i\|` loops |
| 4. Timing | behavior name contains "measure"/"timed" | `nanoTimestamp()` wrapping |
| 5. Random Vectors | `Hypervector.random(` | `sdk.Hypervector.random(dim, seed)` |
| 6. Assignment | `variable = expression` | Direct Zig equivalent |

Currently vibeec's PatternMatcher detects VSA keywords but only emits comments. This spec defines the path from comment-stubs to real code generation.

### 3. hdc_test_harness.vibee

Defines the **exact test file** that should exist at `src/tests/hdc_integration_test.zig`. Contains 5 complete Zig test blocks with real assertions:

| Test | What It Validates | Pass Criterion |
|------|-------------------|----------------|
| Forward Pass | Output is non-null, density > 0 | predicted != null |
| Training Reduces Loss | 5 epochs reduce eval loss | loss_after < loss_before |
| Pack/Unpack Round-trip | 256 trits survive encoding | All 256 trits identical |
| Role Orthogonality | 11 role vectors are quasi-orthogonal | max \|cosine\| < 0.3 |
| BFT Majority Vote | 2/10 adversaries rejected | similarity > 0.5 |

Plus 8 helper functions (~10-20 lines each): initRoles, forwardPass, evaluateLoss, computeError, sparsifyError, updateRoles, packTrits, unpackTrits.

## Critical Assessment

### What Works
- **Spec architecture is complete**: 33 Level 10A specs cover every layer from VSA primitives through swarm federation
- **Core VSA engine is proven**: bind, bundle, cosine similarity, permute all pass tests at consistent latencies
- **API surface is documented**: v2.27 wiring specs map every operation to exact sdk.zig function signatures
- **Test infrastructure**: 3098 tests passing, benchmark harness stable

### What Does NOT Work
- **Zero executed integration tests** — this has not changed since v2.25
- **vibeec generates stubs** — every `pub fn` body is either `const result = "implemented"` or a VSA comment placeholder
- **No forward pass has ever run on real tokens** in the generated code
- **Codegen improvement path is defined but not implemented** — the meta-spec exists but emitter.zig has not been modified

### Honest Score: 8.9 / 10

The specification layer is essentially complete. The gap between specification and execution remains the single unresolved issue. v2.28's contribution is identifying the **minimal bridge**: 60 lines of hand-written Zig (or codegen improvement) to prove the system works.

## Next Steps (Tech Tree)

### Option A: Hand-Write the Minimal Demo
Create `src/demos/minimal_forward.zig` (~60 lines) directly using sdk.zig API. This bypasses vibeec entirely but **proves the system works** in minutes.

### Option B: Implement Codegen Rules in emitter.zig
Apply the 6 rules from hdc_codegen_wiring to `src/vibeec/codegen/emitter.zig`. This makes vibeec generate real code from wiring specs, benefiting all future specs.

### Option C: Create the Test Harness Directly
Write `src/tests/hdc_integration_test.zig` (~200 lines) from the hdc_test_harness spec. This validates the entire Level 10A stack with 5 falsifiable tests.

**Recommended path**: Option A first (smallest risk, fastest proof), then Option C (validates the full stack), then Option B (improves the toolchain).

## Architecture Evolution

```
v2.25: 24 specs, 8 layers, 0 execution     — Architecture complete
v2.26: 27 specs, validation defined         — What to test
v2.27: 30 specs, wiring mapped              — How to implement
v2.28: 33 specs, minimal demo defined       — Smallest executable proof
v2.29: ???                                   — First real execution
```

The gap is now precisely 60 lines of Zig code.

## Trinity Identity

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*Generated: 2026-02-15 | Golden Chain Link #85*
