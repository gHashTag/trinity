# S³AI Brain API Reference

Complete API documentation for all 23 brain regions in Trinity's S³AI Brain v5.1.

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

#### Performance Characteristics

- **Throughput**: 762 OP/s baseline, 33.3 kOP/s optimized
- **P99 Latency**: < 1ms target
- **Memory**: ~128 bytes per claim
- **Concurrency**: Thread-safe with RwLock

#### SLA Targets

| Metric | Target | Status |
|--------|--------|--------|
| P99 Latency | < 1ms | PASS |
| Throughput | > 10k OP/s | AT_LIMIT |
| Error Rate | < 1% | PASS |

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

#### Performance Characteristics

- **Throughput**: 1.58 kOP/s baseline, 17.8 kOP/s optimized
- **P99 Latency**: < 500us target
- **Buffer Capacity**: 10,000 events
- **Concurrency**: Lock-free publish

#### SLA Targets

| Metric | Target | Status |
|--------|--------|--------|
| P99 Latency | < 500us | AT_LIMIT |
| Throughput | > 100k OP/s | FAIL |
| Error Rate | < 0.1% | PASS |

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

#### Example

```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

// Open event log
var log = try brain.persistence.BrainEventLog.open(
    allocator,
    "/path/to/brain_events.jsonl"
);
defer log.close();

// Log events
try log.log("task_claimed", .{ .task_id = "task-123", .agent_id = "agent-001" });
try log.log("task_completed", .{ .task_id = "task-123", .duration_ms = 5000 });

// Count events
const count = try log.countEvents();
std.log.info("Total events: {d}", .{count});

// Replay events
try log.replay(null, struct {
    fn callback(ctx: ?*anyopaque, event: brain.persistence.BrainEvent) !void {
        _ = ctx;
        std.log.info("[{d}] {s}", .{ event.ts, event.event });
    }
}.callback);
```

#### Performance Characteristics

- **Append Latency**: IO-bound, ~50ms P99 with fsync
- **Throughput**: ~1k events/sec (disk limited)
- **File Size**: ~1MB per 10k events
- **Pattern**: Sequential writes, random reads

#### SLA Targets

| Metric | Target | Status |
|--------|--------|--------|
| P99 Latency | < 50ms | PASS |
| Throughput | > 1k events/sec | PASS |
| Error Rate | < 1% | PASS |

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

#### Example

```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

// Initialize telemetry
var tel = try brain.telemetry.BrainTelemetry.init(allocator, 1000);
defer tel.deinit();

// Record telemetry point
const point = brain.telemetry.TelemetryPoint{
    .timestamp = std.time.milliTimestamp(),
    .active_claims = 42,
    .events_published = 1567,
    .events_buffered = 89,
    .health_score = 95.5,
};
try tel.record(point);

// Get average health over last 100 points
const avg_health = tel.avgHealth(100);
std.log.info("Avg health (last 100): {d:.1}", .{avg_health});

// Get trend
const trend = tel.trend(100);
std.log.info("Trend: {s}", .{@tagName(trend)});

// Export as JSON
var file = try std.fs.cwd().createFile("telemetry.json", .{});
defer file.close();
try tel.exportJson(file.writer());
```

### Thalamus Logs (Sensory Relay)

**Module**: `brain.thalamus_logs`
**File**: `src/brain/thalamus_logs.zig`
**Purpose**: Sensory relay station - relays Queen (18 sensors) to cortex (5 modules) with circular buffer logging

**Biological Role**: The thalamus is the brain's sensory gateway, relaying and filtering sensory information from the body to the cerebral cortex. It regulates consciousness, sleep, and alertness.

#### Types

```zig
pub const SensorId = enum(u8) {
    FarmBestPpl = 7,      // f32 perplexity -> IPS -> GF16 encode
    ArenaBattles = 8,     // i8 win/loss -> IPS -> TF3 encode
    OuroborosScore = 9,   // f32 -> Weber -> log-quantize
    TestsRate = 2,        // f32 pass % -> OFC -> value judgment
    DiskFree = 10,        // u64 bytes -> Fusiform -> GF16 compact
    ArenaStale = 14,      // u32 hours -> Angular -> verbalize
};

pub const SensoryKind = enum(u8) {
    magnitude = 0,   // Encode with GF16
    ternary = 1,     // Encode with TF3-9
    valence = 2,     // Use OFC for value judgment
    verbal = 3,      // Use Angular for introspection
};

pub const SensorInput = struct {
    id: SensorId,
    raw_f32: ?f32 = null,
    raw_i8: ?i8 = null,
    raw_u32: ?u32 = null,
    raw_u64: ?u64 = null,
    magnitude_gf16: ?GoldenFloat16 = null,
    ternary_tf3: ?TernaryFloat9 = null,
    valence_valence: ?Valence = null,
    verbal_msg: ?VerbalMessage = null,
};

pub const SensoryEvent = struct {
    timestamp_ns: u64,
    sensor: SensorId,
    input: SensorInput,
};

pub const ThalamusLogs = struct {
    buf: [256]SensoryEvent,
    head: usize = 0,
    len: usize = 0,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `ThalamusLogs.init(buf_storage)` | Initialize with buffer storage | `ThalamusLogs` |
| `thalamus.logEvent(event)` | Log sensory event to circular buffer | `void` |
| `thalamus.iterator()` | Get iterator over events | `Iterator` |
| `thalamus.processSensor(sensor_data)` | Process sensor through HSLM module | `!void` |
| `Iterator.next()` | Get next event from iterator | `?*const SensoryEvent` |

#### Sensor Processing Pipeline

| Sensor ID | Input | HSLM Module | Output |
|-----------|-------|-------------|--------|
| `FarmBestPpl` | f32 PPL | IPS GF16 encode | GoldenFloat16 |
| `ArenaBattles` | i8 win/loss | IPS TF3 encode | TernaryFloat9 |
| `OuroborosScore` | f32 score | Weber log-quantize | GF16 compact |
| `TestsRate` | f32 pass % | OFC value judgment | Valence |
| `DiskFree` | u64 bytes | Fusiform GF16 | GF16 compact |
| `ArenaStale` | u32 hours | Angular verbalize | VerbalMessage |

#### Performance Characteristics

- **Buffer Size**: 256 events (fixed, no allocation)
- **Operation**: Lock-free circular buffer
- **Latency**: < 1us per event (in-memory)
- **Throughput**: > 1M events/sec

#### Example

```zig
const brain = @import("brain");

// Initialize thalamus with buffer storage
var buf_storage: [256]brain.thalamus_logs.SensoryEvent = undefined;
const thalamus = brain.thalamus_logs.ThalamusLogs.init(&buf_storage);

// Process farm PPL sensor
const sensor_data = brain.thalamus_logs.SensorInput{
    .id = .FarmBestPpl,
    .raw_f32 = 4.6,
};
try thalamus.processSensor(sensor_data);

// Iterate logged events
var iter = thalamus.iterator();
while (iter.next()) |event| {
    std.log.info("Sensor: {s}, Value: {d:.1}", .{
        @tagName(event.sensor),
        event.input.raw_f32.?,
    });
}
```

### Intraparietal Sulcus (Numerical Processing)

**Module**: `brain.intraparietal_sulcus`
**File**: `src/brain/intraparietal_sulcus.zig`
**Purpose**: Numerical layer - f16/GF16/TF3 format conversion, phi-weighted quantization

**Biological Role**: The intraparietal sulcus is involved in numerical processing, mathematical cognition, and spatial representation. It integrates the zig-hslm library for HSLM numerical operations.

#### Types

```zig
// Re-exported from hslm module
pub const GF16 = hslm.GF16;           // Golden Float16
pub const TF3 = hslm.TF3;             // Ternary Float3 (8x i2)
pub const PHI = hslm.PHI;             // 1.618033988749895
pub const PHI_INV = hslm.PHI_INV;     // 0.6180339887498949
pub const HslmF16 = f16;              // HSLM f16 type

pub const NumericalMetrics = struct {
    quantization_error_max: f32,
    quantization_error_avg: f32,
    overflow_count: u32,
    nan_count: u32,
    inf_count: u32,
    subnormal_count: u32,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `hslmF16ToF32(v)` | Safe f16 to f32 conversion | `f32` |
| `f32ToHslmF16(v)` | f32 to hslm f16 | `HslmF16` |
| `hslmF16BatchToF32(N, src)` | Batch f16->f32 conversion | `[N]f32` |
| `f32BatchToF16(N, src)` | Batch f32->f16 conversion | `[N]f16` |
| `phiQuantize(v)` | φ-weighted quantization | `f16` |
| `phiDequantize(v)` | φ-weighted dequantization | `f32` |
| `f32ToGF16(v)` | Convert f32 to GF16 | `GF16` |
| `gf16ToF32(gf)` | Convert GF16 to f32 | `f32` |
| `i2ToTF3(N, src)` | Create TF3 from i2 array | `TF3` |
| `tf3ToI2(tf3, N)` | Convert TF3 to i2 array | `[N]i2` |
| `vectorFloatCast(T, src)` | SIMD-safe float cast | `T` |

#### Number Formats

| Format | Bits | Range | Precision | Use Case |
|--------|------|-------|-----------|----------|
| `f32` | 32 | ±3.4E38 | 7 digits | General computation |
| `HslmF16` | 16 | ±65504 | 3-4 digits | Neural network weights |
| `GF16` | 16 | Optimized for φ | φ-enhanced | Sacred number encoding |
| `TF3` | 16 | {-1,0,1} x 8 | Ternary | Ternary neural networks |

#### Performance Characteristics

- **f16 Conversion**: < 100ns per value
- **GF16 Encoding**: φ-optimized for minimal error
- **TF3 Encoding**: 8 ternary values in 16 bits
- **Batch Conversion**: SIMD-optimized

#### Example

```zig
const brain = @import("brain");

// f32 to GF16 with golden ratio optimization
const phi: f32 = 1.618033988749895;
const gf16 = brain.intraparietal_sulcus.f32ToGF16(phi);
const recovered = brain.intraparietal_sulcus.gf16ToF32(gf16);
std.log.info("φ encoded: {d:.5}, recovered: {d:.5}", .{ phi, recovered });

// φ-weighted quantization
const quantized = brain.intraparietal_sulcus.phiQuantize(2.71828);
const dequantized = brain.intraparietal_sulcus.phiDequantize(quantized);

// TF3 ternary encoding
const ternary_data = [_]i2{ -1, 0, 1, -1, 0, 1, 0, 0 };
const tf3 = brain.intraparietal_sulcus.i2ToTF3(8, ternary_data);
const decoded = brain.intraparietal_sulcus.tf3ToI2(tf3, 8);

// Batch conversion (SIMD-safe)
const f32_array = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
const f16_array = brain.intraparietal_sulcus.f32BatchToF16(4, f32_array);
const f32_back = brain.intraparietal_sulcus.hslmF16BatchToF32(4, f16_array);
```

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

#### Example

```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

var microglia = brain.microglia.Microglia{
    .patrol_interval_ms = 30 * 60 * 1000,
    .night_mode = false,
    .dont_eat_me = &[_][]const u8{"worker-critical-001"},
};

// Run surveillance patrol
const report = try microglia.patrol(allocator);
std.log.info("Active: {d}, Crashed: {d}, Idle: {d}", .{
    report.active_workers,
    report.crashed_workers,
    report.idle_workers,
});

// Act on recommendation
switch (report.recommendation) {
    .prune_crashed => {
        for (report.crashed_workers) |worker| {
            try microglia.phagocytose(worker.id);
        }
    },
    .stimulate_growth => {
        const new_worker = try microglia.stimulateRegrowth("worker-template", allocator);
        std.log.info("Spawned: {s}", .{new_worker});
    },
    .enter_sleep => microglia.enterSleepMode(),
    else => {},
}
```

#### Performance Characteristics

- **Patrol Interval**: 30 minutes default
- **Night Mode**: Reduced pruning during off-hours
- **Patrol Duration**: < 5 seconds for 100 workers
- **Pruning Overhead**: ~100ms per worker

#### Recommendations

| Condition | Action | Priority |
|-----------|--------|----------|
| Crashed > 10% | prune_crashed | High |
| Diversity < 0.5 | inject_diversity | Medium |
| Idle > 50% | scale_down | Low |
| Queue > 100 | stimulate_growth | Medium |

## Advanced Regions

### State Recovery (Hippocampus - Long-term Memory)

**Module**: `brain.state_recovery`
**File**: `src/brain/state_recovery.zig`
**Purpose**: Hippocampus (Long-term Memory Consolidation) - State persistence, versioning, and crash recovery

#### Types

```zig
pub const StateManager = struct {
    allocator: mem.Allocator,
    state_path: []const u8,
    mutex: std.Thread.Mutex,
    current_version: u32,
    state: BrainState,
};

pub const BrainState = struct {
    version: u32,
    timestamp: i64,
    claims: []TaskClaimState,
    metrics: MetricsState,
    config: ConfigState,
};

pub const LoadedState = struct {
    state: BrainState,
    migrated: bool,
    backup_created: bool,
};

pub const TaskClaimState = struct {
    task_id: []const u8,
    agent_id: []const u8,
    claimed_at: i64,
    ttl_ms: u64,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `StateManager.init(allocator, state_path)` | Create state manager | `!StateManager` |
| `manager.save()` | Save current state to disk | `!void` |
| `manager.load()` | Load state from disk | `!LoadedState` |
| `manager.restore(loaded_state)` | Restore brain to saved state | `!void` |
| `manager.autoRecover()` | Auto-recover from crash | `!bool` |
| `manager.createBackup()` | Create state backup | `!void` |
| `manager.restoreBackup(backup_id)` | Restore from backup | `!void` |
| `manager.migrate(from_version)` | Migrate state to current version | `!void` |
| `manager.getCurrentVersion()` | Get state version | `u32` |
| `manager.getStateSize()` | Get state size in bytes | `!usize` |

#### Example

```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

// Initialize state manager
const manager = try brain.state_recovery.StateManager.init(
    allocator,
    "/path/to/brain_state.json"
);

// Auto-recover from crash (if any)
const recovered = try manager.autoRecover();
if (recovered) {
    std.log.info("Recovered from crash", .{});
}

// Save state periodically
try manager.save();

// Load and restore
const loaded = try manager.load();
if (loaded.migrated) {
    std.log.info("State migrated from older version", .{});
}
try manager.restore(loaded.state);
```

#### Performance Characteristics

- **Save Latency**: < 100ms for typical state
- **Load Latency**: < 50ms for typical state
- **State Size**: ~1KB per active claim
- **Auto-recovery**: < 200ms

#### Recovery Guarantees

| Scenario | Recovery Time | Data Loss |
|----------|--------------|-----------|
| Clean shutdown | Instant | None |
| Crash (auto-recover) | < 200ms | Since last save |
| Corrupted state | Manual restore | To backup |
| Version migration | Variable | None |

### Hypothalamus (Homeostatic Regulation)

**Module**: `brain.admin`
**File**: `src/brain/admin.zig`
**Purpose**: Hypothalamus (Homeostatic Regulation) - Administrative commands and system health maintenance

#### Types

```zig
pub const AdminManager = struct {
    allocator: mem.Allocator,
    state_manager: *state_recovery.StateManager,
    registry: *basal_ganglia.Registry,
    event_bus: *reticular_formation.EventBus,
};

pub const DiagnosticReport = struct {
    timestamp: i64,
    overall_health: f32,
    active_claims: usize,
    buffered_events: usize,
    memory_usage: usize,
    issues: []Issue,
};

pub const Issue = struct {
    severity: enum { warning, error, critical },
    region: []const u8,
    message: []const u8,
};

pub const PruneStats = struct {
    claims_removed: usize,
    events_trimmed: usize,
    memory_freed: usize,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `AdminManager.init(allocator, state_mgr, registry, event_bus)` | Create admin manager | `AdminManager` |
| `admin.runCommand(cmd, allocator)` | Execute admin command | `![]const u8` |
| `admin.reset(confirm)` | Reset all brain state | `!void` |
| `admin.doctor()` | Run diagnostic | `!DiagnosticReport` |
| `admin.prune(before_timestamp)` | Prune old data | `!PruneStats` |
| `admin.migrate(target_version)` | Migrate state version | `!void` |
| `admin.backup(label)` | Create state backup | `![]const u8` |
| `admin.restore(backup_id, confirm)` | Restore from backup | `!void` |
| `admin.stats()` | Get system statistics | `!SystemStats` |

#### Commands

| Command | Description | Requires Confirmation |
|---------|-------------|----------------------|
| `reset` | Reset all brain state | Yes |
| `doctor` | Run health diagnostics | No |
| `prune` | Remove old claims/events | No |
| `migrate` | Migrate to new state version | Yes |
| `backup` | Create state backup | No |
| `restore` | Restore from backup | Yes |

#### Example

```zig
const brain = @import("brain");

// Initialize admin manager
const admin = try brain.admin.AdminManager.init(
    allocator,
    &state_mgr,
    &registry,
    &event_bus
);

// Run diagnostics
const report = try admin.doctor();
std.log.info("Health: {d:.1}%", .{report.overall_health});

// Prune old data
const stats = try admin.prune(std.time.milliTimestamp() - 86400000);
std.log.info("Pruned {d} claims, {d} events", .{
    stats.claims_removed,
    stats.events_trimmed
});

// Create backup
const backup_id = try admin.backup("before-experiment");
std.log.info("Backup: {s}", .{backup_id});
```

#### Performance Characteristics

- **Doctor Scan**: < 1 second for full diagnostic
- **Prune Operation**: ~100ms per 1000 entries
- **Backup Creation**: < 500ms for typical state
- **Migration**: Depends on version delta

### Health History (Hippocampal Memory Consolidation)

**Module**: `brain.health_history`
**File**: `src/brain/health_history.zig`
**Purpose**: Hippocampal Memory Consolidation - Records brain health snapshots over time for trend analysis

#### Types

```zig
pub const HealthSnapshot = struct {
    timestamp: i64,
    overall_health: f32,
    region_health: std.StringHashMap(f32),
    active_claims: usize,
    buffered_events: usize,
    memory_usage: usize,
};

pub const HealthTrend = enum {
    improving,    // Health increasing
    stable,       // No significant change
    declining,    // Health decreasing
    volatile,     // Large fluctuations
};

pub const BrainHealthHistory = struct {
    snapshots: std.ArrayList(HealthSnapshot),
    max_snapshots: usize = 1000,
    mutex: std.Thread.Mutex,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `BrainHealthHistory.init(allocator, max_snapshots)` | Create history | `BrainHealthHistory` |
| `history.recordSnapshot(snapshot)` | Record health snapshot | `!void` |
| `history.getLatest()` | Get most recent snapshot | `?HealthSnapshot` |
| `history.getTrend(duration_ms)` | Analyze health trend | `HealthTrend` |
| `history.getAverageHealth(duration_ms)` | Average health over period | `f32` |
| `history.getPercentile(p, duration_ms)` | P-th percentile health | `f32` |
| `history.findAnomalies(threshold)` | Find anomalous snapshots | `![]HealthSnapshot` |
| `history.exportJson(writer)` | Export as JSON | `!void` |
| `history.trim(keep_count)` | Keep only N recent snapshots | `void` |
| `history.clear()` | Remove all snapshots | `void` |

#### Example

```zig
const brain = @import("brain");

// Initialize health history
const history = brain.health_history.BrainHealthHistory.init(
    allocator,
    1000  // Keep last 1000 snapshots
);

// Record current state
const snapshot = brain.health_history.HealthSnapshot{
    .timestamp = std.time.milliTimestamp(),
    .overall_health = 87.5,
    .region_health = region_health_map,
    .active_claims = 42,
    .buffered_events = 156,
    .memory_usage = 1024 * 1024,
};
try history.recordSnapshot(snapshot);

// Analyze trend over last hour
const trend = history.getTrend(3600 * 1000);
if (trend == .declining) {
    std.log.warn("Brain health declining!", .{});
}

// Find anomalies (snapshots with health < 50)
const anomalies = try history.findAnomalies(50.0);
defer allocator.free(anomalies);
for (anomalies) |anomaly| {
    std.log.warn("Anomaly at {d}: health={d:.1}", .{
        anomaly.timestamp,
        anomaly.overall_health
    });
}
```

#### Performance Characteristics

- **Record Snapshot**: < 1ms
- **Trend Analysis**: O(n) over duration
- **Percentile**: O(n log n) with sorting
- **Anomaly Detection**: O(n) linear scan
- **Max Snapshots**: 1000 (configurable)

### Metrics Dashboard (Command Center)

**Module**: `brain.metrics_dashboard`
**File**: `src/brain/metrics_dashboard.zig`
**Purpose**: Command center view of brain health - Aggregates metrics from all brain regions

#### Types

```zig
pub const RegionMetrics = struct {
    region_name: []const u8,
    health: f32,
    active_count: usize,
    error_count: usize,
    avg_latency_ms: u64,
    last_activity: i64,
};

pub const AggregateMetrics = struct {
    timestamp: i64,
    overall_health: f32,
    total_regions: usize,
    healthy_regions: usize,
    degraded_regions: usize,
    failed_regions: usize,
    total_operations: u64,
    total_errors: u64,
    avg_latency_ms: u64,
};

pub const RegionStatus = enum {
    healthy,     // Health >= 80
    degraded,    // 50 <= Health < 80
    failed,      // Health < 50
    unknown,     // No data
};

pub const MetricsDashboard = struct {
    regions: std.StringHashMap(RegionMetrics),
    aggregates: std.ArrayList(AggregateMetrics),
    max_aggregates: usize = 1000,
    mutex: std.Thread.Mutex,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `MetricsDashboard.init(allocator, max_aggregates)` | Create dashboard | `MetricsDashboard` |
| `dashboard.recordRegion(name, metrics)` | Record region metrics | `!void` |
| `dashboard.collectAggregate()` | Collect aggregate metrics | `!AggregateMetrics` |
| `dashboard.getRegionStatus(name)` | Get region status | `RegionStatus` |
| `dashboard.getOverallHealth()` | Get overall health score | `f32` |
| `dashboard.getReport()` | Generate full report | `![]const u8` |
| `dashboard.getCompactReport()` | Generate one-line report | `![]const u8` |
| `dashboard.exportJson(writer)` | Export as JSON | `!void` |
| `dashboard.resetRegion(name)` | Reset region metrics | `void` |
| `dashboard.getHistory(duration_ms)` | Get aggregate history | `![]AggregateMetrics` |

#### Example

```zig
const brain = @import("brain");

// Initialize dashboard
const dashboard = brain.metrics_dashboard.MetricsDashboard.init(
    allocator,
    1000
);

// Record metrics for a region
const region_metrics = brain.metrics_dashboard.RegionMetrics{
    .region_name = "Basal Ganglia",
    .health = 95.0,
    .active_count = 42,
    .error_count = 0,
    .avg_latency_ms = 12,
    .last_activity = std.time.milliTimestamp(),
};
try dashboard.recordRegion("basal_ganglia", region_metrics);

// Collect and report
const aggregate = try dashboard.collectAggregate();
std.log.info("Overall health: {d:.1}%", .{aggregate.overall_health});

// Get human-readable report
const report = try dashboard.getCompactReport();
std.log.info("{s}", .{report});
// Output: "Health: 87% | 14/16 regions | 0 errors"
```

#### Performance Characteristics

- **Record Region**: < 1ms
- **Collect Aggregate**: O(n) over regions
- **Report Generation**: < 10ms
- **Max Aggregates**: 1000 (configurable)
- **Region Update**: Thread-safe

### Brain Alerts (Critical Health Notification)

**Module**: `brain.alerts`
**File**: `src/brain/alerts.zig`
**Purpose**: Critical health state notification - Sends alerts when brain regions fail or health degrades

#### Types

```zig
pub const Alert = struct {
    id: []const u8,
    timestamp: i64,
    severity: enum { info, warning, error, critical },
    region: []const u8,
    message: []const u8,
    resolved: bool,
    resolved_at: ?i64,
};

pub const AlertManager = struct {
    alerts: std.ArrayList(Alert),
    suppression: SuppressionState,
    telegram_config: ?TelegramConfig,
    mutex: std.Thread.Mutex,
};

pub const AlertHistory = struct {
    alerts: []Alert,
    total_count: usize,
    by_severity: std.EnumField(enum { info, warning, error, critical }, usize),
};

pub const SuppressionState = struct {
    suppressed_patterns: std.StringHashMap(i64),  // pattern -> expiry
    cooldown_ms: u64 = 300000,  // 5 minutes default
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `AlertManager.init(allocator, telegram_config)` | Create alert manager | `AlertManager` |
| `manager.emit(severity, region, message)` | Emit alert | `!void` |
| `manager.resolve(alert_id)` | Mark alert as resolved | `!bool` |
| `manager.getActive()` | Get active (unresolved) alerts | `![]Alert` |
| `manager.getHistory(duration_ms)` | Get alert history | `!AlertHistory` |
| `manager.suppress(pattern, duration_ms)` | Suppress alert pattern | `!void` |
| `manager.isSuppressed(pattern)` | Check if pattern suppressed | `bool` |
| `manager.clearSuppression()` | Clear all suppressions | `void` |
| `manager.sendTelegram(alert)` | Send via Telegram | `!bool` |
| `manager.getReport()` | Generate alert report | `![]const u8` |

#### Alert Thresholds

| Severity | Health | Condition |
|----------|--------|-----------|
| `info` | - | Normal operations |
| `warning` | < 80 | Region degraded |
| `error` | < 50 | Region failed |
| `critical` | < 25 | Multiple regions failed |

#### Example

```zig
const brain = @import("brain");

// Initialize with Telegram (optional)
const telegram_config = brain.alerts.TelegramConfig{
    .bot_token = "your_bot_token",
    .chat_id = "your_chat_id",
};
const manager = try brain.alerts.AlertManager.init(
    allocator,
    &telegram_config
);

// Emit critical alert
try manager.emit(.critical, "Basal Ganglia", "Task claim registry full");

// Suppress noisy pattern for 10 minutes
try manager.suppress("high_latency", 10 * 60 * 1000);

// Get active alerts
const active = try manager.getActive();
defer allocator.free(active);
for (active) |alert| {
    std.log.warn("{s}: {s}", .{@tagName(alert.severity), alert.message});
}

// Resolve an alert
_ = try manager.resolve(alert.id);
```

### Simulation Environment (Synthetic Workload Generator)

**Module**: `brain.simulation`
**File**: `src/brain/simulation.zig`
**Purpose**: Simulation Environment - Generates synthetic workloads for testing brain resilience

#### Types

```zig
pub const SimulationConfig = struct {
    duration_ms: u64 = 60000,  // 1 minute default
    agent_count: usize = 10,
    task_rate: f64 = 10.0,  // tasks per second
    failure_rate: f32 = 0.05,  // 5% failure rate
    network_partition: bool = false,
    high_load: bool = false,
};

pub const SimulationResult = struct {
    config: SimulationConfig,
    start_time: i64,
    end_time: i64,
    total_tasks: usize,
    completed_tasks: usize,
    failed_tasks: usize,
    avg_latency_ms: u64,
    p99_latency_ms: u64,
    final_health: f32,
};

pub const SimulationEngine = struct {
    config: SimulationConfig,
    registry: *basal_ganglia.Registry,
    event_bus: *reticular_formation.EventBus,
    agents: []Agent,
    rng: std.Random.Default,
};

pub const Scenario = enum {
    smoke_test,       // Light load, no failures
    agent_competition,// Many agents, few tasks
    event_storm,      // High event rate
    network_partition,// Simulate partition
    chaos,            // Random failures
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `SimulationEngine.init(config, registry, event_bus)` | Create engine | `SimulationEngine` |
| `engine.run(allocator)` | Run simulation | `!SimulationResult` |
| `engine.runScenario(scenario, allocator)` | Run preset scenario | `!SimulationResult` |
| `engine.getReport(result)` | Generate report | `![]const u8` |
| `Scenario.fromName(name)` | Parse scenario from string | `?Scenario` |
| `runBenchmark(config, allocator)` | Quick benchmark | `!SimulationResult` |

#### Scenarios

| Scenario | Description | Duration |
|----------|-------------|----------|
| `smoke_test` | Light load, verify basic functionality | 10s |
| `agent_competition` | Test claim contention | 30s |
| `event_storm` | High event throughput | 60s |
| `network_partition` | Simulate network failure | 30s |
| `chaos` | Random failures | 60s |

#### Example

```zig
const brain = @import("brain");

// Configure simulation
const config = brain.simulation.SimulationConfig{
    .duration_ms = 30000,
    .agent_count = 20,
    .task_rate = 50.0,  // 50 tasks/sec
    .failure_rate = 0.1,  // 10% failure
    .network_partition = true,
};

// Run simulation
const engine = try brain.simulation.SimulationEngine.init(
    config,
    &registry,
    &event_bus
);
const result = try engine.run(allocator);

// Check results
std.log.info("Completed {d}/{d} tasks", .{
    result.completed_tasks,
    result.total_tasks
});
std.log.info("Final health: {d:.1}%", .{result.final_health});

// Generate report
const report = try engine.getReport(result);
std.log.info("{s}", .{report});
```

### Observability Export (External Telemetry)

**Module**: `brain.observability_export`
**File**: `src/brain/observability_export.zig`
**Purpose**: Export telemetry for external monitoring - Prometheus, OpenTelemetry, InfluxDB, StatsD

#### Types

```zig
pub const ObservabilityExporter = struct {
    exporter_type: ExporterType,
    config: ExporterConfig,
    mutex: std.Thread.Mutex,
};

pub const ExporterType = enum {
    prometheus,     // Prometheus text format
    otlp,           // OpenTelemetry Protocol
    json,           // JSON lines
    influxdb,       // InfluxDB line protocol
    statsd,         // StatsD protocol
};

pub const ExporterConfig = struct {
    endpoint: ?[]const u8 = null,  // HTTP endpoint for OTLP/InfluxDB
    format: ExporterType = .json,
    include_timestamp: bool = true,
    batch_size: usize = 100,
};

pub const MetricsStreamer = struct {
    exporter: *ObservabilityExporter,
    buffer: std.ArrayList(Metric),
    buffer_mutex: std.Thread.Mutex,
};

pub const MetricsServer = struct {
    address: []const u8 = "127.0.0.1",
    port: u16 = 9090,
    exporter: *ObservabilityExporter,
};

pub const Metric = struct {
    name: []const u8,
    value: f64,
    labels: std.StringHashMap([]const u8),
    timestamp: i64,
    metric_type: enum { gauge, counter, histogram } = .gauge,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `ObservabilityExporter.init(config)` | Create exporter | `ObservabilityExporter` |
| `exporter.exportMetric(metric)` | Export single metric | `!void` |
| `exporter.exportBatch(metrics)` | Export metrics batch | `!void` |
| `exporter.formatPrometheus(writer)` | Format as Prometheus | `!void` |
| `exporter.formatOtlp()` | Format as OTLP | `![]const u8` |
| `exporter.formatJson(writer)` | Format as JSON | `!void` |
| `MetricsStreamer.init(exporter)` | Create streamer | `MetricsStreamer` |
| `streamer.record(name, value, labels)` | Record metric | `!void` |
| `streamer.flush()` | Flush buffer | `!void` |
| `MetricsServer.init(exporter, port)` | Create HTTP server | `MetricsServer` |
| `server.start()` | Start HTTP server | `!void` |
| `server.stop()` | Stop HTTP server | `void` |

#### Export Formats

| Format | Protocol | Usage |
|--------|----------|-------|
| `prometheus` | HTTP text | Prometheus scraping |
| `otlp` | HTTP/protobuf | OpenTelemetry collectors |
| `json` | JSON lines | Log aggregators |
| `influxdb` | Line protocol | InfluxDB database |
| `statsd` | UDP | StatsD daemon |

#### Example

```zig
const brain = @import("brain");

// Configure exporter
const config = brain.observability_export.ExporterConfig{
    .format = .prometheus,
    .include_timestamp = true,
};
const exporter = brain.observability_export.ObservabilityExporter.init(config);

// Export metrics
const metric = brain.observability_export.Metric{
    .name = "brain_health",
    .value = 87.5,
    .labels = label_map,  // { "region": "basal_ganglia" }
    .timestamp = std.time.milliTimestamp(),
    .metric_type = .gauge,
};
try exporter.exportMetric(metric);

// Start Prometheus endpoint
var server = brain.observability_export.MetricsServer.init(
    &exporter,
    9090
);
try server.start();
// Now scrape at http://localhost:9090/metrics
```

### Thalamus (Async Relay & Processing)

**Module**: `brain.async_processor`
**File**: `src/brain/async_processor.zig`
**Purpose**: Thalamus (Async Relay & Processing) - Worker pool for async task processing

#### Types

```zig
pub const AsyncProcessor = struct {
    allocator: mem.Allocator,
    workers: []Worker,
    task_queue: TaskQueue,
    result_channels: std.StringHashMap(*ResultChannel),
    config: ProcessorConfig,
    running: std.atomic.Value(bool),
};

pub const AsyncTask = struct {
    id: []const u8,
    task_type: TaskType,
    payload: []const u8,
    timeout_ms: u64,
    created_at: i64,
    callback: ?Callback,
};

pub const TaskType = enum {
    compute,         // CPU-bound task
    io,              // I/O-bound task
    network,         // Network request
    query,           // Database query
    custom,          // User-defined
};

pub const ResultChannel = struct {
    results: std.ArrayList(TaskResult),
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
};

pub const TaskResult = struct {
    task_id: []const u8,
    success: bool,
    data: []const u8,
    error: ?[]const u8,
    duration_ms: u64,
};

pub const ProcessorConfig = struct {
    worker_count: usize = 4,
    queue_size: usize = 1000,
    idle_timeout_ms: u64 = 30000,
    max_retries: usize = 3,
};

pub const BackgroundCollector = struct {
    processor: *AsyncProcessor,
    interval_ms: u64,
    thread: ?std.Thread,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `AsyncProcessor.init(allocator, config)` | Create processor | `!AsyncProcessor` |
| `processor.start()` | Start worker pool | `!void` |
| `processor.stop()` | Stop worker pool | `!void` |
| `processor.submit(task)` | Submit async task | `![]const u8` |
| `processor.awaitResult(task_id, timeout_ms)` | Wait for result | `!TaskResult` |
| `processor.registerChannel(name)` | Register result channel | `!*ResultChannel` |
| `processor.getChannel(name)` | Get result channel | `?*ResultChannel` |
| `processor.getStats()` | Get processor stats | `ProcessorStats` |
| `processor.resizeWorkers(new_count)` | Resize worker pool | `!void` |
| `BackgroundCollector.init(processor, interval_ms)` | Create collector | `BackgroundCollector` |
| `collector.start()` | Start background collection | `!void` |
| `collector.stop()` | Stop background collection | `void` |

#### Example

```zig
const brain = @import("brain");

// Configure processor
const config = brain.async_processor.ProcessorConfig{
    .worker_count = 8,
    .queue_size = 10000,
    .idle_timeout_ms = 60000,
};
const processor = try brain.async_processor.AsyncProcessor.init(
    allocator,
    config
);
try processor.start();

// Submit task
const task = brain.async_processor.AsyncTask{
    .id = "task-123",
    .task_type = .compute,
    .payload = "{\"data\": \"...\"}",
    .timeout_ms = 5000,
    .created_at = std.time.milliTimestamp(),
    .callback = null,
};
const task_id = try processor.submit(task);

// Wait for result
const result = try processor.awaitResult(task_id, 5000);
if (result.success) {
    std.log.info("Result: {s}", .{result.data});
} else {
    std.log.err("Error: {s}", .{result.error.?});
}

// Register channel for streaming results
const channel = try processor.registerChannel("results");
```

### Evolution Simulation (Deterministic Brain Evolution)

**Module**: `brain.evolution_simulation`
**File**: `src/brain/evolution_simulation.zig`
**Purpose**: Deterministic brain evolution - Simulates PPL curves for SEVO (Sacred EVolutionary Objective) optimization

#### Types

```zig
pub const PplModel = struct {
    ppl_start: f32,
    ppl_target: f32,
    asymptote: f32,
    decay_rate: f32,
    noise_level: f32,
};

pub const EvolutionSimulator = struct {
    config: EvolutionConfig,
    models: std.StringHashMap(PplModel),
    rng: std.Random.Default,
    step: u64 = 0,
};

pub const EvolutionConfig = struct {
    max_steps: u64 = 100000,
    checkpoint_interval: u64 = 1000,
    models: []ModelConfig,
    scenarios: []ScenarioConfig,
};

pub const EvolutionResult = struct {
    model_name: []const u8,
    scenario: Scenario,
    steps: []const u64,
    ppl_values: []const f32,
    final_ppl: f32,
    converged: bool,
    convergence_step: ?u64,
};

pub const Scenario = enum {
    baseline,      // S1: Baseline comparison
    current,       // S2: Current implementation
    multi_objective, // S3: Multi-objective optimization
    depin,         // S4: dePIN network simulation
};

pub const ModelConfig = struct {
    name: []const u8,
    ppl_model: PplModel,
    optimizer: enum { adam, lion, sacred_adam },
    learning_rate: f32,
    batch_size: usize,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `EvolutionSimulator.init(config)` | Create simulator | `EvolutionSimulator` |
| `simulator.run(model_name, scenario, allocator)` | Run simulation | `!EvolutionResult` |
| `simulator.runAll(allocator)` | Run all simulations | `![]EvolutionResult` |
| `simulator.step()` | Advance one step | `!void` |
| `simulator.reset()` | Reset to initial state | `void` |
| `simulator.getPPL(model_name, step)` | Get PPL at step | `!f32` |
| `simulator.addModel(name, model)` | Add evolution model | `!void` |
| `simulator.compare(model_a, model_b)` | Compare two models | `!ComparisonResult` |
| `Scenario.fromName(name)` | Parse scenario | `?Scenario` |
| `generatePPLCurve(model, steps)` | Generate PPL curve | `![]f32` |

#### Scenarios

| Scenario | Description | Models |
|----------|-------------|--------|
| `baseline` | S1: Baseline comparison | Reference implementations |
| `current` | S2: Current implementation | Production models |
| `multi_objective` | S3: Multi-objective | Pareto frontier |
| `depin` | S4: dePIN simulation | Federated learning |

#### Example

```zig
const brain = @import("brain");

// Configure evolution
const ppl_model = brain.evolution_simulation.PplModel{
    .ppl_start = 100.0,
    .ppl_target = 4.5,
    .asymptote = 4.0,
    .decay_rate = 0.0001,
    .noise_level = 0.05,
};

const config = brain.evolution_simulation.EvolutionConfig{
    .max_steps = 100000,
    .checkpoint_interval = 1000,
    .models = &[_]brain.evolution_simulation.ModelConfig{
        .{ .name = "hslm-r33", .ppl_model = ppl_model, .optimizer = .adam, .learning_rate = 0.001, .batch_size = 66 },
    },
    .scenarios = &[_]brain.evolution_simulation.ScenarioConfig{.{ .scenario = .current }},
};

// Run simulation
const simulator = brain.evolution_simulation.EvolutionSimulator.init(config);
const result = try simulator.run("hslm-r33", .current, allocator);

std.log.info("Final PPL: {d:.2}", .{result.final_ppl});
if (result.converged) {
    std.log.info("Converged at step {d}", .{result.convergence_step.?});
}
```

### Visual Cortex (Spatial Representation)

**Module**: `brain.visualization`
**File**: `src/brain/visualization.zig`
**Purpose**: Visual Cortex - ASCII art brain maps, sparklines, heatmaps, and 3D visualizations

#### Types

```zig
pub const VizMode = enum {
    map,         // ASCII brain regions
    sparkline,   // Health trends
    connections, // Region dependency graph
    heatmap,     // Activity heatmap
    @"3d",       // Text-based 3D view
    preset,      // Predefined visualization
};

pub const BrainRegionViz = struct {
    name: []const u8,
    health: f32,          // 0-100
    activity: f32,        // 0-1
    color: []const u8,
    position: struct { x: usize, y: usize },
};

pub const BrainState = struct {
    regions: []const BrainRegionViz,
    timestamp: i64,
    overall_health: f32,
};

pub const SparklineOptions = struct {
    width: usize = 40,
    height: usize = 1,
    show_min_max: bool = true,
    color: bool = true,
};

pub const BrainMapOptions = struct {
    show_labels: bool = true,
    show_connections: bool = true,
    compact: bool = false,
    color: bool = true,
};

pub const HeatmapOptions = struct {
    width: usize = 32,
    height: usize = 16,
    color: bool = true,
    show_scale: bool = true,
};

pub const Brain3DOptions = struct {
    rotation_x: f32 = 0.3,
    rotation_y: f32 = 0.5,
    zoom: f32 = 1.0,
    color: bool = true,
    width: usize = 60,
    height: usize = 30,
};

pub const Preset = enum {
    dashboard,  // Full dashboard
    minimal,    // Single-line status
    detailed,   // Detailed brain map
    scan,       // Scan animation
    monitor,    // Real-time monitoring
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `sparkline(allocator, data, opts)` | Generate sparkline | `![]const u8` |
| `brainMap(allocator, state, opts)` | Generate ASCII brain map | `![]const u8` |
| `connectionDiagram(allocator, connections, opts)` | Generate connection diagram | `![]const u8` |
| `activityHeatmap(allocator, data, opts)` | Generate activity heatmap | `![]const u8` |
| `brain3D(allocator, opts)` | Generate 3D visualization | `![]const u8` |
| `preset(allocator, preset_type, opts)` | Generate preset visualization | `![]const u8` |

#### Visualization Modes

| Mode | Output | Use Case |
|------|--------|----------|
| `map` | ASCII brain outline | Regional health overview |
| `sparkline` | Trend line | Health history |
| `connections` | Flow diagram | Region dependencies |
| `heatmap` | Density grid | Activity patterns |
| `3d` | Rotating brain | Spatial awareness |
| `preset` | Pre-built layouts | Quick dashboards |

#### Example

```zig
const brain = @import("brain");

// Health data for sparkline
const health_data = [_]f32{ 85.0, 87.0, 86.0, 88.0, 90.0, 89.0, 87.0 };

// Generate sparkline
const spark = try brain.visualization.sparkline(
    allocator,
    &health_data,
    .{ .width = 30, .color = true }
);
std.log.info("Health: {s}", .{spark});
// Output: "Health: ▃▄▅▆█▇▅ [85.0-90.0]"

// Generate brain map
const regions = [_]brain.visualization.BrainRegionViz{
    .{ .name = "Basal Ganglia", .health = 95.0, .activity = 0.8, .color = "\x1b[32m", .position = .{ .x = 5, .y = 10 } },
    // ... more regions
};
const state = brain.visualization.BrainState{
    .regions = &regions,
    .timestamp = std.time.milliTimestamp(),
    .overall_health = 87.0,
};
const map = try brain.visualization.brainMap(allocator, state, .{});
std.log.info("{s}", .{map});

// Generate preset dashboard
const dashboard = try brain.visualization.preset(
    allocator,
    .dashboard,
    .{ .health_data = &health_data }
);
std.log.info("{s}", .{dashboard});
```

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

#### Example

```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

// Generate instance ID
const my_id = brain.federation.InstanceId.generate();

// Initialize federation
var federation = try brain.federation.FederationState.init(allocator, my_id);
defer federation.deinit();

// Check if I'm the leader
if (federation.amILeader()) {
    std.log.info("I am the leader!", .{});

    // Leader performs privileged operations
    try federation.heartbeat();
} else {
    const leader = federation.getLeader();
    std.log.info("Following leader: {s}", .{leader.?});
}

// Get aggregated health across all instances
const health = federation.getAggregatedHealth();
std.log.info("Federation health: {d:.1}%", .{health});
```

#### Performance Characteristics

- **Leader Election**: Raft-based, < 1s convergence
- **GCounter Merging**: O(n) over instances
- **Heartbeat Interval**: 100ms default
- **Network Overhead**: ~1KB per heartbeat

#### Federation Guarantees

| Property | Guarantee | Mechanism |
|----------|-----------|-----------|
| Leader Uniqueness | At most one leader | Raft consensus |
| Data Consistency | Eventually consistent | GCounter CRDT |
| Network Partition | Auto-recovery | Leader re-election |
| Fault Tolerance | N-1/2 instances | Majority voting |

### Cerebellum (Learning)

**Module**: `brain.learning`
**File**: `src/brain/learning.zig`
**Purpose**: Performance history tracking, pattern recognition, adaptive backoff, failure prediction

#### Types

```zig
pub const LearningSystem = struct {
    history: std.ArrayList(PerformanceRecord),
    patterns: std.ArrayList(Pattern),
    backoff_config: AdaptiveBackoffConfig,
    failure_models: std.ArrayList(FailureModel),
    stats: SystemStats,
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

pub const AdaptiveBackoffConfig = struct {
    initial_ms: u64,
    max_ms: u64,
    multiplier: f32,
    strategy: BackoffStrategy,
    learned_multiplier: f32,
    confidence: f32,
};

pub const FailurePrediction = struct {
    probability: f32,
    reason: []const u8,
    suggested_action: []const u8,
    time_until_failure_ms: u64,
};

pub const Recommendation = struct {
    action: []const u8,
    priority: u8,
    confidence: f32,
    reasoning: []const u8,
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `LearningSystem.init(allocator)` | Initialize | `!LearningSystem` |
| `learning.deinit()` | Free resources | `void` |
| `learning.recordEvent(event)` | Record performance event | `!void` |
| `learning.learnPatterns()` | Analyze history for patterns | `!void` |
| `learning.getBackoffDelay(attempt)` | Get adaptive backoff delay | `u64` |
| `learning.predictFailure(operation)` | Predict failure probability | `FailurePrediction` |
| `learning.getRecommendation()` | Get actionable recommendation | `Recommendation` |

#### Example

```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

var learning = try brain.learning.LearningSystem.init(allocator);
defer learning.deinit();

// Record events
try learning.recordEvent(.{
    .timestamp = std.time.milliTimestamp(),
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

// Learn patterns from history
try learning.learnPatterns();

// Get recommendation
const rec = learning.getRecommendation();
std.log.info("Action: {s} (priority: {d})", .{ rec.action, rec.priority });

// Predict failure
const prediction = learning.predictFailure(.task_claim);
std.log.info("Failure probability: {d:.0}%", .{ prediction.probability * 100 });
```

#### Performance Characteristics

- **Record Event**: < 1us
- **Learn Patterns**: O(n log n) over history
- **Predict Failure**: O(1) with trained model
- **Backoff Calculation**: O(1) adaptive
- **History Size**: Configurable, ~1000 entries

#### Learning Behavior

| Metric | Behavior |
|--------|----------|
| Pattern Confidence | 0-1 scale, updated continuously |
| Adaptive Multiplier | Learns from success/failure |
| Failure Prediction | Based on recent error rate |
| Recommendation Priority | 0-255, higher = urgent |

### Performance Dashboard (Unified Performance Monitoring)

**Module**: `brain.perf_dashboard`
**File**: `src/brain/perf_dashboard.zig`
**Purpose**: Real-time performance tracking, SLA monitoring, comparison reports, sparklines

#### Types

```zig
pub const PerformanceDashboard = struct {
    allocator: std.mem.Allocator,
    histories: std.StringHashMap(PerformanceHistory),
    current_stats: std.StringHashMap(PerformanceStats),
    baseline_stats: std.StringHashMap(PerformanceStats),
    slas: std.StringHashMap(SLATarget),
    start_time: i64,
    last_update: i64,
};

pub const PerformanceSnapshot = struct {
    timestamp: i64,
    operation: []const u8,
    region: []const u8,
    latency_ns: u64,
    memory_bytes: ?u64,
    success: bool,
    metadata: std.StringHashMap([]const u8),
};

pub const PerformanceStats = struct {
    name: []const u8,
    region: []const u8,
    total_ops: u64,
    success_count: u64,
    failure_count: u64,
    total_latency_ns: u64,
    min_latency_ns: u64,
    max_latency_ns: u64,
    p50_ns: u64,
    p95_ns: u64,
    p99_ns: u64,
    throughput_ops_per_sec: f64,
    error_rate: f32,
};

pub const PerformanceHistory = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    region: []const u8,
    latencies: std.array_list.Managed(u64),
    timestamps: std.array_list.Managed(i64),
    max_size: usize,
    current_idx: usize,
    sla: SLATarget,
};

pub const SLATarget = struct {
    max_latency_ns: ?u64 = null,
    min_throughput_ops_per_sec: ?f64 = null,
    max_error_rate: ?f32 = null,
    description: []const u8 = "",
};

pub const SLA_PRESETS = struct {
    pub const TASK_CLAIM: SLATarget;
    pub const EVENT_PUBLISH: SLATarget;
    pub const HEALTH_CHECK: SLATarget;
    pub const TELEMETRY_RECORD: SLATarget;
};
```

#### Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `PerformanceDashboard.init(allocator)` | Create dashboard | `PerformanceDashboard` |
| `dashboard.deinit()` | Free all resources | `void` |
| `dashboard.registerMetric(region, operation, history_size)` | Register metric for tracking | `!void` |
| `dashboard.setSLA(metric_name, sla)` | Set SLA target | `!void` |
| `dashboard.record(region, operation, latency_ns)` | Record measurement | `!void` |
| `dashboard.getStats(region, operation)` | Get current stats | `!PerformanceStats` |
| `dashboard.collectFromBrain()` | Collect from all brain regions | `!void` |
| `dashboard.saveBaseline()` | Save current as baseline | `!void` |
| `dashboard.compareWithBaseline(allocator)` | Compare with baseline | `![]ComparisonResult` |
| `dashboard.formatAscii(writer)` | Format as ASCII table | `!void` |
| `dashboard.formatComparison(writer)` | Format comparison report | `!void` |
| `dashboard.formatSparklines(writer)` | Format all sparklines | `!void` |
| `dashboard.exportJson(writer)` | Export as JSON | `!void` |

#### Example

```zig
const brain = @import("brain");
const allocator = std.heap.page_allocator;

var dashboard = brain.perf_dashboard.PerformanceDashboard.init(allocator);
defer dashboard.deinit();

// Register metrics
try dashboard.registerMetric("Basal Ganglia", "task_claim", 1000);

// Set SLA
const sla = brain.perf_dashboard.SLATarget.init()
    .withLatency(1_000_000)  // 1ms P99
    .withThroughput(10_000)  // 10k OP/s
    .withErrorRate(0.01);    // 1% max error rate
try dashboard.setSLA("task_claim", sla);

// Record measurements
try dashboard.record("Basal Ganglia", "task_claim", 500_000); // 500us
try dashboard.record("Basal Ganglia", "task_claim", 600_000);
try dashboard.record("Basal Ganglia", "task_claim", 400_000);

// Get stats
const stats = try dashboard.getStats("Basal Ganglia", "task_claim");
std.log.info("P99: {d}ns, Throughput: {d:.2} OP/s", .{
    stats.p99_ns,
    stats.throughput_ops_per_sec
});

// Check SLA compliance
const meets_sla = stats.meetsSLA(sla);
std.log.info("SLA met: {}", .{meets_sla});

// Save and compare
try dashboard.saveBaseline();
// ... perform optimization ...
const results = try dashboard.compareWithBaseline(allocator);
defer {
    for (results) |r| {
        allocator.free(r.metric_name);
        allocator.free(r.region);
    }
    allocator.free(results);
}
```

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

- **v5.1** (igla-ready): 23 regions documented, full federation support, evolution simulation, visualization, thalamus logs, intraparietal sulcus
- **v5.0**: Added async processor, learning system
- **v4.4**: Initial 10-region architecture

## See Also

- **Architecture Overview**: `docs/BRAIN_ARCHITECTURE.md`
- **Module Details**: `docs/S3AI_BRAIN_MODULES.md`
- **Federation Protocol**: `src/brain/FEDERATION_PROTOCOL.md`
- **Source Code**: `src/brain/brain.zig`
