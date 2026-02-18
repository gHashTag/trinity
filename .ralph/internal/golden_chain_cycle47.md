# Golden Chain Cycle 47: Full Local Fluent Multilingual Code Gen
# Date: 2026-02-18
# Objective: Create a coder model product through Trinity's symbolic AI pipeline

---

## Link 1: TRI DECOMPOSE

### Objective
"Full local fluent multilingual code gen" — a coding model that:
1. Runs locally (no cloud dependency)
2. Generates fluent, idiomatic code
3. Supports multiple languages (Python, Rust, TypeScript, Go, Zig)
4. Uses Trinity's VSA + Symbolic AI pipeline (not just neural)

### Quarks (Atomic Tasks)

#### Q1: Fix Build (BLOCKER)
- [ ] Fix tri_demos.zig (5 functions reference missing TextCorpus thread pool API)
- [ ] Fix fluent target (missing triples_parser module dep in build.zig)
- [ ] Fix chat_server.zig (i128/i64 type mismatch)
- Acceptance: `zig build` exits 0

#### Q2: VSA Core Verification
- [ ] Verify bind/bundle/permute/cosine_similarity all pass tests
- [ ] Run VSA benchmarks, record M trits/sec
- [ ] Compare with previous benchmarks
- Acceptance: All VSA tests pass, benchmarks recorded

#### Q3: Inference Pipeline E2E
- [ ] Load a GGUF model (Qwen 2.5 Coder 7B)
- [ ] Convert to TRI format via gguf_to_tri
- [ ] Run forward pass, generate 20 tokens
- [ ] Measure: load time, TTFT, tok/s
- Acceptance: Model generates coherent code tokens

#### Q4: Symbolic Reasoning Integration
- [ ] Wire HDC knowledge graph into inference
- [ ] Test analogy solving (code patterns)
- [ ] Test triple extraction from code context
- Acceptance: VSA augments code generation with symbolic reasoning

#### Q5: Multilingual Codegen Verification
- [ ] Verify Python codegen (MGEN-001)
- [ ] Verify Rust codegen (MGEN-002)
- [ ] Verify TypeScript codegen (MGEN-003)
- [ ] Test .vibee → Zig → Python/Rust/TS pipeline
- Acceptance: All 3 languages generate correct code from .vibee

#### Q6: Coder Model Spec
- [ ] Create coder_model.vibee spec
- [ ] Define: code completion, code explanation, code review behaviors
- [ ] Define: language detection, syntax-aware generation
- Acceptance: Spec covers all coder model behaviors

#### Q7: Benchmarking Suite
- [ ] Benchmark vs llama.cpp (GGUF inference speed)
- [ ] Benchmark vs BitNet (ternary efficiency)
- [ ] Benchmark VSA reasoning vs pure neural
- [ ] Record all results with timestamps
- Acceptance: Comparison table with real numbers

---

## Link 2: TRI PLAN

### Tech Tree Node Selection

**Primary: INF-003 (KV Cache Optimization)**
- ROI: (9/3) × 2 = 6.0 (HIGHEST)
- Why: Directly enables coder model memory efficiency
- Unlocks: Partial INF-005 (Speculative Decoding v2)

**Secondary: OPT-002 (next optimization)**
- ROI: (7/5) × 1 = 1.4
- Why: Weight Streaming enables larger models locally

**Exploratory: E2E coder model pipeline**
- ROI: High impact, medium complexity
- Why: Direct path to Arena submission

### Strategy
1. Fix build blockers (Q1) — IMMEDIATE
2. Create coder_model.vibee spec (Q6) — SPEC FIRST
3. Generate code from spec (Q6 → Link 4)
4. Test E2E pipeline (Q3 + Q4)
5. Benchmark with proofs (Q7)

### Critical Path
```
Q1 (fix build) → Q2 (VSA verify) → Q3 (inference E2E) → Q4 (symbolic) → Q6 (spec) → Q7 (bench)
```

---

## Performance Baselines (from previous cycles)

| Metric | Value | Source |
|--------|-------|--------|
| VSA bind | SIMD optimized | MATH-001 |
| Bundle3 | 3-16x speedup | OPT-001 |
| JIT | 17.74x improvement | NEXUS-002 |
| Prefix cache | 99% prefill reduction | OPT-PC01 |
| KG wire format | 268 bytes | SYM-003 |
| Memory vs f32 | 20x savings | MATH-003 |
| Ternary matmul | ~10x vs float | OPT-T02 |
| Ternary compression | 8.5x (7B model) | OPT-T01 |

---

## Tech Tree ROI Matrix

| Node | Impact | Complexity | Unlocks | ROI | Priority |
|------|--------|-----------|---------|-----|----------|
| INF-003 | 9 | 3 | 2 | 6.00 | #1 |
| OPT-002 | 7 | 5 | 1 | 1.40 | #2 |
| DEV-003 | 5 | 4 | 0 | 1.25 | #3 |

---

φ² + 1/φ² = 3 | TRINITY | Cycle 47
