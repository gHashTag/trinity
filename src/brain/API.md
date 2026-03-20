# S3AI Brain API Documentation

## Overview

The S3AI Brain is a bio-inspired neuromorphic architecture implementing 10 brain regions for autonomous agent coordination. Each region maps biological function to engineering purpose, following the sacred formula: phi^2 + 1/phi^2 = 3 = TRINITY.

## Module Overview Table

| Brain Region | Biological Function | Engineering Role | File |
|-------------|---------------------|------------------|------|
| **Basal Ganglia** | Action Selection | Task claim registry - prevents duplicate task execution across agents | `basal_ganglia.zig` |
| **Reticular Formation** | Broadcast Alerting | Event bus - publishes task events for all agents to consume | `reticular_formation.zig` |
| **Locus Coeruleus** | Arousal Regulation | Backoff policy - regulates timing and retry behavior | `locus_coeruleus.zig` |
| **Amygdala** | Emotional Salience | Detects emotionally significant events and prioritizes them | `amygdala.zig` |
| **Prefrontal Cortex** | Executive Function | Decision making, planning, and cognitive control | `prefrontal_cortex.zig` |
| **Intraparietal Sulcus** | Numerical Processing | f16/GF16/TF3 conversions via zig-hslm integration | `intraparietal_sulcus.zig` |
| **Hippocampus** | Memory Persistence | JSONL event logging for replay and analysis | `persistence.zig` |
| **Corpus Callosum** | Telemetry | Time-series metrics aggregation | `telemetry.zig` |
| **Thalamus** | Sensory Relay | Railway live logs relay to HSLM cortex modules | `thalamus_logs.zig` |
| **Microglia** | Immune Surveillance | Constant Gardeners - patrols farm, prunes crashed workers, stimulates regrowth | `microglia.zig` |

---

## Quick Start

```zig
const std = @import("std");
const brain = @import("brain");

// Initialize high-level coordination API
var coord = try brain.AgentCoordination.init(allocator);
defer {
    brain.basal_ganglia.resetGlobal(allocator);
    brain.reticular_formation.resetGlobal(allocator);
}

// Claim a task (returns false if already claimed)
const claimed = try coord.claimTask("issue-123", "agent-alpha");
if (!claimed) {
    const delay = coord.getBackoffDelay(0);
    std.time.sleep(delay * 1_000_000);
}

// Refresh heartbeat periodically
_ = coord.refreshHeartbeat("issue-123", "agent-alpha");

// Complete task
try coord.completeTask("issue-123", "agent-alpha", 5000);

// Health check
const health = coord.healthCheck();
std.debug.print("Brain health: {d:.1}/100\n", .{health.score});
```

---

## Basal Ganglia (Action Selection)

### Purpose
CRDT-based task claim system for parallel agent coordination. First agent wins - atomic claim with TTL + heartbeat.

### Types

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
};
```

### API Functions

#### `Registry.init(allocator: std.mem.Allocator) Registry`
Creates a new task claim registry.

#### `Registry.deinit(self: *Registry) void`
Frees all claimed task IDs and agent IDs from memory.

#### `Registry.claim(self: *Registry, allocator: std.mem.Allocator, task_id: []const u8, agent_id: []const u8, ttl_ms: u64) !bool`
Attempts to claim a task for an agent. Returns `true` if claim succeeded, `false` if already claimed by another agent or claim expired.

**Parameters:**
- `task_id`: Unique task identifier
- `agent_id`: Unique agent identifier
- `ttl_ms`: Time-to-live in milliseconds (claim expires after this)

#### `Registry.heartbeat(self: *Registry, task_id: []const u8, agent_id: []const u8) bool`
Refreshes the heartbeat timestamp for an active claim. Returns `true` if heartbeat updated, `false` if claim not found or invalid.

**Note:** Heartbeats must be sent within 30 seconds or the claim expires.

#### `Registry.complete(self: *Registry, task_id: []const u8, agent_id: []const u8) bool`
Marks a task as completed. Returns `true` if successful.

#### `Registry.abandon(self: *Registry, task_id: []const u8, agent_id: []const u8) bool`
Marks a task as abandoned. Returns `true` if successful.

#### `Registry.reset(self: *Registry) void`
Clears all claims from the registry.

### Global Singleton

```zig
pub fn getGlobal(allocator: std.mem.Allocator) !*Registry
pub fn resetGlobal(allocator: std.mem.Allocator) void
```

### Usage Example

```zig
const basal_ganglia = @import("brain").basal_ganglia;

// Get or create global registry
const registry = try basal_ganglia.getGlobal(allocator);

// Claim a task with 5-minute TTL
const claimed = try registry.claim(allocator, "task-123", "agent-007", 300_000);
if (claimed) {
    std.debug.print("Task claimed successfully\n", .{});

    // Send heartbeat every 20 seconds
    while (working) {
        std.time.sleep(20 * 1_000_000_000);
        _ = registry.heartbeat("task-123", "agent-007");
    }

    // Complete the task
    _ = registry.complete("task-123", "agent-007");
} else {
    std.debug.print("Task already claimed or expired\n", .{});
}
```

---

## Reticular Formation (Broadcast Alerting)

### Purpose
Event streaming system for Trinity agents. Thread-safe event publishing and polling with in-memory circular buffer (max 10,000 events).

### Types

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
    allocator: std.mem.Allocator,
    events: std.ArrayList(StoredEvent),
    stats: struct { published: u64, polled: u64 },
};
```

### API Functions

#### `EventBus.init(allocator: std.mem.Allocator) EventBus`
Creates a new event bus with initial capacity of 256 events.

#### `EventBus.deinit(self: *EventBus) void`
Frees all event memory.

#### `EventBus.publish(self: *EventBus, event_type: AgentEventType, data: EventData) !void`
Publishes an event to the bus. Automatically trims oldest events if buffer exceeds 10,000.

#### `EventBus.poll(self: *EventBus, since: i64, allocator: std.mem.Allocator, max_events: usize) ![]AgentEventRecord`
Returns events with timestamp greater than `since`. Caller must free returned slice.

#### `EventBus.getStats(self: *EventBus) struct { published: u64, polled: u64, buffered: usize }`
Returns current statistics.

#### `EventBus.trim(self: *EventBus, count: usize) void`
Trims buffer to keep only the most recent `count` events.

#### `EventBus.clear(self: *EventBus) void`
Clears all events from buffer.

### Global Singleton

```zig
pub fn getGlobal(allocator: std.mem.Allocator) !*EventBus
pub fn resetGlobal(allocator: std.mem.Allocator) void
```

### Usage Example

```zig
const reticular_formation = @import("brain").reticular_formation;

const bus = try reticular_formation.getGlobal(allocator);

// Publish events
try bus.publish(.task_claimed, .{
    .task_claimed = .{ .task_id = "task-123", .agent_id = "agent-007" }
});

try bus.publish(.task_completed, .{
    .task_completed = .{ .task_id = "task-123", .agent_id = "agent-007", .duration_ms = 5000 }
});

// Poll recent events (last minute)
const since = std.time.milliTimestamp() - 60_000;
const events = try bus.poll(since, allocator, 100);
defer allocator.free(events);

for (events) |ev| {
    std.debug.print("{d}: {?}\n", .{ev.timestamp, ev.event_type});
}

// Get statistics
const stats = bus.getStats();
std.debug.print("Published: {d}, Buffered: {d}\n", .{stats.published, stats.buffered});
```

---

## Locus Coeruleus (Arousal Regulation)

### Purpose
Exponential backoff policy for agent retry logic. Supports multiple strategies and jitter types.

### Types

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

### API Functions

#### `BackoffPolicy.init() BackoffPolicy`
Creates a default backoff policy (exponential, no jitter).

#### `BackoffPolicy.nextDelay(self: *const BackoffPolicy, attempt: u32) u64`
Calculates delay for given attempt number.

**Strategies:**
- `exponential`: `initial_ms * multiplier^attempt`
- `linear`: `min(max_ms, initial_ms + linear_increment * attempt)`
- `constant`: Always returns `initial_ms`

**Jitter types:**
- `none`: No jitter added
- `uniform`: Multiplies by `(1.0 + random[0,1))`
- `phi_weighted`: Multiplies by 0.618 or 1.618 (golden ratio)

### Usage Example

```zig
const locus_coeruleus = @import("brain").locus_coeruleus;

// Exponential backoff with phi-weighted jitter
var policy = locus_coeruleus.BackoffPolicy{
    .initial_ms = 1000,
    .max_ms = 60000,
    .multiplier = 2.0,
    .strategy = .exponential,
    .jitter_type = .phi_weighted,
};

// Retry loop
var attempt: u32 = 0;
while (attempt < 5) {
    const result = try doSomething();
    if (result) break;

    const delay = policy.nextDelay(attempt);
    std.debug.print("Attempt {d} failed, waiting {d}ms\n", .{attempt, delay});
    std.time.sleep(delay * 1_000_000);
    attempt += 1;
}
```

---

## Amygdala (Emotional Salience)

### Purpose
Detects emotionally significant events and prioritizes them. Analyzes tasks and errors for salience.

### Types

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
```

### API Functions

#### `SalienceLevel.fromScore(score: f32) SalienceLevel`
Converts a score (0-100) to salience level:
- `< 20`: none
- `< 40`: low
- `< 60`: medium
- `< 80`: high
- `>= 80`: critical

#### `SalienceLevel.emoji(self: SalienceLevel) []const u8`
Returns emoji representation: ⚪, 🟢, 🟡, 🟠, 🔴

#### `Amygdala.analyzeTask(task_id: []const u8, realm: []const u8, priority: []const u8) EventSalience`
Analyzes task salience based on realm (dukh=+40, razum=+30), keywords (urgent=+30, critical=+50, security=+40), and priority field.

#### `Amygdala.analyzeError(err_msg: []const u8) EventSalience`
Analyzes error salience based on patterns:
- Critical (+30 each): segfault, panic, out of memory, deadlock, corruption, security, authentication, injection
- High (+15 each): timeout, connection refused, not found
- Base score: 20

#### `Amygdala.requiresAttention(salience: EventSalience) bool`
Returns `true` if level is high or critical.

#### `Amygdala.urgency(salience: EventSalience) f32`
Returns urgency score (0-1, higher = more urgent).

### Usage Example

```zig
const amygdala = @import("brain").amygdala;

// Analyze task salience
const task_salience = amygdala.analyzeTask("urgent-security-fix", "dukh", "high");
std.debug.print("Task salience: {s} ({d:.1}/100)\n", .{
    @tagName(task_salience.level),
    task_salience.score,
});

// Analyze error salience
const err_salience = amygdala.analyzeError("segfault in critical module");
if (amygdala.requiresAttention(err_salience)) {
    std.debug.print("CRITICAL: Immediate attention required!\n", .{});
}

// Check urgency
const urgency = amygdala.urgency(err_salience);
if (urgency > 0.5) {
    // Prioritize this event
}
```

---

## Prefrontal Cortex (Executive Function)

### Purpose
Decision making, planning, and cognitive control. Evaluates system context and recommends actions.

### Types

```zig
pub const DecisionContext = struct {
    task_count: usize,
    active_agents: usize,
    error_rate: f32,
    avg_latency_ms: u64,
    memory_usage_pct: f32,
};

pub const Action = enum {
    proceed,       // Continue normal operations
    throttle,      // Reduce task acceptance rate
    scale_up,      // Spawn more agents
    scale_down,    // Reduce agent count
    pause,         // Pause new task acceptance
    alert,         // Immediate intervention required
};

pub const Decision = struct {
    action: Action,
    confidence: f32,
    reasoning: []const u8,
};
```

### API Functions

#### `PrefrontalCortex.decide(ctx: DecisionContext) Decision`
Makes executive decision based on context:
- `error_rate > 0.5`: pause
- `error_rate > 0.2`: throttle
- `queue_per_agent > 10`: scale_up
- `avg_latency_ms > 5000`: throttle
- `memory_usage_pct > 90`: alert
- `memory_usage_pct > 75`: throttle
- `underutilized`: scale_down

#### `PrefrontalCortex.recommend(decision: Decision) []const u8`
Returns human-readable recommendation string.

### Usage Example

```zig
const prefrontal_cortex = @import("brain").prefrontal_cortex;

const ctx = .{
    .task_count = 200,
    .active_agents = 10,
    .error_rate = 0.05,
    .avg_latency_ms = 500,
    .memory_usage_pct = 40.0,
};

const decision = prefrontal_cortex.PrefrontalCortex.decide(ctx);
std.debug.print("Action: {s}, Confidence: {d:.1}\n", .{
    @tagName(decision.action),
    decision.confidence,
});

std.debug.print("Recommendation: {s}\n", .{
    prefrontal_cortex.PrefrontalCortex.recommend(decision),
});
```

---

## Intraparietal Sulcus (Numerical Processing)

### Purpose
Numerical processing and format conversion. Integrates zig-hslm for f16/GF16/TF3 support.

### Re-exported Types

```zig
pub const f16 = hslm.f16;
pub const GF16 = hslm.GF16;
pub const TF3 = hslm.TF3;
pub const PHI = hslm.PHI;        // 1.618
pub const PHI_INV = hslm.PHI_INV; // 0.618
```

### API Functions

#### Number Format Conversion

```zig
pub fn f16ToF32(v: f16) f32
pub fn f32ToF16(v: f32) f16
pub fn f16BatchToF32(comptime N: usize, src: [N]f16) [N]f32
pub fn f32BatchToF16(comptime N: usize, src: [N]f32) [N]f16
```

#### Phi-Weighted Quantization

```zig
pub fn phiQuantize(v: f32) f16
pub fn phiDequantize(v: f16) f32
```

#### GF16 (Golden Float16) Utilities

```zig
pub fn f32ToGF16(v: f32) GF16
pub fn gf16ToF32(gf: GF16) f32
```

#### TF3 (Ternary Float3) Utilities

```zig
pub fn i2ToTF3(comptime N: usize, src: [N]i2) TF3
pub fn tf3ToI2(tf3: TF3, comptime N: usize) [N]i2
```

#### SIMD-Safe Vector Float Cast

```zig
pub fn vectorFloatCast(comptime T: type, src: anytype) T
```

### Numerical Metrics

```zig
pub const NumericalMetrics = struct {
    quantization_error_max: f32,
    quantization_error_avg: f32,
    overflow_count: u32,
    nan_count: u32,
    inf_count: u32,
    subnormal_count: u32,

    pub fn init() NumericalMetrics
    pub fn track(self: *NumericalMetrics, original: f32, quantized: f16) void
    pub fn trackSpecial(self: *NumericalMetrics, value: f16) void
};
```

### Usage Example

```zig
const ips = @import("brain").intraparietal_sulcus;

// Convert f32 to f16
const original: f32 = 3.14159;
const f16_val = ips.f32ToF16(original);
const f32_val = ips.f16ToF32(f16_val);

// Phi-weighted quantization
const quantized = ips.phiQuantize(2.71828);
const dequantized = ips.phiDequantize(quantized);

// GF16 conversion
const gf = ips.f32ToGF16(1.41421);
const back = ips.gf16ToF32(gf);

// Track numerical metrics
var metrics = ips.NumericalMetrics.init();
metrics.track(original, f16_val);
std.debug.print("Max error: {d:.6}\n", .{metrics.quantization_error_max});
```

---

## Persistence (Hippocampus - Event Log)

### Purpose
Persists brain events to JSONL for replay and analysis.

### Types

```zig
pub const BrainEventLog = struct {
    file: fs.File,
    writer: fs.File.Writer,
    mutex: std.Thread.Mutex,
};
```

### API Functions

#### `BrainEventLog.open(path: []const u8) !Self`
Opens or creates a brain event log file at the given path. Creates parent directories if needed.

#### `BrainEventLog.close(self: *Self) void`
Closes the log file.

#### `BrainEventLog.log(self: *Self, comptime fmt: []const u8, args: anytype) !void`
Logs a brain event with nanosecond timestamp. Thread-safe.

### Usage Example

```zig
const persistence = @import("brain").persistence;

var log = try persistence.BrainEventLog.open(".trinity/brain_events.jsonl");
defer log.close();

try log.log("task_claimed", .{});
try log.log("task_completed {d}ms", .{5000});
try log.log("error: {s}", .{"segfault"});
```

---

## Telemetry (Corpus Callosum)

### Purpose
Time-series metrics aggregation for analysis and alerting.

### Types

```zig
pub const TelemetryPoint = struct {
    timestamp: i64,
    active_claims: usize,
    events_published: u64,
    events_buffered: usize,
    health_score: f32,
};

pub const BrainTelemetry = struct {
    allocator: std.mem.Allocator,
    points: std.ArrayList(TelemetryPoint),
    max_points: usize,
    mutex: std.Thread.Mutex,
};
```

### API Functions

#### `BrainTelemetry.init(allocator: std.mem.Allocator, max_points: usize) Self`
Creates a new telemetry collector with fixed max capacity.

#### `BrainTelemetry.deinit(self: *Self) void`
Frees all telemetry data.

#### `BrainTelemetry.record(self: *Self, point: TelemetryPoint) !void`
Records a telemetry point. Automatically trims oldest if over capacity.

#### `BrainTelemetry.avgHealth(self: *Self, last_n: usize) f32`
Returns average health score over last N points.

#### `BrainTelemetry.trend(self: *Self, last_n: usize) enum { improving, stable, declining }`
Analyzes trend direction over last N points.

#### `BrainTelemetry.exportJson(self: *Self, writer: anytype) !void`
Exports all telemetry points as JSON.

### Usage Example

```zig
const telemetry = @import("brain").telemetry;

var tel = telemetry.BrainTelemetry.init(allocator, 1000);
defer tel.deinit();

const now = std.time.nanoTimestamp();
try tel.record(.{
    .timestamp = now,
    .active_claims = 5,
    .events_published = 100,
    .events_buffered = 10,
    .health_score = 90.0,
});

const avg_health = tel.avgHealth(100);
const trend = tel.trend(100);

std.debug.print("Avg health: {d:.1}, Trend: {s}\n", .{
    avg_health, @tagName(trend),
});

// Export as JSON
var buffer: std.ArrayList(u8) = .init(allocator);
defer buffer.deinit();
try tel.exportJson(buffer.writer());
```

---

## Health History (Hippocampal Memory)

### Purpose
Records brain health snapshots over time for trend analysis.

### Types

```zig
pub const HealthSnapshot = struct {
    timestamp: i64,
    health_score: f32,
    healthy: bool,
    active_claims: usize,
    events_published: u64,
    events_buffered: usize,
    stress_test_passed: bool,
    stress_test_score: ?u32,
};

pub const BrainHealthHistory = struct {
    allocator: std.mem.Allocator,
};
```

### API Functions

#### `BrainHealthHistory.init(allocator: std.mem.Allocator) BrainHealthHistory`
Creates a new health history instance.

#### `BrainHealthHistory.record(snapshot_ptr: *BrainHealthHistory, snapshot: HealthSnapshot) !void`
Appends a health snapshot to `.trinity/brain_health_history.jsonl`.

#### `BrainHealthHistory.recent(self: *BrainHealthHistory, n: usize) ![]HealthSnapshot`
Returns the last N health snapshots. Caller must free.

#### `BrainHealthHistory.trend(self: *BrainHealthHistory, n: usize) !enum { improving, stable, declining }`
Analyzes health trend over last N snapshots.

### Usage Example

```zig
const health_history = @import("brain").health_history;

var history = health_history.BrainHealthHistory.init(allocator);

const snapshot = .{
    .timestamp = std.time.milliTimestamp(),
    .health_score = 95.0,
    .healthy = true,
    .active_claims = 5,
    .events_published = 100,
    .events_buffered = 10,
    .stress_test_passed = true,
    .stress_test_score = 98,
};

try history.record(snapshot);

const snapshots = try history.recent(10);
defer allocator.free(snapshots);

const trend = try history.trend(10);
std.debug.print("Health trend: {s}\n", .{@tagName(trend)});
```

---

## Thalamus Logs (Sensory Relay)

### Purpose
Relays sensory input from Queen (18 sensors) to cortex (5 HSLM modules). Provides circular buffer logging with direct HSLM module calls.

### Neuroanatomical Context
The thalamus is the brain's sensory gateway - all touch, vision, hearing, and other sensory signals pass through it before reaching cortex. In Trinity, Railway logs are "touch" (external sensory data) that flows through Thalamus to HSLM cortex modules (IPS, Weber, OFC, Angular, Fusiform).

### Types

```zig
pub const CAPACITY: usize = 256;  // Circular buffer capacity

pub const SensorId = enum(u8) {
    FarmBestPpl = 7,    // f32 perplexity -> IPS -> GF16 encode
    ArenaBattles = 8,   // i8 win/loss -> IPS -> TF3 ternary encode
    OuroborosScore = 9, // f32 -> Weber -> log-quantize
    TestsRate = 2,      // f32 pass % -> OFC -> value judgment
    DiskFree = 10,      // u64 bytes -> Fusiform -> GF16 compact
    ArenaStale = 14,    // u32 hours -> Angular -> verbalize/introspect
};

pub const SensoryKind = enum(u8) {
    magnitude = 0,  // Encode with GF16
    ternary = 1,    // Encode with TF3-9
    valence = 2,    // Use OFC for value judgment
    verbal = 3,     // Use Angular for introspection
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

### API Functions

#### `ThalamusLogs.init(buf_storage: *[CAPACITY]SensoryEvent) Self`
Initializes thalamus with pre-allocated buffer storage.

#### `ThalamusLogs.logEvent(self: *Self, event: SensoryEvent) void`
Logs a sensory event to circular buffer.

#### `ThalamusLogs.clear(self: *Self) void`
Clears all events from the buffer.

#### `ThalamusLogs.reset(self: *Self) void`
Alias for clear() - resets buffer to initial state.

#### `ThalamusLogs.count(self: *const Self) usize`
Returns current event count.

#### `ThalamusLogs.isEmpty(self: *const Self) bool`
Returns true if buffer is empty.

#### `ThalamusLogs.isFull(self: *const Self) bool`
Returns true if buffer is at capacity.

#### `ThalamusLogs.iterator(self: *const Self) Iterator`
Returns iterator over all events (head to tail).

#### `ThalamusLogs.processSensor(self: *Self, sensor_data: SensorInput) !void`
Processes sensor input through appropriate HSLM module and stores result.

### Usage Example

```zig
const thalamus = @import("brain").thalamus_logs;

var buf_storage: [256]thalamus.SensoryEvent = undefined;
var logs = thalamus.ThalamusLogs.init(&buf_storage);

// Process farm best PPL (f32 -> IPS -> GF16)
try logs.processSensor(.{
    .id = .FarmBestPpl,
    .raw_f32 = 4.6,
});

// Process arena battles (i8 -> IPS -> TF3)
try logs.processSensor(.{
    .id = .ArenaBattles,
    .raw_i8 = 1, // win
});

// Check buffer state
std.debug.print("Events: {d}/{}\n", .{logs.count(), thalamus.ThalamusLogs.CAPACITY});

// Iterate events
var iter = logs.iterator();
while (iter.next()) |ev| {
    std.debug.print("Sensor {d}: {?}\n", .{@intFromEnum(ev.sensor), ev.input.raw_f32});
}

// Clear when done
logs.clear();
```

### Version
v5.2.0 - Bugfix: iterator modulus, added clear/reset/count/isEmpty/isFull, improved tests

---

## Microglia (Immune Surveillance)

### Purpose
The Constant Gardeners - patrols training farm every 30 minutes, prunes crashed/stalled workers, stimulates regrowth from top performers.

### Types

```zig
pub const Microglia = struct {
    patrol_interval_ms: u64 = 30 * 60 * 1000,
    night_mode: bool = false,
    sacred_list: []const []const u8 = &.{},
    find_me_threshold: f32 = 15.0,
    eat_me_threshold: f32 = 100.0,
    dont_eat_me: []const []const u8 = &.{"hslm-r33", "hslm-r5", "hslm-r13"},
    state_file: []const u8 = ".trinity/microglia_state.jsonl",
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

pub const SynapticSignal = enum {
    find_me,      // Neuron needs help
    eat_me,       // Neuron is dying
    dont_eat_me,  // Healthy neuron
    help_me,      // Needs support
};

pub const WorkerState = struct {
    ppl: f32,
    step: u32,
    status: enum { active, stalled, crashed },
};
```

### API Functions

#### `Microglia.patrol(_: *const Microglia, allocator: std.mem.Allocator) !SurveillanceReport`
Runs surveillance patrol to scan farm and assess health.

#### `Microglia.phagocytose(self: *Microglia, worker_id: []const u8) !void`
Prunes a dead/dying worker. Respects "don't-eat-me" signals and night mode.

#### `Microglia.stimulateRegrowth(_: *const Microglia, template: []const u8, allocator: std.mem.Allocator) ![]const u8`
Spawns new worker from top performer template.

#### `Microglia.enterSleepMode(self: *Microglia) void`
Reduces pruning aggression during sleep hours.

#### `Microglia.wakeUp(self: *Microglia) void`
Restores full pruning capacity.

#### `detectSignal(worker: WorkerState) SynapticSignal`
Detects synaptic signal from worker state based on PPL and status.

### Usage Example

```zig
const microglia = @import("brain").microglia;

var mg = microglia.Microglia{
    .patrol_interval_ms = 30 * 60 * 1000,
    .dont_eat_me = &.{"hslm-r33", "hslm-r5"},
};

// Run patrol
const report = try mg.patrol(allocator);
std.debug.print("Crashed workers: {d}\n", .{report.crashed_workers});

// Prune crashed worker
try mg.phagocytose("hslm-bad-worker-42");

// Stimulate regrowth from best performer
const new_worker = try mg.stimulateRegrowth("hslm-r33", allocator);
std.debug.print("New worker: {s}\n", .{new_worker});
allocator.free(new_worker);

// Detect signal from worker
const signal = microglia.detectSignal(.{
    .ppl = 5.0,
    .step = 10000,
    .status = .active,
});
std.debug.print("Signal: {s}\n", .{@tagName(signal)});
```

---

## High-Level Integration Guide

### AgentCoordination API

The `AgentCoordination` struct provides a unified interface combining all brain regions for seamless integration into orchestrators.

```zig
pub const AgentCoordination = struct {
    allocator: std.mem.Allocator,
    registry: *basal_ganglia.Registry,
    event_bus: *reticular_formation.EventBus,
    backoff_policy: locus_coeruleus.BackoffPolicy,
};
```

### Initialization

```zig
var coord = try brain.AgentCoordination.init(allocator);
defer {
    brain.basal_ganglia.resetGlobal(allocator);
    brain.reticular_formation.resetGlobal(allocator);
}
```

### Core Workflow

```zig
// 1. Claim task
const claimed = try coord.claimTask(task_id, agent_id);
if (!claimed) {
    const delay = coord.getBackoffDelay(attempt);
    std.time.sleep(delay * 1_000_000);
    return; // Retry later
}

// 2. Work on task (send heartbeat periodically)
while (working) {
    std.time.sleep(20 * 1_000_000_000);
    _ = coord.refreshHeartbeat(task_id, agent_id);
}

// 3. Complete or fail
try coord.completeTask(task_id, agent_id, duration_ms);
// OR
try coord.failTask(task_id, agent_id, err_msg);
```

### Monitoring

```zig
// Get statistics
const stats = coord.getStats();
std.debug.print("Active claims: {d}, Events: {d}\n", .{
    stats.active_claims, stats.total_events_published,
});

// Health check
const health = coord.healthCheck();
if (!health.healthy) {
    std.debug.print("Brain unhealthy! Score: {d:.1}\n", .{health.score});
}

// Poll events
const events = try coord.pollEvents(since_timestamp, 100);
defer allocator.free(events);
for (events) |ev| {
    std.debug.print("Event: {s}\n", .{@tagName(ev.event_type)});
}
```

### Metrics Export

```zig
// Prometheus format
var buffer: std.ArrayList(u8) = .init(allocator);
defer buffer.deinit();
try coord.exportMetrics(buffer.writer());
std.debug.print("{s}\n", .{buffer.items});

// Brain dump (ASCII)
var stdout_writer = std.io.getStdOut().writer();
try coord.dump(stdout_writer);

// Visual scan
const scan = coord.scan();
std.debug.print("Overall: {s}\n", .{scan.overall});
```

### Complete Example

```zig
const std = @import("std");
const brain = @import("brain");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var coord = try brain.AgentCoordination.init(allocator);
    defer {
        brain.basal_ganglia.resetGlobal(allocator);
        brain.reticular_formation.resetGlobal(allocator);
    }

    const task_id = "issue-123";
    const agent_id = "agent-alpha-001";

    // Try to claim task with backoff
    var attempt: u32 = 0;
    while (attempt < 5) {
        const claimed = try coord.claimTask(task_id, agent_id);
        if (claimed) break;

        const delay = coord.getBackoffDelay(attempt);
        std.debug.print("Claim failed, waiting {d}ms...\n", .{delay});
        std.time.sleep(delay * 1_000_000);
        attempt += 1;
    } else {
        std.debug.print("Could not claim task after 5 attempts\n", .{});
        return;
    }

    std.debug.print("Task claimed, starting work...\n", .{});

    // Simulate work with heartbeat
    const start = std.time.milliTimestamp();
    var work_done = false;
    while (!work_done) {
        // Send heartbeat
        _ = coord.refreshHeartbeat(task_id, agent_id);

        // Do actual work here
        work_done = true; // Placeholder

        std.time.sleep(5 * 1_000_000_000); // 5 seconds
    }

    const duration_ms = @intCast(std.time.milliTimestamp() - start);

    // Complete task
    try coord.completeTask(task_id, agent_id, duration_ms);

    // Print final stats
    const health = coord.healthCheck();
    const stats = coord.getStats();

    std.debug.print("\n=== Task Complete ===\n", .{});
    std.debug.print("Duration: {d}ms\n", .{duration_ms});
    std.debug.print("Brain health: {d:.1}/100\n", .{health.score});
    std.debug.print("Events published: {d}\n", .{stats.total_events_published});
}
```

---

## Constants and Configuration

### Sacred Constants

```zig
const SACRED_PHI: f32 = 1.618;  // Golden ratio
const SACRED_PHI_INV: f32 = 0.618;  // 1/phi
```

### Default Values

| Module | Parameter | Default |
|--------|-----------|---------|
| Basal Ganglia | TTL | 5 minutes (300,000ms) |
| Basal Ganglia | Heartbeat timeout | 30 seconds |
| Reticular Formation | Max events | 10,000 |
| Locus Coeruleus | Initial delay | 1,000ms |
| Locus Coeruleus | Max delay | 60,000ms |
| Locus Coeruleus | Multiplier | 2.0 |
| Microglia | Patrol interval | 30 minutes |
| Microglia | Find-me threshold | PPL 15.0 |
| Microglia | Eat-me threshold | PPL 100.0 |

### File Paths

```zig
const BRAIN_HEALTH_LOG = ".trinity/brain_health_history.jsonl";
const MICROGLIA_STATE_FILE = ".trinity/microglia_state.jsonl";
```

---

## Testing

Run all brain tests:

```bash
zig build test-brain
```

Run specific module tests:

```bash
zig test src/brain/basal_ganglia.zig
zig test src/brain/reticular_formation.zig
zig test src/brain/locus_coeruleus.zig
```

Run stress test:

```bash
zig build test-brain-stress
```

The stress test simulates 1000 tasks across 10 competing agents to validate:
- Basal Ganglia: no duplicate task claims
- Reticular Formation: event broadcast consistency
- Locus Coeruleus: backoff timing fairness

---

## Biological References

### Papers

1. **Paolicelli & Gasparini (2011)** - "Microglia in the developing brain: From birth to adulthood"
2. **Stevens et al. (2007)** - "The classical complement pathway is required for developmental synapse elimination"
3. **EMBL (2024)** - "Gardening the Brain" - synapse pruning review

### Trinity Mapping

| Biological Concept | Engineering Equivalent |
|-------------------|------------------------|
| Synapse | Training worker |
| Weak synapse | Poor performer (high PPL) |
| Strong synapse | Leader (low PPL) |
| Pruning | Kill via ASHA/PBT |
| Neurotrophic factors | Recycle from best |
| Find-me signal | Worker needs help |
| Eat-me signal | Worker is dying |
| Don't-eat-me signal | Sacred protection |

---

## Version History

- **v5.2** - Thalamus Logs bugfix (iterator modulus), added clear/reset/count/isEmpty/isFull, 40 tests
- **v5.1** - S³AI Brain with Intraparietal Sulcus, Thalamus Logs, Microglia
- **v5.0** - AgentCoordination high-level API
- **v1.0** - Initial brain regions (Basal Ganglia, Reticular Formation, Locus Coeruleus)

---

## License

MIT License - See repository root for details.

---

## References

- zig-hslm: https://codeberg.org/gHashTag/zig-hslm
- Academic: https://www.academia.edu/144897776/Trinity_Framework_Architecture
- Trinity Repository: https://github.com/gHashTag/trinity

phi^2 + 1/phi^2 = 3 = TRINITY
