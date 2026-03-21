# S³AI Brain — Neuroanatomy v5.1

Complete nervous system for Trinity agent swarm coordination.

## Architecture Overview

The brain uses a **sharded design** for horizontal scalability:

| Brain Region | File | Biological Function | Engineering Role |
|---|---|---|---|
| **Basal Ganglia** | `basal_ganglia.zig` | Action Selection (Go/No-Go) | Sharded task claim registry — prevents duplicate execution |
| **Reticular Formation** | `reticular_formation.zig` | Broadcast Alerting | Event bus — publishes events for all agents |
| **Locus Coeruleus** | `locus_coeruleus.zig` | Arousal Regulation | Backoff policy — regulates timing and retry behavior |
| **Intraparietal Sulcus** | `intraparietal_sulcus.zig` | Numerical Processing | f16/GF16/TF3 format conversions |
| **Hippocampus** | `state_recovery.zig` | Memory Consolidation | Save/load brain state for crash recovery |
| **Brain Aggregator** | `brain.zig` | Corpus Callosum | High-level API combining all regions |

## Examples

### Basal Ganglia (Action Selection)

```zig
const basal_ganglia = @import("basal_ganglia.zig");

// Initialize registry (sharded, 16 partitions)
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

// Get statistics (lock-free atomic counters)
const stats = registry.getStats();
std.debug.print("Claims: {d}/{d} success, Active: {d}\n", .{
    stats.claim_success, stats.claim_attempts, stats.active_claims
});
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

### Hippocampus (State Recovery)

```zig
const state_recovery = @import("state_recovery.zig");

// Initialize state manager
var manager = try state_recovery.StateManager.init(allocator);
defer manager.deinit();

// Save current brain state
try manager.save(&registry, &event_bus);

// Load brain state on startup (crash recovery)
var loaded = try manager.load();
defer loaded.deinit();

// Restore state to live components
// NOTE: Summary entries are skipped during restore
try manager.restore(&loaded, &registry, &event_bus);

// Check state file info
const info = try manager.getStateInfo();
std.debug.print("State exists: {}, Backups: {d}\n", .{info.exists, info.backup_count});
```

**IMPORTANT**: Due to the sharded Registry design:
- `save()` captures a **summary entry** with statistics instead of individual claims
- `restore()` **skips summary entries** (task_id="_summary") during recovery
- Active agents must re-establish claims after recovery

**Auto-Recovery**:
```zig
// Automatically recover on startup
const recovered = try state_recovery.autoRecover(allocator, &registry, &event_bus);
if (recovered) {
    std.debug.print("Brain recovered from previous state\n");
} else {
    std.debug.print("Starting fresh (no previous state)\n");
}
```

## Architecture Details

### Sharded Registry Design

The Basal Ganglia uses a **sharded HashMap** for horizontal scalability:

- **16 shards** (power of 2 for fast hash-based routing)
- Each shard has its own `RwLock` for independent access
- Operations on different shards can proceed in parallel
- ~16x reduction in contention vs single-lock design

**Shard Selection**: `hash(task_id) & (SHARD_COUNT - 1)`

### State Persistence Behavior

The Hippocampus (state recovery) has these behaviors due to the sharded design:

1. **Summary Entry Behavior**: During `save()`, the Registry doesn't expose individual claims
   (they're distributed across shards). Instead, a single summary entry is captured:
   ```json
   {
     "task_id": "_summary",
     "agent_id": "_registry",
     "status": "active:42,completed:10,abandoned:3"
   }
   ```

2. **Restore Behavior**: During `restore()`, summary entries are automatically skipped.
   Only actual task claims are restored, and only if they're still active and unexpired.

3. **Claim Re-establishment**: After recovery, active agents should:
   - Check if their previous tasks are still claimed
   - Re-claim any tasks that expired during the downtime
   - Use heartbeat to refresh claims immediately

## Sacred Formula

```
φ² + 1/φ² = 3 = TRINITY
```

Where φ = (1 + √5) / 2 ≈ 1.618 (golden ratio)

## Performance Characteristics

| Operation | Time Complexity | Thread Safety | Notes |
|---|---|---|---|
| **claim()** | O(1) | Locks one shard | Hash-based routing |
| **heartbeat()** | O(1) | Locks one shard | Read lock on shard |
| **complete()** | O(1) | Locks one shard | Update claim status |
| **abandon()** | O(1) | Locks one shard | Mark as abandoned |
| **getStats()** | O(SHARD_COUNT) | Locks all shards | Atomic counters are lock-free |
| **count()** | O(SHARD_COUNT) | Shared locks on all shards | Sum of shard counts |
| **listClaims()** | O(N) + O(SHARD_COUNT) | Shared locks on all shards | N = total claims |
| **cleanupExpired()** | O(N) + O(SHARD_COUNT) | Exclusive locks sequentially | N = total claims |

### Sharding Benefits

- **Parallel Reads**: Different shards can be read simultaneously
- **Parallel Writes**: Different task IDs can be claimed simultaneously
- **Reduced Contention**: 16x less contention than single-lock design
- **Scalable**: Can increase SHARD_COUNT for higher concurrency

### State Recovery Performance

| Operation | Performance |
|---|---|
| **save()** | ~5ms for 1000 claims (summary only) |
| **load()** | ~10ms for typical state file |
| **restore()** | ~2ms (logs only, no claim restoration) |
| **backup()** | ~15ms (file copy + prune) |

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
- **Shard count**: 16 (hardcoded, must be power of 2)
- **Approx. memory per claim**: ~64 bytes + string storage

## Thread Safety

All brain regions use `std.Thread.Mutex` for thread-safe operations:
- Basal Ganglia: Registry protected by mutex
- Reticular Formation: Event bus protected by mutex
- Locus Coeruleus: Stateless (no mutex needed)

## Testing Best Practices

### Test Flakiness Management

Timing-dependent tests can be flaky due to thread scheduling. Best practices:

1. **Avoid boundary condition tests**: Tests that sleep exactly to TTL boundaries are unreliable
   - Use margins (e.g., 75% of TTL for success case, >125% of TTL for fail case)
   - Example: Instead of sleeping 90ms then 20ms for 100ms TTL, sleep 75ms then 50ms

2. **Module Import Testing**: When testing modules that import other brain regions:
   - Use `zig build test-<module>` instead of `zig test src/brain/module.zig`
   - Direct `zig test` on modules with imports will fail because they need build system's module configuration
   - Add test steps in `build.zig` following the pattern of existing brain module tests

3. **Async Error Handling**: Functions returning `!void` must have errors handled in tests:
   - Use `catch {}` to discard errors when result is not important
   - Cannot use `_ = ` for error-returning functions (Zig 0.15 requires explicit error handling)

4. **Const vs Mutable**: Test functions like `deinit()` require mutable pointers:
   - Use `var processor` instead of `const processor` when calling methods that need mutation
   - This is a breaking change in Zig 0.15 - method signatures may require non-const self

5. **Error Union Comparison**: Cannot directly compare `!?T` to `null`:
   - Either unwrap with `try` first, OR
   - Use pattern matching, OR
   - Test specific error conditions with `expectError`

### Test Coverage

| Module | Tests | Status |
|---|---|---|
| basal_ganglia | 51 | PASS |
| basal_ganglia_lockfree | 63 | PASS |
| amygdala | 97 | PASS |
| amygdala_opt | 20 | PASS |
| alerts | 38 | PASS |
| reticular_formation | ~60 | PASS |
| locus_coeruleus | ~40 | PASS |

## References

- Academic: https://www.academia.edu/144897776/Trinity_Framework_Architecture
- zig-hslm: https://codeberg.org/gHashTag/zig-hslm
- GitHub: https://github.com/gHashTag/trinity

## License

MIT — See Trinity repository for full license text.
