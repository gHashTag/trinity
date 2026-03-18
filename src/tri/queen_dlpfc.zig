// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN DLPFC (Dorsolateral Prefrontal Cortex) — Autonomous Decision Engine
// ═══════════════════════════════════════════════════════════════════════════════
// S³AI Brain Module — Central decision engine tying all modules together
// Neuro: Executive function, working memory, cognitive flexibility, planning
// Trinity: READ → THINK → ACT → SPEAK autonomous cycle
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const array_list = std.array_list;

const qt = @import("queen_types.zig");
const thalamus = @import("thalamus.zig");
const voice_engine = @import("voice_engine.zig");
const queen_actions = @import("queen_actions.zig");
const queen_ofc = @import("queen_ofc.zig");
const basal_ganglia = @import("basal_ganglia.zig");
const cerebellum = @import("cerebellum.zig");
const queen_policy = @import("queen_policy.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// DECISION — What Queen wants to do
// ═══════════════════════════════════════════════════════════════════════════════

pub const Decision = struct {
    action: qt.ActionKind,
    urgency: basal_ganglia.Urgency,
    reason: []const u8,
    confidence: f32 = 0.0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DECISION CONTEXT — All sensor data for decision making
// ═══════════════════════════════════════════════════════════════════════════════

pub const DecisionContext = struct {
    allocator: Allocator,
    farm: thalamus.FarmStatus,
    issues: thalamus.GitHubIssues,
    mu_heartbeat: voice_engine.MuHeartbeat,
    config: qt.QueenConfig,
    state: *qt.QueenState,
    counters: *queen_policy.ActionCounters,
    incidents: *queen_policy.IncidentMemory,

    // Derived metrics
    ouroboros_score: f32 = 0.0,
    dirty_files: u16 = 0,
    build_ok: bool = true,

    /// Check if we should take any auto-action
    pub fn shouldAutoAct(self: *const DecisionContext) bool {
        return self.config.allow_auto_actions and self.config.daemon;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CYCLE STATE — Track decision loop progress
// ═══════════════════════════════════════════════════════════════════════════════

pub const CycleState = struct {
    iteration: u64 = 0,
    last_decision: ?Decision = null,
    decision_count: u64 = 0,
    running: bool = true,
    start_time: i64 = 0,

    pub fn init() CycleState {
        return .{
            .start_time = std.time.timestamp(),
        };
    }

    pub fn uptimeSeconds(self: *const CycleState) i64 {
        return std.time.timestamp() - self.start_time;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN AUTONOMOUS LOOP — READ → THINK → ACT → SPEAK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runUnifiedLoop(allocator: Allocator, config: qt.QueenConfig) !void {
    var state = qt.QueenState{
        .started_at = std.time.timestamp(),
    };
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();
    var cycle_state = CycleState.init();

    const print = std.debug.print;

    print("\n{s}" ++ qt.E_CROWN ++ " Queen DLPFC — Autonomous Decision Engine{s}\n", .{
        @import("tri_colors.zig").GOLDEN, @import("tri_colors.zig").RESET,
    });
    print("  interval: {d}s | daemon: {s} | auto_level: L{d}\n\n", .{
        config.interval_sec,
        if (config.daemon) "YES" else "NO",
        config.max_auto_level,
    });

    while (cycle_state.running) {
        cycle_state.iteration += 1;

        // Build context
        var ctx = DecisionContext{
            .allocator = allocator,
            .config = config,
            .state = &state,
            .counters = &counters,
            .incidents = &incidents,
        };

        // PHASE 1: READ — Gather all sensor data
        try readSenses(allocator, &ctx);

        // PHASE 2: THINK — Decide what to do
        const decision = try decide(&ctx);

        // PHASE 3: ACT — Execute action (or skip if none)
        var result = qt.ActionResult{ .success = true };
        if (decision) |d| {
            cycle_state.last_decision = d;
            cycle_state.decision_count += 1;
            result = try act(&ctx, d);
        }

        // PHASE 4: SPEAK — Report via OFC
        try speak(&ctx, decision, result);

        // Sleep until next cycle
        if (!config.daemon) {
            cycle_state.running = false;
        } else {
            print("\n{s}Cycle #{d} complete. Sleeping {d}s...{s}\n\n", .{
                @import("tri_colors.zig").GRAY,
                cycle_state.iteration,
                config.interval_sec,
                @import("tri_colors.zig").RESET,
            });
            std.time.sleep(config.interval_sec * 1_000_000_000);
        }
    }

    print("\n{s}" ++ qt.E_CROWN ++ " Queen DLPFC — Shutdown after {d} cycles, {d} decisions{s}\n\n", .{
        @import("tri_colors.zig").GOLDEN,
        cycle_state.iteration,
        cycle_state.decision_count,
        @import("tri_colors.zig").RESET,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// READ PHASE — Gather sensor data from all Thalamus relays
// ═══════════════════════════════════════════════════════════════════════════════

pub fn readSenses(allocator: Allocator, ctx: *DecisionContext) !void {
    // Relay 12: Farm Status
    ctx.farm = try thalamus.getFarmStatus(allocator);

    // Relay 13: GitHub Issues
    ctx.issues = try thalamus.getGitHubIssues(allocator);

    // Relay 1: Mu Heartbeat
    ctx.mu_heartbeat = thalamus.getMuHeartbeat(allocator);

    // Derived metrics
    ctx.build_ok = ctx.mu_heartbeat.build_ok;
    // TODO: Get ouroboros_score and dirty_files from actual sensors
    ctx.ouroboros_score = 75.0; // Default healthy
    ctx.dirty_files = 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// THINK PHASE — Decision engine using Basal Ganglia
// ═══════════════════════════════════════════════════════════════════════════════

pub fn decide(ctx: *DecisionContext) !?Decision {
    if (!ctx.shouldAutoAct()) {
        return null;
    }

    // Collect candidates from observations
    const CandidateList = array_list.AlignedManaged(basal_ganglia.ActionCandidate, null);
    var candidates = CandidateList.init(ctx.allocator);
    defer candidates.deinit();

    // Rule 1: Build broken → doctor_quick (high urgency)
    if (!ctx.build_ok) {
        try candidates.append(.{
            .kind = .doctor_quick,
            .urgency = .critical,
            .value = 0.9,
            .cost = 0.1,
        });
    }

    // Rule 2: Farm has crashed workers → farm_recycle (high urgency)
    if (ctx.farm.crashed > 3) {
        try candidates.append(.{
            .kind = .farm_recycle,
            .urgency = .high,
            .value = 0.8,
            .cost = 0.3,
        });
    }

    // Rule 3: Best PPL record → celebrate (low urgency, just notification)
    if (ctx.farm.best_ppl < 5.0) {
        try candidates.append(.{
            .kind = .notify,
            .urgency = .normal,
            .value = 0.5,
            .cost = 0.0,
        });
    }

    // Rule 4: Open agent:spawn issues → cloud_spawn
    if (ctx.issues.agent_spawn > 0) {
        try candidates.append(.{
            .kind = .cloud_spawn,
            .urgency = .high,
            .value = 0.7,
            .cost = 0.4,
        });
    }

    // Rule 5: Idle workers > 5 → farm_recycle
    const idle_count = ctx.farm.total_services - ctx.farm.active - ctx.farm.crashed;
    if (idle_count > 5) {
        try candidates.append(.{
            .kind = .farm_recycle,
            .urgency = .normal,
            .value = 0.6,
            .cost = 0.3,
        });
    }

    // Select via Basal Ganglia action selection
    const selected = basal_ganglia.selectAction(candidates.items);

    if (selected) |action| {
        // Find the candidate to get urgency
        var urgency = basal_ganglia.Urgency.normal;
        var confidence: f32 = 0.5;
        for (candidates.items) |c| {
            if (c.kind == action) {
                urgency = c.urgency;
                confidence = c.value;
                break;
            }
        }

        const reason = switch (action) {
            .doctor_quick => "Build broken, needs healing",
            .farm_recycle => "Farm has idle/crashed workers",
            .notify => "Celebrating farm progress",
            .cloud_spawn => "Agent spawn issues detected",
            else => "Routine action",
        };

        return Decision{
            .action = action,
            .urgency = urgency,
            .reason = reason,
            .confidence = confidence,
        };
    }

    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACT PHASE — Execute selected action
// ═══════════════════════════════════════════════════════════════════════════════

pub fn act(ctx: *DecisionContext, decision: Decision) !qt.ActionResult {
    // Check policy before executing
    const verdict = queen_policy.checkPolicy(
        decision.action,
        ctx.config,
        ctx.counters,
        ctx.incidents,
    );

    if (!verdict.isAllowed()) {
        // Log denial
        queen_policy.writeAuditEntry(
            "auto-denied",
            decision.action,
            verdict,
            false,
            verdict.reason(),
        );

        return qt.ActionResult{
            .success = false,
            .output_len = 0,
            .duration_ms = 0,
        };
    }

    // Execute action
    const result = queen_actions.execute(ctx.allocator, decision.action);

    // Record action
    queen_actions.recordAutoAction(ctx.state, decision.action, ctx.counters);

    // Log incident
    ctx.incidents.record(
        if (result.success) queen_policy.IncidentKind.auto_action else queen_policy.IncidentKind.auto_action_fail,
        decision.action,
        result.success,
        decision.reason,
    );

    // Audit trail
    queen_policy.writeAuditEntry(
        "auto-action",
        decision.action,
        verdict,
        result.success,
        decision.reason,
    );

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEAK PHASE — Report decision and result via OFC
// ═══════════════════════════════════════════════════════════════════════════════

pub fn speak(ctx: *DecisionContext, decision: ?Decision, result: qt.ActionResult) !void {
    const mood = queen_ofc.inferMood(ctx.build_ok, ctx.ouroboros_score, false);

    var report_buf: [1024]u8 = undefined;
    var offset: usize = 0;

    // Header
    const header = std.fmt.bufPrint(
        report_buf[offset..],
        "{s} Queen {s} — Cycle #{d}\n\n",
        .{ mood.emoji(), mood.label(), ctx.state.cycle },
    ) catch return;
    offset += header.len;

    // Farm status
    const farm_line = std.fmt.bufPrint(
        report_buf[offset..],
        "{s} Farm: {d}/{d} active, PPL {d:.1}",
        .{ qt.E_DNA, ctx.farm.active, ctx.farm.total_services, ctx.farm.best_ppl },
    ) catch return;
    offset += farm_line.len;

    if (ctx.farm.best_ppl_service_len > 0) {
        const best_line = std.fmt.bufPrint(
            report_buf[offset..],
            " ({s})\n",
            .{ctx.farm.bestPplServiceStr()},
        ) catch return;
        offset += best_line.len;
    } else {
        const newline = "\n";
        if (offset + newline.len <= report_buf.len) {
            @memcpy(report_buf[offset..][0..newline.len], newline);
            offset += newline.len;
        }
    }

    // Mu heartbeat
    const mu_line = std.fmt.bufPrint(
        report_buf[offset..],
        "{s} Build: {s} | Wake #{d}\n",
        .{ qt.E_BRAIN, if (ctx.build_ok) "OK" else "FAIL", ctx.mu_heartbeat.wake },
    ) catch return;
    offset += mu_line.len;

    // Decision report
    if (decision) |d| {
        const decision_line = std.fmt.bufPrint(
            report_buf[offset..],
            "{s} Action: {s} ({s})\n",
            .{ d.action.emojiIcon(), d.action.label(), d.reason },
        ) catch return;
        offset += decision_line.len;

        // Result
        const result_line = std.fmt.bufPrint(
            report_buf[offset..],
            "  Result: {s} ({d}ms)\n",
            .{ if (result.success) "OK" else "FAIL", result.duration_ms },
        ) catch return;
        offset += result_line.len;
    } else {
        const no_action = "No action needed\n";
        if (offset + no_action.len <= report_buf.len) {
            @memcpy(report_buf[offset..][0..no_action.len], no_action);
            offset += no_action.len;
        }
    }

    const report = report_buf[0..offset];

    // Send via OFC
    ctx.state.cycle +|= 1;
    try queen_ofc.sendReport(ctx.allocator, mood, report);
}

/// Format decision report for Telegram
fn formatDecisionReport(decision: Decision, result: qt.ActionResult) []const u8 {
    _ = decision;
    _ = result;
    return ""; // TODO: Implement if needed
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENTRY POINT — Start Queen DLPFC as autonomous daemon
// ═══════════════════════════════════════════════════════════════════════════════

pub fn start(config: qt.QueenConfig) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try runUnifiedLoop(gpa.allocator(), config);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn health() CellHealth {
    return CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = std.time.timestamp(),
    };
}

pub const CellHealth = struct {
    status: Status = .healthy,
    cycle: u32 = 0,
    last_check: i64 = 0,

    pub const Status = enum {
        healthy,
        weak,
        broken,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "dlpfc — decide returns valid action on broken build" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{ .build_ok = false },
        .config = .{ .allow_auto_actions = true, .daemon = true },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
        .build_ok = false,
    };

    const decision = try decide(&ctx);
    try std.testing.expect(decision != null);
    try std.testing.expectEqual(qt.ActionKind.doctor_quick, decision.?.action);
}

test "dlpfc — decide returns null when no action needed" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{ .total_services = 10, .active = 10, .best_ppl = 10.0 },
        .issues = .{},
        .mu_heartbeat = .{ .build_ok = true },
        .config = .{ .allow_auto_actions = true, .daemon = true },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
        .build_ok = true,
    };

    const decision = try decide(&ctx);
    try std.testing.expect(decision == null);
}

test "dlpfc — decide detects crashed workers" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{ .total_services = 10, .active = 5, .crashed = 5, .timestamp = std.time.timestamp() },
        .issues = .{},
        .mu_heartbeat = .{ .build_ok = true },
        .config = .{ .allow_auto_actions = true, .daemon = true, .max_auto_level = 2 },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
        .build_ok = true,
    };

    const decision = try decide(&ctx);
    try std.testing.expect(decision != null);
    try std.testing.expectEqual(qt.ActionKind.farm_recycle, decision.?.action);
}

test "dlpfc — CycleState init" {
    const state = CycleState.init();
    try std.testing.expectEqual(@as(u64, 0), state.iteration);
    try std.testing.expect(state.last_decision == null);
    try std.testing.expect(state.running);
}

test "dlpfc — CycleState uptime" {
    var state = CycleState.init();
    const uptime1 = state.uptimeSeconds();
    try std.testing.expect(uptime1 >= 0);
    // Uptime should increase (might be 0 or 1 second)
    const uptime2 = state.uptimeSeconds();
    try std.testing.expect(uptime2 >= uptime1);
}

test "dlpfc — readSenses populates context" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
    };

    try readSenses(std.testing.allocator, &ctx);

    // Should have non-zero timestamp
    try std.testing.expect(ctx.farm.timestamp > 0);
}

test "dlpfc — act respects policy level" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{ .max_auto_level = 0 }, // Read-only only
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
        .build_ok = false,
    };

    const decision = Decision{
        .action = .doctor_quick, // L1 action
        .urgency = .critical,
        .reason = "test",
        .confidence = 0.9,
    };

    const result = try act(&ctx, decision);
    try std.testing.expect(!result.success); // Should be denied by policy
}

test "dlpfc — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "dlpfc — DecisionContext shouldAutoAct" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    const ctx1 = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{ .allow_auto_actions = false, .daemon = true },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
    };
    try std.testing.expect(!ctx1.shouldAutoAct());

    const ctx2 = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{ .allow_auto_actions = true, .daemon = false },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
    };
    try std.testing.expect(!ctx2.shouldAutoAct());

    const ctx3 = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{ .allow_auto_actions = true, .daemon = true },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
    };
    try std.testing.expect(ctx3.shouldAutoAct());
}

test "dlpfc — Decision struct fields" {
    const decision = Decision{
        .action = .farm_recycle,
        .urgency = .high,
        .reason = "Test reason",
        .confidence = 0.85,
    };
    try std.testing.expectEqual(qt.ActionKind.farm_recycle, decision.action);
    try std.testing.expectEqual(basal_ganglia.Urgency.high, decision.urgency);
    try std.testing.expectEqualStrings("Test reason", decision.reason);
    try std.testing.expectApproxEqAbs(@as(f32, 0.85), decision.confidence, 0.01);
}

test "dlpfc — decide with agent spawn issues" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{ .agent_spawn = 2 },
        .mu_heartbeat = .{ .build_ok = true },
        .config = .{ .allow_auto_actions = true, .daemon = true },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
        .build_ok = true,
    };

    const decision = try decide(&ctx);
    try std.testing.expect(decision != null);
    try std.testing.expectEqual(qt.ActionKind.cloud_spawn, decision.?.action);
}

test "dlpfc — decide with best PPL celebration" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{ .total_services = 10, .active = 10, .best_ppl = 4.5 },
        .issues = .{},
        .mu_heartbeat = .{ .build_ok = true },
        .config = .{ .allow_auto_actions = true, .daemon = true },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
        .build_ok = true,
    };

    const decision = try decide(&ctx);
    try std.testing.expect(decision != null);
    try std.testing.expectEqual(qt.ActionKind.notify, decision.?.action);
}
