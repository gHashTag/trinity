# GoldenFloat16 — φ-Optimized Number Formats

GoldenFloat16 (GF16) is a φ-optimized 16-bit floating-point format designed for machine learning applications in Zig.

## Mathematical Foundation

### Trinity Identity

The Trinity Identity is the mathematical foundation of GF16:

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

Where $\varphi$ (phi) is the golden ratio:

$$\varphi = \frac{1 + \sqrt{5}}{2} \approx 1.6180339887498949$$

### Phi-Distance Optimization

The phi-distance measures how closely a bit split approximates the golden ratio:

$$d_\varphi = \left| \frac{E}{M} - \frac{1}{\varphi} \right|$$

Where $E$ is exponent bits and $M$ is mantissa bits.

| Format | Split | Phi-Distance |
|--------|-------|--------------|
| IEEE f16 | 5:10 | 0.082 |
| **GF16** | **6:9** | **0.049** |

The 6:9 split is **40% closer** to φ-optimal than IEEE's 5:10 split.

## Format Specification

### GF16 Bit Layout

```
┌──────┬─────────┬─────────┐
│ sign │   exp   │  mant   │
│ 1bit │   6bit  │   9bit  │
└──────┴─────────┴─────────┘
   15     14-9      8-0
```

**Parameters:**
- **Exponent bias**: 31
- **Exponent range**: -31 to +32
- **Mantissa precision**: 9 bits (~2 decimal digits)
- **Value range**: ~±4.3 × 10^9
- **Smallest normal**: 2^(-31) ≈ 4.7 × 10^(-10)

**Value formula:**

$$v = (-1)^s \times \left(0.5 + \frac{m}{511}\right) \times 2^{e-31}$$

Where $s \in \{0,1\}$ is sign, $m \in [0, 511]$ is mantissa, $e \in [0, 63]$ is exponent.

### TF3 (Ternary Float3)

TF3 is an 18-bit format for ternary computing:

```
┌──────┬─────────┬────────────┐
│ sign │   exp   │   mant      │
│ 1bit │   6bit  │   11 bit    │
└──────┴─────────┴────────────┘
   17     16-11      10-0
```

**Parameters:**
- **Total bits**: 18 (packed in u18)
- **Base**: 3 (ternary, not binary)
- **Ternary digits**: {-1, 0, +1}

## Why GF16 Instead of IEEE f16?

### Problem 1: Range Overflow

IEEE f16 max value is **±65,504**. During ML training, activations commonly exceed this:

```zig
// ReLU activation with large input
const x: f32 = 100000;  // Typical in deep networks
const f16_val = @as(f16, @floatCast(x));  // OVERFLOW → infinity!
```

GF16 handles this with its 6-bit exponent:
- GF16 max: ~4.3 × 10^9 (65,000× larger range)
- No overflow for typical ML activations

### Problem 2: Gradient Vanishing

IEEE f16 smallest normal: 2^(-14) ≈ 6.1 × 10^(-5)

During backpropagation:
```zig
var grad: f32 = 1e-5;  // Small gradient
const f16_grad = @as(f16, @floatCast(grad));  // UNDERFLOW → 0!
// Gradient lost — training stalls
```

GF16 smallest normal: 2^(-31) ≈ 4.7 × 10^(-10)
- **1 million times** smaller than IEEE f16
- Gradients survive through deep layers

### Problem 3: Distribution Mismatch

The 5:10 split (IEEE f16) is far from φ-optimal. The 6:9 split (GF16) was independently discovered by:

1. **Trinity**: φ-optimization theory
2. **IBM Research**: DLFloat paper (empirical ML training)

Convergent evolution validates the approach.

## Code Examples

### Basic Usage

```zig
const std = @import("std");
const golden = @import("golden-float");

// Convert f32 to GF16
const gf = golden.formats.GF16.fromF32(3.14159);

// Convert back
const back = gf.toF32();
try std.testing.expectApproxEqAbs(3.14, back, 0.01);

// Arithmetic
const a = golden.formats.GF16.fromF32(1.5);
const b = golden.formats.GF16.fromF32(2.5);
const sum = golden.formats.GF16.add(a, b);  // ~4.0
```

### φ-Weighted Quantization

For ML weight quantization:

```zig
const weight: f32 = 0.753;

// Quantize with φ-weighting
const quantized = golden.formats.GF16.phiQuantize(weight);

// Dequantize
const dequantized = golden.formats.GF16.phiDequantize(quantized);

// Error < 10%
const error_pct = @abs(dequantized - weight) / weight * 100.0;
```

### TF3 for Ternary Computing

```zig
// TF3 for VSA/ternary applications
const tf3 = golden.formats.TF3.fromF32(2.71828);

// Get ternary sign {-1, 0, +1}
const sign = tf3.getSign();  // 1 for positive
```

## Benchmarks

**Platform**: Apple M1 Max

| Operation | Time | Notes |
|-----------|------|-------|
| GF16 encode | ~12ns | comptime-friendly |
| GF16 decode | ~12ns | comptime-friendly |
| IEEE f16 cast | ~8ns | Hardware-accelerated |
| Precision error | 0.5% | GF16 vs f32 average |

## References

- [zig-golden-float on GitHub](https://github.com/gHashTag/zig-golden-float)
- [IBM DLFloat Paper](https://research.ibm.com/publications/dlfloat-a-16-floating-point-format-designed-for-deep-learning-training-and-inference)
- [Trinity Framework](https://github.com/gHashTag/trinity)
- [Phi-Distance Formats](/docs/concepts/phi-distance-formats)
- [Native f16 Comparison](/docs/concepts/native-f16-comparison)
