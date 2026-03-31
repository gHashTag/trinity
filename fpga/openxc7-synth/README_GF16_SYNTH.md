# GF16 FPGA Synthesis — BENCH-005

**Target:** QMTECH XC7A100T-FGG676
**Tool:** Vivado (synth_design)
**Goal:** Measure LUT/FF/DSP/Fmax for GF16 add/mul vs ternary baseline

## Files Created

| File | Purpose |
|------|---------|
| `gf16_add_top.v` | GF16 adder with IO registers (for fair Fmax) |
| `gf16_mul_top.v` | GF16 multiplier with IO registers |
| `gf16_add_synth.tcl` | Vivado synthesis script (add) |
| `gf16_mul_synth.tcl` | Vivado synthesis script (mul) |

## How to Run

### Prerequisites
1. Xilinx Vivado installed
2. QMTECH XC7A100T connected via JTAG (ESP32 bridge)

### Synthesis Commands

```bash
cd fpga/openxc7-synth

# GF16 Adder
vivado -mode batch -source gf16_add_synth.tcl

# GF16 Multiplier
vivado -mode batch -source gf16_mul_synth.tcl
```

## Expected Reports

After synthesis, check:
- `gf16_add_output/utilization.rpt` → LUT, FF, DSP counts
- `gf16_add_output/timing.rpt` → Fmax, WNS, TNS
- `gf16_mul_output/utilization.rpt` → LUT, FF, DSP counts
- `gf16_mul_output/timing.rpt` → Fmax, WNS, TNS

## Target Table (Section 8.7)

| Module | LUT | FF | DSP | Fmax (MHz) | Status |
|--------|-----|----|-----|------------|--------|
| ternary (hslm) | 4,267 | 2,449 | 0 | ≥92 | ✅ Measured |
| gf16_add | ? | ? | 0? | ? | ⏳ TBD |
| gf16_mul | ? | ? | 1? | ? | ⏳ TBD |

## Next Steps

1. Run synthesis for both modules
2. Extract LUT/FF/DSP from `utilization.rpt`
3. Extract Fmax from `timing.rpt` (Fmax = 1 / (period - WNS))
4. Update `docs/research/gf16_vs_literature.md` Section 8.7
