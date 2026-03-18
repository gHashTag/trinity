// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN ACTIONS — Execute tri subcommands via subprocess
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const qt = @import("queen_types.zig");
const queen_policy = @import("queen_policy.zig");

const Allocator = std.mem.Allocator;
const ActionKind = qt.ActionKind;
const ActionResult = qt.ActionResult;
const print = std.debug.print;

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTE ACTION
// ═══════════════════════════════════════════════════════════════════════════════

pub fn execute(allocator: Allocator, kind: ActionKind) ActionResult {
    const argv = kindToArgv(kind);
    const start = std.time.milliTimestamp();

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 64 * 1024,
    }) catch |err| {
        var r = ActionResult{ .success = false };
        const msg = std.fmt.bufPrint(&r.output, "exec error: {s}", .{@errorName(err)}) catch "";
        r.output_len = msg.len;
        r.duration_ms = @intCast(@max(0, std.time.milliTimestamp() - start));
        return r;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const elapsed: u64 = @intCast(@max(0, std.time.milliTimestamp() - start));

    var r = ActionResult{
        .success = result.term.Exited == 0,
        .duration_ms = elapsed,
    };

    // Copy stdout (prefer) or stderr into output buffer
    const src = if (result.stdout.len > 0) result.stdout else result.stderr;
    const len = @min(src.len, r.output.len);
    @memcpy(r.output[0..len], src[0..len]);
    r.output_len = len;

    return r;
}

fn kindToArgv(kind: ActionKind) []const []const u8 {
    return switch (kind) {
        // L0 — Read-Only
        .farm_status => &.{ "./zig-out/bin/tri", "farm", "status" },
        .arena_status => &.{ "./zig-out/bin/tri", "arena", "leaderboard" },
        .doctor_scan => &.{ "./zig-out/bin/tri", "doctor", "scan" },
        .train_status => &.{ "./zig-out/bin/tri", "train", "status" },
        .train_diagnose => &.{ "./zig-out/bin/tri", "train", "diagnose", "." },
        .experiment_chart => &.{ "./zig-out/bin/tri", "experiment", "chart" },
        .patent_status => &.{ "./zig-out/bin/tri", "patent", "status" },
        .research_sacred => &.{ "./zig-out/bin/tri", "research", "sacred" },
        .ouroboros_status => &.{ "./zig-out/bin/tri", "ouroboros", "status" },
        .experience_recall => &.{ "./zig-out/bin/tri", "experience", "mistakes" },
        .farm_evolve_status => &.{ "./zig-out/bin/tri", "farm", "evolve", "status" },
        .swarm_status => &.{ "./zig-out/bin/tri", "swarm", "status" },
        // L1 — Soft Write
        .doctor_quick => &.{ "./zig-out/bin/tri", "doctor", "quick" },
        .doctor_heal => &.{ "./zig-out/bin/tri", "doctor", "heal" },
        .ouroboros_cycle => &.{ "./zig-out/bin/tri", "ouroboros", "--cycles", "1" },
        .git_commit_state => &.{ "./zig-out/bin/tri", "git", "commit", "chore(queen): auto-commit state" },
        .git_push => &.{ "./zig-out/bin/tri", "git", "push" },
        .issue_comment => &.{ "./zig-out/bin/tri", "issue", "comment", "357", "--body", "Queen auto-update" },
        .notify => &.{ "./zig-out/bin/tri", "notify", "Queen heartbeat" },
        .arena_battle => &.{ "./zig-out/bin/tri", "code", "arena", "battle", "Queen auto-battle" },
        .experience_save => &.{ "./zig-out/bin/tri", "experience", "save" },
        .fmt => &.{ "./zig-out/bin/tri", "fmt" },
        // L2 — Dangerous (always with safety flags)
        .farm_recycle => &.{ "./zig-out/bin/tri", "farm", "recycle" },
        .farm_evolve_step => &.{ "./zig-out/bin/tri", "farm", "evolve", "step", "--protect-primary" },
        .cloud_spawn => &.{ "./zig-out/bin/tri", "cloud", "spawn-all" },
        .cloud_kill => &.{ "./zig-out/bin/tri", "cloud", "cleanup" },
        .cloud_cleanup => &.{ "./zig-out/bin/tri", "cloud", "cleanup" },
        .issue_create => &.{ "./zig-out/bin/tri", "issue", "create", "Queen auto-issue" },
        .swarm_decompose => &.{ "./zig-out/bin/tri", "swarm", "decompose" },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-DECISION ENGINE (v3: policy-gated)
// ═══════════════════════════════════════════════════════════════════════════════

/// What action does Queen want to take? (sense-based, first-match-wins, 12 rules)
pub fn desiredAction(state: *const qt.QueenState, senses: qt.SenseResult) ?ActionKind {
    // Rule 1: Build broken → doctor_quick
    if (!senses.build_ok and state.last_build_heal_cycle != state.cycle) {
        return .doctor_quick;
    }
    // Rule 2: Build broken + doctor_quick failed 2x → doctor_heal
    if (!senses.build_ok and senses.doctor_quick_fails >= 2) {
        return .doctor_heal;
    }
    // Rule 3: Dirty overload → git commit
    if (senses.dirty_files > 50) {
        return .git_commit_state;
    }
    // Rule 4: Dirty overload + committed → git push
    if (senses.dirty_files > 50 and state.last_auto_action_ts > 0) {
        return .git_push;
    }
    // Rule 5: Low ouroboros score → ouroboros cycle
    if (senses.ouroboros_score < 40.0 and senses.ouroboros_score > 0.0) {
        return .ouroboros_cycle;
    }
    // Rule 6: Farm alert + no comment in 2h → issue comment
    if (senses.farm_best_ppl < 999.0) {
        const now = std.time.timestamp();
        if (senses.last_issue_comment_ts == 0 or (now - senses.last_issue_comment_ts) > 7200) {
            return .issue_comment;
        }
    }
    // Rule 7: Stale arena (>24h no battle) → arena battle
    if (senses.stale_arena_hours > 24) {
        return .arena_battle;
    }
    // Rule 8: Experience episodes grew → save
    if (senses.experience_count > 0) {
        // Save periodically (this is a heuristic — fires once per cycle if episodes exist)
        return .experience_save;
    }
    // Rule 9: Farm idle > 3 services → recycle (L2)
    if (senses.farm_idle_count > 3) {
        return .farm_recycle;
    }
    // Rule 10: Farm has bottom performers → evolve step (L2)
    if (senses.farm_services > 5 and senses.farm_best_ppl < 50.0) {
        return .farm_evolve_step;
    }
    // Rule 11: agent:spawn issues + containers < 10 → cloud spawn (L2)
    if (senses.agent_spawn_issues > 0 and senses.finished_containers < 10) {
        return .cloud_spawn;
    }
    // Rule 12: Finished containers > 5 → cleanup (L2)
    if (senses.finished_containers > 5) {
        return .cloud_cleanup;
    }
    return null;
}

/// v3: Policy-gated auto-action. Returns the action + verdict.
/// Caller decides whether to execute based on verdict.
pub const AutoDecision = struct {
    action: ActionKind,
    verdict: queen_policy.PolicyVerdict,
};

pub fn maybeAutoAction(
    state: *const qt.QueenState,
    senses: qt.SenseResult,
    config: qt.QueenConfig,
    counters: *const queen_policy.ActionCounters,
    incidents: *const queen_policy.IncidentMemory,
) ?AutoDecision {
    const action = desiredAction(state, senses) orelse return null;
    const verdict = queen_policy.checkPolicy(action, config, counters, incidents);
    return .{ .action = action, .verdict = verdict };
}

/// Record that an auto-action was taken (updates both legacy state and v3 counters)
pub fn recordAutoAction(state: *qt.QueenState, kind: ActionKind, counters: *queen_policy.ActionCounters) void {
    state.auto_actions_this_hour +|= 1;
    state.last_auto_action_ts = std.time.timestamp();
    if (kind == .doctor_quick or kind == .doctor_heal) {
        state.last_build_heal_cycle = state.cycle;
    }
    counters.record(kind);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TTY — Print action result
// ═══════════════════════════════════════════════════════════════════════════════

pub fn printActionResult(kind: ActionKind, result: ActionResult) void {
    const colors = @import("tri_colors.zig");
    print("\n{s}{s} {s} — {s}{s}\n", .{
        if (result.success) colors.GREEN else colors.RED,
        kind.emojiIcon(),
        kind.label(),
        if (result.success) "OK" else "FAIL",
        colors.RESET,
    });
    print("  Duration: {d}ms\n", .{result.duration_ms});
    if (result.output_len > 0) {
        const preview_len = @min(result.output_len, 512);
        print("  Output:\n  {s}\n", .{result.output[0..preview_len]});
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Queen actions — kindToArgv" {
    const argv = kindToArgv(.doctor_quick);
    try std.testing.expectEqualStrings("./zig-out/bin/tri", argv[0]);
    try std.testing.expectEqualStrings("doctor", argv[1]);
    try std.testing.expectEqualStrings("quick", argv[2]);

    // v4: new actions
    const farm_argv = kindToArgv(.farm_recycle);
    try std.testing.expectEqualStrings("farm", farm_argv[1]);
    try std.testing.expectEqualStrings("recycle", farm_argv[2]);

    const evolve_argv = kindToArgv(.farm_evolve_step);
    try std.testing.expectEqualStrings("farm", evolve_argv[1]);
    try std.testing.expectEqualStrings("evolve", evolve_argv[2]);
    try std.testing.expectEqualStrings("--protect-primary", evolve_argv[4]);

    const push_argv = kindToArgv(.git_push);
    try std.testing.expectEqualStrings("git", push_argv[1]);
    try std.testing.expectEqualStrings("push", push_argv[2]);
}

test "Queen actions — desiredAction build broken" {
    const state = qt.QueenState{ .cycle = 1 };
    const senses = qt.SenseResult{ .build_ok = false };
    const action = desiredAction(&state, senses);
    try std.testing.expectEqual(ActionKind.doctor_quick, action.?);
}

test "Queen actions — desiredAction dirty overload" {
    const state = qt.QueenState{};
    const senses = qt.SenseResult{ .build_ok = true, .dirty_files = 60 };
    const action = desiredAction(&state, senses);
    try std.testing.expectEqual(ActionKind.git_commit_state, action.?);
}

test "Queen actions — desiredAction low score" {
    const state = qt.QueenState{};
    const senses = qt.SenseResult{ .build_ok = true, .ouroboros_score = 30.0 };
    const action = desiredAction(&state, senses);
    try std.testing.expectEqual(ActionKind.ouroboros_cycle, action.?);
}

test "Queen actions — desiredAction no action needed" {
    const state = qt.QueenState{};
    const senses = qt.SenseResult{ .build_ok = true, .ouroboros_score = 80.0, .experience_count = 0 };
    const action = desiredAction(&state, senses);
    try std.testing.expectEqual(@as(?ActionKind, null), action);
}

test "Queen actions — desiredAction doctor_heal after quick fails" {
    const state = qt.QueenState{ .cycle = 1, .last_build_heal_cycle = 1 };
    const senses = qt.SenseResult{ .build_ok = false, .doctor_quick_fails = 2 };
    const action = desiredAction(&state, senses);
    try std.testing.expectEqual(ActionKind.doctor_heal, action.?);
}

test "Queen actions — desiredAction stale arena" {
    const state = qt.QueenState{};
    const senses = qt.SenseResult{ .build_ok = true, .ouroboros_score = 80.0, .stale_arena_hours = 25, .experience_count = 0 };
    const action = desiredAction(&state, senses);
    try std.testing.expectEqual(ActionKind.arena_battle, action.?);
}

test "Queen actions — desiredAction farm idle triggers recycle" {
    const state = qt.QueenState{};
    const senses = qt.SenseResult{ .build_ok = true, .ouroboros_score = 80.0, .farm_idle_count = 5, .experience_count = 0, .stale_arena_hours = 0 };
    const action = desiredAction(&state, senses);
    try std.testing.expectEqual(ActionKind.farm_recycle, action.?);
}

test "Queen actions — desiredAction cloud cleanup" {
    const state = qt.QueenState{};
    const senses = qt.SenseResult{ .build_ok = true, .ouroboros_score = 80.0, .finished_containers = 7, .experience_count = 0, .stale_arena_hours = 0 };
    const action = desiredAction(&state, senses);
    try std.testing.expectEqual(ActionKind.cloud_cleanup, action.?);
}

test "Queen actions — maybeAutoAction policy allowed" {
    const state = qt.QueenState{ .cycle = 1 };
    const senses = qt.SenseResult{ .build_ok = false };
    const config = qt.QueenConfig{ .max_auto_level = 1 };
    var counters = queen_policy.ActionCounters{};
    const memory = queen_policy.IncidentMemory.init();
    const decision = maybeAutoAction(&state, senses, config, &counters, &memory);
    try std.testing.expect(decision != null);
    try std.testing.expectEqual(ActionKind.doctor_quick, decision.?.action);
    try std.testing.expect(decision.?.verdict.isAllowed());
}

test "Queen actions — maybeAutoAction policy denied" {
    const state = qt.QueenState{ .cycle = 1 };
    const senses = qt.SenseResult{ .build_ok = false };
    const config = qt.QueenConfig{ .max_auto_level = 0 }; // read-only only
    var counters = queen_policy.ActionCounters{};
    const memory = queen_policy.IncidentMemory.init();
    const decision = maybeAutoAction(&state, senses, config, &counters, &memory);
    try std.testing.expect(decision != null);
    try std.testing.expect(!decision.?.verdict.isAllowed());
}

test "Queen actions — recordAutoAction" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    recordAutoAction(&state, .doctor_quick, &counters);
    try std.testing.expectEqual(@as(u8, 1), state.auto_actions_this_hour);
    try std.testing.expect(state.last_auto_action_ts > 0);
    try std.testing.expectEqual(state.cycle, state.last_build_heal_cycle);
    try std.testing.expectEqual(@as(u8, 1), counters.getCount(.doctor_quick));
}
