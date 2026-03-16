---
name: train
description: HSLM training analytics dashboard — live process status, checkpoint loss curve, model architecture, platform benchmarks, FPGA status, and scientific metrics. Use when checking training progress, loss convergence, or preparing paper-ready results.
argument-hint: [focus] (status, loss, bench, fpga, paper, all)
allowed-tools: Bash(tri *), Bash(cat *), Bash(ls *), Bash(tail *), Bash(date *), Read, Grep, Glob
context: fork
---

# 🧠 HSLM Training Observatory

## Step 1: Render ANSI Dashboard (REQUIRED)

Run the full colored ANSI dashboard:

!`cd /Users/playra/trinity-w1 && ./zig-out/bin/tri train dashboard 2>&1`

This outputs the complete observatory: architecture, farm overview, leaderboard (top 15), accounts, loss curves (sparklines), alerts (stalled/diverged/stuck), ETA, local checkpoints, scientific metrics, and recommendations.

## Step 2: Additional Data (if $ARGUMENTS specified)

### If focus=fpga:
!`ls -lh /Users/playra/trinity-w1/fpga/openxc7-synth/hslm_full_top.bit 2>/dev/null && echo "✅ Bitstream ready" || echo "❌ No bitstream"; ps aux | grep -E "jtag_program|flash_auto|openocd" | grep -v grep 2>/dev/null || echo "🔌 No FPGA programmer running"`

### If focus=paper:
Add arXiv summary block:
- Model: HSLM-1.95M, ternary {-1,0,+1}, 1.58 bits/param
- Best result: R33 PPL=4.6 at 100K (LAMB 1e-3, cosine)
- Zero-DSP FPGA inference: 5000 tok/s on Artix-7

### Run History (reference)
| Run | Host | Steps | LR | Optim | Schedule | Best Loss | PPL | Status |
|-----|------|-------|----|-------|----------|-----------|-----|--------|
| v1 | M1 Pro | 100K | 1e-3 | adam | flat | 5.50 | 245 | done |
| v3R | Railway | 100K | 1e-4 | adamw | cosine | 4.88 | 131 | done |
| v4R | Railway | 100K | 3e-4 | adam | cosine | 4.83 | 125 | done |
| R33 | Railway | 100K | 1e-3 | lamb | cosine | 1.53 | 4.6 | KING |

## Step 3: Telegram Broadcast (REQUIRED)

After the dashboard, compose a human-readable summary in Russian.

**Message rules:**
1. Language: Russian only, casual tone (as if writing to a colleague in Slack)
2. Numbers: spell out in words! "тридцать восемь" NOT "38", "два девяносто шесть" NOT "2.96"
   - Exception: service names stay as-is (R5, C1v2, W6-8)
3. Structure: 3-5 sentences, NOT bullet lists
4. Emoji: 2-3, naturally woven in
5. Focus: leader, how many training, crashes, finishers, ETA

Set `TG_TEXT` to the training narration (no mood signature `[emoji mood]`).
Set `TG_MODE=dedup`, `TG_DEDUP_FILE=.trinity/tg_dedup_train.hash`.
Then execute the shared Telegram template from `.claude/skills/_shared/telegram.md`.

**NOTE:** `/train` uses dedup mode (skips if data unchanged). Only `/tri` manages the pinned dashboard.
