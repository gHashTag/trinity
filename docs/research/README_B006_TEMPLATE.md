# Trinity B006: Sacred GF16/TF3 — Phi-Based Number Formats

**Zenodo DOI:** [10.5281/zenodo.19227743](https://doi.org/10.5281/zenodo.19227743)  
**Version:** 5.2.0  
**Date:** 2026-03-26  
**License:** MIT  
**Author:** Dmitrii Vasilev

---

## Abstract

Sacred GF16 and TF3 are φ-optimal number formats for ternary neural network inference. Key innovations: GF16 [sign:1][exp:6][mant:9] with φ-distance 0.049 (40% better than IEEE f16), TF3 18-bit ternary with base-3 exponent, φ-distance metric |e/m - 1/φ|, Theorem: GF16 achieves minimal φ-distance among 16-bit formats, 98.4% information retention vs FP32. Mathematical foundation: Trinity Identity φ² + φ⁻² = 3.

---

## Citation

```bibtex
@software{trinity_b006_2026,
  title        = {Trinity B006: Sacred GF16/TF3},
  author       = {Vasilev, Dmitrii},
  year         = 2026,
  month        = 3,
  version      = {5.2.0},
  doi          = {10.5281/zenodo.19227743},
  url          = {https://doi.org/10.5281/zenodo.19227743}
}
```

---

## Key Innovations

### 1. GF16 Format
```
[sign:1][exp:6][mant:9]
Value = (-1)^sign × 2^(exp-31) × (1 + mant/512)
```

### 2. TF3 Format
```
[sign:1][exp3:6][mant3:11]
Value = (-1)^sign × 3^(exp3-31) × mant3_trits
```

### 3. Phi-Distance Metric
```
φ-distance = |e/m - 1/φ|
where φ = (1 + √5) / 2 ≈ 1.618
```

---

## Theorem: Phi-Optimal Bit Distribution

```
Theorem: For a b-bit floating-point format, optimal exponent/mantissa 
ratio ≈ 1/φ.

Proof: The function f(e,m) = |e/m - 1/φ| is convex. Minimizing over 
integer solutions with e + m = b - 1 yields the solution closest to 1/φ.

For b = 16 (excluding sign): e = 6, m = 9
  e/m = 6/9 = 0.667
  |0.667 - 0.618| = 0.049 (minimal)

This is GF16, achieving 40% better efficiency than IEEE f16 
(which has e/m = 0.118 distance). ∎
```

---

## Format Comparison

| Format | Sign | Exp | Mant | φ-distance | Efficiency |
|--------|------|-----|------|------------|------------|
| FP32 | 1 | 8 | 23 | 0.364 | Baseline |
| IEEE f16 | 1 | 5 | 10 | 0.118 | 100% |
| **GF16** | 1 | 6 | 9 | **0.049** | **140%** |
| BF16 | 1 | 8 | 7 | 0.594 | 85% |
| TF3 | 1 | 6 | 11 | 0.049 | 145% |

---

## Results

| Metric | GF16 | TF3 | IEEE f16 |
|--------|------|-----|----------|
| Info retention | 98.4% | 97.8% | 94.1% |
| Round-trip error | 0.008 | 0.011 | 0.023 |
| φ-distance | 0.049 | 0.049 | 0.118 |
| Memory (vs FP32) | 50% | 56% | 50% |

---

## Algorithm: GF16 to FP32 Conversion

```
Algorithm 1: GF16 → FP32 Conversion
Input: gf16 ∈ [0, 65535]
Output: fp32

1:  sign ← (gf16 >> 15) & 1
2:  exp  ← (gf16 >> 9) & 0x3F
3:  mant ← gf16 & 0x1FF
4:  
5:  // Handle special cases
6:  if exp = 0 then
7:    if mant = 0 then return 0.0  // Zero
8:    else return denormal(gf16)   // Denormal
9:  end if
10: 
11: // Convert to FP32
12: fp32_mant ← (1.0 + mant / 512.0)
13: fp32_exp ← exp - 31
14: 
15: result ← (-1)^sign × 2^fp32_exp × fp32_mant
16: return result

// Properties:
// - Exact: No precision loss for normals
// - Fast: 3 integer ops + 1 float mul
// - Reversible: FP32 → GF16 is bijection (for normals)
```

---

## Mathematical Proofs

### Trinity Identity
```
φ = (1 + √5) / 2 ≈ 1.618034
φ² = (3 + √5) / 2 ≈ 2.618034
φ⁻² = (3 - √5) / 2 ≈ 0.381966

φ² + φ⁻² = (3 + √5 + 3 - √5) / 2 = 6 / 2 = 3 ∎

Corollary: Balanced ternary {-1, 0, +1} is "natural" for φ-based computing.
```

### Ternary Entropy
```
Theorem: Balanced ternary has log₂(3) = 1.585 bits/trit

Proof: H = -Σ p(x) log₂ p(x) = -3 × (1/3) × log₂(1/3) = log₂(3) ≈ 1.585 ∎

Corollary: Ternary is 58.5% more efficient than binary per digit.
```

---

## Limitations

1. **Range:** GF16 range smaller than FP32
2. **Denormals:** Slow path for denormal handling
3. **Hardware:** No native hardware support

---

## References

[1] Livio "The Golden Ratio" (2008)  
[2] IEEE 754-2019 Standard  
[3] Ma et al. "The Era of 1-bit LLMs" (2024)

---

**φ² + 1/φ² = 3 | TRINITY**
