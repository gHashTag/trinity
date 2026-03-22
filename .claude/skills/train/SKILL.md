---
name: train
description: HSLM training analytics dashboard — live process status, checkpoint loss curve, model architecture, platform benchmarks, FPGA status, and scientific metrics. Use when checking training progress, loss convergence, or preparing paper-ready results.
argument-hint: [focus] (status, loss, bench, fpga, paper, all)
allowed-tools: Bash(tri *), Bash(cat *), Bash(ls *), Bash(tail *), Bash(date *), Read, Grep, Glob
context: fork
---

# HSLM Training Observatory v2

## Step 0: Auto-Monitoring Check (REQUIRED)

First, check if monitoring loop is running:

```bash
# Check if 15-min monitoring loop is active
crontab -l 2>/dev/null | grep -q "tri train" && echo "✅ Мониторинг активен" || echo "⚠️ Мониторинг НЕ настроен"
```

If NOT active, offer to set up:
```
⚠️ Автомониторинг не запущен. Для мониторинга каждые 15 минут:
/loop 15m /train
```

## Step 1: Show the Dashboard (REQUIRED)

Run and **display the FULL output to the user as-is**:

!`cd /Users/playra/trinity-w1 && ./zig-out/bin/tri train dashboard 2>&1`

**CRITICAL**: The output of `tri train dashboard` IS the report. Show it COMPLETELY. Do NOT summarize, do NOT rephrase, do NOT hide it. The user wants to SEE the ANSI dashboard output directly.

### Sacred Workers Status (ALWAYS show)

After dashboard, show sacred workers explicitly:

```bash
cd /Users/playra/trinity-w1 && ./zig-out/bin/tri train dashboard 2>&1 | grep -E "(hslm-r6|hslm-r33|hslm-r5|hslm-r12|hslm-r13|hslm-r11|hslm-r18|hslm-w7-50)" | head -10
```

## Step 2: Wave 9 Status (REQUIRED) — S3 MultiObj

**CRITICAL**: Wave 9 is the current active wave with S3 MultiObj profile.

### S3 MultiObj Configuration (ALL 48 services MUST use):

```
HSLM_PROFILE = s3-multiobj
HSLM_CTX = 81
HSLM_NTP_WEIGHT = 0.50
HSLM_JEPA_WEIGHT = 0.25
HSLM_NCA_WEIGHT = 0.25
HSLM_CRASH_TOLERANCE = 0.05
HSLM_WAVE = 9
```

Query ALL 8 Railway accounts (FARM-2 through FARM-12) for wave 9 deployment:
```bash
set -a && source /Users/playra/trinity-w1/.env && set +a
for ACCT in 7 8; do
  TOKEN_VAR="RAILWAY_API_TOKEN_$ACCT"
  TOKEN="${!TOKEN_VAR}"
  PID_VAR="RAILWAY_PROJECT_ID_$ACCT"
  PID="${!PID_VAR}"
  echo "=== FARM-$ACCT ==="
  curl -s https://backboard.railway.app/graphql/v2 \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"query\":\"query { project(id: \\\"$PID\\\") { services { edges { node { name serviceInstances { edges { node { startCommand builder latestDeployment { status } } } } } } } } }\"}" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
svcs=d['data']['project']['services']['edges']
building=running=failed=idle=0
for s in svcs:
    n=s['node']
    inst=n['serviceInstances']['edges']
    st='NO_DEPLOY'
    if inst:
        dep=inst[0]['node'].get('latestDeployment')
        if dep: st=dep.get('status','?')
    if st in ('BUILDING','DEPLOYING','INITIALIZING'): building+=1
    elif st in ('SUCCESS',): running+=1
    elif st in ('FAILED','CRASHED'): failed+=1
    else: idle+=1
    print(f'  {n[\"name\"]}: {st}')
print(f'  --- {len(svcs)} total: {running} running, {building} building, {failed} failed, {idle} other')
" 2>/dev/null
done
```

Display wave 9 table:
```
### Wave 9 — 48 Workers (ALL 8 Railway accounts)
| Account | Workers | Building | Running | Failed | S3-Ready |
|---------|---------|----------|---------|--------|----------|
| FARM-2  | 6       | ...      | ...     | ...    | ... |
| FARM-3  | 6       | ...      | ...     | ...    | ... |
| FARM-8  | 6       | ...      | ...     | ...    | ... |
| FARM-9  | 6       | ...      | ...     | ...    | ... |
| FARM-10 | 6       | ...      | ...     | ...    | ... |
| FARM-11 | 6       | ...      | ...     | ...    | ... |
| FARM-12 | 6       | ...      | ...     | ...    | ... |
| ...     | ...     | ...      | ...     | ...    | ... |
| TOTAL   | 48      | ...      | ...     | ...    | ... |

Config: S3 MultiObj (NTP 50%, JEPA 25%, NCA 25%), ctx=81, crash_tol=5%
```

## Step 3: Your Analysis (after dashboard)

After showing the full dashboard + wave 9 table, add a SHORT (5-10 lines) analytical block in Russian:

```
### 📊 Аналитика [UTC: $(date -u +%H:%M)]

{emoji} **Лидер**: {name} PPL={val} @ {step} — {insight}
{emoji} **S3 MultiObj**: {count}/{total} активны — {status} (NTP 50%, JEPA 25%, NCA 25%)
{emoji} **Stalled**: {count} воркеров — {action if any}
{emoji} **Эволюция**: Step {step} — {kills} kills за сессию
{emoji} **Волна 7**: {best} w7-50 PPL={val} — {insight}

**Вердикт**: {one sentence — act or wait}
```

Rules:
- Compare leader with R6 PPL=28.07 (current king)
- Flag S3 workers that are STALLED
- Count stalled total vs previous run
- Note which objective (NTP/NCA/JEPA) is winning
- Say the phase: EARLY (<10K) / MIDDLE (10-50K) / LATE (50K+)
- Report wave 9 build progress (how many building/running/failed)
- Max 10 lines. Dense. No fluff.

### S3 Workers Alert

If ANY S3 MultiObj worker is STALLED, add:

```
🚨 **СТОП! S3 воркер {name} stalled на {step} шагов!**
   Действие: railway restart --service {name}
   Профиль: S3 MultiObj (NTP 50%, JEPA 25%, NCA 25%)
```

## Step 4: Additional Data (if $ARGUMENTS specified)

### If focus=fpga:
!`ls -lh /Users/playra/trinity-w1/fpga/openxc7-synth/hslm_full_top.bit 2>/dev/null && echo "Bitstream ready" || echo "No bitstream"`

### If focus=paper:
Reference: R33 PPL=4.6 (verified), R18 PPL=6.1 (MIRAGE), R19 PPL=2.04 (UNVERIFIED)

## Step 5: Telegram Broadcast (REQUIRED)

Compose a SHORT narration in Russian (3-5 sentences, Slack tone).

Set `TG_TEXT` to the narration.
Set `TG_MODE=dedup`, `TG_DEDUP_FILE=.trinity/tg_dedup_train.hash`.
Then execute the shared Telegram template from `.claude/skills/_shared/telegram.md`.
