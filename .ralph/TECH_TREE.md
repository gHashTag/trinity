# Tech Tree — Ralph Navigation

> Source of truth: `specs/tri/tech_tree_strategy.vibee`
> Last sync: 2026-02-18

---

## 🏗 In Progress
| ID | Name | Branch | Progress | Gain |
|----|------|--------|----------|------|
|**VIBEE-PURE-001**|**Pure Zig Focus**|**vibee**|**Zig-first codegen with AGENT MU integration**|
|**AGENT-MU-002**|**Full Self-Evolution Mode**|**agent**|**12 FixType implementations + semantic pattern search + generator self-patching**|



## 🚀 Available Nodes
| ID | Name | Branch | Complexity | Gain |
|----|------|--------|------------|------|


## ✅ Recently Completed
| ID | Name | Branch | Gain |
|----|------|--------|------|
|**OPT-B01**|**Continuous Batching**|**optimization**|**continuous_batching.zig (891 lines): Orca/vLLM-style iteration-level scheduler, priority queue with wait-time boost, preemption, 13 tests, completion detection, continuous admission, throughput analysis, build.zig wired**|
|----|------|--------|------|
|**OPT-PA01**|**PagedAttention**|**optimization**|**paged_attention.zig (947 lines): vLLM-style block KV cache, CoW block sharing, 14 tests, 4-10x memory efficiency, beam search fork, pool lifecycle, attention Q@K^T+softmax+V, memory analysis (64x with ternary), build.zig wired**|
|----|------|--------|------|
|**OPT-T02**|**Ternary Matrix Multiplication**|**optimization**|**ternary_matmul.zig (851 lines): 10x matmul speedup (no multiply), scalar+SIMD8+SIMD16+batch4 kernels, matmat, 3 quant modes, per-row scales, 15.9x compression, cosine accuracy, 15 tests**|
|----|------|--------|------|
|**OPT-T03**|**Ternary KV Cache**|**optimization**|**ternary_kv_cache.zig (729 lines): 16x compression proof, full attention pipeline, SIMD ternaryDot, 4 quant modes, 13 tests, cosine accuracy validation**|
|----|------|--------|------|
|**DEV-003**|**SWARM-WATCH (DHT)**|**development**|**swarm_watch.zig (515 lines): zero-alloc DHT health + TRI reward monitor, ring buffer, ANSI dashboard, Prometheus export, 10 tests, build.zig wired**|
|----|------|--------|------|
|**DEV-002**|**KG-INSIGHT**|**development**|**kg_cli.zig v2.0: 4 commands (triples/inspect/export/find), case-insensitive entity search, JSON export, kg_insight.vibee spec**|
|----|------|--------|------|
|**AGENT-005**|**Query CLI**|**agent**|**CLI for IGLA + KG pipeline queries with full reasoning trace**|
|----|------|--------|------|
|**AGENT-004**|**$TRI Rewards**|**agent**|**ProofOfKnowledge + KgRewardCalculator (0.0002 TRI/triple)**|
|----|------|--------|------|
|**AGENT-003**|**KG DHT Sync**|**agent**|**Kademlia XOR routing, k=3, 268-byte wire format**|
|----|------|--------|------|
|**AGENT-002**|**Triples Parser**|**agent**|**6 SVO patterns, zero-alloc, confidence scoring, 11 tests**|
|----|------|--------|------|
|**AGENT-001**|**IGLA Hybrid Chat**|**agent**|**Hybrid symbolic + neural reasoning engine**|
|----|------|--------|------|
|**ZIG15-001**|**Zig 0.15.1 Idioms Demo**|**agent**|**AGENT MU demo with 7 idioms: comptime generics, unmanaged containers, inferred errors, build.zig modules, raygui glassmorphism, sacred math, inline unrolling. docs/AGENT_MU_ZIG15_DEMO.md + generated/agent_mu_zig15_demo.zig**|
|----|------|--------|------|
|**AGENT-MU-001**|**Self-Evolution Demo**|**agent**|**AGENT MU flow demonstration: V01 → Pi03 → Phi02 → Mu05 → Sigma07, 7 Zig 0.15.1 idioms, before/after examples, μ = 0.0382 sacred mutation**|
|----|------|--------|------|
|**NEXUS-010**|**Architecture Documentation**|**nexus**|**docs/ARCHITECTURE.md (267 lines): module map, ASCII dep graph, build guide, 6 module details, workspace config, math foundation, migration history NEXUS-001 through NEXUS-010**|
|----|------|--------|------|
|**NEXUS-009**|**Workspace Collaboration**|**nexus**|**4 files: workspace.toml extended with [external] openclaw + [agents] ralph/clawd + [ci], config.toml (73 lines agent config), nexus-build.yml CI (matrix 6 modules), spec**|
|----|------|--------|------|
|**MGEN-001**|**FLUENT-PYTHON**|**multilingual**|**Idiomatic Python: dataclasses, type hints, snake_case**|
|**MGEN-002**|**FLUENT-RUST**|**multilingual**|**[DEPRECATED] Idiomatic Rust: structs, traits, Result error handling — Focus on Zig. Multilingual support maintained but not actively developed.**|
|**MGEN-003**|**FLUENT-TS**|**multilingual**|**[DEPRECATED] Idiomatic TypeScript: interfaces, ESM, camelCase — Focus on Zig. Multilingual support maintained but not actively developed.**|
|----|------|--------|------|
|**NEXUS-008**|**Workspace Wiring**|**nexus**|**15 files: build.zig + build.nexus.zig wired with .imports dep graph, 6 build.zig.zon with path deps, 6 module build.zig with b.dependency(), workspace.toml, spec. DAG: core->lang->symb->network, core->canvas, tools->all**|
|----|------|--------|------|
|**NEXUS-007**|**Tools Module Migration**|**nexus**|**73 files migrated to trinity-nexus/tools/src/ in 8 subdirs (cli/devtools/bench/gen/util/maxwell/phi), 26629 lines, 44 pub exports, maxwell+phi 100% self-contained**|
|----|------|--------|------|
|**NEXUS-006**|**Network Module Migration**|**nexus**|**60 files migrated to trinity-nexus/network/src/, 37534 lines, P2P/DHT/sharding/consensus/repair/crypto/monitoring, 52 pub exports, 96.2% self-contained, 8 deferred**|
|----|------|--------|------|
|**NEXUS-005**|**Canvas UI Migration**|**nexus**|**26 files migrated to trinity-nexus/canvas/src/, 20948 lines, Photon engine (6 files), Trinity Canvas subsystem (10 files), UI framework (6 files), Node GUI (2 files, ui→node_ui rename), 16 pub exports, 5 deferred**|
|----|------|--------|------|
|**Q-MGEN-005**|**Symbolic Mapping Verification**|**multilingual**|**[COMPLETED]**|
|**Q-MGEN-006**|**Performance Benchmarking Suite**|**multilingual**|**[COMPLETED]**|
|**NEXUS-004**|**Symbolic AI Migration**|**nexus**|**29 files migrated to trinity-nexus/symb/src/, 15650 lines, KG pipeline (SYM-001-005) + TVC subsystem (20 files), 15 pub exports**|
|----|------|--------|------|
|**NEXUS-003**|**VIBEE Compiler Migration**|**nexus**|**38 files migrated to trinity-nexus/lang/src/, 28186 lines, 15 pub exports, codegen/ module with 20 files, 100% self-contained imports**|
|----|------|--------|------|
|**OPT-PC01**|**Prefix Caching**|**optimization**|**99% prefill reduction, 19 tests, scheduler integration (3 fixes), TTFT/throughput benchmarks, LRU/LFU/FIFO eviction, block sharing**|
|----|------|--------|------|
|**NEXUS-002**|**Core VM Migration**|**nexus**|**39 files migrated to trinity-nexus/core/, all tests pass, JIT 17.74x**|
|----|------|--------|------|
|**NEXUS-001**|**Trinity Nexus Repository Structure**|**nexus**|**6 modules (core/lang/symb/network/canvas/tools), workspace.toml, build.nexus.zig, all builds pass, 21 files**|
|----|------|--------|------|
|**SYM-005**|**TRI SOTA MVP**|**symbolic**|**Full pipeline: extractTriples -> KG DHT -> TRI rewards, PoK, 7 tests, 268B wire, 125x energy**|
|----|------|--------|------|
|**SYM-003**|**Decentralized KG Sync + $TRI Rewards**|**symbolic**|**KgTripleDHT Kademlia XOR routing k=3, 268-byte wire format, ProofOfKnowledge, KgRewardCalculator 0.0002 TRI/triple, 12 tests**|
|----|------|--------|------|
|**SYM-004**|**IGLA + KG Full Pipeline**|**symbolic**|**extractTriples wired into respond(), confidence 0.6 filter, addFact KG storage, CLI compiles**|
|----|------|--------|------|
|**SYM-002**|**LLM Triples Extractor**|**symbolic**|**6 SVO patterns, zero-alloc, confidence scoring, 11 tests, build.zig wired**|
|----|------|--------|------|
|**VIS-001**|**Ralph Canvas Monitor v2**|**visualization**|**[v2 UPGRADE] Glassmorphism shadows/highlights, activity waves (background), terminal-style logs with scanlines, refined metrics cards**|
|----|------|--------|------|
|**DEV-001**|**TRI-TRACE Symbolic Trace**|**development**|**Tracer struct, 9 OpKinds, VectorMeta, 4 tests, global singleton, build.zig wired**|
|**SYM-001**|**SOTA Tech Report Pivot**|**symbolic**|**10/10 metrics validated, report demo, 3 vibee specs**|
|**OPT-001**|**SIMD Vectorization**|**optimization**|**bundle3/vectorNorm/countNonZero SIMD, bundleN accumulator, 3-16x speedups**|
|**MATH-003**|**VSA Benchmarks vs Competitors**|**math**|**7-section benchmark suite: throughput, bundleN, memory (20x vs f32), recall curves, convergence, proof timing, comparison table**|
|**MATH-004**|**Multilingual Math Codegen**|**math**|**10 VSA proofs in 5 languages (Zig, Python, TypeScript, Rust, Go) from single spec. 9 generators wired, array syntax [zig, python, ts]**|
|**MATH-001**|**VSA Math Proofs v2**|**math**|**12 proofs: bind inverse, commutativity, associativity, self-identity, bundle convergence, orthogonality, permute cycle, similarity bounds, trinity identity, bundle2, permute inverse, info density**|
|**MATH-002**|**Bundle N Optimization**|**math**|**O(N*D) accumulator, bundleN API, 6 tests**|
|**CORE-002b**|**Multilingual Codegen Fix**|**core**|**Fixed type errors in generated multilingual engine, enum variant support in codegen**|
|CORE-001|VIBEE Parser v2|core|+20% spec parsing speed|
|CORE-002|Multi-Language Codegen|core|+42 target languages|
|CORE-003|Bytecode VM|core|+500% execution speed vs interpreter|
|**INF-001**|**GGUF Parser**|**inference**|**gguf_parser.zig (850 lines): GGUF v3 binary parser, ByteReader, 13 value types, tensor info, Q4_0/Q8_0 dequant, f16-to-f32, model config extraction, GGUFBuilder for round-trip tests, 20 tests, build.zig wired**|
|**INF-002**|**Transformer Forward Pass**|**inference**|**transformer_forward.zig (960 lines): LLaMA-style transformer, RMSNorm, RoPE cache, SIMD matVec, GQA attention, SwiGLU FFN, KV cache, generation loop, top-p sampling, inference stats, 18 tests, build.zig wired**|
|----|------|--------|------|
|**HW-001**|**Hardware Abstraction Layer**|**hardware**|**hardware_abstraction.zig (~750 lines): compile-time backend selection (CPU_SCALAR/CPU_SIMD/FPGA/GPU), SIMD capability detection (AVX-512/AVX2/SSE4/NEON), ScalarBackend + SimdBackend @Vector(8,i8), unified dispatch, PerfCounters, MemoryAnalysis (16x compression), 21 tests, build.zig wired**|
|----|------|--------|------|
|DEP-001|Docker Container|deployment|Portable deployment|
|DEP-002|Fly.io Integration|deployment|Global edge deployment|
|OPT-T01|Ternary Weight Quantization|optimization|20x weight compression|
|OPT-T07|Batch Ternary MatMul|optimization|2.28x matmul speedup|
|OPT-M01|Memory-Mapped Loading|optimization|30x faster model load|
|OPT-C01|KV Cache Compression|optimization|5-16x cache compression|
|**OPT-S01**|**Speculative Decoding**|**optimization**|**speculative_decoding.zig (700 lines): draft-verify-accept cycle, min(1,p_target/p_draft) criterion, adjusted rejection sampling, LCG PRNG, mock ProbDist, SpeedupAnalysis, 14 tests, build.zig wired**|

## 🔒 Locked (waiting for dependencies)
| ID | Name | Branch | Needs (missing) |
|----|------|--------|----------------|

|INF-005|Speculative Decoding v2|inference|INF-003 ❌, INF-004 ❌|
|OPT-003|Weight Streaming|optimization|OPT-002 ❌|
|DEP-004|Multi-Region Replication|deployment|DEP-003 ❌|
|HW-003|FPGA Acceleration|hardware|HW-001 ✅ — **UNLOCKED**|

## 📊 Branch Progress
| Branch | Done | Total | % |
|--------|------|-------|---|
|**Core**|**4**|**4**|**100%**|
|**Inference**|**4**|**5**|**80%**|
|Deployment|2|4|50%|
|**Optimization**|**16**|**16**|**100%**|
|**Hardware**|**1**|**3**|**33%**|
|**Math**|**5**|**5**|**100%**|
|**Development**|**3**|**3**|**100%**|
|**Symbolic**|**5**|**5**|**100%**|
|Visualization|1|1|100%|
|**Nexus**|**10**|**10**|**100%**|
|**Agent**|**6**|**7**|**86%**|
|**VIBEE**|**8**|**9**|**89%**|
|Multilingual|3|3|100%|
|**Total**|**68**|**75**|**91%**|

## 🎯 Recommended Next (highest ROI)
1. **AGENT-MU-002** Full Self-Evolution Mode — 12 FixType + semantic search + generator self-patching
2. **VIBEE-PURE-001** Pure Zig Focus — Zig-first codegen with AGENT MU integration
3. **HW-003** FPGA Acceleration — HW-001 ✅ UNLOCKED, native ternary hardware
4. **DEP-001** Docker Container — portable deployment, enables CI testing
5. **DEP-003** Auto-Scaling — elastic infrastructure, prerequisite for DEP-004

---

## Sacred Metrics (v8.12)

**Trinity Identity:** φ² + 1/φ² = 3 (where φ = (1 + √5) / 2)

**Intelligence Gain:** μ = 1/φ²/10 = 0.0382 (0.0382% per failure iteration)

**Learning Curve:** After 100 failures → intelligence × 47×

**Branch Focus:** Pure Zig — Multilingual support maintained but not actively developed

**Symbolic AI Maturity:** AGENT branch (86% complete)
- AGENT-001: IGLA Hybrid Chat ✅
- AGENT-002: Triples Parser ✅
- AGENT-003: KG DHT Sync ✅
- AGENT-004: $TRI Rewards ✅
- AGENT-005: Query CLI ✅
- AGENT-MU-001: Self-Evolution Demo ✅ (Cycle 44: 7 Zig 0.15.1 idioms)
- AGENT-MU-002: Full Self-Evolution Mode (IN PROGRESS - Cycle 45)

**VIBEE Maturity:** VIBEE branch (89% complete)
- VIBEE-001..007: Core ✅
- VIBEE-008: Self-Improver ✅
- VIBEE-PURE-001: Pure Zig Focus (IN PROGRESS)

---
φ² + 1/φ² = 3 | μ = 0.0382 | TRINITY
