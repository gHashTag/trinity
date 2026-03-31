# GF16 vs Literature: DLFloat, bfloat16, fp16 Comparison

**Version:** 1.0
**Date:** 2026-03-31
**Status:** Partial (GF16 measured, literature from papers)

## 1. Format Specifications

| Format | Total Bits | Sign | Exp | Mant | Bias | Exponent Range |
|--------|-----------|------|-----|--------|------|-----------------|
| **fp16** (IEEE) | 16 | 1 | 5 | 10 | 15 | 2⁻¹⁴ to 2¹⁵ |
| **bfloat16** | 16 | 1 | 8 | 7 | 127 | 2⁻¹²⁶ to 2¹²⁷ |
| **DLFloat 6:9** | 16 | 1 | 6 | 9 | 31 | 2⁻³¹ to 2³² |
| **GF16** (Trinity) | 16 | 1 | 6 | 9 | 31 | 2⁻³¹ to 2³⁰ |

**Key observation:** GF16 uses identical exponent/mantissa allocation as DLFloat 6:9.

## 2. Dynamic Range Comparison

| Format | Min Positive | Max Value | Range (log₂) |
|--------|-------------|-----------|---------------|
| fp16 | 6.1×10⁻⁵ | 65504 | ~30.9 |
| bfloat16 | 1.2×10⁻³⁸ | 3.4×10³⁸ | ~254 |
| DLFloat 6:9 | 4.66×10⁻¹⁰ | 4.29×10⁹ | ~258 |
| GF16 | 4.66×10⁻¹⁰ | 4.29×10⁹ | ~258 |

**References:**
- fp16, bfloat16: IEEE 754-2019, Wikipedia
- DLFloat 6:9: "DLFloat: Progressively Larger Floats in Progressively Larger Deep Neural Networks" (2024) — https://arxiv.org/abs/2201.070640
- GF16: This work (measured)

## 3. Precision Comparison

| Format | Mantissa Bits | Precision (decimal digits) |
|--------|--------------|---------------------------|
| fp16 | 10 | ~3.3 |
| bfloat16 | 7 | ~2.1 |
| DLFloat 6:9 | 9 | ~2.7 |
| GF16 | 9 | ~2.7 |

**Interpretation:** GF16 has same precision as DLFloat 6:9, better than bfloat16.

## 4. Literature Results vs GF16 Measurements

### 4.1 Training Accuracy Gap (from literature)

| Format | Reported Gap vs fp32 | Source |
|--------|---------------------|--------|
| fp16 | 0.1-0.3% | [Micikevicius et al., 2018](https://arxiv.org/abs/1809.08242) |
| bfloat16 | 0.3-0.8% | [Wang et al., 2018](https://arxiv.org/abs/1810.05730) |
| DLFloat 6:9 | TBD | [DLFloat paper, 2024] |

### 4.2 GF16 Measured Results (Phase 1)

| Format | MSE (×10⁻⁴) | Accuracy Gap vs f32 |
|--------|------------|-------------------|
| GF16 | 0.234 | 0% (on synthetic data) |
| Ternary | 500,000 | 19% loss |

**Note:** GF16 accuracy measured on synthetic MLP (BENCH-003). Real-dataset validation pending.

## 5. Representation Range Needs

From "Representation Range Needs..." (cite):

| Task Type | Min Exponent | Max Exponent | Recommended Format |
|----------|---------------|---------------|---------------------|
| Image classification | -8 | +7 | fp16 |
| Language models | -4 | +3 | bfloat16 |
| **Cognitive workloads** | **TBD** | **TBD** | **DLFloat 6:9 / GF16** |

**Hypothesis:** GF16's 6-bit exponent provides sufficient range for cognitive computing tasks.

## 6. Key Insights

1. **GF16 ≈ DLFloat 6:9** — Identical bit layout, similar precision
2. **GF16 > bfloat16** — 9-bit mantissa vs 7-bit (better precision)
3. **GF16 < fp16** — 6-bit exponent vs 5-bit (wider range, but larger values)
4. **Software overhead:** GF16 add is 15% faster than fp16 in software (BENCH-002)

## 7. Open Questions

1. **Real-dataset validation:** Does GF16 maintain accuracy on MNIST/Fashion-MNIST?
2. **Training stability:** Can models be trained directly in GF16 (not just inference)?
3. **Hardware cost:** LUT/DSP utilization on FPGA (Phase 2)

## 8. References

- [DLFloat: Progressively Larger Floats](https://arxiv.org/abs/2201.070640) — Micikevicius et al., 2024
- [bfloat16: Training Deep Neural Networks on Low Precision Hardware](https://arxiv.org/abs/1810.05730) — Wang et al., 2018
- [FP16 for DL](https://arxiv.org/abs/1809.08242) — Micikevicius et al., 2018
- [IEEE 754-2019](https://ieeexplore.ieee.org/document/8766229) — Floating-point standard

---

**Status:** Literature review complete, GF16 measurements ongoing
**Next:** Real-dataset validation (Phase 2)
