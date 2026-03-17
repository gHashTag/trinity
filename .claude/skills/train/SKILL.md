---
name: train
description: HSLM training analytics dashboard — live process status, checkpoint loss curve, model architecture, platform benchmarks, FPGA status, and scientific metrics. Use when checking training progress, loss convergence, or preparing paper-ready results.
argument-hint: [focus] (status, loss, bench, fpga, paper, all)
allowed-tools: Bash(tri *), Bash(cat *), Bash(ls *), Bash(tail *), Bash(date *), Read, Grep, Glob
context: fork
---

# HSLM Training Observatory v2

## Step 1: Show the Dashboard (REQUIRED)

Run and **display the FULL output to the user as-is**:

!`cd /Users/playra/trinity-w1 && ./zig-out/bin/tri train dashboard 2>&1`

**CRITICAL**: The output of `tri train dashboard` IS the report. Show it COMPLETELY. Do NOT summarize, do NOT rephrase, do NOT hide it. The user wants to SEE the ANSI dashboard output directly.

## Step 2: Your Analysis (after dashboard)

After showing the full dashboard, add a SHORT (5-10 lines) analytical block in Russian:

```
### Аналитика

{emoji} **{topic}**: {one-line insight}
{emoji} **{topic}**: {one-line insight}
{emoji} **{topic}**: {one-line insight}

**Вердикт**: {one sentence — act or wait}
```

Rules:
- Compare leader with R33 PPL=4.6 (verified king)
- Flag any ctx<81 with PPL<50 as mirage risk
- Note which objective (NTP/NCA/JEPA) is winning
- Say the phase: EARLY (<10K) / MIDDLE (10-50K) / LATE (50K+)
- Max 10 lines. Dense. No fluff.

## Step 3: Additional Data (if $ARGUMENTS specified)

### If focus=fpga:
!`ls -lh /Users/playra/trinity-w1/fpga/openxc7-synth/hslm_full_top.bit 2>/dev/null && echo "Bitstream ready" || echo "No bitstream"`

### If focus=paper:
Reference: R33 PPL=4.6 (verified), R18 PPL=6.1 (MIRAGE), R19 PPL=2.04 (UNVERIFIED)

## Step 4: Telegram Broadcast (REQUIRED)

Compose a SHORT narration in Russian (3-5 sentences, Slack tone).

Set `TG_TEXT` to the narration.
Set `TG_MODE=dedup`, `TG_DEDUP_FILE=.trinity/tg_dedup_train.hash`.
Then execute the shared Telegram template from `.claude/skills/_shared/telegram.md`.
