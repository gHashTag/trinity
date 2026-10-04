# ADR-001: De-Zigфикация — Tri as Source of Truth

**Status:** Phase 1 & 2 Complete (2026-04-04)
**Date:** 2026-04-04
**Order:** EXECUTED

---

## Phase 1 Completion Summary (2026-04-04)

### Completed Artifacts

| Artifact | Status | Notes |
|----------|--------|-------|
| `architecture/CANON_DE_ZIGFICATION.md` | ✅ Done | Foundation document |
| `t27/specs/base/types.t27` | ✅ Done | Trit, PackedTrit, TernaryWord |
| `t27/specs/base/ops.t27` | ✅ Done | trit multiply, add, carry |
| `architecture/graph.tri` | ✅ Done | Dependency graph (assembly format) |
| `architecture/graph_v2.json` | ✅ Done | Machine-readable graph v2 |
| `t27/specs/numeric/gf16.t27` | ✅ Done | GoldenFloat16 encode/decode |
| `t27/specs/numeric/tf3.t27` | ✅ Done | TF3 format, 8-bit weights |
| `t27/specs/math/constants.t27` | ✅ Done | φ, identities, sacred chain (HOTFIX SP-1 applied) |
| `t27/specs/math/sacred_physics.t27` | ✅ Done | Sacred physics layer (HOTFIX SP-1 applied) |
| `t27/conformance/sacred_physics_*.json` | ✅ Done | 4 conformance vectors (HOTFIX SP-1 applied) |
| `docs/ARCH_BENCH.md` | ✅ Done | ARCH_BENCH-001 documentation |
| `t27/conformance/arch_bench.json` | ✅ Done | Machine-readable benchmark results |
| `AGENTS.md` (v2.0) | ✅ Done | 27-agent alphabet documentation |
| `skills/agent-t/SKILL.md` | ✅ Done | Queen T 6-phase orchestration cycle |

### HOTFIX SP-1: PHI Naming + OMEGA_LAMBDA Dimensionless

**Bugs Fixed:**

1. **PHI/PHI_INV swap** — `constants.t27` had PHI = 0.618 (φ⁻¹), now corrected:
   - `PHI = 1.618...` (golden ratio)
   - `PHI_INV = 0.618...` (inverse golden ratio = consciousness threshold C)

2. **OMEGA_LAMBDA dimensionless** — `constants.t27` had dimensional Λ, now corrected:
   - `LAMBDA_COSMO = 1.1056e-52` (dimensional Λ in m⁻²)
   - `OMEGA_LAMBDA_MEASURED = 0.685` (dimensionless Ω_Λ from Planck)

**Files Updated:**
- `t27/specs/math/constants.t27` — Fixed PHI, PHI_INV, OMEGA_LAMBDA, added LAMBDA_COSMO
- `t27/specs/math/sacred_physics.t27` — Uses PHI_INV from constants
- `t27/conformance/sacred_physics_constants.json` — Fixed PHI/PHI_INV values
- `t27/conformance/sacred_physics_cosmology.json` — Fixed omega value to 0.685

### graph_v2.json Features

- **17 nodes** with full metadata (id, name, path, strand, tier, kind, exports, status)
- **Typed edges**: import, codegen, runtime, bench-impact, phi-critical, sacred-core
- **Action graph**: commands triggered by file changes
- **Bench links**: traceability between specs and benchmarks
- **Topological contract**: validated dependency order

### ARCH_BENCH-001 Results

Trinity's typed graph vs baseline systems (Bazel, Make):

| Metric | Trinity | Bazel | Make | Improvement |
|--------|---------|-------|------|-------------|
| Avg Impacted Nodes | 4.0 | 11.7 | 14.0 | -66% / -71% |
| Avg Tests Rerun | 2.7 | 9.7 | 11.7 | -72% / -77% |
| Avg Wasted Steps | 0.3 | 4.7 | 6.3 | -94% / -95% |
| Avg Repeat Errors | 0.0 | 1.7 | 2.3 | -100% |

---

## Context

Trinity Project currently has Zig code scattered across `src/` with `.tri` specs in `specs/`. This creates:

1. **Dual Source of Truth** — Which is correct: .zig or .tri?
2. **Zig-Language Lock-in** — Hard to target other languages from Zig code
3. **Implementation Drift** — Logic duplicated between specs and Zig
4. **Fragmented Knowledge** — ML algorithms split across many files

---

## Decision

**Establish `t27` as the canonical language specification.**

### Core Principles

1. **Single Source of Truth** — All implementations derive from .t27 specs
2. **Hardware-First Design** — t27 models Ternary Computing directly (27 registers, Coptic ISA)
3. **Zero Zig in Specs** — Specifications are hardware- and language-agnostic
4. **Multi-Target Generation** — One .t27 spec → Zig, C, Verilog, Python, Rust, Go

> **Correction (2026-10-04).** Item 4 named backends the compiler does not have.
> `t27c` emits Zig, Verilog, Verilog (HIR), C, Rust, JavaScript and TypeScript —
> the seven targets of `t27_compiler.wasm`, listed as `TARGET_IDS` in
> `apps/website/src/lib/t27Compiler.ts`. A Python backend is planned for
> gHashTag/t27 and not yet shipped. Go, C++ and VHDL were never t27c
> backends (Go, Java, Kotlin, Swift and SQL generators belonged to VIBEE). The
> decision above is left as written; this note records what it shipped as.

---

## The t27 Language

t27 is **TRI-27 Assembly** — a low-level hardware specification language.

### Design Philosophy

- **27 Registers** — Coptic registers r0-r26 (r0-r25 general, r26 = zero)
- **Ternary Operations** — All operations on trits {-1, 0, +1}
- **Opcodes** — MOV, JZ, MUL, ADD, BIND, BUNDLE, HALT
- **Data Section** — Static data storage (.data)
- **Code Section** — Sequential execution (.code)

### Syntax

```t27
; Comment
.const NAME value

.data
    .dword 0  ; Space for variables

.code
    MOV r0, #5      ; Load immediate
    MUL r1, r0, r2  ; Multiply r1 = r0 * r2
    JZ r0, label     ; Jump if zero
    HALT

label:
    ; ...
```

---

## Migration Strategy

### Phase 1: Foundations (Current)

1. ✅ `architecture/CANON_DE_ZIGFICATION.md` — Foundation document
2. ✅ `t27/specs/base/types.t27` — Trit, PackedTrit, TernaryWord
3. ✅ `t27/specs/base/ops.t27` — trit multiply, add, carry
4. ✅ `architecture/graph.tri` — Dependency graph
5. ✅ `architecture/ADR-001-de-zigfication.md` — This decision

### Phase 2: Numeric Formats (Complete ✅)

6. ✅ `t27/specs/numeric/gf16.t27` — GoldenFloat16 encode/decode
7. ✅ `t27/specs/numeric/tf3.t27` — TF3 format, 8-bit weights
8. ✅ `t27/specs/math/constants.t27` — φ, identities, sacred chain (HOTFIX SP-1 applied)
9. ✅ `t27/specs/math/sacred_physics.t27` — Sacred physics layer (Done with HOTFIX SP-1)
10. ✅ `t27/specs/numeric/goldenfloat_family.t27` — GF4-GF32 family (NUMERIC-STANDARD-001)
11. ✅ `t27/conformance/gf_family_bench.json` — GoldenFloat benchmarks (NUMERIC-STANDARD-001)
12. ✅ `t27/specs/numeric/gf4.t27` — GF4 spec (NUMERIC-STANDARD-001)
13. ✅ `t27/specs/numeric/gf8.t27` — GF8 spec (NUMERIC-STANDARD-001)
14. ✅ `t27/specs/numeric/gf12.t27` — GF12 spec (NUMERIC-STANDARD-001)
15. ✅ `t27/specs/numeric/gf20.t27` — GF20 spec (NUMERIC-STANDARD-001)
16. ✅ `t27/specs/numeric/gf24.t27` — GF24 spec (NUMERIC-STANDARD-001)
17. ✅ `t27/specs/numeric/gf32.t27` — GF32 spec (NUMERIC-STANDARD-001)
18. ✅ `t27/specs/numeric/phi_ratio.t27` — φ-ratio proof (NUMERIC-STANDARD-001)
19. ✅ `t27/conformance/gf4_vectors.json` — GF4 conformance (NUMERIC-STANDARD-001)
20. ✅ `t27/conformance/gf8_vectors.json` — GF8 conformance (NUMERIC-STANDARD-001)
21. ✅ `t27/conformance/gf12_vectors.json` — GF12 conformance (NUMERIC-STANDARD-001)
22. ✅ `t27/conformance/gf16_vectors.json` — GF16 conformance (NUMERIC-STANDARD-001)
23. ✅ `t27/conformance/gf20_vectors.json` — GF20 conformance (NUMERIC-STANDARD-001)
24. ✅ `t27/conformance/gf24_vectors.json` — GF24 conformance (NUMERIC-STANDARD-001)
25. ✅ `docs/GF_FAMILY_BENCH.md` — BENCH-005 documentation (NUMERIC-STANDARD-001)

### Phase 3: Compiler

9. ⏳ `t27/compiler/parser/` — Minimal .t27 parser
10. ⏳ `t27/compiler/codegen/zig/` — .t27 → Zig generation
11. ⏳ `t27/compiler/codegen/verilog/` — .t27 → Verilog generation
12. ⏳ `t27/compiler/codegen/c/` — .t27 → C generation
13. ⏳ `t27/compiler/runtime/` — Bootstrap runtime for T27

### Phase 4: Validation (In Progress)

14. ⏳ `t27/conformance/` — JSON test vectors for correctness
15. ⏳ `t27/build.tri` — Canonical build system
16. ⏳ `docs/migration-map.md` — 80+ folders migration map
17. ✅ GitHub repository — **https://github.com/gHashTag/t27**

---

## Success Criteria

### Phase 1 Complete ✅ (2026-04-04)

- [x] All base specs written and validated
- [x] Architecture documents signed off
- [x] graph.tri can validate dependency resolution
- [x] graph_v2.json created with typed edges
- [x] ARCH_BENCH-001 benchmark completed
- [x] HOTFIX SP-1 applied (PHI/PHI_INV + OMEGA_LAMBDA)
- [x] 27-agent alphabet documented (AGENTS.md v2.0)
- [x] Queen T 6-phase cycle defined (skills/agent-t/SKILL.md)

### Phase 2 Complete ✅ (2026-04-04)

- [x] GF16 roundtrip accuracy < 0.01% error
- [x] TF3 spec verified against TensorFlow documentation
- [x] Sacred constants (φ² + 1/φ² = 3) validated
- [x] GoldenFloat Family (GF4-GF32) created
- [x] arch_bench.json real metrics from actual runs
- [x] phi_ratio.t27 proof complete
- [x] BENCH-005 documentation created

### Phase 3 Complete

- [ ] Parser can parse all existing .t27 files
- [ ] Zig generator produces valid Zig 0.15 code
- [ ] Verilog generator synthesizable on XC7A100T
- [ ] C generator compiles with clang/gcc

### Phase 4 Complete

- [ ] All conformance tests passing
- [ ] `t27/build.tri` can build entire project
- [ ] Migration map covers 80% of trinity/src/
- [ ] t27 repo has first stable release

---

## Alternatives Considered

### Alternative 1: Keep Zig as Source of Truth

**Pros:**
- No migration cost
- Existing code continues to work

**Cons:**
- Hard to target other languages
- Logic drift between .tri and .zig
- Hardware-agnostic specs difficult

**Decision:** REJECTED — Violates multi-target principle

### Alternative 2: Use External Language (DSL)

**Pros:**
- Established ecosystem
- Mature tooling

**Cons:**
- External dependency
- Not hardware-first
- Lost Ternary specificity

**Decision:** REJECTED — Trinity must own its language

---

## Future Work

### Orchestration Infrastructure (Phase 1 Complete ✅)

1. **27-Agent Alphabet** — Complete agent registry with Coptic letter mapping
   - `AGENTS.md` (v2.0) — All 27 agents with domains, archetypes, files
   - Three layers: Archetypal (A-I), Spiritual (J-R), Physical (S-Ϯ)
   - AGENT T (Ϯ, Ti) as Queen orchestrator
   - Word formations: TRINITY, SPEC, CELL, PHI

2. **Queen T 6-Phase Cycle** — Orchestration protocol
   - Phase 1 (Plan): T, G, R — graph analysis and issue scanning
   - Phase 2 (Assign): T assigns to domain experts (A, N, P, F, S, etc.)
   - Phase 3 (Run): Parallel execution of all assigned agents
   - Phase 4 (Test): F, V, G, M — validation and benchmarking
   - Phase 5 (Verdict): V, Q, E, U — analysis and toxic blocking
   - Phase 6 (Evolve): T, E, M, W, Z, X, C, B — integration and documentation
   - `skills/agent-t/SKILL.md` — Complete cycle documentation

### Development Tools

3. **IDE Support** — VSCode extension for .t27 syntax highlighting
4. **LSP Server** — Language server for autocomplete/diagnostics
5. **REPL** — Interactive t27 development environment
6. **Debugger** — Visual stepping through t27 execution

---

## References

- `architecture/CANON_DE_ZIGFICATION.md` — Foundation document
- `architecture/graph.tri` — Dependency graph (assembly format)
- `architecture/graph_v2.json` — Machine-readable graph v2
- `CLAUDE.md` — Project rules
- `AGENTS.md` (v2.0) — 27-agent alphabet documentation
- `skills/agent-t/SKILL.md` — Queen T 6-phase orchestration cycle
- **https://github.com/gHashTag/t27** — t27 canonical language repository
- Issue references to be added

---

**Maintained by:** Architecture Team
**Review Date:** 2026-04-04
**Next Review:** After Phase 2 complete
