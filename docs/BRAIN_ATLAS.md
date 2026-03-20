# S³AI Brain Atlas — Complete Neuroanatomy Guide

## Overview

Trinity's S³AI (Self-Supervised Symbolic AI) Brain consists of 21 neuroanatomically-inspired modules implementing executive function, emotional processing, decision-making, and distributed coordination.

**Sacred Formula**: φ² + 1/φ² = 3 = TRINITY

**Version**: v5.1 (igla-ready)

## Table of Contents

- [Brain Region Map](#brain-region-map)
- [Complete Brain Regions](#complete-brain-regions)
- [Module Imports](#module-imports)
- [Quick Reference](#quick-reference)
- [CLI Examples](#cli-examples)
- [Inter-Region Communication](#inter-region-communication)
- [API Documentation](#api-documentation)
- [Testing](#testing)

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

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                        S³AI BRAIN DATA FLOW                                           │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  INPUTS                                  OUTPUTS                       │
│  ┌──────────────────┐                   ┌──────────────────┐              │
│  │ Tasks            │                   │ Decisions         │              │
│  │ Errors           │                   │ Actions           │              │
│  │ Metrics          │                   │ Events            │              │
│  │ Commands         │                   │ Alerts            │              │
│  └────────┬─────────┘                   └────────┬─────────┘              │
│           │                                      │                          │
│           ▼                                      ▼                          │
│  ┌──────────────────────────────────────────────────────────┐               │
│  │                    SENSORY LAYER                         │               │
│  │  ┌───────────┐ ┌───────────┐ ┌─────────────────────┐    │               │
│  │  │ Thalamus  │ │ Amygdala  │ │ Locus Coeruleus     │    │               │
│  │  │ (Relay)   │ │ (Salience)│ │ (Arousal/Timing)    │    │               │
│  │  └─────┬─────┘ └─────┬─────┘ └─────────┬───────────┘    │               │
│  └────────┼─────────────┼──────────────────┼──────────────────               │
│           │             │                  │                              │
│           ▼             ▼                  ▼                              │
│  ┌──────────────────────────────────────────────────────────┐               │
│  │                   COORDINATION LAYER                      │               │
│  │  ┌───────────┐ ┌───────────┐ ┌─────────────────────┐    │               │
│  │  │ Basal     │ │Reticular  │ │ Prefrontal Cortex   │    │               │
│  │  │ Ganglia   │ │Formation  │ │ (Executive)          │    │               │
│  │  │ (Claim)   │ │ (Events)  │ │ (Decision)           │    │               │
│  │  └─────┬─────┘ └─────┬─────┘ └─────────┬───────────┘    │               │
│  └────────┼─────────────┼──────────────────┼──────────────────               │
│           │             │                  │                              │
│           ▼             ▼                  ▼                              │
│  ┌──────────────────────────────────────────────────────────┐               │
│  │                    MEMORY LAYER                           │               │
│  │  ┌───────────┐ ┌───────────┐ ┌─────────────────────┐    │               │
│  │  │Hippocampus│ │  Corpus   │ │ Health History       │    │               │
│  │  │ (Events)  │ │ Callosum  │ │ (Snapshots)          │    │               │
│  │  │           │ │(Telemetry)│ │                      │    │               │
│  │  └───────────┘ └───────────┘ └─────────────────────┘    │               │
│  └──────────────────────────────────────────────────────────┘               │
│           │
│           ▼
│  ┌──────────────────────────────────────────────────────────┐               │
│  │                   ACTION LAYER                           │               │
│  │  ┌───────────┐ ┌───────────┐ ┌─────────────────────┐    │               │
│  │  │Microglia  │ │Cerebellum │ │ Federation           │    │               │
│  │  │(Patrol)   │ │ (Learning)│ │ (Multi-instance)     │    │               │
│  │  └───────────┘ └───────────┘ └─────────────────────┘    │               │
│  └──────────────────────────────────────────────────────────┘               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
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

## Complete CLI Reference

The S³AI Brain provides CLI commands for all brain regions through the `tri` CLI.

### Brain Health Commands

```bash
# Show overall brain health
tri brain health

# Show specific region status
tri brain region basal-ganglia
tri brain region reticular-formation
tri brain region locus-coeruleus
tri brain region amygdala
tri brain region prefrontal-cortex

# Show all regions with activity levels
tri brain scan

# Visual ASCII brain scan (for TUI display)
tri brain scan --visual
```

### Task Operations (Basal Ganglia)

```bash
# Claim a task for an agent
tri brain claim <task_id> <agent_id>

# Refresh task heartbeat
tri brain heartbeat <task_id> <agent_id>

# Complete a task
tri brain complete <task_id> <agent_id> <duration_ms>

# Abandon a task
tri brain abandon <task_id> <agent_id>

# Show task statistics
tri brain stats
```

### Event Operations (Reticular Formation)

```bash
# Poll recent events
tri brain events --since <timestamp> --limit <count>

# Get event statistics
tri brain events --stats

# Publish custom event
tri brain publish <event_type> --task-id <id> --agent-id <id>

# Stream events in real-time
tri brain stream
```

### Telemetry and Monitoring

```bash
# Show brain telemetry
tri brain telemetry

# Export metrics in Prometheus format
tri brain metrics --format prometheus

# Export metrics in JSON format
tri brain metrics --format json

# Show health history
tri brain history --last <duration>

# Show learning patterns
tri brain learn --patterns
```

### Federation (Multi-Instance)

```bash
# Show federation status
tri federation status

# List all instances
tri federation instances

# Show leader election state
tri federation leader

# Sync state with other instances
tri federation sync

# Show federation metrics
tri federation metrics
```

### Microglia (Immune Surveillance)

```bash
# Run surveillance patrol
tri microglia patrol

# Show patrol report
tri microglia report

# Prune crashed workers
tri microglia prune --crashed

# Prune stalled workers
tri microglia prune --stalled

# Stimulate regrowth from leader
tri microglia regrow --template <name>

# Enter night mode (reduced pruning)
tri microglia night-mode on
tri microglia night-mode off

# Show don't-eat-me list
tri microglia protected
```

### Administration (Hypothalamus)

```bash
# Reset brain state
tri brain admin reset

# Run doctor scan
tri brain doctor scan

# Mark modules for regeneration
tri brain doctor mark --all

# Generate migration plan
tri brain doctor plan

# Backup brain state
tri brain backup --path <path>

# Restore brain state
tri brain restore --path <path>
```

### Visualization (Visual Cortex)

```bash
# Show ASCII brain map
tri brain map

# Show activity heatmap
tri brain heatmap

# Show sparkline trends
tri brain trends

# Show 3D visualization
tri brain visualize --3d
```

### Alerting (Brain Alerts)

```bash
# Show alert configuration
tri brain alerts config

# Show recent alerts
tri brain alerts recent

# Configure alert thresholds
tri brain alerts threshold --health <score> --buffered <count>

# Test alert system
tri brain alerts test
```

### Simulation (Synthetic Workload)

```bash
# Run simulation scenario
tri brain simulate --scenario <name>

# List available scenarios
tri brain simulate --list

# Run with custom parameters
tri brain simulate --tasks <count> --agents <count> --duration <seconds>

# Show simulation results
tri brain simulate --results
```

### Observability Export

```bash
# Export to Prometheus
tri brain export --prometheus --port <port>

# Export to OpenTelemetry
tri brain export --otel --endpoint <url>

# Export to JSON
tri brain export --json --file <path>
```

### Learning System (Cerebellum)

```bash
# Show learning statistics
tri brain learn --stats

# Show learned patterns
tri brain learn --patterns

# Show failure predictions
tri brain learn --predictions

# Reset learning history
tri brain learn --reset
```

### Async Processor

```bash
# Show async processor status
tri brain async status

# Show pending operations
tri brain async pending

# Show background telemetry
tri brain async telemetry
```

### Evolution Simulation

```bash
# Run evolution simulation
tri brain evolve --scenario <name>

# Show evolution progress
tri brain evolve --progress

# Show evolution results
tri brain evolve --results

# Compare scenarios
tri brain evolve --compare <scenarios...>
```

## CLI Examples by Use Case

### Monitoring Agent Swarm Health

```bash
# Quick health check
tri brain health

# Detailed region status
tri brain scan --visual

# Event stream
tri brain stream

# Metrics export
tri brain metrics --format prometheus
```

### Debugging Task Coordination

```bash
# Check task claims
tri brain stats

# View recent events
tri brain events --since -1h

# Check specific task
tri brain claim get <task_id>

# View event history for task
tri brain events --filter task_id:<task_id>
```

### Managing Farm Workers

```bash
# Run microglia patrol
tri microglia patrol

# Prune crashed workers
tri microglia prune --crashed

# Stimulate regrowth from leader
tri microglia regrow --template hslm-r33

# View protected workers
tri microglia protected
```

### Multi-Instance Coordination

```bash
# Check federation status
tri federation status

# View leader election
tri federation leader

# Sync state
tri federation sync

# View all instances
tri federation instances
```

### Performance Analysis

```bash
# View telemetry
tri brain telemetry

# Check trends
tri brain trends

# View learning patterns
tri brain learn --patterns

# Run simulation
tri brain simulate --scenario high-load
```

## Output Formats

The brain CLI supports multiple output formats:

```bash
# JSON output
tri brain health --format json

# Prometheus metrics
tri brain metrics --format prometheus

# Human-readable table
tri brain stats --format table

# Compact format
tri brain scan --format compact
```

## Configuration

Brain configuration is stored in `.trinity/brain/`:

```
.trinity/brain/
├── config.json           # Main configuration
├── alerts.json           # Alert thresholds
├── microglia.json        # Microglia settings
├── federation.json       # Federation config
└── state/                # Persistent state
    ├── claims.json       # Task claims
    ├── events.jsonl      # Event log
    └── telemetry.json    # Telemetry data
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

## Complete CLI Reference

The S³AI Brain is integrated into the `tri` CLI. Here are all available commands:

### Brain Status Dashboard

```bash
# Show overall brain health
tri brain health

# Show specific region status
tri brain region basal-ganglia
tri brain region reticular-formation
tri brain region locus-coeruleus

# Show all regions with activity levels
tri brain scan

# Visual ASCII brain scan (for TUI display)
tri brain scan --visual
```

### Task Claim Operations (Basal Ganglia)

```bash
# Claim a task for an agent
tri brain claim task-123 agent-001

# Refresh task heartbeat
tri brain heartbeat task-123 agent-001

# Complete a task
tri brain complete task-123 agent-001 5000

# Abandon a task
tri brain abandon task-123 agent-001
```

### Event Streaming (Reticular Formation)

```bash
# Poll recent events
tri brain events --since 1710907200000 --limit 100

# Get event statistics
tri brain events --stats

# Publish custom event
tri brain publish task_claimed --task-id task-123 --agent-id agent-001
```

### Telemetry and Monitoring

```bash
# Show brain telemetry
tri brain telemetry

# Export metrics in Prometheus format
tri brain metrics --format prometheus

# Show health history
tri brain history --last 24h

# Show learning patterns
tri brain learn --patterns
```

### Federation (Multi-Instance)

```bash
# Show federation status
tri federation status

# List all instances
tri federation instances

# Show leader election state
tri federation leader

# Sync state with other instances
tri federation sync
```

### Microglia (Immune Surveillance)

```bash
# Run surveillance patrol
tri microglia patrol

# Show patrol report
tri microglia report

# Prune crashed workers
tri microglia prune --crashed

# Stimulate regrowth from leader
tri microglia regrow --template hslm-r33

# Enter night mode (reduced pruning)
tri microglia night-mode on
tri microglia night-mode off
```

## Inter-Region Communication

The brain regions communicate through well-defined patterns:

### 1. Event-Based Communication (Reticular Formation)

Most regions publish events to the Reticular Formation event bus:

```zig
// Basal Ganglia publishes claim events
try event_bus.publish(.task_claimed, .{
    .task_claimed = .{ .task_id = "task-123", .agent_id = "agent-001" }
});

// Other regions poll and react
const events = try event_bus.poll(since_timestamp, allocator, 100);
for (events) |event| {
    switch (event.event_type) {
        .task_claimed => handleTaskClaimed(event.data.task_claimed),
        .task_completed => handleTaskCompleted(event.data.task_completed),
        else => {},
    }
}
```

### 2. Shared State (Basal Ganglia)

Multiple regions access the global task claim registry:

```zig
const registry = try brain.basal_ganglia.getGlobal(allocator);
const claimed = try registry.claim(allocator, task_id, agent_id, ttl_ms);
```

### 3. Telemetry Aggregation (Corpus Callosum)

All regions contribute to the central telemetry:

```zig
var tel = telemetry.BrainTelemetry.init(allocator, 100);
try tel.record(.{
    .timestamp = std.time.milliTimestamp(),
    .active_claims = registry.claims.count(),
    .events_published = event_bus.getStats().published,
    .events_buffered = event_bus.getStats().buffered,
    .health_score = health_score,
});
```

### 4. Federation Messaging (Corpus Callosum)

Distributed instances communicate via federation messages:

```zig
const federation = try brain.federation.getGlobal(allocator);

// Send claim request to federation
const msg = FederationMessage{
    .msg_type = .claim_request,
    .from = federation.my_id,
    .to = target_id,
    .term = federation.election.current_term,
    .timestamp = std.time.milliTimestamp(),
    .data = .{ .claim_request = .{
        .task_id = "task-123",
        .agent_id = "agent-001",
        .ttl_ms = 60000,
    }},
};
```

## API Documentation

### Basal Ganglia (Action Selection)

**File**: `src/brain/basal_ganglia.zig`

The Basal Ganglia prevents duplicate task execution across agents using a CRDT-based claim system.

**Key Types**:
```zig
pub const TaskClaim = struct {
    task_id: []const u8,
    agent_id: []const u8,
    claimed_at: i64,
    ttl_ms: u64,
    status: enum { active, completed, abandoned },
    completed_at: ?i64,
    last_heartbeat: i64,
};

pub const Registry = struct {
    claims: std.StringHashMap(TaskClaim),
    mutex: std.Thread.Mutex,
    // ...
};
```

**Key Functions**:
- `Registry.init(allocator)` - Create new registry
- `registry.claim(allocator, task_id, agent_id, ttl_ms)` - Atomic task claim
- `registry.heartbeat(task_id, agent_id)` - Refresh claim timeout
- `registry.complete(task_id, agent_id)` - Mark task complete
- `registry.abandon(task_id, agent_id)` - Abandon task
- `basal_ganglia.getGlobal(allocator)` - Get global singleton

**Usage Example**:
```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

// Get global registry
const registry = try brain.basal_ganglia.getGlobal(allocator);

// Claim a task (5 minute TTL)
const claimed = try registry.claim(allocator, "task-123", "agent-001", 300000);
if (claimed) {
    // Task claimed successfully, start working
    // Refresh heartbeat every 30s
    _ = registry.heartbeat("task-123", "agent-001");

    // Complete when done
    _ = registry.complete("task-123", "agent-001");
}
```

### Reticular Formation (Broadcast Alerting)

**File**: `src/brain/reticular_formation.zig`

Event streaming system for broadcasting agent events.

**Key Types**:
```zig
pub const AgentEventType = enum {
    task_claimed,
    task_completed,
    task_failed,
    task_abandoned,
    agent_idle,
    agent_spawned,
};

pub const EventData = union(AgentEventType) {
    task_claimed: struct { task_id: []const u8, agent_id: []const u8 },
    task_completed: struct { task_id: []const u8, agent_id: []const u8, duration_ms: u64 },
    // ...
};

pub const EventBus = struct {
    mutex: std.Thread.Mutex,
    events: std.ArrayList(StoredEvent),
    // ...
};
```

**Key Functions**:
- `EventBus.init(allocator)` - Create new event bus
- `event_bus.publish(event_type, data)` - Publish event
- `event_bus.poll(since, allocator, max_events)` - Poll events
- `event_bus.getStats()` - Get statistics
- `reticular_formation.getGlobal(allocator)` - Get global singleton

**Usage Example**:
```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

// Get global event bus
const event_bus = try brain.reticular_formation.getGlobal(allocator);

// Publish task claimed event
try event_bus.publish(.task_claimed, .{
    .task_claimed = .{ .task_id = "task-123", .agent_id = "agent-001" }
});

// Poll for new events
const events = try event_bus.poll(since_timestamp, allocator, 100);
defer allocator.free(events);

for (events) |event| {
    std.log.info("Event: {s}", .{@tagName(event.event_type)});
}
```

### Locus Coeruleus (Arousal Regulation)

**File**: `src/brain/locus_coeruleus.zig`

Exponential backoff policy for agent retry logic with sacred jitter.

**Key Types**:
```zig
pub const BackoffPolicy = struct {
    initial_ms: u64 = 1000,
    max_ms: u64 = 60000,
    multiplier: f32 = 2.0,
    strategy: enum { exponential, linear, constant } = .exponential,
    jitter_type: enum { none, uniform, phi_weighted } = .none,
};
```

**Key Functions**:
- `BackoffPolicy.init()` - Create default policy
- `policy.nextDelay(attempt)` - Get delay for attempt number

**Usage Example**:
```zig
const brain = @import("brain");

var policy = brain.locus_coeruleus.BackoffPolicy{
    .initial_ms = 1000,
    .max_ms = 60000,
    .multiplier = 2.0,
    .strategy = .exponential,
    .jitter_type = .phi_weighted, // Use golden ratio for jitter
};

var attempt: u32 = 0;
while (true) {
    const delay_ms = policy.nextDelay(attempt);
    std.time.sleep(delay_ms * 1000); // Convert to nanoseconds

    // Try operation
    if (tryOperation()) break;

    attempt += 1;
}
```

### Amygdala (Emotional Salience)

**File**: `src/brain/amygdala.zig`

Detects emotionally significant events and prioritizes them.

**Key Types**:
```zig
pub const SalienceLevel = enum(u3) {
    none = 0,
    low = 1,
    medium = 2,
    high = 3,
    critical = 4,
};

pub const EventSalience = struct {
    level: SalienceLevel,
    score: f32,
    reason: []const u8,
};

pub const Amygdala = struct {
    // ...
};
```

**Key Functions**:
- `Amygdala.analyzeTask(task_id, realm, priority)` - Analyze task salience
- `Amygdala.analyzeError(err_msg)` - Analyze error salience
- `Amygdala.requiresAttention(salience)` - Check if needs attention
- `Amygdala.urgency(salience)` - Get urgency score (0-1)

**Usage Example**:
```zig
const brain = @import("brain");

// Analyze task salience
const salience = brain.amygdala.Amygdala.analyzeTask(
    "urgent-security-fix",
    "dukh",
    "critical"
);

std.log.info("Salience: {s} (score: {d:.1})", .{
    @tagName(salience.level),
    salience.score
});

if (brain.amygdala.Amygdala.requiresAttention(salience)) {
    // Handle urgent task
    handleUrgentTask();
}
```

### Prefrontal Cortex (Executive Function)

**File**: `src/brain/prefrontal_cortex.zig`

Decision making, planning, and cognitive control.

**Key Types**:
```zig
pub const DecisionContext = struct {
    task_count: usize,
    active_agents: usize,
    error_rate: f32,
    avg_latency_ms: u64,
    memory_usage_pct: f32,
};

pub const Decision = struct {
    action: Action,
    confidence: f32,
    reasoning: []const u8,
};

pub const Action = enum {
    proceed,
    throttle,
    scale_up,
    scale_down,
    pause,
    alert,
};
```

**Key Functions**:
- `PrefrontalCortex.decide(ctx)` - Make executive decision
- `PrefrontalCortex.recommend(decision)` - Get human-readable recommendation

**Usage Example**:
```zig
const brain = @import("brain");

const ctx = brain.prefrontal_cortex.DecisionContext{
    .task_count = 150,
    .active_agents = 10,
    .error_rate = 0.05,
    .avg_latency_ms = 2000,
    .memory_usage_pct = 65.0,
};

const decision = brain.prefrontal_cortex.PrefrontalCortex.decide(ctx);

std.log.info("Decision: {s} (confidence: {d:.2})", .{
    @tagName(decision.action),
    decision.confidence
});

const recommendation = brain.prefrontal_cortex.PrefrontalCortex.recommend(decision);
std.log.info("Recommendation: {s}", .{recommendation});
```

### Hippocampus (Memory Persistence)

**File**: `src/brain/persistence.zig`

Persists brain events to JSONL for replay and analysis.

**Key Types**:
```zig
pub const BrainEvent = struct {
    ts: i64,
    event: []const u8,
};

pub const BrainEventLog = struct {
    file: fs.File,
    mutex: std.Thread.Mutex,
    path: []const u8,
    // ...
};
```

**Key Functions**:
- `BrainEventLog.open(allocator, path)` - Open or create log
- `log.log(fmt, args)` - Log an event
- `log.replay(context, callback)` - Replay events
- `log.countEvents()` - Count events
- `log.rotate()` - Force log rotation

**Usage Example**:
```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

// Open event log
var log = try brain.persistence.BrainEventLog.open(
    allocator,
    ".trinity/brain/events.jsonl"
);
defer log.close();

// Log events
try log.log("task_claimed", .{});
try log.log("metric_update", .{"ppl", 2.45});

// Replay events
var captured = std.ArrayList([]const u8).init(allocator);
defer {
    for (captured.items) |e| allocator.free(e);
    captured.deinit(allocator);
}

try log.replay(&captured, struct {
    fn fn(ctx: *std.ArrayList([]const u8), ev: brain.persistence.BrainEvent) !void {
        const copy = try std.testing.allocator.dupe(u8, ev.event);
        try ctx.append(std.testing.allocator, copy);
    }
}.fn);
```

### Corpus Callosum (Telemetry)

**File**: `src/brain/telemetry.zig`

Time-series metrics aggregation.

**Key Types**:
```zig
pub const TelemetryPoint = struct {
    timestamp: i64,
    active_claims: usize,
    events_published: u64,
    events_buffered: usize,
    health_score: f32,
};

pub const BrainTelemetry = struct {
    points: std.ArrayList(TelemetryPoint),
    max_points: usize,
    mutex: std.Thread.Mutex,
};
```

**Key Functions**:
- `BrainTelemetry.init(allocator, max_points)` - Create telemetry
- `tel.record(point)` - Record telemetry point
- `tel.avgHealth(last_n)` - Get average health
- `tel.trend(last_n)` - Get trend direction
- `tel.percentile(p, last_n)` - Get percentile
- `tel.exportJson(writer)` - Export as JSON

**Usage Example**:
```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

var tel = brain.telemetry.BrainTelemetry.init(allocator, 100);
defer tel.deinit();

// Record telemetry
try tel.record(.{
    .timestamp = std.time.milliTimestamp(),
    .active_claims = 42,
    .events_published = 1000,
    .events_buffered = 10,
    .health_score = 95.0,
});

// Query metrics
const avg_health = tel.avgHealth(10);
const trend = tel.trend(50); // .improving, .stable, or .declining
const p95 = tel.percentile(95.0, 100);
```

### Microglia (Immune Surveillance)

**File**: `src/brain/microglia.zig`

The Constant Gardeners - patrol, prune, and stimulate regrowth.

**Key Types**:
```zig
pub const Microglia = struct {
    patrol_interval_ms: u64 = 30 * 60 * 1000,
    night_mode: bool = false,
    dont_eat_me: []const []const u8 = &.{ "hslm-r33", "hslm-r5", "hslm-r13" },
    // ...
};

pub const SurveillanceReport = struct {
    timestamp: i64,
    active_workers: usize,
    crashed_workers: usize,
    idle_workers: usize,
    stalled_workers: usize,
    diversity_index: f32,
    recommendation: Recommendation,
};

pub const Recommendation = enum {
    monitor,
    prune_crashed,
    prune_stalled,
    stimulate_growth,
    inject_diversity,
    enter_sleep,
};
```

**Key Functions**:
- `microglia.patrol(allocator)` - Run surveillance patrol
- `microglia.phagocytose(worker_id)` - Prune worker
- `microglia.stimulateRegrowth(template, allocator)` - Spawn new worker
- `microglia.enterSleepMode()` - Reduce pruning aggression
- `microglia.wakeUp()` - Full pruning capacity

**Usage Example**:
```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator();

var microglia = brain.microglia.Microglia{
    .patrol_interval_ms = 30 * 60 * 1000, // 30 minutes
    .night_mode = false,
    .dont_eat_me = &.{ "hslm-r33", "hslm-r5", "hslm-r13" },
};

// Run surveillance
const report = try microglia.patrol(allocator);
std.log.info("Active: {d}, Crashed: {d}", .{
    report.active_workers,
    report.crashed_workers
});

// Prune crashed worker
if (report.recommendation == .prune_crashed) {
    try microglia.phagocytose("hslm-weak-worker");
}

// Stimulate regrowth from leader
const new_worker = try microglia.stimulateRegrowth("hslm-r33", allocator);
defer allocator.free(new_worker);
std.log.info("Spawned: {s}", .{new_worker});
```

### Federation (Corpus Callosum - Distributed)

**File**: `src/brain/federation.zig`

Distributed multi-instance coordination with leader election and CRDT state sync.

**Key Types**:
```zig
pub const InstanceId = struct {
    bytes: [16]u8, // UUID v4
};

pub const FederationState = struct {
    my_id: InstanceId,
    instances: std.StringHashMap(InstanceInfo),
    election: ElectionState,
    task_counter: GCounter,
    event_counter: GCounter,
};

pub const GCounter = struct {
    counts: std.AutoHashMap(InstanceId, u64),
};

pub const ElectionState = struct {
    current_term: u64,
    voted_for: ?InstanceId,
    leader_id: ?InstanceId,
    state: enum { follower, candidate, leader },
};
```

**Key Functions**:
- `InstanceId.generate()` - Generate new instance ID
- `InstanceId.parse(str)` - Parse UUID string
- `FederationState.init(allocator, my_id)` - Initialize federation
- `federation.amILeader()` - Check if I am leader
- `federation.getLeader()` - Get current leader
- `federation.getAggregatedHealth()` - Get federation health

**Usage Example**:
```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator();

// Initialize federation
const my_id = brain.federation.InstanceId.generate();
var federation = try brain.federation.FederationState.init(allocator, my_id);
defer federation.deinit();

// Check if I'm the leader
if (federation.amILeader()) {
    std.log.info("I am the leader!", .{});
} else {
    const leader = federation.getLeader();
    std.log.info("Following leader: {any}", .{leader});
}

// Get aggregated health
const health = federation.getAggregatedHealth();
std.log.info("Federation health: {d:.1}", .{health});
```

### Cerebellum (Learning)

**File**: `src/brain/learning.zig`

Performance history tracking, pattern recognition, adaptive backoff, failure prediction.

**Key Types**:
```zig
pub const LearningSystem = struct {
    history: std.ArrayList(PerformanceRecord),
    patterns: std.ArrayList(Pattern),
    backoff_config: AdaptiveBackoffConfig,
    failure_models: std.ArrayList(FailureModel),
};

pub const PerformanceRecord = struct {
    timestamp: i64,
    operation: OperationType,
    duration_ms: u64,
    success: bool,
    metadata: Metadata,
};

pub const Pattern = struct {
    name: []const u8,
    confidence: f32,
    description: []const u8,
    recommendation: []const u8,
    pattern_type: PatternType,
};
```

**Key Functions**:
- `LearningSystem.init(allocator)` - Initialize learning system
- `learning.recordEvent(event)` - Record performance event
- `learning.learnPatterns()` - Learn patterns from history
- `learning.getBackoffDelay(attempt)` - Get adaptive backoff
- `learning.predictFailure(operation)` - Predict failure probability
- `learning.getRecommendation()` - Get actionable recommendation

**Usage Example**:
```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator();

var learning = try brain.learning.LearningSystem.init(allocator);
defer learning.deinit();

// Record events
const now = std.time.milliTimestamp();
try learning.recordEvent(.{
    .timestamp = now,
    .operation = .task_claim,
    .duration_ms = 100,
    .success = true,
    .metadata = .{
        .task_id = "task-123",
        .agent_id = "agent-001",
        .attempt = 0,
        .backoff_ms = 0,
        .error_msg = "",
        .health_score = 100.0,
    },
});

// Learn patterns
try learning.learnPatterns();

// Get recommendation
const rec = learning.getRecommendation();
std.log.info("Recommendation: {s} (priority: {d})", .{
    rec.action,
    rec.priority
});

// Predict failure
const prediction = learning.predictFailure(.task_claim);
std.log.info("Failure probability: {d:.0}%", .{prediction.probability * 100});
```

## Complete CLI Reference

The S³AI Brain provides CLI commands for all brain regions through the `tri` CLI.

### Brain Health Commands

```bash
# Show overall brain health
tri brain health

# Show specific region status
tri brain region basal-ganglia
tri brain region reticular-formation
tri brain region locus-coeruleus
tri brain region amygdala
tri brain region prefrontal-cortex

# Show all regions with activity levels
tri brain scan

# Visual ASCII brain scan (for TUI display)
tri brain scan --visual
```

### Task Operations (Basal Ganglia)

```bash
# Claim a task for an agent
tri brain claim <task_id> <agent_id>

# Refresh task heartbeat
tri brain heartbeat <task_id> <agent_id>

# Complete a task
tri brain complete <task_id> <agent_id> <duration_ms>

# Abandon a task
tri brain abandon <task_id> <agent_id>

# Show task statistics
tri brain stats
```

### Event Operations (Reticular Formation)

```bash
# Poll recent events
tri brain events --since <timestamp> --limit <count>

# Get event statistics
tri brain events --stats

# Publish custom event
tri brain publish <event_type> --task-id <id> --agent-id <id>

# Stream events in real-time
tri brain stream
```

### Telemetry and Monitoring

```bash
# Show brain telemetry
tri brain telemetry

# Export metrics in Prometheus format
tri brain metrics --format prometheus

# Export metrics in JSON format
tri brain metrics --format json

# Show health history
tri brain history --last <duration>

# Show learning patterns
tri brain learn --patterns
```

### Federation (Multi-Instance)

```bash
# Show federation status
tri federation status

# List all instances
tri federation instances

# Show leader election state
tri federation leader

# Sync state with other instances
tri federation sync

# Show federation metrics
tri federation metrics
```

### Microglia (Immune Surveillance)

```bash
# Run surveillance patrol
tri microglia patrol

# Show patrol report
tri microglia report

# Prune crashed workers
tri microglia prune --crashed

# Prune stalled workers
tri microglia prune --stalled

# Stimulate regrowth from leader
tri microglia regrow --template <name>

# Enter night mode (reduced pruning)
tri microglia night-mode on
tri microglia night-mode off

# Show don't-eat-me list
tri microglia protected
```

### Administration (Hypothalamus)

```bash
# Reset brain state
tri brain admin reset

# Run doctor scan
tri brain doctor scan

# Mark modules for regeneration
tri brain doctor mark --all

# Generate migration plan
tri brain doctor plan

# Backup brain state
tri brain backup --path <path>

# Restore brain state
tri brain restore --path <path>
```

### Visualization (Visual Cortex)

```bash
# Show ASCII brain map
tri brain map

# Show activity heatmap
tri brain heatmap

# Show sparkline trends
tri brain trends

# Show 3D visualization
tri brain visualize --3d
```

### Alerting (Brain Alerts)

```bash
# Show alert configuration
tri brain alerts config

# Show recent alerts
tri brain alerts recent

# Configure alert thresholds
tri brain alerts threshold --health <score> --buffered <count>

# Test alert system
tri brain alerts test
```

### Simulation (Synthetic Workload)

```bash
# Run simulation scenario
tri brain simulate --scenario <name>

# List available scenarios
tri brain simulate --list

# Run with custom parameters
tri brain simulate --tasks <count> --agents <count> --duration <seconds>

# Show simulation results
tri brain simulate --results
```

### Observability Export

```bash
# Export to Prometheus
tri brain export --prometheus --port <port>

# Export to OpenTelemetry
tri brain export --otel --endpoint <url>

# Export to JSON
tri brain export --json --file <path>
```

### Learning System (Cerebellum)

```bash
# Show learning statistics
tri brain learn --stats

# Show learned patterns
tri brain learn --patterns

# Show failure predictions
tri brain learn --predictions

# Reset learning history
tri brain learn --reset
```

### Async Processor

```bash
# Show async processor status
tri brain async status

# Show pending operations
tri brain async pending

# Show background telemetry
tri brain async telemetry
```

### Evolution Simulation

```bash
# Run evolution simulation
tri brain evolve --scenario <name>

# Show evolution progress
tri brain evolve --progress

# Show evolution results
tri brain evolve --results

# Compare scenarios
tri brain evolve --compare <scenarios...>
```

## CLI Examples by Use Case

### Monitoring Agent Swarm Health

```bash
# Quick health check
tri brain health

# Detailed region status
tri brain scan --visual

# Event stream
tri brain stream

# Metrics export
tri brain metrics --format prometheus
```

### Debugging Task Coordination

```bash
# Check task claims
tri brain stats

# View recent events
tri brain events --since -1h

# Check specific task
tri brain claim get <task_id>

# View event history for task
tri brain events --filter task_id:<task_id>
```

### Managing Farm Workers

```bash
# Run microglia patrol
tri microglia patrol

# Prune crashed workers
tri microglia prune --crashed

# Stimulate regrowth from leader
tri microglia regrow --template hslm-r33

# View protected workers
tri microglia protected
```

### Multi-Instance Coordination

```bash
# Check federation status
tri federation status

# View leader election
tri federation leader

# Sync state
tri federation sync

# View all instances
tri federation instances
```

### Performance Analysis

```bash
# View telemetry
tri brain telemetry

# Check trends
tri brain trends

# View learning patterns
tri brain learn --patterns

# Run simulation
tri brain simulate --scenario high-load
```

## Output Formats

The brain CLI supports multiple output formats:

```bash
# JSON output
tri brain health --format json

# Prometheus metrics
tri brain metrics --format prometheus

# Human-readable table
tri brain stats --format table

# Compact format
tri brain scan --format compact
```

## Configuration

Brain configuration is stored in `.trinity/brain/`:

```
.trinity/brain/
├── config.json           # Main configuration
├── alerts.json           # Alert thresholds
├── microglia.json        # Microglia settings
├── federation.json       # Federation config
└── state/                # Persistent state
    ├── claims.json       # Task claims
    ├── events.jsonl      # Event log
    └── telemetry.json    # Telemetry data
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
zig test src/brain/learning.zig
zig test src/brain/microglia.zig
zig test src/brain/amygdala.zig
zig test src/brain/prefrontal_cortex.zig
zig test src/brain/persistence.zig
zig test src/brain/telemetry.zig
zig test src/brain/locus_coeruleus.zig
```

## See Also

- **Architecture Overview**: `docs/BRAIN_ARCHITECTURE.md`
- **Module Details**: `docs/S3AI_BRAIN_MODULES.md`
- **Federation Protocol**: `src/brain/FEDERATION_PROTOCOL.md`
- **Source Code**: `src/brain/brain.zig`
