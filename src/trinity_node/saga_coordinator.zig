// Trinity Storage Network v2.3 — Saga Pattern Coordinator
// Non-blocking distributed transactions with compensating actions
// Alternative to 2PC: higher throughput, eventual consistency
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");

/// Phase of an individual saga step
pub const StepPhase = enum(u8) {
    pending, // Not yet started
    running, // Forward action executing
    succeeded, // Forward action completed
    compensating, // Undo action executing
    compensated, // Undo action completed
    failed, // Forward action failed, not yet compensated
    compensation_failed, // Undo also failed (requires manual intervention)
};

/// Phase of the entire saga
pub const SagaPhase = enum(u8) {
    created, // Steps defined but not started
    executing, // Forward steps in progress
    compensating, // Rolling back completed steps
    completed, // All forward steps succeeded
    compensated, // All completed steps rolled back successfully
    partially_compensated, // Some compensations failed
    failed, // Saga failed with compensation failures

    pub fn label(self: SagaPhase) []const u8 {
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

/// Type of action a step performs (for diagnostics)
pub const StepAction = enum(u8) {
    shard_write, // Write data to a shard
    shard_delete, // Delete data from a shard
    lock_acquire, // Acquire VSA shard lock
    lock_release, // Release VSA shard lock
    stake_lock, // Lock stake for operation
    stake_release, // Release locked stake
    escrow_create, // Create slashing escrow
    escrow_resolve, // Resolve escrow
    route_select, // Select route for operation
    custom, // Application-defined action
};

/// A single step in a saga with forward and compensating action metadata
pub const SagaStep = struct {
    step_index: u32,
    action: StepAction,
    target_shard: [32]u8, // Shard or resource this step operates on
    target_node: [32]u8, // Node responsible for executing this step
    phase: StepPhase,
    started_at: i64,
    completed_at: i64,
    compensation_retries: u32,
    error_code: u32, // 0 = no error
};

/// Configuration for the saga coordinator
pub const SagaConfig = struct {
    max_steps_per_saga: u32 = 32,
    max_concurrent_sagas: u32 = 1024,
    step_timeout_ms: i64 = 60_000,
    max_saga_duration_ms: i64 = 300_000,
    max_compensation_retries: u32 = 3,
};

/// Internal saga entry tracking all steps and state
pub const SagaEntry = struct {
    saga_id: u64,
    coordinator_id: [32]u8,
    phase: SagaPhase,
    steps: std.ArrayList(SagaStep),
    created_at: i64,
    started_at: i64,
    completed_at: i64,
    current_step: u32, // Index of step being executed
    steps_succeeded: u32,
    steps_compensated: u32,
    compensation_failures: u32,
};

/// Result of a saga execution
pub const SagaResult = struct {
    saga_id: u64,
    success: bool,
    phase: SagaPhase,
    steps_total: u32,
    steps_succeeded: u32,
    steps_compensated: u32,
    compensation_failures: u32,
    duration_ms: i64,
};

/// Statistics tracked by the saga coordinator
pub const SagaStats = struct {
    total_sagas: u64,
    completed_sagas: u64,
    compensated_sagas: u64,
    failed_sagas: u64,
    total_steps: u64,
    steps_succeeded: u64,
    steps_compensated: u64,
    compensation_failures: u64,
    avg_saga_duration_ms: i64,
    avg_steps_per_saga: f64,
    duration_sum: i64,
    steps_sum: u64,
};

/// Saga Coordinator — manages non-blocking distributed transactions
/// with forward steps and compensating (undo) actions
pub const SagaCoordinator = struct {
    allocator: std.mem.Allocator,
    config: SagaConfig,
    sagas: std.AutoHashMap(u64, SagaEntry),
    next_saga_id: u64,
    stats: SagaStats,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: SagaConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .sagas = std.AutoHashMap(u64, SagaEntry).init(allocator),
            .next_saga_id = 1,
            .stats = .{
                .total_sagas = 0,
                .completed_sagas = 0,
                .compensated_sagas = 0,
                .failed_sagas = 0,
                .total_steps = 0,
                .steps_succeeded = 0,
                .steps_compensated = 0,
                .compensation_failures = 0,
                .avg_saga_duration_ms = 0,
                .avg_steps_per_saga = 0,
                .duration_sum = 0,
                .steps_sum = 0,
            },
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.sagas.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.steps.deinit(self.allocator);
        }
        self.sagas.deinit();
    }

    /// Create a new saga
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
            .current_step = 0,
            .steps_succeeded = 0,
            .steps_compensated = 0,
            .compensation_failures = 0,
        });

        self.stats.total_sagas += 1;
        return saga_id;
    }

    /// Add a step to the saga (must be in created phase)
    pub fn addStep(
        self: *Self,
        saga_id: u64,
        action: StepAction,
        target_shard: [32]u8,
        target_node: [32]u8,
    ) error{ SagaNotFound, InvalidPhase, TooManySteps }!u32 {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .created) return error.InvalidPhase;
        if (entry.steps.items.len >= self.config.max_steps_per_saga) return error.TooManySteps;

        const step_index: u32 = @intCast(entry.steps.items.len);
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
        }) catch return error.TooManySteps;

        self.stats.total_steps += 1;
        return step_index;
    }

    /// Begin executing the saga (transitions from created → executing)
    pub fn execute(self: *Self, saga_id: u64, timestamp: i64) error{ SagaNotFound, InvalidPhase, NoSteps }!void {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .created) return error.InvalidPhase;
        if (entry.steps.items.len == 0) return error.NoSteps;

        entry.phase = .executing;
        entry.started_at = timestamp;
        entry.current_step = 0;

        // Mark first step as running
        entry.steps.items[0].phase = .running;
        entry.steps.items[0].started_at = timestamp;
    }

    /// Report that a step succeeded (advances to next step or completes saga)
    pub fn stepSucceeded(self: *Self, saga_id: u64, step_index: u32, timestamp: i64) error{ SagaNotFound, InvalidPhase, InvalidStep }!?SagaResult {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .executing) return error.InvalidPhase;
        if (step_index >= entry.steps.items.len) return error.InvalidStep;

        var step = &entry.steps.items[step_index];
        if (step.phase != .running) return error.InvalidStep;

        step.phase = .succeeded;
        step.completed_at = timestamp;
        entry.steps_succeeded += 1;
        self.stats.steps_succeeded += 1;

        // Check if all steps are done
        if (entry.steps_succeeded == @as(u32, @intCast(entry.steps.items.len))) {
            // Saga completed successfully
            entry.phase = .completed;
            entry.completed_at = timestamp;
            self.stats.completed_sagas += 1;
            self.updateDurationStats(timestamp - entry.started_at, @intCast(entry.steps.items.len));
            return .{
                .saga_id = saga_id,
                .success = true,
                .phase = .completed,
                .steps_total = @intCast(entry.steps.items.len),
                .steps_succeeded = entry.steps_succeeded,
                .steps_compensated = 0,
                .compensation_failures = 0,
                .duration_ms = timestamp - entry.started_at,
            };
        }

        // Advance to next step
        const next = step_index + 1;
        if (next < entry.steps.items.len) {
            entry.current_step = next;
            entry.steps.items[next].phase = .running;
            entry.steps.items[next].started_at = timestamp;
        }

        return null; // Not yet complete
    }

    /// Report that a step failed (triggers compensation)
    pub fn stepFailed(self: *Self, saga_id: u64, step_index: u32, error_code: u32, timestamp: i64) error{ SagaNotFound, InvalidPhase, InvalidStep }!void {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .executing) return error.InvalidPhase;
        if (step_index >= entry.steps.items.len) return error.InvalidStep;

        var step = &entry.steps.items[step_index];
        if (step.phase != .running) return error.InvalidStep;

        step.phase = .failed;
        step.error_code = error_code;
        step.completed_at = timestamp;

        // Transition saga to compensating phase
        entry.phase = .compensating;

        // Start compensating from the last succeeded step backwards
        self.initiateCompensation(entry, timestamp);
    }

    /// Begin compensating completed steps (called internally or for timeout)
    fn initiateCompensation(self: *Self, entry: *SagaEntry, timestamp: i64) void {
        _ = self;
        // Walk backwards through steps, mark succeeded ones as compensating
        var i: usize = entry.steps.items.len;
        while (i > 0) {
            i -= 1;
            if (entry.steps.items[i].phase == .succeeded) {
                entry.steps.items[i].phase = .compensating;
                entry.steps.items[i].started_at = timestamp;
            }
        }
    }

    /// Report that a compensation succeeded for a step
    pub fn compensationSucceeded(self: *Self, saga_id: u64, step_index: u32, timestamp: i64) error{ SagaNotFound, InvalidPhase, InvalidStep }!?SagaResult {
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
    pub fn compensationFailed(self: *Self, saga_id: u64, step_index: u32, timestamp: i64) error{ SagaNotFound, InvalidPhase, InvalidStep }!?SagaResult {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .compensating) return error.InvalidPhase;
        if (step_index >= entry.steps.items.len) return error.InvalidStep;

        var step = &entry.steps.items[step_index];
        if (step.phase != .compensating) return error.InvalidStep;

        step.compensation_retries += 1;

        if (step.compensation_retries >= self.config.max_compensation_retries) {
            // Exceeded retry limit — mark as permanently failed
            step.phase = .compensation_failed;
            step.completed_at = timestamp;
            entry.compensation_failures += 1;
            self.stats.compensation_failures += 1;

            return self.checkCompensationComplete(entry, saga_id, timestamp);
        }

        // Retry: keep in compensating state
        step.started_at = timestamp;
        return null;
    }

    /// Check if all compensations are resolved
    fn checkCompensationComplete(self: *Self, entry: *SagaEntry, saga_id: u64, timestamp: i64) ?SagaResult {
        // Count remaining compensations
        var pending_compensations: u32 = 0;
        for (entry.steps.items) |step| {
            if (step.phase == .compensating) pending_compensations += 1;
        }

        if (pending_compensations > 0) return null; // Still compensating

        // All compensations resolved
        entry.completed_at = timestamp;

        if (entry.compensation_failures > 0) {
            entry.phase = .partially_compensated;
            self.stats.failed_sagas += 1;
        } else {
            entry.phase = .compensated;
            self.stats.compensated_sagas += 1;
        }

        const duration = timestamp - entry.started_at;
        self.updateDurationStats(duration, @intCast(entry.steps.items.len));

        return .{
            .saga_id = saga_id,
            .success = false,
            .phase = entry.phase,
            .steps_total = @intCast(entry.steps.items.len),
            .steps_succeeded = entry.steps_succeeded,
            .steps_compensated = entry.steps_compensated,
            .compensation_failures = entry.compensation_failures,
            .duration_ms = duration,
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
                    // Timeout — start compensation
                    entry.phase = .compensating;

                    // Mark running steps as failed
                    for (entry.steps.items) |*step| {
                        if (step.phase == .running) {
                            step.phase = .failed;
                            step.error_code = 408; // Timeout
                            step.completed_at = current_time;
                        }
                    }

                    self.initiateCompensation(entry, current_time);
                    timed_out += 1;
                }
            }
        }
        return timed_out;
    }

    /// Force-abort a saga (mark as compensating)
    pub fn abortSaga(self: *Self, saga_id: u64, timestamp: i64) error{ SagaNotFound, InvalidPhase }!void {
        const entry = self.sagas.getPtr(saga_id) orelse return error.SagaNotFound;
        if (entry.phase != .executing and entry.phase != .created) return error.InvalidPhase;

        if (entry.phase == .created) {
            // Not yet started — just mark as compensated (nothing to undo)
            entry.phase = .compensated;
            entry.completed_at = timestamp;
            self.stats.compensated_sagas += 1;
            return;
        }

        // Executing — trigger compensation
        entry.phase = .compensating;

        // Fail running steps
        for (entry.steps.items) |*step| {
            if (step.phase == .running) {
                step.phase = .failed;
                step.error_code = 499; // Client abort
                step.completed_at = timestamp;
            }
        }

        self.initiateCompensation(entry, timestamp);
    }

    /// Update running average for duration and steps
    fn updateDurationStats(self: *Self, duration_ms: i64, step_count: u32) void {
        const finished = self.stats.completed_sagas + self.stats.compensated_sagas + self.stats.failed_sagas;
        self.stats.duration_sum += duration_ms;
        self.stats.steps_sum += step_count;
        if (finished > 0) {
            self.stats.avg_saga_duration_ms = @divTrunc(self.stats.duration_sum, @as(i64, @intCast(finished)));
            self.stats.avg_steps_per_saga = @as(f64, @floatFromInt(self.stats.steps_sum)) / @as(f64, @floatFromInt(finished));
        }
    }

    /// Get saga details
    pub fn getSaga(self: *const Self, saga_id: u64) ?SagaEntry {
        return self.sagas.get(saga_id);
    }

    pub fn getStats(self: *const Self) SagaStats {
        return self.stats;
    }
};

// ============================================================
// Unit Tests
// ============================================================

test "saga — create and add steps" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.init(allocator);
    defer coord.deinit();

    const coordinator_id = [_]u8{0xAA} ** 32;
    const saga_id = try coord.createSaga(coordinator_id, 1000);

    const shard1 = [_]u8{0x01} ** 32;
    const shard2 = [_]u8{0x02} ** 32;
    const node1 = [_]u8{0xB1} ** 32;
    const node2 = [_]u8{0xB2} ** 32;

    const idx0 = try coord.addStep(saga_id, .shard_write, shard1, node1);
    const idx1 = try coord.addStep(saga_id, .lock_acquire, shard2, node2);
    try std.testing.expectEqual(@as(u32, 0), idx0);
    try std.testing.expectEqual(@as(u32, 1), idx1);

    const saga = coord.getSaga(saga_id).?;
    try std.testing.expectEqual(SagaPhase.created, saga.phase);
    try std.testing.expectEqual(@as(usize, 2), saga.steps.items.len);
}

test "saga — full success path (all steps succeed)" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.init(allocator);
    defer coord.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const saga_id = try coord.createSaga(cid, 1000);

    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;

    _ = try coord.addStep(saga_id, .shard_write, shard, node);
    _ = try coord.addStep(saga_id, .lock_acquire, shard, node);
    _ = try coord.addStep(saga_id, .stake_lock, shard, node);

    try coord.execute(saga_id, 2000);

    // Step 0 succeeds
    const r0 = try coord.stepSucceeded(saga_id, 0, 2100);
    try std.testing.expect(r0 == null); // not done yet

    // Step 1 succeeds
    const r1 = try coord.stepSucceeded(saga_id, 1, 2200);
    try std.testing.expect(r1 == null);

    // Step 2 succeeds — saga completes
    const r2 = try coord.stepSucceeded(saga_id, 2, 2300);
    try std.testing.expect(r2 != null);
    try std.testing.expect(r2.?.success);
    try std.testing.expectEqual(SagaPhase.completed, r2.?.phase);
    try std.testing.expectEqual(@as(u32, 3), r2.?.steps_succeeded);
    try std.testing.expectEqual(@as(i64, 300), r2.?.duration_ms);

    const stats = coord.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 3), stats.steps_succeeded);
}

test "saga — step failure triggers compensation" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.init(allocator);
    defer coord.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const saga_id = try coord.createSaga(cid, 1000);

    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;

    _ = try coord.addStep(saga_id, .shard_write, shard, node);
    _ = try coord.addStep(saga_id, .lock_acquire, shard, node);
    _ = try coord.addStep(saga_id, .stake_lock, shard, node);

    try coord.execute(saga_id, 2000);

    // Step 0 succeeds
    _ = try coord.stepSucceeded(saga_id, 0, 2100);

    // Step 1 succeeds
    _ = try coord.stepSucceeded(saga_id, 1, 2200);

    // Step 2 fails → triggers compensation of steps 0, 1
    try coord.stepFailed(saga_id, 2, 500, 2300);

    const saga = coord.getSaga(saga_id).?;
    try std.testing.expectEqual(SagaPhase.compensating, saga.phase);

    // Steps 0, 1 should be in compensating state
    try std.testing.expectEqual(StepPhase.compensating, saga.steps.items[0].phase);
    try std.testing.expectEqual(StepPhase.compensating, saga.steps.items[1].phase);
    try std.testing.expectEqual(StepPhase.failed, saga.steps.items[2].phase);
}

test "saga — full compensation path" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.init(allocator);
    defer coord.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const saga_id = try coord.createSaga(cid, 1000);

    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;

    _ = try coord.addStep(saga_id, .shard_write, shard, node);
    _ = try coord.addStep(saga_id, .lock_acquire, shard, node);

    try coord.execute(saga_id, 2000);
    _ = try coord.stepSucceeded(saga_id, 0, 2100);

    // Step 1 fails
    try coord.stepFailed(saga_id, 1, 500, 2200);

    // Compensate step 0
    const result = try coord.compensationSucceeded(saga_id, 0, 2300);
    try std.testing.expect(result != null);
    try std.testing.expect(!result.?.success);
    try std.testing.expectEqual(SagaPhase.compensated, result.?.phase);
    try std.testing.expectEqual(@as(u32, 1), result.?.steps_compensated);
    try std.testing.expectEqual(@as(u32, 0), result.?.compensation_failures);

    const stats = coord.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.compensated_sagas);
    try std.testing.expectEqual(@as(u64, 1), stats.steps_compensated);
}

test "saga — compensation failure with retries" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.initWithConfig(allocator, .{
        .max_compensation_retries = 2,
    });
    defer coord.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const saga_id = try coord.createSaga(cid, 1000);

    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;

    _ = try coord.addStep(saga_id, .shard_write, shard, node);
    _ = try coord.addStep(saga_id, .lock_acquire, shard, node);

    try coord.execute(saga_id, 2000);
    _ = try coord.stepSucceeded(saga_id, 0, 2100);
    try coord.stepFailed(saga_id, 1, 500, 2200);

    // Compensation attempt 1 fails
    const r1 = try coord.compensationFailed(saga_id, 0, 2300);
    try std.testing.expect(r1 == null); // Retry still possible

    // Compensation attempt 2 fails — exceeds max retries
    const r2 = try coord.compensationFailed(saga_id, 0, 2400);
    try std.testing.expect(r2 != null);
    try std.testing.expectEqual(SagaPhase.partially_compensated, r2.?.phase);
    try std.testing.expectEqual(@as(u32, 1), r2.?.compensation_failures);

    const stats = coord.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.failed_sagas);
    try std.testing.expectEqual(@as(u64, 1), stats.compensation_failures);
}

test "saga — timeout triggers compensation" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.initWithConfig(allocator, .{
        .max_saga_duration_ms = 5000,
    });
    defer coord.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const saga_id = try coord.createSaga(cid, 1000);

    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;

    _ = try coord.addStep(saga_id, .shard_write, shard, node);
    _ = try coord.addStep(saga_id, .lock_acquire, shard, node);

    try coord.execute(saga_id, 2000);
    _ = try coord.stepSucceeded(saga_id, 0, 2500);
    // Step 1 is running but takes too long...

    // Check timeouts 10 seconds later
    const timed_out = coord.checkTimeouts(12000);
    try std.testing.expectEqual(@as(u32, 1), timed_out);

    const saga = coord.getSaga(saga_id).?;
    try std.testing.expectEqual(SagaPhase.compensating, saga.phase);
    try std.testing.expectEqual(StepPhase.failed, saga.steps.items[1].phase);
    try std.testing.expectEqual(@as(u32, 408), saga.steps.items[1].error_code); // timeout
}

test "saga — abort before execution" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.init(allocator);
    defer coord.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const saga_id = try coord.createSaga(cid, 1000);

    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;
    _ = try coord.addStep(saga_id, .shard_write, shard, node);

    // Abort while still in created phase
    try coord.abortSaga(saga_id, 1500);

    const saga = coord.getSaga(saga_id).?;
    try std.testing.expectEqual(SagaPhase.compensated, saga.phase);
    try std.testing.expectEqual(@as(u64, 1), coord.getStats().compensated_sagas);
}

test "saga — abort during execution" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.init(allocator);
    defer coord.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const saga_id = try coord.createSaga(cid, 1000);

    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;
    _ = try coord.addStep(saga_id, .shard_write, shard, node);
    _ = try coord.addStep(saga_id, .lock_acquire, shard, node);

    try coord.execute(saga_id, 2000);
    _ = try coord.stepSucceeded(saga_id, 0, 2100);

    // Abort while step 1 is running
    try coord.abortSaga(saga_id, 2200);

    const saga = coord.getSaga(saga_id).?;
    try std.testing.expectEqual(SagaPhase.compensating, saga.phase);
    try std.testing.expectEqual(StepPhase.failed, saga.steps.items[1].phase);
    try std.testing.expectEqual(@as(u32, 499), saga.steps.items[1].error_code); // client abort
    try std.testing.expectEqual(StepPhase.compensating, saga.steps.items[0].phase);
}

test "saga — stats accumulation across multiple sagas" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.init(allocator);
    defer coord.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;

    // Saga 1: success (2 steps)
    const s1 = try coord.createSaga(cid, 1000);
    _ = try coord.addStep(s1, .shard_write, shard, node);
    _ = try coord.addStep(s1, .lock_acquire, shard, node);
    try coord.execute(s1, 2000);
    _ = try coord.stepSucceeded(s1, 0, 2100);
    _ = try coord.stepSucceeded(s1, 1, 2200);

    // Saga 2: compensated (3 steps, step 2 fails)
    const s2 = try coord.createSaga(cid, 3000);
    _ = try coord.addStep(s2, .shard_write, shard, node);
    _ = try coord.addStep(s2, .lock_acquire, shard, node);
    _ = try coord.addStep(s2, .escrow_create, shard, node);
    try coord.execute(s2, 4000);
    _ = try coord.stepSucceeded(s2, 0, 4100);
    _ = try coord.stepSucceeded(s2, 1, 4200);
    try coord.stepFailed(s2, 2, 500, 4300);
    _ = try coord.compensationSucceeded(s2, 0, 4400);
    _ = try coord.compensationSucceeded(s2, 1, 4500);

    const stats = coord.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_sagas);
    try std.testing.expectEqual(@as(u64, 1), stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 1), stats.compensated_sagas);
    try std.testing.expectEqual(@as(u64, 5), stats.total_steps);
    try std.testing.expectEqual(@as(u64, 4), stats.steps_succeeded);
    try std.testing.expectEqual(@as(u64, 2), stats.steps_compensated);
    try std.testing.expect(stats.avg_saga_duration_ms > 0);
    try std.testing.expect(stats.avg_steps_per_saga > 0);
}

test "saga — max concurrent sagas enforced" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.initWithConfig(allocator, .{
        .max_concurrent_sagas = 2,
    });
    defer coord.deinit();

    const cid = [_]u8{0xAA} ** 32;
    _ = try coord.createSaga(cid, 1000);
    _ = try coord.createSaga(cid, 2000);

    // Third should fail
    const result = coord.createSaga(cid, 3000);
    try std.testing.expectError(error.TooManySagas, result);
}

test "saga — max steps per saga enforced" {
    const allocator = std.testing.allocator;
    var coord = SagaCoordinator.initWithConfig(allocator, .{
        .max_steps_per_saga = 2,
    });
    defer coord.deinit();

    const cid = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;

    const saga_id = try coord.createSaga(cid, 1000);
    _ = try coord.addStep(saga_id, .shard_write, shard, node);
    _ = try coord.addStep(saga_id, .lock_acquire, shard, node);

    // Third step should fail
    const result = coord.addStep(saga_id, .stake_lock, shard, node);
    try std.testing.expectError(error.TooManySteps, result);
}
