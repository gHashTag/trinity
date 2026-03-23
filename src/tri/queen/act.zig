// Queen Act — Stage 5 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Import from Plan stage
pub const Plan = @import("plan.zig").Plan;
pub const PolicyDelta = @import("plan.zig").PolicyDelta;
pub const Evaluation = @import("evaluate.zig").Evaluation;
pub const Context = @import("observe.zig").Context;
pub const SensorsSnapshot = @import("observe.zig").SensorsSnapshot;

/// ═══════════════════════════════════════════════════════════════════════════════════
// RESULT OUTCOME — What happened after an action
/// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

/// Outcome of an action execution
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

/// Timing information for action execution
pub const Timing = struct {
    /// Start timestamp (unix nanos)
    start_ns: u64,
    /// End timestamp
    end_ns: u64,
    /// Duration in milliseconds
    duration_ms: u64,
};

/// Result of action execution
pub const Result = struct {
    /// Success/failure indicator
    success: bool,
    /// Error code (if failed)
    error: ?[]const u8,
    /// Timing information
    timing: Timing,
    /// Output data captured
    output: ?[]const u8,
    /// New sensor readings after action
    new_senses: SensorsSnapshot,
};

/// Full cycle result (all stages combined)
pub const CycleResult = struct {
    /// Context before action
    context: Context,
    /// Evaluation decision
    evaluation: Evaluation,
    /// Execution plan
    plan: Plan,
    /// Action result
    result: Result,
    /// Derived outcome
    outcome: Outcome,
};

/// ═════════════════════════════════════════════════════════════════════════════════════
// RESULT OUTCOME — What happened after an action
/// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════→ readCurrentSenses();

/// Execute action and capture result
pub fn act(plan: Plan) !Result {
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

    errdefer {
        // On error, rollback if we modified policy
        if (plan.rollback) |rollback| {
            rollbackPolicyChange(rollback) catch {};
        }
    };

    // Execute based on action type
    switch (plan.action) {
        .scale_up => {
            result = try executePolicyScale(plan.key, 1.1, plan.quality_score);
        },
        .scale_down => {
            result = try executePolicyScale(plan.key, 0.9, plan.quality_score);
        },
        .trigger => {
            result = try executeTrigger(plan.key);
        },
        .wait => {
            result.success = true;
            result.timing.end_ns = std.time.nanoTimestamp();
            result.timing.duration_ms = (result.timing.end_ns - result.timing.start_ns) / 1_000_000;
            result.output = "Wait complete";
            result.new_senses = try readCurrentSenses();
        },
    }

    return result;
}

/// Execute policy scaling action
fn executePolicyScale(key: []const u8, multiplier: f64, quality: f64) !Result {
    const start_ns = std.time.nanoTimestamp();

    // 1. Read current policy
    const file = try std.fs.cwd().openFile(".trinity/queen/policy.json", .{});
    defer file.close();

    // Read all file contents - Zig 0.15 requires max_bytes parameter
    const contents = file.readToEndAlloc(std.heap.page_allocator, 1024 * 1024) catch |err| {
        return Result{
            .success = false,
            .error = try std.fmt.allocPrint(std.heap.page_allocator, "Read failed: {s}", .{err}),
            .timing = Timing{ .start_ns = start_ns, .end_ns = std.time.nanoTimestamp(), .duration_ms = 0 },
            .output = null,
            .new_senses = undefined,
        };
    };
    };
    defer std.heap.page_allocator.free(contents);

    var policy = try std.json.parseFromSlice(PolicySnapshot, contents) catch PolicySnapshot{};

    // 2. Calculate new value
    const old_value = getPolicyValueFromPolicy(policy, key);
    const new_value_f64 = old_value.f64 * multiplier;

    // Apply clamps for safety
    const clamped_value = std.math.clamp(new_value_f64, 0.0, 10.0);

    // 3. Update policy
    if (std.mem.eql(u8, key, "kill_threshold")) {
        policy.kill_threshold = clamped_value;
    } else if (std.mem.eql(u8, key, "crash_rate_limit")) {
        policy.crash_rate_limit = clamped_value;
    }

    // 4. Write back to file
    const new_contents = try std.json.stringifyAlloc(std.heap.page_allocator, policy, .{ .whitespace = .indent });
    defer std.heap.page_allocator.free(new_contents);

    const write_file = try std.fs.cwd().createFile(".trinity/queen/policy.json", .{});
    defer write_file.close();

    try write_file.writeAll(new_contents);

    const end_ns = std.time.nanoTimestamp();

    return Result{
        .success = true,
        .error = null,
        .timing = Timing{
            .start_ns = start_ns,
            .end_ns = end_ns,
            .duration_ms = (end_ns - start_ns) / 1_000_000,
        },
        .output = try std.fmt.allocPrint(std.heap.page_allocator, "Scaled {s} by {d:.2}", .{key, multiplier}),
        .new_senses = try readCurrentSenses(),
    };
}

/// Read current senses for result capture
fn readCurrentSenses() !SensorsSnapshot {
    const file = std.fs.cwd().openFile(".trinity/queen/senses.json", .{}) catch {
        return SensorsSnapshot{};
    };
    defer file.close();

    // Read all file contents
    const contents = file.readToEndAlloc(std.heap.page_allocator) catch |err| {
        return SensorsSnapshot{};
    };
    defer std.heap.page_allocator.free(contents);

    return std.json.parseFromSlice(SensorsSnapshot, contents) catch SensorsSnapshot{};
}

/// Get policy value from PolicySnapshot
fn getPolicyValueFromPolicy(policy: PolicySnapshot, key: []const u8) union { bool: bool, f64: f64 } {
    if (std.mem.eql(u8, key, "kill_threshold")) return .{ .f64 = policy.kill_threshold };
    if (std.mem.eql(u8, key, "crash_rate_limit")) return .{ .f64 = policy.crash_rate_limit };
    if (std.mem.eql(u8, key, "byzantine_rate_limit")) return .{ .f64 = policy.byzantine_rate_limit };
    if (std.mem.eql(u8, key, "god_mode")) return .{ .bool = policy.god_mode };

    return .{ .f64 = 0.0 };
}

/// Rollback policy change (on error)
fn rollbackPolicyChange(rollback: Rollback) !void {
    // Implement rollback logic (simplified for now)
    _ = rollback;
}

/// Trigger a command execution
fn executeTrigger(command: []const u8) !Result {
    const start_ns = std.time.nanoTimestamp();

    // For now, just record the trigger
    const end_ns = std.time.nanoTimestamp();

    return Result{
        .success = true,
        .error = null,
        .timing = Timing{
            .start_ns = start_ns,
            .end_ns = end_ns,
            .duration_ms = (end_ns - start_ns) / 1_000_000,
        },
        .output = try std.fmt.allocPrint(std.heap.page_allocator, "Triggered: {s}", .{command}),
        .new_senses = try readCurrentSenses(),
    };
}

/// Full cycle: Observe → Evaluate → Plan → Act
pub fn runLotusCycle() !CycleResult {
    // 1. Observe
    const context = try observe(std.heap.page_allocator);

    // 2. Evaluate
    const evaluation = try evaluate(context);

    // 3. Plan
    const plan = try plan(evaluation, context.policy);

    // 4. Act
    const result = try act(plan);

    // 5. Derive outcome
    const outcome = deriveOutcome(result);

    return CycleResult{
        .context = context,
        .evaluation = evaluation,
        .plan = plan,
        .result = result,
        .outcome = outcome,
    };
}

/// Derive outcome from result
fn deriveOutcome(result: Result) Outcome {
    if (!result.success) return .failure_learned;
    if (result.timing.duration_ms < 100) return .success;
    return .partial;
}

test "act: scale_up produces valid result" {
    const plan = Plan{
        .action = .scale_up,
        .key = "kill_threshold",
        .quality_score = 0.7,
        .steps = &[_]Step{},
        .rollback = Rollback{
            .action = .scale_down,
            .key = "kill_threshold",
            .reason = "Test rollback",
        },
    };

    const result = try act(plan);

    try std.testing.expect(result.success == true);
    try std.testing.expect(result.timing.duration_ms >= 0);
}
