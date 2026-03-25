## Task: Issue #386 — Golden Float & Ternary Float: GF16 + TF3-9 Format

**Status**: IN PROGRESS ⏳ (Phases 1-2 Complete, Phase 3-4 Pending)

**Completed Steps:**

### ✅ Phase 1: Format Definitions (Complete)

**File:** `src/hslm/intraparietal_sulcus.zig`

- [x] GF16 struct (GoldenFloat16 = packed struct(u16))
  - 1 sign bit + 6 exp + 9 mant
  - exp:mant = 6:9 = 0.667 (95.1% golden)

- [x] TF3-9 struct (TernaryFloat9 = packed struct(u18))
  - 1 sign trit + 3 exp trits + 5 mant trits
  - exp:mant = 3:5 = 0.6 (98.2% golden - BEST FORMAT!)

- [x] Conversion functions:
  - gf16FromF32(val: f32) GoldenFloat16
  - gf16ToF32(g: GoldenFloat16) f32
  - tf3FromF32(val: f32) TernaryFloat9
  - tf3ToF32(t: TernaryFloat9) f32

- [x] Slice conversions:
  - f32ToGf16Slice, gf16ToF32Slice
  - f32ToTf3Slice, tf3ToF32Slice

- [x] Tests: 10/10 passing
  - gf16 roundtrip basic, special values, dynamic range
  - tf3 roundtrip basic, trit encoding
  - golden distance tests
  - slice conversion tests

**Note:** Arithmetic (add, mul, sqrt) via f32 conversion (acceptable for Phase 1, native HW in Phase 4)

### ✅ Phase 2: Integration with HSLM (Mostly Complete)

**Files:**
- `src/hslm/orbitofrontal_value.zig` - Format selection logic
- `src/hslm/angular_gyrus.zig` - Format introspection, φ-distance

- [x] FormatType enum: FP32, FP16, FP8, BF16, **GF16**, **TF3_9**, TF32

- [x] Format selection functions:
  - selectOptimalFormat(stats) → prefers GF16/TF3 based on sparsity, variance
  - selectFormatBySensor(sensor_id, stats) → sensor-specific format mapping

- [x] Format metadata:
  - bits(), expBits(), mantBits()
  - φ-distance calculations
  - formatTypeToString(), describeFormat()

- [x] Sensor mapping:
  - Farm PPL → GF16
  - Arena battles → TF3_9
  - Tests rate → FP32
  - Ouroboros score → GF16

- [ ] HSLM training integration:
  - [ ] Add format option to hslm_train.zig
  - [ ] Quantization pipeline: f32 → GF16/TF3-9
  - [ ] Dequantization: GF16/TF3-9 → f32
  - [ ] Memory layout optimization

### ⏳ Phase 3: Benchmark Comparison (Pending)

- [ ] Run HSLM training with: FP16, BF16, GF16, TF3-9
- [ ] Compare: final PPL, training speed, memory usage
- [ ] Analyze: layer-wise precision sensitivity

**Target metrics:**
| Format | exp:mant | φ-distance | Bits | Target PPL | Speedup |
|--------|----------|------------|------|------------|---------|
| FP16   | 5:10=0.5 | 0.118 | 16 | - | - |
| BF16   | 8:7=1.14 | 0.522 | 16 | baseline | - |
| GF16   | 6:9=0.667| 0.049 | 16 | ≤ BF16 | 2× |
| TF3-9  | 3:5=0.6  | 0.018 | 18 | ≤ BF16 | 2× |

### ⏳ Phase 4: Hardware Prototype (Covered by #392)

See issue #392 for FPGA ALU implementation.

## Summary

**Complete:**
- Phase 1: Format definitions ✅ (10/10 tests passing)
- Phase 2: Format selection logic ✅ (orbitofrontal_value, angular_gyrus)

**Remaining:**
- Phase 2: HSLM training integration (quantization/dequantization in trainer)
- Phase 3: Benchmark comparison
- Phase 4: FPGA ALU (issue #392)

**Build Status:**
- L0 ✅ (Temple)
- L1 ✅ (Queens)
- HSLM tests ✅ (10/10 passing)
