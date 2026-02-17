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
|INF-003|KV Cache Optimization|inference|3/5|+50% inference speed|
|INF-004|Batch Processing|inference|4/5|+300% throughput|
|DEP-003|Auto-Scaling|deployment|3/5|Handle traffic spikes|
|OPT-001|SIMD Vectorization|optimization|4/5|+400% matrix ops|
|OPT-002|Memory Pool Allocator|optimization|3/5|-30% memory usage|
|OPT-004|Flash Attention|optimization|5/5|+200% attention speed|
|OPT-005|Quantization Engine|optimization|4/5|Support Q4, Q5, Q6 formats|
|OPT-CP01|Chunked Prefill|optimization|3/5|-50% TTFT latency|
|**MATH-005**|**Large-Scale Analogies (1000+)**|**math**|**4/5**|**Scalable analogy reasoning with VSA**|

## ✅ Recently Completed
| ID | Name | Branch | Gain |
|----|------|--------|------|
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
|HW-001|GPU Backend (CUDA)|hardware|OPT-001 ❌|
|HW-002|Metal Backend (Apple)|hardware|OPT-001 ❌|
|HW-003|FPGA Acceleration|hardware|HW-001 ❌|

## 📊 Branch Progress
| Branch | Done | Total | % |
|--------|------|-------|---|
|Core|3|4|75%|
|Inference|2|5|40%|
|Deployment|2|4|50%|
|Optimization|10|14|71%|
|Hardware|0|3|0%|
|**Math**|**4**|**5**|**80%**|
|**Total**|**21+1ip**|**35**|**60%→63%**|

## 🎯 Recommended Next (highest ROI)
1. **OPT-001** SIMD Vectorization — unlocks 3 nodes (OPT-004, HW-001, HW-002), highest unlock count
2. **MATH-005** Large-Scale Analogies — completes Math branch (80%→100%), unlocked by MATH-003
3. **INF-003** KV Cache Optimization — +50% inference speed, unlocks INF-005

---
φ² + 1/φ² = 3 | TRINITY
