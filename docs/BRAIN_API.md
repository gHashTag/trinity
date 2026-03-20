# S³AI Brain API Reference

Complete API documentation for all 21 brain regions in Trinity's S³AI Brain v5.1.

## Table of Contents

- [Quick Start](#quick-start)
- [Core Regions](#core-regions)
- [Supporting Regions](#supporting-regions)
- [Advanced Regions](#advanced-regions)
- [Inter-Region Communication](#inter-region-communication)
- [Error Handling](#error-handling)
- [Thread Safety](#thread-safety)

## Quick Start

```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

// Initialize brain regions
const registry = try brain.basal_ganglia.getGlobal(allocator);
const event_bus = try brain.reticular_formation.getGlobal(allocator);

// Claim a task
const claimed = try registry.claim(allocator, "task-123", "agent-001", 300000);
if (claimed) {
    // Publish event
    try event_bus.publish(.task_claimed, .{
        .task_claimed = .{ .task_id = "task-123", .agent_id = "agent-001" }
    });

    // Work on task...

    // Complete task
    _ = registry.complete("task-123", "agent-001");
}
```

## Core Regions

### Basal Ganglia (Action Selection)

**Module**: `brain.basal_ganglia`
**File**: `src/brain/basal_ganglia.zig`
**Purpose**: Prevents duplicate task execution across agents

#### Types

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
    stats: struct {
        claim_attempts: u64,
        claim_success: u64,
        claim_conflicts: u64,
        // ...
    },
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `Registry.init(allocator)` | Create new registry | `Registry` |
| `registry.claim(allocator, task_id, agent_id, ttl_ms)` | Atomically claim task | `!bool` |
| `registry.heartbeat(task_id, agent_id)` | Refresh claim TTL | `bool` |
| `registry.complete(task_id, agent_id)` | Mark task complete | `bool` |
| `registry.abandon(task_id, agent_id)` | Release task | `bool` |
| `registry.reset()` | Clear all claims | `void` |
| `registry.getStats()` | Get performance stats | `Stats` |
| `getGlobal(allocator)` | Get/process-wide singleton | `!*Registry` |
| `resetGlobal(allocator)` | Reset global singleton | `void` |

#### Example

```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

// Get global registry
const registry = try brain.basal_ganglia.getGlobal(allocator);

// Claim task with 5-minute TTL
const claimed = try registry.claim(allocator, "task-123", "agent-001", 300000);
if (claimed) {
    // Send heartbeat every 30s while working
    while (working) {
        _ = registry.heartbeat("task-123", "agent-001");
        std.time.sleep(30 * std.time.ns_per_s);
    }

    // Mark complete
    _ = registry.complete("task-123", "agent-001");
} else {
    std.log.warn("Task already claimed", .{});
}
```

### Reticular Formation (Broadcast Alerting)

**Module**: `brain.reticular_formation`
**File**: `src/brain/reticular_formation.zig`
**Purpose**: Event bus for broadcasting agent events

#### Types

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
    task_failed: struct { task_id: []const u8, agent_id: []const u8, err_msg: []const u8 },
    task_abandoned: struct { task_id: []const u8, agent_id: []const u8, reason: []const u8 },
    agent_idle: struct { agent_id: []const u8, idle_ms: u64 },
    agent_spawned: struct { agent_id: []const u8 },
};

pub const AgentEventRecord = struct {
    event_type: AgentEventType,
    timestamp: i64,
    data: EventData,
};

pub const EventBus = struct {
    mutex: std.Thread.Mutex,
    events: std.ArrayList(StoredEvent),
    stats: struct {
        published: u64,
        polled: u64,
        trim_count: u64,
        peak_buffered: usize,
    },
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `EventBus.init(allocator)` | Create new event bus | `EventBus` |
| `event_bus.publish(event_type, data)` | Publish event | `!void` |
| `event_bus.poll(since, allocator, max_events)` | Poll events since timestamp | `![]AgentEventRecord` |
| `event_bus.getStats()` | Get statistics | `Stats` |
| `event_bus.trim(count)` | Keep only N most recent events | `void` |
| `event_bus.clear()` | Remove all events | `void` |
| `getGlobal(allocator)` | Get/process-wide singleton | `!*EventBus` |

#### Example

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
const since_timestamp = std.time.milliTimestamp() - 60000; // Last minute
const events = try event_bus.poll(since_timestamp, allocator, 100);
defer allocator.free(events);

for (events) |event| {
    std.log.info("{s}: {s}", .{@tagName(event.event_type), event.data.task_claimed.task_id});
}
```

### Locus Coeruleus (Arousal Regulation)

**Module**: `brain.locus_coeruleus`
**File**: `src/brain/locus_coeruleus.zig`
**Purpose**: Exponential backoff policy for agent retry logic

#### Types

```zig
pub const BackoffPolicy = struct {
    initial_ms: u64 = 1000,
    max_ms: u64 = 60000,
    multiplier: f32 = 2.0,
    linear_increment: u64 = 1000,
    strategy: enum { exponential, linear, constant } = .exponential,
    jitter_type: enum { none, uniform, phi_weighted } = .none,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `BackoffPolicy.init()` | Create default policy | `BackoffPolicy` |
| `policy.nextDelay(attempt)` | Get delay for attempt N | `u64` |

#### Strategies

| Strategy | Formula | Example (initial=1000, mult=2) |
|----------|---------|-------------------------------|
| `exponential` | `initial * mult^attempt` | 1000, 2000, 4000, 8000... |
| `linear` | `initial + increment * attempt` | 1000, 2000, 3000, 4000... |
| `constant` | `initial` | 1000, 1000, 1000, 1000... |

#### Jitter Types

| Type | Effect |
|------|--------|
| `none` | No jitter, exact delay |
| `uniform` | Random 1.0-2.0x multiplier |
| `phi_weighted` | Golden ratio jitter (0.618x or 1.618x) |

#### Example

```zig
const brain = @import("brain");

var policy = brain.locus_coeruleus.BackoffPolicy{
    .initial_ms = 1000,
    .max_ms = 60000,
    .multiplier = 2.0,
    .strategy = .exponential,
    .jitter_type = .phi_weighted, // Sacred jitter
};

var attempt: u32 = 0;
while (true) {
    const delay_ms = policy.nextDelay(attempt);
    std.time.sleep(delay_ms * std.time.ns_per_us);

    if (tryOperation()) break;
    attempt += 1;
}
```

### Amygdala (Emotional Salience)

**Module**: `brain.amygdala`
**File**: `src/brain/amygdala.zig`
**Purpose**: Detects emotionally significant events and prioritizes them

#### Types

```zig
pub const SalienceLevel = enum(u3) {
    none = 0,    // 0-19: Routine
    low = 1,     // 20-39: Normal
    medium = 2,  // 40-59: Above average
    high = 3,    // 60-79: Needs attention
    critical = 4 // 80-100: Immediate action
};

pub const EventSalience = struct {
    level: SalienceLevel,
    score: f32,
    reason: []const u8,
};

pub const Amygdala = struct {};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `Amygdala.analyzeTask(task_id, realm, priority)` | Analyze task salience | `EventSalience` |
| `Amygdala.analyzeError(err_msg)` | Analyze error salience | `EventSalience` |
| `Amygdala.requiresAttention(salience)` | Check if urgent | `bool` |
| `Amygdala.urgency(salience)` | Get 0-1 urgency score | `f32` |
| `SalienceLevel.fromScore(score)` | Convert score to level | `SalienceLevel` |
| `SalienceLevel.emoji()` | Get emoji for TUI | `[]const u8` |

#### Scoring Factors

**Task Analysis:**
- Realm `dukh`: +40, `razum`: +30
- Keywords: `urgent` +30, `critical` +50, `security` +40
- Priority: `high` +20, `critical` +30

**Error Analysis:**
- Base score: 20 (all errors)
- Critical patterns (`segfault`, `panic`, `security`): +30 each
- High severity (`timeout`, `connection refused`): +15 each

#### Example

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

// Check emoji for TUI
std.log.info("Status: {s}", .{salience.level.emoji()});
// Output: Status: 🔴

// Check if needs immediate attention
if (brain.amygdala.Amygdala.requiresAttention(salience)) {
    handleUrgentTask();
}

// Get urgency score (0-1)
const urgency = brain.amygdala.Amygdala.urgency(salience);
std.log.info("Urgency: {d:.2}", .{urgency});
```

### Prefrontal Cortex (Executive Function)

**Module**: `brain.prefrontal_cortex`
**File**: `src/brain/prefrontal_cortex.zig`
**Purpose**: Decision making, planning, and cognitive control

#### Types

```zig
pub const DecisionContext = struct {
    task_count: usize,
    active_agents: usize,
    error_rate: f32,
    avg_latency_ms: u64,
    memory_usage_pct: f32,
};

pub const Action = enum {
    proceed,    // Continue normal operations
    throttle,   // Reduce task acceptance
    scale_up,   // Spawn more agents
    scale_down, // Reduce agent count
    pause,      // Stop accepting tasks
    alert,      // Immediate intervention
};

pub const Decision = struct {
    action: Action,
    confidence: f32,
    reasoning: []const u8,
};

pub const PrefrontalCortex = struct {};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `PrefrontalCortex.decide(ctx)` | Make executive decision | `Decision` |
| `PrefrontalCortex.recommend(decision)` | Get human-readable recommendation | `[]const u8` |

#### Decision Thresholds

| Condition | Action | Priority |
|-----------|--------|----------|
| `memory > 90%` | alert | Highest |
| `error_rate > 0.5` | pause | Very high |
| `error_rate > 0.2` | throttle | High |
| `queue/agent > 10` | scale_up | Medium |
| `latency > 5000ms` | throttle | Medium |
| `memory > 75%` | throttle | Medium |
| `tasks < agents & queue < 0.5` | scale_down | Low |
| All healthy | proceed | Default |

#### Example

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

// Act on decision
switch (decision.action) {
    .proceed => std.log.info("All systems nominal"),
    .throttle => reduceTaskRate(),
    .scale_up => spawnMoreAgents(),
    .scale_down => terminateIdleAgents(),
    .pause => pauseTaskAcceptance(),
    .alert => sendCriticalAlert(),
}
```

## Supporting Regions

### Hippocampus (Memory Persistence)

**Module**: `brain.persistence`
**File**: `src/brain/persistence.zig`
**Purpose**: JSONL event logging for replay and analysis

#### Types

```zig
pub const BrainEvent = struct {
    ts: i64,
    event: []const u8,
};

pub const BrainEventLog = struct {
    file: fs.File,
    mutex: std.Thread.Mutex,
    path: []const u8,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `BrainEventLog.open(allocator, path)` | Open/create log | `!BrainEventLog` |
| `log.log(fmt, args)` | Log event | `!void` |
| `log.replay(context, callback)` | Replay events | `!void` |
| `log.countEvents()` | Count events | `!usize` |
| `log.rotate()` | Force log rotation | `!void` |
| `log.close()` | Close log | `void` |

### Corpus Callosum (Telemetry)

**Module**: `brain.telemetry`
**File**: `src/brain/telemetry.zig`
**Purpose**: Time-series metrics aggregation

#### Types

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

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `BrainTelemetry.init(allocator, max_points)` | Create telemetry | `BrainTelemetry` |
| `tel.record(point)` | Record telemetry point | `!void` |
| `tel.avgHealth(last_n)` | Average health over N points | `f32` |
| `tel.trend(last_n)` | Get trend direction | `Trend` |
| `tel.percentile(p, last_n)` | P-th percentile | `f32` |
| `tel.exportJson(writer)` | Export as JSON | `!void` |

### Microglia (Immune Surveillance)

**Module**: `brain.microglia`
**File**: `src/brain/microglia.zig`
**Purpose**: Patrol, prune, and stimulate regrowth

#### Types

```zig
pub const Microglia = struct {
    patrol_interval_ms: u64 = 30 * 60 * 1000,
    night_mode: bool = false,
    dont_eat_me: []const []const u8,
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

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `microglia.patrol(allocator)` | Run surveillance | `!SurveillanceReport` |
| `microglia.phagocytose(worker_id)` | Prune worker | `!void` |
| `microglia.stimulateRegrowth(template, allocator)` | Spawn new worker | `![]const u8` |
| `microglia.enterSleepMode()` | Reduce pruning | `void` |
| `microglia.wakeUp()` | Full pruning | `void` |

## Advanced Regions

### Federation (Corpus Callosum - Distributed)

**Module**: `brain.federation`
**File**: `src/brain/federation.zig`
**Purpose**: Multi-instance coordination with leader election

#### Types

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

pub const ElectionState = struct {
    current_term: u64,
    voted_for: ?InstanceId,
    leader_id: ?InstanceId,
    state: enum { follower, candidate, leader },
};

pub const GCounter = struct {
    counts: std.AutoHashMap(InstanceId, u64),
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `InstanceId.generate()` | Generate new UUID | `InstanceId` |
| `InstanceId.parse(str)` | Parse UUID string | `!InstanceId` |
| `FederationState.init(allocator, my_id)` | Initialize | `!FederationState` |
| `federation.amILeader()` | Check if leader | `bool` |
| `federation.getLeader()` | Get current leader | `?InstanceId` |
| `federation.getAggregatedHealth()` | Get federation health | `f32` |

### Cerebellum (Learning)

**Module**: `brain.learning`
**File**: `src/brain/learning.zig`
**Purpose**: Performance history tracking and adaptive behavior

#### Types

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
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `LearningSystem.init(allocator)` | Initialize | `!LearningSystem` |
| `learning.recordEvent(event)` | Record event | `!void` |
| `learning.learnPatterns()` | Learn patterns | `!void` |
| `learning.getBackoffDelay(attempt)` | Get adaptive backoff | `u64` |
| `learning.predictFailure(operation)` | Predict probability | `Prediction` |
| `learning.getRecommendation()` | Get action | `Recommendation` |

## Inter-Region Communication

### Communication Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                        S³AI BRAIN COMMUNICATION                              │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────┐     Event Bus     ┌───────────────┐              │
│  │ Agent A       │ ───────────────────▶ │ Reticular     │              │
│  │ (Basal        │                   │ Formation     │              │
│  │  Ganglia)     │◀───────────────────│ (Broadcast)    │              │
│  └───────────────┘                   └───────────────┘              │
│                                                 │                      │
│                                      publish/poll     │               │
│                                                 │                      │
│  ┌───────────────┐                        │        ┌───────────────┐  │
│  │ Agent B       │                        │        │ Agent C       │  │
│  │ (Other        │                        │        │ (Amygdala/    │  │
│  │  Regions)     │                        │        │  Prefrontal)   │  │
│  └───────────────┘                        │        └───────────────┘  │
│                                                 │                      │
│                                                 ▼                      │
│                                      ┌──────────────────────────┐       │
│                                      │ Global Task Registry   │       │
│                                      │ (Basal Ganglia)      │       │
│                                      └──────────────────────────┘       │
│                                                                         │
│  ══════════════════════════════════════════════════════════════════        │
│                                                                         │
│  FEDERATION (Multi-Instance)                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐     │
│  │ Instance 1             Instance 2              Instance 3        │     │
│  │ ┌───────────┐          ┌───────────┐          ┌───────────┐      │     │
│  │ │ Brain    │  ◄────► │ Brain    │  ◄────► │ Brain    │      │     │
│  │ │ Modules  │  CRDT   │ Modules  │  CRDT   │ Modules  │      │     │
│  │ └───────────┘  Sync   └───────────┘  Sync   └───────────┘      │     │
│  │      │                                       │                │      │
│  │      └─────────────────► Leader Election ◄─────────┘      │     │
│  └─────────────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### Event Types

| Event Type | Data Fields | When Published |
|------------|-------------|----------------|
| `task_claimed` | `task_id`, `agent_id` | Agent claims task |
| `task_completed` | `task_id`, `agent_id`, `duration_ms` | Task finishes |
| `task_failed` | `task_id`, `agent_id`, `err_msg` | Task errors |
| `task_abandoned` | `task_id`, `agent_id`, `reason` | Agent gives up |
| `agent_idle` | `agent_id`, `idle_ms` | Agent has no work |
| `agent_spawned` | `agent_id` | New agent created |

### Priority Signaling

The Amygdala provides emotional salience that affects task prioritization:

```zig
const salience = brain.amygdala.Amygdala.analyzeTask(
    "urgent-security-fix",
    "dukh",
    "critical"
);

if (brain.amygdala.Amygdala.requiresAttention(salience)) {
    // High/critical salience bypasses normal queue
    handleImmediately();
}
```

## Error Handling

All brain regions use Zig's error union for error handling:

```zig
// Common errors
error.OutOfMemory     // Allocation failed
error.TaskClaimed     // Task already claimed
error.AgentMismatch   // Wrong agent for task
error.InvalidState    // Operation not allowed in current state

// Example: handling errors
const claimed = registry.claim(allocator, task_id, agent_id, ttl_ms) catch |err| {
    std.log.err("Failed to claim task: {}", .{err});
    return err;
};
```

## Thread Safety

Most brain regions use mutexes for thread-safe operations:

| Region | Thread Safety | Notes |
|--------|--------------|-------|
| Basal Ganglia | Mutex protected | All operations thread-safe |
| Reticular Formation | Mutex protected | Publish/poll are atomic |
| Locus Coeruleus | Stateless | Fully thread-safe |
| Amygdala | Stateless | Fully thread-safe |
| Prefrontal Cortex | Stateless | Fully thread-safe |
| Telemetry | Mutex protected | Record/query are atomic |
| Federation | Mutex protected | State changes are atomic |

## Sacred Formula Integration

The brain uses the sacred formula φ² + 1/φ² = 3 = TRINITY:

```zig
// Golden ratio jitter in Locus Coeruleus
const phi: f32 = 1.61803398875;
const phi_inverse: f32 = 0.61803398875;

// Jitter uses golden ratio for "sacred" timing
const factor: f32 = if (seed % 2 == 0) phi_inverse else phi;
```

## Version History

- **v5.1** (igla-ready): 22 regions, full federation support
- **v5.0**: Added async processor, learning system
- **v4.4**: Initial 10-region architecture

## See Also

- **Architecture Overview**: `docs/BRAIN_ARCHITECTURE.md`
- **Module Details**: `docs/S3AI_BRAIN_MODULES.md`
- **Federation Protocol**: `src/brain/FEDERATION_PROTOCOL.md`
- **Source Code**: `src/brain/brain.zig`
