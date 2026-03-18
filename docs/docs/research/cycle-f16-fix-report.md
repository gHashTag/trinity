# f16ToF32 Subnormal Bug Fix Report

## Issue Summary

The GGUF Q4_K dequantization produced incorrect values due to a bug in the `f16ToF32` function when handling subnormal (denormalized) f16 values. This affected all quantized weight loading.

## Root Cause

In `src/vibeec/gguf_reader.zig`, the f16 to f32 conversion for subnormal values had an off-by-one error in the exponent calculation:

**Before (Bug):**
```zig
return @bitCast(sign | ((127 - 15 + 1 - e) << 23) | (m << 13));
// Computes: 113 - e (WRONG)
```

**After (Fixed):**
```zig
return @bitCast(sign | ((114 - e) << 23) | (m << 13));
// Computes: 114 - e (CORRECT)
```

## Impact

This bug caused all Q4_K scale values (`d`) to be **exactly half** of their correct values:

| Value | Before Fix | After Fix | Correct |
|-------|-----------|-----------|---------|
| d for block 8 | 5.722e-6 | 1.144e-5 | 1.144e-5 |
| Token 1 emb[0] | -2.58e-3 | -1.30e-3 | -1.30e-3 |

## Verification

After the fix, token embeddings match llama-cpp-python exactly:
- Token 1 embedding L2 norm: 0.1009 (matches Python)
- First 10 values match to 7 significant figures

## Files Changed

- `src/vibeec/gguf_reader.zig`: Fixed `f16ToF32` function

## Remaining Work

While the embedding dequantization is now correct, the final logits still differ from llama-cpp-python. Further investigation is needed in:
- Weight matrix dimension interpretation (row-major vs column-major)
- Attention mechanism implementation
- RoPE application

## Date

2026-02-07
