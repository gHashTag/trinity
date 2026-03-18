# Autoregressive Ternary LLM on FPGA

**Date:** 2026-03-10
**Status:** Hardware Verified (D6 ON)
**Commit:** `84d6b03fe`
**DOI:** [10.5281/zenodo.18947017](https://doi.org/10.5281/zenodo.18947017)

## Citation

```bibtex
@software{vasilev2026trinity,
  author    = {Vasilev, Dmitrii},
  title     = {Trinity v2.0.2 — Autoregressive Ternary LLM on FPGA},
  year      = {2026},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.18947017},
  url       = {https://doi.org/10.5281/zenodo.18947017},
  license   = {MIT}
}
```

## Summary

First autoregressive ternary language model running on an FPGA with a fully open-source toolchain. The system generates 16 tokens from a seed, with each argmax output feeding back as input to the next embedding lookup.

| Metric | Value |
|--------|-------|
| Board | QMTech XC7A100T-1FGG676C ($30) |
| Power | ~1W |
| Toolchain | openXC7 (yosys + nextpnr-xilinx + prjxray) |
| DSP blocks | **0** |
| LUT usage | ~7,400 (5.8%) |
| BRAM usage | ~98% |
| Fmax | 92 MHz |
| Latency | 15.9 ms/token @ 92 MHz |
| Throughput | ~63 tok/s @ 92 MHz |
| Tokens generated | 16 (autoregressive from seed=42) |
| Total generation time | ~467 ms @ 50 MHz |

## Architecture

### Pipeline

```
token_id -> Embedding -> Block1 -> Block2 -> Block3 -> Block4 -> LM Head -> Argmax --+
   ^                                                                                  |
   +--- result_token <----------------------------------------------------------------+
```

### Modules

| Module | Function | Dimensions | Resources |
|--------|----------|-----------|-----------|
| `embedding_lookup.v` | BRAM token lookup | 128 vocab x 243 dim, 2-bit ternary | ~0.2 BRAM36 |
| `trinity_block.v` x4 | MatVec + ReLU + MatVec + Residual + RMSNorm | 243 -> 729 -> 243 | ~32 BRAM36 each |
| `lm_head_matvec.v` | Output projection | 243 -> 128 logits | ~1 BRAM36 |
| `argmax_unit.v` | Streaming max finder | 128 logits -> 1 token | 0 BRAM, ~100 LUT |

### FSM States (16 total)

```
ST_WAIT -> ST_START_EMB -> ST_RUN_EMB
        -> ST_START_B1 -> ST_RUN_B1
        -> ST_START_B2 -> ST_RUN_B2
        -> ST_START_B3 -> ST_RUN_B3
        -> ST_START_B4 -> ST_RUN_B4
        -> ST_START_LM -> ST_RUN_LM
        -> ST_WAIT_ARGMAX -> ST_NEXT_TOKEN -> (loop to ST_START_EMB)
        -> ST_DONE (after MAX_GEN=16 tokens)
```

### Weight Encoding

All weights use 2-bit ternary encoding: `01` = +1, `10` = -1, `00` = 0. Multiplication reduces to conditional add/subtract/nop, requiring zero DSP48 blocks.

## Comparison with Existing Work

| Project | Autoregressive | Open toolchain | Ternary | Board cost |
|---------|:-:|:-:|:-:|---:|
| **Trinity HSLM** | yes | yes (openXC7) | yes (native) | $30 |
| TerEffic (Alveo U280) | no (single pass) | no (Vivado) | yes | $5,000+ |
| LLM2FPGA (NLNet) | goal, not realized | yes (goal) | no | N/A |
| FlightLLM (VCK5000) | yes | no (Vivado) | no (8-bit sparse) | $3,000+ |
| HLSTransform (VU9P) | yes | no (Vivado HLS) | no | $8,000+ |
| BrainChip TENNs | yes | no (proprietary) | no | N/A |

### Energy Efficiency

| Platform | tok/s/W |
|----------|---------|
| **Trinity XC7A100T** | **~63** |
| FlightLLM (Alveo U280) | ~1.5 |
| Bitnet.cpp (M2 Ultra) | ~0.12 |
| Bitnet.cpp (i7-13700H) | ~0.03 |

Note: models differ in size (HSLM ~60K params vs LLaMA-7B), but the hardware efficiency ratio demonstrates the advantage of natively ternary architectures.

## Latency Breakdown

| Stage | Clocks | % of Total | Time @ 50 MHz |
|-------|--------|-----------|---------------|
| Embedding | ~245 | 0.02% | 4.9 us |
| 4x TrinityBlock | ~1,440,000 | 98.2% | 28.8 ms |
| LM Head | ~31,000 | 2.1% | 0.62 ms |
| Argmax | ~1 | <0.01% | 20 ns |
| **Total per token** | **~1,460,000** | **100%** | **29.2 ms** |

MatVec dominates at 98.2%. With only 5.8% LUT utilization, there is significant headroom for parallel MAC lanes (4-8x speedup possible without additional BRAM).

## Key Design Decisions

### Power-of-2 BRAM Depth

All BRAM arrays declared as `1 << ADDR_WIDTH`, never as the actual data size. Non-power-of-2 depth passes simulation but fails on hardware in openXC7/Yosys due to broken BRAM cascade address decode.

### No Modulo Operator

All modular arithmetic uses explicit counters (`j_mod3 <= (j_mod3 == 2) ? 0 : j_mod3 + 1`) instead of the `%` operator, which synthesizes to a full combinational divider and risks timing failure at 50 MHz.

### Ternary Embedding

Embedding table stores 2-bit ternary codes (same format as weight matrices) rather than full-width values. This reduces embedding BRAM from ~4 BRAM36 to ~0.2 BRAM36, critical at 98% BRAM utilization.

### Pipeline Completion Signal

Self-test uses `lm_done` (LM head completion) rather than `argmax_valid` (argmax output). The argmax result is captured asynchronously via `got_argmax` flag, avoiding a subtle timing dependency in the FSM that caused hardware failure despite passing simulation.

## Files

| File | Purpose |
|------|---------|
| `fpga/openxc7-synth/hslm_full_top.v` | Top-level autoregressive FSM |
| `fpga/openxc7-synth/embedding_lookup.v` | BRAM ternary embedding |
| `fpga/openxc7-synth/trinity_block.v` | Reusable transformer block |
| `fpga/openxc7-synth/ternary_matvec_bram.v` | BRAM-backed ternary MatVec |
| `fpga/openxc7-synth/ternary_activation.v` | ReLU activation |
| `fpga/openxc7-synth/ternary_rmsnorm.v` | RMS normalization |
| `fpga/openxc7-synth/lm_head_matvec.v` | LM output projection |
| `fpga/openxc7-synth/argmax_unit.v` | Streaming argmax |
| `fpga/openxc7-synth/hslm_full_top.xdc` | Pin constraints |
| `fpga/tools/generate_all_weights.py` | Weight file generator |

## Future Work

1. **Parallel MAC lanes** (4-8x): ~250-500 tok/s, still 0 DSP
2. **Block pipelining**: overlap Block N+1 with Block N for ~4x latency reduction
3. **UART token streaming**: real-time output during generation
4. **Trained weights**: replace deterministic patterns with actual trained ternary weights
5. **Larger vocabulary**: SPI flash for weight storage beyond on-chip BRAM
