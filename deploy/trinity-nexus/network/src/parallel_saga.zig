// Trinity Storage Network v2.5 — Parallel Step Execution
// Independent saga steps run concurrently via dependency graph
// Steps with no dependencies execute in parallel; dependent steps wait
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");
const saga_mod = @import("saga_coordinator.zig");

/// Maximum number of dependencies per step
pub const MAX_DEPS_PER_STEP: u32 = 8;
/// Maximum number of steps per parallel saga
pub const MAX_STEPS: u32 = 32;
/// Maximum number of execution levels (depth of dependency graph)
pub const MAX_LEVELS: u32 = 16;

/// Phase of the parallel saga
pub const ParallelSagaPhase = enum(u8) {
    created, // Steps and deps defined
    executing, // Forward steps in progress (level by level)
    compensating, // Rolling back completed steps
    completed, // All steps succeeded
    compensated, // All compensations succeeded
    partially_compensated, // Some compensations failed
    failed, // Unrecoverable

    pub fn label(self: ParallelSagaPhase) []const u8 {
        return switch (self) {
            .created => "CREATED",
            .executing => "EXECUTING",
            .compensating => "COMPENSATING",
            .completed => "COMPLETED",
            .compensated => "COMPENSATED",
            .partially_compensated => "PARTIALLY_COMPENSATED",
            .failed => "FAILED",
        };
    }
};

/// A step in the parallel saga with dependency information
pub const ParallelStep = struct {
    step_index: u32,
    action: saga_mod.StepAction,
    target_shard: [32]u8,
    target_node: [32]u8,
    phase: saga_mod.StepPhase,
    started_at: i64,
    completed_at: i64,
    compensation_retries: u32,
    error_code: u32,
    // Dependency tracking
    dep_count: u32, // Number of dependencies
    deps: [MAX_DEPS_PER_STEP]u32, // Indices of steps this depends on
    level: u32, // Computed execution level (0 = root, no deps)
};

/// Configuration for parallel saga engine
pub const ParallelSagaConfig = struct {
    max_steps_per_saga: u32 = MAX_STEPS,
    max_concurrent_sagas: u32 = 512,
    max_deps_per_step: u32 = MAX_DEPS_PER_STEP,
    max_levels: u32 = MAX_LEVELS,
    step_timeout_ms: i64 = 60_000,
    max_saga_duration_ms: i64 = 300_000,
    max_compensation_retries: u32 = 3,
};

/// A parallel saga entry with all steps and dependency graph
pub const ParallelSagaEntry = struct {
    saga_id: u64,
    coordinator_id: [32]u8,
    phase: ParallelSagaPhase,
    steps: std.ArrayList(ParallelStep),
    created_at: i64,
    started_at: i64,
    completed_at: i64,
    current_level: u32, // Currently executing level
    max_level: u32, // Maximum level in dependency graph
    steps_succeeded: u32,
    steps_running: u32, // Steps currently executing in parallel
    steps_compensated: u32,
    compensation_failures: u32,
};

/// Result of a parallel saga execution
pub const ParallelSagaResult = struct {
    saga_id: u64,
    success: bool,
    phase: ParallelSagaPhase,
    steps_total: u32,
    steps_succeeded: u32,
    steps_compensated: u32,
    compensation_failures: u32,
    duration_ms: i64,
    levels_executed: u32,
    max_parallelism: u32, // Most steps running at once in any level
};

/// Execution level info — steps grouped by dependency depth
pub const LevelInfo = struct {
    level: u32,
    step_count: u32,
    step_indices: [MAX_STEPS]u32,
};

/// Statistics tracked by the parallel saga engine
pub const ParallelSagaStats = struct {
    total_sagas: u64,
    completed_sagas: u64,
    compensated_sagas: u64,
    failed_sagas: u64,
    total_steps: u64,
    steps_succeeded: u64,
    steps_compensated: u64,
    compensation_failures: u64,
    total_levels_executed: u64,
    max_parallelism_seen: u32, // Highest parallelism across all sagas
    avg_saga_duration_ms: i64,
    avg_steps_per_saga: f64,
    avg_parallelism: f64,
    duration_sum: i64,
    steps_sum: u64,
    parallelism_sum: u64,
};

/// Parallel Saga Engine — manages saga execution with dependency-based parallelism
pub const ParallelSagaEngine = struct {
    allocator: std.mem.Allocator,
    config: ParallelSagaConfig,
    sagas: std.AutoHashMap(u64, ParallelSagaEntry),
    next_saga_id: u64,
    stats: ParallelSagaStats,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: ParallelSagaConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .sagas = std.AutoHashMap(u64, ParallelSagaEntry).init(allocator),
            .next_saga_id = 1,
            .stats = std.mem.zeroes(ParallelSagaStats),
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.sagas.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.steps.deinit(self.allocator);
        }
        self.sagas.deinit();
    }

    /// Create a new parallel saga
    pub fn createSaga(self: *Self, coordinator_id: [32]u8, timestamp: i64) (std.mem.Allocator.Error || error{TooManySagas})!u64 {
        if (self.sagas.count() >= self.config.max_concurrent_sagas) return error.TooManySagas;

        const saga_id = self.next_saga_id;
        self.next_saga_id += 1;

        try self.sagas.put(saga_id, .{
            .saga_id = saga_id,
            .coordinator_id = coordinator_id,
            .phase = .created,
            .steps = .empty,
            .created_at = timestamp,
            .started_at = 0,
            .completed_at = 0,
            .current_level = 0,
            .max_level = 0,
            .steps_succeeded = 0,
            .steps_running = 0,
            .steps_compensated = 0,
            .compensation_failures = 0,
        });

        self.stats.total_sagas += 1;
        return saga_id;
    }

    /// Add a step with no dependencies (level 0 — runs immediately)
    pub fn addStep(
        self: *Self,
        saga_id: u64,
        action: saga_mod.StepAction,
        target_shard: [32]u8,
        target_node: [32]u8,
    ) error{ SagaNotFound, InvalidPhase, TooManySteps }!u32 {
        return self.addStepWithDeps(saga_id, action, target_shard, target_node, &.{});
    }

    /// Add a step with explicit dependencies on other step indices
    pub fn addStepWithDeps(
        self: *Self,
        saga_id: u64,
        action: saga_mod.StepAction,
        target_shard: [32]u8,
        target_node: [32]u8,
        deps: []const u32,
    ) error{ SagaNotFound, InvalidPhase, TooManySteps }!u32 {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .created) return error.InvalidPhase;
        if (entry.steps.items.len >= self.config.max_steps_per_saga) return error.TooManySteps;
        if (deps.len > self.config.max_deps_per_step) return error.TooManySteps;

        const step_index: u32 = @intCast(entry.steps.items.len);

        // Validate all deps refer to existing steps
        for (deps) |dep| {
            if (dep >= step_index) return error.TooManySteps; // forward ref
        }

        var step_deps = [_]u32{0} ** MAX_DEPS_PER_STEP;
        for (deps, 0..) |dep, i| {
            step_deps[i] = dep;
        }

        // Compute level: max(dep levels) + 1, or 0 if no deps
        var level: u32 = 0;
        if (deps.len > 0) {
            var max_dep_level: u32 = 0;
            for (deps) |dep| {
                const dep_level = entry.steps.items[dep].level;
                if (dep_level > max_dep_level) max_dep_level = dep_level;
            }
            level = max_dep_level + 1;
        }

        if (level > entry.max_level) entry.max_level = level;

        entry.steps.append(self.allocator, .{
            .step_index = step_index,
            .action = action,
            .target_shard = target_shard,
            .target_node = target_node,
            .phase = .pending,
            .started_at = 0,
            .completed_at = 0,
            .compensation_retries = 0,
            .error_code = 0,
            .dep_count = @intCast(deps.len),
            .deps = step_deps,
            .level = level,
        }) catch return error.TooManySteps;

        self.stats.total_steps += 1;
        return step_index;
    }

    /// Get information about steps at a given level
    pub fn getLevelInfo(self: *const Self, saga_id: u64, level: u32) error{SagaNotFound}!LevelInfo {
        const entry = self.sagas.get(saga_id) orelse return error.SagaNotFound;
        var info = LevelInfo{
            .level = level,
            .step_count = 0,
            .step_indices = [_]u32{0} ** MAX_STEPS,
        };
        for (entry.steps.items) |step| {
            if (step.level == level) {
                info.step_indices[info.step_count] = step.step_index;
                info.step_count += 1;
            }
        }
        return info;
    }

    /// Begin executing the parallel saga — starts all level-0 steps concurrently
    pub fn execute(self: *Self, saga_id: u64, timestamp: i64) error{ SagaNotFound, InvalidPhase, NoSteps }!u32 {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .created) return error.InvalidPhase;
        if (entry.steps.items.len == 0) return error.NoSteps;

        entry.phase = .executing;
        entry.started_at = timestamp;
        entry.current_level = 0;

        // Start all level-0 steps in parallel
        var started: u32 = 0;
        for (entry.steps.items) |*step| {
            if (step.level == 0) {
                step.phase = .running;
                step.started_at = timestamp;
                started += 1;
            }
        }
        entry.steps_running = started;

        // Track max parallelism
        if (started > self.stats.max_parallelism_seen) {
            self.stats.max_parallelism_seen = started;
        }

        return started; // Number of steps started in parallel
    }

    /// Report that a step succeeded — may trigger next level if all deps satisfied
    pub fn stepSucceeded(self: *Self, saga_id: u64, step_index: u32, timestamp: i64) error{ SagaNotFound, InvalidPhase, InvalidStep }!?ParallelSagaResult {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .executing) return error.InvalidPhase;
        if (step_index >= entry.steps.items.len) return error.InvalidStep;

        var step = &entry.steps.items[step_index];
        if (step.phase != .running) return error.InvalidStep;

        step.phase = .succeeded;
        step.completed_at = timestamp;
        entry.steps_succeeded += 1;
        if (entry.steps_running > 0) entry.steps_running -= 1;
        self.stats.steps_succeeded += 1;

        // Check if all steps are done
        if (entry.steps_succeeded == @as(u32, @intCast(entry.steps.items.len))) {
            entry.phase = .completed;
            entry.completed_at = timestamp;
            self.stats.completed_sagas += 1;
            const duration = timestamp - entry.started_at;
            const max_p = self.computeMaxParallelism(entry);
            self.updateDurationStats(duration, @intCast(entry.steps.items.len), max_p);
            return .{
                .saga_id = saga_id,
                .success = true,
                .phase = .completed,
                .steps_total = @intCast(entry.steps.items.len),
                .steps_succeeded = entry.steps_succeeded,
                .steps_compensated = 0,
                .compensation_failures = 0,
                .duration_ms = duration,
                .levels_executed = entry.max_level + 1,
                .max_parallelism = max_p,
            };
        }

        // Check if any new steps can be started (their deps are all satisfied)
        const newly_started = self.startReadySteps(entry, timestamp);
        _ = newly_started;

        return null;
    }

    /// Report that a step failed — triggers compensation of all succeeded steps
    pub fn stepFailed(self: *Self, saga_id: u64, step_index: u32, error_code: u32, timestamp: i64) error{ SagaNotFound, InvalidPhase, InvalidStep }!void {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .executing) return error.InvalidPhase;
        if (step_index >= entry.steps.items.len) return error.InvalidStep;

        var step = &entry.steps.items[step_index];
        if (step.phase != .running) return error.InvalidStep;

        step.phase = .failed;
        step.error_code = error_code;
        step.completed_at = timestamp;
        if (entry.steps_running > 0) entry.steps_running -= 1;

        // Cancel all other running steps
        for (entry.steps.items) |*s| {
            if (s.phase == .running) {
                s.phase = .failed;
                s.error_code = 499; // Cascade cancel
                s.completed_at = timestamp;
                if (entry.steps_running > 0) entry.steps_running -= 1;
            }
        }

        // Transition to compensating
        entry.phase = .compensating;
        self.initiateCompensation(entry, timestamp);
    }

    /// Check if pending steps have all deps satisfied and start them
    fn startReadySteps(self: *Self, entry: *ParallelSagaEntry, timestamp: i64) u32 {
        var started: u32 = 0;
        for (entry.steps.items) |*step| {
            if (step.phase != .pending) continue;

            // Check if all deps are succeeded
            var all_deps_met = true;
            for (0..step.dep_count) |d| {
                const dep_idx = step.deps[d];
                if (entry.steps.items[dep_idx].phase != .succeeded) {
                    all_deps_met = false;
                    break;
                }
            }

            if (all_deps_met) {
                step.phase = .running;
                step.started_at = timestamp;
                entry.steps_running += 1;
                started += 1;
            }
        }

        // Update max parallelism tracking
        if (entry.steps_running > self.stats.max_parallelism_seen) {
            self.stats.max_parallelism_seen = entry.steps_running;
        }

        return started;
    }

    /// Initiate compensation of all succeeded steps (reverse level order)
    fn initiateCompensation(self: *Self, entry: *ParallelSagaEntry, timestamp: i64) void {
        _ = self;
        // Mark all succeeded steps as compensating
        // They will be processed in reverse level order by the caller
        for (entry.steps.items) |*step| {
            if (step.phase == .succeeded) {
                step.phase = .compensating;
                step.started_at = timestamp;
            }
        }
    }

    /// Report that a compensation succeeded for a step
    pub fn compensationSucceeded(self: *Self, saga_id: u64, step_index: u32, timestamp: i64) error{ SagaNotFound, InvalidPhase, InvalidStep }!?ParallelSagaResult {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .compensating) return error.InvalidPhase;
        if (step_index >= entry.steps.items.len) return error.InvalidStep;

        var step = &entry.steps.items[step_index];
        if (step.phase != .compensating) return error.InvalidStep;

        step.phase = .compensated;
        step.completed_at = timestamp;
        entry.steps_compensated += 1;
        self.stats.steps_compensated += 1;

        return self.checkCompensationComplete(entry, saga_id, timestamp);
    }

    /// Report that a compensation failed for a step
    pub fn compensationFailed(self: *Self, saga_id: u64, step_index: u32, timestamp: i64) error{ SagaNotFound, InvalidPhase, InvalidStep }!?ParallelSagaResult {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .compensating) return error.InvalidPhase;
        if (step_index >= entry.steps.items.len) return error.InvalidStep;

        var step = &entry.steps.items[step_index];
        if (step.phase != .compensating) return error.InvalidStep;

        step.compensation_retries += 1;

        if (step.compensation_retries >= self.config.max_compensation_retries) {
            step.phase = .compensation_failed;
            step.completed_at = timestamp;
            entry.compensation_failures += 1;
            self.stats.compensation_failures += 1;
            return self.checkCompensationComplete(entry, saga_id, timestamp);
        }

        // Retry
        step.started_at = timestamp;
        return null;
    }

    /// Check if all compensations are resolved
    fn checkCompensationComplete(self: *Self, entry: *ParallelSagaEntry, saga_id: u64, timestamp: i64) ?ParallelSagaResult {
        var pending: u32 = 0;
        for (entry.steps.items) |step| {
            if (step.phase == .compensating) pending += 1;
        }
        if (pending > 0) return null;

        entry.completed_at = timestamp;
        const duration = timestamp - entry.started_at;
        const max_p = self.computeMaxParallelism(entry);

        if (entry.compensation_failures > 0) {
            entry.phase = .partially_compensated;
            self.stats.failed_sagas += 1;
        } else {
            entry.phase = .compensated;
            self.stats.compensated_sagas += 1;
        }

        self.updateDurationStats(duration, @intCast(entry.steps.items.len), max_p);

        return .{
            .saga_id = saga_id,
            .success = false,
            .phase = entry.phase,
            .steps_total = @intCast(entry.steps.items.len),
            .steps_succeeded = entry.steps_succeeded,
            .steps_compensated = entry.steps_compensated,
            .compensation_failures = entry.compensation_failures,
            .duration_ms = duration,
            .levels_executed = entry.current_level + 1,
            .max_parallelism = max_p,
        };
    }

    /// Check for timed-out sagas and trigger compensation
    pub fn checkTimeouts(self: *Self, current_time: i64) u32 {
        var timed_out: u32 = 0;
        var it = self.sagas.iterator();
        while (it.next()) |kv| {
            const entry = kv.value_ptr;
            if (entry.phase == .executing) {
                const elapsed = current_time - entry.started_at;
                if (elapsed > self.config.max_saga_duration_ms) {
                    entry.phase = .compensating;
                    for (entry.steps.items) |*step| {
                        if (step.phase == .running) {
                            step.phase = .failed;
                            step.error_code = 408;
                            step.completed_at = current_time;
                        }
                    }
                    entry.steps_running = 0;
                    self.initiateCompensation(entry, current_time);
                    timed_out += 1;
                }
            }
        }
        return timed_out;
    }

    /// Abort a saga
    pub fn abortSaga(self: *Self, saga_id: u64, timestamp: i64) error{ SagaNotFound, InvalidPhase }!void {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .executing and entry.phase != .created) return error.InvalidPhase;

        if (entry.phase == .created) {
            entry.phase = .compensated;
            entry.completed_at = timestamp;
            self.stats.compensated_sagas += 1;
            return;
        }

        entry.phase = .compensating;
        for (entry.steps.items) |*step| {
            if (step.phase == .running) {
                step.phase = .failed;
                step.error_code = 499;
                step.completed_at = timestamp;
            }
        }
        entry.steps_running = 0;
        self.initiateCompensation(entry, timestamp);
    }

    /// Compute maximum parallelism (largest number of steps at any single level)
    fn computeMaxParallelism(self: *const Self, entry: *const ParallelSagaEntry) u32 {
        _ = self;
        var max_p: u32 = 0;
        for (0..entry.max_level + 1) |lvl| {
            var count: u32 = 0;
            for (entry.steps.items) |step| {
                if (step.level == @as(u32, @intCast(lvl))) count += 1;
            }
            if (count > max_p) max_p = count;
        }
        return max_p;
    }

    /// Update running averages
    fn updateDurationStats(self: *Self, duration_ms: i64, step_count: u32, max_parallelism: u32) void {
        const finished = self.stats.completed_sagas + self.stats.compensated_sagas + self.stats.failed_sagas;
        self.stats.duration_sum += duration_ms;
        self.stats.steps_sum += step_count;
        self.stats.parallelism_sum += max_parallelism;
        self.stats.total_levels_executed += 1;
        if (finished > 0) {
            self.stats.avg_saga_duration_ms = @divTrunc(self.stats.duration_sum, @as(i64, @intCast(finished)));
            self.stats.avg_steps_per_saga = @as(f64, @floatFromInt(self.stats.steps_sum)) / @as(f64, @floatFromInt(finished));
            self.stats.avg_parallelism = @as(f64, @floatFromInt(self.stats.parallelism_sum)) / @as(f64, @floatFromInt(finished));
        }
    }

    /// Get saga details
    pub fn getSaga(self: *const Self, saga_id: u64) ?ParallelSagaEntry {
        return self.sagas.get(saga_id);
    }

    pub fn getStats(self: *const Self) ParallelSagaStats {
        return self.stats;
    }
};

// ============================================================
// Unit Tests
// ============================================================

test "parallel saga — create and add steps with deps" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const saga_id = try engine.createSaga(cid, 1000);

    const shard1 = [_]u8{0x01} ** 32;
    const shard2 = [_]u8{0x02} ** 32;
    const node1 = [_]u8{0xB1} ** 32;
    const node2 = [_]u8{0xB2} ** 32;

    // Step 0: no deps (level 0)
    const s0 = try engine.addStep(saga_id, .shard_write, shard1, node1);
    // Step 1: no deps (level 0) — runs in parallel with step 0
    const s1 = try engine.addStep(saga_id, .shard_write, shard2, node2);
    // Step 2: depends on both step 0 and step 1 (level 1)
    const s2 = try engine.addStepWithDeps(saga_id, .lock_acquire, shard1, node1, &.{ s0, s1 });

    try std.testing.expectEqual(@as(u32, 0), s0);
    try std.testing.expectEqual(@as(u32, 1), s1);
    try std.testing.expectEqual(@as(u32, 2), s2);

    const saga = engine.getSaga(saga_id).?;
    try std.testing.expectEqual(ParallelSagaPhase.created, saga.phase);
    try std.testing.expectEqual(@as(usize, 3), saga.steps.items.len);
    try std.testing.expectEqual(@as(u32, 0), saga.steps.items[0].level);
    try std.testing.expectEqual(@as(u32, 0), saga.steps.items[1].level);
    try std.testing.expectEqual(@as(u32, 1), saga.steps.items[2].level);
    try std.testing.expectEqual(@as(u32, 1), saga.max_level);
}

test "parallel saga — level info" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;
    const saga_id = try engine.createSaga(cid, 1000);

    // 3 steps at level 0, 1 at level 1
    const s0 = try engine.addStep(saga_id, .shard_write, shard, node);
    _ = try engine.addStep(saga_id, .shard_write, shard, node);
    _ = try engine.addStep(saga_id, .shard_write, shard, node);
    _ = try engine.addStepWithDeps(saga_id, .lock_acquire, shard, node, &.{s0});

    const level0 = try engine.getLevelInfo(saga_id, 0);
    try std.testing.expectEqual(@as(u32, 3), level0.step_count);

    const level1 = try engine.getLevelInfo(saga_id, 1);
    try std.testing.expectEqual(@as(u32, 1), level1.step_count);
}

test "parallel saga — execute starts all level-0 steps" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;
    const saga_id = try engine.createSaga(cid, 1000);

    const s0 = try engine.addStep(saga_id, .shard_write, shard, node);
    _ = try engine.addStep(saga_id, .shard_write, shard, node);
    _ = try engine.addStepWithDeps(saga_id, .lock_acquire, shard, node, &.{s0});

    const started = try engine.execute(saga_id, 2000);
    try std.testing.expectEqual(@as(u32, 2), started); // 2 level-0 steps

    const saga = engine.getSaga(saga_id).?;
    try std.testing.expectEqual(ParallelSagaPhase.executing, saga.phase);
    try std.testing.expectEqual(saga_mod.StepPhase.running, saga.steps.items[0].phase);
    try std.testing.expectEqual(saga_mod.StepPhase.running, saga.steps.items[1].phase);
    try std.testing.expectEqual(saga_mod.StepPhase.pending, saga.steps.items[2].phase); // waiting
}

test "parallel saga — full parallel success (diamond pattern)" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;
    const saga_id = try engine.createSaga(cid, 1000);

    // Diamond: step 0 → (step 1, step 2) → step 3
    const s0 = try engine.addStep(saga_id, .shard_write, shard, node); // level 0
    const s1 = try engine.addStepWithDeps(saga_id, .lock_acquire, shard, node, &.{s0}); // level 1
    const s2 = try engine.addStepWithDeps(saga_id, .stake_lock, shard, node, &.{s0}); // level 1
    _ = try engine.addStepWithDeps(saga_id, .escrow_create, shard, node, &.{ s1, s2 }); // level 2

    // Level 0: step 0
    const started = try engine.execute(saga_id, 2000);
    try std.testing.expectEqual(@as(u32, 1), started);

    // Step 0 succeeds → should start steps 1 and 2 (both at level 1)
    const r0 = try engine.stepSucceeded(saga_id, 0, 2100);
    try std.testing.expect(r0 == null);

    const saga1 = engine.getSaga(saga_id).?;
    try std.testing.expectEqual(saga_mod.StepPhase.running, saga1.steps.items[1].phase);
    try std.testing.expectEqual(saga_mod.StepPhase.running, saga1.steps.items[2].phase);
    try std.testing.expectEqual(saga_mod.StepPhase.pending, saga1.steps.items[3].phase);

    // Steps 1 and 2 succeed (parallel) → should start step 3
    const r1 = try engine.stepSucceeded(saga_id, 1, 2200);
    try std.testing.expect(r1 == null);
    const r2 = try engine.stepSucceeded(saga_id, 2, 2200);
    try std.testing.expect(r2 == null);

    const saga2 = engine.getSaga(saga_id).?;
    try std.testing.expectEqual(saga_mod.StepPhase.running, saga2.steps.items[3].phase);

    // Step 3 succeeds → saga completes
    const r3 = try engine.stepSucceeded(saga_id, 3, 2300);
    try std.testing.expect(r3 != null);
    try std.testing.expect(r3.?.success);
    try std.testing.expectEqual(ParallelSagaPhase.completed, r3.?.phase);
    try std.testing.expectEqual(@as(u32, 4), r3.?.steps_succeeded);
    try std.testing.expectEqual(@as(u32, 3), r3.?.levels_executed);
    try std.testing.expectEqual(@as(u32, 2), r3.?.max_parallelism); // level 1 had 2 steps
}

test "parallel saga — all steps at level 0 (fully parallel)" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;
    const saga_id = try engine.createSaga(cid, 1000);

    // 5 independent steps — all level 0
    for (0..5) |_| {
        _ = try engine.addStep(saga_id, .shard_write, shard, node);
    }

    const started = try engine.execute(saga_id, 2000);
    try std.testing.expectEqual(@as(u32, 5), started);

    // Complete all 5 in "parallel"
    for (0..4) |i| {
        const r = try engine.stepSucceeded(saga_id, @intCast(i), 2100);
        try std.testing.expect(r == null);
    }
    const rfinal = try engine.stepSucceeded(saga_id, 4, 2100);
    try std.testing.expect(rfinal != null);
    try std.testing.expect(rfinal.?.success);
    try std.testing.expectEqual(@as(u32, 5), rfinal.?.max_parallelism);
    try std.testing.expectEqual(@as(u32, 1), rfinal.?.levels_executed);
}

test "parallel saga — failure triggers compensation of all succeeded" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;
    const saga_id = try engine.createSaga(cid, 1000);

    // 3 parallel steps at level 0
    _ = try engine.addStep(saga_id, .shard_write, shard, node);
    _ = try engine.addStep(saga_id, .shard_write, shard, node);
    _ = try engine.addStep(saga_id, .shard_write, shard, node);

    _ = try engine.execute(saga_id, 2000);

    // Step 0 and 1 succeed, step 2 fails
    _ = try engine.stepSucceeded(saga_id, 0, 2100);
    _ = try engine.stepSucceeded(saga_id, 1, 2100);
    try engine.stepFailed(saga_id, 2, 500, 2200);

    const saga = engine.getSaga(saga_id).?;
    try std.testing.expectEqual(ParallelSagaPhase.compensating, saga.phase);
    try std.testing.expectEqual(saga_mod.StepPhase.compensating, saga.steps.items[0].phase);
    try std.testing.expectEqual(saga_mod.StepPhase.compensating, saga.steps.items[1].phase);
    try std.testing.expectEqual(saga_mod.StepPhase.failed, saga.steps.items[2].phase);

    // Compensate both
    const r0 = try engine.compensationSucceeded(saga_id, 0, 2300);
    try std.testing.expect(r0 == null);
    const r1 = try engine.compensationSucceeded(saga_id, 1, 2300);
    try std.testing.expect(r1 != null);
    try std.testing.expectEqual(ParallelSagaPhase.compensated, r1.?.phase);
    try std.testing.expectEqual(@as(u32, 2), r1.?.steps_compensated);
}

test "parallel saga — timeout triggers compensation" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.initWithConfig(allocator, .{
        .max_saga_duration_ms = 5000,
    });
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;
    const saga_id = try engine.createSaga(cid, 1000);

    _ = try engine.addStep(saga_id, .shard_write, shard, node);
    _ = try engine.addStep(saga_id, .shard_write, shard, node);

    _ = try engine.execute(saga_id, 2000);
    _ = try engine.stepSucceeded(saga_id, 0, 2500);
    // Step 1 still running...

    const timed_out = engine.checkTimeouts(12000);
    try std.testing.expectEqual(@as(u32, 1), timed_out);

    const saga = engine.getSaga(saga_id).?;
    try std.testing.expectEqual(ParallelSagaPhase.compensating, saga.phase);
    try std.testing.expectEqual(@as(u32, 408), saga.steps.items[1].error_code);
}

test "parallel saga — abort during execution" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;
    const saga_id = try engine.createSaga(cid, 1000);

    _ = try engine.addStep(saga_id, .shard_write, shard, node);
    _ = try engine.addStep(saga_id, .shard_write, shard, node);

    _ = try engine.execute(saga_id, 2000);
    _ = try engine.stepSucceeded(saga_id, 0, 2100);
    try engine.abortSaga(saga_id, 2200);

    const saga = engine.getSaga(saga_id).?;
    try std.testing.expectEqual(ParallelSagaPhase.compensating, saga.phase);
    try std.testing.expectEqual(@as(u32, 499), saga.steps.items[1].error_code);
    try std.testing.expectEqual(saga_mod.StepPhase.compensating, saga.steps.items[0].phase);
}

test "parallel saga — deep dependency chain (4 levels)" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;
    const saga_id = try engine.createSaga(cid, 1000);

    // Chain: s0 → s1 → s2 → s3 (each depends on previous)
    const s0 = try engine.addStep(saga_id, .shard_write, shard, node);
    const s1 = try engine.addStepWithDeps(saga_id, .lock_acquire, shard, node, &.{s0});
    const s2 = try engine.addStepWithDeps(saga_id, .stake_lock, shard, node, &.{s1});
    _ = try engine.addStepWithDeps(saga_id, .escrow_create, shard, node, &.{s2});

    try std.testing.expectEqual(@as(u32, 0), engine.getSaga(saga_id).?.steps.items[0].level);
    try std.testing.expectEqual(@as(u32, 1), engine.getSaga(saga_id).?.steps.items[1].level);
    try std.testing.expectEqual(@as(u32, 2), engine.getSaga(saga_id).?.steps.items[2].level);
    try std.testing.expectEqual(@as(u32, 3), engine.getSaga(saga_id).?.steps.items[3].level);
    try std.testing.expectEqual(@as(u32, 3), engine.getSaga(saga_id).?.max_level);

    // Execute sequentially through levels
    const started = try engine.execute(saga_id, 2000);
    try std.testing.expectEqual(@as(u32, 1), started); // Only s0 at level 0

    _ = try engine.stepSucceeded(saga_id, 0, 2100);
    try std.testing.expectEqual(saga_mod.StepPhase.running, engine.getSaga(saga_id).?.steps.items[1].phase);

    _ = try engine.stepSucceeded(saga_id, 1, 2200);
    try std.testing.expectEqual(saga_mod.StepPhase.running, engine.getSaga(saga_id).?.steps.items[2].phase);

    _ = try engine.stepSucceeded(saga_id, 2, 2300);
    try std.testing.expectEqual(saga_mod.StepPhase.running, engine.getSaga(saga_id).?.steps.items[3].phase);

    const result = try engine.stepSucceeded(saga_id, 3, 2400);
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.success);
    try std.testing.expectEqual(@as(u32, 4), result.?.levels_executed);
    try std.testing.expectEqual(@as(u32, 1), result.?.max_parallelism); // sequential chain
}

test "parallel saga — stats accumulation" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;

    // Saga 1: 3 parallel steps, all succeed
    const s1_id = try engine.createSaga(cid, 1000);
    _ = try engine.addStep(s1_id, .shard_write, shard, node);
    _ = try engine.addStep(s1_id, .shard_write, shard, node);
    _ = try engine.addStep(s1_id, .shard_write, shard, node);
    _ = try engine.execute(s1_id, 2000);
    _ = try engine.stepSucceeded(s1_id, 0, 2100);
    _ = try engine.stepSucceeded(s1_id, 1, 2100);
    _ = try engine.stepSucceeded(s1_id, 2, 2100);

    // Saga 2: 2 parallel steps, step 1 fails → compensate step 0
    const s2_id = try engine.createSaga(cid, 3000);
    _ = try engine.addStep(s2_id, .shard_write, shard, node);
    _ = try engine.addStep(s2_id, .lock_acquire, shard, node);
    _ = try engine.execute(s2_id, 4000);
    _ = try engine.stepSucceeded(s2_id, 0, 4100);
    try engine.stepFailed(s2_id, 1, 500, 4200);
    _ = try engine.compensationSucceeded(s2_id, 0, 4300);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_sagas);
    try std.testing.expectEqual(@as(u64, 1), stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 1), stats.compensated_sagas);
    try std.testing.expectEqual(@as(u64, 5), stats.total_steps);
    try std.testing.expectEqual(@as(u64, 4), stats.steps_succeeded);
    try std.testing.expectEqual(@as(u64, 1), stats.steps_compensated);
    try std.testing.expect(stats.avg_saga_duration_ms > 0);
    try std.testing.expect(stats.avg_parallelism > 0);
    try std.testing.expect(stats.max_parallelism_seen >= 2);
}

test "parallel saga — max concurrent sagas enforced" {
    const allocator = std.testing.allocator;
    var engine = ParallelSagaEngine.initWithConfig(allocator, .{
        .max_concurrent_sagas = 2,
    });
    defer engine.deinit();

    const cid = [_]u8{0xAA} ** 32;
    _ = try engine.createSaga(cid, 1000);
    _ = try engine.createSaga(cid, 2000);
    const result = engine.createSaga(cid, 3000);
    try std.testing.expectError(error.TooManySagas, result);
}
