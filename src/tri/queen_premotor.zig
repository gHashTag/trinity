// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN PREMOTOR CORTEX (PMC) — Action Sequencing & Planning
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// Phase 2: Receives goals from PFC, sequences actions, sends to M1
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const qt = @import("queen_types.zig");

const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION SEQUENCING — PMC plans multi-step action sequences
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_SEQUENCE_STEPS = 10;
pub const MAX_PARALLEL_BRANCHES = 3;

/// A single step in an action sequence
pub const SequenceStep = struct {
    action: qt.ActionKind,
    delay_ms: u64 = 0, // Delay before this step (0 = immediate)
    condition: ?Condition = null, // Optional condition to check before execution
    on_failure: FailureAction = .stop,
    custom_check_fn: ?CustomCheckFn = null, // For custom_check condition

    pub const Condition = enum(u8) {
        build_ok,
        tests_pass,
        farm_idle_exists,
        arena_exists,
        custom_check,
        // v2: health-based conditions
        health_critical, // ouroboros_score < 50
        health_good, // ouroboros_score >= 70
        dirty_exists, // dirty_files > 0
        // v2: farm conditions
        farm_has_leaders, // farm_idle_count >= 3
        farm_best_ppl_good, // best_ppl < 10.0
        // v2: arena conditions
        arena_stale, // stale_arena_hours > 24
        // v2: git conditions
        has_uncommitted, // uncommitted changes exist
    };

    pub const CustomCheckFn = *const fn (*const SequenceStep.ConditionContext) bool;

    pub const FailureAction = union(enum(u8)) {
        stop: void,
        skip: void,
        retry: void,
        fallback: qt.ActionKind,
    };

    pub const ConditionContext = struct {
        build_ok: bool = false,
        tests_pass: bool = false,
        farm_idle_count: u8 = 0,
        arena_exists: bool = false,
        // v2: extended context
        ouroboros_score: f32 = 0.0,
        dirty_files: u16 = 0,
        farm_best_ppl: f32 = 999.0,
        stale_arena_hours: u16 = 0,
        has_uncommitted: bool = false,
    };
};

/// An action sequence (plan) from PMC to M1
pub const ActionSequence = struct {
    name: [64]u8 = undefined,
    name_len: usize = 0,
    steps: [MAX_SEQUENCE_STEPS]SequenceStep = undefined,
    step_count: u8 = 0,
    parallel: bool = false, // true = execute branches in parallel
    max_retries: u8 = 3,
    timeout_sec: u32 = 300, // 5 min default

    pub fn nameStr(self: *const ActionSequence) []const u8 {
        return self.name[0..self.name_len];
    }

    /// Add a step to the sequence
    pub fn addStep(self: *ActionSequence, action: qt.ActionKind) !void {
        if (self.step_count >= MAX_SEQUENCE_STEPS) return error.SequenceFull;
        self.steps[self.step_count] = .{
            .action = action,
            .delay_ms = 0,
            .condition = null,
            .on_failure = .stop,
        };
        self.step_count += 1;
    }

    /// Add a step with condition
    pub fn addStepWithCondition(
        self: *ActionSequence,
        action: qt.ActionKind,
        cond: SequenceStep.Condition,
    ) !void {
        if (self.step_count >= MAX_SEQUENCE_STEPS) return error.SequenceFull;
        self.steps[self.step_count] = .{
            .action = action,
            .delay_ms = 0,
            .condition = cond,
            .on_failure = .skip,
        };
        self.step_count += 1;
    }

    /// Add a delayed step
    pub fn addDelayedStep(self: *ActionSequence, action: qt.ActionKind, delay_ms: u64) !void {
        if (self.step_count >= MAX_SEQUENCE_STEPS) return error.SequenceFull;
        self.steps[self.step_count] = .{
            .action = action,
            .delay_ms = delay_ms,
            .condition = null,
            .on_failure = .stop,
        };
        self.step_count += 1;
    }
};

/// Predefined action sequences (PMC "knows" these patterns)
pub const PredefinedSequences = struct {
    /// Full heal cycle: doctor scan → quick → ouroboros → heal
    pub fn fullHeal() ActionSequence {
        var seq = ActionSequence{};
        @memcpy(seq.name[0.."full_heal".len], "full_heal");
        seq.name_len = "full_heal".len;
        seq.steps[0] = .{ .action = .doctor_scan, .delay_ms = 0 };
        seq.steps[1] = .{ .action = .doctor_quick, .condition = .build_ok, .delay_ms = 500 };
        seq.steps[2] = .{ .action = .ouroboros_cycle, .delay_ms = 1000 };
        seq.steps[3] = .{ .action = .doctor_heal, .delay_ms = 500 };
        seq.step_count = 4;
        return seq;
    }

    /// Farm health check: status → evolve_status → (recycle if needed)
    pub fn farmHealthCheck() ActionSequence {
        var seq = ActionSequence{};
        @memcpy(seq.name[0.."farm_health".len], "farm_health");
        seq.name_len = "farm_health".len;
        seq.steps[0] = .{ .action = .farm_status, .delay_ms = 0 };
        seq.steps[1] = .{ .action = .farm_evolve_status, .delay_ms = 1000 };
        seq.step_count = 2;
        return seq;
    }

    /// Cloud cleanup: status → kill finished → cleanup
    pub fn cloudCleanup() ActionSequence {
        var seq = ActionSequence{};
        @memcpy(seq.name[0.."cloud_cleanup".len], "cloud_cleanup");
        seq.name_len = "cloud_cleanup".len;
        seq.steps[0] = .{ .action = .cloud_spawn, .condition = .custom_check, .custom_check_fn = null, .delay_ms = 0 };
        seq.steps[1] = .{ .action = .cloud_cleanup, .delay_ms = 2000 };
        seq.step_count = 2;
        return seq;
    }

    /// Research cycle: sacred → patent status → (notify if new)
    pub fn researchCycle() ActionSequence {
        var seq = ActionSequence{};
        @memcpy(seq.name[0.."research_cycle".len], "research_cycle");
        seq.name_len = "research_cycle".len;
        seq.steps[0] = .{ .action = .research_sacred, .delay_ms = 0 };
        seq.steps[1] = .{ .action = .patent_status, .delay_ms = 500 };
        seq.step_count = 2;
        return seq;
    }

    // v2: New predefined sequences with delays and conditions

    /// check_and_heal: Quick health check → heal if critical
    /// Delays: 0ms for scan, 1s delay before heal
    pub fn checkAndHeal() ActionSequence {
        var seq = ActionSequence{};
        @memcpy(seq.name[0.."check_and_heal".len], "check_and_heal");
        seq.name_len = "check_and_heal".len;
        seq.steps[0] = .{ .action = .doctor_scan, .delay_ms = 0 };
        seq.steps[1] = .{ .action = .doctor_heal, .condition = .health_critical, .delay_ms = 1000 };
        seq.step_count = 2;
        return seq;
    }

    /// farm_cycle: Check farm → evolve if idle leaders exist → inject top configs
    /// Delays: 500ms between steps for status refresh
    pub fn farmCycle() ActionSequence {
        var seq = ActionSequence{};
        @memcpy(seq.name[0.."farm_cycle".len], "farm_cycle");
        seq.name_len = "farm_cycle".len;
        seq.steps[0] = .{ .action = .farm_status, .delay_ms = 0 };
        seq.steps[1] = .{ .action = .farm_evolve_step, .condition = .farm_has_leaders, .delay_ms = 500 };
        seq.step_count = 2;
        return seq;
    }

    /// full_backup: Git stash → commit → push
    /// Delays: 200ms between steps for filesystem sync
    pub fn fullBackup() ActionSequence {
        var seq = ActionSequence{};
        @memcpy(seq.name[0.."full_backup".len], "full_backup");
        seq.name_len = "full_backup".len;
        seq.steps[0] = .{ .action = .git_commit_state, .condition = .has_uncommitted, .delay_ms = 0 };
        seq.steps[1] = .{ .action = .git_push, .condition = .has_uncommitted, .delay_ms = 200 };
        seq.step_count = 2;
        return seq;
    }

    /// arena_battle: Run arena battle → record result to experience
    /// Delays: 1s before battle for setup, 500ms after for save
    pub fn arenaBattle() ActionSequence {
        var seq = ActionSequence{};
        @memcpy(seq.name[0.."arena_battle".len], "arena_battle");
        seq.name_len = "arena_battle".len;
        seq.steps[0] = .{ .action = .arena_battle, .delay_ms = 1000 };
        seq.steps[1] = .{ .action = .experience_save, .delay_ms = 500 };
        seq.step_count = 2;
        return seq;
    }

    /// research_scan: Search arXiv for new papers → save to Scholar if found
    /// Delays: 2s for search, 500ms for save
    pub fn researchScan() ActionSequence {
        var seq = ActionSequence{};
        @memcpy(seq.name[0.."research_scan".len], "research_scan");
        seq.name_len = "research_scan".len;
        seq.steps[0] = .{ .action = .research_sacred, .delay_ms = 2000 };
        seq.steps[1] = .{ .action = .experience_save, .delay_ms = 500 };
        seq.step_count = 2;
        return seq;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEQUENCER — Executes action sequences
// ═══════════════════════════════════════════════════════════════════════════════

pub const Sequencer = struct {
    allocator: Allocator,
    context: SequenceStep.ConditionContext,

    pub fn init(allocator: Allocator) Sequencer {
        return .{
            .allocator = allocator,
            .context = .{},
        };
    }

    /// Execute a predefined sequence
    pub fn executeSequence(self: *Sequencer, seq: *const ActionSequence) !SequenceResult {
        var result = SequenceResult{
            .success = true,
            .executed_count = 0,
            .total_duration_ms = 0,
        };

        const start = std.time.milliTimestamp();

        for (0..seq.step_count) |i| {
            const step = &seq.steps[i];

            // Check condition if present
            if (step.condition) |cond| {
                if (!self.checkCondition(cond, step.custom_check_fn)) {
                    result.executed_count = @intCast(i);
                    result.failed_at = @intCast(i);
                    result.failed_condition = cond;
                    continue; // Skip this step
                }
            }

            // Delay if specified
            if (step.delay_ms > 0) {
                std.Thread.sleep(step.delay_ms * std.time.ns_per_ms);
            }

            // Execute action (will be handled by M1 cortex)
            result.executed_count += 1;
        }

        result.total_duration_ms = @intCast(@max(0, std.time.milliTimestamp() - start));
        return result;
    }

    fn checkCondition(self: *const Sequencer, cond: SequenceStep.Condition, fn_ptr: ?SequenceStep.CustomCheckFn) bool {
        return switch (cond) {
            .build_ok => self.context.build_ok,
            .tests_pass => self.context.tests_pass,
            .farm_idle_exists => self.context.farm_idle_count > 0,
            .arena_exists => self.context.arena_exists,
            .custom_check => if (fn_ptr) |f| f(&self.context) else false,
            .health_critical => self.context.ouroboros_score < 50.0,
            .health_good => self.context.ouroboros_score >= 70.0,
            .dirty_exists => self.context.dirty_files > 0,
            .farm_has_leaders => self.context.farm_idle_count >= 3,
            .farm_best_ppl_good => self.context.farm_best_ppl < 10.0,
            .arena_stale => self.context.stale_arena_hours > 24,
            .has_uncommitted => self.context.has_uncommitted,
        };
    }

    /// Update context from current senses
    pub fn updateContext(self: *Sequencer, senses: qt.SenseResult) void {
        self.context.build_ok = senses.build_ok;
        self.context.tests_pass = senses.test_rate >= 80;
        self.context.farm_idle_count = senses.farm_idle_count;
        self.context.arena_exists = senses.arena_battles > 0;
        // v2: extended context
        self.context.ouroboros_score = senses.ouroboros_score;
        self.context.dirty_files = senses.dirty_files;
        self.context.farm_best_ppl = senses.farm_best_ppl;
        self.context.stale_arena_hours = senses.stale_arena_hours;
        self.context.has_uncommitted = senses.dirty_files > 0;
    }
};

pub const SequenceResult = struct {
    success: bool,
    executed_count: u8,
    total_duration_ms: u64,
    failed_at: ?u8 = null,
    failed_condition: ?SequenceStep.Condition = null,
};

// ═══════════════════════════════════════════════════════════════════════════════
// GOAL PLANNER — High-level goals → action sequences
// ═══════════════════════════════════════════════════════════════════════════════

pub const Goal = enum {
    heal_system,
    check_farm,
    cleanup_cloud,
    research_update,
    assess_health,
    emergency_shutdown,

    pub fn label(self: Goal) []const u8 {
        return switch (self) {
            .heal_system => "Heal System",
            .check_farm => "Check Farm",
            .cleanup_cloud => "Cleanup Cloud",
            .research_update => "Research Update",
            .assess_health => "Assess Health",
            .emergency_shutdown => "Emergency Shutdown",
        };
    }

    pub fn priority(self: Goal) u8 {
        return switch (self) {
            .emergency_shutdown => 100,
            .heal_system => 80,
            .assess_health => 60,
            .check_farm => 40,
            .cleanup_cloud => 30,
            .research_update => 10,
        };
    }
};

/// Plan a sequence from a high-level goal
pub fn planFromGoal(goal: Goal) ActionSequence {
    return switch (goal) {
        .heal_system => PredefinedSequences.fullHeal(),
        .check_farm => PredefinedSequences.farmHealthCheck(),
        .cleanup_cloud => PredefinedSequences.cloudCleanup(),
        .research_update => PredefinedSequences.researchCycle(),
        .assess_health => blk: {
            var seq = ActionSequence{};
            @memcpy(seq.name[0.."assess_health".len], "assess_health");
            seq.name_len = "assess_health".len;
            seq.steps[0] = .{ .action = .doctor_scan };
            seq.steps[1] = .{ .action = .farm_status };
            seq.steps[2] = .{ .action = .arena_status };
            seq.steps[3] = .{ .action = .ouroboros_status };
            seq.step_count = 4;
            break :blk seq;
        },
        .emergency_shutdown => blk: {
            var seq = ActionSequence{};
            @memcpy(seq.name[0.."emergency_stop".len], "emergency_stop");
            seq.name_len = "emergency_stop".len;
            seq.steps[0] = .{ .action = .notify }; // Send alert
            seq.step_count = 1;
            break :blk seq;
        },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOTOR PLAN OUTPUT — What PMC sends to M1
// ═══════════════════════════════════════════════════════════════════════════════

/// Motor plan: a ready-to-execute plan for M1
pub const MotorPlan = struct {
    sequence: ActionSequence,
    created_at: i64,
    priority: u8,
    source_goal: Goal,

    pub fn init(goal: Goal) MotorPlan {
        return .{
            .sequence = planFromGoal(goal),
            .created_at = std.time.milliTimestamp(),
            .priority = goal.priority(),
            .source_goal = goal,
        };
    }
};

/// Plan queue - PMC queues plans for M1
pub const PlanQueue = struct {
    plans: [8]MotorPlan = undefined,
    head: u8 = 0,
    tail: u8 = 0,
    count: u8 = 0,

    pub fn push(self: *PlanQueue, plan: MotorPlan) bool {
        if (self.count >= 8) return false; // Full
        self.plans[self.tail] = plan;
        self.tail = (self.tail + 1) % 8;
        self.count += 1;
        return true;
    }

    pub fn pop(self: *PlanQueue) ?MotorPlan {
        if (self.count == 0) return null;
        const plan = self.plans[self.head];
        self.head = (self.head + 1) % 8;
        self.count -= 1;
        return plan;
    }

    pub fn peek(self: *const PlanQueue) ?MotorPlan {
        if (self.count == 0) return null;
        return self.plans[self.head];
    }

    pub fn len(self: *const PlanQueue) u8 {
        return self.count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — ActionSequence addStep" {
    var seq = ActionSequence{};
    try seq.addStep(.doctor_quick);
    try std.testing.expectEqual(@as(u8, 1), seq.step_count);
    try std.testing.expectEqual(.doctor_quick, seq.steps[0].action);
}

test "Premotor — ActionSequence full" {
    var seq = ActionSequence{};
    var i: u8 = 0;
    while (i < MAX_SEQUENCE_STEPS) : (i += 1) {
        try seq.addStep(.doctor_scan);
    }
    try std.testing.expectError(error.SequenceFull, seq.addStep(.doctor_scan));
}

test "Premotor — PredefinedSequences fullHeal" {
    const seq = PredefinedSequences.fullHeal();
    try std.testing.expectEqual(@as(u8, 4), seq.step_count);
    try std.testing.expectEqual(.doctor_scan, seq.steps[0].action);
    try std.testing.expectEqual(.doctor_quick, seq.steps[1].action);
    try std.testing.expectEqual(.ouroboros_cycle, seq.steps[2].action);
    try std.testing.expectEqual(.doctor_heal, seq.steps[3].action);
}

test "Premotor — PlanQueue push/pop" {
    var queue = PlanQueue{};
    const plan = MotorPlan.init(.heal_system);

    try std.testing.expect(queue.push(plan));
    try std.testing.expectEqual(@as(u8, 1), queue.len());

    const popped = queue.pop().?;
    try std.testing.expectEqual(.heal_system, popped.source_goal);
}

test "Premotor — planFromGoal" {
    const seq = planFromGoal(.assess_health);
    try std.testing.expectEqual(@as(u8, 4), seq.step_count);
}

test "Premotor — Goal priority" {
    try std.testing.expectEqual(@as(u8, 100), Goal.emergency_shutdown.priority());
    try std.testing.expectEqual(@as(u8, 80), Goal.heal_system.priority());
    try std.testing.expectEqual(@as(u8, 10), Goal.research_update.priority());
}

test "Premotor — SequenceStep condition evaluation" {
    // No condition = always executable
    const step_no_cond = SequenceStep{ .action = .doctor_scan };
    try std.testing.expect(step_no_cond.condition == null);

    // With build_ok condition
    const step_with_cond = SequenceStep{
        .action = .doctor_quick,
        .condition = .build_ok,
    };
    try std.testing.expect(step_with_cond.condition != null);
    try std.testing.expectEqual(SequenceStep.Condition.build_ok, step_with_cond.condition.?);
}

test "Premotor — ConditionContext default values" {
    const ctx = SequenceStep.ConditionContext{};
    try std.testing.expectEqual(false, ctx.build_ok);
    try std.testing.expectEqual(false, ctx.tests_pass);
    try std.testing.expectEqual(@as(u8, 0), ctx.farm_idle_count);
    try std.testing.expectEqual(false, ctx.arena_exists);
}

test "Premotor — MotorPlan initialization" {
    const plan = MotorPlan.init(.heal_system);
    try std.testing.expectEqual(.heal_system, plan.source_goal);
    try std.testing.expect(plan.sequence.step_count > 0);
    try std.testing.expect(plan.priority <= 100);
}

test "Premotor — Goal enum coverage" {
    inline for (std.meta.fields(Goal)) |field| {
        const goal = @field(Goal, field.name);
        try std.testing.expect(goal.priority() <= 100);
        try std.testing.expect(goal.priority() >= 0);
        try std.testing.expect(goal.label().len > 0);
    }
}

test "Premotor — SequenceStep delays" {
    const step = SequenceStep{
        .action = .farm_recycle,
        .delay_ms = 5000,
    };
    try std.testing.expectEqual(@as(u64, 5000), step.delay_ms);
}

test "Premotor — PredefinedSequences farmHealthCheck" {
    const seq = PredefinedSequences.farmHealthCheck();
    try std.testing.expectEqual(@as(u8, 2), seq.step_count);
    try std.testing.expectEqual(.farm_status, seq.steps[0].action);
    try std.testing.expectEqual(.farm_evolve_status, seq.steps[1].action);
}

test "Premotor — PlanQueue multiple operations" {
    var queue = PlanQueue{};
    const plan1 = MotorPlan.init(.heal_system);
    const plan2 = MotorPlan.init(.check_farm);

    _ = queue.push(plan1);
    _ = queue.push(plan2);
    try std.testing.expectEqual(@as(u8, 2), queue.len());

    const first = queue.pop().?;
    try std.testing.expectEqual(.heal_system, first.source_goal);

    const second = queue.pop().?;
    try std.testing.expectEqual(.check_farm, second.source_goal);

    try std.testing.expect(queue.pop() == null);
}

test "Premotor — Condition enum coverage" {
    inline for (std.meta.fields(SequenceStep.Condition)) |field| {
        _ = @field(SequenceStep.Condition, field.name);
    }
}

test "Premotor — FailureAction variants" {
    const stop_action: SequenceStep.FailureAction = .stop;
    const skip_action: SequenceStep.FailureAction = .skip;
    const retry_action: SequenceStep.FailureAction = .retry;
    const fallback_action: SequenceStep.FailureAction = .{ .fallback = .doctor_scan };

    _ = stop_action;
    _ = skip_action;
    _ = retry_action;
    _ = fallback_action;
}

test "Premotor — ActionSequence addStepWithCondition" {
    var seq = ActionSequence{};
    try seq.addStepWithCondition(.doctor_quick, .build_ok);
    try std.testing.expectEqual(@as(u8, 1), seq.step_count);
    try std.testing.expectEqual(.doctor_quick, seq.steps[0].action);
    try std.testing.expectEqual(SequenceStep.Condition.build_ok, seq.steps[0].condition.?);
}

test "Premotor — ActionSequence addDelayedStep" {
    var seq = ActionSequence{};
    try seq.addDelayedStep(.farm_recycle, 5000);
    try std.testing.expectEqual(@as(u8, 1), seq.step_count);
    try std.testing.expectEqual(.farm_recycle, seq.steps[0].action);
    try std.testing.expectEqual(@as(u64, 5000), seq.steps[0].delay_ms);
}

test "Premotor — PredefinedSequences cloudCleanup" {
    const seq = PredefinedSequences.cloudCleanup();
    try std.testing.expectEqual(@as(u8, 2), seq.step_count);
    try std.testing.expectEqual(.cloud_spawn, seq.steps[0].action);
    try std.testing.expectEqual(.cloud_cleanup, seq.steps[1].action);
}

test "Premotor — PlanQueue overflow" {
    var queue = PlanQueue{};
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        const plan = MotorPlan.init(.heal_system);
        _ = queue.push(plan);
    }
    try std.testing.expectEqual(@as(u8, 8), queue.len());

    // 9th push should fail
    const overflow_plan = MotorPlan.init(.check_farm);
    try std.testing.expect(!queue.push(overflow_plan));
}

test "Premotor — PlanQueue peek" {
    var queue = PlanQueue{};
    const plan = MotorPlan.init(.heal_system);

    try std.testing.expect(queue.peek() == null);

    _ = queue.push(plan);
    const peeked = queue.peek().?;
    try std.testing.expectEqual(.heal_system, peeked.source_goal);

    // Peek doesn't remove
    try std.testing.expectEqual(@as(u8, 1), queue.len());
}

test "Premotor — Sequencer checkCondition build_ok" {
    var seq = Sequencer.init(std.testing.allocator);
    seq.context.build_ok = true;
    try std.testing.expect(seq.checkCondition(.build_ok, null));

    seq.context.build_ok = false;
    try std.testing.expect(!seq.checkCondition(.build_ok, null));
}

test "Premotor — Sequencer checkCondition health_critical" {
    var seq = Sequencer.init(std.testing.allocator);
    seq.context.ouroboros_score = 30.0;
    try std.testing.expect(seq.checkCondition(.health_critical, null));

    seq.context.ouroboros_score = 70.0;
    try std.testing.expect(!seq.checkCondition(.health_critical, null));
}

test "Premotor — Sequencer checkCondition farm_has_leaders" {
    var seq = Sequencer.init(std.testing.allocator);
    seq.context.farm_idle_count = 5;
    try std.testing.expect(seq.checkCondition(.farm_has_leaders, null));

    seq.context.farm_idle_count = 2;
    try std.testing.expect(!seq.checkCondition(.farm_has_leaders, null));
}

test "Premotor — Sequencer updateContext" {
    var seq = Sequencer.init(std.testing.allocator);
    const senses = qt.SenseResult{
        .build_ok = true,
        .test_rate = 90,
        .farm_idle_count = 7,
        .arena_battles = 5,
        .ouroboros_score = 85.0,
        .dirty_files = 3,
        .farm_best_ppl = 8.5,
        .stale_arena_hours = 12,
    };

    seq.updateContext(senses);
    try std.testing.expect(seq.context.build_ok);
    try std.testing.expect(seq.context.tests_pass);
    try std.testing.expectEqual(@as(u8, 7), seq.context.farm_idle_count);
    try std.testing.expect(seq.context.arena_exists);
    try std.testing.expectApproxEqAbs(@as(f32, 85.0), seq.context.ouroboros_score, 0.01);
    try std.testing.expectEqual(@as(u16, 3), seq.context.dirty_files);
    try std.testing.expect(seq.context.has_uncommitted);
}

test "Premotor — PredefinedSequences checkAndHeal" {
    const seq = PredefinedSequences.checkAndHeal();
    try std.testing.expectEqual(@as(u8, 2), seq.step_count);
    try std.testing.expectEqual(.doctor_scan, seq.steps[0].action);
    try std.testing.expectEqual(.doctor_heal, seq.steps[1].action);
    try std.testing.expectEqual(SequenceStep.Condition.health_critical, seq.steps[1].condition.?);
    try std.testing.expectEqual(@as(u64, 1000), seq.steps[1].delay_ms);
}

test "Premotor — PredefinedSequences farmCycle" {
    const seq = PredefinedSequences.farmCycle();
    try std.testing.expectEqual(@as(u8, 2), seq.step_count);
    try std.testing.expectEqual(.farm_status, seq.steps[0].action);
    try std.testing.expectEqual(.farm_evolve_step, seq.steps[1].action);
    try std.testing.expectEqual(SequenceStep.Condition.farm_has_leaders, seq.steps[1].condition.?);
}

test "Premotor — PredefinedSequences fullBackup" {
    const seq = PredefinedSequences.fullBackup();
    try std.testing.expectEqual(@as(u8, 2), seq.step_count);
    try std.testing.expectEqual(.git_commit_state, seq.steps[0].action);
    try std.testing.expectEqual(.git_push, seq.steps[1].action);
}

test "Premotor — ActionSequence nameStr" {
    var seq = ActionSequence{};
    @memcpy(seq.name[0.."test_name".len], "test_name");
    seq.name_len = "test_name".len;
    try std.testing.expectEqualStrings("test_name", seq.nameStr());
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEQUENCE STEP TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — SequenceStep default values" {
    const step = SequenceStep{
        .action = .doctor_scan,
    };

    try std.testing.expectEqual(@as(u64, 0), step.delay_ms);
    try std.testing.expect(step.condition == null);
    try std.testing.expectEqual(SequenceStep.FailureAction.stop, step.on_failure);
    try std.testing.expect(step.custom_check_fn == null);
}

test "Premotor — SequenceStep with all fields" {
    const step = SequenceStep{
        .action = .farm_recycle,
        .delay_ms = 1000,
        .condition = .build_ok,
        .on_failure = .retry,
        .custom_check_fn = null,
    };

    try std.testing.expectEqual(.farm_recycle, step.action);
    try std.testing.expectEqual(@as(u64, 1000), step.delay_ms);
    try std.testing.expectEqual(SequenceStep.Condition.build_ok, step.condition.?);
    try std.testing.expectEqual(SequenceStep.FailureAction.retry, step.on_failure);
}

test "Premotor — SequenceStep with fallback action" {
    const step = SequenceStep{
        .action = .doctor_scan,
        .on_failure = .{ .fallback = .doctor_quick },
    };

    try std.testing.expectEqual(.doctor_scan, step.action);
    try std.testing.expectEqual(.doctor_quick, step.on_failure.fallback);
}

test "Premotor — SequenceStep condition all values" {
    const conditions = [_]SequenceStep.Condition{
        .build_ok,
        .tests_pass,
        .farm_idle_exists,
        .arena_exists,
        .custom_check,
        .health_critical,
        .health_good,
        .dirty_exists,
        .farm_has_leaders,
        .farm_best_ppl_good,
        .arena_stale,
        .has_uncommitted,
    };

    for (conditions) |cond| {
        const step = SequenceStep{
            .action = .doctor_scan,
            .condition = cond,
        };
        try std.testing.expectEqual(cond, step.condition.?);
    }
}

test "Premotor — SequenceStep FailureAction skip" {
    const step = SequenceStep{
        .action = .doctor_scan,
        .on_failure = .skip,
    };

    try std.testing.expectEqual(SequenceStep.FailureAction.skip, step.on_failure);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION SEQUENCE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — ActionSequence default values" {
    const seq = ActionSequence{};

    try std.testing.expectEqual(@as(usize, 0), seq.name_len);
    try std.testing.expectEqual(@as(u8, 0), seq.step_count);
    try std.testing.expect(!seq.parallel);
    try std.testing.expectEqual(@as(u8, 3), seq.max_retries);
    try std.testing.expectEqual(@as(u32, 300), seq.timeout_sec);
}

test "Premotor — ActionSequence parallel flag" {
    var seq = ActionSequence{};
    seq.parallel = true;

    try std.testing.expect(seq.parallel);
}

test "Premotor — ActionSequence max_retries" {
    var seq = ActionSequence{};
    seq.max_retries = 10;

    try std.testing.expectEqual(@as(u8, 10), seq.max_retries);
}

test "Premotor — ActionSequence timeout_sec" {
    var seq = ActionSequence{};
    seq.timeout_sec = 600;

    try std.testing.expectEqual(@as(u32, 600), seq.timeout_sec);
}

test "Premotor — ActionSequence nameStr empty" {
    const seq = ActionSequence{};

    try std.testing.expectEqual(@as(usize, 0), seq.nameStr().len);
}

test "Premotor — ActionSequence nameStr truncated" {
    var seq = ActionSequence{};
    // Fill name buffer
    @memset(seq.name[0..], 'x');
    seq.name_len = seq.name.len;

    const name = seq.nameStr();
    try std.testing.expectEqual(@as(usize, 64), name.len);
}

test "Premotor — ActionSequence addStep multiple" {
    var seq = ActionSequence{};

    try seq.addStep(.doctor_scan);
    try seq.addStep(.doctor_quick);
    try seq.addStep(.farm_status);

    try std.testing.expectEqual(@as(u8, 3), seq.step_count);
    try std.testing.expectEqual(.doctor_scan, seq.steps[0].action);
    try std.testing.expectEqual(.doctor_quick, seq.steps[1].action);
    try std.testing.expectEqual(.farm_status, seq.steps[2].action);
}

test "Premotor — ActionSequence addStepWithCondition skip" {
    var seq = ActionSequence{};
    try seq.addStepWithCondition(.doctor_quick, .build_ok);

    try std.testing.expectEqual(.doctor_quick, seq.steps[0].action);
    try std.testing.expectEqual(SequenceStep.FailureAction.skip, seq.steps[0].on_failure);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREDEFINED SEQUENCES TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — PredefinedSequences researchCycle" {
    const seq = PredefinedSequences.researchCycle();
    try std.testing.expectEqual(@as(u8, 2), seq.step_count);
    try std.testing.expectEqual(.research_sacred, seq.steps[0].action);
    try std.testing.expectEqual(.patent_status, seq.steps[1].action);
    try std.testing.expectEqual(@as(u64, 500), seq.steps[1].delay_ms);
}

test "Premotor — PredefinedSequences arenaBattle" {
    const seq = PredefinedSequences.arenaBattle();
    try std.testing.expectEqual(@as(u8, 2), seq.step_count);
    try std.testing.expectEqual(.arena_battle, seq.steps[0].action);
    try std.testing.expectEqual(.experience_save, seq.steps[1].action);
    try std.testing.expectEqual(@as(u64, 1000), seq.steps[0].delay_ms);
    try std.testing.expectEqual(@as(u64, 500), seq.steps[1].delay_ms);
}

test "Premotor — PredefinedSequences researchScan" {
    const seq = PredefinedSequences.researchScan();
    try std.testing.expectEqual(@as(u8, 2), seq.step_count);
    try std.testing.expectEqual(.research_sacred, seq.steps[0].action);
    try std.testing.expectEqual(.experience_save, seq.steps[1].action);
    try std.testing.expectEqual(@as(u64, 2000), seq.steps[0].delay_ms);
}

test "Premotor — PredefinedSequences fullHeal delays" {
    const seq = PredefinedSequences.fullHeal();

    try std.testing.expectEqual(@as(u64, 0), seq.steps[0].delay_ms);
    try std.testing.expectEqual(@as(u64, 500), seq.steps[1].delay_ms);
    try std.testing.expectEqual(@as(u64, 1000), seq.steps[2].delay_ms);
    try std.testing.expectEqual(@as(u64, 500), seq.steps[3].delay_ms);
}

test "Premotor — PredefinedSequences fullHeal conditions" {
    const seq = PredefinedSequences.fullHeal();

    try std.testing.expect(seq.steps[0].condition == null);
    try std.testing.expectEqual(SequenceStep.Condition.build_ok, seq.steps[1].condition.?);
}

test "Premotor — PredefinedSequences cloudCleanup custom_check" {
    const seq = PredefinedSequences.cloudCleanup();

    try std.testing.expectEqual(SequenceStep.Condition.custom_check, seq.steps[0].condition.?);
    try std.testing.expectEqual(.cloud_spawn, seq.steps[0].action);
}

test "Premotor — PredefinedSequences fullBackup conditions" {
    const seq = PredefinedSequences.fullBackup();

    try std.testing.expectEqual(SequenceStep.Condition.has_uncommitted, seq.steps[0].condition.?);
    try std.testing.expectEqual(SequenceStep.Condition.has_uncommitted, seq.steps[1].condition.?);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEQUENCER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — Sequencer init" {
    const seq = Sequencer.init(std.testing.allocator);

    try std.testing.expectEqual(@as(f32, 0.0), seq.context.ouroboros_score);
    try std.testing.expectEqual(@as(u16, 0), seq.context.dirty_files);
}

test "Premotor — Sequencer checkCondition tests_pass" {
    var seq = Sequencer.init(std.testing.allocator);

    seq.context.tests_pass = true;
    try std.testing.expect(seq.checkCondition(.tests_pass, null));

    seq.context.tests_pass = false;
    try std.testing.expect(!seq.checkCondition(.tests_pass, null));
}

test "Premotor — Sequencer checkCondition farm_idle_exists" {
    var seq = Sequencer.init(std.testing.allocator);

    seq.context.farm_idle_count = 0;
    try std.testing.expect(!seq.checkCondition(.farm_idle_exists, null));

    seq.context.farm_idle_count = 1;
    try std.testing.expect(seq.checkCondition(.farm_idle_exists, null));
}

test "Premotor — Sequencer checkCondition arena_exists" {
    var seq = Sequencer.init(std.testing.allocator);

    seq.context.arena_exists = true;
    try std.testing.expect(seq.checkCondition(.arena_exists, null));
}

test "Premotor — Sequencer checkCondition health_good" {
    var seq = Sequencer.init(std.testing.allocator);

    seq.context.ouroboros_score = 80.0;
    try std.testing.expect(seq.checkCondition(.health_good, null));

    seq.context.ouroboros_score = 60.0;
    try std.testing.expect(!seq.checkCondition(.health_good, null));
}

test "Premotor — Sequencer checkCondition dirty_exists" {
    var seq = Sequencer.init(std.testing.allocator);

    seq.context.dirty_files = 0;
    try std.testing.expect(!seq.checkCondition(.dirty_exists, null));

    seq.context.dirty_files = 5;
    try std.testing.expect(seq.checkCondition(.dirty_exists, null));
}

test "Premotor — Sequencer checkCondition farm_best_ppl_good" {
    var seq = Sequencer.init(std.testing.allocator);

    seq.context.farm_best_ppl = 5.0;
    try std.testing.expect(seq.checkCondition(.farm_best_ppl_good, null));

    seq.context.farm_best_ppl = 15.0;
    try std.testing.expect(!seq.checkCondition(.farm_best_ppl_good, null));
}

test "Premotor — Sequencer checkCondition arena_stale" {
    var seq = Sequencer.init(std.testing.allocator);

    seq.context.stale_arena_hours = 30;
    try std.testing.expect(seq.checkCondition(.arena_stale, null));

    seq.context.stale_arena_hours = 10;
    try std.testing.expect(!seq.checkCondition(.arena_stale, null));
}

test "Premotor — Sequencer checkCondition has_uncommitted" {
    var seq = Sequencer.init(std.testing.allocator);

    seq.context.has_uncommitted = true;
    try std.testing.expect(seq.checkCondition(.has_uncommitted, null));

    seq.context.has_uncommitted = false;
    try std.testing.expect(!seq.checkCondition(.has_uncommitted, null));
}

test "Premotor — Sequencer checkCondition custom_check null" {
    var seq = Sequencer.init(std.testing.allocator);

    // Null custom check should return false
    try std.testing.expect(!seq.checkCondition(.custom_check, null));
}

test "Premotor — Sequencer updateContext edge cases" {
    var seq = Sequencer.init(std.testing.allocator);

    // Test rate below threshold
    const senses_low = qt.SenseResult{
        .build_ok = true,
        .test_rate = 70,
    };
    seq.updateContext(senses_low);
    try std.testing.expect(!seq.context.tests_pass);

    // Test rate at threshold
    const senses_threshold = qt.SenseResult{
        .build_ok = true,
        .test_rate = 80,
    };
    seq.updateContext(senses_threshold);
    try std.testing.expect(seq.context.tests_pass);
}

test "Premotor — Sequencer updateContext dirty_files to has_uncommitted" {
    var seq = Sequencer.init(std.testing.allocator);

    const senses = qt.SenseResult{
        .dirty_files = 5,
    };
    seq.updateContext(senses);

    try std.testing.expect(seq.context.has_uncommitted);
    try std.testing.expectEqual(@as(u16, 5), seq.context.dirty_files);
}

test "Premotor — Sequencer executeSequence simple" {
    var seq = Sequencer.init(std.testing.allocator);

    var action_seq = ActionSequence{};
    try action_seq.addStep(.doctor_scan);

    const result = try seq.executeSequence(&action_seq);

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 1), result.executed_count);
    try std.testing.expect(result.failed_at == null);
}

test "Premotor — Sequencer executeSequence with skip" {
    var seq = Sequencer.init(std.testing.allocator);

    var action_seq = ActionSequence{};
    try action_seq.addStep(.doctor_scan);
    try action_seq.addStepWithCondition(.doctor_quick, .build_ok);

    const result = try seq.executeSequence(&action_seq);

    // Second step should be skipped since build_ok is false
    try std.testing.expectEqual(@as(u8, 1), result.executed_count);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEQUENCE RESULT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — SequenceResult default values" {
    const result = SequenceResult{
        .success = true,
        .executed_count = 5,
        .total_duration_ms = 1000,
    };

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 5), result.executed_count);
    try std.testing.expectEqual(@as(u64, 1000), result.total_duration_ms);
    try std.testing.expect(result.failed_at == null);
    try std.testing.expect(result.failed_condition == null);
}

test "Premotor — SequenceResult with failure" {
    const result = SequenceResult{
        .success = false,
        .executed_count = 2,
        .total_duration_ms = 500,
        .failed_at = 2,
        .failed_condition = .build_ok,
    };

    try std.testing.expect(!result.success);
    try std.testing.expectEqual(@as(u8, 2), result.failed_at.?);
    try std.testing.expectEqual(SequenceStep.Condition.build_ok, result.failed_condition.?);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOTOR PLAN TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — MotorPlan init emergency_shutdown" {
    const plan = MotorPlan.init(.emergency_shutdown);

    try std.testing.expectEqual(.emergency_shutdown, plan.source_goal);
    try std.testing.expectEqual(@as(u8, 100), plan.priority);
    try std.testing.expect(plan.created_at > 0);
}

test "Premotor — MotorPlan init research_update" {
    const plan = MotorPlan.init(.research_update);

    try std.testing.expectEqual(.research_update, plan.source_goal);
    try std.testing.expectEqual(@as(u8, 10), plan.priority);
}

test "Premotor — MotorPlan sequence from goal" {
    const plan = MotorPlan.init(.check_farm);

    try std.testing.expectEqual(.check_farm, plan.source_goal);
    try std.testing.expect(plan.sequence.step_count > 0);
}

test "Premotor — MotorPlan created_at is reasonable" {
    const before = std.time.milliTimestamp();
    const plan = MotorPlan.init(.heal_system);
    const after = std.time.milliTimestamp();

    try std.testing.expect(plan.created_at >= before);
    try std.testing.expect(plan.created_at <= after);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLAN QUEUE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — PlanQueue push returns false when full" {
    var queue = PlanQueue{};
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        const plan = MotorPlan.init(.heal_system);
        _ = queue.push(plan);
    }

    const overflow_plan = MotorPlan.init(.check_farm);
    try std.testing.expect(!queue.push(overflow_plan));
}

test "Premotor — PlanQueue pop returns null when empty" {
    var queue = PlanQueue{};

    try std.testing.expect(queue.pop() == null);
}

test "Premotor — PlanQueue FIFO order" {
    var queue = PlanQueue{};

    const plan1 = MotorPlan.init(.heal_system);
    const plan2 = MotorPlan.init(.check_farm);
    const plan3 = MotorPlan.init(.cleanup_cloud);

    _ = queue.push(plan1);
    _ = queue.push(plan2);
    _ = queue.push(plan3);

    try std.testing.expectEqual(.heal_system, queue.pop().?.source_goal);
    try std.testing.expectEqual(.check_farm, queue.pop().?.source_goal);
    try std.testing.expectEqual(.cleanup_cloud, queue.pop().?.source_goal);
}

test "Premotor — PlanQueue wraparound" {
    var queue = PlanQueue{};

    // Fill and empty to cause wraparound
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        const plan = MotorPlan.init(.heal_system);
        _ = queue.push(plan);
    }

    // Empty half
    var j: u8 = 0;
    while (j < 4) : (j += 1) {
        _ = queue.pop();
    }

    // Add new plans
    const new_plan = MotorPlan.init(.check_farm);
    try std.testing.expect(queue.push(new_plan));

    try std.testing.expectEqual(@as(u8, 5), queue.len());
}

test "Premotor — PlanQueue peek after multiple ops" {
    var queue = PlanQueue{};

    const plan1 = MotorPlan.init(.heal_system);
    const plan2 = MotorPlan.init(.check_farm);

    _ = queue.push(plan1);
    _ = queue.push(plan2);

    // Peek should return first plan
    const peeked = queue.peek().?;
    try std.testing.expectEqual(.heal_system, peeked.source_goal);

    // Pop and peek again
    _ = queue.pop();
    const peeked2 = queue.peek().?;
    try std.testing.expectEqual(.check_farm, peeked2.source_goal);
}

test "Premotor — PlanQueue len tracks correctly" {
    var queue = PlanQueue{};

    try std.testing.expectEqual(@as(u8, 0), queue.len());

    const plan1 = MotorPlan.init(.heal_system);
    _ = queue.push(plan1);
    try std.testing.expectEqual(@as(u8, 1), queue.len());

    _ = queue.pop();
    try std.testing.expectEqual(@as(u8, 0), queue.len());
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOAL TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — Goal label all goals" {
    try std.testing.expectEqualStrings("Heal System", Goal.heal_system.label());
    try std.testing.expectEqualStrings("Check Farm", Goal.check_farm.label());
    try std.testing.expectEqualStrings("Cleanup Cloud", Goal.cleanup_cloud.label());
    try std.testing.expectEqualStrings("Research Update", Goal.research_update.label());
    try std.testing.expectEqualStrings("Assess Health", Goal.assess_health.label());
    try std.testing.expectEqualStrings("Emergency Shutdown", Goal.emergency_shutdown.label());
}

test "Premotor — Goal priority all goals" {
    try std.testing.expectEqual(@as(u8, 100), Goal.emergency_shutdown.priority());
    try std.testing.expectEqual(@as(u8, 80), Goal.heal_system.priority());
    try std.testing.expectEqual(@as(u8, 60), Goal.assess_health.priority());
    try std.testing.expectEqual(@as(u8, 40), Goal.check_farm.priority());
    try std.testing.expectEqual(@as(u8, 30), Goal.cleanup_cloud.priority());
    try std.testing.expectEqual(@as(u8, 10), Goal.research_update.priority());
}

test "Premotor — Goal priority ordering" {
    try std.testing.expect(Goal.emergency_shutdown.priority() > Goal.heal_system.priority());
    try std.testing.expect(Goal.heal_system.priority() > Goal.assess_health.priority());
    try std.testing.expect(Goal.assess_health.priority() > Goal.check_farm.priority());
    try std.testing.expect(Goal.check_farm.priority() > Goal.cleanup_cloud.priority());
    try std.testing.expect(Goal.cleanup_cloud.priority() > Goal.research_update.priority());
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONDITION CONTEXT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — ConditionContext default extended values" {
    const ctx = SequenceStep.ConditionContext{};

    try std.testing.expectEqual(@as(f32, 0.0), ctx.ouroboros_score);
    try std.testing.expectEqual(@as(u16, 0), ctx.dirty_files);
    try std.testing.expectEqual(@as(f32, 999.0), ctx.farm_best_ppl);
    try std.testing.expectEqual(@as(u16, 0), ctx.stale_arena_hours);
    try std.testing.expect(!ctx.has_uncommitted);
}

test "Premotor — ConditionContext with values" {
    const ctx = SequenceStep.ConditionContext{
        .build_ok = true,
        .tests_pass = true,
        .farm_idle_count = 5,
        .arena_exists = true,
        .ouroboros_score = 75.0,
        .dirty_files = 10,
        .farm_best_ppl = 5.5,
        .stale_arena_hours = 48,
        .has_uncommitted = true,
    };

    try std.testing.expect(ctx.build_ok);
    try std.testing.expect(ctx.tests_pass);
    try std.testing.expectEqual(@as(u8, 5), ctx.farm_idle_count);
    try std.testing.expect(ctx.arena_exists);
    try std.testing.expectEqual(@as(f32, 75.0), ctx.ouroboros_score);
    try std.testing.expectEqual(@as(u16, 10), ctx.dirty_files);
    try std.testing.expectEqual(@as(f32, 5.5), ctx.farm_best_ppl);
    try std.testing.expectEqual(@as(u16, 48), ctx.stale_arena_hours);
    try std.testing.expect(ctx.has_uncommitted);
}

test "Premotor — ConditionContext boundary values" {
    const ctx = SequenceStep.ConditionContext{
        .farm_idle_count = 255,
        .dirty_files = 1000,
        .stale_arena_hours = 65535,
    };

    try std.testing.expectEqual(@as(u8, 255), ctx.farm_idle_count);
    try std.testing.expectEqual(@as(u16, 1000), ctx.dirty_files);
    try std.testing.expectEqual(@as(u16, 65535), ctx.stale_arena_hours);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLAN FROM GOAL TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — planFromGoal heal_system" {
    const seq = planFromGoal(.heal_system);

    try std.testing.expectEqual(@as(u8, 4), seq.step_count);
    try std.testing.expectEqual(.doctor_scan, seq.steps[0].action);
}

test "Premotor — planFromGoal emergency_shutdown" {
    const seq = planFromGoal(.emergency_shutdown);

    try std.testing.expectEqual(@as(u8, 1), seq.step_count);
    try std.testing.expectEqual(.notify, seq.steps[0].action);
}

test "Premotor — planFromGoal cleanup_cloud" {
    const seq = planFromGoal(.cleanup_cloud);

    try std.testing.expectEqual(@as(u8, 2), seq.step_count);
    try std.testing.expectEqual(.cloud_spawn, seq.steps[0].action);
}

test "Premotor — planFromGoal research_update" {
    const seq = planFromGoal(.research_update);

    try std.testing.expectEqual(@as(u8, 2), seq.step_count);
    try std.testing.expectEqual(.research_sacred, seq.steps[0].action);
}

test "Premotor — planFromGoal assess_health steps" {
    const seq = planFromGoal(.assess_health);

    try std.testing.expectEqual(@as(u8, 4), seq.step_count);
    try std.testing.expectEqual(.doctor_scan, seq.steps[0].action);
    try std.testing.expectEqual(.farm_status, seq.steps[1].action);
    try std.testing.expectEqual(.arena_status, seq.steps[2].action);
    try std.testing.expectEqual(.ouroboros_status, seq.steps[3].action);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Premotor — MAX_SEQUENCE_STEPS constant" {
    try std.testing.expectEqual(@as(u8, 10), MAX_SEQUENCE_STEPS);
}

test "Premotor — MAX_PARALLEL_BRANCHES constant" {
    try std.testing.expectEqual(@as(u8, 3), MAX_PARALLEL_BRANCHES);
}

