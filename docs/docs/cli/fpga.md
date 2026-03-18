---
sidebar_position: 30
sidebar_label: FPGA
---

# tri fpga — FPGA Synthesis & Inference

FPGA synthesis pipeline, bitstream management, and ternary inference on hardware.

## Subcommands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri fpga status` | — | Show FPGA device and bitstream status |
| `tri fpga build` | — | Build FPGA project |
| `tri fpga synth` | — | Run synthesis pipeline |
| `tri fpga flash` | — | Flash bitstream to FPGA |
| `tri fpga verify` | — | Verify loaded bitstream |
| `tri fpga uart` | — | UART communication test |
| `tri fpga snap` | — | Snapshot current FPGA state |
| `tri fpga eye` | — | Eye diagram visualization |
| `tri fpga infer` | — | Run ternary inference on FPGA |

## Examples

```bash
tri fpga status                    # Check FPGA status
tri fpga synth                     # Run synthesis
tri fpga flash                     # Flash bitstream
tri fpga verify                    # Verify bitstream
tri fpga infer                     # Run inference
tri fpga uart                      # Test UART
```

## Hardware

- **Target:** Xilinx 7-series (openXC7 toolchain)
- **Bitstream:** `fpga/openxc7-synth/hslm_full_top.bit`
- **Resources:** 4 blocks, 135 BRAM36-eq (100%), 4,267 LUT (6.7%), 0 DSP48 — Yosys 0.63 verified
- **Performance:** 5,000 tok/s ternary inference

## Handler

**File:** `src/tri/tri_register.zig`
