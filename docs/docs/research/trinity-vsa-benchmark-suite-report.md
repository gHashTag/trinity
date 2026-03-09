---
title: "VSA Math Benchmark Suite (MATH-003)"
sidebar_label: "VSA Benchmarks"
slug: /research/vsa-benchmark-suite
---

# VSA Math Benchmark Suite — MATH-003

> **Branch:** `ralph/math-framework`
> **Tech Tree Node:** MATH-003
> **Level:** 11.39

---

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Operations benchmarked | 6 (bind, unbind, bundle2, bundleN, similarity, permute) | Complete |
| Dimensions tested | 1024, 4096, 10000 | Complete |
| Memory compression vs float32 | 19.5-20.0x | Verified |
| Bundle-N recall curve | N=3..500 | Complete |
| Convergence validation | 3 tests (bind recovery, bundle3, orthogonality) | Complete |
| Proof verification | 12 proofs timed | Complete |
| Comparison table | Ternary vs Float32 vs Int8 vs Binary | Complete |

---

## What This Means

### For Users
- **20x memory savings** over float32 representations, validated across all tested dimensions
- **Add-only compute** for bind/unbind (no multiply), enabling efficient hardware implementations
- **Quantified recall curves** showing bundle capacity limits at every scale from N=3 to N=500

### For Operators
- Benchmark suite runs via `zig build bench-math` with ReleaseFast optimization
- 7-section suite covers all critical VSA operations
- Results are reproducible with deterministic seeded vectors

### For Researchers
- **Information density**: 1.585 bits/trit (log2(3)), 58.5% more than binary
- **Convergence**: Bind/unbind recovery > 0.60, bundle3 signal > 0.15, orthogonality < 0.10
- **Recall curve**: Empirical vs theoretical 1/sqrt(N) model comparison

---

## Technical Details

### Architecture
The benchmark suite (`benchmarks/bench_math.zig`) imports the core VSA module and bundle optimizer:
- `vsa` module: bind, unbind, bundle2, bundle3, cosineSimilarity, permute
- `bundle_opt` module: BundleAccumulator, bundleN

### Benchmark Sections
1. **Operation Throughput**: ops/sec and ns/op for each VSA primitive at 3 dimensions
2. **Bundle-N Throughput**: Accumulator performance scaling from N=3 to N=500
3. **Memory Efficiency**: Packed ternary (5 trits/byte) vs float32/binary/theoretical
4. **Recall Curve**: Bundle capacity analysis with theory comparison
5. **Convergence Validation**: Statistical validation over multiple trials
6. **Proof Verification Time**: 12 algebraic proofs timed at 1000 iterations each
7. **Comparison Table**: Multi-format information density comparison

### Memory Comparison (dim=1024)

| Format | Bytes | Bits/element | Compression |
|--------|-------|-------------|-------------|
| Ternary packed | 205 | 1.60 | 1.0x (baseline) |
| Float32 | 4096 | 32.00 | 20.0x more |
| Int8 | 1024 | 8.00 | 5.0x more |
| Binary packed | 128 | 1.00 | 0.6x less |

---

## Conclusion

MATH-003 provides a comprehensive, reproducible benchmark suite that quantifies the ternary VSA advantage across all critical dimensions: throughput, memory, recall, and convergence. The 20x memory savings vs float32 and add-only compute model are validated with empirical data.

**Next steps:** Run benchmarks on target hardware platforms, compare with SIMD-optimized implementations (OPT-001).

---

phi^2 + 1/phi^2 = 3 = TRINITY
