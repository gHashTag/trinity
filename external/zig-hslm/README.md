# zig-hslm — Official HSLM Numerical Library

**Official repo:** https://codeberg.org/gHashTag/zig-hslm
**Branch:** `feat/vector-float-cast`

## Purpose

Float16 utilities for Trinity's numerical layer (Intraparietal Sulcus).
Provides safe f16/f32 conversion with NaN/Inf/subnormal/overflow handling.

## Status

⚠️ **Note:** Due to Codeberg clone issues (corrupted pack), this directory contains a local copy of `f16_utils.zig`. The submodule approach is temporarily disabled.

## Features

- `f16` type alias
- `GF16` — φ-optimized packed format
- `TF3` — Ternary Float3 (2-bit per value)
- `safeF16ToF32()` — Safe cast
- `vectorFloatCast()` — SIMD-safe vector cast
- `phiQuantize()` / `phiDequantize()` — φ-weighted quantization

## Integration

See `src/brain/intraparietal_sulcus.zig` for usage examples.
