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

## ☁️ Railway Training Farm (6 accounts)
!`cd /Users/playra/trinity-w1 && set -a && source .env 2>/dev/null && set +a; ./zig-out/bin/tri farm status 2>&1 || echo "  ⚠️ tri farm not built — run: zig build"`

## 🏆 Evolution Leaderboard (LIVE from evolution_state.json)
!`cd /Users/playra/trinity-w1 && python3 -c "
import json, sys
try:
    with open('.trinity/evolution_state.json') as f:
        state = json.load(f)
    svcs = [s for s in state['services'] if s['status'] == 0 and s['ppl'] < 998]
    svcs.sort(key=lambda x: x['ppl'])
    print(f'Best: {state[\"best_name\"]} PPL={state[\"best_ppl\"]:.2f} best_step={state.get(\"best_step\",0)}')
    print(f'Evolution step: {state[\"evolution_step\"]} | Configs tested: {state[\"total_configs_tested\"]}')
    alive = sum(1 for s in state['services'] if s['status'] == 0 and s.get('step',0) > 0)
    killed = sum(1 for s in state['services'] if s['status'] == 3)
    total = state['service_count']
    print(f'Alive: {alive} | Killed: {killed} | Total: {total}')
    print()
    print('# | Name                 | PPL     | Step   | LR       | Tok/s | Acct')
    print('--|----------------------|---------|--------|----------|-------|-----')
    for i, s in enumerate(svcs[:15]):
        medal = '👑' if i < 3 else '⚡' if s['ppl'] < 10 else '  '
        tps = s.get('tps', 0)
        tps_str = f'{tps:.0f}' if tps > 0 else '—'
        print(f'{medal}{i+1:>2} | {s[\"name\"]:<20} | {s[\"ppl\"]:>7.2f} | {s[\"step\"]:>6} | {s[\"lr\"]:<8} | {tps_str:>5} | {s[\"acct\"]}')
except Exception as e:
    print(f'⚠️ Cannot read evolution state: {e}')
    print('Run: set -a && source .env && set +a && tri farm evolve init')
" 2>&1`

## 📊 Farm Health (LIVE)
!`cd /Users/playra/trinity-w1 && python3 -c "
import json
try:
    with open('.trinity/evolution_state.json') as f:
        state = json.load(f)
    svcs = state['services']
    running = [s for s in svcs if s['status'] == 0 and s.get('step',0) > 0]
    if not running:
        print('No running workers with metrics')
    else:
        ppls = sorted([s['ppl'] for s in running if s['ppl'] < 998])
        steps = [s['step'] for s in running if s['step'] > 0]
        tps_list = [s.get('tps',0) for s in running if s.get('tps',0) > 0]
        at_100k = sum(1 for s in running if s['step'] >= 100000)
        sub5 = sum(1 for p in ppls if p < 5)
        sub10 = sum(1 for p in ppls if p < 10)
        print(f'Workers with metrics: {len(running)}')
        print(f'PPL range: {ppls[0]:.2f} — {ppls[-1]:.2f} (median {ppls[len(ppls)//2]:.2f})')
        print(f'Sub-5 PPL: {sub5} | Sub-10 PPL: {sub10}')
        print(f'Steps range: {min(steps)} — {max(steps)}')
        print(f'At 100K: {at_100k}')
        if tps_list:
            print(f'Tok/s avg: {sum(tps_list)/len(tps_list):.0f}')
        # ETA for leader
        leader = min(running, key=lambda s: s['ppl'])
        ltps = leader.get('tps', 0)
        if ltps > 0 and leader['step'] < 100000:
            remaining = 100000 - leader['step']
            eta_sec = remaining * 1782 / ltps  # ctx=27 * batch=66
            print(f'Leader ETA to 100K: ~{eta_sec/3600:.1f}h ({remaining} steps remaining)')
        # Per-account breakdown
        acct_stats = {}
        for s in svcs:
            a = s['acct']
            if a not in acct_stats:
                acct_stats[a] = {'alive': 0, 'killed': 0, 'total': 0}
            acct_stats[a]['total'] += 1
            if s['status'] == 0 and s.get('step',0) > 0:
                acct_stats[a]['alive'] += 1
            elif s['status'] == 3:
                acct_stats[a]['killed'] += 1
        print()
        acct_names = {0:'PRIMARY', 1:'FARM-2', 2:'FARM-3', 3:'FARM-4', 4:'FARM-5', 5:'FARM-6'}
        print('Account  | Alive | Killed | Total')
        print('---------|-------|--------|------')
        for a in sorted(acct_stats.keys()):
            st = acct_stats[a]
            name = acct_names.get(a, f'FARM-{a+1}')
            print(f'{name:<8} | {st[\"alive\"]:>5} | {st[\"killed\"]:>6} | {st[\"total\"]:>5}')
except Exception as e:
    print(f'⚠️ {e}')
" 2>&1`

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
| v4R | Railway | 100K | 3e-4 | adam | cosine | 4.83 | 125 | ✅ |
| R33 | Railway | 100K | 1e-3 | lamb | cosine | 1.53 | 4.6 | 🏆 verified |

**Key insight:** flat LR schedule = ceiling at loss=6.0. NEVER use flat. Always cosine/sacred.

## 📚 EXPERIENCE LOG
!`wc -l /Users/playra/trinity-w1/EXPERIENCE_LOG.md 2>/dev/null | awk '{print $1}' || echo "0"; grep -c "^### EXP-" /Users/playra/trinity-w1/EXPERIENCE_LOG.md 2>/dev/null || echo "0"; grep -c "SUCCESS" /Users/playra/trinity-w1/EXPERIENCE_LOG.md 2>/dev/null || echo "0"; grep -c "FAILURE" /Users/playra/trinity-w1/EXPERIENCE_LOG.md 2>/dev/null || echo "0"; grep -c "DISCOVERY" /Users/playra/trinity-w1/EXPERIENCE_LOG.md 2>/dev/null || echo "0"; grep -c "WARNING" /Users/playra/trinity-w1/EXPERIENCE_LOG.md 2>/dev/null || echo "0"; tail -1 /Users/playra/trinity-w1/EXPERIENCE_LOG.md 2>/dev/null`

Present as: `N entries (X successes, Y failures, Z discoveries, W warnings). Latest: [EXP-NNN] description`

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
   Local:  [status emoji] description
   Railway: [status emoji] description

🏆 EVOLUTION LEADERBOARD (top 10-15 from evolution_state.json)
   [table: rank, name, PPL, step, LR, tok/s, account]

📊 FARM HEALTH
   Workers: N alive / M killed / T total
   Health: NN/100
   PPL range / Sub-5 / Sub-10 counts
   ETA: leader + tail to 100K

💾 CHECKPOINTS
   [from local dirs]

📉 LOSS CURVE (local checkpoints, sorted by step)
   [with PPL, delta, trend arrows]

🔬 SCIENTIFIC
   Bits/param: 1.58 | Compression: 20.25× | θ: φ⁻¹ = 0.618
   φ² + 1/φ² = 3.0 ✅

🔧 FPGA: [status]

☁️ RAILWAY (per-account breakdown from evolution state)

🎯 RECOMMENDATIONS
   [dynamic based on current state]

⏱️ ETA: leader + tail to 100K
```

### Compute for each checkpoint:
- PPL = exp(loss)
- Delta = loss[n] - loss[n-1]
- Trend: 📈 worse, 📉 better, ➡️ flat (|delta| < 0.1)
- Flag ⚡ if PPL < 10 (phase transition!)

### Model Architecture (reference):
Vocab=729(3⁶) | Embed=243(3⁵) | Hidden=729(3⁶) | Blocks=3 | Heads=3 | Context=81(3⁴) | Params=1.95M | Ternary=1,872KB

### 🎯 Recommendations rules

Based on evolution state:
- If leader approaching 100K → mention RECORD_VERIFIED coming
- If diversity=0 → recommend sacred mutations
- If stagnation > 10K → recommend --tune or wave restart
- If many killed slots → recommend --sacred inject to fill
- Show farm evolve commands: `tri farm evolve status/notify/watch/inject`

### If focus=paper, add arXiv summary block at the end.

## Step: Telegram Broadcast (REQUIRED)

After rendering the dashboard above, compose a human-readable summary in Russian
and send it via `tri notify`. This step is REQUIRED — always send.

**DEDUP RULE:** If the dashboard data is identical to what was just sent (same leader, same PPL, same step), do NOT send to Telegram. Say "no change, skipping Telegram" instead.

### Message rules:
1. Language: Russian only, casual tone (as if writing to a colleague in Slack)
2. Numbers: spell out in words! "тридцать восемь" NOT "38", "два девяносто шесть" NOT "2.96"
   - Exception: service names stay as-is (R5, C1v2, W6-8)
3. Structure: 3-5 sentences, NOT bullet lists
4. Emoji: 2-3, naturally woven in
5. Focus: leader, how many training, crashes, finishers, ETA
6. **Do NOT include mood signature `[emoji mood]` in Telegram messages**

### Send command (regular, NOT pinned):
```bash
export TELEGRAM_BOT_TOKEN="$(grep TELEGRAM_BOT_TOKEN .env 2>/dev/null | cut -d= -f2)"
tri notify --chat "-5160767429" "<narration>"
```

**NOTE:** `/train` sends a regular (unpinned) message. Only `/tri` manages the pinned dashboard.
