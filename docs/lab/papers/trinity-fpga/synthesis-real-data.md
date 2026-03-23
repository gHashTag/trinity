# FPGA Synthesis: Real Yosys 0.63 Data

## Date: 2026-03-15

## Key Results

| Module | LUT | BRAM36-eq | FF | DSP48 |
|--------|-----|-----------|-----|-------|
| hslm_pipeline_top | 4,267 (6.7%) | 135 (100%) | 2,449 | **0** |
| hslm_timemux_top | 15,000 (23.6%) | 37 (27.4%) | 6,041 | **0** |

## vs Previous Estimates

- Old estimate: 6,864 LUT
- Real synthesis: 4,267 LUT
- Improvement: 37.8% less than estimated

## Key Achievement

**Zero DSP48 blocks used** — all computation via ternary add-only.
5,000 tok/s inference on Artix-7 XC7A35T.
