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

## ☁️ Railway Slots
!`curl -s -X POST "https://backboard.railway.com/graphql/v2" -H "Authorization: Bearer $(grep RAILWAY_API_TOKEN /Users/playra/trinity-w1/.env | cut -d= -f2)" -H "Content-Type: application/json" -d '{"query":"query($id:String!){project(id:$id){services{edges{node{id name deployments(first:1){edges{node{status}}}}}}}}","variables":{"id":"aa0efa7f-95e6-4466-8de6-43945a031365"}}' 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); nodes=[e['node'] for e in d['data']['project']['services']['edges']]; total=len(nodes); active=len([n for n in nodes if n['deployments']['edges'] and n['deployments']['edges'][0]['node']['status'] in ('DEPLOYING','BUILDING')]); agents=[{'name':n['name'],'status':n['deployments']['edges'][0]['node']['status'] if n['deployments']['edges'] else 'NO_DEPLOY'} for n in nodes if n['name'].startswith('agent-')]; print(json.dumps({'total':total,'active':active,'free':10-total,'agents':agents},indent=2))" 2>/dev/null || echo "⚠️ Railway API unavailable"`

## 📊 Live Training Log (last 15 lines)
!`for log in /Users/playra/trinity-w1/data/checkpoints_v3/train_v3.log /Users/playra/trinity-w1/data/train_v5.log; do if [ -f "$log" ]; then echo "📄 $log"; tail -15 "$log"; echo ""; fi; done 2>/dev/null || echo "No active training logs"`

## 💾 Checkpoints (all dirs)
!`for dir in /Users/playra/trinity-w1/data/checkpoints*/; do if [ -d "$dir" ]; then name=$(basename "$dir"); count=$(ls "$dir"/hslm_step_*.bin 2>/dev/null | wc -l | tr -d ' '); latest=$(ls -t "$dir"/hslm_step_*.bin 2>/dev/null | head -1); if [ -n "$latest" ]; then echo "📁 $name/: $count files, latest: $(basename $latest) ($(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$latest" 2>/dev/null || date -r "$latest" '+%Y-%m-%d %H:%M' 2>/dev/null))"; else echo "📁 $name/: (empty)"; fi; fi; done 2>/dev/null || echo "No checkpoint dirs found"`

## 📉 Loss Curve (checkpoint headers → step, loss)
!`for dir in /Users/playra/trinity-w1/data/checkpoints*/; do if [ -d "$dir" ] && ls "$dir"/hslm_step_*.bin >/dev/null 2>&1; then echo "📁 $(basename $dir):"; for f in $(ls -v "$dir"/hslm_step_*.bin 2>/dev/null); do step_hex=$(xxd -s 8 -l 4 -p "$f" 2>/dev/null); loss_hex=$(xxd -s 12 -l 4 -p "$f" 2>/dev/null); if [ -n "$step_hex" ]; then step=$(python3 -c "import struct; print(struct.unpack('<I', bytes.fromhex('$step_hex'))[0])" 2>/dev/null); loss=$(python3 -c "import struct; print(f'{struct.unpack(\"<f\", bytes.fromhex(\"$loss_hex\"))[0]:.6f}')" 2>/dev/null); ppl=$(python3 -c "import math; print(f'{math.exp($loss):.1f}')" 2>/dev/null); echo "  Step $step | Loss $loss | PPL $ppl | $(basename $f)"; fi; done; echo ""; fi; done 2>/dev/null || echo "No checkpoints"`

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
| v12L | M1 Pro | 16K | 3e-4 | cosine+TWN | 5.73 | 307 | ~4h | ✅ batch=32 |
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

☁️ RAILWAY SLOTS
   Total services: N | Active: N | Free: N/10
   Agent services: [list with status]

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

### 🎯 Slot Recommendation Rules

Generate dynamic recommendations in the dashboard based on Railway slot data:

**If 0 free slots (total >= 10):**
→ "⚠️ All slots busy. Wait or kill idle agents with `tri cloud cleanup`."

**If 1-2 free slots:**
→ Suggest the highest-priority untested training config:
  - v13: LR=5e-4, batch=256, cosine (2x faster than v4R?)
  - v14: LR=1e-4, LAMB optimizer, batch=128
  - v15: Progressive STE (warmup 5K → full at 20K)
→ Reference current best: v4R PPL=125 (LR=3e-4, cosine, batch=128)

**If 3+ free slots:**
→ Suggest training + agent tasks in parallel:
  - 1 slot: next training experiment from list above
  - Remaining slots: issues with `agent:spawn` label (check GitHub)
→ E.g. "1 slot: v13 training. 2 slots: issues #304, #305 via `tri cloud spawn`"

**Untested configs (priority order):**
1. batch=256 (v12L proved batch=32 works, scale up)
2. LR=5e-4 (v5R crashed at 1e-3, try middle ground)
3. LR=1e-4 + LAMB optimizer (src/hslm/simd_ops.zig has LAMB impl)
4. Progressive STE threshold scheduling
5. Context=162 (2×current 81)

### If focus=paper, add arXiv summary block at the end.
