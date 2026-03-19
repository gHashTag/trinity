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

const faculty_types = @import("faculty_types.zig");
const qt = @import("queen_types.zig");
const thalamus = @import("thalamus.zig");
const voice_engine = @import("voice_engine.zig");
const queen_actions = @import("queen_actions.zig");
const queen_ofc = @import("queen_ofc.zig");
const basal_ganglia = @import("basal_ganglia.zig");
const cerebellum = @import("cerebellum.zig");
const queen_policy = @import("queen_policy.zig");

// Phoenix brainstem modules
const locus_coeruleus = @import("phoenix_locus_coeruleus.zig");
const medulla = @import("phoenix_medulla.zig");
const pons = @import("phoenix_pons.zig");

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

    // Faculty board integration (Phase 3.5)
    faculty_metrics: ?FacultyMetrics = null,
    trend_analysis: ?TrendAnalysis = null,

    // Phoenix brainstem integration
    locus_state: locus_coeruleus.LocusState = .{},
    last_sleep_ts: i64 = 0,

    /// Check if we should take any auto-action
    pub inline fn shouldAutoAct(self: *const DecisionContext) bool {
        return self.config.allow_auto_actions and self.config.daemon;
    }

    /// Get current arousal level
    pub inline fn getArousal(self: *const DecisionContext) locus_coeruleus.ArousalLevel {
        return locus_coeruleus.getArousal(&self.locus_state);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FACULTY METRICS — Real-time faculty board health summary
// ═══════════════════════════════════════════════════════════════════════════════

pub const FacultyMetrics = struct {
    active_count: u8 = 0, // Number of active agents (0-6)
    build_health: f32 = 0.0, // 0-100: build pass rate
    compile_rate: u8 = 0, // 0-100: percentage
    v_number: f32 = 0.0, // V-number (0-2+)
    dirty_files: u16 = 0, // Number of uncommitted files
    open_issues: u16 = 0, // GitHub issues
    mu_patterns: u16 = 0, // Mu memory patterns
    cycle: FacultyCycle = .working,
    v_zone: faculty_types.VZone = .drift,
    timestamp: i64 = 0,

    pub const FacultyCycle = enum { working, evaluating, sleeping };

    /// Calculate overall health score (0-100)
    pub inline fn healthScore(self: *const FacultyMetrics) f32 {
        var score: f32 = 0.0;
        score += @as(f32, @floatFromInt(self.active_count)) * 15.0; // 0-90 points
        score += self.build_health * 0.1; // 0-10 points
        return @min(score, 100.0);
    }

    /// Get V-zone description
    pub inline fn vZoneStr(self: *const FacultyMetrics) []const u8 {
        return switch (self.v_zone) {
            .gold => "GOLD",
            .stable => "STABLE",
            .drift => "DRIFT",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TREND ANALYSIS — Predictive problem detection
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrendAnalysis = struct {
    compile_trend: Trend = .stable,
    v_trend: Trend = .stable,
    dirty_trend: Trend = .stable,
    faculty_trend: Trend = .stable,
    confidence: f32 = 0.0, // 0-1: how confident we are in these trends
    sample_size: u32 = 0, // Number of data points analyzed

    pub const Trend = enum { falling, stable, rising };

    /// Get summary string
    pub fn summary(self: *const TrendAnalysis) []const u8 {
        if (self.confidence < 0.5) return "insufficient data";
        return switch (self.compile_trend) {
            .falling => "⚠ compile rate declining",
            .rising => "✓ compile rate improving",
            .stable => "✓ stable",
        };
    }

    /// Check if any metric is trending negatively
    pub inline fn hasProblemTrends(self: *const TrendAnalysis) bool {
        return self.compile_trend == .falling or
            self.v_trend == .falling or
            self.dirty_trend == .rising or
            self.faculty_trend == .falling;
    }

    /// Calculate urgency score based on trends (0-10)
    pub inline fn urgencyScore(self: *const TrendAnalysis) u8 {
        var score: u8 = 0;
        if (self.compile_trend == .falling) score += 3;
        if (self.v_trend == .falling) score += 2;
        if (self.dirty_trend == .rising) score += 2;
        if (self.faculty_trend == .falling) score += 3;
        return @min(score, 10);
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

    pub inline fn uptimeSeconds(self: *const CycleState) i64 {
        return std.time.timestamp() - self.start_time;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN AUTONOMOUS LOOP — READ → THINK → ACT → SPEAK
// ═══════════════════════════════════════════════════════════════════════════════

/// Alert sink for Locus Coeruleus — receives alarm notifications
fn locusAlertSink(alert: locus_coeruleus.Alert, arousal: locus_coeruleus.ArousalLevel) void {
    _ = alert;
    _ = arousal;
    // This is called by LC when alarm is triggered
    // The arousal level is passed to OFC for tone adjustment
    // In daemon mode, this will trigger immediate Telegram notification
}

pub fn runUnifiedLoop(allocator: Allocator, config: qt.QueenConfig) !void {
    var state = qt.QueenState{
        .started_at = std.time.timestamp(),
    };
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();
    var cycle_state = CycleState.init();

    // Initialize Locus Coeruleus with alert sink
    var locus_state = locus_coeruleus.init(locusAlertSink);

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
            .locus_state = locus_state,
            .last_sleep_ts = state.last_sleep_ts,
        };

        // PHASE 1: READ — Gather all sensor data
        // Medulla heartbeat at start of each cycle
        if (config.daemon) {
            _ = medulla.heartbeatPing(allocator);
        }

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

        // Save locus state and last_sleep_ts
        locus_state = ctx.locus_state;
        state.last_sleep_ts = ctx.last_sleep_ts;

        // Sleep cycle every 24 hours
        if (config.daemon) {
            const now = std.time.timestamp();
            const hours_since_sleep = if (ctx.last_sleep_ts > 0)
                @divTrunc(now - ctx.last_sleep_ts, 3600)
            else
                25; // Trigger on first run
            if (hours_since_sleep >= 24) {
                _ = medulla.sleepCycle(allocator);
                ctx.last_sleep_ts = now;
                state.last_sleep_ts = now;
            }
        }

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
            std.Thread.sleep(config.interval_sec * 1_000_000_000);
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

    // Get ouroboros_score from ouroboros module
    const ouroboros = @import("queen_ouroboros.zig");
    const ouroboros_state = ouroboros.fetch();
    ctx.ouroboros_score = ouroboros.getScore(ouroboros_state);

    // Get dirty_files from faculty metrics
    if (ctx.faculty_metrics) |metrics| {
        ctx.dirty_files = metrics.dirty_files;
    } else {
        ctx.dirty_files = 0;
    }

    // Phase 3.5: Collect faculty metrics from faculty board
    ctx.faculty_metrics = collectFacultyMetrics(allocator);

    // Phase 3.5: Analyze trends from faculty metrics
    ctx.trend_analysis = analyzeTrends(allocator, ctx.faculty_metrics);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECT FACULTY METRICS — Gather real-time faculty board data
// ═══════════════════════════════════════════════════════════════════════════════

fn collectFacultyMetrics(allocator: Allocator) ?FacultyMetrics {
    const faculty_board = @import("cortex.zig");
    const snapshot = faculty_board.collectSnapshot(allocator) catch return null;

    const metrics = FacultyMetrics{
        .active_count = snapshot.activeFaculty(),
        .build_health = if (snapshot.compile_total > 0)
            @as(f32, @floatFromInt(snapshot.compile_pass)) * 100.0 / @as(f32, @floatFromInt(snapshot.compile_total))
        else
            100.0,
        .compile_rate = snapshot.compile_rate,
        .v_number = @as(f32, @floatCast(snapshot.v_number)),
        .v_zone = snapshot.v_zone,
        .dirty_files = snapshot.dirty_files,
        .open_issues = snapshot.open_issues,
        .mu_patterns = snapshot.mu_patterns,
        .cycle = switch (snapshot.cycle) {
            .working, .quiet => .working,
            .emergency => .working,
        },
        .timestamp = std.time.timestamp(),
    };

    return metrics;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANALYZE TRENDS — Predictive problem detection from historical data
// ═══════════════════════════════════════════════════════════════════════════════

fn analyzeTrends(allocator: Allocator, current: ?FacultyMetrics) ?TrendAnalysis {
    if (current == null) return null;

    // Read recent faculty history from hippocampus
    const hippocampus = @import("hippocampus.zig");
    var results = hippocampus.read(allocator, .{
        .agent = "faculty_board",
        .kind = .observation,
        .limit = 10,
    }) catch return null;
    defer results.deinit(allocator);

    if (results.items.len < 3) return null; // Need at least 3 data points

    // Parse metrics from each historical record
    var first_active: u8 = 0;
    var last_active: u8 = 0;
    var first_compile: u8 = 0;
    var last_compile: u8 = 0;
    var first_v: f32 = 0;
    var last_v: f32 = 0;
    var first_dirty: u16 = 0;
    var last_dirty: u16 = 0;
    var data_points: u8 = 0;

    for (results.items) |r| {
        const summary = r.summary();
        // Parse format: "active: 5/6 | compile_rate: 85 | v: 1.17 | dirty: 12"

        // Parse active count
        if (std.mem.indexOf(u8, summary, "active:")) |idx| {
            const active_end = std.mem.indexOf(u8, summary[idx..], "/") orelse summary.len;
            const active_str = summary[idx + 7 .. idx + active_end];
            const active = std.fmt.parseInt(u8, active_str, 10) catch continue;
            if (data_points == 0) first_active = active;
            last_active = active;
        }

        // Parse compile_rate
        if (std.mem.indexOf(u8, summary, "compile_rate:")) |idx| {
            const rest = summary[idx + 13 ..];
            const rate_end = std.mem.indexOfScalar(u8, rest, ' ') orelse rest.len;
            const rate_end2 = std.mem.indexOfScalar(u8, rest[0..rate_end], '|') orelse rate_end;
            const rate_str = rest[0..rate_end2];
            const rate = std.fmt.parseInt(u8, rate_str, 10) catch continue;
            if (data_points == 0) first_compile = rate;
            last_compile = rate;
        }

        // Parse v-number
        if (std.mem.indexOf(u8, summary, "v:")) |idx| {
            // Make sure we're not matching "v_zone"
            if (idx == 0 or summary[idx - 1] != '_') {
                const rest = summary[idx + 2 ..];
                const v_end = std.mem.indexOfScalar(u8, rest, ' ') orelse rest.len;
                const v_end2 = std.mem.indexOfScalar(u8, rest[0..v_end], '|') orelse v_end;
                const v_str = rest[0..v_end2];
                const v = std.fmt.parseFloat(f32, v_str) catch continue;
                if (data_points == 0) first_v = v;
                last_v = v;
            }
        }

        // Parse dirty files
        if (std.mem.indexOf(u8, summary, "dirty:")) |idx| {
            const rest = summary[idx + 6 ..];
            const dirty_end = std.mem.indexOfScalar(u8, rest, ' ') orelse rest.len;
            const dirty_end2 = std.mem.indexOfScalar(u8, rest[0..dirty_end], '|') orelse dirty_end;
            const dirty_str = rest[0..dirty_end2];
            const dirty = std.fmt.parseInt(u16, dirty_str, 10) catch continue;
            if (data_points == 0) first_dirty = dirty;
            last_dirty = dirty;
        }

        if (data_points == 0) {
            data_points = 1;
        }
    }

    // Calculate trends based on first and last values
    const compile_trend = if (data_points >= 2 and first_compile > 0)
        determineTrend(@as(f32, @floatFromInt(last_compile)), @as(f32, @floatFromInt(first_compile)))
    else
        TrendAnalysis.Trend.stable;

    const v_trend = if (data_points >= 2 and first_v > 0)
        determineTrend(last_v, first_v)
    else
        TrendAnalysis.Trend.stable;

    const dirty_trend = if (data_points >= 2)
        // More dirty files = falling trend (bad)
        if (last_dirty > first_dirty + 5)
            TrendAnalysis.Trend.falling
        else if (last_dirty < first_dirty - 5)
            TrendAnalysis.Trend.rising
        else
            TrendAnalysis.Trend.stable
    else
        TrendAnalysis.Trend.stable;

    const faculty_trend = if (data_points >= 2)
        if (last_active > first_active)
            TrendAnalysis.Trend.rising
        else if (last_active < first_active)
            TrendAnalysis.Trend.falling
        else
            TrendAnalysis.Trend.stable
    else
        TrendAnalysis.Trend.stable;

    const analysis = TrendAnalysis{
        .compile_trend = compile_trend,
        .v_trend = v_trend,
        .dirty_trend = dirty_trend,
        .faculty_trend = faculty_trend,
        .confidence = @as(f32, @floatFromInt(results.items.len)) / 10.0,
        .sample_size = @intCast(results.items.len),
    };

    return analysis;
}

/// Determine trend from two values
fn determineTrend(current: f32, previous: f32) TrendAnalysis.Trend {
    const threshold = 0.05; // 5% change threshold
    const delta = current - previous;
    const pct_change = if (previous != 0) delta / previous else 0;

    if (pct_change > threshold) return TrendAnalysis.Trend.rising;
    if (pct_change < -threshold) return TrendAnalysis.Trend.falling;
    return TrendAnalysis.Trend.stable;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCUS COERULEUS INTEGRATION — Alarm triggers for critical events
// ═══════════════════════════════════════════════════════════════════════════════

/// Trigger LC alarms based on system state
fn triggerLocusAlarms(ctx: *DecisionContext) !void {
    // Critical: Build broken
    if (!ctx.build_ok) {
        try locus_coeruleus.triggerAlarm(
            &ctx.locus_state,
            .build_broken,
            "Build system failed - training stopped",
            null, // Use default severity-based arousal
        );
    }

    // Critical: Mass worker crash (>10 crashed)
    if (ctx.farm.crashed > 10) {
        var msg_buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(
            &msg_buf,
            "{d} workers crashed - mass failure detected",
            .{ctx.farm.crashed},
        );
        try locus_coeruleus.triggerAlarm(
            &ctx.locus_state,
            .worker_crashed,
            msg,
            .emergency,
        );
    }

    // Alarm: Token expired (check via environment)
    const has_token = std.posix.getenv("RAILWAY_TOKEN_1") orelse
        std.posix.getenv("RAILWAY_TOKEN_2") orelse
        std.posix.getenv("ZAI_KEY_1") orelse null;
    if (has_token == null) {
        try locus_coeruleus.triggerAlarm(
            &ctx.locus_state,
            .token_expired,
            "API token expired or missing - cannot communicate with Railway",
            .alarm,
        );
    }

    // Decay arousal over time (natural relaxation)
    locus_coeruleus.decayArousal(&ctx.locus_state, 300);
}

// ═══════════════════════════════════════════════════════════════════════════════
// THINK PHASE — Decision engine using Basal Ganglia
// ═══════════════════════════════════════════════════════════════════════════════

pub fn decide(ctx: *DecisionContext) !?Decision {
    if (!ctx.shouldAutoAct()) {
        return null;
    }

    // Trigger LC alarms for critical events
    try triggerLocusAlarms(ctx);

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

    // Rule 3: Active farm with good PPL → celebrate (only if training is happening!)
    const has_active_training = ctx.farm.active > 0;
    const has_good_ppl = ctx.farm.best_ppl > 0.0 and ctx.farm.best_ppl < 10.0;
    if (has_active_training and has_good_ppl) {
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

        const reason = getContextualReason(action, ctx);

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

    // Pons bridge: after farm recycle, send results to cerebellum
    if (decision.action == .farm_recycle) {
        // Build simple crashed worker list (for Phase 1, just use count)
        const bridge_results = pons.FarmSweepResults{
            .stale_count = @intCast(ctx.farm.stale_count),
            .crashed_workers = &[_][]const u8{},
        };
        _ = try pons.bridgeToCerebellum(ctx.allocator, bridge_results);
    }

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
// CONTEXT-AWARE MESSAGING — Human-like voice
// ═══════════════════════════════════════════════════════════════════════════════

/// Get contextual reason that explains WHAT and WHY
fn getContextualReason(action: qt.ActionKind, ctx: *const DecisionContext) []const u8 {
    return switch (action) {
        .doctor_quick => buildBrokenReason(ctx),
        .farm_recycle => farmRecycleReason(ctx),
        .notify => celebrationReason(ctx),
        .cloud_spawn => cloudSpawnReason(ctx),
        else => "Routine action",
    };
}

/// Explain why build healing is needed
fn buildBrokenReason(ctx: *const DecisionContext) []const u8 {
    if (ctx.faculty_metrics) |m| {
        if (m.compile_rate < 50) {
            return "Compile rate very low, needs immediate attention";
        }
        if (m.dirty_files > 100) {
            return "Too many dirty files, build unstable";
        }
    }
    return "Build broken, running quick heal";
}

/// Explain farm recycling decision
fn farmRecycleReason(ctx: *const DecisionContext) []const u8 {
    const crashed = ctx.farm.crashed;
    const total = ctx.farm.total_services;
    const active = ctx.farm.active;
    const idle = total - active - crashed;

    if (crashed > 5) {
        return "Many workers crashed, recycling farm";
    }
    if (idle > 10) {
        return "Many idle workers, recycling for efficiency";
    }
    return "Farm needs optimization";
}

/// Explain celebration (only when there's something to celebrate!)
fn celebrationReason(ctx: *const DecisionContext) []const u8 {
    if (ctx.farm.active == 0) {
        return "Farm is idle - nothing to celebrate";
    }

    const ppl = ctx.farm.best_ppl;
    if (ppl < 3.0) {
        return "Excellent PPL achieved!";
    }
    if (ppl < 5.0) {
        return "Good progress on PPL";
    }
    return "Training running smoothly";
}

/// Explain cloud spawn decision
fn cloudSpawnReason(ctx: *const DecisionContext) []const u8 {
    const issues = ctx.issues.agent_spawn;
    const finished = if (ctx.farm.total_services > 0) ctx.farm.total_services else 0;

    if (issues > 3) {
        return "Multiple agent spawn issues detected";
    }
    if (finished > 0) {
        return "Spawning replacements for finished containers";
    }
    return "Agent spawn needed";
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEAK PHASE — Report decision and result via OFC
// ═══════════════════════════════════════════════════════════════════════════════

pub fn speak(ctx: *DecisionContext, decision: ?Decision, result: qt.ActionResult) !void {
    _ = decision; // Available for future enhancements
    _ = result; // Available for future enhancements

    // Generate arousal-aware report
    const arousal = ctx.getArousal();

    // Use OFC's arousal-aware formatting
    const report = queen_ofc.formatStatusReportWithArousal(
        ctx.allocator,
        ctx.build_ok,
        ctx.ouroboros_score,
        @intCast(ctx.farm.active),
        ctx.farm.best_ppl,
        arousal,
    ) catch return;
    defer ctx.allocator.free(report);

    // Send via OFC with appropriate routing based on arousal
    const route = if (arousal == .emergency or arousal == .alarm)
        queen_ofc.ChatRoute.alert
    else
        queen_ofc.ChatRoute.group;

    ctx.state.cycle +|= 1;
    try queen_ofc.send(ctx.allocator, route, report);
}

/// Format human-like report that explains WHAT happened and WHY
fn formatHumanReport(
    buf: []u8,
    ctx: *const DecisionContext,
    decision: ?Decision,
    result: qt.ActionResult,
) ![]const u8 {
    var offset: usize = 0;

    // Context-aware header
    const header = getContextualHeader(ctx);
    if (offset + header.len <= buf.len) {
        @memcpy(buf[offset..][0..header.len], header);
        offset += header.len;
    }

    // Farm status (human-readable)
    const farm_status = formatFarmStatus(ctx);
    if (offset + farm_status.len <= buf.len) {
        @memcpy(buf[offset..][0..farm_status.len], farm_status);
        offset += farm_status.len;
    }

    // Build status
    const build_status = if (ctx.build_ok)
        "\n✅ Build is healthy"
    else
        "\n❌ Build broken - will attempt healing";
    if (offset + build_status.len <= buf.len) {
        @memcpy(buf[offset..][0..build_status.len], build_status);
        offset += build_status.len;
    }

    // Action explanation
    if (decision) |d| {
        const action_text = formatActionExplanation(d, result);
        if (offset + action_text.len <= buf.len) {
            @memcpy(buf[offset..][0..action_text.len], action_text);
            offset += action_text.len;
        }
    } else {
        const no_action = "\n\n🧠 Standing by. No action needed.";
        if (offset + no_action.len <= buf.len) {
            @memcpy(buf[offset..][0..no_action.len], no_action);
            offset += no_action.len;
        }
    }

    return buf[0..offset];
}

/// Get header based on actual system state (not generic mood)
fn getContextualHeader(ctx: *const DecisionContext) []const u8 {
    const farm_active = ctx.farm.active;
    const farm_total = ctx.farm.total_services;

    if (farm_active == 0 and farm_total > 0) {
        // Farm is idle
        return "🧠 Farm Status Update\n\nTraining farm is idle. ";
    } else if (farm_active > 0) {
        // Farm is running
        return "🧠 Farm Status Update\n\nTraining is active. ";
    } else {
        // No farm at all
        return "🧠 System Status\n\n";
    }
}

/// Format farm status in human-readable way
fn formatFarmStatus(ctx: *const DecisionContext) []const u8 {
    if (ctx.farm.active == 0 and ctx.farm.total_services == 0) {
        return "No training services configured.";
    }

    if (ctx.farm.active == 0) {
        if (ctx.farm.best_ppl < 999.0) {
            // Has results but not currently training
            return "Farm is sleeping. ";
        }
        return "Farm is offline. ";
    }

    // Active training
    return "Training in progress. ";
}

/// Explain what action was taken and why
fn formatActionExplanation(d: Decision, result: qt.ActionResult) []const u8 {
    _ = result; // Available for future enhancement (e.g., show result emoji)
    return switch (d.action) {
        .doctor_quick => "\n\n🔧 Running quick heal to fix build issues...",
        .farm_recycle => "\n\n♻️ Recycling farm to recover idle/crashed workers.",
        .notify => "\n\n📊 Status update - all systems nominal.",
        .cloud_spawn => "\n\n🚀 Spawning new agent containers.",
        .doctor_heal => "\n\n🏥 Running deep heal to recover codebase.",
        .git_commit_state => "\n\n💾 Committing state to preserve work.",
        .git_push => "\n\n☁️ Pushing changes to remote.",
        .issue_comment => "\n\n📝 Updating GitHub issue tracker.",
        .arena_battle => "\n\n⚔️ Running arena battles for evaluation.",
        .ouroboros_cycle => "\n\n🔄 Running Ouroboros health cycle.",
        else => "\n\nExecuting routine action.",
    };
}

/// Format decision report for Telegram
fn formatDecisionReport(decision: Decision, result: qt.ActionResult) []const u8 {
    _ = decision;
    _ = result;
    // Reports are sent via Queen OFC with proper formatting
    // This function kept for potential custom reporting needs
    return "";
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

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 3.5 TESTS — Faculty Metrics & Trend Analysis
// ═══════════════════════════════════════════════════════════════════════════════

test "Phase 3.5 — FacultyMetrics health score calculation" {
    var metrics = FacultyMetrics{
        .active_count = 5,
        .build_health = 80.0,
    };

    const score = metrics.healthScore();
    // score = 5 * 15 + 80 * 0.1 = 75 + 8 = 83
    try std.testing.expect(score >= 75.0 and score <= 100.0);
    try std.testing.expectApproxEqAbs(@as(f32, 83.0), score, 0.1);
}

test "Phase 3.5 — FacultyMetrics vZoneStr returns valid" {
    const metrics = FacultyMetrics{ .v_zone = .gold };

    const zone_str = metrics.vZoneStr();
    try std.testing.expect(zone_str.len > 0);
}

test "Phase 3.5 — TrendAnalysis summary with low confidence" {
    var analysis = TrendAnalysis{
        .confidence = 0.3,
        .compile_trend = .falling,
    };

    const summary = analysis.summary();
    try std.testing.expectEqualStrings("insufficient data", summary);
}

test "Phase 3.5 — TrendAnalysis summary with high confidence" {
    var analysis = TrendAnalysis{
        .confidence = 0.8,
        .compile_trend = .rising,
    };

    const summary = analysis.summary();
    try std.testing.expect(std.mem.indexOf(u8, summary, "improving") != null);
}

test "Phase 3.5 — TrendAnalysis hasProblemTrends detection" {
    // All stable → no problems
    var stable = TrendAnalysis{ .confidence = 1.0 };
    try std.testing.expect(!stable.hasProblemTrends());

    // Compile falling → has problems
    var failing = TrendAnalysis{
        .confidence = 1.0,
        .compile_trend = .falling,
    };
    try std.testing.expect(failing.hasProblemTrends());

    // Dirty rising → has problems
    var dirty = TrendAnalysis{
        .confidence = 1.0,
        .dirty_trend = .rising,
    };
    try std.testing.expect(dirty.hasProblemTrends());
}

test "Phase 3.5 — TrendAnalysis urgency score calculation" {
    // All stable → 0 urgency
    var stable = TrendAnalysis{ .confidence = 1.0 };
    try std.testing.expectEqual(@as(u8, 0), stable.urgencyScore());

    // Single falling → 3 urgency
    var single = TrendAnalysis{
        .confidence = 1.0,
        .compile_trend = .falling,
    };
    try std.testing.expectEqual(@as(u8, 3), single.urgencyScore());

    // Multiple problems → higher urgency
    var multiple = TrendAnalysis{
        .confidence = 1.0,
        .compile_trend = .falling,
        .v_trend = .falling,
        .dirty_trend = .rising,
        .faculty_trend = .falling,
    };
    try std.testing.expectEqual(@as(u8, 10), multiple.urgencyScore());
}

test "Phase 3.5 — determineTrend helper function" {
    // Rising trend
    try std.testing.expectEqual(TrendAnalysis.Trend.rising, determineTrend(10.0, 8.0));

    // Falling trend
    try std.testing.expectEqual(TrendAnalysis.Trend.falling, determineTrend(5.0, 10.0));

    // Stable (within threshold)
    try std.testing.expectEqual(TrendAnalysis.Trend.stable, determineTrend(10.0, 9.9));
    try std.testing.expectEqual(TrendAnalysis.Trend.stable, determineTrend(10.0, 10.1));
}

test "dlpfc — Decision struct with all fields" {
    const decision = Decision{
        .action = .doctor_quick,
        .urgency = .high,
        .reason = "test reason",
        .confidence = 0.85,
    };

    try std.testing.expectEqual(qt.ActionKind.doctor_quick, decision.action);
    try std.testing.expectEqual(basal_ganglia.Urgency.high, decision.urgency);
    try std.testing.expectEqualStrings("test reason", decision.reason);
    try std.testing.expectApproxEqAbs(@as(f32, 0.85), decision.confidence, 0.01);
}

test "dlpfc — Decision struct default confidence" {
    const decision = Decision{
        .action = .farm_status, // L0 safe action
        .urgency = .low,
        .reason = "",
    };

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), decision.confidence, 0.001);
}

test "dlpfc — DecisionContext getArousal" {
    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
        .locus_state = .{},
    };

    // Default locus state should return some arousal level
    const arousal = ctx.getArousal();
    _ = arousal;
    // Just verify it doesn't crash
}

test "dlpfc — CycleState running flag" {
    var cycle = CycleState.init();
    try std.testing.expect(cycle.running);

    cycle.running = false;
    try std.testing.expect(!cycle.running);
}

test "dlpfc — CycleState decision count increments" {
    var cycle = CycleState.init();
    try std.testing.expectEqual(@as(u64, 0), cycle.decision_count);

    cycle.decision_count = 5;
    try std.testing.expectEqual(@as(u64, 5), cycle.decision_count);
}

test "dlpfc — CycleState iteration tracking" {
    var cycle = CycleState.init();
    try std.testing.expectEqual(@as(u64, 0), cycle.iteration);

    cycle.iteration = 100;
    try std.testing.expectEqual(@as(u64, 100), cycle.iteration);
}

test "dlpfc — FacultyMetrics max health score" {
    var metrics = FacultyMetrics{
        .active_count = 6, // Max agents
        .build_health = 100.0,
    };

    const score = metrics.healthScore();
    // 6*15 + 100*0.1 = 90 + 10 = 100
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), score, 0.1);
}

test "dlpfc — FacultyMetrics zero health score" {
    var metrics = FacultyMetrics{
        .active_count = 0,
        .build_health = 0.0,
    };

    const score = metrics.healthScore();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), score, 0.1);
}

test "dlpfc — FacultyMetrics all V-zones" {
    var metrics = FacultyMetrics{};

    metrics.v_zone = .gold;
    try std.testing.expectEqualStrings("GOLD", metrics.vZoneStr());

    metrics.v_zone = .stable;
    try std.testing.expectEqualStrings("STABLE", metrics.vZoneStr());

    metrics.v_zone = .drift;
    try std.testing.expectEqualStrings("DRIFT", metrics.vZoneStr());
}

test "dlpfc — FacultyCycle enum coverage" {
    const cycles = [_]FacultyMetrics.FacultyCycle{ .working, .evaluating, .sleeping };
    for (cycles) |c| {
        _ = c; // Verify all enum values exist
    }
}

test "dlpfc — TrendAnalysis Trend enum coverage" {
    const trends = [_]TrendAnalysis.Trend{ .falling, .stable, .rising };
    for (trends) |t| {
        _ = t; // Verify all enum values exist
    }
}

test "dlpfc — TrendAnalysis summary stable trend" {
    var analysis = TrendAnalysis{
        .confidence = 0.8,
        .compile_trend = .stable,
    };

    try std.testing.expectEqualStrings("✓ stable", analysis.summary());
}

test "dlpfc — TrendAnalysis summary rising trend" {
    var analysis = TrendAnalysis{
        .confidence = 0.8,
        .compile_trend = .rising,
    };

    try std.testing.expectEqualStrings("✓ compile rate improving", analysis.summary());
}

test "dlpfc — TrendAnalysis all falling trends urgency" {
    var analysis = TrendAnalysis{
        .confidence = 1.0,
        .compile_trend = .falling,
        .v_trend = .falling,
        .faculty_trend = .falling,
        .dirty_trend = .rising,
    };

    // 3 + 2 + 3 + 2 = 10, capped at 10
    try std.testing.expectEqual(@as(u8, 10), analysis.urgencyScore());
}

test "dlpfc — TrendAnalysis sample size tracking" {
    const analysis = TrendAnalysis{
        .sample_size = 100,
    };

    try std.testing.expectEqual(@as(u32, 100), analysis.sample_size);
}

test "dlpfc — DecisionContext default values" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
    };

    try std.testing.expectEqual(@as(f32, 0.0), ctx.ouroboros_score);
    try std.testing.expectEqual(@as(u16, 0), ctx.dirty_files);
    try std.testing.expect(ctx.build_ok);
}

test "dlpfc — CycleState last_decision optional" {
    var cycle = CycleState.init();

    try std.testing.expect(cycle.last_decision == null);

    const decision = Decision{
        .action = .farm_status,
        .urgency = .low,
        .reason = "test",
    };
    cycle.last_decision = decision;

    try std.testing.expect(cycle.last_decision != null);
}

test "dlpfc — determineTrend rising" {
    const trend = determineTrend(1.1, 1.0); // 10% increase
    try std.testing.expectEqual(TrendAnalysis.Trend.rising, trend);
}

test "dlpfc — determineTrend falling" {
    const trend = determineTrend(0.9, 1.0); // 10% decrease
    try std.testing.expectEqual(TrendAnalysis.Trend.falling, trend);
}

test "dlpfc — determineTrend stable" {
    const trend1 = determineTrend(1.02, 1.0); // 2% change - below threshold
    try std.testing.expectEqual(TrendAnalysis.Trend.stable, trend1);

    const trend2 = determineTrend(1.0, 1.0); // No change
    try std.testing.expectEqual(TrendAnalysis.Trend.stable, trend2);
}

test "dlpfc — determineTrend handles zero previous" {
    const trend = determineTrend(1.0, 0.0);
    try std.testing.expectEqual(TrendAnalysis.Trend.stable, trend);
}

test "dlpfc — TrendAnalysis all trend combinations" {
    const trends = [_]TrendAnalysis.Trend{ .rising, .stable, .falling };

    for (trends) |compile| {
        for (trends) |v| {
            for (trends) |dirty| {
                for (trends) |faculty| {
                    const analysis = TrendAnalysis{
                        .compile_trend = compile,
                        .v_trend = v,
                        .dirty_trend = dirty,
                        .faculty_trend = faculty,
                    };
                    _ = analysis;
                    // Just verify all combinations are valid
                }
            }
        }
    }
}

test "dlpfc — TrendAnalysis confidence range" {
    var analysis = TrendAnalysis{ .sample_size = 0 };
    try std.testing.expectEqual(@as(f32, 0.0), analysis.confidence);

    analysis.sample_size = 5;
    analysis.confidence = 0.5;
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), analysis.confidence, 0.01);

    analysis.sample_size = 10;
    analysis.confidence = 1.0;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), analysis.confidence, 0.01);
}

// ═══════════════════════════════════════════════════════════════════
// CellHealth TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — CellHealth default values" {
    const h = CellHealth{};
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "dlpfc — CellHealth custom values" {
    var h = CellHealth{};
    h.status = .weak;
    h.cycle = 5;
    h.last_check = 1234567890;

    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
    try std.testing.expectEqual(@as(u32, 5), h.cycle);
    try std.testing.expectEqual(@as(i64, 1234567890), h.last_check);
}

test "dlpfc — CellHealth Status enum coverage" {
    const statuses = [_]CellHealth.Status{ .healthy, .weak, .broken };
    for (statuses) |s| {
        _ = s; // Verify all enum values exist
    }
}

test "dlpfc — CellHealth broken status" {
    const h = CellHealth{ .status = .broken };
    try std.testing.expectEqual(CellHealth.Status.broken, h.status);
}

test "dlpfc — health returns timestamp" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

// ═══════════════════════════════════════════════════════════════════
// FacultyMetrics EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — FacultyMetrics compile_rate field" {
    const metrics = FacultyMetrics{ .compile_rate = 85 };
    try std.testing.expectEqual(@as(u8, 85), metrics.compile_rate);
}

test "dlpfc — FacultyMetrics dirty_files field" {
    const metrics = FacultyMetrics{ .dirty_files = 42 };
    try std.testing.expectEqual(@as(u16, 42), metrics.dirty_files);
}

test "dlpfc — FacultyMetrics open_issues field" {
    const metrics = FacultyMetrics{ .open_issues = 10 };
    try std.testing.expectEqual(@as(u16, 10), metrics.open_issues);
}

test "dlpfc — FacultyMetrics mu_patterns field" {
    const metrics = FacultyMetrics{ .mu_patterns = 123 };
    try std.testing.expectEqual(@as(u16, 123), metrics.mu_patterns);
}

test "dlpfc — FacultyMetrics v_number field" {
    const metrics = FacultyMetrics{ .v_number = 1.5 };
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), metrics.v_number, 0.01);
}

test "dlpfc — FacultyMetrics timestamp field" {
    const ts: i64 = 1234567890;
    const metrics = FacultyMetrics{ .timestamp = ts };
    try std.testing.expectEqual(ts, metrics.timestamp);
}

test "dlpfc — FacultyMetrics cycle field" {
    const metrics = FacultyMetrics{ .cycle = .evaluating };
    try std.testing.expectEqual(FacultyMetrics.FacultyCycle.evaluating, metrics.cycle);
}

test "dlpfc — FacultyMetrics all cycles" {
    var metrics = FacultyMetrics{};

    metrics.cycle = .working;
    try std.testing.expectEqual(FacultyMetrics.FacultyCycle.working, metrics.cycle);

    metrics.cycle = .evaluating;
    try std.testing.expectEqual(FacultyMetrics.FacultyCycle.evaluating, metrics.cycle);

    metrics.cycle = .sleeping;
    try std.testing.expectEqual(FacultyMetrics.FacultyCycle.sleeping, metrics.cycle);
}

test "dlpfc — FacultyMetrics health score capped at 100" {
    // Very high values should still cap at 100
    const metrics = FacultyMetrics{
        .active_count = 10, // More than max
        .build_health = 200.0, // More than max
    };

    const score = metrics.healthScore();
    try std.testing.expect(score <= 100.0);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), score, 0.1);
}

test "dlpfc — FacultyMetrics with all fields set" {
    const metrics = FacultyMetrics{
        .active_count = 4,
        .build_health = 90.0,
        .compile_rate = 95,
        .v_number = 1.2,
        .dirty_files = 15,
        .open_issues = 5,
        .mu_patterns = 200,
        .cycle = .working,
        .v_zone = .stable,
        .timestamp = 1234567890,
    };

    try std.testing.expectEqual(@as(u8, 4), metrics.active_count);
    try std.testing.expectApproxEqAbs(@as(f32, 90.0), metrics.build_health, 0.1);
    try std.testing.expectEqual(@as(u8, 95), metrics.compile_rate);
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), metrics.v_number, 0.01);
    try std.testing.expectEqual(@as(u16, 15), metrics.dirty_files);
    try std.testing.expectEqual(@as(u16, 5), metrics.open_issues);
    try std.testing.expectEqual(@as(u16, 200), metrics.mu_patterns);
    try std.testing.expectEqual(FacultyMetrics.FacultyCycle.working, metrics.cycle);
    try std.testing.expectEqual(faculty_types.VZone.stable, metrics.v_zone);
    try std.testing.expectEqual(@as(i64, 1234567890), metrics.timestamp);
}

// ═══════════════════════════════════════════════════════════════════
// DecisionContext EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — DecisionContext locus_state field" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
        .locus_state = .{}, // Default locus state
    };

    // Verify locus_state is accessible
    _ = ctx.locus_state;
}

test "dlpfc — DecisionContext last_sleep_ts field" {
    const sleep_ts: i64 = 1234567890;
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
        .last_sleep_ts = sleep_ts,
    };

    try std.testing.expectEqual(sleep_ts, ctx.last_sleep_ts);
}

test "dlpfc — DecisionContext faculty_metrics optional" {
    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
        .faculty_metrics = null,
    };

    try std.testing.expect(ctx.faculty_metrics == null);

    const metrics = FacultyMetrics{ .active_count = 3 };
    ctx.faculty_metrics = metrics;
    try std.testing.expect(ctx.faculty_metrics != null);
    if (ctx.faculty_metrics) |m| {
        try std.testing.expectEqual(@as(u8, 3), m.active_count);
    }
}

test "dlpfc — DecisionContext trend_analysis optional" {
    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
        .trend_analysis = null,
    };

    try std.testing.expect(ctx.trend_analysis == null);

    const analysis = TrendAnalysis{ .confidence = 0.8 };
    ctx.trend_analysis = analysis;
    try std.testing.expect(ctx.trend_analysis != null);
}

test "dlpfc — DecisionContext derived metrics" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
        .ouroboros_score = 75.5,
        .dirty_files = 23,
        .build_ok = false,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 75.5), ctx.ouroboros_score, 0.01);
    try std.testing.expectEqual(@as(u16, 23), ctx.dirty_files);
    try std.testing.expect(!ctx.build_ok);
}

// ═══════════════════════════════════════════════════════════════════
// decide ADDITIONAL TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — decide with idle workers" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{ .total_services = 20, .active = 10, .crashed = 0 }, // 10 idle (>5)
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
    try std.testing.expectEqual(qt.ActionKind.farm_recycle, decision.?.action);
}

test "dlpfc — decide priority: build broken > crashed workers" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{ .total_services = 10, .active = 5, .crashed = 5 }, // Both conditions
        .issues = .{},
        .mu_heartbeat = .{ .build_ok = false }, // Build broken (critical)
        .config = .{ .allow_auto_actions = true, .daemon = true },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
        .build_ok = false,
    };

    const decision = try decide(&ctx);
    try std.testing.expect(decision != null);
    // Build broken should take priority (critical vs high urgency)
    try std.testing.expectEqual(qt.ActionKind.doctor_quick, decision.?.action);
}

test "dlpfc — decide returns null when auto_actions disabled" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{ .build_ok = false }, // Would trigger action
        .config = .{ .allow_auto_actions = false, .daemon = true },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
        .build_ok = false,
    };

    const decision = try decide(&ctx);
    try std.testing.expect(decision == null);
}

test "dlpfc — decide returns null when not in daemon mode" {
    var state = qt.QueenState{};
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();

    var ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{ .build_ok = false },
        .config = .{ .allow_auto_actions = true, .daemon = false },
        .state = &state,
        .counters = &counters,
        .incidents = &incidents,
        .build_ok = false,
    };

    const decision = try decide(&ctx);
    try std.testing.expect(decision == null);
}

// ═══════════════════════════════════════════════════════════════════
// TrendAnalysis EDGE CASES
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — TrendAnalysis v_trend falling detection" {
    var analysis = TrendAnalysis{
        .confidence = 1.0,
        .v_trend = .falling,
    };
    try std.testing.expect(analysis.hasProblemTrends());
}

test "dlpfc — TrendAnalysis faculty_trend falling detection" {
    var analysis = TrendAnalysis{
        .confidence = 1.0,
        .faculty_trend = .falling,
    };
    try std.testing.expect(analysis.hasProblemTrends());
}

test "dlpfc — TrendAnalysis multiple problems urgency" {
    // compile_falling (3) + v_falling (2) + dirty_rising (2) = 7
    var analysis = TrendAnalysis{
        .confidence = 1.0,
        .compile_trend = .falling,
        .v_trend = .falling,
        .dirty_trend = .rising,
    };
    try std.testing.expectEqual(@as(u8, 7), analysis.urgencyScore());
}

test "dlpfc — TrendAnalysis urgency capped at 10" {
    // All worst case = 3+2+2+3 = 10 (capped)
    var analysis = TrendAnalysis{
        .confidence = 1.0,
        .compile_trend = .falling,
        .v_trend = .falling,
        .dirty_trend = .rising,
        .faculty_trend = .falling,
    };
    try std.testing.expectEqual(@as(u8, 10), analysis.urgencyScore());
}

test "dlpfc — TrendAnalysis summary with falling trend" {
    var analysis = TrendAnalysis{
        .confidence = 0.8,
        .compile_trend = .falling,
    };

    const summary = analysis.summary();
    try std.testing.expect(std.mem.indexOf(u8, summary, "declining") != null);
}

test "dlpfc — determineTrend with exact threshold boundary" {
    // 5% change = threshold, should be stable
    const trend_rising = determineTrend(1.05, 1.0);
    try std.testing.expectEqual(TrendAnalysis.Trend.stable, trend_rising);

    const trend_falling = determineTrend(0.95, 1.0);
    try std.testing.expectEqual(TrendAnalysis.Trend.stable, trend_falling);

    // Just above threshold
    const trend_above = determineTrend(1.051, 1.0);
    try std.testing.expectEqual(TrendAnalysis.Trend.rising, trend_above);

    // Just below threshold
    const trend_below = determineTrend(0.949, 1.0);
    try std.testing.expectEqual(TrendAnalysis.Trend.falling, trend_below);
}

test "dlpfc — determineTrend with negative values" {
    const trend = determineTrend(-5.0, -10.0); // Rising (less negative)
    try std.testing.expectEqual(TrendAnalysis.Trend.rising, trend);
}

// ═══════════════════════════════════════════════════════════════════
// CycleState ADDITIONAL TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — CycleState start_time set on init" {
    const cycle = CycleState.init();
    try std.testing.expect(cycle.start_time > 0);
}

test "dlpfc — CycleState uptime increases" {
    var cycle = CycleState.init();
    const uptime1 = cycle.uptimeSeconds();
    std.Thread.sleep(100_000); // 0.1 seconds
    const uptime2 = cycle.uptimeSeconds();
    try std.testing.expect(uptime2 >= uptime1);
}

test "dlpfc — CycleState with last_decision set" {
    var cycle = CycleState.init();
    const decision = Decision{
        .action = .farm_status,
        .urgency = .low,
        .reason = "test",
        .confidence = 0.5,
    };
    cycle.last_decision = decision;

    try std.testing.expect(cycle.last_decision != null);
    if (cycle.last_decision) |d| {
        try std.testing.expectEqual(qt.ActionKind.farm_status, d.action);
    }
}

// ═══════════════════════════════════════════════════════════════════
// Decision ADDITIONAL TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — Decision with all urgency levels" {
    const urgencies = [_]basal_ganglia.Urgency{ .critical, .high, .normal, .low };

    for (urgencies) |u| {
        const decision = Decision{
            .action = .farm_status,
            .urgency = u,
            .reason = "test",
        };
        try std.testing.expectEqual(u, decision.urgency);
    }
}

test "dlpfc — Decision confidence range" {
    const decision1 = Decision{
        .action = .farm_status,
        .urgency = .low,
        .reason = "test",
        .confidence = 0.0,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), decision1.confidence, 0.01);

    const decision2 = Decision{
        .action = .farm_status,
        .urgency = .low,
        .reason = "test",
        .confidence = 1.0,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), decision2.confidence, 0.01);
}

// ═══════════════════════════════════════════════════════════════════
// DecisionContext INLINE METHOD TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — DecisionContext shouldAutoAct true" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{ .allow_auto_actions = true, .daemon = true },
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
    };

    try std.testing.expect(ctx.shouldAutoAct());
}

test "dlpfc — DecisionContext shouldAutoAct false disabled" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{ .allow_auto_actions = false, .daemon = true },
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
    };

    try std.testing.expect(!ctx.shouldAutoAct());
}

test "dlpfc — DecisionContext shouldAutoAct false not daemon" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{ .allow_auto_actions = true, .daemon = false },
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
    };

    try std.testing.expect(!ctx.shouldAutoAct());
}

test "dlpfc — DecisionContext getArousal returns valid" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
        .locus_state = .{},
    };

    const arousal = ctx.getArousal();
    _ = arousal; // Just verify it returns without crashing
}

// ═══════════════════════════════════════════════════════════════════
// FacultyMetrics vZoneStr TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — FacultyMetrics vZoneStr drift" {
    const metrics = FacultyMetrics{ .v_zone = .drift };
    try std.testing.expectEqualStrings("⚠ drift", metrics.vZoneStr());
}

test "dlpfc — FacultyMetrics vZoneStr stable" {
    const metrics = FacultyMetrics{ .v_zone = .stable };
    try std.testing.expectEqualStrings("✓ stable", metrics.vZoneStr());
}

test "dlpfc — FacultyMetrics vZoneStr improving" {
    const metrics = FacultyMetrics{ .v_zone = .gold };
    try std.testing.expectEqualStrings("↑ improving", metrics.vZoneStr());
}

test "dlpfc — FacultyMetrics vZoneStr declining" {
    const metrics = FacultyMetrics{ .v_zone = .drift };
    try std.testing.expectEqualStrings("↓ declining", metrics.vZoneStr());
}

test "dlpfc — FacultyMetrics all v_zones" {
    const zones = [_]faculty_types.VZone{ .drift, .stable, .gold };

    for (zones) |z| {
        const metrics = FacultyMetrics{ .v_zone = z };
        _ = metrics.vZoneStr(); // Verify all zones produce valid strings
    }
}

// ═══════════════════════════════════════════════════════════════════
// TrendAnalysis COMPREHENSIVE TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — TrendAnalysis hasProblemTrends none" {
    const analysis = TrendAnalysis{
        .confidence = 1.0,
        .compile_trend = .stable,
        .v_trend = .stable,
        .dirty_trend = .stable,
        .faculty_trend = .stable,
    };
    try std.testing.expect(!analysis.hasProblemTrends());
}

test "dlpfc — TrendAnalysis hasProblemTrends dirty rising" {
    const analysis = TrendAnalysis{
        .confidence = 1.0,
        .dirty_trend = .rising,
    };
    try std.testing.expect(analysis.hasProblemTrends());
}

test "dlpfc — TrendAnalysis hasProblemTrends low confidence masks" {
    const analysis = TrendAnalysis{
        .confidence = 0.4, // Below threshold
        .compile_trend = .falling, // Would be problem if confident
    };
    try std.testing.expect(!analysis.hasProblemTrends());
}

test "dlpfc — TrendAnalysis urgency score zero" {
    const analysis = TrendAnalysis{
        .confidence = 1.0,
        .compile_trend = .stable,
        .v_trend = .stable,
        .dirty_trend = .stable,
        .faculty_trend = .stable,
    };
    try std.testing.expectEqual(@as(u8, 0), analysis.urgencyScore());
}

test "dlpfc — TrendAnalysis urgency partial scores" {
    // compile_falling only = 3
    const analysis1 = TrendAnalysis{
        .confidence = 1.0,
        .compile_trend = .falling,
    };
    try std.testing.expectEqual(@as(u8, 3), analysis1.urgencyScore());

    // dirty_rising only = 2
    const analysis2 = TrendAnalysis{
        .confidence = 1.0,
        .dirty_trend = .rising,
    };
    try std.testing.expectEqual(@as(u8, 2), analysis2.urgencyScore());

    // faculty_falling only = 3
    const analysis3 = TrendAnalysis{
        .confidence = 1.0,
        .faculty_trend = .falling,
    };
    try std.testing.expectEqual(@as(u8, 3), analysis3.urgencyScore());

    // v_falling only = 2
    const analysis4 = TrendAnalysis{
        .confidence = 1.0,
        .v_trend = .falling,
    };
    try std.testing.expectEqual(@as(u8, 2), analysis4.urgencyScore());
}

test "dlpfc — TrendAnalysis summary default" {
    const analysis = TrendAnalysis{
        .confidence = 0.0,
        .compile_trend = .stable,
    };
    try std.testing.expectEqualStrings("insufficient data", analysis.summary());
}

test "dlpfc — TrendAnalysis summary with confidence" {
    const analysis = TrendAnalysis{
        .confidence = 0.9,
        .compile_trend = .rising,
        .v_trend = .rising,
        .dirty_trend = .falling, // Good - dirty files decreasing
        .faculty_trend = .rising,
    };

    const summary = analysis.summary();
    try std.testing.expect(summary.len > 0);
}

// ═══════════════════════════════════════════════════════════════════
// determineTrend EDGE CASES
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — determineTrend both zero" {
    const trend = determineTrend(0.0, 0.0);
    try std.testing.expectEqual(TrendAnalysis.Trend.stable, trend);
}

test "dlpfc — determineTrend current zero" {
    const trend = determineTrend(0.0, 1.0);
    try std.testing.expectEqual(TrendAnalysis.Trend.falling, trend);
}

test "dlpfc — determineTrend previous zero current non-zero" {
    const trend = determineTrend(1.0, 0.0);
    try std.testing.expectEqual(TrendAnalysis.Trend.rising, trend);
}

test "dlpfc — determineTrend large change" {
    const trend = determineTrend(10.0, 1.0); // 10x increase
    try std.testing.expectEqual(TrendAnalysis.Trend.rising, trend);
}

test "dlpfc — determineTrend small change within threshold" {
    const trend = determineTrend(1.01, 1.0); // 1% change
    try std.testing.expectEqual(TrendAnalysis.Trend.stable, trend);
}

test "dlpfc — determineTrend exactly at threshold" {
    const trend = determineTrend(1.05, 1.0); // Exactly 5%
    try std.testing.expectEqual(TrendAnalysis.Trend.stable, trend); // Stable at boundary
}

test "dlpfc — determineTrend negative to positive" {
    const trend = determineTrend(5.0, -5.0);
    try std.testing.expectEqual(TrendAnalysis.Trend.rising, trend);
}

test "dlpfc — determineTrend positive to negative" {
    const trend = determineTrend(-5.0, 5.0);
    try std.testing.expectEqual(TrendAnalysis.Trend.falling, trend);
}

// ═══════════════════════════════════════════════════════════════════
// CellHealth COMPREHENSIVE TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — CellHealth all statuses" {
    const statuses = [_]CellHealth.Status{ .healthy, .weak, .broken };

    for (statuses) |s| {
        const h = CellHealth{ .status = s };
        try std.testing.expectEqual(s, h.status);
    }
}

test "dlpfc — CellHealth cycle increments" {
    var h = CellHealth{};
    try std.testing.expectEqual(@as(u32, 0), h.cycle);

    h.cycle = 1;
    try std.testing.expectEqual(@as(u32, 1), h.cycle);

    h.cycle = 100;
    try std.testing.expectEqual(@as(u32, 100), h.cycle);
}

test "dlpfc — CellHealth last_check timestamp" {
    var h = CellHealth{};
    const ts1 = h.last_check;

    std.Thread.sleep(1_000_000); // 1ms

    h.last_check = std.time.timestamp();
    const ts2 = h.last_check;

    try std.testing.expect(ts2 >= ts1);
}

test "dlpfc — CellHealth with weak status" {
    const h = CellHealth{ .status = .weak };
    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
}

test "dlpfc — CellHealth with healthy status" {
    const h = CellHealth{ .status = .healthy };
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "dlpfc — health returns current timestamp" {
    const h = health();
    const now = std.time.timestamp();

    // Should be within 1 second
    try std.testing.expect(@abs(now - h.last_check) <= 1);
}

// ═══════════════════════════════════════════════════════════════════
// CycleState COMPREHENSIVE TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — CycleState init sets running true" {
    const cycle = CycleState.init();
    try std.testing.expect(cycle.running);
}

test "dlpfc — CycleState init zero iteration" {
    const cycle = CycleState.init();
    try std.testing.expectEqual(@as(u64, 0), cycle.iteration);
}

test "dlpfc — CycleState init null last_decision" {
    const cycle = CycleState.init();
    try std.testing.expect(cycle.last_decision == null);
}

test "dlpfc — CycleState init zero decision_count" {
    const cycle = CycleState.init();
    try std.testing.expectEqual(@as(u64, 0), cycle.decision_count);
}

test "dlpfc — CycleState uptimeSeconds returns non-negative" {
    const cycle = CycleState.init();
    const uptime = cycle.uptimeSeconds();
    try std.testing.expect(uptime >= 0);
}

test "dlpfc — CycleState iteration increments" {
    var cycle = CycleState.init();
    try std.testing.expectEqual(@as(u64, 0), cycle.iteration);

    cycle.iteration = 1;
    try std.testing.expectEqual(@as(u64, 1), cycle.iteration);

    cycle.iteration = 100;
    try std.testing.expectEqual(@as(u64, 100), cycle.iteration);
}

test "dlpfc — CycleState decision_count increments" {
    var cycle = CycleState.init();
    try std.testing.expectEqual(@as(u64, 0), cycle.decision_count);

    cycle.decision_count = 1;
    try std.testing.expectEqual(@as(u64, 1), cycle.decision_count);

    cycle.decision_count = 50;
    try std.testing.expectEqual(@as(u64, 50), cycle.decision_count);
}

test "dlpfc — CycleState running can be toggled" {
    var cycle = CycleState.init();
    try std.testing.expect(cycle.running);

    cycle.running = false;
    try std.testing.expect(!cycle.running);

    cycle.running = true;
    try std.testing.expect(cycle.running);
}

// ═══════════════════════════════════════════════════════════════════
// Decision COMPREHENSIVE TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — Decision all action kinds" {
    // Just verify we can create decisions with various actions
    const actions = [_]qt.ActionKind{
        .farm_status,
        .doctor_quick,
        .farm_recycle,
        .cloud_spawn,
        .git_commit_state,
    };

    for (actions) |a| {
        const decision = Decision{
            .action = a,
            .urgency = .normal,
            .reason = "test",
            .confidence = 0.5,
        };
        try std.testing.expectEqual(a, decision.action);
    }
}

test "dlpfc — Decision reason field" {
    const decision = Decision{
        .action = .farm_status,
        .urgency = .low,
        .reason = "Checking farm status",
        .confidence = 0.75,
    };
    try std.testing.expectEqualStrings("Checking farm status", decision.reason);
}

test "dlpfc — Decision empty reason" {
    const decision = Decision{
        .action = .farm_status,
        .urgency = .low,
        .reason = "",
        .confidence = 0.5,
    };
    try std.testing.expectEqual(@as(usize, 0), decision.reason.len);
}

test "dlpfc — Decision confidence default" {
    const decision = Decision{
        .action = .farm_status,
        .urgency = .low,
        .reason = "test",
    };
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), decision.confidence, 0.01);
}

test "dlpfc — Decision negative confidence clamped" {
    // Confidence should be 0-1, but we just store what's given
    const decision = Decision{
        .action = .farm_status,
        .urgency = .low,
        .reason = "test",
        .confidence = -0.5,
    };
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), decision.confidence, 0.01);
}

test "dlpfc — Decision confidence above 1" {
    const decision = Decision{
        .action = .farm_status,
        .urgency = .low,
        .reason = "test",
        .confidence = 1.5,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), decision.confidence, 0.01);
}

test "dlpfc — Decision urgency critical" {
    const decision = Decision{
        .action = .doctor_quick,
        .urgency = .critical,
        .reason = "Build broken",
        .confidence = 1.0,
    };
    try std.testing.expectEqual(basal_ganglia.Urgency.critical, decision.urgency);
}

test "dlpfc — Decision urgency high" {
    const decision = Decision{
        .action = .farm_recycle,
        .urgency = .high,
        .reason = "Crashed workers",
        .confidence = 0.9,
    };
    try std.testing.expectEqual(basal_ganglia.Urgency.high, decision.urgency);
}

test "dlpfc — Decision urgency normal" {
    const decision = Decision{
        .action = .farm_status,
        .urgency = .normal,
        .reason = "Periodic check",
        .confidence = 0.5,
    };
    try std.testing.expectEqual(basal_ganglia.Urgency.normal, decision.urgency);
}

test "dlpfc — Decision urgency low" {
    const decision = Decision{
        .action = .git_commit_state,
        .urgency = .low,
        .reason = "Optional commit",
        .confidence = 0.3,
    };
    try std.testing.expectEqual(basal_ganglia.Urgency.low, decision.urgency);
}

// ═══════════════════════════════════════════════════════════════════
// DecisionContext COMPREHENSIVE TESTS
// ═══════════════════════════════════════════════════════════════════

test "dlpfc — DecisionContext all fields zero" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
    };

    try std.testing.expectEqual(@as(f32, 0.0), ctx.ouroboros_score);
    try std.testing.expectEqual(@as(u16, 0), ctx.dirty_files);
    try std.testing.expect(ctx.build_ok);
}

test "dlpfc — DecisionContext with all derived metrics set" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
        .ouroboros_score = 85.5,
        .dirty_files = 42,
        .build_ok = false,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 85.5), ctx.ouroboros_score, 0.01);
    try std.testing.expectEqual(@as(u16, 42), ctx.dirty_files);
    try std.testing.expect(!ctx.build_ok);
}

test "dlpfc — DecisionContext faculty_metrics set" {
    const metrics = FacultyMetrics{
        .active_count = 3,
        .build_health = 90.0,
    };

    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
        .faculty_metrics = metrics,
    };

    try std.testing.expect(ctx.faculty_metrics != null);
    if (ctx.faculty_metrics) |m| {
        try std.testing.expectEqual(@as(u8, 3), m.active_count);
    }
}

test "dlpfc — DecisionContext trend_analysis set" {
    const analysis = TrendAnalysis{
        .confidence = 0.85,
        .compile_trend = .rising,
    };

    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{},
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
        .trend_analysis = analysis,
    };

    try std.testing.expect(ctx.trend_analysis != null);
    if (ctx.trend_analysis) |a| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.85), a.confidence, 0.01);
    }
}

test "dlpfc — DecisionContext config allow_auto_actions" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{ .allow_auto_actions = true, .daemon = true },
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
    };

    try std.testing.expect(ctx.config.allow_auto_actions);
    try std.testing.expect(ctx.config.daemon);
}

test "dlpfc — DecisionContext config disabled" {
    const ctx = DecisionContext{
        .allocator = std.testing.allocator,
        .farm = .{},
        .issues = .{},
        .mu_heartbeat = .{},
        .config = .{ .allow_auto_actions = false, .daemon = false },
        .state = undefined,
        .counters = undefined,
        .incidents = undefined,
    };

    try std.testing.expect(!ctx.config.allow_auto_actions);
    try std.testing.expect(!ctx.config.daemon);
}
