# S³AI Brain — Neuroanatomy v5.1

Complete nervous system for Trinity agent swarm coordination.

## Examples

### Basal Ganglia (Action Selection)

```zig
const basal_ganglia = @import("basal_ganglia.zig");

// Initialize registry
var registry = try basal_ganglia.Registry.init(allocator);
defer registry.deinit(allocator);

// Claim a task (atomic, first-come-first-served)
const task_id = "issue-123";
const agent_id = "agent-alpha";
const ttl_ms = 300_000; // 5 minutes

const claimed = try registry.claim(allocator, task_id, agent_id, ttl_ms);
if (claimed) {
    std.debug.print("Task '{s}' claimed by {s}\n", .{task_id, agent_id});

    // Send heartbeat to keep claim alive
    if (registry.heartbeat(task_id, agent_id)) {
        std.debug.print("Heartbeat sent\n");
    }

    // Complete task
    if (registry.complete(task_id, agent_id)) {
        std.debug.print("Task completed\n");
    }
} else {
    std.debug.print("Task already claimed\n");
}

// Get statistics
const stats = registry.getStats();
std.debug.print("Claims: {d}/{d} success\n", .{stats.claim_success, stats.claim_attempts});
```

### Reticular Formation (Event Bus)

```zig
const reticular_formation = @import("reticular_formation.zig");

// Initialize event bus
var event_bus = try reticular_formation.EventBus.init(allocator);
defer event_bus.deinit(allocator);

// Publish event
try event_bus.emit("task_claimed", .{
    .task_id = "issue-123",
    .agent_id = "agent-alpha",
    .timestamp = std.time.timestamp(),
});

// Poll events (get all events since timestamp)
const events = try event_bus.poll(0, allocator, 100);
defer {
    for (events) |ev| {
        allocator.free(ev.type);
        allocator.free(ev.data);
    }
    allocator.free(events);
}

for (events) |ev| {
    std.debug.print("{s}: {s}\n", .{ev.type, ev.data});
}

// Get bus statistics
const stats = event_bus.getStats();
std.debug.print("Events: {d} buffered\n", .{stats.total_events});
```

### Locus Coeruleus (Arousal Regulation)

```zig
const locus_coeruleus = @import("locus_coeruleus.zig");

// Initialize backoff policy (exponential)
var backoff = locus_coeruleus.BackoffPolicy.init(.exponential);
defer backoff.deinit();

// Record failure and get delay for retry
backoff.recordFailure();
const delay_ms = backoff.getCurrentDelay();
std.debug.print("Waiting {d}ms before retry\n", .{delay_ms});

std.time.sleep(delay_ms * 1_000_000);

// On success, reset backoff
backoff.recordSuccess();
const next_delay = backoff.getCurrentDelay(); // = 0.0
```

### Amygdala (Threat Detection)

```zig
const amygdala = @import("amygdala.zig");

// Analyze task for threat level
const salience = amygdala.analyzeTask(
    "critical-security-fix",
    "agent-theta",
    "critical"
);

std.debug.print("Threat level: {}\n", .{salience.level});
std.debug.print("Salience score: {d:.1}\n", .{salience.score});

// Threat levels: .none, .low, .medium, .high, .critical
if (salience.level == .critical) {
    std.debug.print("URGENT: prioritize this task!\n");
}
```

### Full Brain Circuit Example

```zig
const std = @import("std");
const basal_ganglia = @import("basal_ganglia.zig");
const reticular_formation = @import("reticular_formation.zig");
const locus_coeruleus = @import("locus_coeruleus.zig");
const amygdala = @import("amygdala.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Initialize all brain regions
    var registry = try basal_ganglia.Registry.init(allocator);
    defer registry.deinit(allocator);

    var event_bus = try reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit(allocator);

    var backoff = locus_coeruleus.BackoffPolicy.init(.exponential);

    // Agent workflow
    const task_id = "issue-456";
    const agent_id = "agent-beta";

    // 1. Amygdala evaluates threat
    const threat = amygdala.analyzeTask(task_id, agent_id, "medium");
    if (threat.level == .critical) {
        std.debug.print("High priority task detected!\n");
    }

    // 2. Try to claim task (Basal Ganglia)
    const claimed = try registry.claim(allocator, task_id, agent_id, 300_000);
    if (!claimed) {
        // 3. Calculate backoff delay (Locus Coeruleus)
        backoff.recordFailure();
        const delay = backoff.getCurrentDelay();
        std.time.sleep(@intFromFloat(delay * 1_000_000));
        return; // Retry later
    }

    // Broadcast claim event (Reticular Formation)
    try event_bus.emit("task_claimed", .{
        .task_id = task_id,
        .agent_id = agent_id,
        .timestamp = std.time.timestamp(),
    });

    // Execute task...
    std.debug.print("Executing task '{s}'...\n", .{task_id});

    // Complete task
    _ = registry.complete(task_id, agent_id);
    backoff.recordSuccess();

    try event_bus.emit("task_completed", .{
        .task_id = task_id,
        .agent_id = agent_id,
        .timestamp = std.time.timestamp(),
    });
}
```

## Architecture

The brain is organized into biological regions, each handling a specific aspect of agent coordination:

| Brain Region | File | Biological Function | Engineering Role |
|---|---|---|---|
| **Basal Ganglia** | `basal_ganglia.zig` | Action Selection (Go/No-Go) | Task claim registry — prevents duplicate execution |
| **Reticular Formation** | `reticular_formation.zig` | Broadcast Alerting | Event bus — publishes events for all agents |
| **Locus Coeruleus** | `locus_coeruleus.zig` | Arousal Regulation | Backoff policy — regulates timing and retry behavior |
| **Intraparietal Sulcus** | `intraparietal_sulcus.zig` | Numerical Processing | f16/GF16/TF3 format conversions |
| **Brain Aggregator** | `brain.zig` | Corpus Callosum | High-level API combining all regions |

## Sacred Formula

```
φ² + 1/φ² = 3 = TRINITY
```

Where φ = (1 + √5) / 2 ≈ 1.618 (golden ratio)

## Quick Start

```zig
const brain = @import("brain");

// Initialize brain circuitry
var coord = try brain.AgentCoordination.init(allocator);
defer coord.deinit();

// Agent tries to claim a task
const task_id = "issue-123";
const agent_id = "agent-007";
const claimed = try coord.claimTask(task_id, agent_id);

if (claimed) {
    // Task acquired — execute work
    const result = await executeTask(task);

    if (result.success) {
        try coord.completeTask(task_id, agent_id, result.duration_ms);
    } else {
        try coord.failTask(task_id, agent_id, result.error);
    }
} else {
    // Task taken by another agent — backoff
    const delay = coord.getBackoffDelay(attempt);
    std.time.sleep(delay);
}
```

## CLI Commands

```bash
# Basal Ganglia (Task Claims)
tri task claim <task_id> [--agent <id>]     # Claim a task
tri task release <task_id> [--agent <id>]    # Release a task
tri task list [--agent <id>]                 # List active claims
tri task stats                               # Show registry stats
tri task heartbeat <task_id> [--agent <id>]  # Refresh claim
tri task reset                               # Clear registry

# Reticular Formation (Event Bus)
tri event stream [--since <ts>] [--max <N>]  # Poll events
tri event stats                               # Show bus stats
tri event trim <count>                        # Trim old events
tri event clear                               # Clear all events

# Brain Health
tri stress --health                           # Quick health check
tri stress                                   # Full stress test (1000×10)
```

## Testing

```bash
# Unit tests (individual regions)
zig build test-basal-ganglia
zig build test-reticular-formation
zig build test-locus-coeruleus
zig build test-intraparietal

# Integration test
zig build test-brain

# Stress test (Functional MRI)
zig build test-brain-stress
```

## Stress Test Phases

The stress test validates brain circuit health under load:

1. **Phase 1: Basal Ganglia** — Concurrent Claims (1000 tasks × 10 agents)
   - Validates: No duplicate task claims
   - Score: 0-100 based on claim success rate

2. **Phase 2: Locus Coeruleus** — Backoff Fairness
   - Validates: Jain's Fairness Index ≥ 0.95
   - Score: 0-100 based on fairness

3. **Phase 3: Reticular Formation** — Event Broadcast
   - Validates: Event delivery rate ≥ 95%
   - Score: 0-100 based on delivery rate

**Pass Criteria**: Score ≥ 270/300 (90+ per phase)

## Brain Health Check

```zig
const health = coord.healthCheck();

if (health.healthy) {
    std.debug.print("Brain is healthy! Score: {d:.1}/100\n", .{health.score});
} else {
    std.debug.print("Brain needs attention! Score: {d:.1}/100\n", .{health.score});
}
```

Health formula:
```
score = (claims_ok * 0.4 + events_ok * 0.4 + backoff_ok * 0.2) * 100
```

## External Dependencies

- **zig-hslm**: Official HSLM numerical library
  - Repository: https://codeberg.org/gHashTag/zig-hslm
  - Branch: feat/vector-float-cast
  - Local copy: `external/zig-hslm/src/f16_utils.zig`

## CI Pipeline

See `.github/workflows/brain-ci.yml` for the full CI pipeline:

1. **Phase 0**: Build Check (fast feedback)
2. **Phase 1**: Unit Tests (parallel matrix)
3. **Phase 2**: Integration Test
4. **Phase 3**: Stress Test (Functional MRI Gate) ⭐
5. **Phase 4**: CLI Smoke Test
6. **Final**: Brain Health Report

## Performance Characteristics

- **Task Claim**: O(1) hash map lookup
- **Event Publish**: O(1) append (circular buffer)
- **Event Poll**: O(n) where n = buffered events
- **Backoff Delay**: O(1) computation

## Memory Limits

- Max buffered events: 10,000
- Task claim TTL: 5 minutes (300,000 ms)
- Circular buffer overflow: oldest events auto-trimmed

## Thread Safety

All brain regions use `std.Thread.Mutex` for thread-safe operations:
- Basal Ganglia: Registry protected by mutex
- Reticular Formation: Event bus protected by mutex
- Locus Coeruleus: Stateless (no mutex needed)

## References

- Academic: https://www.academia.edu/144897776/Trinity_Framework_Architecture
- zig-hslm: https://codeberg.org/gHashTag/zig-hslm
- GitHub: https://github.com/gHashTag/trinity

## License

MIT — See Trinity repository for full license text.
