# K-Quantization Support

**Date**: 2026-02-04
**Formula**: φ² + 1/φ² = 3

---

## Supported Quantization Types

| Type | Block Size | Bytes/Block | Bits/Weight | Status |
|------|------------|-------------|-------------|--------|
| F32 | 1 | 4 | 32 | ✅ |
| F16 | 1 | 2 | 16 | ✅ |
| Q8_0 | 32 | 34 | 8.5 | ✅ |
| Q4_0 | 32 | 18 | 4.5 | ✅ |
| **Q4_K** | 256 | 144 | 4.5 | ✅ NEW |
| **Q5_K** | 256 | 176 | 5.5 | ✅ NEW |
| **Q6_K** | 256 | 210 | 6.6 | ✅ NEW |
| TQ1_0 | 32 | 8 | 2.0 | ✅ |
| Q2_K | 256 | - | - | ❌ |
| Q3_K | 256 | - | - | ❌ |

---

## Q4_K Format

```
Block structure (256 elements, 144 bytes):
┌─────────────────────────────────────────────────────────────────┐
│ Offset │ Size │ Description                                    │
├────────┼──────┼────────────────────────────────────────────────┤
│ 0      │ 2    │ d (f16) - super-block scale                    │
│ 2      │ 2    │ dmin (f16) - super-block min                   │
│ 4      │ 12   │ scales[12] - 8 sub-block scales + 4 mins       │
│ 16     │ 128  │ qs[128] - 256 4-bit quantized values           │
└────────┴──────┴────────────────────────────────────────────────┘

Sub-block structure:
- 8 sub-blocks of 32 elements each
- Each sub-block has 6-bit scale and 6-bit min
- Dequantization: x = q * d * scale - dmin * min
```

---

## Q5_K Format

```
Block structure (256 elements, 176 bytes):
┌─────────────────────────────────────────────────────────────────┐
│ Offset │ Size │ Description                                    │
├────────┼──────┼────────────────────────────────────────────────┤
│ 0      │ 2    │ d (f16) - super-block scale                    │
│ 2      │ 2    │ dmin (f16) - super-block min                   │
│ 4      │ 12   │ scales[12] - sub-block scales/mins             │
│ 16     │ 32   │ qh[32] - high bits (5th bit)                   │
│ 48     │ 128  │ qs[128] - low 4 bits                           │
└────────┴──────┴────────────────────────────────────────────────┘
```

---

## Q6_K Format

```
Block structure (256 elements, 210 bytes):
┌─────────────────────────────────────────────────────────────────┐
│ Offset │ Size │ Description                                    │
├────────┼──────┼────────────────────────────────────────────────┤
│ 0      │ 128  │ ql[128] - low 4 bits                           │
│ 128    │ 64   │ qh[64] - high 2 bits                           │
│ 192    │ 16   │ scales[16] - 8-bit scales                      │
│ 208    │ 2    │ d (f16) - super-block scale                    │
└────────┴──────┴────────────────────────────────────────────────┘
```

---

## Performance

### Dequantization Speed (estimated)

| Type | Scalar | SIMD | Speedup |
|------|--------|------|---------|
| Q4_K | 1.0x | 2.5x | +150% |
| Q5_K | 1.0x | 2.0x | +100% |
| Q6_K | 1.0x | 1.8x | +80% |

### Memory Comparison (7B model)

| Format | Size | vs FP16 |
|--------|------|---------|
| FP16 | 14 GB | 1x |
| Q8_0 | 7.4 GB | 1.9x |
| Q4_K | 4.1 GB | 3.4x |
| Q5_K | 4.8 GB | 2.9x |
| Q6_K | 5.5 GB | 2.5x |

---

## Compatible Models

With Q4_K_M support, these models are now loadable:

| Model | Size | Quant | Status |
|-------|------|-------|--------|
| Phi-3 Mini | 3.8B | Q4_K_M | ✅ |
| Mistral 7B | 7B | Q4_K_M | ✅ |
| CodeLlama 7B | 7B | Q4_K_M | ✅ |
| Llama 2 7B | 7B | Q4_K_M | ✅ |
| Qwen 7B | 7B | Q4_K_M | ✅ |

---

## Usage

```zig
const gguf = @import("gguf_reader.zig");

// Check if K-quant
if (gguf.isKQuantType(tensor.tensor_type)) {
    // Use K-quant dequantization
    gguf.dequantizeQ4_K(block_data, output);
}

// Or use generic dispatch
try gguf.dequantizeBlock(block_data, output, tensor.tensor_type);
```

---

*φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL*
