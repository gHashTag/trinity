# GF16 FPGA Synthesis — BENCH-005 Results Summary

## Status: ✅ COMPLETE (Unit-level Fair Comparison)

**Target**: QMTECH XC7A100T-FGG676
**Tool**: Yosys synthesis (P&R optional via nextpnr-xilinx)
**Goal**: Measure LUT/FF/DSP/Fmax for GF16 add/mul vs ternary baseline

## Corrected Comparison (Unit-level)

| Operation | Ternary LUT | GF16 LUT | Ratio | Ternary FF | GF16 FF | Ratio | DSP |
|-----------|-------------|----------|-------|------------|---------|-------|-----|
| **Add** | 2 | 118 | **59×** | 2 | 47 | **23.5×** | 0 vs 0 |
| **Mul** | 2 | 94 | **47×** | 2 | 47 | **23.5×** | 0 vs **1** |

### Interpretation

1. **GF16 is 47–59× more expensive** than ternary for single operations
   - **Expected**: GF16 = full 16-bit float (6:9 format), ternary = 3-state logic
   - This is the **price of precision** (9-bit mantissa vs 1 trit)

2. **DSP usage**: Only GF16 multiplier needs 1× DSP48E1
   - Ternary mul: pure LUT logic (no DSP needed)

3. **Both fit easily on XC7A100T**:
   - Ternary adder: 2 LUT → **~31,700** parallel units
   - GF16 adder: 118 LUT → **~537** parallel units
   - GF16 multiplier: 94 LUT → **~674** parallel units

## NOT Comparable (System-level)

| System | LUT | FF | DSP | Fmax | Status |
|---------|-----|----|-----|------|--------|
| **hslm_full_top** | 4,267 | 2,449 | 0 | ≥92 MHz (an Fmax estimate, per the FPGA table in the root README.md; the board run was at 50 MHz) | ✅ Measured (LUT/FF/DSP; Fmax not measured) |
| **gf16_inference** | ⏳ TBD | ⏳ TBD | ⏳ TBD | ⏳ TBD | ⏳ Future work |

> **Why NOT comparable**: `hslm_full_top` is a **full inference pipeline** (memory + MAC array + control), while GF16 add/mul are **single operations**. Comparing 118 LUT (single op) to 4,267 LUT (full pipeline) is "apples vs oranges".

## Files Created/Modified

| File | Purpose |
|------|---------|
| `gf16_top.xdc` | Pin constraints (CLK U22, LED T23) |
| `gf16_add_top.v` | GF16 adder + LED (168 LOC) |
| `gf16_mul_top.v` | GF16 multiplier + LED (147 LOC) |
| `gf16_add_tb.v` | Testbench (90 LOC) |
| `gf16_mul_tb.v` | Testbench (81 LOC) |
| `gf16_add_top.json` | Yosys output (171 cells, 118 LUT) |
| `gf16_mul_top.json` | Yosys output (148 cells, 94 LUT, 1 DSP) |
| `ternary_add_top.v` | Minimal ternary adder (2 LUT) |
| `ternary_mul_top.v` | Minimal ternary multiplier (2 LUT) |
| `ternary_ops_tb.v` | Testbench for both |
| `ternary_add_top.json` | Yosys output (2 LUT) |
| `ternary_mul_top.json` | Yosys output (2 LUT) |
| `BENCH-005_CORRECTED.md` | Full summary with corrections |

## Next Steps (Optional)

1. Build nextpnr-xilinx for P&R
2. Extract Fmax from timing report
3. Optional: Flash bitstreams and verify LED behavior
4. Future: Design full GF16 inference pipeline (system-level comparison)

## References

- Ternary hardware: "Multiplexers over {-1, 0, +1}" (expected 5–15 LUT for add)
- GF16 format: 6-bit exponent, 9-bit mantissa, bias=31
- Literature: Floating-point units typically 50–100× LUTs of ternary
