// @origin(manual) @regen(pending)
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
const queen_vmpfc = @import("queen_vmpfc.zig");

// Faculty board integration (lazy import to avoid circular deps)
const faculty_cortex = @import("cortex.zig");
const faculty_types = @import("faculty_types.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// DECISION — What Queen wants to do
// ═══════════════════════════════════════════════════════════════════════════════

pub const Decision = struct {
    action: qt.ActionKind,
    urgency: basal_ganglia.Urgency,
    reason: [256]u8 = undefined,
    reason_len: usize = 0,
    confidence: f32 = 0.0,

    pub fn reasonStr(self: *const Decision) []const u8 {
        return self.reason[0..self.reason_len];
    }

    fn setReason(self: *Decision, text: []const u8) void {
        const len = @min(text.len, self.reason.len);
        @memcpy(self.reason[0..len], text[0..len]);
        self.reason_len = len;
    }
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

    // Faculty board integration
    faculty_metrics: ?FacultyMetrics = null,
    trend_analysis: ?TrendAnalysis = null,

    /// Check if we should take any auto-action
    pub fn shouldAutoAct(self: *const DecisionContext) bool {
        return self.config.allow_auto_actions and self.config.daemon;
    }

    /// Check if trend analysis suggests we should act
    pub fn hasWarningTrends(self: *const DecisionContext) bool {
        return if (self.trend_analysis) |ta| ta.hasWarning() else false;
    }

    /// Get suggested goals from trend analysis
    pub fn getSuggestedGoals(self: *const DecisionContext) []const SuggestedGoal {
        _ = self; // TODO: populate from trend_analysis
        // This would be populated by readSenses phase
        return &.{};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FACULTY METRICS — Real-time monitoring from faculty_board
// ═══════════════════════════════════════════════════════════════════════════════

/// Detailed metrics collected from faculty_board
pub const FacultyMetrics = struct {
    snapshot: faculty_types.FacultySnapshot,
    delta: faculty_types.FacultyDelta,
    collected_at: i64 = 0,

    pub fn timestamp(self: FacultyMetrics) i64 {
        return self.collected_at;
    }
};

/// Trend analysis — predicting problems before they occur
pub const TrendAnalysis = struct {
    direction: TrendDirection = .stable,
    urgency: basal_ganglia.Urgency = .normal,
    confidence: f32 = 0.0,

    // Specific trend indicators
    compile_trend: TrendDirection = .stable,
    v_zone_trend: TrendDirection = .stable,
    dirty_trend: TrendDirection = .stable,
    faculty_trend: TrendDirection = .stable,

    // Predicted problems (0-3 predictions)
    predictions: [3]Prediction = .{Prediction{}} ** 3,
    prediction_count: u8 = 0,

    pub fn hasWarning(self: *const TrendAnalysis) bool {
        return self.direction == .deteriorating or self.direction == .critical;
    }

    pub fn summary(self: *const TrendAnalysis) []const u8 {
        return switch (self.direction) {
            .improving => "System metrics improving",
            .stable => "All metrics stable",
            .deteriorating => "Metrics declining, attention needed",
            .critical => "Critical degradation detected",
        };
    }
};

pub const TrendDirection = enum {
    improving,
    stable,
    deteriorating,
    critical,

    pub fn emoji(self: TrendDirection) []const u8 {
        return switch (self) {
            .improving => "\xe2\x96\xb2", // ▲
            .stable => "\xe2\x96\xbc", // ▶ (stable arrow)
            .deteriorating => "\xe2\x96\xbc", // ▼
            .critical => "\xf0\x9f\x9a\xa8", // 🚨
        };
    }

    pub fn color(self: TrendDirection) []const u8 {
        return switch (self) {
            .improving => "\x1b[38;2;0;229;153m", // green
            .stable => "\x1b[38;2;156;156;160m", // gray
            .deteriorating => "\x1b[38;2;255;165;0m", // orange
            .critical => "\x1b[38;2;239;68;68m", // red
        };
    }
};

pub const Prediction = struct {
    kind: PredictionKind = .unknown,
    description: [128]u8 = undefined,
    description_len: usize = 0,
    time_to_event_hours: f32 = 0.0,
    suggested_action: qt.ActionKind = .farm_status,

    pub fn descriptionStr(self: *const Prediction) []const u8 {
        return self.description[0..self.description_len];
    }

    fn setDescription(self: *Prediction, text: []const u8) void {
        const len = @min(text.len, self.description.len);
        @memcpy(self.description[0..len], text[0..len]);
        self.description_len = len;
    }
};

pub const PredictionKind = enum {
    unknown,
    compile_failure_imminent,
    v_zone_drift,
    faculty_loss,
    dirty_overflow,
    build_break,
};

/// Get detailed metrics from faculty_board
pub fn getFacultyMetrics(allocator: Allocator) !FacultyMetrics {
    const now = std.time.timestamp();

    // Collect current snapshot from faculty_board
    const snapshot = try faculty_cortex.collectSnapshot(allocator);

    // For now, delta is all zeros (no previous snapshot comparison)
    // TODO: Implement history tracking for proper trend analysis
    return FacultyMetrics{
        .snapshot = snapshot,
        .delta = .{}, // Empty delta = no change detected
        .collected_at = now,
    };
}

/// Analyze trends and predict problems before they occur
/// Returns TrendAnalysis with predictions and suggested actions
pub fn analyzeTrends(
    allocator: Allocator,
    current: FacultyMetrics,
    history: []const FacultyMetrics,
) !TrendAnalysis {
    _ = allocator; // TODO: use for history persistence
    var analysis = TrendAnalysis{
        .confidence = if (history.len >= 2) 0.7 else 0.3,
    };

    // Need at least one previous snapshot for trend analysis
    if (!current.delta.has_prev or history.len == 0) {
        analysis.direction = .stable;
        return analysis;
    }

    const prev = history[history.len - 1];

    // Analyze compile rate trend
    if (current.delta.compile_rate_delta > 5) {
        analysis.compile_trend = .improving;
    } else if (current.delta.compile_rate_delta < -5) {
        analysis.compile_trend = .deteriorating;
        analysis.direction = .deteriorating;
        analysis.urgency = .high;

        // Predict compile failure if trend continues
        if (current.snapshot.compile_rate < 60) {
            addPrediction(&analysis, .{
                .kind = .compile_failure_imminent,
                .time_to_event_hours = 24.0,
                .suggested_action = .doctor_quick,
            }, "Compile rate < 60%, expecting build failure");
        }
    }

    // Analyze V-zone trend (using v_number directly)
    const v_current = current.snapshot.v_number;
    const v_prev = if (prev.delta.has_prev)
        @as(f64, @floatFromInt(current.delta.prev_compile_rate)) / 100.0 * 1.618
    else
        v_current;

    if (v_current > v_prev + 0.1) {
        analysis.v_zone_trend = .improving;
    } else if (v_current < v_prev - 0.1) {
        analysis.v_zone_trend = .deteriorating;
        if (analysis.direction != .deteriorating) {
            analysis.direction = .deteriorating;
        }

        // Predict V-zone drift
        if (current.snapshot.v_zone == .drift) {
            addPrediction(&analysis, .{
                .kind = .v_zone_drift,
                .time_to_event_hours = 48.0,
                .suggested_action = .doctor_heal,
            }, "V-zone in DRIFT, system health declining");
        }
    }

    // Analyze dirty files trend
    if (current.delta.dirty_delta > 10) {
        analysis.dirty_trend = .deteriorating;
        if (analysis.direction != .critical) {
            analysis.direction = .deteriorating;
        }

        if (current.snapshot.dirty_files > 50) {
            addPrediction(&analysis, .{
                .kind = .dirty_overflow,
                .time_to_event_hours = 12.0,
                .suggested_action = .git_commit_state,
            }, "Dirty files > 50, repository state messy");
        }
    } else if (current.delta.dirty_delta < -10) {
        analysis.dirty_trend = .improving;
    }

    // Analyze active faculty trend
    const active_now = current.snapshot.activeFaculty();
    if (current.delta.active_delta < -1) {
        analysis.faculty_trend = .deteriorating;
        if (analysis.direction != .critical) {
            analysis.direction = .deteriorating;
        }

        if (active_now < 3) {
            addPrediction(&analysis, .{
                .kind = .faculty_loss,
                .time_to_event_hours = 6.0,
                .suggested_action = .farm_status,
            }, "Active faculty < 3, agents may be down");
        }
    } else if (current.delta.active_delta > 1) {
        analysis.faculty_trend = .improving;
    }

    // Determine overall direction from component trends
    var deteriorating_count: u8 = 0;
    if (analysis.compile_trend == .deteriorating) deteriorating_count += 1;
    if (analysis.v_zone_trend == .deteriorating) deteriorating_count += 1;
    if (analysis.dirty_trend == .deteriorating) deteriorating_count += 1;
    if (analysis.faculty_trend == .deteriorating) deteriorating_count += 1;

    if (deteriorating_count >= 3) {
        analysis.direction = .critical;
        analysis.urgency = .critical;
    } else if (deteriorating_count >= 1) {
        analysis.direction = .deteriorating;
        analysis.urgency = .high;
    } else if (analysis.compile_trend == .improving or analysis.v_zone_trend == .improving) {
        analysis.direction = .improving;
    }

    return analysis;
}

fn addPrediction(analysis: *TrendAnalysis, pred: Prediction, description: []const u8) void {
    if (analysis.prediction_count >= 3) return;

    var p = pred;
    p.setDescription(description);
    analysis.predictions[analysis.prediction_count] = p;
    analysis.prediction_count += 1;
}

/// Generate goals based on trend analysis using VMPFC value assessment
/// Returns action suggestions with ROI scoring
pub fn generateGoalsFromTrends(
    allocator: Allocator,
    analysis: TrendAnalysis,
    current_ppl: f32,
) ![]const SuggestedGoal {
    var goals = std.ArrayList(SuggestedGoal).init(allocator);

    // For each prediction, generate a goal with VMPFC assessment
    for (analysis.predictions[0..analysis.prediction_count]) |pred| {
        // Copy description to allocator-owned memory
        const reason = try allocator.dupe(u8, pred.descriptionStr());

        var goal = SuggestedGoal{
            .action = pred.suggested_action,
            .priority = if (analysis.direction == .critical) .critical else .high,
            .reason = reason,
        };

        // Get VMPFC value assessment for this action
        if (queen_vmpfc.assessFarmAction(
            allocator,
            if (pred.suggested_action == .farm_recycle) .recycle else if (pred.suggested_action == .doctor_quick) .inject else .evolve,
            current_ppl,
        )) |vmpfc_result| {
            goal.roi = vmpfc_result.roi;
            goal.confidence = vmpfc_result.confidence;
            goal.recommendation = vmpfc_result.recommendation;
        } else |err| {
            goal.roi = 0.5;
            goal.confidence = 0.3;
            goal.recommendation = .wait;
            _ = err;
        }

        try goals.append(goal);
    }

    // Add trend-based goals even without specific predictions
    if (analysis.compile_trend == .deteriorating) {
        const reason = try allocator.dupe(u8, "Compile rate declining, scan needed");
        try goals.append(.{
            .action = .doctor_scan,
            .priority = .high,
            .roi = 3.0,
            .confidence = 0.8,
            .recommendation = .execute,
            .reason = reason,
        });
    }

    if (analysis.v_zone_trend == .deteriorating) {
        const reason = try allocator.dupe(u8, "V-zone drifting, consider healing");
        try goals.append(.{
            .action = .doctor_heal,
            .priority = .normal,
            .roi = 2.0,
            .confidence = 0.6,
            .recommendation = .wait,
            .reason = reason,
        });
    }

    return goals.toOwnedSlice();
}

pub const SuggestedGoal = struct {
    action: qt.ActionKind,
    priority: GoalPriority = .normal,
    roi: f32 = 0.0,
    confidence: f32 = 0.0,
    recommendation: queen_vmpfc.Recommendation = .wait,
    reason: []const u8 = "",
};

pub const GoalPriority = enum {
    low,
    normal,
    high,
    critical,

    pub fn emoji(self: GoalPriority) []const u8 {
        return switch (self) {
            .low => "\xe2\x97\xbb", // ◻
            .normal => "\xe2\x97\xbc", // ◼
            .high => "\xe2\x96\xaa", // ▪
            .critical => "\xf0\x9f\x94\xb4", // 🔴
        };
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

    // Relay 14: Faculty Board metrics (detailed monitoring)
    if (getFacultyMetrics(allocator)) |fm| {
        ctx.faculty_metrics = fm;

        // Update derived metrics from faculty snapshot
        ctx.build_ok = fm.snapshot.build_ok;
        ctx.dirty_files = fm.snapshot.dirty_files;

        // Calculate ouroboros_score from V-number (0-100 scale)
        // V-number ranges 0 to PHI (1.618), map to 0-100
        ctx.ouroboros_score = @as(f32, @floatCast(@min(100.0, fm.snapshot.v_number * 61.8)));
    } else |err| {
        // Faculty board collection failed, continue without it
        _ = err;
        ctx.faculty_metrics = null;
    }

    // Trend analysis (if we have history)
    if (ctx.faculty_metrics) |*fm| {
        const history: []const FacultyMetrics = &.{};
        const trend = analyzeTrends(allocator, fm.*, history) catch |err| {
            _ = err;
            null;
        };
        ctx.trend_analysis = trend;
    }
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

    // Rule 6: TREND-BASED PREDICTIONS — Preemptive action
    if (ctx.trend_analysis) |ta| {
        // Compile rate declining → doctor_scan
        if (ta.compile_trend == .deteriorating) {
            try candidates.append(.{
                .kind = .doctor_scan,
                .urgency = if (ta.direction == .critical) .critical else .high,
                .value = 0.7,
                .cost = 0.2,
            });
        }

        // V-zone drifting → doctor_heal
        if (ta.v_zone_trend == .deteriorating and ta.direction != .critical) {
            try candidates.append(.{
                .kind = .doctor_heal,
                .urgency = .normal,
                .value = 0.5,
                .cost = 0.4,
            });
        }

        // Faculty loss → farm_status to check agents
        if (ta.faculty_trend == .deteriorating) {
            try candidates.append(.{
                .kind = .farm_status,
                .urgency = .normal,
                .value = 0.4,
                .cost = 0.1,
            });
        }

        // Dirty files accumulating → git_commit_state
        if (ta.dirty_trend == .deteriorating and ctx.dirty_files > 20) {
            try candidates.append(.{
                .kind = .git_commit_state,
                .urgency = .normal,
                .value = 0.5,
                .cost = 0.2,
            });
        }

        // Critical trend → escalate urgency
        if (ta.direction == .critical) {
            // Boost priority of first action
            if (candidates.items.len > 0) {
                candidates.items[0].urgency = .critical;
                candidates.items[0].value = @min(1.0, candidates.items[0].value + 0.2);
            }
        }
    }

    // Select via Basal Ganglia action selection
    const selected = basal_ganglia.selectAction(candidates.items);

    if (selected) |action| {
        // Find the candidate to get urgency
        var urgency = basal_ganglia.Urgency.normal;
        var confidence: f32 = 0.5;
        var reason_buf: [256]u8 = undefined;
        var reason_len: usize = 0;

        for (candidates.items) |c| {
            if (c.kind == action) {
                urgency = c.urgency;
                confidence = c.value;

                // Build reason with trend context
                const base_reason = switch (action) {
                    .doctor_quick => "Build broken, needs healing",
                    .farm_recycle => "Farm has idle/crashed workers",
                    .notify => "Celebrating farm progress",
                    .cloud_spawn => "Agent spawn issues detected",
                    .doctor_scan => "Compile rate declining (trend)",
                    .doctor_heal => "V-zone drifting (trend)",
                    .farm_status => "Faculty declining (trend)",
                    .git_commit_state => "Dirty files accumulating (trend)",
                    else => "Routine action",
                };

                // Add trend emoji if applicable
                if (ctx.trend_analysis) |ta| {
                    const formatted = std.fmt.bufPrint(&reason_buf, "{s} {s}", .{
                        ta.direction.emoji(), base_reason,
                    }) catch base_reason;
                    reason_len = formatted.len;
                } else {
                    reason_len = base_reason.len;
                    @memcpy(reason_buf[0..reason_len], base_reason);
                }
                break;
            }
        }

        var decision = Decision{
            .action = action,
            .urgency = urgency,
            .confidence = confidence,
        };
        @memcpy(decision.reason[0..reason_len], reason_buf[0..reason_len]);
        decision.reason_len = reason_len;
        return decision;
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
        decision.reasonStr(),
    );

    // Audit trail
    queen_policy.writeAuditEntry(
        "auto-action",
        decision.action,
        verdict,
        result.success,
        decision.reasonStr(),
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
            .{ d.action.emojiIcon(), d.action.label(), d.reasonStr() },
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

    var decision = Decision{
        .action = .doctor_quick, // L1 action
        .urgency = .critical,
        .confidence = 0.9,
    };
    @memcpy(decision.reason[0..4], "test");
    decision.reason_len = 4;

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

test "dlpfc — Decision setReason and reasonStr" {
    var decision = Decision{
        .action = .farm_status,
        .urgency = .normal,
        .confidence = 0.0,
    };
    try std.testing.expectEqual(@as(usize, 0), decision.reason_len);

    decision.setReason("test reason");
    try std.testing.expectEqual(@as(usize, 11), decision.reason_len);
    try std.testing.expectEqualStrings("test reason", decision.reasonStr());
}

test "dlpfc — TrendDirection emoji and color" {
    try std.testing.expectEqualStrings("\xe2\x96\xb2", TrendDirection.improving.emoji());
    try std.testing.expectEqualStrings("\xf0\x9f\x9a\xa8", TrendDirection.critical.emoji());
}

test "dlpfc — TrendAnalysis hasWarning" {
    var analysis = TrendAnalysis{ .direction = .stable };
    try std.testing.expect(!analysis.hasWarning());

    analysis.direction = .deteriorating;
    try std.testing.expect(analysis.hasWarning());

    analysis.direction = .critical;
    try std.testing.expect(analysis.hasWarning());
}

test "dlpfc — Prediction setDescription and descriptionStr" {
    var pred = Prediction{};
    try std.testing.expectEqual(@as(usize, 0), pred.description_len);

    pred.setDescription("test prediction");
    try std.testing.expectEqual(@as(usize, 15), pred.description_len);
    try std.testing.expectEqualStrings("test prediction", pred.descriptionStr());
}

test "dlpfc — GoalPriority emoji" {
    try std.testing.expectEqualStrings("\xe2\x97\xbb", GoalPriority.low.emoji());
    try std.testing.expectEqualStrings("\xf0\x9f\x94\xb4", GoalPriority.critical.emoji());
}
