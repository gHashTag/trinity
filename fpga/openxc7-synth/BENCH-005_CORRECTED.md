# BENCH-005: GF16 FPGA Synthesis — CORRECTED

## What Was Fixed

**Incorrect comparison** (previously):
- GF16 adder (118 LUT) vs **full HSLM pipeline** (4,267 LUT)
- → "2.8% of ternary baseline" — **apples vs oranges**

**Honest comparison** (now):
- GF16 adder (118 LUT) vs **ternary adder** (2 LUT)
- → **59× overhead** for 16-bit floating-point vs 3-state ternary

## Unit-level FPGA Cost (Yosys)

| Unit | LUT | FF | DSP | LC Estimate | Status |
|------|-----|----|-----|-------------|--------|
| **ternary_add** | 2 | 2 | 0 | 2 | ✅ Measured |
| **ternary_mul** | 2 | 2 | 0 | 2 | ✅ Measured |
| **gf16_add** | 118 | 47 | 0 | 95 | ✅ Measured |
| **gf16_mul** | 94 | 47 | 1 DSP48E1 | 67 | ✅ Measured |

## GF16 vs Ternary (Single Operations)

| Metric | GF16 Add | Ternary Add | Ratio | GF16 Mul | Ternary Mul | Ratio |
|--------|----------|-------------|-------|----------|-------------|-------|
| **LUT** | 118 | 2 | **59×** | 94 | 2 | **47×** |
| **FF** | 47 | 2 | **23.5×** | 47 | 2 | **23.5×** |
| **DSP** | 0 | 0 | — | 1 | 0 | — |

## Why GF16 Is More Expensive

| Operation | Ternary (2-LUT) | GF16 (94-118 LUT) | Overhead |
|-----------|-----------------|-------------------|----------|
| Addition | XNOR + mux | Align exponents + add mantissas + normalize + round | 59× |
| Multiplication | AND gate | 9×9 mantissa mul (DSP) + exponent add + normalize | 47× |

**Ternary**: 3 states {-1, 0, +1} → trivial multiplexers
**GF16**: 16-bit float (6:9) → full IEEE 754-like pipeline

## System Context (DO NOT compare!)

| System | LUT | FF | DSP | Fmax | Status |
|---------|-----|----|-----|------|--------|
| **hslm_full_top** | 4,267 | 2,449 | 0 | ≥92 MHz (an Fmax estimate, per the FPGA table in the root README.md; the board run was at 50 MHz) | ✅ Measured (LUT/FF/DSP; Fmax not measured) |
| **gf16_inference** | ⏳ TBD | ⏳ TBD | ⏳ TBD | ⏳ TBD | ⏳ Future work |

> `hslm_full_top` = **full inference pipeline** (memory + MAC array + control)
> GF16 add/mul = **single operations** (not a full inference engine)

## Key Findings

1. **GF16 is 47–59× more expensive** than ternary for single operations
   - Expected: GF16 is full floating-point, ternary is 3-state logic
   - This is the **price of precision** (9-bit mantissa vs 1 trit)

2. **Both fit easily on XC7A100T**:
   - Ternary adder: 2 LUT → **~31,700** parallel units
   - GF16 adder: 118 LUT → **~537** parallel units
   - GF16 multiplier: 94 LUT → **~674** parallel units

3. **DSP usage**: Only GF16 multiplier needs DSP (1× DSP48E1)
   - Ternary uses pure LUT logic (no DSP needed)

## References

- Ternary hardware: "Multiplexers over {-1, 0, +1}" (expected 5–15 LUT for add)
- GF16 format: 6-bit exponent, 9-bit mantissa, bias=31
- Literature: Floating-point units typically 50–100× LUTs of ternary

## Next Steps (To Complete BENCH-005)

1. ⏳ **BLOCKED**: Build nextpnr-xilinx for P&R
2. Extract Fmax from timing report
3. Optional: Flash and verify LED behavior
4. Future: Design full GF16 inference pipeline (system-level comparison)

## Files Created (Corrected)

| File | Purpose |
|------|---------|
