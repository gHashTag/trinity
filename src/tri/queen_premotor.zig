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
