# zig-half — Trinity ML Formats Standalone Package

[![Zig](https://ziglang.org/documentation/0.15.2/)
[![Trinity](https://github.com/gHashTag/trinity)

**Standalone Package** for φ-optimized ML number formats (GF16, TF3-9)

## Contents

This package consolidates Trinity's ML format implementations from multiple locations:
- `src/sacred/sacred_types.zig` — Original sacred type definitions
- `external/zig-hslm/src/f16_utils.zig` — Official HSLM library
- `src/hslm/f16_utils.zig` — Brain region format integration
- `src/formats/golden_float16.zig` — **Consolidated source**

## Formats

### GF16 (Golden Float16)

**Bit Layout:**
```
┌──────┬─────────┬─────────┐
│ sign │   exp   │  mant   │
│ 1bit │   6bit  │   9bit  │
└──────┴─────────┴─────────┘
```

**Parameters:**
- Exponent bias: 31 (0x1F)
- Min positive: 2^(-31) ≈ 4.66e-10
- Max value: ~2^31 × 1.999 ≈ 4.29e9
- phi-distance: |exp/mant - 1/φ| ≈ 0.049 (close to φ-optimal)

**Why φ-optimal?**
GF16 uses 9 mantissa bits vs IEEE f16's 10. This provides:
- Better distribution (phi-distance: 0.049 vs 0.082 for IEEE)
- φ² + 1/φ² = 3 | Trinity Identity

### TF3 (Ternary Float3)

**Bit Layout:**
```
┌──────┬─────────┬────────────┐
│ sign │   exp   │   mant      │
│ 1bit │   6bit  │   11 bit    │
└──────┴─────────┴────────────┘
```
(18 bits total)

**Structure:**
- sign: 1 sign bit
- exp: 6 exponent bits (values -31..+32, base 3)
- mant: 11 mantissa bits (ternary digits: {-1, 0, +1})

**Encoding:**
```
trit value | TF3 encoding
----------|-------------
   -1     | NEG = 2 (binary: 10)
    0     | ZERO = 0
   +1     | POS = 1
```

**Usage:**
```zig
const std = @import("std");
const golden = @import("golden_float16.zig");

// GF16: φ-optimized 16-bit
const gf = golden.GF16.fromF32(3.14159);
const gf_f32 = gf.toF32();

// TF3: packed ternary (18-bit)
const tf3 = golden.TF3.fromF32(2.71828);
const tf3_f32 = tf3.toF32();
```

## Integration with Trinity

```zig
const std = @import("std");
const golden = @import("golden_float16.zig");

// For HSLM training
const quantized_weight = golden.GF16.phiQuantize(weight);
const dequantized = golden.GF16.phiDequantize(quantized_weight);

// For ternary VSA operations
const tf3_tensor = golden.TF3.fromF32(1.5);
```

## Mathematical Foundation

**Trinity Identity:**
```
φ² + 1/φ² = 3
```

Where:
- φ (PHI) = (1 + √5) / 2 ≈ 1.6180339887498949
- φ² (PHI_SQ) = φ × φ ≈ 2.61803398874989495
- 1/φ² (PHI_INV) ≈ 0.6180339887498949

## Comparison with Native Formats

| Format | Bits | Range | Precision |
|--------|-------|--------|----------|
| IEEE f16 | 16 | -65,504 to 65,504 | 1 mantissa bit (±5 sign) |
| GF16 | 16 | ~0.0005 to 4.29e9 | 9 mantissa bits (±5 sign) |
| TF3 | 18 | ~0 to 2^31 × 1.999 | Ternary {-1, 0, +1} |

## License

Same as Trinity — See LICENSE file in repository root.

## References

- [IBM DLFloat Paper](https://research.ibm.com/publications/dlfloat-a-16-floating-point-format-designed-for-deep-learning-training-and-inference)
- [Trinity Architecture](https://github.com/gHashTag/trinity/blob/main/docs/research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md)
- [Zig 0.15 Documentation](https://ziglang.org/documentation/0.15.2/)
