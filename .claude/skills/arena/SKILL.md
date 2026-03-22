---
name: arena
description: Trinity Arena 2.0 — LLM Battle Platform dashboard. Live leaderboard, battle history, scientific metrics, deploy to Railway.
user_invocable: true
---

# Trinity Arena 2.0 — LLM Battle Dashboard

## Overview

Arena is a pure-Zig LLM battle platform with ELO rankings (LMSYS-style).
Binary: `zig-out/bin/arena` | Source: `src/arena/` (7 files, ~1200 LOC)

## Step 1: Collect Arena State

```bash
# Check if arena binary exists
test -f zig-out/bin/arena && echo "ARENA_BIN:OK" || echo "ARENA_BIN:MISSING"

# Check leaderboard data
cat data/arena/leaderboard.json 2>/dev/null || echo "LEADERBOARD:EMPTY"

# Count battle results
wc -l data/arena/arena_results.jsonl 2>/dev/null || echo "BATTLES:0"

# Last 5 battles
tail -5 data/arena/arena_results.jsonl 2>/dev/null

# Check arena server running
lsof -ti:8080 2>/dev/null && echo "SERVER:UP" || echo "SERVER:DOWN"

# Task catalog size
grep -c '.id =' src/arena/tasks.zig 2>/dev/null || echo "0"

# Fighter kinds available
grep -c 'FighterKind' src/arena/types.zig 2>/dev/null || echo "0"

# Check Railway deployment
cat .trinity/arena_deploy.json 2>/dev/null || echo "DEPLOY:NONE"
```

## Step 2: Render Dashboard

```
⚔ TRINITY ARENA 2.0 — LLM Battle Platform
══════════════════════════════════════════════════

📊 НАУЧНАЯ БАЗА
┌─────────────────────────────────────────────────┐
│ ELO System: LMSYS Chatbot Arena compatible      │
│ Formula: E = 1/(1+10^((Rb-Ra)/400)), K=32      │
│ Judge: LLM-as-judge (Anthropic/OpenAI)          │
│ Debiasing: length-bias correction (WildBench)   │
│ Win strength: much_better / slightly_better     │
│ Reference: Zheng et al. 2023 "LMSYS Arena"      │
│            Li et al. 2024 "WildBench"           │
└─────────────────────────────────────────────────┘

🏆 LEADERBOARD
┌──────────────────┬──────┬─────┬─────┬─────┬───────┐
│ Fighter          │ ELO  │ W   │ L   │ T   │ Total │
├──────────────────┼──────┼─────┼─────┼─────┼───────┤
│ {from leaderboard.json, sorted by ELO desc}      │
└──────────────────┴──────┴─────┴─────┴─────┴───────┘

📋 TASK CATALOG: {N} tasks
  math: 7 | coding: 7 | reasoning: 6
  Difficulty: easy/medium/hard

🥊 RECENT BATTLES (last 5)
  {from arena_results.jsonl}

⚙ INFRASTRUCTURE
  Binary:   {OK/MISSING} (zig-out/bin/arena)
  Server:   {UP/DOWN} (:8080)
  Cloud:    {DEPLOYED/NOT DEPLOYED} (Railway)
  Data:     data/arena/

🔬 НАУЧНЫЕ МЕТРИКИ
  Battle convergence: {total battles needed for stable ELO ≈ 30 per pair}
  Coverage: {pairs tested / total possible pairs}
  Judge agreement: {if multiple judges — inter-annotator κ}
  Length-bias corrections: {count from results}
```

## Step 3: Quick Actions

Based on state, suggest actions:

| Condition | Action |
|-----------|--------|
| ARENA_BIN:MISSING | `zig build arena` |
| SERVER:DOWN | `./zig-out/bin/arena serve &` |
| LEADERBOARD:EMPTY | `./zig-out/bin/arena battle "2+2" --a echo --b echo` |
| DEPLOY:NONE | Deploy to Railway (see Step 4) |
| < 30 battles per pair | "Need more battles for stable ELO" |

Print 2-3 concrete commands the user can run.

## Step 4: Cloud Deployment

When user asks to deploy Arena to Railway cloud:

### Dockerfile

Create `deploy/Dockerfile.arena`:
```dockerfile
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y curl xz-utils && \
    curl -L https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz | tar -xJ -C /opt && \
    ln -s /opt/zig-linux-x86_64-0.15.2/zig /usr/local/bin/zig
WORKDIR /app
COPY . .
RUN zig build arena

FROM debian:bookworm-slim
COPY --from=build /app/zig-out/bin/arena /usr/local/bin/arena
RUN mkdir -p /data/arena
ENV ARENA_PORT=8080
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/arena", "serve"]
```

### Railway Deploy Commands

```bash
source .env

# Create service
ARENA_SVC=$(curl -s https://railway.com/graphql/v2 \
  -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"mutation{serviceCreate(input:{name:\"trinity-arena\",projectId:\"aa0efa7f-95e6-4466-8de6-43945a031365\"}){id}}"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['serviceCreate']['id'])")

echo "Arena service: $ARENA_SVC"

# Set config: builder=NIXPACKS won't work, must set dockerfilePath
curl -s https://railway.com/graphql/v2 \
  -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"mutation{serviceInstanceUpdate(input:{serviceId:\\\"$ARENA_SVC\\\",environmentId:\\\"6748f1ad-9c2f-4b71-9a90-67f40ce34dc9\\\",source:{image:\\\"ghcr.io/ghashtag/trinity-arena:latest\\\"}})}\"}\"}"

# Save deploy info
echo "{\"service_id\":\"$ARENA_SVC\",\"deployed_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"url\":\"pending\"}" > .trinity/arena_deploy.json
```

### Docker Build & Push

```bash
docker build -f deploy/Dockerfile.arena -t ghcr.io/ghashtag/trinity-arena:latest .
docker push ghcr.io/ghashtag/trinity-arena:latest
```

## Step 5: CLI Reference

All arena commands (run via `./zig-out/bin/arena` or `tri arena`):

| Command | Description |
|---------|-------------|
| `arena serve` | Start HTTP server on :8080 |
| `arena battle <prompt>` | Run CLI battle (default: trinity-hslm vs echo) |
| `arena battle "X" --a gpt-4o --b claude-sonnet --judge` | Battle with auto-judge |
| `arena leaderboard` | Show ELO rankings |
| `arena bench math` | Run all math tasks |
| `arena bench all` | Run all categories |
| `arena tasks` | List task catalog |
| `arena register <name> <kind> [model]` | Register new fighter |

## Step 6: HTTP API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/battle` | POST | Create battle: `{"prompt":"...","fighter_a":"...","fighter_b":"..."}` |
| `/battle/:id` | GET | Get battle status |
| `/leaderboard` | GET | Current ELO rankings JSON |
| `/tasks` | GET | Task catalog JSON |
| `/battle/:id/vote` | POST | Submit manual vote |

## Scientific References

- **ELO Rating**: Elo, A. (1978). "The Rating of Chessplayers, Past and Present"
- **LMSYS Arena**: Zheng et al. (2023). "Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena"
- **WildBench**: Lin et al. (2024). "WildBench: Benchmarking Language Models with Challenging Tasks from Real Users"
- **Length Bias**: Wang et al. (2024). "Large Language Models are not Fair Evaluators" — verbosity bias in LLM judges
- **K-factor**: K=32 (same as LMSYS default, chess rapid); higher K = faster convergence, more volatile
- **Bradley-Terry**: Arena ELO is equivalent to Bradley-Terry model coefficients when fitted via MLE
- **Bootstrap CI**: For confidence intervals, resample battles 1000x and recompute ELO (not implemented yet)
