# FPGA Synthesis Results — Yosys 0.63 on XC7A100T

Date: 2026-03-16
Tool: Yosys 0.63 (synth_xilinx -flatten -abc9 -arch xc7)
Target: XC7A100T-FGG676 (QMTech board)

## hslm_full_top — THE LIVE DESIGN (flashed, running on silicon)

**Architecture**: 3-block ternary transformer, TMU K=16, 81.25 MHz MMCM, BSCANE2 JTAG bridge
**Bitstream**: hslm_full_top.bit (FPGA-015 milestone, 2026-03-15)

### Resource Utilization

| Resource | Used | Available | % | Notes |
|----------|------|-----------|---|-------|
| **LUT (cells)** | 49,363 | 63,400 | **77.9%** | INV=112, LUT2=5632, LUT3=2711, LUT4=4099, LUT5=25024, LUT6=11785 |
| **RAM64M** | 4,608 | — | — | Distributed RAM (x_buffer + emb/inter/relu buffers), ~18K LUT-equiv |
| **Estimated LCs** | 43,619 | 63,400 | **68.7%** | Yosys combined metric (LUT + RAM + CARRY) |
| **Flip-Flops** | 59,013 | 126,800 | **46.5%** | FDRE=59,006, FDSE=7 |
| **BRAM36-eq** | 63.0 | 135 | **46.7%** | RAMB18E1=118, RAMB36E1=4 |
| **CARRY4** | 701 | 15,850 | **4.4%** | Carry chains for adder trees |
| **DSP48E1** | **0** | 240 | **0.0%** | Zero DSP — all computation is ternary add-only |
| **MMCME2_BASE** | 1 | 6 | 16.7% | 50 MHz -> 81.25 MHz |
| **BSCANE2** | 1 | 4 | 25.0% | JTAG bridge for runtime control |
| **BUFG** | 2 | 32 | 6.3% | sys_clk + BSCANE2 TCK |

### Key Findings

1. **LUT is the bottleneck** (78%), not BRAM (47%) as previously estimated
2. **FF utilization is moderate** (46.5%) — pipeline registers well-utilized
3. **BRAM at 47%** — much lower than the 87% estimate, room for expansion
4. **DSP48 = 0 CONFIRMED** — pure ternary arithmetic, zero DSP blocks
5. **4,608 RAM64M** = distributed RAM for TMU x_buffer (K=16 simultaneous reads)

### Chip Utilization Summary

```
LUT  ████████████████████░░░░░  78%  — PRIMARY BOTTLENECK
FF   ████████████░░░░░░░░░░░░░  47%  — moderate
BRAM ████████████░░░░░░░░░░░░░  47%  — headroom available
DSP  ░░░░░░░░░░░░░░░░░░░░░░░░░   0%  — zero (by design)
```

### Optimization Opportunities

| Optimization | Delta LUT | Delta BRAM | Effect | Feasibility |
|-------------|-----------|------------|--------|-------------|
| Clock 81->100 MHz | 0 | 0 | +23% tok/s (1,003->1,234) | EASY (MMCM param) |
| Clock 81->125 MHz | 0 | 0 | +54% tok/s (1,003->1,545) | MEDIUM (timing) |
| Context 81->243 | ~0 | +4 | 3x context window | EASY |
| Vocab 128->256 | ~0 | +2 | 2x output vocabulary | EASY |
| Weight sharing (B2=B1 weights) | -16K LUT | -30 BRAM | Opens space for B4 | MEDIUM |
| 4th block (needs weight sharing) | +16K LUT | +30 BRAM | Deeper model | POSSIBLE with sharing |

---

## All Modules Summary

| Module | LUTs | BRAM36-eq | FFs | CARRY4 | DSP48 | Status |
|--------|------|-----------|-----|--------|-------|--------|
| **hslm_full_top** | **49,363** | **63.0** | **59,013** | **701** | **0** | LIVE ON SILICON |
| uart_weight_loader | 309 | 0 | 179 | 53 | 0 | OK |
| spi_flash_master | 73 | 0 | 89 | 16 | 0 | OK |
| hslm_dynamic_top | 93 | 0 | 104 | 21 | 0 | OK |
| embedding_lookup | 87 | 2 | 65 | 13 | 0 | OK |
| hslm_pipeline_top | — | — | — | — | — | .mem path error |
| hslm_timemux_top | — | — | — | — | — | .mem path error |
| hslm_uart_inference_top | — | — | — | — | — | .mem path error |
| ternary_attention | — | — | — | — | — | .mem path error |
| trinity_attn_block | — | — | — | — | — | defparam error |
| embedding_lookup_512 | — | — | — | — | — | .mem path error |

Note: Modules marked ".mem path error" fail because they reference `fpga/weights/*.mem`
which doesn't exist relative to the synthesis directory. These are legacy modules —
hslm_full_top is the authoritative design.

---

## Hardware Verification (JTAG, 2026-03-16)

| Test | Command | Result | Value |
|------|---------|--------|-------|
| Status | `jtag_switcher status` | PASS | DONE=1, CRC_OK, MMCM_LOCK=1 |
| IDCODE (IR) | `jtag_switcher idcode` | PASS | 0x13631093 (XC7A100T) |
| IDCODE (CFG) | `jtag_switcher idcode` | PASS | 0x13631093 (match) |
| Device DNA | `jtag_switcher dna` | PASS | 0x00001C0000001C |
| Raw STAT | `jtag_switcher reg 0x07` | PASS | 0x401079FC |
| Full Debug | `jtag_switcher debug` | PASS | 6/6 tests passed |

### STAT Register Decode (0x401079FC)

| Bit | Field | Value |
|-----|-------|-------|
| 14 | DONE | YES |
| 12 | INIT_B | HIGH |
| 11 | GTS_CFG_B | HIGH |
| 10 | GWE | NO |
| 9 | GHIGH_B | LOW |
| 5-7 | MODE | M[2:0]=111 |
| 4 | EOS | YES |
| 3 | DCI_MATCH | YES |
| 2 | MMCM_LOCK | YES |
| 1 | Part_Secured | NO |
| 0 | CRC_ERROR | OK |

---

## For Paper (FPL 2026)

| Metric | Value | Source |
|--------|-------|--------|
| Device | Xilinx XC7A100T-FGG676 | JTAG IDCODE |
| Device DNA | 0x00001C0000001C | JTAG DNA read |
| Clock | 81.25 MHz | MMCM (50x13/8) |
| LUT utilization | 49,363 / 63,400 (77.9%) | Yosys synth_xilinx |
| FF utilization | 59,013 / 126,800 (46.5%) | Yosys synth_xilinx |
| BRAM36-eq | 63.0 / 135 (46.7%) | Yosys synth_xilinx |
| DSP48E1 | 0 / 240 (0.0%) | Yosys synth_xilinx |
| Throughput | 1,003 tok/s (K=16, estimated) | Cycle count simulation |
| Architecture | 3-block ternary transformer | 243-dim, vocab=128 |
| Power | ~0.5W TDP (estimated) | Xilinx Power Estimator |
| DONE bit | 1 (configured) | JTAG STAT register |
| CRC errors | 0 | JTAG STAT register |
