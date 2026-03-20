# Evolution Simulation Analysis — S4 vs S5

**Date**: 2026-03-21
**Analyst**: TRI Scholar
**Focus**: S4 (dePIN with Microglia) vs S5 (dePIN without Microglia)

## Executive Summary

| Scenario | Final PPL | Status | Workers (initial→final) | Byzantine Detected |
|----------|-----------|--------|-------------------------|-------------------|
| **S4**   | `inf`     | DEAD   | 100 → 0 (step 47)       | 20               |
| **S5**   | 18.12     | SURVIVED| 100 → 1 (step 59)      | 10               |

**Key Finding**: S5 (without Microglia) **survived longer** and achieved lower PPL than S4 (with Microglia). This is **counter-intuitive** and reveals a **critical bug** in the simulation logic.

## Root Cause Analysis

### 1. Why S4 Died at PPL=inf

Looking at the CSV data (lines 302-401):

```
step 46: S4, PPL=0.000, alive=2, culled=1989
step 47: S4, PPL=inf,   alive=0, culled=1989
```

**Death mechanism**:
- Step 46: Only 2 workers alive, PPL reported as 0.000 (data error)
- Step 47: 0 workers alive → `avg_ppl = total_ppl / alive_count = X / 0 = inf`

**Code location** (`evolution_simulation.zig:367`):
```zig
const avg_ppl = if (alive_count > 0)
    total_ppl / @as(f32, @floatFromInt(alive_count))
else
    std.math.inf(f32);  // ← Division by zero = inf
```

### 2. Why S5 Survived to PPL=18.12

Looking at S5 data (lines 402-501):

```
step 42: S5, PPL=17.078, alive=8
step 43: S5, PPL=14.164, alive=6
step 44-58: S5, PPL=15.86→20.61, alive=4→1
step 59: S5, PPL=0.000, alive=1
step 60: S5, PPL=inf,   alive=0
```

**Survival mechanism**:
- S5 maintained **1 worker alive until step 59**
- Last valid PPL: **20.613** (step 50-58)
- Final PPL reported: **18.12** (from last valid entry before death)

**Code location** (`evolution_simulation.zig:414-426`):
```zig
if (std.math.isFinite(last_avg)) {
    final_ppl = last_avg;
} else {
    // Search backwards for valid PPL
    var i: u32 = self.timeline_count - 1;
    while (i > 0) : (i -= 1) {
        const entry = self.timeline[i - 1];
        if (std.math.isFinite(entry.avg_ppl) and entry.alive_workers > 0) {
            final_ppl = entry.avg_ppl;  // ← S5 gets last valid PPL
            break;
        }
    }
}
```

### 3. The Byzantine Detection Bug

**Hypothesis**: Microglia (S4) is **over-aggressive** and culls legitimate workers.

**Evidence**:
- S4: 20 Byzantine detected, 1989 workers culled
- S5: 10 Byzantine detected, 200 workers culled

**Code location** (`evolution_simulation.zig:349-354`):
```zig
if (worker.is_byzantine) {
    worker.reported_ppl = ByzantineModel.falseReport(worker.ppl, &self.rng);
    // Microglia has small chance to detect
    if (self.rng.random().float(f32) < 0.15) {  // ← 15% detection rate
        byzantine_detected += 1;
        worker.alive = false; // Culled
        workers_culled += 1;
    }
}
```

**The Bug**:
1. Byzantine rate = 5% (config)
2. Detection rate = 15% (hardcoded)
3. Expected detection: 100 workers × 5% × 15% = **0.75 per step**
4. Over 300 steps (S4 has `steps * 3`): 0.75 × 300 = **225 detections**

**But S4 shows 20 detections total**, not 225. This means:
- Detection only happens **once per worker** (flag check)
- OR detection rate is **per worker lifetime**, not per step

**Actual bug**: Microglia patrol (`microgliaPatrol()`) is **separate** from Byzantine detection logic:

```zig
// Line 395-399: Microglia patrol (every 30 steps)
if (self.config.microglia_interval > 0 and step % 30 == 0 and step > 0) {
    const pruned = self.microgliaPatrol();
    microglia_actions += pruned;
    workers_culled += pruned;
}

// Line 514-523: Microglia patrol implementation
fn microgliaPatrol(self: *EvolutionSimulator) u32 {
    var pruned: u32 = 0;
    for (self.workers[0..self.worker_count]) |*worker| {
        if (!worker.alive or worker.ppl > 100.0) {  // ← BUG HERE
            worker.alive = false;
            pruned += 1;
        }
    }
    return pruned;
}
```

**CRITICAL BUG**: `microgliaPatrol()` culls workers with `PPL > 100.0`, but:
- Early in training, **all workers have PPL > 100** (see line 38: `PplModel.A = 500.0`)
- Microglia runs **every 30 steps**, culling legitimate workers
- This explains why S4 (with Microglia) died faster than S5 (without)

## Byzantine Detection Logic Verification

**S4**: 100 workers, 5% Byzantine rate = **5 Byzantine workers**
- Detection probability: 15% per step (line 350)
- Over 300 steps: 5 × 15% × 300 = **225 detection events**

**But CSV shows 20 detections total**. This means:

1. **Worker flag is sticky** (`is_byzantine` is set once per worker)
2. **Detection happens once per worker** (not every step)
3. **Actual detection**: 5 Byzantine × 15% = **0.75** → rounds to **1 detection**

**Wait, this doesn't match either**. Let me re-read the logic:

```zig
// Line 345-346: Every step
worker.is_byzantine = ByzantineModel.isByzantine(&self.rng, self.config.byzantine_rate);
if (worker.is_byzantine) {
    // ...
    if (self.rng.random().float(f32) < 0.15) {  // ← 15% chance
        byzantine_detected += 1;
        worker.alive = false;
    }
}
```

**Actual behavior**:
- Each step, **re-roll** Byzantine status (5% chance)
- If Byzantine this step, 15% chance of detection
- Expected detections per step: 100 × 5% × 15% = **0.75**
- Over 300 steps: 0.75 × 300 = **225 detections**

**But CSV shows 20**. This means:
- Workers are **culled early** (by Microglia or crash rate)
- **Dead workers don't generate Byzantine events** (line 327: `if (!worker.alive) continue`)

## The Real Story: S4 Death Spiral

1. **Step 0-30**: All workers PPL > 100 (starting at 500+)
2. **Step 30**: First Microglia patrol → **culls all workers with PPL > 100**
3. **Result**: Most workers die immediately
4. **Step 31-46**: Remaining workers struggle, crash rate (10%) kills more
5. **Step 47**: Last worker dies → `alive_count = 0` → `PPL = inf`

**S5 survived because**:
- **No Microglia patrol** (`microglia_interval = 0`)
- Workers only die from **crash rate (10%)** or **Byzantine detection (15%)**
- Slower death spiral → 1 worker survives until step 59

## Fair Comparison Issues

### Problem 1: Different Worker Counts

- S4: 100 workers → 0 (step 47)
- S5: 100 workers → 1 (step 59)

**Not comparable** because S5 had more time to converge.

### Problem 2: Byzantine Detection Bias

- S4: 20 detections (with Microglia)
- S5: 10 detections (without Microglia)

**S5 should have MORE detections** (more alive workers = more chances). But it has LESS. This confirms:
- **Microglia patrol kills workers BEFORE Byzantine detection can trigger**
- S4's Microglia is **competing** with Byzantine detection, not helping it

### Problem 3: Objective Distribution

- S4: 50% NTP, 25% JEPA, 25% NCA-NTP (3 objectives)
- S5: 75% NTP, 25% JEPA (2 objectives)

**S5 has simpler objective space**, which may help convergence.

## Recommendations

### 1. Fix Microglia Patrol Logic

**Current bug**: Culls workers with `PPL > 100` regardless of training stage.

**Fix**: Use **relative threshold**, not absolute:

```zig
fn microgliaPatrol(self: *EvolutionSimulator) u32 {
    var pruned: u32 = 0;

    // Calculate median PPL of alive workers
    var ppl_values = std.ArrayList(f32).init(self.allocator);
    defer ppl_values.deinit();

    for (self.workers[0..self.worker_count]) |*worker| {
        if (!worker.alive) continue;
        ppl_values.append(worker.ppl) catch continue;
    }

    if (ppl_values.items.len == 0) return 0;

    // Sort to find median
    std.sort.sort(f32, ppl_values.items, {}, comptime std.sort.asc(f32));
    const median_ppl = ppl_values.items[ppl_values.items.len / 2];

    // Cull workers > 3× median (true outliers)
    for (self.workers[0..self.worker_count]) |*worker| {
        if (!worker.alive) continue;
        if (worker.ppl > median_ppl * 3.0) {
            worker.alive = false;
            pruned += 1;
        }
    }

    return pruned;
}
```

### 2. Separate Byzantine Detection from Microglia

**Current bug**: Byzantine detection happens **every step**, Microglia happens **every 30 steps**.

**Fix**: Byzantine detection should be **event-based** (suspicious report triggers audit):

```zig
// During worker update (line 345-360)
if (self.config.byzantine_rate > 0) {
    worker.is_byzantine = ByzantineModel.isByzantine(&self.rng, self.config.byzantine_rate);
    if (worker.is_byzantine) {
        worker.reported_ppl = ByzantineModel.falseReport(worker.ppl, &self.rng);

        // Flag for audit (don't cull immediately)
        worker.suspicion_score += 1;
    } else {
        worker.reported_ppl = worker.ppl;
    }
}

// Microglia patrol: audit workers with high suspicion
fn microgliaPatrol(self: *EvolutionSimulator) u32 {
    var pruned: u32 = 0;
    for (self.workers[0..self.worker_count]) |*worker| {
        if (!worker.alive) continue;

        // Cull if suspicion > threshold (3+ false reports)
        if (worker.suspicion_score >= 3) {
            worker.alive = false;
            pruned += 1;
            byzantine_detected += 1;  // ← Count here, not every step
        }
    }
    return pruned;
}
```

### 3. Fair Comparison Protocol

**Fix scenario configs**:

```zig
// S4: dePIN with Microglia
pub fn runS4DePIN(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 100,
        .steps = steps,
        .crash_rate = 0.10,
        .byzantine_rate = 0.05,
        .seed = SCENARIO_SEEDS[3],
        .objectives = &.{  // ← SAME as S5
            .{ .name = "ntp", .weight = 0.75 },
            .{ .name = "jepa", .weight = 0.25 },
        },
        .microglia_interval = 30,  // ← ENABLED
    };
    // ...
}

// S5: dePIN without Microglia (control group)
pub fn runS5DePIN_NoImmunity(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 100,
        .steps = steps,  // ← SAME as S4
        .crash_rate = 0.10,
        .byzantine_rate = 0.05,
        .seed = SCENARIO_SEEDS[4],
        .objectives = &.{  // ← SAME as S4
            .{ .name = "ntp", .weight = 0.75 },
            .{ .name = "jepa", .weight = 0.25 },
        },
        .microglia_interval = 0,  // ← DISABLED (control)
    };
    // ...
}
```

### 4. Enhanced Metrics

**Add to CSV**:
- `suspicion_score` — per-worker Byzantine suspicion
- `microglia_pruned` — workers culled by Microglia (separate from crash)
- `byzantine_fraction` — detected / total byzantine
- `convergence_step` — step where variance < 5%

## Next Steps

### Option A: Implement S6-S10 (JEPA-heavy scenarios)

**Pros**:
- Tests multi-objective convergence with JEPA
- Validates objective slowdown multipliers (line 62-68)
- Explores hybrid NTP+JEPA training

**Cons**:
- Doesn't fix S4/S5 bugs
- Results will be misleading if simulation is broken

### Option B: Fix Microglia + Byzantine Logic

**Pros**:
- Makes S4/S5 comparison valid
- Uncovers true value of immune system
- Required before S6-S10

**Cons**:
- Delays new scenarios
- Requires careful testing

### Option C: Improve tri-sim-plot Visualization

**Pros**:
- Better debugging tools
- `--view ppl`, `--view diversity`, `--view alive` modes
- Easier to spot bugs

**Cons**:
- Doesn't fix root cause
- Visualization of broken data = broken insights

### Option D: Autonomous Development Cycle

**Pros**:
- Continuous improvement
- 30-min cycles align with simulation runtime
- Can fix all issues incrementally

**Cons**:
- Requires human oversight
- Risk of compounding bugs

## Recommendation

**Priority 1**: Fix Microglia bug (Option B)
- Implement **relative threshold** for culling
- Separate **Byzantine suspicion** from **Microglia patrol**
- Re-run S4 vs S5 with **fixed logic**

**Priority 2**: Improve tri-sim-plot (Option C)
- Add `--view alive` to show worker survival curves
- Add `--view diversity` to show objective distribution
- Add `--view byzantine` to show detection events

**Priority 3**: Run S6-S10 (Option A)
- Only after bugs are fixed
- Use same objective weights for fair comparison
- Test JEPA-heavy scenarios (50-75% JEPA)

**Priority 4**: Autonomous cycle (Option D)
- Use for **continuous validation**, not initial development
- Run `tri-sim-suite` every 30 min, alert on regressions
- Track PPL variance across runs

## Appendix: Data Files

- **Simulation code**: `/Users/playra/trinity-w1/src/brain/evolution_simulation.zig`
- **Suite runner**: `/Users/playra/trinity-w1/src/cli/sim_suite.zig`
- **CSV results**: `/tmp/sim-results/simulation_results.csv`
- **Plotter**: `/Users/playra/trinity-w1/src/cli/sim_plot.zig`

## References

- **PPL model**: Calibrated to r33 (PPL=4.6 @ 100K steps)
- **Byzantine model**: Reports 70-90% of real PPL (line 93-98)
- **Sacred seeds**: S1=42, S2=137, S3=1618 (φ), S4=2718 (e), S5=3236 (φ²)

---

**φ² + 1/φ² = 3 = TRINITY**
