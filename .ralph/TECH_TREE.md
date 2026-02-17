# Tech Tree — Ralph Navigation

> Source of truth: `specs/tri/tech_tree_strategy.vibee`
> Last sync: 2026-02-17

---

## 🏗 In Progress
| ID | Name | Branch | Progress | Gain |
|----|------|--------|----------|------|
(none)



## 🚀 Available Nodes
| ID | Name | Branch | Complexity | Gain |
|----|------|--------|------------|------|

|DEV-002|KG-INSIGHT (JSON)|development|3/5|Local triple inspection suite|
|DEV-003|SWARM-WATCH (DHT)|development|4/5|Live DHT & economy monitor|

## ✅ Recently Completed
| ID | Name | Branch | Gain |
|----|------|--------|------|
|**NEXUS-009**|**Workspace Collaboration**|**nexus**|**4 files: workspace.toml extended with [external] openclaw + [agents] ralph/clawd + [ci], config.toml (73 lines agent config), nexus-build.yml CI (matrix 6 modules), spec**|
|----|------|--------|------|
|**MGEN-001**|**FLUENT-PYTHON**|**multilingual**|**Idiomatic Python: dataclasses, type hints, snake_case**|
|**MGEN-002**|**FLUENT-RUST**|**multilingual**|**Idiomatic Rust: structs, traits, Result error handling**|
|**MGEN-003**|**FLUENT-TS**|**multilingual**|**Idiomatic TypeScript: interfaces, ESM, camelCase**|
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
|INF-001|GGUF Parser|inference|Load any GGUF model|
|INF-002|Transformer Forward Pass|inference|Native LLM inference|
|DEP-001|Docker Container|deployment|Portable deployment|
|DEP-002|Fly.io Integration|deployment|Global edge deployment|
|OPT-T01|Ternary Weight Quantization|optimization|20x weight compression|
|OPT-T02|Ternary Matrix Multiplication|optimization|10x matmul speedup (no multiply)|
|OPT-T03|Ternary KV Cache|optimization|16x KV cache compression|
|OPT-T07|Batch Ternary MatMul|optimization|2.28x matmul speedup|
|OPT-M01|Memory-Mapped Loading|optimization|30x faster model load|
|OPT-C01|KV Cache Compression|optimization|5-16x cache compression|
|OPT-S01|Speculative Decoding|optimization|2-3x generation speed|
|OPT-B01|Continuous Batching|optimization|2-3x throughput|
|OPT-PA01|PagedAttention|optimization|4-10x memory efficiency|

## 🔒 Locked (waiting for dependencies)
| ID | Name | Branch | Needs (missing) |
|----|------|--------|----------------|
|CORE-004|JIT Compilation|core|HW-001 ❌|
|INF-005|Speculative Decoding v2|inference|INF-003 ❌, INF-004 ❌|
|OPT-003|Weight Streaming|optimization|OPT-002 ❌|
|DEP-004|Multi-Region Replication|deployment|DEP-003 ❌|
|HW-003|FPGA Acceleration|hardware|HW-001 ❌|

## 📊 Branch Progress
| Branch | Done | Total | % |
|--------|------|-------|---|
|Core|3|4|75%|
|Inference|2|5|40%|
|Deployment|2|4|50%|
|Optimization|12|14|86%|
|Hardware|0|3|0%|
|**Math**|**5**|**5**|**100%**|
|Development|1|3|33%|
|**Symbolic**|**5**|**5**|**100%**|
|Visualization|1|1|100%|
|Nexus|9|10|90%|
|Multilingual|3|3|100%|
|**Total**|**40**|**54**|**74%**|

## 🎯 Recommended Next (highest ROI)
1. **NEXUS-010** Trinity Nexus Architecture documentation
2. **DEV-002** KG-INSIGHT — local triple inspection
3. **MGEN-001** FLUENT-PYTHON — idiomatic Python code generation

---
φ² + 1/φ² = 3 | TRINITY
