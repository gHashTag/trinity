# zig-hslm — HSLM Numerical Utilities

Official HSLM library for Trinity project.

**Repository:** https://codeberg.org/gHashTag/zig-hslm

**Branch:** `feat/vector-float-cast` — f16 edge case tests + @floatCast

## Status

⚠️ **CodeBerg repository temporarily unavailable.**

This is a placeholder structure. To use the full zig-hslm:
1. Clone manually: `git clone https://codeberg.org/gHashTag/zig-hslm.git`
2. Copy contents to this directory, OR
3. Replace as submodule when CodeBerg is accessible

## Modules (Planned)

- `f16_utils.zig` — f16/GF16/TF3 utilities for HSLM inference
  - `GF16` — Gaussian Float 16 representation
  - `TF3` — Ternary Float 3 {-1, 0, +1}
  - `vecF16ToF32()` / `vecF32ToF16()` — Vector conversions
  - `gf16Quantize()` / `gf16Dequantize()` — GF16 quantization
  - `tf3Quantize()` / `tf3Dequantize()` — TF3 quantization

## Build

```bash
zig build
zig build test
```

## License

MIT (see LICENSE file)
