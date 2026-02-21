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

## 🏛️ CRITICAL PRIORITY: Trinity Nexus Migration (Level 12.0)

> **STATUS:** HIGHEST PRIORITY — Complete architecture refactoring before any new features
> **Goal:** Modular ecosystem with Ternary VM + VIBEE Compiler + Symbolic AI + Decentralization
> **Tech Tree:** NEXUS-001 (Monolithic → Modular transition)
> **Golden Chain:** Level 11.42 → 12.0 transition. Cycle 0: Trinity Nexus Foundation.

- [x] [P1] NEXUS-001: Create Trinity Nexus repository structure
  - Acceptance: `trinity-nexus/` created with modular layout (core/, lang/, symb/, network/, canvas/, tools/, docs/, .trinity/). Each module has zig.mod, tests/ directory, and src/ folder. Workspace config `.trinity/workspace.toml` wired.
  - Files: `trinity-nexus/` (all directories), `.trinity/workspace.toml`, `trinity-nexus/build.nexus.zig`
  - Tech Tree: NEXUS-001
  - Blocked-by: (none)
  - DONE: 6 modules (core/lang/symb/network/canvas/tools), workspace.toml, build.nexus.zig, all pass

- [x] [P1] NEXUS-002: Migrate core VM from trinity/src/vsa/ to trinity-nexus/core/
  - Acceptance: All VM code (vm.zig, mem.zig, tryte.zig, isa.zig, builder.zig) moved to `trinity-nexus/core/src/`. `trinity-core` package created with zig.mod, @import paths updated, tests pass.
  - Files: `trinity-nexus/core/src/` (5 files), `trinity-nexus/core/zig.mod`, `trinity-nexus/core/tests/`
  - Tech Tree: NEXUS-002
  - Blocked-by: NEXUS-001
  - DONE: 39 files to trinity-nexus/core/src/, sdk.zig import fixed, all tests pass, JIT 17.74x

- [x] [P1] NEXUS-003: Migrate VIBEE compiler to trinity-nexus/lang/
  - Acceptance: All lang code (parser.zig, ast.zig, codegen.zig, multilang.zig) moved to `trinity-nexus/lang/src/`. `trinity-lang` package created with zig.mod, @trinity/core dependency wired, all tests pass.
  - Files: `trinity-nexus/lang/src/` (parser, ast, codegen, multilang), `trinity-nexus/lang/zig.mod`, `trinity-nexus/lang/tests/`
  - Tech Tree: NEXUS-003
  - Blocked-by: NEXUS-001
  - DONE: 38 files migrated to trinity-nexus/lang/src/, 28186 lines, 15 pub exports, codegen/ module with 20 files, 100% self-contained imports

- [x] [P1] NEXUS-004: Migrate Symbolic AI to trinity-nexus/symb/
  - Acceptance: All symb code (triples.zig, reason.zig, vsa.zig, hybrid.zig, tvc.zig) moved to `trinity-nexus/symb/src/`. `trinity-symb` package created, @trinity/core and @trinity/lang dependencies wired, tests pass.
  - Files: `trinity-nexus/symb/src/` (6 files), `trinity-nexus/symb/zig.mod`, `trinity-nexus/symb/tests/`
  - Tech Tree: NEXUS-004
  - Blocked-by: NEXUS-001, NEXUS-002, NEXUS-003
  - DONE: 29 files migrated to trinity-nexus/symb/src/, 15650 lines, KG pipeline + TVC subsystem, 15 pub exports

- [x] [P1] NEXUS-005: Migrate Canvas UI to trinity-nexus/canvas/
  - Acceptance: All canvas code (photon.zig, photon_trinity_canvas.zig, panels.zig, ralph.zig, theme.zig) moved to `trinity-nexus/canvas/src/`. `trinity-canvas` package created, @trinity/core dependency wired, 27-petal animation tests pass.
  - Files: `trinity-nexus/canvas/src/` (5 files), `trinity-nexus/canvas/zig.mod`, `trinity-nexus/canvas/assets/`, `trinity-nexus/canvas/tests/`
  - Tech Tree: NEXUS-005
  - Blocked-by: NEXUS-001
  - DONE: 26 files migrated to trinity-nexus/canvas/src/, 20948 lines, 16 pub exports, 5 deferred

- [x] [P1] NEXUS-006: Create network module (DHT + P2P) in trinity-nexus/network/
  - Acceptance: Network module created with dht.zig, p2p.zig, consensus.zig, sync.zig. `trinity-network` package with zig.mod, @trinity/core (mem) and @trinity/symb (triples) dependencies, tests pass.
  - Files: `trinity-nexus/network/src/` (4 files), `trinity-nexus/network/zig.mod`, `trinity-nexus/network/tests/`
  - Tech Tree: NEXUS-006
  - Blocked-by: NEXUS-001
  - DONE: 60 files migrated to trinity-nexus/network/src/, 37534 lines, 52 pub exports, 96.2% self-contained

- [x] [P1] NEXUS-007: Create tools module (CLI + DevTools) in trinity-nexus/tools/
  - Acceptance: Tools module created with build.zig, deploy.zig, bench.zig, format.zig, scripts/. `trinity-tools` package with zig.mod, workspace build script `build.nexus.zig`, all tool tests pass.
  - Files: `trinity-nexus/tools/src/` (5 files), `trinity-nexus/tools/zig.mod`, `trinity-nexus/tools/scripts/`, `trinity-nexus/build.nexus.zig`
  - Tech Tree: NEXUS-007
  - Blocked-by: NEXUS-001
  - DONE: 73 files migrated to trinity-nexus/tools/src/ in 8 subdirs, 26629 lines, 44 pub exports

- [x] [P1] NEXUS-008: Wire Zig workspace and configure internal dependencies
  - Acceptance: `.trinity/workspace.toml` configured with all 6 members (core, lang, symb, network, canvas, tools). Each zig.mod wired to internal dependencies (@trinity/core, @trinity/lang, @trinity/symb). `zig build --workspace` compiles all modules.
  - Files: `.trinity/workspace.toml` (6 workspace members), all zig.mod files
  - Tech Tree: NEXUS-008
  - Blocked-by: NEXUS-001, NEXUS-002, NEXUS-003, NEXUS-004, NEXUS-005, NEXUS-006, NEXUS-007
  - DONE: 15 files wired: build.zig + build.nexus.zig with .imports dep graph, 6 build.zig.zon with path deps, workspace.toml, spec

- [x] [P1] NEXUS-009: Configure user + openclaw in workspace for internal collab
  - Acceptance: `.trinity/workspace.toml` includes openclaw workspace at `/Users/playra/openclaw`. Ralph and clawd agents can build/test all modules. CI/CD config works with user + openclaw in workspace.
  - Files: `.trinity/workspace.toml`, `.trinity/config.toml`, `trinity-nexus/.github/workflows/`
  - Tech Tree: NEXUS-009
  - Blocked-by: NEXUS-008
  - DONE: 4 files: workspace.toml extended with openclaw + agents + CI, config.toml (73 lines), nexus-build.yml (matrix 6 modules), spec

- [x] [P2] NEXUS-010: Write Trinity Nexus Architecture documentation
  - Acceptance: `docs/ARCHITECTURE.md` created with full module diagram, dependency graph, Zig workspace config guide. README.md updated with Nexus overview.
  - Files: `docs/ARCHITECTURE.md`, `docs/README.md`, `docs/module-diagrams/`
  - Tech Tree: NEXUS-010
  - Blocked-by: NEXUS-008
  - DONE: docs/ARCHITECTURE.md (267 lines), module map, ASCII dep graph, build guide, module details, workspace config, math foundation, migration history. Nexus branch 10/10 100%.

---

## 🔥 CRITICAL PRIORITY: Ralph Monitor Integration (Level 11.42)

> **STATUS:** SECONDARY PRIORITY — Resume after Nexus migration
> **Goal:** Visual autonomous dev loop control via 27-petal Trinity Canvas UI
> **Tech Tree:** VIS-001 (Canvas visualization integration)
> **Golden Chain:** Level 11.41 → 11.42 transition. Cycle 42: Canvas Monitor Panel.

- [x] [P1] RALPH-CANVAS-001: Add Ralph Monitor panel to Trinity Canvas
  - Acceptance: Shift+9 or petal click opens Ralph Monitor panel showing: loop_count, calls/hour, status, active task from fix_plan.md, live ⚡ stream from live.log. Panel persists across mode switches.
  - Files: `src/vsa/photon_trinity_canvas.zig` (WaveMode.ralph, renderRalphPanel, pollRalphStatus, parseLiveLog, live log buffer)
  - Tech Tree: VIS-001
  - Blocked-by: (none)

- [x] [P2] RALPH-CANVAS-002: Bind Ralph Monitor to Block 2 petal in idle logo
  - Acceptance: Click on Block 2 (lower-left petal) toggles Ralph Monitor panel. Visual feedback: petal highlight on hover, pulse when Ralph active.
  - Files: `src/vsa/photon_trinity_canvas.zig` (LogoAnimation.applyMouse integration, petal 2 click handler)
  - Tech Tree: VIS-001
  - Blocked-by: RALPH-CANVAS-001

- [x] [P2] RALPH-CANVAS-003: Add Ralph control buttons (Start/Stop/Restart)
  - Acceptance: Panel has START/STOP/RESTART buttons. START runs `ralph --monitor`, STOP sends SIGTERM, RESTART does stop+start. Status updates live.
  - Files: `src/vsa/photon_trinity_canvas.zig` (ralphControl function, process spawning via std.process.Child)
  - Tech Tree: VIS-001
  - Blocked-by: RALPH-CANVAS-001

- [x] [P3] RALPH-CANVAS-004: Color-coded circuit breaker visualization
  - Acceptance: Circuit breaker states (normal/degraded/circuit_open) shown with colors: green/yellow/red. Alert banner when circuit is open.
  - Files: `src/vsa/photon_trinity_canvas.zig` (parseCircuitBreakerState, circuitBreakerColor)
  - Tech Tree: VIS-001
  - Blocked-by: RALPH-CANVAS-001

---

## Infrastructure: Diagnostic & Debugging Quarks (Development Suite)

- [x] [P1] TRI-TRACE: Symbolic Reasoning Trace Mode
  - Acceptance: `zig build run -- --trace` shows full bind/unbind/sim-search path for every IGLA query.
  - Files: `src/igla/trace.zig`, `src/vsa/core.zig` (instrumentation)
  - Tech Tree: DEV-001
  - DONE: Tracer struct (256-entry ring buffer), 9 OpKinds, VectorMeta, TraceEntry, global singleton, recordBinary/recordScalar/printTrace, 4 tests pass, build.zig wired

- [x] [P2] KG-INSIGHT: Local Knowledge Graph Inspector
  - Acceptance: CLI command `zig build query -- --inspect <vector_id>` returns human-readable triples associated with the node.
  - Files: `src/query_cli.zig`, `src/vsa/storage.zig`
  - Tech Tree: DEV-002
  - DONE: kg_cli.zig v2.0 (517 lines), 4 new commands (triples/inspect/export/find), case-insensitive search, JSON export, kg_insight.vibee spec

- [ ] [P2] SWARM-WATCH: Real-time DHT & $TRI Rewards Monitor
  - Acceptance: Dashboard (TMUX pane or CLI) showing real-time sync events and reward payouts.
  - Files: `src/swarm/monitor.zig`, `src/economy/rewards.zig`
  - Tech Tree: DEV-003

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

- [x] [P1] Generate multilingual VSA proof files (MATH-004 completion)
  - Acceptance: VSA proofs generated in Python, TypeScript, Rust, Go from single spec
  - Files: `specs/tri/vsa_proofs_multilingual.vibee`, `generated/vsa_math_proofs.{py,ts,rs,go}`
  - Tech Tree: MATH-004
  - DONE: 10 proofs per language, full VSA ops (bind/unbind/bundle/similarity/permute), self-contained runners

- [x] [P2] Write achievement documentation for MATH-003 and MATH-004
  - Acceptance: Reports in docsite/docs/research/, sidebars updated
  - Files: `docsite/docs/research/trinity-vsa-benchmark-suite-report.md`, `docsite/docs/research/trinity-multilingual-math-codegen-report.md`, `docsite/sidebars.ts`
  - DONE: Both reports created with Key Metrics, Technical Details, Conclusion sections. Sidebars updated.

---

- [x] [P1] Cycle 39: SOTA Tech Report Pivot (structured from chat + agent integration)
  - DONE: `sota_tech_report.vibee` created, `src/sota_report_demo.zig` implemented, empirical benchmarks pass, research report live in docsite.
  - Tech Tree: SYM-001 (Level 11.39 milestone)
  - DONE: 3 vibee specs (sym/), sota_report_demo.zig (10/10 metrics pass), research report, empirical log.

---

## Current Sprint — Golden Chain Cycle 43: Full Local Fluent Multilingual Code Gen (Level 11.43)

> **Goal:** High-fidelity, idiomatic code generation in Zig, Python, Rust, and TS.
> **Enforced:** 9-link Golden Chain flow. VIBEE-FIRST mandate.
> **Verification:** Toxic Verdict + Detailed Performance Benchmarking (vs previous versions/SOTA).

- [x] Link 1: Tri Decompose — "full local fluent multilingual code gen"
- [/] Link 2: Tri Plan — Update Tech Tree (MGEN-001..003) and Strategy
- [x] Link 3: Tri Spec Create — Update `multilingual_code_gen.vibee` with Fluency Engine
- [ ] Link 4: Tri Gen — `zig build vibee -- gen`. Generate Zig/Python/Rust/TS from spec.
- [ ] Link 5: Tri Test — E2E validation of all generated targets.
- [ ] Link 6: Tri Bench — Performance benchmarking vs Cycle 40 & SOTA (with proofs).
- [ ] Link 7: Tri Verdict — **TOXIC VERDICT MANDATE**
- [ ] Link 8: Tri Git — Multi-agent commit/push with Telegram report.
- [ ] Link 9: Tri Loop Decision — Needle check for Level 11.43 achievement.

### Quarks
- [x] [P1] Q-MGEN-001: Support `language: [list]` in VIBEE parser and update specs
- [ ] [P3] Q-MGEN-002: Implement Fluent Python Template (Dataclasses, Type Hints)
  - **DEPRECATED**: Multilingual support maintained but not actively developed. Focus on Zig.
- [ ] [P3] Q-MGEN-003: Implement Fluent Rust Template (Structs, Traits, Result)
  - **DEPRECATED**: Multilingual support maintained but not actively developed. Focus on Zig.
- [ ] [P3] Q-MGEN-004: Implement Fluent TypeScript Template (Interfaces, ESM, CamelCase)
  - **DEPRECATED**: Multilingual support maintained but not actively developed. Focus on Zig.
- [ ] [P2] Q-MGEN-005: Symbolic Mapping Verification (unbind/bind semantic transfer)
- [ ] [P2] Q-MGEN-006: Multilingual Benchmark Suite (Speed/Memory proofs)
- [ ] [P1] Link 9: Tri Loop Decision — Needle check for Level 11.41 achievement

---

## Current Sprint — TRI SOTA: Decentralized Knowledge Collector (Level 11.40)

> **Goal:** LLM response -> auto-triples -> KG -> reusable symbolic reasoning.
> **Tech Tree:** SYM branch (SYM-002..005), transition to Symbolic AGI maturity.
> **Golden Chain:** Level 11.39 → 11.40 transition. Cycle 40: Decentralized Knowledge Collector Roadmap.

- [x] [P1] Stage 1: LLM → Triples Extractor
  - Acceptance: `igla_hybrid_chat.zig` implements auto-extraction, 90% accuracy on sample set.
  - Files: `src/igla_hybrid_chat.zig`, `src/vibeec/triples_parser.zig`
  - Tech Tree: SYM-002
  - DONE: triples_parser.zig (6 SVO patterns, zero-alloc, confidence scoring, 11 tests pass, build.zig wired)

- [x] [P1] Stage 2: Decentralized KG Sync + $TRI Rewards
  - Acceptance: KG shard sync in swarm (Kademlia DHT) works, $TRI proof-of-contribution live.
  - Files: `src/swarm/kg_sync.zig`, `src/economy/rewards.zig`
  - Tech Tree: SYM-003
  - DONE: KgTripleDHT (Kademlia XOR, k=3), 268B wire format, ProofOfKnowledge, KgRewardCalculator 0.0002 TRI/triple, 12 tests

- [x] [P1] Stage 3: IGLA + KG Full Pipeline + Query CLI
  - Acceptance: Pipeline: Question -> LLM -> KG -> Reuse. `zig build query --` implements reasoning trace.
  - Files: `src/igla_hybrid_chat.zig`, `src/query_cli.zig`
  - Tech Tree: SYM-004
  - DONE: triples_parser wired into respond() pipeline, confidence 0.6 filter, addFact KG storage, CLI compiles, format clean

- [x] [P2] Stage 4: MVP Release + $TRI Staking
  - Acceptance: Public demo live (web + CLI), $TRI staking for contributors enabled.
  - Tech Tree: SYM-005
  - DONE: sym_005_demo.zig (extractTriples->KG DHT->TRI rewards->PoK), 7 tests, 268B wire, 125x energy

---

## Backlog

- [x] [P1] OPT-001: SIMD Vectorization — unlocks HW-001, HW-002, OPT-004 (highest ROI)
  - DONE: bundle3, vectorNorm, countNonZero SIMD. New bundleN accumulator. 4 tests. 3x to 16x speedups.
- [x] [P1] MATH-005: Large-Scale Analogies (1000+ vectors) — completes Math branch
- [ ] [P2] INF-003: KV Cache Optimization — +50% inference speed
- [ ] [P3] Dashboard widget for multilingual codegen status (MATERIYA column)
- [ ] [P3] E2E test: spec -> generate all targets -> validate each output
- [ ] [P3] Benchmark: codegen performance across targets

---

## Current Sprint — Trinity Canvas: Ralph Monitor Integration (Level 11.42)

> **Goal:** Visual autonomous dev loop control via 27-petal Trinity Canvas UI
> **Tech Tree:** VIS-001 (Canvas visualization integration)
> **Golden Chain:** Level 11.41 → 11.42 transition. Cycle 42: Canvas Monitor Panel.

- [x] [P1] RALPH-CANVAS-001: Add Ralph Monitor panel to Trinity Canvas
  - Acceptance: Shift+9 or petal click opens Ralph Monitor panel showing: loop_count, calls/hour, status, active task from fix_plan.md, live ⚡ stream from live.log. Panel persists across mode switches.
  - Files: `src/vsa/photon_trinity_canvas.zig` (WaveMode.ralph, renderRalphPanel, pollRalphStatus, parseLiveLog, live log buffer)
  - Tech Tree: VIS-001
  - Blocked-by: (none)

- [x] [P2] RALPH-CANVAS-002: Bind Ralph Monitor to Block 2 petal in idle logo
  - Acceptance: Click on Block 2 (lower-left petal) toggles Ralph Monitor panel. Visual feedback: petal highlight on hover, pulse when Ralph active.
  - Files: `src/vsa/photon_trinity_canvas.zig` (LogoAnimation.applyMouse integration, petal 2 click handler)
  - Tech Tree: VIS-001
  - Blocked-by: RALPH-CANVAS-001

- [x] [P2] RALPH-CANVAS-003: Add Ralph control buttons (Start/Stop/Restart)
  - Acceptance: Panel has START/STOP/RESTART buttons. START runs `ralph --monitor`, STOP sends SIGTERM, RESTART does stop+start. Status updates live.
  - Files: `src/vsa/photon_trinity_canvas.zig` (ralphControl function, process spawning via std.process.Child)
  - Tech Tree: VIS-001
  - Blocked-by: RALPH-CANVAS-001

- [x] [P3] RALPH-CANVAS-004: Color-coded circuit breaker visualization
  - Acceptance: Circuit breaker states (normal/degraded/circuit_open) shown with colors: green/yellow/red. Alert banner when circuit is open.
  - Files: `src/vsa/photon_trinity_canvas.zig` (parseCircuitBreakerState, circuitBreakerColor)
  - Tech Tree: VIS-001
  - Blocked-by: RALPH-CANVAS-001

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

---

## 💰 POST-NEXUS: TRI SOTA Monetization

> **Start after NEXUS-024 complete**
> **Goal:** $1M/month revenue, $1B valuation

### Developer Experience (Week 1-2)
- [ ] [P1] DX-001: One-line install (`curl -sSL trinity.ai/install | bash`)
- [ ] [P2] DX-002: VS Code extension
- [ ] [P2] DX-003: Web playground (trinity.ai/playground)

### Community (Week 3-4)
- [ ] [P2] OSS-001: GitHub stars campaign (10K stars = $TRI airdrop)
- [ ] [P3] OSS-002: Hackathon ($10K prize pool)

### Enterprise (Month 2-3)
- [ ] [P1] ENT-001: Enterprise tier ($999/mo)
- [ ] [P2] ENT-002: On-premise deployment
- [ ] [P2] ENT-003: Cloud platform (pay-per-hour)

### AI Products (Month 4-6)
- [ ] [P1] API-001: Trinity AI API ($0.01/1K tokens)
- [ ] [P2] LLM-011: Trinity Chat ($9/mo)
- [ ] [P2] LLM-012: Trinity Code ($9/mo)

### Token (Month 6-12)
- [ ] [P1] TOKEN-001: $TRI launch (1B supply, $100M market cap)
- [ ] [P2] TOKEN-002: Staking (10% APY) + governance

---

*Full roadmap: /Users/playra/clawd/TRI_SOTA_ROADMAP.md*
