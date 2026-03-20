# S³AI Brain Architecture Decision Records (ADRs)

This document contains architecture decision records (ADRs) for the S³AI Brain.
Each ADR captures a significant architectural decision, its context,
alternatives considered, and the consequences.

## ADR-001: Event-Based Inter-Region Communication

**Status**: Accepted

**Context**:
- Brain regions need to communicate state changes and events
- Multiple agents run concurrently, requiring coordination
- Synchronous calls would create tight coupling

**Decision**:
Use the Reticular Formation as a pub/sub event bus for inter-region
communication. Regions publish events and other regions poll for changes.

**Alternatives Considered**:
1. **Direct function calls**: Too tight coupling, hard to add new regions
2. **Shared mutable state**: Race conditions, difficult to reason about
3. **Event bus pattern (CHOSEN)**: Decoupled, extensible, ordered

**Consequences**:
- **Positive**: Loosely coupled regions, easy to add new subscribers
- **Positive**: Natural ordering by timestamp, replay capability
- **Negative**: Must manage event buffer size (10,000 event limit)
- **Negative**: No guarantee of delivery (poll-based)

**Implementation**:
```zig
// Publish event
try event_bus.publish(.task_claimed, .{
    .task_claimed = .{ .task_id = "task-123", .agent_id = "agent-001" }
});

// Poll for new events
const events = try event_bus.poll(since_timestamp, allocator, 100);
```

---

## ADR-002: CRDT-Based Task Claim Registry

**Status**: Accepted

**Context**:
- Multiple agents must not work on the same task
- Agents can crash, requiring automatic timeout
- No central lock server (distributed agents)

**Decision**:
Use a CRDT-inspired task claim registry with first-come-first-served
semantics. Claims have TTL and require heartbeats for liveness.

**Alternatives Considered**:
1. **Central lock server**: Single point of failure, added complexity
2. **Distributed lock (Raft)**: Too complex for use case
3. **CRDT claim registry (CHOSEN)**: Simple, no central server

**Consequences**:
- **Positive**: No single point of failure
- **Positive**: Automatic cleanup via TTL
- **Positive**: Liveness via heartbeat
- **Negative**: Race window between expiration and reclaim
- **Negative**: No priority ordering (first come wins)

**Implementation**:
```zig
const claimed = try registry.claim(allocator, task_id, agent_id, ttl_ms);
if (claimed) {
    // Refresh heartbeat every 30s
    _ = registry.heartbeat(task_id, agent_id);
    // Complete when done
    _ = registry.complete(task_id, agent_id);
}
```

---

## ADR-003: Sacred Jitter for Retry Timing

**Status**: Accepted

**Context**:
- Multiple agents retrying simultaneously can cause "thundering herd"
- Uniform jitter doesn't leverage sacred constants
- Brain architecture embraces sacred geometry (phi)

**Decision**:
Use golden ratio (phi = 1.618...) for jitter calculation.
Jitter factors: 0.618x (phi inverse) or 1.618x (phi).

**Alternatives Considered**:
1. **No jitter**: Thundering herd problem
2. **Uniform random jitter**: Good, but no sacred meaning
3. **Phi-weighted jitter (CHOSEN)**: Sacred + solves herd problem

**Consequences**:
- **Positive**: Reduces thundering herd by splitting retries into two groups
- **Positive**: Aligned with sacred brain architecture
- **Negative**: Two discrete values (could be smoother)
- **Negative**: Fixed ratio (not adaptive)

**Sacred Formula**:
- phi = (1 + sqrt(5)) / 2 ≈ 1.618...
- phi^2 + 1/phi^2 = 3 = TRINITY

**Implementation**:
```zig
const factor: f32 = if (seed % 2 == 0) 0.618 else 1.618;
const delay = @as(u64, @intFromFloat(@as(f32, @floatFromInt(base_delay)) * factor));
```

---

## ADR-004: Global Singleton Pattern for Core Regions

**Status**: Accepted

**Context**:
- Multiple modules need access to same brain region state
- Thread-safe access required
- Avoid passing allocator everywhere

**Decision**:
Use global singleton pattern with lazy initialization.
`getGlobal(allocator)` creates instance on first call, returns same instance subsequently.

**Alternatives Considered**:
1. **Pass explicit references**: Verbose, easy to get wrong instance
2. **Dependency injection**: Complex setup
3. **Global singleton (CHOSEN)**: Simple, accessible anywhere

**Consequences**:
- **Positive**: Simple API (`brain.basal_ganglia.getGlobal(allocator)`)
- **Positive**: Thread-safe with mutex-protected initialization
- **Positive**: Single source of truth
- **Negative**: Hidden dependencies (magic initialization)
- **Negative**: Testing requires explicit reset

**Implementation**:
```zig
var global_registry: ?*Registry = null;
var global_mutex = std.Thread.Mutex{};

pub fn getGlobal(allocator: std.mem.Allocator) !*Registry {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_registry) |reg| return reg;

    const reg = try allocator.create(Registry);
    reg.* = Registry.init(allocator);
    global_registry = reg;
    return reg;
}
```

---

## ADR-005: Priority-Based Executive Action Selection

**Status**: Accepted

**Context**:
- Prefrontal Cortex evaluates multiple system metrics
- Multiple conditions can be true simultaneously
- Need deterministic action selection

**Decision**:
Use priority-based action selection with explicit precedence.
Higher priority actions override lower priority ones.

**Priority Order** (highest to lowest):
1. **alert**: memory > 90% (critical resource exhaustion)
2. **pause**: error_rate > 0.5 (severe degradation)
3. **throttle**: elevated metrics but not critical
4. **scale_up**: queue depth too high
5. **scale_down**: underutilized
6. **proceed**: all systems healthy (default)

**Alternatives Considered**:
1. **Score-based selection**: Need to define scoring weights
2. **Rule engine**: More flexible but complex
3. **Priority-based (CHOSEN)**: Simple, deterministic

**Consequences**:
- **Positive**: Clear, predictable action selection
- **Positive**: Easy to debug and understand
- **Negative**: Hard to add nuanced behaviors
- **Negative**: Fixed priorities may not fit all scenarios

**Implementation**:
```zig
// Check in priority order
if (ctx.memory_usage_pct > 90) {
    action = .alert; // Highest priority
} else if (ctx.error_rate > 0.5) {
    action = .pause;
} else if (ctx.error_rate > 0.2) {
    action = .throttle;
}
// ...
```

---

## ADR-006: JSONL Format for Hippocampal Event Logging

**Status**: Accepted

**Context**:
- Need to log brain events for replay and analysis
- Binary format is compact but hard to inspect
- Standard formats make tooling easier

**Decision**:
Use JSONL (JSON Lines) format for event logging.
One JSON object per line, newline-separated.

**Alternatives Considered**:
1. **Binary format**: Compact, but requires custom tools
2. **JSON array**: Requires parsing entire file to append
3. **JSONL (CHOSEN)**: Append-only, human-readable

**Consequences**:
- **Positive**: Append-only write (fast, no rewrite)
- **Positive**: Human-readable, grep-able
- **Positive**: Standard tooling support
- **Negative**: Verbose (less space-efficient)
- **Negative**: No schema validation

**Format Example**:
```jsonl
{"ts":1710907200000,"event":"task_claimed","data":{"task_id":"task-123","agent_id":"agent-001"}}
{"ts":1710907260000,"event":"metric_update","data":{"metric":"ppl","value":2.45}}
```

---

## ADR-007: In-Memory Circular Buffer for Event Bus

**Status**: Accepted

**Context**:
- Event bus needs to store recent events for polling
- Files too slow for real-time access
- Unbounded memory growth is dangerous

**Decision**:
Use in-memory circular buffer with fixed capacity (10,000 events).
Oldest events are automatically removed when capacity exceeded.

**Alternatives Considered**:
1. **Unbounded array**: Risk of memory exhaustion
2. **File-backed buffer**: Slow, complex
3. **Circular buffer (CHOSEN)**: Fixed memory, automatic cleanup

**Consequences**:
- **Positive**: Predictable memory usage
- **Positive**: No manual cleanup needed
- **Positive**: Fast in-memory access
- **Negative**: Events older than buffer limit are lost
- **Negative**: Must tune capacity for workload

**Configuration**:
```zig
const MAX_EVENTS: usize = 10_000; // ~2MB at typical event sizes
```

---

## ADR-008: Thread Safety via Mutex (Not Lock-Free)

**Status**: Accepted

**Context**:
- Multiple threads access brain regions concurrently
- Need to ensure data consistency
- Zig provides std.Thread.Mutex

**Decision**:
Use std.Thread.Mutex for all shared data structures.
Explicit locking at critical sections.

**Alternatives Considered**:
1. **Lock-free data structures**: Complex, Zig std doesn't provide them
2. **Actor model**: Too much architecture change
3. **Mutex locking (CHOSEN)**: Simple, well-understood

**Consequences**:
- **Positive**: Simple to implement correctly
- **Positive**: Standard approach, easy to review
- **Positive**: Zig's Mutex is efficient (futex-based on Linux)
- **Negative**: Lock contention possible under high load
- **Negative**: Deadlock risk (avoid by consistent lock order)

**Implementation Pattern**:
```zig
pub const Registry = struct {
    claims: std.StringHashMap(TaskClaim),
    mutex: std.Thread.Mutex,

    pub fn claim(self: *Registry, ...) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        // Critical section
    }
};
```

---

## ADR-009: Emoji-Based Salience Visualization

**Status**: Accepted

**Context**:
- Need TUI-friendly visualization of salience levels
- Text alone doesn't convey urgency quickly
- Color not available in all TUI environments

**Decision**:
Use emoji characters for salience level visualization.
⚪ (none), 🟢 (low), 🟡 (medium), 🟠 (high), 🔴 (critical)

**Alternatives Considered**:
1. **Text labels only**: Slower to scan
2. **ANSI colors**: Not available everywhere
3. **Emoji (CHOSEN)**: Universal, works on most terminals

**Consequences**:
- **Positive**: Quick visual scan of urgency
- **Positive**: Works on most modern terminals
- **Positive**: No terminal escape sequences needed
- **Negative**: May not display correctly on legacy terminals
- **Negative**: Unicode handling varies by environment

**Mapping**:
```zig
pub fn emoji(self: SalienceLevel) []const u8 {
    return switch (self) {
        .none => "⚪",
        .low => "🟢",
        .medium => "🟡",
        .high => "🟠",
        .critical => "🔴",
    };
}
```

---

## ADR-010: Five-Level Salience Classification

**Status**: Accepted

**Context**:
- Need to classify events by importance
- Binary (urgent/not urgent) insufficient
- Too many levels make decision thresholds complex

**Decision**:
Use five-level salience classification with fixed score thresholds.

**Levels**:
| Level | Score Range | Meaning |
|-------|-------------|---------|
| none | 0-19 | Routine, ignore |
| low | 20-39 | Normal processing |
| medium | 40-59 | Elevated importance |
| high | 60-79 | Requires attention |
| critical | 80-100 | Immediate action |

**Alternatives Considered**:
1. **Binary (urgent/not)**: Too coarse
2. **10 levels**: Too many thresholds to tune
3. **Five levels (CHOSEN)**: Balanced granularity

**Consequences**:
- **Positive**: Clear, intuitive levels
- **Positive**: Easy thresholds (multiples of 20)
- **Positive**: Maps well to emoji visualization
- **Negative**: Some gray areas at boundaries

**Threshold Formula**:
```zig
pub fn fromScore(score: f32) SalienceLevel {
    return if (score < 20) .none
        else if (score < 40) .low
        else if (score < 60) .medium
        else if (score < 80) .high
        else .critical;
}
```

---

## ADR-011: Modular Brain Region Architecture

**Status**: Accepted

**Context**:
- Brain has 21 regions with distinct responsibilities
- Need to organize code for maintainability
- Want to avoid monolithic brain module

**Decision**:
Each brain region is a separate Zig module file.
Main `brain.zig` aggregates all regions for convenient import.

**Alternatives Considered**:
1. **Single file**: Too large, hard to navigate
2. **Package with submodules**: Zig doesn't have subpackages
3. **Separate files (CHOSEN)**: Clear separation

**Consequences**:
- **Positive**: Easy to find specific region code
- **Positive**: Can test regions independently
- **Positive**: Can add new regions without touching existing
- **Negative**: Must import through brain.zig aggregator
- **Negative**: Some circular dependency handling needed

**Module Structure**:
```
src/brain/
├── brain.zig           # Aggregator, exports all regions
├── basal_ganglia.zig  # Action selection
├── reticular_formation.zig  # Event bus
├── locus_coeruleus.zig  # Backoff
├── amygdala.zig        # Salience
├── prefrontal_cortex.zig  # Executive function
└── ... (16 more regions)
```

---

## ADR-012: AgentCoordination High-Level API

**Status**: Accepted

**Context**:
- Orchestrators need access to multiple brain regions
- Repeatedly calling individual region APIs is verbose
- Common patterns emerge (claim -> work -> complete)

**Decision**:
Provide `AgentCoordination` wrapper combining core regions.
Single interface for common orchestration patterns.

**Wrapped Regions**:
- Basal Ganglia (task claims)
- Reticular Formation (events)
- Locus Coeruleus (backoff)
- Telemetry (metrics)
- Alerts (notifications)

**Alternatives Considered**:
1. **Direct region access**: Verbose, error-prone
2. **Trait-based composition**: Not idiomatic in Zig
3. **Wrapper struct (CHOSEN)**: Clean API

**Consequences**:
- **Positive**: Simple API for common patterns
- **Positive**: Handles coordination (claim + publish)
- **Positive**: Built-in health checking
- **Negative**: Adds another abstraction layer
- **Negative**: Doesn't expose all region capabilities

**Usage Example**:
```zig
var coord = try brain.AgentCoordination.init(allocator);
defer coord.deinit();

// Claim, work, complete
if (try coord.claimTask(task_id, agent_id)) {
    _ = coord.refreshHeartbeat(task_id, agent_id);
    try coord.completeTask(task_id, agent_id, duration_ms);
}

// Check health
const health = coord.healthCheck();
```

---

## ADR-013: Fixed Health Score Formula

**Status**: Accepted

**Context**:
- Need a single metric for overall brain health
- Multiple regions contribute differently to health
- Formula must be deterministic and explainable

**Decision**:
Use weighted average formula with fixed weights:
```
health = 100 × (0.4 × generated_ratio +
                 0.3 × compliance_rate +
                 0.2 × specs_coverage +
                 0.1 × tests_passing)
```

**Components**:
- **generated_ratio** (40%): Code from pipeline
- **compliance_rate** (30%): Passing tests/linting
- **specs_coverage** (20%): Documented in .tri specs
- **tests_passing** (10%): Test pass rate

**Alternatives Considered**:
1. **Minimum component**: Too pessimistic
2. **Geometric mean**: Harder to explain
3. **Weighted average (CHOSEN)**: Balanced

**Consequences**:
- **Positive**: Single number 0-100
- **Positive**: Weights reflect component importance
- **Positive**: Easy to understand contribution
- **Negative**: Weights are heuristic (not scientific)
- **Negative**: Doesn't capture all quality aspects

**Health Categories**:
| Score | Category | Meaning |
|-------|----------|---------|
| 90-100 | HEALTHY | Good to go |
| 70-89 | RECOVERING | Some issues, auto-fixing |
| 50-69 | INFECTED | Significant problems |
| 0-49 | CRITICAL | Major intervention needed |

---

## ADR-014: Biological Metaphor for Region Naming

**Status**: Accepted

**Context**:
- Need names for brain regions
- Names should be memorable and meaningful
- Biological metaphor aligns with "brain" concept

**Decision**:
Use biological brain region names that map to computational function.

**Mapping**:
| Brain Region | Computational Function |
|-------------|----------------------|
| Basal Ganglia | Action selection, task coordination |
| Reticular Formation | Event broadcasting, alerting |
| Locus Coeruleus | Arousal regulation, backoff timing |
| Amygdala | Emotional salience, prioritization |
| Prefrontal Cortex | Executive decision making |
| Hippocampus | Memory persistence, event logging |
| Corpus Callosum | Telemetry aggregation |
| Intraparietal Sulcus | Numerical processing |
| Microglia | Immune surveillance, pruning |
| Thalamus | Sensory relay, logs relay |
| Hypothalamus | Administrative control |

**Alternatives Considered**:
1. **Technical names**: BasalGanglia, EventBus, etc.
2. **Abstract names**: Coordinator, Manager, etc.
3. **Biological metaphor (CHOSEN)**: Memorable, thematically consistent

**Consequences**:
- **Positive**: Memorable and distinctive
- **Positive**: Thematically consistent
- **Positive**: Biological accuracy for enthusiasts
- **Negative**: Some names require lookup for newcomers
- **Negative**: Metaphor can be imperfect

---

## ADR-015: Expiration-Based Claim Validity

**Status**: Accepted

**Context**:
- Tasks can be abandoned (agent crash)
- Need to free claims after abandonment
- No crash notification in all cases

**Decision**:
Claims become invalid after either:
1. Time-to-live expires (e.g., 5 minutes)
2. No heartbeat for 30 seconds
3. Status changed to completed or abandoned

**Alternatives Considered**:
1. **Heartbeat only**: Claims never expire on healthy agents
2. **Manual release**: Requires explicit call
3. **Hybrid (CHOSEN)**: Best of both worlds

**Consequences**:
- **Positive**: Automatic cleanup from crashes
- **Positive**: Liveness detection via heartbeat
- **Positive**: Flexible TTL for different task types
- **Negative**: Must tune heartbeat interval
- **Negative**: Claims may expire during long tasks

**Validity Check**:
```zig
pub fn isValid(self: *const TaskClaim) bool {
    if (self.status != .active) return false;

    const now_ms = std.time.timestamp() * 1000;
    const age_ms = @as(u64, @intCast(now_ms - self.claimed_at));
    if (age_ms > self.ttl_ms) return false;

    const heartbeat_age_ms = @as(u64, @intCast(now_ms - self.last_heartbeat));
    if (heartbeat_age_ms > 30000) return false; // 30s heartbeat timeout

    return true;
}
```

---

## ADR-016: Trend Detection for Telemetry

**Status**: Accepted

**Context**:
- Telemetry stores historical metrics
- Need to identify improving or degrading trends
- Single point values are noisy

**Decision**:
Use simple linear trend detection on N most recent points.
Compare average of first half to average of second half.

**Trend Classification**:
- **improving**: Recent average > older average + threshold
- **stable**: Absolute difference < threshold
- **declining**: Recent average < older average - threshold

**Alternatives Considered**:
1. **No trend**: Only latest value
2. **Linear regression**: More complex, similar result
3. **Simple comparison (CHOSEN)**: Easy to understand

**Consequences**:
- **Positive**: Simple, fast calculation
- **Positive**: Clear three-state classification
- **Negative**: Threshold requires tuning
- **Negative**: Doesn't detect non-linear trends

**Implementation**:
```zig
pub const Trend = enum { improving, stable, declining };

pub fn trend(self: *const BrainTelemetry, last_n: usize) Trend {
    const count = @min(self.points.items.len, last_n);
    if (count < 2) return .stable;

    const mid = count / 2;
    var first_sum: f32 = 0;
    var second_sum: f32 = 0;

    for (0..mid) |i| {
        first_sum += self.points.items[self.points.items.len - count + i].health_score;
    }
    for (mid..count) |i| {
        second_sum += self.points.items[self.points.items.len - count + i].health_score;
    }

    const first_avg = first_sum / @as(f32, @floatFromInt(mid));
    const second_avg = second_sum / @as(f32, @floatFromInt(count - mid));

    const diff = second_avg - first_avg;
    const threshold: f32 = 1.0; // Configurable

    return if (diff > threshold) .improving
        else if (diff < -threshold) .declining
        else .stable;
}
```

---

## ADR-017: Percentile Calculation for Metrics

**Status**: Accepted

**Context**:
- Need to understand metric distribution
- Average can be skewed by outliers
- Percentiles show typical values better

**Decision**:
Use linear interpolation for percentile calculation.
Sample array is sorted and percentile value is interpolated.

**Algorithm**:
1. Sort N most recent samples
2. Compute target index: `(percentile / 100) * N`
3. If exact index, return that value
4. Otherwise, interpolate between neighbors

**Alternatives Considered**:
1. **Average only**: Doesn't show distribution
2. **Min/Max**: Too extreme
3. **Percentile (CHOSEN)**: Shows typical values

**Consequences**:
- **Positive**: P50 = median, robust to outliers
- **Positive**: P95 shows "typical worst"
- **Positive**: Standard interpretation
- **Negative**: Requires sorting (O(N log N))
- **Negative**: Sampling required for large datasets

**Common Percentiles**:
| Percentile | Meaning |
|-----------|---------|
| P50 | Median, typical value |
| P95 | 95th percentile, "typical worst" |
| P99 | 99th percentile, extreme but expected |

---

## ADR-018: Microglia Patrol and Prune Strategy

**Status**: Accepted

**Context**:
- Workers (HSLM training services) crash and fail
- Need automated cleanup of crashed workers
- Want to maintain healthy worker population

**Decision**:
Microglia patrols farm every 30 minutes and:
1. Identifies crashed workers
2. Prunes (deletes) crashed workers
3. Stimulates regrowth from healthy workers
4. Respects "don't eat me" protected workers
5. Night mode reduces aggression during off-hours

**Alternatives Considered**:
1. **Manual cleanup**: Too slow, error-prone
2. **Immediate cleanup**: Can cascade failures
3. **Periodic patrol (CHOSEN)**: Time to verify stability

**Consequences**:
- **Positive**: Automated worker health management
- **Positive**: Protects important workers (leaders)
- **Positive**: Night mode preserves diversity during off-hours
- **Negative**: 30-minute patrol interval may be too long
- **Negative**: No learning from patrol history

**Configuration**:
```zig
pub const Microglia = struct {
    patrol_interval_ms: u64 = 30 * 60 * 1000, // 30 minutes
    night_mode: bool = false,
    dont_eat_me: []const []const u8 = &.{ "hslm-r33", "hslm-r5", "hslm-r13" },
};
```

---

## ADR-019: Federation for Multi-Instance Coordination

**Status**: Accepted

**Context**:
- Multiple brain instances may run (different machines/containers)
- Need distributed coordination between instances
- Want leader election and state synchronization

**Decision**:
Use Raft-inspired federation protocol:
- Leader election via term voting
- CRDT state synchronization
- G-Counter for task/event counting

**Alternatives Considered**:
1. **Single instance**: No distributed support
2. **Full Raft**: Too complex for this use case
3. **Simplified federation (CHOSEN)**: Adequate coordination

**Consequences**:
- **Positive**: Distributed multi-instance support
- **Positive**: Leader election prevents split brain
- **Positive**: CRDT counters converge eventually
- **Negative**: Network partitions cause temporary split
- **Negative**: Not full Raft (log replication missing)

**Federation State**:
```zig
pub const FederationState = struct {
    my_id: InstanceId,
    instances: std.StringHashMap(InstanceInfo),
    election: ElectionState, // term, voted_for, leader_id, state
    task_counter: GCounter,   // CRDT: max of all counters
    event_counter: GCounter,  // CRDT: max of all counters
};
```

---

## ADR-020: Confidence Scoring for Executive Decisions

**Status**: Accepted

**Context**:
- Prefrontal Cortex makes executive decisions
- Not all decisions are equally reliable
- Feedback on decision quality helps automation

**Decision**:
Confidence score (0.0 to 1.0) based on:
- Starting confidence: 1.0
- Each degradation factor reduces confidence by 0.1-0.2

**Degradation Factors**:
- High error rate: -0.2 (0.8)
- High queue depth: -0.1 (0.9)
- High latency: -0.2 (0.8)
- High memory: -0.15 (0.85)
- Underutilized: -0.2 (0.8)

**Alternatives Considered**:
1. **No confidence**: All decisions equal weight
2. **Probabilistic**: Random action selection
3. **Confidence scoring (CHOSEN)**: Quantifies certainty

**Consequences**:
- **Positive**: Decision reliability information available
- **Positive**: Can warn on low-confidence decisions
- **Positive**: Simple, interpretable formula
- **Negative**: Weights are heuristic
- **Negative**: No learning from past decisions

**Example**:
```zig
// All healthy: confidence = 1.0
// High latency: confidence = 0.8
// High latency + high queue: confidence = 0.72
```

---

## ADR Index

| ADR | Title | Status |
|-----|-------|--------|
| 001 | Event-Based Inter-Region Communication | Accepted |
| 002 | CRDT-Based Task Claim Registry | Accepted |
| 003 | Sacred Jitter for Retry Timing | Accepted |
| 004 | Global Singleton Pattern for Core Regions | Accepted |
| 005 | Priority-Based Executive Action Selection | Accepted |
| 006 | JSONL Format for Hippocampal Event Logging | Accepted |
| 007 | In-Memory Circular Buffer for Event Bus | Accepted |
| 008 | Thread Safety via Mutex (Not Lock-Free) | Accepted |
| 009 | Emoji-Based Salience Visualization | Accepted |
| 010 | Five-Level Salience Classification | Accepted |
| 011 | Modular Brain Region Architecture | Accepted |
| 012 | AgentCoordination High-Level API | Accepted |
| 013 | Fixed Health Score Formula | Accepted |
| 014 | Biological Metaphor for Region Naming | Accepted |
| 015 | Expiration-Based Claim Validity | Accepted |
| 016 | Trend Detection for Telemetry | Accepted |
| 017 | Percentile Calculation for Metrics | Accepted |
| 018 | Microglia Patrol and Prune Strategy | Accepted |
| 019 | Federation for Multi-Instance Coordination | Accepted |
| 020 | Confidence Scoring for Executive Decisions | Accepted |

---

## See Also

- **Brain Atlas**: `docs/BRAIN_ATLAS.md`
- **Main Module**: `src/brain/brain.zig`
- **API Reference**: `docs/BRAIN_API.md`
