---
name: train
description: HSLM training analytics dashboard — live process status, checkpoint loss curve, model architecture, platform benchmarks, FPGA status, and scientific metrics. Use when checking training progress, loss convergence, or preparing paper-ready results.
argument-hint: [focus] (status, loss, bench, fpga, paper, all)
---

# HSLM Training Observatory

## 1. Process Status
!`ps aux | grep hslm-train | grep -v grep 2>/dev/null || echo "No hslm-train process running"`

## 2. Checkpoint Timeline
!`ls -lt /Users/playra/trinity-w1/data/checkpoints/hslm_step_*.bin 2>/dev/null | head -20 || echo "No checkpoints found"`

## 3. Loss Curve (from checkpoint headers)
Extract step (u32 LE at offset 8) and loss (f32 LE at offset 12) from each checkpoint binary header:
!`for f in $(ls -v /Users/playra/trinity-w1/data/checkpoints/hslm_step_*.bin 2>/dev/null); do step_hex=$(xxd -s 8 -l 4 -p "$f" 2>/dev/null); loss_hex=$(xxd -s 12 -l 4 -p "$f" 2>/dev/null); if [ -n "$step_hex" ]; then step=$(python3 -c "import struct; print(struct.unpack('<I', bytes.fromhex('$step_hex'))[0])" 2>/dev/null); loss=$(python3 -c "import struct; print(f'{struct.unpack(\"<f\", bytes.fromhex(\"$loss_hex\"))[0]:.6f}')" 2>/dev/null); echo "Step $step | Loss $loss | $(basename $f)"; fi; done 2>/dev/null || echo "No checkpoint headers to parse"`

## 4. Training Data
!`ls -lh /Users/playra/trinity-w1/data/tinystories/real_tinystories.txt 2>/dev/null || echo "Training data not found"`

## 5. Benchmark Binary
!`ls -la /Users/playra/trinity-w1/zig-out/bin/hslm-bench 2>/dev/null || echo "hslm-bench not built — run: cd /Users/playra/trinity-w1 && zig build hslm-bench"`

## 6. FPGA Status
!`ls -lh /Users/playra/trinity-w1/fpga/openxc7-synth/hslm_full_top.bit 2>/dev/null; ps aux | grep -E "jtag_program|flash_auto|openocd" | grep -v grep 2>/dev/null || echo "No FPGA programmer running"`

## Task

Analyze the HSLM training data above and present a complete analytics dashboard.

Focus area: $ARGUMENTS (default: all)

### Analysis Instructions

**For each checkpoint with parsed loss, compute:**
- Perplexity: exp(loss)
- Loss delta between consecutive checkpoints
- Convergence rate (loss improvement per 1K steps)
- Best loss achieved and at which step

**Model Architecture (from constants.zig):**
| Parameter | Value |
|-----------|-------|
| Vocab Size | 729 (3^6) |
| Embed Dim | 243 (3^5) |
| Hidden Dim | 729 (3^6) |
| VSA Dim | 1024 |
| Blocks | 3 (Trinity) |
| Context | 81 (3^4) |
| Heads | 3 (Sacred) |
| Head Dim | 81 (3^4) |
| Total Params | ~1.95M |
| Ternary Size | ~390 KB |
| LR | 1e-3 |

**Scientific Metrics to calculate:**
- Bits/parameter: 1.58 (log2(3) for ternary)
- Compression ratio vs float32: 32 / 1.58 = 20.25x
- Memory efficiency: 1.95M params in 390 KB
- Consciousness threshold: 0.618 (phi inverse)
- Trinity identity: phi^2 + 1/phi^2 = 3.0

**Platform Comparison (if benchmark available):**
Run `cd /Users/playra/trinity-w1 && zig-out/bin/hslm-bench` and present results as a comparison table.

### Output Format

Present as a structured dashboard with clear sections:

```
═══════════════════════════════════════════════
  HSLM TRAINING OBSERVATORY
═══════════════════════════════════════════════

[PROCESS]     Running/Stopped, step N/100K, CPU%
[CHECKPOINTS] N checkpoints, latest at step X
[LOSS CURVE]  Table: step | loss | perplexity | delta
[CONVERGENCE] Rate, trend, estimated completion
[ARCHITECTURE] Model summary table
[BENCHMARKS]  Platform comparison (if available)
[FPGA]        Bitstream status, programmer status
[SCIENTIFIC]  Bits/param, compression, sacred constants

═══════════════════════════════════════════════
  PAPER-READY SUMMARY (arXiv format)
═══════════════════════════════════════════════
```

For the paper-ready summary, format as:
> **Model**: HSLM-1.95M (Hybrid Symbolic Language Model)
> **Architecture**: 3-block ternary transformer, 729-token vocab, 243-dim embeddings
> **Training**: N steps on TinyStories, batch 9, lr 1e-3, AdamW
> **Best Loss**: X.XXX (perplexity Y.YY) at step Z
> **Efficiency**: 1.58 bits/param, 390 KB ternary, 20x compression vs float32
> **Hardware**: Apple Silicon (M-series) + Artix-7 FPGA inference at 28.5ms
