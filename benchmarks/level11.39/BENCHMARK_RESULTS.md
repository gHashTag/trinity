# VSA Math Benchmark Results — Level 11.39 (MATH-003)

> Run: `zig build bench-math`
> Date: 2026-02-17
> Branch: ralph/math-framework
> Commit: (fill after run)

---

## Summary

| Metric | Value | Status |
|--------|-------|--------|
| Operations benchmarked | 6 (bind, unbind, bundle2, bundleN, similarity, permute) |  |
| Dimensions tested | 1024, 4096, 10000 |  |
| Memory compression vs f32 | ~20x |  |
| Bundle-N recall curve | N=3..500 |  |
| Convergence validation | bind recovery, bundle3 signal, orthogonality |  |
| Proof verification | 8 proofs timed |  |

---

## How to Run

```bash
zig build bench-math
```

---

## Sections

### 1. Operation Throughput
Measures ops/sec and ns/op for bind, unbind, bundle2, similarity, permute at dimensions 1024, 4096, 10000.

### 2. Bundle-N Throughput
BundleAccumulator performance at N = 3, 5, 10, 25, 50, 100, 250, 500.

### 3. Memory Efficiency
Ternary packed vs Float32 vs Binary vs Theoretical minimum.
Key result: **~20x compression vs float32** at 1.585 bits/trit.

### 4. Recall Curve
How many of N bundled vectors can be recalled (positive cosine similarity with bundle).
Compared against 1/sqrt(N) theoretical model.

### 5. Convergence Validation
Statistical validation over multiple trials:
- Bind/unbind recovery similarity (expected > 0.60)
- Bundle3 input signal retention (expected > 0.15)
- Random vector orthogonality (expected < 0.10)

### 6. Proof Verification Time
Timing for 8 core VSA algebraic proofs (1000 iterations each).

### 7. Comparison Table
Ternary vs Float32 vs Int8 vs Binary — bytes, information density, compression ratios.

---

## Key Advantages Quantified

| Advantage | Ternary | Float32 | Ratio |
|-----------|---------|---------|-------|
| Storage (1024 dim) | 205 bytes | 4096 bytes | 20.0x |
| Bits/element | 1.60 | 32.00 | 20.0x |
| Compute model | Add-only | Multiply-add | Simpler |
| Information density | 1.585 bits/trit | 1.0 bits/bit | 1.585x |

---

## Tech Tree

- **Node:** MATH-003 (VSA Benchmarks vs Competitors)
- **Branch:** Math (40% -> 60%)
- **Unlocks:** MATH-005 (Large-Scale Analogies)

---

*Results will be populated after running `zig build bench-math`.*
*Actual numbers are platform-dependent — run locally for accurate results.*

---
phi^2 + 1/phi^2 = 3 = TRINITY
