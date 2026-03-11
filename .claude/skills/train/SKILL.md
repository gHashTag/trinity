---
name: train
description: HSLM training analytics dashboard — live process status, checkpoint loss curve, model architecture, platform benchmarks, FPGA status, and scientific metrics. Use when checking training progress, loss convergence, or preparing paper-ready results.
argument-hint: [focus] (status, loss, bench, fpga, paper, all)
---

# 🧠 HSLM Training Observatory

## 📡 Live Process
!`ps aux | grep hslm-train | grep -v grep 2>/dev/null || echo "💤 No local hslm-train process running"`

## 📡 Railway Cloud
!`/Users/playra/trinity-w1/zig-out/bin/tri train status --host railway 2>&1 | tail -10 || echo "☁️ Railway SSH unavailable"`

## 📊 Live Training Log (last 15 lines)
!`for log in /Users/playra/trinity-w1/data/checkpoints_v3/train_v3.log /Users/playra/trinity-w1/data/train_v5.log; do if [ -f "$log" ]; then echo "📄 $log"; tail -15 "$log"; echo ""; fi; done 2>/dev/null || echo "No active training logs"`

## 💾 Checkpoints (all dirs)
!`echo "📁 checkpoints/:"; ls -lt /Users/playra/trinity-w1/data/checkpoints/hslm_step_*.bin 2>/dev/null | head -5 || echo "  (empty)"; echo ""; echo "📁 checkpoints_v3/:"; ls -lt /Users/playra/trinity-w1/data/checkpoints_v3/hslm_step_*.bin 2>/dev/null | head -5 || echo "  (empty)"`

## 📉 Loss Curve (checkpoint headers → step, loss)
!`for dir in /Users/playra/trinity-w1/data/checkpoints /Users/playra/trinity-w1/data/checkpoints_v3; do if ls "$dir"/hslm_step_*.bin >/dev/null 2>&1; then echo "📁 $(basename $dir):"; for f in $(ls -v "$dir"/hslm_step_*.bin 2>/dev/null); do step_hex=$(xxd -s 8 -l 4 -p "$f" 2>/dev/null); loss_hex=$(xxd -s 12 -l 4 -p "$f" 2>/dev/null); if [ -n "$step_hex" ]; then step=$(python3 -c "import struct; print(struct.unpack('<I', bytes.fromhex('$step_hex'))[0])" 2>/dev/null); loss=$(python3 -c "import struct; print(f'{struct.unpack(\"<f\", bytes.fromhex(\"$loss_hex\"))[0]:.6f}')" 2>/dev/null); ppl=$(python3 -c "import math; print(f'{math.exp($loss):.1f}')" 2>/dev/null); echo "  Step $step | Loss $loss | PPL $ppl | $(basename $f)"; fi; done; echo ""; fi; done 2>/dev/null || echo "No checkpoints"`

## 🗂️ Training Data
!`ls -lh /Users/playra/trinity-w1/data/tinystories/real_tinystories.txt 2>/dev/null || echo "⚠️ Training data not found"`

## 🔧 FPGA Status
!`ls -lh /Users/playra/trinity-w1/fpga/openxc7-synth/hslm_full_top.bit 2>/dev/null && echo "✅ Bitstream ready" || echo "❌ No bitstream"; ps aux | grep -E "jtag_program|flash_auto|openocd" | grep -v grep 2>/dev/null || echo "🔌 No FPGA programmer running"`

## 🏆 Run History

| Run | Host | Steps | LR | Schedule | Best Loss | PPL | Time | Status |
|-----|------|-------|----|----------|-----------|-----|------|--------|
| v1 | M1 Pro | 100K | 1e-3 | flat | 5.50 | 245 | 5.8h | ✅ |
| v3R | Railway | 100K | 1e-4 | cosine | 4.88 | 131 | 4.35h | ✅ |
| v4R | Railway | 100K | 3e-4 | cosine | 4.83 | 125 | 3.3h | ✅ |
| v3L | M1 Pro | 100K | 1e-4 | cosine | 5.77 | 322 | ~14h | ✅ |
| v5R | Railway | 100K | 1e-3 | cosine | — | — | — | 💀 killed ×2 |
| PT | M1 Pro | 50K | 1e-3 | flat | 0.984 | 2.68 | — | ⚡ |

## Task

Analyze the data above and present a **rich, visual dashboard** with emojis.

Focus area: $ARGUMENTS (default: all)

### Dashboard Format

ALWAYS output the full dashboard — never compress to one line. Use this format:

```
🧠 ═══════════════════════════════════════════════════
   HSLM TRAINING OBSERVATORY
   ═══════════════════════════════════════════════════

🟢 PROCESS
   Local:  [status emoji] PID, CPU%, step/target, tok/s
   Railway: [status emoji] description

📊 LIVE METRICS (from log tail)
   Step: N/100K [████████░░] 85%
   Loss: X.XX (batch) / X.XX (avg 10)
   PPL:  ~NNN
   LR:   X.XXe-X (cosine decay)
   Speed: N,NNN tok/s

💾 CHECKPOINTS
   Dir1: N files, latest step XK (date)
   Dir2: N files, latest step XK (date)

📉 LOSS CURVE (sorted by step, with trend arrows)
   Step  | Loss  | PPL   | Δ     | Trend
   ------|-------|-------|-------|------
   10K   | 5.91  | 369   | —     |
   20K   | 6.05  | 426   | +0.14 | 📈
   ...

🏆 RUN COMPARISON
   [table with emoji status column]

🔬 SCIENTIFIC
   Bits/param: 1.58 | Compression: 20.25× | θ: φ⁻¹ = 0.618
   φ² + 1/φ² = 3.0 ✅

🔧 FPGA: [status]

⏱️ ETA: ~NN min to completion
```

### Compute for each checkpoint:
- PPL = exp(loss)
- Delta = loss[n] - loss[n-1]
- Trend: 📈 worse, 📉 better, ➡️ flat (|delta| < 0.1)
- Flag ⚡ if PPL < 10 (phase transition!)

### Model Architecture (reference):
Vocab=729(3⁶) | Embed=243(3⁵) | Hidden=729(3⁶) | Blocks=3 | Heads=3 | Context=81(3⁴) | Params=1.95M | Ternary=1,872KB

### If focus=paper, add arXiv summary block at the end.
