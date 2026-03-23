# Queen Lotus Cycle

> **Autonomous 5-Stage Improvement Loop**
> `φ² + 1/φ² = 3` | TRINITY

---

## Overview

Lotus Cycle is Queen's autonomous improvement mechanism — a continuous loop of **observation → memory formation → evaluation → planning → action**. Each iteration produces an `Episode` that becomes part of Queen's experience base.

**Philosophy**: Like a lotus growing from mud, Queen learns from every action, accumulating wisdom through structured episodes that inform future decisions.

---

## Episode Structure

Every completed Lotus Cycle iteration produces one `Episode` record:

```zig
pub const Episode = struct {
    /// Unique episode identifier (timestamp-based)
    id: u64,

    /// When this episode occurred
    timestamp: u64,

    /// Source: who/what triggered this cycle
    source: Source,

    /// Context: Queen's state before action
    context: Context,

    /// Action: what was decided/executed
    action: Action,

    /// Result: outcome of the action
    result: Result,

    /// Learning outcome: derived from result
    outcome: Outcome,
};

pub const Source = enum {
    /// Internal Lotus Cycle (self-triggered)
    lotus_cycle,
    /// External trigger (user command, webhook, alert)
    external,
    /// Scheduled (periodic check, watchdog)
    scheduled,
    /// Experience replay (from similar past episodes)
    experience_recall,
};

pub const Context = struct {
    /// Current policy state (rate limits, approvals)
    policy: PolicySnapshot,

    /// Sensor readings (build status, farm metrics, ouroboros score)
    senses: SensorsSnapshot,

    /// Similar episodes recalled from memory
    recalled_episodes: []const Episode,

    /// Active issues/tasks in queue
    active_issues: []const u64,
};

pub const Action = union(enum) {
    /// Set a policy parameter to specific value
    set: SetAction,
    /// Increase a rate limit level
    scale_up: ScaleAction,
    /// Decrease a rate limit level
    scale_down: ScaleAction,
    /// Trigger a command with parameters
    trigger: TriggerAction,
    /// Skip/no-op (wait state)
    wait: void,
};

pub const SetAction = struct {
    /// Policy key to modify
    key: []const u8,
    /// Value to set
    value: union {
        bool: bool,
        i64: i64,
        f64: f64,
        string: []const u8,
    },
};

pub const ScaleAction = struct {
    /// Policy key to scale
    key: []const u8,
    /// Multiplier for scaling (e.g., 2.0 = double, 0.5 = half)
    multiplier: f64,
    /// Optional max/min clamp values
    clamp: ?struct {
        max: f64,
        min: f64,
    },
};

pub const TriggerAction = struct {
    /// Command identifier (from command registry)
    command_id: u16,
    /// Parameters for the command
    params: []const u8,
    /// Target context (if applicable)
    target: ?[]const u8,
};

pub const Result = struct {
    /// Success/failure indicator
    success: bool,

    /// Error code (if failed)
    error: ?ErrorCode,

    /// Timing information
    timing: Timing,

    /// Output data captured
    output: ?[]const u8,

    /// New sensor readings after action
    new_senses: SensorsSnapshot,
};

pub const Timing = struct {
    /// Start timestamp (unix nanos)
    start_ns: u64,

    /// End timestamp
    end_ns: u64,

    /// Duration in milliseconds
    duration_ms: u64,
};

pub const Outcome = enum {
    /// Action succeeded as expected
    success,

    /// Succeeded with caveats (partial success)
    partial,

    /// Failed but lesson learned
    failure_learned,

    /// Failed with no clear lesson
    failure_unknown,

    /// Blocked by constraint (rate limit, approval)
    blocked,
};

/// Derived from (success + new_senses vs context.senses)
pub const Quality = struct {
    /// Did sensors improve? (e.g., dirty_files decreased, PPL improved)
    delta_improvement: bool,

    /// Estimated impact (0.0-1.0)
    impact_score: f64,

    /// Recommendation for next cycle
    next_recommendation: Recommendation,
};

pub const Recommendation = enum {
    /// Continue current approach
    continue,

    /// Increase rate limit
    scale_up,

    /// Decrease rate limit
    scale_down,

    /// Switch strategy
    pivot,

    /// Wait/monitor
    observe,

    /// Escalate to human
    escalate,
};
```

---

## The 5 Stages

### Stage 1: Observe

**Purpose**: Gather current state from sensors and external inputs.

**Inputs**:
- `senses.json` — real-time metrics (build status, farm PPL, ouroboros score, disk, etc.)
- `locus_state.json` — arousal/alert level
- External triggers (user commands, webhooks, scheduled events)

**Process**:
1. Read current sensor snapshot
2. Check for active alerts or blockers
3. Scan experience.json for similar past episodes (by tags, context)
4. Build `Context` struct

**Output**: `Context` snapshot

```zig
fn observe(allocator: Allocator) !Context {
    const senses = try readSenses();
    const locus = try readLocusState();
    const policy = try readPolicy();

    const similar = try recallSimilarEpisodes(
        allocator,
        senses,
        locus.alert_count > 0,
        .max_results: 5,
    );

    return Context{
        .policy = PolicySnapshot.from(policy),
        .senses = SensorsSnapshot.from(senses),
        .recalled_episodes = similar,
        .active_issues = try getActiveIssues(),
    };
}
```

---

### Stage 2: Record Episode

**Purpose**: Document the cycle attempt before taking action — ensures learnable trace.

**Process**:
1. Generate episode ID from timestamp
2. Serialize `Context` to episode
3. Allocate `Episode` with empty `action/result/outcome`
4. Write to `.trinity/queen/episodes.jsonl` (append-only)

**Format** (JSONL):
```json
{"id":1774259876,"timestamp":1774259876000000,"source":"lotus_cycle","context":{...},"action":null,"result":null,"outcome":null}
```

```zig
fn recordEpisode(allocator: Allocator, context: Context) !Episode {
    const episode = Episode{
        .id = std.time.nanoTimestamp(),
        .timestamp = std.time.nanoTimestamp(),
        .source = .lotus_cycle,
        .context = context,
        .action = undefined, // Filled after Stage 4
        .result = undefined, // Filled after Stage 5
        .outcome = undefined, // Filled after Stage 5
    };

    const line = try std.json.stringifyAlloc(allocator, episode, .{});
    defer allocator.free(line);

    const file = try std.fs.appendFile(".trinity/queen/episodes.jsonl", .{});
    defer file.close();
    try file.writeAll(line);
    try file.writeAll("\n");

    return episode;
}
```

**Note**: JSONL used for append-only semantics — no locking needed for concurrent cycles.

---

### Stage 3: Evaluate

**Purpose**: Analyze context to determine optimal action.

**Process**:
1. Compare current state against `recalled_episodes`
2. Check policy constraints (rate limits, approval flags)
3. Calculate quality scores for candidate actions
4. Select best action based on heuristics

**Heuristics**:
- **Safety first**: Never escalate if alert count is low
- **Conservation**: Scale down if high frequency without improvement
- **Escalation**: Require 3+ failures before human escalation
- **Experience bias**: Prefer actions that succeeded in similar contexts

```zig
fn evaluate(context: Context) Evaluation !void {
    const candidates = try generateCandidateActions(context);

    for (candidates) |*candidate| {
        candidate.quality = try scoreAction(candidate, context);
    }

    // Sort by quality score (descending)
    std.sort.insertionSort(candidates, {}, struct {
        fn less(_: void, a: Candidate, b: Candidate) bool {
            return a.quality.impact_score > b.quality.impact_score;
        }
    });

    context.best_action = candidates[0].action;
    context.evaluation = candidates[0];
}
```

**Output**: `Evaluation` with ranked candidates and selected action

---

### Stage 4: Plan

**Purpose**: Convert selected action into executable plan.

**Process**:
1. Validate action against policy (`god_mode`, `require_human_approval`)
2. Check rate limits — if exceeded, choose alternative or queue
3. Build execution plan (substeps, dependencies, rollback)
4. Generate `PolicyDelta` if action modifies policy

**PolicyDelta Structure**:

```zig
pub const PolicyDelta = struct {
    /// What changed
    operation: PolicyOperation,

    /// Key affected
    key: []const u8,

    /// Previous value
    old_value: ?union { bool: bool, i64: i64, f64: f64, string: []const u8 },

    /// New value
    new_value: union { bool: bool, i64: i64, f64: f64, string: []const u8 },

    /// Reason for change
    reason: []const u8,

    /// Estimated quality delta (-1.0 to 1.0)
    expected_quality_delta: f64,
};

pub const PolicyOperation = enum {
    /// Set key to value
    set,

    /// Multiply value by factor (>1.0 = up, <1.0 = down)
    scale,

    /// Toggle boolean (flip)
    toggle,

    /// Increment numeric value
    increment,

    /// Reset to default
    reset,
};
```

**Rate Limit Keys** (examples):

| Key | Meaning | Range |
|------|----------|--------|
| `kill_threshold` | Farm: PPL threshold for recycling | 0.0 - 10.0 |
| `crash_rate_limit` | Farm: Max allowable crash rate | 0.0 - 1.0 |
| `byzantine_rate_limit` | Farm: Max byzantine worker ratio | 0.0 - 1.0 |
| `hslm_optimizer_steps` | Training: Optimization frequency | 100 - 100000 |

**Example Plan**:
```zig
const plan = Plan{
    .action = .{ .scale_up = ScaleAction{
        .key = "kill_threshold",
        .multiplier = 1.1,
        .clamp = .{ .max = 5.0, .min = 2.0 },
    }},
    .substeps = &[_]Substep{
        .{ .name = "Read current farm status" },
        .{ .name = "Calculate new threshold" },
        .{ .name = "Update policy.json" },
        .{ .name = "Validate change" },
    },
    .rollback = .{ .action = .scale_down, .key = "kill_threshold" },
};
```

---

### Stage 5: Act

**Purpose**: Execute the planned action and capture result.

**Process**:
1. Lock episode for update (read-modify-write pattern)
2. Execute action (command, policy change, external call)
3. Capture timing and output
4. Read new sensor state
5. Update episode with `result` and `outcome`
6. Append `PolicyDelta` to policy history

**Execution Patterns**:

| Action Type | Handler |
|------------|----------|
| `.set` / `.scale_up/down` | `src/tri/queen/policy.zig` |
| `.trigger` | Command registry → tri CLI execution |
| `.wait` | No-op, schedule next observe |

```zig
fn act(allocator: Allocator, episode: *Episode, plan: Plan) !Result {
    const start_ns = std.time.nanoTimestamp();

    var result = Result{
        .success = false,
        .error = null,
        .timing = Timing{
            .start_ns = start_ns,
            .end_ns = 0,
            .duration_ms = 0,
        },
        .output = null,
        .new_senses = undefined,
    };

    // Execute based on action type
    switch (plan.action) {
        .scale_up, .scale_down => {
            result = try executePolicyDelta(plan.action, plan.substeps);
        },
        .trigger => |trigger| {
            result = try executeCommand(trigger.command_id, trigger.params, trigger.target);
        },
        .wait => {
            result.success = true;
            result.timing.end_ns = std.time.nanoTimestamp();
            result.timing.duration_ms = (result.timing.end_ns - result.timing.start_ns) / 1_000_000;
        },
    }

    // Capture post-action sensor state
    result.new_senses = try readSenses();
    result.timing.end_ns = std.time.nanoTimestamp();
    result.timing.duration_ms = (result.timing.end_ns - result.timing.start_ns) / 1_000_000;

    // Derive outcome from result
    episode.outcome = deriveOutcome(result);

    return result;
}
```

**After Act**:
1. Update `episodes.jsonl` entry with full `result` and `outcome`
2. If `PolicyDelta` exists, append to `policy_history.jsonl`
3. Trigger Stage 1 again (continuous loop)

---

## Experience Recall

Lotus Cycle uses `experience.jsonl` for learning from past actions.

**Matching Heuristics**:
- **Tag overlap**: Jaccard similarity on `tags` arrays
- **Context similarity**: Compare `policy` state and `senses` snapshots
- **Temporal recency**: Boost score for episodes < 7 days old
- **Success bias**: Prefer episodes with `outcome: .success` or `.partial`

**Recall Query**:
```zig
fn recallSimilarEpisodes(
    allocator: Allocator,
    current_context: Context,
    options: RecallOptions,
) ![]Episode {
    const all_episodes = try loadAllEpisodes();

    var candidates = std.ArrayList(Episode).init(allocator);
    defer candidates.deinit();

    for (all_episodes) |episode| {
        const score = try calculateSimilarity(episode, current_context, options);
        if (score > 0.3) { // Threshold for "relevant"
            try candidates.append(episode);
        }
    }

    // Sort by similarity + recency bias
    std.sort.insertionSort(candidates.items, {}, similaritySortFn);

    return try candidates.toOwnedSlice();
}
```

---

## Policy Management

`policy.json` stores rate limits and constraints that govern action selection.

**Operations**:
- **Set**: Direct assignment (`KILL_THRESHOLD = 4.0`)
- **Scale**: Multiplicative (`kill_threshold *= 0.9`)
- **Toggle**: Flip boolean (`god_mode = !god_mode`)
- **Reset**: Restore defaults

**Safety Checks**:
- `require_human_approval = true` → block `scale_up` above level 2
- `god_mode = true` → bypass all rate limits
- Rate limit cooldowns prevent rapid oscillation

```zig
pub fn applyPolicyDelta(delta: PolicyDelta, policy: *Policy) !void {
    const current_value = try policy.get(delta.key);
    const old_value = current_value;

    switch (delta.operation) {
        .set => {
            policy.set(delta.key, delta.new_value);
        },
        .scale => {
            const scaled = current_value.asNumber() * delta.multiplier;
            if (delta.clamp) |clamp| {
                const clamped = std.math.clamp(scaled, clamp.min, clamp.max);
                policy.set(delta.key, clamped);
            } else {
                policy.set(delta.key, scaled);
            }
        },
        // ... other operations
    }

    try savePolicy(policy);
    try logPolicyChange(delta, old_value);
}
```

---

## Cycle Completion

A full Lotus Cycle completes when all 5 stages have executed and the episode is fully recorded.

**Success Criteria**:
- ✅ `Episode.outcome` is not `null`
- ✅ `policy.json` updated if action modified policy
- ✅ `episodes.jsonl` entry is complete
- ✅ Next cycle triggered within 60 seconds (unless in `wait` state)

**Failure Recovery**:
- If Stage 5 fails, set `outcome = .failure_learned` with `error`
- Rollback `PolicyDelta` if applied
- Schedule next Observe with higher alert level

---

## Integration Points

| Module | Integration |
|--------|-------------|
| `src/tri/queen/` | Lotus Cycle implementation |
| `src/tri/farm/` | Train status, recycling actions |
| `src/tri/cloud/` | Container spawn/kill actions |
| `src/tri/github_integration.zig` | Issue creation/comments |
| `src/tri/command_registry.zig` | Command execution |
| `.trinity/queen/*.json` | State persistence |

---

## Future Enhancements

- **Episode clustering**: Group similar episodes into "scenarios" for pattern mining
- **Temporal decay**: Weight older episodes less in similarity scoring
- **Multi-arm bandit**: Try multiple actions in parallel for faster learning
- **Causal tracing**: Link episodes via `result` → `next_episode.context`
- **Confidence intervals**: Track uncertainty in quality estimates

---

> **TRINITY** | φ² + 1/φ² = 3
