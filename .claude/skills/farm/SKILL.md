---
name: farm
description: HSLM training farm management — service status, evolution, leaderboard, recycle, inject configs, kill underperformers. Central dashboard for 152 Railway training workers across 8 accounts.
argument-hint: [status|evolve|recycle|inject|kill <name>|leaderboard|full]
allowed-tools: Bash(tri *), Bash(cat *), Bash(python3 *), Bash(ls *), Bash(tail *), Bash(ssh *), Bash(curl *), Bash(date *), Bash(grep *), Read, Grep, Glob
context: fork
---

# 🌾 HSLM Training Farm

For language detection and translations, follow `.claude/skills/_shared/language.md`.
For system state collection, follow `.claude/skills/_shared/data_collection.md`.
For output formatting conventions, follow `.claude/skills/_shared/output_format.md`.

## Mode Detection

Check $ARGUMENTS:
- "status" or empty → **MODE=STATUS** (farm overview + active services)
- "evolve" → **MODE=EVOLVE** (run evolution cycle)
- "recycle" → **MODE=RECYCLE** (recycle underperformers)
- "inject" → **MODE=INJECT** (inject new configs from evolution)
- "kill <name>" → **MODE=KILL** (kill specific service)
- "leaderboard" → **MODE=LEADERBOARD** (top performers by PPL)
- "full" → **MODE=FULL** (all of the above)

## Data Sources

### Railway Accounts (8 total)
Read tokens from `.env`:
- `RAILWAY_API_TOKEN` (PRIMARY)
- `RAILWAY_API_TOKEN_2` through `RAILWAY_API_TOKEN_8`
- FARM-7: 24 workers (hslm-w8-1..24), wave 8
- FARM-8: 24 workers (hslm-w8-25..48), wave 8

### Evolution State
!`cat /Users/playra/trinity-w1/.trinity/evolution_state.json 2>/dev/null | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin)
  gen=d.get('generation',0)
  pop=d.get('population',[])
  best=sorted(pop, key=lambda x: x.get('fitness',0), reverse=True)[:5]
  print(f'Generation: {gen} | Population: {len(pop)}')
  for i,p in enumerate(best):
    print(f'  #{i+1} {p.get(\"name\",\"?\")}: fitness={p.get(\"fitness\",0):.4f} ppl={p.get(\"ppl\",\"?\")}'  )
except: print('No evolution data')
" 2>/dev/null || echo "No evolution state"`

### Farm Health
!`/Users/playra/trinity-w1/zig-out/bin/tri train status 2>&1 | head -20 || echo "tri train unavailable"`

## STATUS Mode

Query all 8 Railway accounts for hslm-train services:
```bash
set -a && source /Users/playra/trinity-w1/.env && set +a
for i in "" _2 _3 _4 _5 _6 _7 _8; do
  TOKEN_VAR="RAILWAY_API_TOKEN$i"
  TOKEN="${!TOKEN_VAR}"
  [ -z "$TOKEN" ] && continue
  echo "=== Account${i:-_1} ==="
  curl -s -X POST "https://railway.com/graphql/v2" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"query":"query{projects{edges{node{id name services{edges{node{id name deployments(first:1){edges{node{status createdAt}}}}}}}}}}"}'  2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
for p in d['data']['projects']['edges']:
  proj=p['node']
  for s in proj['services']['edges']:
    svc=s['node']
    dep=svc['deployments']['edges']
    status=dep[0]['node']['status'] if dep else 'NO_DEPLOY'
    if 'hslm' in svc['name'].lower() or 'train' in svc['name'].lower():
      print(f'  {svc[\"name\"]}: {status}')
" 2>/dev/null
done
```

Display as table:
```
🌾 FARM STATUS
| # | Service | Account | Status | Uptime |
|---|---------|---------|--------|--------|
```

## LEADERBOARD Mode

Read from evolution state + any available checkpoint logs:
```
🏆 LEADERBOARD (by PPL)
| Rank | Config | PPL | Steps | LR | Schedule | Batch |
|------|--------|-----|-------|----|----------|-------|
```

Sort by PPL ascending (lower = better). Highlight top 3 with 🥇🥈🥉.

## EVOLVE Mode

1. Read current evolution state
2. Run `tri farm evolve` or execute evolution logic:
   - Select top 50% by fitness
   - Crossover hyperparameters (LR, batch, grad_clip)
   - Mutate with 10% probability
   - Generate new generation configs
3. Save new generation to `.trinity/evolution_state.json`
4. Report: generation N → N+1, N configs generated

## RECYCLE Mode

1. Identify services with:
   - PPL stagnated for >10K steps
   - Loss diverged (NaN or >100)
   - Status: CRASHED or STOPPED
2. For each candidate: show name, reason, last PPL
3. Ask for confirmation before killing
4. Kill via `tri farm kill <name>` or Railway API
5. Deploy replacement with next evolution config

## INJECT Mode

1. Read pending configs from evolution state
2. For each undeployed config:
   - Set env vars: HSLM_OPTIMIZER, HSLM_LR, HSLM_LR_SCHEDULE, HSLM_BATCH_SIZE, HSLM_GRAD_CLIP
   - Deploy to available slot
3. Report: N configs injected to N services

## KILL Mode

Kill specific service by name:
1. Verify service exists and is not the best performer
2. Confirm with user
3. Execute kill via Railway API
4. Log action to GitHub issue #357

## Safeguards

- **NEVER** delete a service that is the current best performer (lowest PPL)
- **NEVER** use `flat` LR schedule — cosine/sacred ONLY
- **NEVER** set `startCommand` on training services — must be null
- **ALWAYS** log every farm action to GitHub issue #357
- **ALWAYS** record experiment results before killing a service
- **ALWAYS** set `builder: NIXPACKS` via `serviceInstanceUpdate`
- **ALWAYS** set `dockerfilePath` via `serviceInstanceUpdate`
- Max 152 concurrent services across 8 accounts

## Output Format

### STATUS (default)
```
🌾 FARM STATUS — Gen {N}

📊 Overview: {active}/{total} services | {N} accounts
🏆 Best: {name} PPL={ppl} @ {steps}K steps
📈 Trend: {improving|stagnating|diverging}

| Service | PPL | Steps | Status |
|---------|-----|-------|--------|

⚡ Actions: {N} ready to recycle, {N} configs pending
```

### FULL
All sections combined: STATUS + LEADERBOARD + evolution state + recommendations.

## Step: Telegram Broadcast

After rendering, send summary to Telegram.
Set `TG_TEXT` to farm summary (active count, best PPL, trend).
Set `TG_MODE=dedup`, `TG_DEDUP_FILE=.trinity/tg_dedup_farm.hash`.
Then execute the shared Telegram template from `.claude/skills/_shared/telegram.md`.

## Step: GitHub Issue Update

After any mutating action (evolve/recycle/inject/kill):
```bash
gh issue comment 357 --body "🌾 Farm action: {action}
- Generation: {N}
- Services affected: {list}
- Result: {outcome}
- Best PPL: {ppl}"
```
