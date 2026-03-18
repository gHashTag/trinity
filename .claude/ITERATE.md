# /iterate — Trinity Training Farm Auto-Pilot

## Cycle (every 15 min or manual /iterate)

### 1. DIAGNOSE (30s)
Check all 3 accounts via GraphQL. Record: slots free, crashed, running, finished.

### 2. FIX (1 min)
- Crashed → check logs → fix startCommand/env vars → redeploy
- Token dead → notify user (can't fix programmatically)
- Data missing → verify train_100k.txt baked in Docker image
- Build failed → check Dockerfile.hslm-train, retry with usePreviousImageTag
- LR=0 / loss flat → ONLY cosine schedule (flat = dead by 20K)
- startCommand bug → must be null (use Dockerfile ENTRYPOINT)

### 3. FILL (2 min)
- Finished → record result in .trinity/experiments.json → launch next from queue
- Free slot → create service → set env vars → deploy
- Goal: 0 idle slots
- Use variableCollectionUpsert + serviceInstanceRedeploy

### 4. ANALYZE (1 min)
- Compare running experiments by loss/PPL at same step count
- Kill diverging (avg10 rising 3 measurements in a row)
- Identify leader → create variations in queue
- Current leader: v4R PPL=125, challenger: v13L PPL=187@20K

### 5. CODE (if needed)
- New feature blocks training → implement in Zig
- Test fails → fix
- Performance issue → profile → optimize
- Always: `zig build` + `zig test` — no bash

### 6. DOCUMENT (30s)
- Update .trinity/experiments.json with results
- Update SKILL.md train dashboard
- Commit if changes exist

## Rules

1. **Cosine schedule ALWAYS** — flat = dead LR (R4 proved ceiling at loss=6.0)
2. **Don't touch running** — only crashed and finished
3. **0 idle slots** — every free slot = wasted time
4. **Zig only** — no bash scripts
5. **Data in experiment DB** — every result recorded
6. **Leader spawns variations** — best config → +/-lr, +/-batch, +features
7. **Kill the dead** — diverging, speed collapse, LR exhausted

## Experiment Priority Queue

1. Repeat leader (v4R config: adam 3e-4 cosine 100K) on latest code
2. Leader variations (+/-lr, +/-batch, +warmup)
3. New features (phi-scale, adaptive-sparsity, full-ternary, ternary-schedule)
4. LR sweep (1e-4 → 5e-3, cosine only)
5. Batch sweep (66 → 1056, with grad_accum)
6. LAMB optimizer variants (promising: v13L PPL=187@20K)

## Success Metrics

- PPL < 125 → new King (beats v4R)
- tok/s > 15K on Railway → code speedup confirmed
- 30+ parallel experiments → farm loaded
- 0 crashed > 10 min → auto-recovery works

## Farm Accounts

| Account | Project ID | Env ID | Token Env |
|---------|-----------|--------|-----------|
| primary | aa0efa7f-... | 6748f1ad-... | RAILWAY_API_TOKEN |
| farm-2 | ca4303d2-... | d8602284-... | RAILWAY_API_TOKEN_2 |
| farm-3 | 292e8862-... | 912e9084-... | RAILWAY_API_TOKEN_3 |

## Key GraphQL Mutations

```
# Set env vars
variableCollectionUpsert(input: { projectId, environmentId, serviceId, variables: {...} })

# Clear startCommand (CRITICAL — must be null for Zig entrypoint)
serviceInstanceUpdate(serviceId, environmentId, input: { startCommand: null })

# Redeploy
serviceInstanceRedeploy(serviceId, environmentId)

# Delete stale service
serviceDelete(id)
```
