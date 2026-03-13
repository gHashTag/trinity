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

## ☁️ Railway Training Farm (3 accounts)
!`cd /Users/playra/trinity-w1 && set -a && source .env 2>/dev/null && set +a; ./zig-out/bin/tri farm status 2>&1 || echo "  ⚠️ tri farm not built — run: zig build"`

## 📊 Live Training Log (last 15 lines)
!`for log in /Users/playra/trinity-w1/data/checkpoints_v13_lamb128/train_v13.log /Users/playra/trinity-w1/data/checkpoints_v3/train_v3.log; do if [ -f "$log" ]; then echo "📄 $log"; tail -15 "$log"; break; fi; done 2>/dev/null || echo "No active training logs"`

## 💾 Checkpoints (all dirs)
!`for dir in /Users/playra/trinity-w1/data/checkpoints*/; do if [ -d "$dir" ]; then name=$(basename "$dir"); count=$(ls -1 "$dir"/hslm_step_*.bin 2>/dev/null | wc -l | tr -d ' '); latest=$(ls -1t "$dir"/hslm_step_*.bin 2>/dev/null | head -1); if [ -n "$latest" ]; then echo "📁 $name/: $count files, latest: $(basename $latest) ($(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$latest" 2>/dev/null || date -r "$latest" '+%Y-%m-%d %H:%M' 2>/dev/null))"; else echo "📁 $name/: (empty)"; fi; fi; done 2>/dev/null || echo "No checkpoint dirs found"`

## 📉 Loss Curve (checkpoint headers → step, loss)
!`for dir in /Users/playra/trinity-w1/data/checkpoints*/; do if [ -d "$dir" ] && ls "$dir"/hslm_step_*.bin >/dev/null 2>&1; then echo "📁 $(basename $dir):"; for f in $(ls -1 "$dir"/hslm_step_*.bin 2>/dev/null | sort); do step_hex=$(xxd -s 8 -l 4 -p "$f" 2>/dev/null); loss_hex=$(xxd -s 12 -l 4 -p "$f" 2>/dev/null); if [ -n "$step_hex" ]; then step=$(python3 -c "import struct; print(struct.unpack('<I', bytes.fromhex('$step_hex'))[0])" 2>/dev/null); loss=$(python3 -c "import struct; print(f'{struct.unpack(\"<f\", bytes.fromhex(\"$loss_hex\"))[0]:.6f}')" 2>/dev/null); ppl=$(python3 -c "import math; print(f'{math.exp(float(\"$loss\")):.1f}')" 2>/dev/null); echo "  Step $step | Loss $loss | PPL $ppl | $(basename $f)"; fi; done; echo ""; fi; done 2>/dev/null || echo "No checkpoints"`

## 🗂️ Training Data
!`ls -lh /Users/playra/trinity-w1/data/tinystories/real_tinystories.txt 2>/dev/null || echo "⚠️ Training data not found"`

## 🔧 FPGA Status
!`ls -lh /Users/playra/trinity-w1/fpga/openxc7-synth/hslm_full_top.bit 2>/dev/null && echo "✅ Bitstream ready" || echo "❌ No bitstream"; ps aux | grep -E "jtag_program|flash_auto|openocd" | grep -v grep 2>/dev/null || echo "🔌 No FPGA programmer running"`

## 🏆 Run History

### Completed Runs
| Run | Host | Steps | LR | Optim | Schedule | Best Loss | PPL | Status |
|-----|------|-------|----|-------|----------|-----------|-----|--------|
| v1 | M1 Pro | 100K | 1e-3 | adam | flat | 5.50 | 245 | ✅ |
| v3R | Railway | 100K | 1e-4 | adamw | cosine | 4.88 | 131 | ✅ |
| v4R | Railway | 100K | 3e-4 | adam | cosine | 4.83 | 125 | ✅ (was best) |
| v3L | M1 Pro | 100K | 1e-4 | adamw | cosine | 5.77 | 322 | ✅ |
| v12L | M1 Pro | 16K | 3e-4 | adam | cosine+TWN | 5.73 | 307 | ✅ batch=32 |
| R4 | Railway | 27K | 3e-4 | adamw | flat | 6.00 | 400 | ☠️ LR dead |
| R7b | Railway | — | 1e-3 | lamb | flat | — | — | ☠️ speed collapse |

**Key insight:** flat LR schedule = ceiling at loss=6.0. LR drops to ~1e-5 by step 20K → no learning. ALL future experiments must use cosine/sacred schedule.

### Wave 5 — Sweet Spot Sweep (2026-03-13, cycle 30)
All cosine schedule. **38 services, 19 recycled → Wave 5**. Tracker: #357

#### PRIMARY (6 services — all active training, cycle 61)
| Run | Service | Step | Avg10 | PPL | Tok/s | Status |
|-----|---------|------|-------|-----|-------|--------|
| C1v2 | trinity | 97.5K | 2.19 | **7.0** | 20,138 | 🏁 FINISHING! |
| C2 | Agents Anywhere | 93.7K | 1.65 | **6.0** | 18,431 | 🟢 approaching 100K! |
| C3 | ubuntu | 80.3K | 1.79 | **7.1** | 7,042 | 🟢 |
| C4v2 | trinity-mcp | 46.3K | 1.87 | **8.2** | 7,699 | 🟢 |
| C7v2 | hslm-v11 | 17.6K | 6.45 | 814 | 10,321 | ⏳ warming |
| C8v2 | hslm-train | 17.9K | 6.54 | 802 | 10,344 | ⏳ warming |

#### FARM-2 (15 services — all training, cycle 61)
| Run | Service | Step | Avg10 | PPL | Tok/s | Status |
|-----|---------|------|-------|-----|-------|--------|
| R5 | hslm-r5 | 32.4K | 0.99 | **3.0** ⚡👑 | 6,289 | 🟢 KING! |
| R6 | hslm-r6 | 31.5K | 3.47 | 29.8 | 13,319 | 🔵 |
| R10 | hslm-r10 | 43.8K | 2.53 | 11.7 | 16,777 | 🔵 |
| R11 | hslm-r11 | 33.1K | 2.36 | **7.2** | 13,074 | 🟢 |
| R12 | hslm-r12 | 23.1K | 3.77 | 53.8 | 8,148 | ⏳ warming |
| R13 | hslm-r13 | 46.5K | 2.42 | 12.7 | 9,459 | 🔵 |
| R18 | hslm-r18 | 89.9K | 1.83 | **5.6** | 11,836 | 🟢 approaching 100K! |
| R19 | hslm-r19 | 43.6K | 2.51 | 11.9 | 8,517 | 🔵 |
| R31 | hslm-r31 | 32.6K | 2.17 | **7.9** | 10,175 | 🟢 |
| R32v2 | hslm-r32 | 11.2K | 2.81 | 16.5 | 8,337 | 🔵 warming |
| R33 | hslm-r33 | 34.6K | 2.08 | **9.1** | 9,148 | 🟢 |
| R34 | hslm-r34 | 49.5K | 3.26 | 22.4 | 14,743 | 🔵 |
| R35 | hslm-r35 | 46.3K | 2.37 | 10.3 | 18,255 | 🔵 |
| R36 | hslm-r36 | 47.2K | 2.06 | 14.2 | 6,499 | 🔵 |
| W5-19 | trinity | 70.5K | 1.89 | **5.5** | 6,255 | 🟢 |

#### FARM-3 (17 services — all training, cycle 61)
| Run | Service | Step | Avg10 | PPL | Tok/s | Status |
|-----|---------|------|-------|-----|-------|--------|
| R14 | hslm-r14 | 14.4K | 5.30 | 202 | 9,066 | ⏳ warming |
| T2v2 | hslm-t1 | 20.2K | 5.06 | 160 | 12,756 | ⏳ warming |
| R21 | hslm-r21 | 51.1K | 2.72 | 17.9 | 10,569 | 🔵 |
| R26v2 | hslm-r26 | 2.3K | 4.97 | 147 | 11,971 | ⏳ warming (recycled) |
| R23v2 | hslm-r23 | 47.3K | 0.95 | **2.9** ⚡👑 | 10,147 | 🟢 KING! |
| R24v2 | hslm-r24 | 33.7K | 2.79 | 14.2 | 21,245 | 🔵 |
| C6v2 | trinity | 33.1K | 3.53 | 23.1 | 6,689 | 🔵 |
| R27 | hslm-r27 | 64.6K | 1.81 | **6.3** | 6,556 | 🟢 |
| R22 | hslm-r22 | 84.7K | 1.97 | **7.5** | 14,446 | 🟢 |
| R29v2 | hslm-r29 | 70.1K | 1.16 | **3.2** ⚡ | 14,138 | 🟢 SUB-5! |
| R15 | hslm-r15 | 48.0K | 2.10 | **7.7** | 7,827 | 🟢 |
| R25v3 | hslm-r25 | 11.6K | 2.93 | 13.0 | 16,671 | 🔵 warming |
| R28 | hslm-r28 | 33.0K | 2.11 | **8.6** | 8,985 | 🟢 |
| R16 | hslm-r16 | 90.6K | 1.86 | **5.5** | 12,645 | 🟢 approaching 100K! |
| R20 | hslm-r20 | 54.0K | 2.17 | 11.8 | 11,982 | 🔵 |
| R17 | hslm-r17 | 84.7K | 2.03 | **7.7** | 11,841 | 🟢 |
| R30 | hslm-r30 | 57.4K | 1.91 | **6.8** | 7,889 | 🟢 |

Status: 🟢=training 🔨=building/deploying

### 💰 Cost Estimates (Railway PRO)

| Resource | Rate | Per Run (8h) | 15 Runs | 75 Runs (max) |
|----------|------|-------------|---------|----------------|
| vCPU | $0.000463/min | $0.22 | $3.33 | $16.67 |
| RAM (2GB) | $0.000231/min/GB | $0.22 | $3.33 | $16.67 |
| **Total** | | **$0.44** | **$6.67** | **$33.33** |

PRO credits: $5/month free + $20 trial = **~$25/account**, 3 accounts = **~$75 budget**
At $0.44/run: can afford **~170 runs** before needing to pay out of pocket.

### 🏗️ Farm Capacity (updated 2026-03-13 cycle 61)

| Account | Max Slots | Services | 🟢 Training | 🔨 Building | Free | API Status |
|---------|-----------|----------|------------|-------------|------|------------|
| primary | 25 | 6 | **6** | 0 | 19 | ✅ MCP+GQL |
| farm-2 | 25 | 15 | **15** | 0 | 10 | ✅ GraphQL |
| farm-3 | 25 | 17 | **17** | 0 | 8 | ✅ GraphQL |
| **Total** | **75** | **38** | **38** | **0** | **37** | |

**🚀 38/38 DEPLOYED. ALL 38 TRAINING. 0 crashed, 0 idle, 0 building!**
**📊 GraphQL tokens ✅ — all 3 accounts confirmed**
**⚠️ R26 at 97.2K — FINISHING IN ~30 MIN! C2 at 90.1K, C1v2 at 89.3K**
**⚠️ 37 free slots BLOCKED** — Railway cumulative creation limit (confirmed cycle 59)
**🔧 FIX:** Contact station.railway.com to raise limit OR create new accounts

### 🏆 Leaderboard (cycle 61 — 2026-03-13)
| # | Run | PPL | Step | Config | Tok/s | Account |
|---|-----|-----|------|--------|-------|---------|
| ⚡⚡⚡👑👑 | **R5** | **2.96** | 32.4K | LAMB 1e-3 cos b=66 ctx=27 | 6,289 | farm-2 |
| ⚡⚡⚡⚡ | **R29v2** | **3.10** | 75.2K | LAMB 1e-3 PHI+restart ctx=21 | 14,136 | farm-3 |
| ⚡⚡⚡ | **R23v2** | **3.66** | 50.5K | LAMB 1e-3 cos b=66 ctx=27 | 10,208 | farm-3 |
| ⚡⚡ | **W5-19** | **5.55** | 70.5K | LAMB 1e-3 cos b=66 ctx=27 | 6,255 | farm-2 |
| ⚡⚡ | **R18** | **5.58** | 89.9K | AdamW 3e-4 cos b=66 ctx=18 | 11,836 | farm-2 |
| ⚡⚡ | **R30** | **5.60** | 59.6K | LAMB 1e-3 cos b=66 ctx=27 | 7,883 | farm-3 |
| ⚡⚡ | **C2** | **6.05** | 93.7K | LAMB 1e-3 cos b=66 ctx=54 | 18,431 | primary |
| ⚡⚡ | **R16** | **6.37** | 95.2K | LAMB 5e-4 cos b=66 ctx=18 | 12,547 | farm-3 |
| ⚡⚡ | **C1v2** | **7.03** | 97.5K | LAMB 1e-3 cos b=66 ctx=27 | 20,138 | primary |
| ⚡⚡ | **C3** | **7.08** | 80.3K | LAMB 1e-3 cos b=66 ctx=27 | 7,042 | primary |
| ⚡⚡ | **R27** | **7.11** | 67.1K | LAMB 1e-3 cos b=66 ctx=27 | 6,548 | farm-3 |
| ⚡⚡ | **R22** | **7.14** | 89.1K | LAMB 1e-3 cos b=66 ctx=22 | 14,330 | farm-3 |
| 🟢 | 21 more services training (PPL 7-54), 5 warming (PPL 147-814) | | | | | |

**🏆 R5 PPL=2.96 KING @ 32.4K (LAMB 1e-3 cos ctx=27) — first sub-3 KING!**
**✅ 38/38 ALL TRAINING. 0 crashed, 0 idle, 0 building!**
**⚡ SUB-5 PPL: R5(2.96), R29v2(3.10), R23v2(3.66)**
**📊 GraphQL tokens ✅ — all 3 accounts confirmed**
**🏁 C1v2 at 97.5K — finishing in ~15 min! R16 at 95.2K, C2 at 93.7K**
**📈 R26v2 recycled successfully — warming at 2.3K steps**
**⛔ 37 free slots: Railway creation limit (confirmed cycle 61)**

### Railway Service UUIDs (for API queries)
| Service | UUID | Account Token |
|---------|------|---------------|
| hslm-v11 | 2b525c13-ab3d-4da0-8e86-fd1abe1ba76a | RAILWAY_API_TOKEN |
| hslm-train | 51a3fe43-eafd-4440-b600-02654f569aec | RAILWAY_API_TOKEN |
| hslm-r10 | 1f30cbdb-ce12-43d3-8afb-abd947da70f0 | RAILWAY_API_TOKEN_2 |
| hslm-r11 | e8d8f5ec-2f34-4f41-a911-e7f41208cdcf | RAILWAY_API_TOKEN_2 |
| hslm-r12 | 9c45fdc4-cf6a-45f9-87ab-d4ffe09aab4b | RAILWAY_API_TOKEN_2 |
| hslm-r13 | f0bd7e32-03c4-43e8-828f-00d5edc32da4 | RAILWAY_API_TOKEN_2 |
| hslm-r18 | b68f1f3b-632c-434e-a7e8-2a0861bcd2c1 | RAILWAY_API_TOKEN_2 |
| hslm-r19 | b31c1078-4e12-451f-8593-c157f24bb101 | RAILWAY_API_TOKEN_2 |
| hslm-r14 | 031f783b-7031-488c-88f4-bd419c4bba43 | RAILWAY_API_TOKEN_3 |
| hslm-r15 | c5e6295d-eb73-4a17-a234-3cd7a53b1320 | RAILWAY_API_TOKEN_3 |
| hslm-r16 | 164e04a2-b0d0-49d5-a6ba-ab1810bf03ca | RAILWAY_API_TOKEN_3 |
| hslm-r17 | e7721613-976b-4111-bb8b-8880fad2c873 | RAILWAY_API_TOKEN_3 |
| hslm-r20 | cccee350-8b71-4d98-94c5-b57b54cda1d5 | RAILWAY_API_TOKEN_3 |
| hslm-t1 | 79c095a7-1b11-4924-b663-7c30c394cb88 | RAILWAY_API_TOKEN_3 |
| hslm-r5 | 5c3f29ff-b38b-47fd-8471-f1209ebda5e4 | RAILWAY_API_TOKEN_2 |
| hslm-r6 | 4088b516-0812-4af0-9cea-145396006ebd | RAILWAY_API_TOKEN_2 |
| hslm-r21 | 383ebb30-fa4a-42f0-8078-56e2dedadaa1 | RAILWAY_API_TOKEN_3 |
| hslm-r22 | 5ba8e185-ca36-4af9-8ac4-e7c8b9b74df2 | RAILWAY_API_TOKEN_3 |
| hslm-r23 | f023ab7d-568d-4c3a-ab8e-7c3eb1ed2a5b | RAILWAY_API_TOKEN_3 |
| hslm-r24 | fba80407-33f7-46f5-af14-df2a29dff90e | RAILWAY_API_TOKEN_3 |
| hslm-r25 | 5c8fc006-cb23-466b-9ad7-284e30ef26de | RAILWAY_API_TOKEN_3 |
| hslm-r26 | 048d2f7f-f232-4fbf-8e97-4c297bddc88f | RAILWAY_API_TOKEN_3 |
| hslm-r27 | 7877c801-5105-4608-8c13-841f67ae1b6b | RAILWAY_API_TOKEN_3 |
| hslm-r28 | b98ff47b-75a7-44fe-aeed-f23f24a03126 | RAILWAY_API_TOKEN_3 |
| hslm-r29 | c425e698-2880-467d-8074-4245895e7d08 | RAILWAY_API_TOKEN_3 |
| hslm-r30 | 4b77d13c-ba78-4929-a53a-7a84fb911863 | RAILWAY_API_TOKEN_3 |

### Railway Project IDs
- Primary: `aa0efa7f-95e6-4466-8de6-43945a031365` (env: `6748f1ad-9c2f-4b71-9a90-67f40ce34dc9`)
- Farm-2: `ca4303d2-4a09-4143-b725-9a3f3977118f` (env: `d8602284-9bba-48bc-94f5-470f9d1fff48`)
- Farm-3: `292e8862-11ce-4542-aff8-35a41e6b3217` (env: `912e9084-e1ad-4bf1-aaea-0a77f9b2a158`)

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

☁️ RAILWAY SLOTS (25/account × 3 = 75 max)
   Total services: N | Active: N | Free: N/25 per account
   Agent services: [list with status]
   💰 Cost: ~$0.67/run (2 vCPU × 8h), ~$10/15 runs

🎯 RECOMMENDATIONS
   Based on free slots + run history + open issues:
   [dynamic recommendations — see rules below]

⏱️ ETA: ~NN min to completion
```

### Compute for each checkpoint:
- PPL = exp(loss)
- Delta = loss[n] - loss[n-1]
- Trend: 📈 worse, 📉 better, ➡️ flat (|delta| < 0.1)
- Flag ⚡ if PPL < 10 (phase transition!)

### Model Architecture (reference):
Vocab=729(3⁶) | Embed=243(3⁵) | Hidden=729(3⁶) | Blocks=3 | Heads=3 | Context=81(3⁴) | Params=1.95M | Ternary=1,872KB

### 🎯 Farm Recommendations

**Current state: Wave 4 running (15 experiments, 3 accounts)**

**When Wave 4 completes (all 15 runs done):**
1. Compare PPL across all runs → find new best
2. If any beats v4R (PPL=125) → that config becomes baseline
3. Key comparisons:
   - Adam vs AdamW vs LAMB (R8/R10 vs R9/R15 vs R13/R19)
   - cosine vs sacred vs cosine-restarts (R8 vs R16 vs R11)
   - grad_accum 2 vs 4 vs 8 (R8 vs R12 vs R19)
   - LR 3e-4 vs 5e-4 (R8 vs R14)
   - vanilla vs adaptive-sparsity vs full-ternary vs ternary-schedule (R8 vs R17 vs R20 vs R18)
4. Plan Wave 5 around winners

**Farm commands (pure Zig, zero curl/Python):**
```bash
tri farm status              # All 3 accounts, service table
tri farm idle                # Only finished/idle services
tri farm recycle             # Set vars + redeploy all idle (default: LAMB 3e-4 cos b=128)
tri farm recycle --lr 1e-3 --batch 256 --optimizer adamw  # Custom config
```

**To get training logs for any experiment:**
Use Railway MCP: `mcp__railway-mcp-server__get-logs(service: "hslm-rXX", logType: "deploy", lines: 10)`
Parse Step line: `Step | Loss | AvgL10 | PPL | LR | C-Ratio | Tok/s`

**Critical learning: NEVER use flat LR schedule.** R4 proved ceiling at loss=6.0 (LR drops to ~1e-5 by 20K steps = no learning).

### If focus=paper, add arXiv summary block at the end.

## Step: Telegram Broadcast (REQUIRED)

After rendering the dashboard above, compose a human-readable summary in Russian
and send it via `tri notify`. This step is REQUIRED — always send.

### Message rules:
1. Language: Russian only, casual tone (as if writing to a colleague in Slack)
2. Numbers: spell out in words! "тридцать восемь" NOT "38", "два девяносто шесть" NOT "2.96"
   - Exception: service names stay as-is (R5, C1v2, W6-8)
3. Structure: 3-5 sentences, NOT bullet lists
4. Emoji: 2-3, naturally woven in
5. Focus: leader, how many training, crashes, finishers, ETA
6. **Do NOT include mood signature `[emoji mood]` in Telegram messages**

### Template guidance:

**All good:**
"Ферма работает, {N spelled out} сервисов учатся 🧠 Лидер {name} —
перплексия {PPL spelled out}, на {step spelled out} шагах. {finishing info}.
Локальная модель на {step spelled out} шагах, потеря {loss spelled out} 📉
Всё стабильно."

**Crashes found:**
"Внимание, {N spelled out} сервисов упали! 🔴 {names}. Остальные {M spelled out}
работают, лидер {name} на перплексии {PPL spelled out}. Нужно починить."

**Finishing soon:**
"🏁 {N spelled out} сервисов вот-вот закончат! {names} — можно
рециклировать на следующую волну. Лидер {name} держит рекорд."

### Send command (regular, NOT pinned):
```bash
export TELEGRAM_BOT_TOKEN="$(grep TELEGRAM_BOT_TOKEN .env 2>/dev/null | cut -d= -f2)"
tri notify --chat "-5160767429" "<narration>"
```

**NOTE:** `/train` sends a regular (unpinned) message. Only `/tri` manages the pinned dashboard.
