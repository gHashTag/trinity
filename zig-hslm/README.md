# zig-hslm — HSLM Numerical Utilities

Official HSLM library for Trinity project.

**Repository:** https://codeberg.org/gHashTag/zig-hslm

**Branch:** `feat/vector-float-cast` — f16 edge case tests + @floatCast

## Modules

- `f16_utils.zig` — f16/GF16/TF3 utilities for HSLM inference
  - `GF16` — Gaussian Float 16 representation
  - `TF3` — Ternary Float 3 {-1, 0, +1}
  - `vecF16ToF32()` / `vecF32ToF16()` — Vector conversions
  - `gf16Quantize()` / `gf16Dequantize()` — GF16 quantization
  - `tf3Quantize()` / `tf3Dequantize()` — TF3 quantization
  - `testF16EdgeCases()` — f16 edge case tests (from feat/vector-float-cast)

## Build

```bash
zig build
zig build test
```

## Usage in Trinity

In `build.zig`:

```zig
const zig_hslm_mod = b.createModule(.{
    .root_source_file = b.path("zig-hslm/src/root.zig"),
    .target = target,
    .optimize = optimize,
});

// Add to executable imports
exe.root_module.addImport("zig_hslm", zig_hslm_mod);
```

In source code:

```zig
const zig_hslm = @import("zig_hslm");
const f16 = zig_hslm.f16_utils;

// TF3 quantization
const tf3_val = f16.TF3.fromF32(0.8); // Returns .pos1
const f32_back = tf3_val.toF32(); // Returns 1.0

// Vector conversion
var f16_buf: [100]f16 = undefined;
try f16.vecF32ToF16(&f32_values, &f16_buf);
```

## License

MIT (see LICENSE file)
