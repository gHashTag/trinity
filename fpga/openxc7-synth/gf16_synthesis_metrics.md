# GF16 FPGA Synthesis Metrics — BENCH-005

## Target Hardware

| Parameter | Value |
|-----------|-------|
| Board | QMTECH XC7A100T-FGG676 |
| LUT | 63,400 |
| FF | 129,600 |
| DSP48 | 240 |
| BRAM36 | 135 |
| Target Fmax | ≥92 MHz (ternary baseline) |

## Synthesis Results (Yosys)

### GF16 Adder (gf16_add_top.v)

| Metric | Value |
|--------|-------|
| **Total Cells** | 171 |
| **LUT2** | 34 |
| **LUT3** | 23 |
| **LUT4** | 15 |
| **LUT5** | 16 |
| **LUT6** | 30 |
| **Total LUTs** | 118 |
| **Estimated LCs** | 95 |
| **DSP48E1** | 0 |
| **CARRY4** | 11 |
| **FDCE (FF)** | 47 |
| **MUXF7** | 16 |
| **MUXF8** | 8 |
| **IBUF/OBUF** | 34/17 |

### GF16 Multiplier (gf16_mul_top.v)

| Metric | Value |
|--------|-------|
| **Total Cells** | 148 |
| **LUT2** | 27 |
| **LUT3** | 33 |
| **LUT4** | 17 |
| **LUT5** | 8 |
| **LUT6** | 9 |
| **Total LUTs** | 94 |
| **Estimated LCs** | 67 |
| **DSP48E1** | 1 |
| **CARRY4** | 8 |
| **FDCE (FF)** | 47 |
| **IBUF/OBUF** | 34/17 |

## Comparison Table

| Module | LUT | FF | DSP | Fmax (MHz) | Status |
|--------|-----|----|-----|------------|--------|
| ternary (hslm) | 4,267 | 2,449 | 0 | ≥92 | ✅ Measured |
| gf16_add | 118 | 47 | 0 | ⏳ TBD | ⏳ Synthesis OK |
| gf16_mul | 94 | 47 | 1 | ⏳ TBD | ⏳ Synthesis OK |

## Notes

- **LUT count**: GF16 adder (118) uses ~2.8% of ternary baseline (4,267)
- **LUT count**: GF16 multiplier (94) uses ~2.2% of ternary baseline (4,267)
- **DSP usage**: Multiplier uses 1 DSP48E1 (out of 240 available = 0.4%)
- **Fmax**: Pending nextpnr-xilinx place & route + timing analysis
- **Total for GF16 MAC**: 118 + 94 = 212 LUTs, 94 FFs, 1 DSP

## Next Steps

1. Build nextpnr-xilinx: `cd fpga/nextpnr-xilinx && cmake .. && make`
2. Run place & route: `nextpnr-xilinx --chipdb ... --json ... --fasm ...`
3. Extract Fmax from nextpnr timing report
4. Optional: Flash bitstreams and verify LED behavior

## Files Generated

- `fpga/openxc7-synth/gf16_add_top.json` — Yosys synthesis output
- `fpga/openxc7-synth/gf16_mul_top.json` — Yosys synthesis output
- `fpga/openxc7-synth/gf16_add_tb.v` — Testbench for adder
- `fpga/openxc7-synth/gf16_mul_tb.v` — Testbench for multiplier
- `fpga/openxc7-synth/gf16_top.xdc` — Pin constraints
