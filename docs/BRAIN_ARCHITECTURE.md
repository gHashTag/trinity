# Trinity S³AI Brain Architecture

## Overview

Trinity's brain consists of 23 neuroanatomically-inspired modules implementing executive function, emotional processing, decision-making, and performance monitoring.

**Sacred Formula**: φ² + 1/φ² = 3 = TRINITY

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v5.1 | 2026-03-19 | Basal Ganglia + Reticular Formation + Locus Coeruleus optimization phases |
| v5.0 | 2026-03-18 | Prefrontal Cortex executive decision integration |
| v4.4 | 2026-03-15 | 26-link sequential brain pipeline |

## Brain Regions (23 Modules)

### Core Decision & Action System

| Region | LOC | Tests | Biological Function |
|--------|-----|-------|---------------------|
| **Prefrontal Cortex** | 717 | 26 | Executive Function — decision making, planning, cognitive control |
| **Basal Ganglia** | 889 | 17 | Action Selection — prevents duplicate task execution across agents |
| **Reticular Formation** | 746 | 16 | Broadcast Alerting — event bus for all agents (10K circular buffer) |
| **Locus Coeruleus** | 253 | 13 | Arousal Regulation — exponential backoff with O(1) lookup table |

### Emotional & Memory System

| Region | LOC | Tests | Biological Function |
|--------|-----|-------|---------------------|
| **Amygdala** | 578 | 28 | Emotional Salience — prioritizes urgent/critical events |
| **Hippocampus (Persistence)** | 804 | 15 | Memory Persistence — JSONL event logging for replay |
| **Hippocampus (Health History)** | 305 | 12 | Health Snapshots — brain health trend analysis |
| **Cerebellum (Learning)** | 1601 | 47 | Motor Learning — performance history, adaptive backoff, failure prediction |

### Sensory & Integration

| Region | LOC | Tests | Biological Function |
|--------|-----|-------|---------------------|
| **Thalamus (Logs)** | 435 | 24 | Sensory Relay — Railway live logs relay |
| **Corpus Callosum (Telemetry)** | 412 | 19 | Inter-hemispheric — time-series metrics aggregation |
| **Intraparietal Sulcus** | 186 | 31 | Numerical Processing — f16/GF16/TF3 format conversions |
| **Corpus Callosum (Federation)** | 2166 | 62 | Distributed Coordination — leader election, CRDT state sync |

### Monitoring & Control

| Region | LOC | Tests | Biological Function |
|--------|-----|-------|---------------------|
| **Metrics Dashboard** | 1884 | 61 | Command Center — aggregates all region metrics with trends |
| **Performance Dashboard** | 1013 | 17 | Real-time Performance — SLA monitoring, comparison reports |
| **Brain Alerts** | 1241 | 38 | Critical Notification — health threshold monitoring |
| **Visual Cortex** | 1302 | 31 | Spatial Representation — ASCII brain maps, sparklines, heatmaps |

### Administration & Resilience

| Region | LOC | Tests | Biological Function |
|--------|-----|-------|---------------------|
| **Hypothalamus (Admin)** | 1374 | 26 | Administrative Control — reset, doctor, prune, migrate, backup |
| **State Recovery** | 2037 | 31 | Crash Recovery — persistent state storage with versioning |
| **Microglia** | 512 | 20 | Immune Surveillance — Constant Gardeners: patrol, prune, stimulate regrowth |
| **Thalamic Async Processor** | 2711 | 73 | Non-blocking Operations — async task claim/release, background telemetry |

### Testing & Evolution

| Region | LOC | Tests | Biological Function |
|--------|-----|-------|---------------------|
| **Simulation** | 1197 | 38 | Synthetic Workload — realistic circuit validation |
| **Evolution Simulation** | 854 | 13 | Deterministic Evolution — baseline/current/multi-obj/dePIN scenarios |
| **Observability Export** | 1104 | 40 | External Monitoring — Prometheus, OpenTelemetry export |
| **Benchmarks** | 1295 | 20 | Performance Measurement — throughput, latency, overhead metrics |

**Total Brain Size**: 33,789 LOC across 37 files, 936 tests

## System Architecture Diagram

```
                        ┌─────────────────────────────────────┐
                        │      EXTERNAL INPUTS                 │
                        │  (Railway logs, tasks, metrics)      │
                        └─────────────────┬───────────────────┘
                                          │
                        ┌─────────────────▼───────────────────┐
                        │         THALAMUS (Sensory Relay)     │
                        │    Railway live logs relay           │
                        └─────────────────┬───────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
        ┌───────────▼──────────┐   ┌─────▼──────┐   ┌────────▼────────┐
        │  LOCUS COERULEUS      │   │ AMYGDALA   │   │ PREFRONTAL      │
        │  (Arousal Regulation) │   │ (Salience) │   │ CORTEX          │
        │  • Backoff policy     │   │ • Priority │   │ • Executive      │
        │  • O(1) lookup table  │   │   scoring │   │   decisions     │
        └───────────┬──────────┘   └─────┬──────┘   └────────┬────────┘
                    │                     │                     │
                    └─────────────────────┼─────────────────────┘
                                          │
                        ┌─────────────────▼───────────────────┐
                        │     BASAL GANGLIA (Action Selection) │
                        │  • Task claim registry              │
                        │  • Prevents duplicates              │
                        └─────────────────┬───────────────────┘
                                          │
        ┌─────────────────────────────────┼─────────────────────────────────┐
        │                                 │                                 │
┌───────▼────────┐              ┌─────────▼─────────┐           ┌────────▼────────┐
│ RETICULAR      │              │ CORPUS CALLOSUM   │           │ CEREBELLUM      │
│ FORMATION      │              │ (Telemetry)       │           │ (Learning)      │
│ • Event bus    │              │ • Time-series     │           │ • Adaptive       │
│ • 10K buffer   │              │   aggregation     │           │   backoff        │
└───────┬────────┘              └─────────┬─────────┘           └────────┬────────┘
        │                                 │                                 │
        └─────────────────────────────────┼─────────────────────────────────┘
                                          │
                        ┌─────────────────▼───────────────────┐
                        │      HIPPOCAMPUS (Persistence)       │
                        │  • JSONL event logging              │
                        │  • Health snapshots                │
                        └─────────────────┬───────────────────┘
                                          │
                        ┌─────────────────▼───────────────────┐
                        │   METRICS DASHBOARD (Command Center) │
                        │  • Aggregates all region metrics     │
                        │  • Trend detection                  │
                        └─────────────────┬───────────────────┘
                                          │
        ┌─────────────────────────────────┼─────────────────────────────────┐
        │                                 │                                 │
┌───────▼────────┐              ┌─────────▼─────────┐           ┌────────▼────────┐
│ BRAIN ALERTS   │              │ PERF DASHBOARD    │           │ VISUAL CORTEX   │
│ • Critical     │              │ • SLA monitoring  │           │ • ASCII maps     │
│   threshold    │              │ • Comparison      │           │ • Sparklines     │
│   monitoring   │              │   reports         │           │ • Heatmaps       │
└────────────────┘              └───────────────────┘           └─────────────────┘
```

## Decision Flow

```
THALAMUS (Sensory Relay)
    ↓
AMYGDALA (Emotional Salience) → Priority boost for urgent events
    ↓
LOCUS COERULEUS (Arousal Regulation) → Backoff timing
    ↓
PREFRONTAL CORTEX (Executive Decision)
    ↓
BASAL GANGLIA (Action Selection) → Claim task
    ↓
RETICULAR FORMATION (Broadcast) → Publish event
    ↓
HIPPOCAMPUS (Memory) → Log to JSONL
    ↓
CORPUS CALLOSUM (Telemetry) → Aggregate metrics
    ↓
CEREBELLUM (Learning) → Adaptive backoff
    ↓
METRICS DASHBOARD → Health score
```

## Communication Flow Between Regions

### 1. Task Claim Flow
```
Agent → Basal Ganglia: claim(task_id, agent_id)
  └─→ Success: return true
  └─→ Failure: return false → Locus Coeruleus: backoff delay

Basal Ganglia → Reticular Formation: publish(task_claimed)
  └─→ All agents: poll events since timestamp

Reticular Formation → Hippocampus: record event
Hippocampus → Corpus Callosum: aggregate telemetry
```

### 2. Health Monitoring Flow
```
Metrics Dashboard → Basal Ganglia: get claim count
Metrics Dashboard → Reticular Formation: get event stats
Metrics Dashboard → Locus Coeruleus: get backoff state
  └─→ Aggregate: health_score = weighted_average

Brain Alerts ← Metrics Dashboard: check thresholds
  └─→ Alert triggered: send notification
```

### 3. Federation Flow (Multi-Instance)
```
Instance A → Federation: broadcast state update
  └─→ CRDT merge: last-write-wins with vector clocks

Federation → Leader Election: Raft consensus
  └─→ Leader: coordinate task distribution

Federation → State Recovery: persist state
  └─→ Crash recovery: replay from WAL
```

## Action Levels

| Level | Description | Examples |
|-------|-------------|----------|
| **Level 0** | Read-only | farm_status, arena_status, doctor_scan |
| **Level 1** | Soft write | doctor_quick, git_commit, notify |
| **Level 2** | Dangerous | farm_recycle, cloud_spawn, cloud_kill |

## Performance Baseline Data

### Phase 1-3 Optimization Results

| Region | Baseline | Optimized | Improvement | Notes |
|--------|----------|-----------|-------------|-------|
| **Basal Ganglia** | ~50k OP/s | TBD | TBD | Stack-based claim (Phase 1) |
| **Reticular Formation** | ~100k OP/s | TBD | TBD | Ring buffer optimization |
| **Locus Coeruleus** | ~10M OP/s | ~10M OP/s | O(1) lookup table | Exponential backoff table |
| **Amygdala** | ~5M OP/s | TBD | TBD | Salience calc optimization |

### Throughput Targets (SLA)

| Operation | P99 Latency | Throughput | Error Rate |
|-----------|-------------|------------|------------|
| task_claim | 1ms | 10k OP/s | 1% |
| event_publish | 500us | 100k OP/s | 0.1% |
| health_check | 100us | 1k OP/s | 0% |
| telemetry_record | 200us | 50k OP/s | 1% |

## Test Coverage

- **Total tests**: 936 passing across 37 files
- **Integration tests**: 50 cross-region tests (integration_test.zig)
- **Stress tests**: 39 high-load scenarios (stress_test.zig)
- **Benchmark tests**: 20 performance measurements (benchmarks.zig)
- **Security tests**: 35 authorization/safety checks (security_test.zig)

## Code Quality Improvements Summary

### Phase 1 Optimizations (dc8d1fca95)
- Fixed memory leaks in event bus string handling
- Improved error propagation through call chain
- Added comprehensive documentation

### Phase 2 Optimizations (3fbd94eb10)
- RwLock for concurrent read access
- Static buffer allocation (zero heap in hot path)
- Single-pass scan algorithms

### Phase 3 Optimizations (509c8d85c6)
- Ring buffer implementation for event bus
- Bug fixes in evolution simulation
- Enhanced error handling

## Region Dependency Graph

```
Basal Ganglia (no deps)
  └─→ Prefrontal Cortex
  └─→ Metrics Dashboard

Reticular Formation (no deps)
  └─→ Prefrontal Cortex
  └─→ Hippocampus
  └─→ Metrics Dashboard

Locus Coeruleus (no deps)
  └─→ Cerebellum

Amygdala (no deps)
  └─→ Metrics Dashboard

Prefrontal Cortex
  └─→ Metrics Dashboard

Metrics Dashboard
  └─→ Brain Alerts

Health History
  └─→ Metrics Dashboard
  └─→ Brain Alerts
```

## Usage

```bash
# Test individual modules
zig test src/brain/basal_ganglia.zig
zig test src/brain/prefrontal_cortex.zig
zig test src/brain/brain.zig

# Run all brain tests
zig build brain-test

# Run benchmarks
zig test src/brain/benchmarks.zig --test-cmd bench

# Run stress tests
zig test src/brain/stress_test.zig

# Run evolution simulation
tri sim-suite

# Check brain health
tri cell status
```

## Key Data Structures

### Basal Ganglia Registry
```zig
pub const Registry = struct {
    claims: StringHashMap(Claim),
    mutex: std.Thread.Mutex,
    // Claim: task_id, agent_id, claimed_at, ttl, heartbeat
};
```

### Reticular Formation EventBus
```zig
pub const EventBus = struct {
    buffer: [10000]StoredEvent,  // Circular buffer
    head_idx: usize,
    tail_idx: usize,
    count: usize,
    stats: Statistics,
};
```

### Locus Coeruleus BackoffPolicy
```zig
pub const BackoffPolicy = struct {
    const EXP_TABLE = [32]u64{...};  // Precomputed
    // O(1) lookup: nextDelay = EXP_TABLE[attempt % 32]
};
```

## φ² + 1/φ² = 3 = TRINITY

The sacred formula permeates the brain architecture:

- **3** Core decision paths: proceed, throttle, alert
- **3** Priority levels: low, medium, critical
- **3** Health states: healthy, degraded, critical
- **3** Memory systems: persistence, health history, state recovery
