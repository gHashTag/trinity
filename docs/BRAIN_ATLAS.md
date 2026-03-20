# S³AI Brain Atlas — Complete Neuroanatomy Guide

## Overview

Trinity's S³AI (Self-Supervised Symbolic AI) Brain consists of 21 neuroanatomically-inspired modules implementing executive function, emotional processing, decision-making, and distributed coordination.

**Sacred Formula**: φ² + 1/φ² = 3 = TRINITY

**Version**: v5.1 (igla-ready)

## Brain Region Map

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         S³AI BRAIN — v5.1                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐              │
│  │ THALAMUS      │  │ BASAL GANGLIA │  │ RETICULAR     │              │
│  │ Sensory Relay │  │ Action Select │  │ Formation     │              │
│  │ thalamus_logs │  │ basal_ganglia │  │ reticular_... │              │
│  └───────────────┘  └───────────────┘  └───────────────┘              │
│                                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐              │
│  │ LOCUS         │  │ AMYGDALA      │  │ PREFRONTAL    │              │
│  │ COERULEUS     │  │ Emotional     │  │ CORTEX        │              │
│  │ Arousal       │  │ Salience      │  │ Executive     │              │
│  └───────────────┘  └───────────────┘  └───────────────┘              │
│                                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐              │
│  │ INTRAPARIETAL │  │ HIPPOCAMPUS   │  │ CORPUS        │              │
│  │ SULCUS        │  │ Memory        │  │ CALLOSUM      │              │
│  │ Numerical     │  │ Persistence   │  │ Telemetry     │              │
│  └───────────────┘  └───────────────┘  └───────────────┘              │
│                                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐              │
│  │ MICROGLIA     │  │ HYPOTHALAMUS  │  │ STATE         │              │
│  │ Immune        │  | Admin         │  │ RECOVERY      │              │
│  │ Surveillance  │  │ Maintenance   │  │ Persistence   │              │
│  └───────────────┘  └───────────────┘  └───────────────┘              │
│                                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐              │
│  │ HEALTH        │  │ METRICS       │  │ ALERTS        │              │
│  │ HISTORY       │  | DASHBOARD     │  │ Critical      │              │
│  │ Snapshots     │  │ Aggregation   │  │ Notification  │              │
│  └───────────────┘  └───────────────┘  └───────────────┘              │
│                                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐              │
│  │ SIMULATION    │  │ OBSERVABILITY │  │ CEREBELLUM    │              │
│  │ Workload      │  │ Export        │  │ Learning      │              │
│  │ Testing       │  │ Monitoring    │  │ Adaptive      │              │
│  └───────────────┘  └───────────────┘  └───────────────┘              │
│                                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐              │
│  │ ASYNC         │  │ FEDERATION    │  │ VISUAL        │              │
│  │ PROCESSOR     │  │ Coordination  │  │ CORTEX        │              │
│  │ Non-blocking  │  │ Multi-instance │  │ Visualization │              │
│  └───────────────┘  └───────────────┘  └───────────────┘              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Complete Brain Regions

| # | Region | Biological Function | Module | LOC | Tests |
|---|--------|---------------------|--------|-----|-------|
| 1 | **Thalamus** | Sensory Relay — Railway live logs relay | `thalamus_logs` | ~200 | ~20 |
| 2 | **Basal Ganglia** | Action Selection — prevents duplicate task execution | `basal_ganglia` | ~180 | ~30 |
| 3 | **Reticular Formation** | Broadcast Alerting — event bus for all agents | `reticular_formation` | ~300 | ~15 |
| 4 | **Locus Coeruleus** | Arousal Regulation — backoff/timing policy | `locus_coeruleus` | ~100 | ~15 |
| 5 | **Amygdala** | Emotional Salience — prioritizes urgent/critical events | `amygdala` | ~200 | ~10 |
| 6 | **Prefrontal Cortex** | Executive Function — decision making and planning | `prefrontal_cortex` | ~200 | ~10 |
| 7 | **Intraparietal Sulcus** | Numerical Processing — f16/GF16/TF3 conversions | `intraparietal_sulcus` | ~300 | ~50 |
| 8 | **Hippocampus** | Memory Persistence — JSONL event logging | `persistence` | ~250 | ~20 |
| 9 | **Corpus Callosum** | Telemetry — time-series metrics aggregation | `telemetry` | ~300 | ~25 |
| 10 | **Microglia** | Immune Surveillance — The Constant Gardeners. Patrols farm every 30min, prunes crashed workers, stimulates regrowth from leaders | `microglia` | ~400 | ~30 |
| 11 | **State Recovery** | Crash Recovery — Persistent state storage with versioning and migration | `state_recovery` | ~350 | ~20 |
| 12 | **Hypothalamus** | Administrative Control — brain maintenance: reset, doctor, prune, migrate, backup, restore | `admin` | ~300 | ~15 |
| 13 | **Health History** | Hippocampal Memory — brain health snapshots for trend analysis | `health_history` | ~250 | ~20 |
| 14 | **Metrics Dashboard** | Command Center — aggregates metrics from all brain regions with trend detection | `metrics_dashboard` | ~400 | ~30 |
| 15 | **Brain Alerts** | Critical Health Notification — monitors health and sends alerts when thresholds are crossed | `alerts` | ~300 | ~20 |
| 16 | **Simulation** | Synthetic Workload Testing — realistic workload testing for brain circuit validation | `simulation` | ~500 | ~25 |
| 17 | **Observability Export** | External Monitoring — Export brain telemetry for Prometheus, OpenTelemetry, and other systems | `observability_export` | ~250 | ~15 |
| 18 | **Cerebellum** | Motor Learning & Adaptive Performance — performance history tracking, pattern recognition, adaptive backoff, failure prediction | `learning` | ~400 | ~30 |
| 19 | **Thalamic Async Processor** | Non-blocking Operations — async task claim/release, event publishing, health checks, background telemetry collection | `async_processor` | ~350 | ~20 |
| 20 | **Federation** | Inter-Hemispheric Communication — distributed multi-instance coordination, leader election, CRDT state sync | `federation` | ~600 | ~25 |
| 21 | **Visual Cortex** | Spatial Representation — ASCII art brain maps, sparklines, heatmaps, 3D visualization | `visualization` | ~500 | ~20 |

## Module Imports

All brain regions are accessible via the main `brain.zig` module:

```zig
const brain = @import("brain");

// Access specific regions
const registry = try brain.basal_ganglia.getGlobal(allocator);
const event_bus = try brain.reticular_formation.getGlobal(allocator);
const backoff = brain.locus_coeruleus.BackoffPolicy.init();
```

## Quick Reference

### Action Selection (Basal Ganglia)

```zig
// Claim a task (atomic, first-come-first-served)
const claimed = try registry.claim(allocator, "task-123", "agent-001", 60000);

// Refresh heartbeat (call every 30s while working)
_ = registry.heartbeat("task-123", "agent-001");

// Complete task
_ = registry.complete("task-123", "agent-001");
```

### Event Streaming (Reticular Formation)

```zig
// Publish event
try event_bus.publish(.task_claimed, .{
    .task_claimed = .{ .task_id = "task-123", .agent_id = "agent-001" }
});

// Poll events since timestamp
const events = try event_bus.poll(since_timestamp, allocator, 100);
defer allocator.free(events);
```

### Backoff Policy (Locus Coeruleus)

```zig
var policy = brain.locus_coeruleus.BackoffPolicy{
    .initial_ms = 1000,
    .max_ms = 60000,
    .multiplier = 2.0,
    .strategy = .exponential,
    .jitter_type = .phi_weighted, // Use golden ratio for jitter
};

const delay_ms = policy.nextDelay(attempt_number);
```

### Emotional Salience (Amygdala)

```zig
const amygdala = brain.amygdala.Amygdala{};
const salience = amygdala.analyzeTask("urgent-security-fix", "dukh", "critical");
// salience.level == .critical
// salience.score >= 80
```

### Executive Decision (Prefrontal Cortex)

```zig
const ctx = brain.prefrontal_cortex.DecisionContext{
    .task_count = 150,
    .active_agents = 10,
    .error_rate = 0.05,
    .avg_latency_ms = 2000,
    .memory_usage_pct = 65,
};

const decision = brain.prefrontal_cortex.PrefrontalCortex.decide(ctx);
// decision.action == .proceed | .throttle | .scale_up | .scale_down | .pause | .alert
```

## Testing

Run all brain module tests:

```bash
# Test all modules
zig build test

# Test specific module
zig test src/brain/basal_ganglia.zig
zig test src/brain/reticular_formation.zig
zig test src/brain/federation.zig
```

## See Also

- **Architecture Overview**: `docs/BRAIN_ARCHITECTURE.md`
- **Module Details**: `docs/S3AI_BRAIN_MODULES.md`
- **Federation Protocol**: `src/brain/FEDERATION_PROTOCOL.md`
- **Source Code**: `src/brain/brain.zig`
