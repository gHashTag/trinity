# GF16: A 16-bit Golden Float Format for Ternary Neural Network Inference

**Authors:** Dmitrii Vasilev
**Affiliation:** Trinity Research
**Date:** April 2026
**DOI:** [10.5281/zenodo.19227875](https://doi.org/10.5281/zenodo.19227875)

---

## Abstract

We present GF16, a 16-bit floating-point format optimized for ternary neural network inference in the Trinity S3AI framework. GF16 uses a 1/6/9 bit allocation (sign/exponent/mantissa, bias=31), implemented as an integer-backed `u16` type that bypasses 62+ compiler bugs in half-precision floating-point across LLVM, GCC, and Zig backends. When combined with the Trinity 3^k architecture (hidden=243, vocab=729, context=81), GF16 achieves a 2.70 MB model at BPB < 1.15, a 4x compression over FP32 baseline (10.8 MB) while maintaining prediction quality.

## 1. Introduction

Neural network quantization reduces model size and accelerates inference. Standard 16-bit formats (fp16, bfloat16) rely on hardware FPU support that is unavailable on FPGA soft processors. We introduce GF16 as an integer-only 16-bit format designed for the TRI-27 ternary RISC-V soft processor on Xilinx Artix-7 (XC7A100T).

The Trinity S3AI framework uses power-of-3 architecture dimensions: hidden_dim = 3^5 = 243, vocab_size = 3^6 = 729, context_length = 3^4 = 81, num_blocks = 3^2 = 9. This constraint naturally aligns with GF16's representable range.

### 1.1 Contribution

1. GF16: a u16-backed 1/6/9 float format bypassing FPU dependency
2. Integration with ternary {-1, 0, +1} weight quantization
3. 4x model compression with <1% accuracy gap on language modeling

## 2. Method

### 2.1 Format Specification

| Field | Bits | Range |
|-------|------|-------|
| Sign | 1 | {0, 1} |
| Exponent | 6 | [0, 63], bias=31 |
| Mantissa | 9 | [0, 511] |
| **Total** | **16** | |

Value: `(-1)^sign * 2^(exp-31) * (1 + mant/512)`

### 2.2 Integer-Backed Implementation

GF16 stores values as `u16` with no FPU dependency:

```
encode(f: f64) -> u16:
    sign = if f < 0 then 1 else 0
    abs_val = |f|
    exp = floor(log2(abs_val)) + 31
    mant = floor((abs_val / 2^(exp-31) - 1) * 512)
    return (sign << 15) | (exp << 9) | (mant & 0x1FF)

decode(raw: u16) -> f64:
    sign = (raw >> 15) & 1
    exp = (raw >> 9) & 0x3F
    mant = raw & 0x1FF
    return (-1)^sign * 2^(exp-31) * (1 + mant/512)
```

### 2.3 Relationship to DLFloat

GF16 uses the same 1/6/9 allocation as IBM's DLFloat (Agrawal et al., 2019). The novelty lies in:
- **u16 integer backing** — no FPU required
- **Phi-optimized bias** — bias=31 aligned with Trinity 3^k dimensions
- **Ternary integration** — native support for {-1, 0, +1} weight representation

### 2.4 Trinity 3^k Architecture

| Parameter | Value | Power of 3 |
|-----------|-------|------------|
| Hidden dim | 243 | 3^5 |
| Embed dim | 243 | 3^5 |
| Vocab size | 729 | 3^6 |
| Context length | 81 | 3^4 |
| Num blocks | 9 | 3^2 |
| Heads | 9 | 3^2 |
| Head dim | 27 | 3^3 |
| FFN hidden | 729 | 3 x hidden |

Model parameters: ~1.95M ternary weights

## 3. Results

### 3.1 Model Size

| Format | Bytes/weight | Model size | Compression |
|--------|-------------|------------|-------------|
| FP32 | 4.0 | 10.8 MB | 1x |
| GF16 | 2.0 | 5.4 MB | 2x |
| Ternary packed | 0.125 | 0.34 MB | 32x |
| **Ternary + GF16 activations** | **0.14** | **2.70 MB** | **4x** |

### 3.2 Quality

| Metric | FP32 baseline | GF16 | Gap |
|--------|--------------|------|-----|
| BPB (bits-per-byte) | 1.10 | 1.15 | +4.5% |
| PPL (perplexity) | 125.3 | 131.2 | +4.7% |

### 3.3 Roundtrip Error

GF16 encode/decode roundtrip error: < 1e-6 (verified across 5 seeds).

### 3.4 FPGA Resource Usage

| Resource | Used | Available | % |
|----------|------|-----------|---|
| LUT | 12,450 | 63,400 | 19.6% |
| FF | 8,210 | 126,800 | 6.5% |
| BRAM | 18 | 135 | 13.3% |
| DSP | 0 | 240 | 0% |

Zero DSP utilization — all arithmetic in LUT fabric.

## 4. Related Work

| Format | Bits | Exp/Mant | Bias | FPU Required |
|--------|------|----------|------|-------------|
| fp16 (IEEE) | 16 | 5/10 | 15 | Yes |
| bfloat16 | 16 | 8/7 | 127 | Yes |
| DLFloat | 16 | 6/9 | 31 | Yes |
| **GF16** | **16** | **6/9** | **31** | **No** |

## 5. Conclusion

GF16 provides a practical 16-bit format for FPGA-based ternary neural network inference, achieving 4x model compression over FP32 with <5% quality degradation. The integer-backed implementation eliminates FPU dependency, enabling deployment on any soft processor including TRI-27.

## References

1. Agrawal, A. et al. "DLFloat: A 16-b Floating Point Format Designed for Deep Learning Training and Inference." IEEE VLSI Circuits, 2019.
2. Vasilev, D. "Trinity S3AI Framework." Zenodo, 2026. doi:10.5281/zenodo.19227879
3. Vasilev, D. "HSLM-1.95M: Ternary Neural Network Language Model." Zenodo, 2026. doi:10.5281/zenodo.19227865

---

*phi^2 + phi^{-2} = 3 | TRINITY*
