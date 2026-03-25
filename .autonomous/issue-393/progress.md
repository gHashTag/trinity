## Task: Issue #393 — IGLA Bench — Ternary Needle In A Haystack Benchmark

**Status**: COMPLETE ✅

**Completed Steps:**

### ✅ Phase 1: Core Modules (Complete)
- [x] `src/bench/igla_bench.zig` — Weight formats, Needle types, Haystack
- [x] `src/bench/igla_tasks.zig` — 4 task generators
- [x] `src/bench/igla_metrics.zig` — CSV export, heatmap
- [x] `src/bench/igla_runner.zig` — Matrix execution
- **Tests:** 11/11 passing

### ✅ Phase 2: Evolution Integration (Complete)
- [x] Added IGLA metrics to ServiceEntry:
  - `igla_score` — overall retrieval [0,1]
  - `igla_format_accuracy[4]` — per-format accuracy
  - `igla_retrieve/multi/ternary/chain_acc` — per-task accuracy
  - `igla_latency_ms`, `igla_tok_per_sec` — performance
- [x] `runIGLABenchmark(allocator, service)` function in evolution.zig
- [x] IGLA evaluation in `evolveStep`: every 30K steps, 10K cooldown
- [x] Build passes: `zig build tri`

### ✅ Phase 3: Multi-Objective Fitness (Complete)

#### 1. computeIGLAFitness() Implementation ✅
Location: `src/tri/evolution.zig` lines 258-274

```zig
fn computeIGLAFitness(svc: *const ServiceEntry) f32 {
    const ppl_weight: f32 = 0.6;   // 60% PPL
    const igla_weight: f32 = 0.4;  // 40% IGLA

    // Normalize PPL: 999 -> 0, 2.0 -> 1
    const ppl_normalized = /* ... */;

    // IGLA score: [0,1]
    const igla_score = /* ... */;

    // Penalty: if IGLA < 0.5, fitness cut in half
    const penalty: f32 = if (igla_score < 0.5) 0.5 else 0.0;

    return (ppl_weight * ppl_normalized + igla_weight * igla_score)
           * (1.0 - penalty);
}
```

#### 2. ServiceEntry Update in runIGLABenchmark ✅
Location: `src/tri/evolution.zig` lines 318-324

```zig
// Update service fields with IGLA metrics
service.igla_score = result.accuracy;
service.igla_latency_ms = result.latency_ms;
service.igla_tok_per_sec = result.tok_per_sec;
```

#### 3. Fitness Logging in Leaderboard ✅
Location: `src/tri/evolution.zig` lines 3729-3740

```zig
// IGLA score (as percentage)
if (svc.igla_score > 0) {
    print("| {d:.0}", .{svc.igla_score * 100});
}

// Multi-objective fitness: 60% PPL + 40% IGLA + penalty
const fitness = svc.computeIGLAFitness();
if (svc.igla_score > 0) {
    print("| {d:.0}\n", .{fitness * 100});
}
```

### CLI Usage
```bash
# Single test
tri bench igla --format GF16 --ctx 243 --needles 3 --depth 50

# Full benchmark (420 configs)
tri bench igla --full
```

### Success Criteria
- [x] Build passes (L0 ✅ L1 ✅ tri ✅)
- [x] All 11 IGLA tests pass
- [x] Evolution integration complete
- [x] Multi-objective fitness in PBT (60% PPL + 40% IGLA)
- [x] `tri farm evolve status` shows IGLA columns
- [x] IGLA evaluation in evolveStep (every 30K steps)

## Summary

Issue #393 is **COMPLETE**! All 3 phases done:
1. Core modules (11 tests passing)
2. Evolution integration
3. Multi-objective fitness (computeIGLAFitness)

<promise>TASK_393_DONE</promise>
