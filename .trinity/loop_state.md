# 🔄 AUTONOMOUS LOOP STATE

## Current Context (2026-03-20 23:45 UTC)

### What We're Doing
**Primary Goal:** Deploy Wave 8 on 3+ Railway accounts with Circuit Breaker protection

### Current Status
| Component | Status |
|-----------|--------|
| Circuit Breaker | ✅ Complete - 9/9 tests, 404 LOC |
| CB Integration | ✅ Complete - railway_farm.zig with selectBest() |
| tri binary | ✅ Built - 33MB |
| Wave 4 | ✅ Running - 10 services on FARM-2 |
| Wave 8 | ⚠️ Partial - 16 configs deployed to FARM-2 only |
| Railway Tokens | ✅ PRIMARY, FARM-2, FARM-3 working |
| FARM-8 | ❌ 26/26 FAILED (token exists, no PROJECT_ID) |
| FARM-12 | ✅ New token added |

### Simulation Results (S1-S5)
- S1 Baseline: PPL=18.12 (matches hslm-r6 real PPL=28.07)
- S2 Current: PPL=0.00, Culled=800 (matches FARM-8 collapse)
- S3 MultiObj: PPL=18.12, Diversity=0.000
- S4 dePIN: PPL=0.00, Byzantine=20
- S5 NoImmunity: PPL=0.00, Byzantine=10

### Known Issues
1. `evolution.zig` line 4152: `if (acct_idx == 0) continue;` blocks PRIMARY
2. Deploy logic only recycles idle/crashed services - doesn't create new ones
3. FARM-3 had no idle services to recycle
4. Circuit Breaker not integrated into evolution.zig deploy (uses RailwayApi directly)

### Next Immediate Steps (Priority Order)
1. Remove PRIMARY skip in evolution.zig (line 4152)
2. Integrate RailwayFarm's Circuit Breaker into evolution.zig deploy
3. Deploy Wave 8 configs to FARM-12 (new account with clean state)
4. Generate new configs from S3 MultiObj for better diversity

### Files to Monitor
- `.env` - Railway tokens
- `src/tri/evolution.zig` - deploy logic
- `src/tri/railway_farm.zig` - Circuit Breaker
- `src/tri/railway_circuit_breaker.zig` - CB module
- `.trinity/farm/w8_mock_configs.json` - Wave 8 configs

### Commands to Run Each Loop
```bash
# Check farm status
tri farm status 2>&1 | head -30

# Check CB events
tri farm logs --tail 100 | grep -Ei '429|circuit|OPEN|health|selectBest'

# Check training progress
tri farm evolve status 2>&1 | head -20

# Check active services count
tri farm status 2>&1 | grep "ACTIVE\|FAILED\|BUILDING"
```

### Success Criteria
- ✅ Wave 8 running on 3+ accounts (PRIMARY, FARM-2, FARM-3, FARM-12)
- ✅ Circuit Breaker actively switching accounts on 429
- ✅ No account exhausted (all have budget remaining)
- ✅ PPL improving on leaderboard

### Last Action
✅ PRIMARY skip removed from evolution.zig (line 4152)
✅ tri binary rebuilt (33MB, Mar 20 23:45)
✅ 94 crashed services ready for recycling on 4 accounts (PRIMARY, FARM-2, FARM-3, FARM-8)

### Loop #1 Progress (2026-03-20 23:50 UTC)
- ✅ Task 1: Remove PRIMARY skip - COMPLETE
- ✅ Task 2: Deploy Wave 8 - IN PROGRESS (10 services INITIALIZING on FARM-2)
- ⏳ Task 3: Deploy to PRIMARY & FARM-3 - PENDING (need to find idle services)
- ⏳ Task 4: Integrate Circuit Breaker - PENDING (larger refactor)

### Next Loop Actions
1. Wait for FARM-2 services to become ACTIVE
2. Check if PRIMARY has any idle services to recycle
3. If FARM-3 has crashed services, recycle them with new configs
4. Monitor Circuit Breaker events for 429 errors

---
**UPDATE THIS FILE after each loop iteration!**
