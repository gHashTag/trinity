# Ralph Fix Plan — Trinity

> Tasks should align with Tech Tree priorities.
> See `.ralph/TECH_TREE.md` for current tree state and available nodes.
> Priority mapping: P1 = Tech Tree Priority 1, P2 = Priority 2, etc.
> After completing a task, update TECH_TREE.md if it corresponds to a tree node.

## Task Format

```
- [ ] [P1/P2/P3] Task description
  - Acceptance: measurable pass/fail criteria
  - Files: paths to create/modify
  - Blocked-by: (dependency, if any)
```

---

## Current Sprint — VSA Mathematical Framework (Level 11.39)

> **Goal:** Mathematical framework for VSA — proofs + optimizations for bind/unbind/bundle, multilingual code gen.
> **Tech Tree:** New branch MATH (nodes MATH-001..005), critical path to symbolic AGI maturity.
> **Golden Chain:** Level 11.38 → 11.39 transition. Cycle 39: Mathematical Framework Development.

- [x] [P1] Create `math_framework_proof.vibee` — VSA math proofs specification
  - Acceptance: Spec defines bind/unbind invariance proofs, bundle N convergence, similarity bounds
  - Files: `specs/tri/math_framework_proof.vibee`
  - Tech Tree: MATH-001
  - DONE: 10 proofs defined (bind inverse, commutative, self-identity, associative, bundle convergence, orthogonality, permute cycle, similarity bounds, trinity identity, bundle2 similarity)

- [x] [P1] Generate + test VSA math proof module from spec
  - Acceptance: `zig build test-math-proofs` passes, proofs verify: `unbind(bind(A,B), A) == B` with sim>0.95
  - Files: `generated/vsa_math_proofs.zig`, `build.zig` (wired to test step)
  - Tech Tree: MATH-001
  - DONE: 10 tests generated, wired into build.zig as test-math-proofs step

- [x] [P1] Create `vsa_optimization.vibee` — bundle N optimization spec
  - Acceptance: Spec defines optimized bundle for N vectors (N=2..1000), SIMD hints, memory layout
  - Files: `specs/tri/vsa_optimization.vibee`
  - Tech Tree: MATH-002
  - DONE: BundleAccumulator pattern with O(N*D) complexity, recall analysis

- [x] [P1] Generate + test VSA optimization module
  - Acceptance: `zig build test-bundle-opt` passes, bundle(100 vectors) recall >= 50%
  - Files: `generated/vsa_bundle_opt.zig`, `build.zig` (wired to test step)
  - Tech Tree: MATH-002
  - DONE: BundleAccumulator struct + bundleN() + 6 tests, wired into build.zig

- [x] [P1] Integrate multilingual_engine.zig into VIBEE codegen pipeline
  - Acceptance: `zig build vibee -- gen specs/tri/multilingual_codegen.vibee` produces output, `zig build test` passes
  - Files: `src/vibeec/multilingual_engine.zig`, `src/vibeec/vibee_gen.zig`, `specs/tri/multilingual_codegen.vibee`
  - Tech Tree: CORE-002 (extend)
  - DONE: multilingual_engine.zig generated with enums (InputLanguage, TargetLanguage, ProgrammingIntent), behavior functions, test file

- [x] [P1] Fix codegen builder/emitter for multi-target output
  - Acceptance: `zig build` compiles, `zig build test` passes, codegen produces valid Zig + at least one other target
  - Files: `src/vibeec/codegen/builder.zig`, `src/vibeec/codegen/emitter.zig`
  - DONE: Added toOwnedSlice() to builder, enum variant emission in emitter, implementation block support in behaviors, improved multiline block parsing in parser

- [x] [P2] Benchmark VSA math framework vs v11.38 and competitors
  - Acceptance: `zig build bench-math` runs, results documented in `benchmarks/level11.39/`, shows improvement over v11.38
  - Files: `benchmarks/bench_math.zig`, `benchmarks/level11.39/BENCHMARK_RESULTS.md`, `specs/tri/vsa_benchmark.vibee`, `build.zig`
  - Tech Tree: MATH-003
  - DONE: 7-section benchmark suite (throughput, bundleN, memory, recall curve, convergence, proof timing, comparison table)

- [x] [P2] Add Python codegen target to multilingual engine
  - Acceptance: `zig build vibee -- gen <spec.vibee>` with `language: python` produces valid .py file
  - Files: `src/vibeec/vibee_gen.zig`, `src/vibeec/lang_generators.zig`
  - Tech Tree: MATH-004 (partial)
  - DONE: Wired lang_generators.zig (Python, TypeScript, Rust, Go, Java, Swift, Kotlin, C, SQL) into vibee_gen.zig main pipeline. VibeeSpec → ParsedSpec bridge, isMultiLangTarget dispatch, deriveOutputPath extensions for all 9 targets.

- [x] [P2] Add TypeScript codegen target to multilingual engine
  - Acceptance: `zig build vibee -- gen <spec.vibee>` with `language: typescript` produces valid .ts file
  - Files: `src/vibeec/vibee_gen.zig`, `src/vibeec/lang_generators.zig`
  - DONE: Same integration as Python — TypeScript generator already existed in lang_generators.zig, now routed via vibee_gen.zig pipeline

- [x] [P3] Update vibee_parser.zig for multi-language spec fields
  - Acceptance: parser handles `language: [zig, python, typescript]` array syntax, `zig build test` passes
  - Files: `src/vibeec/vibee_parser.zig`, `src/vibeec/vibee_gen.zig`
  - Tech Tree: MATH-004 (advance)
  - DONE: Added `languages` ArrayList field to VibeeSpec, `parseLanguageArray()` parser, multi-target generation in vibee_gen.zig, 2 new tests (array syntax + backward compat)

---

## Backlog

- [ ] [P2] Add Rust codegen target
- [ ] [P2] Add Go codegen target
- [ ] [P3] Dashboard widget for multilingual codegen status (MATERIYA column)
- [ ] [P3] E2E test: spec -> generate all targets -> validate each output
- [ ] [P3] Benchmark: codegen performance across targets

---

## Blocked

(none)

---

## Completed

- [x] Project enabled for Ralph
- [x] Ralph configuration improved (.ralphrc, PROMPT.md, AGENT.md, RULES.md)

---

## Learnings

- VIBEE compiler paths: use `zig build vibee --` NOT legacy binary paths
- Generated files in `trinity/output/` — never edit directly
- Golden Chain cycle: spec -> gen -> test -> assess -> tech tree -> commit
- Always check branch before committing (must not be main)
- Implementation blocks in .vibee must match `!void` signature — no typed returns
- Generated modules in `generated/` use `@import("vsa")` module name, not relative paths
- When adding proofs: use `vsa.randomVector(dim, seed)` with deterministic seeds for reproducibility
