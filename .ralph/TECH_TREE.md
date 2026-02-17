# Tech Tree — Ralph Navigation

> Source of truth: `specs/tri/tech_tree_strategy.vibee`
> Last sync: 2026-02-17

---

## 🏗 In Progress
| ID | Name | Branch | Progress | Gain |
|----|------|--------|----------|------|
|OPT-PC01|Prefix Caching|optimization|2/5|99% prefill reduction for cached prompts|



## 🚀 Available Nodes
| ID | Name | Branch | Complexity | Gain |
|----|------|--------|------------|------|

|DEV-002|KG-INSIGHT (JSON)|development|3/5|Local triple inspection suite|
|DEV-003|SWARM-WATCH (DHT)|development|4/5|Live DHT & economy monitor|

## ✅ Recently Completed
| ID | Name | Branch | Gain |
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
|**VIS-001**|**Ralph Canvas Monitor**|**visualization**|**Fullscreen Ralph panel: WaveMode.ralph, Shift+9, Block 2 petal click, START/STOP/RESTART buttons, tri-state circuit breaker (green/yellow/red), alert banners, live log display**|
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
|Optimization|11|14|79%|
|Hardware|0|3|0%|
|**Math**|**5**|**5**|**100%**|
|Development|1|3|33%|
|**Symbolic**|**5**|**5**|**100%**|
|Visualization|1|1|100%|
|Nexus|2|10|20%|
|**Total**|**32**|**54**|**59%**|

## 🎯 Recommended Next (highest ROI)
1. **NEXUS-003** Migrate VIBEE compiler to trinity-nexus/lang/ (unblocked by NEXUS-002)
2. **DEV-002** KG-INSIGHT — local triple inspection, pairs with completed Symbolic branch
3. **OPT-PC01** Prefix Caching — already 2/5 in progress, 99% prefill reduction
4. **DEV-003** SWARM-WATCH — live DHT and economy monitor, pairs with SYM-003

---
φ² + 1/φ² = 3 | TRINITY
