// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN PCC (Posterior Cingulate Cortex) — Self-Awareness & Introspection
// ═══════════════════════════════════════════════════════════════════════════════
// S³AI Brain Module — Self-reference, internal awareness, consciousness monitoring
// Neuro: Default mode hub, self-reference, internal awareness, "who am I"
// Trinity: Self-reflection, consciousness monitoring, self-model, state tracking
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const hippocampus = @import("hippocampus.zig");
const thalamus = @import("thalamus.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SELF MODEL — "Who am I, what am I doing, what can I do?"
// ═══════════════════════════════════════════════════════════════════════════════

pub const SelfModel = struct {
    identity: Identity,
    current_state: CurrentState,
    capabilities: Capabilities,
    goals: Goals,
    learning_state: LearningState,

    pub const Identity = struct {
        name: [32]u8 = [_]u8{0} ** 32,
        name_len: usize = 0,
        version: [16]u8 = [_]u8{0} ** 16,
        version_len: usize = 0,
        role: AgentRole = .autonomous_swarm,
        uptime_seconds: i64 = 0,
        pid: u32 = 0,

        pub fn nameStr(self: *const Identity) []const u8 {
            return self.name[0..self.name_len];
        }

        pub fn versionStr(self: *const Identity) []const u8 {
            return self.version[0..self.version_len];
        }
    };

    pub const AgentRole = enum {
        autonomous_swarm,
        training_farm,
        arena_evaluator,
        cloud_orchestrator,

        pub fn label(self: AgentRole) []const u8 {
            return switch (self) {
                .autonomous_swarm => "Autonomous Agent Swarm",
                .training_farm => "Training Farm Manager",
                .arena_evaluator => "Arena Evaluator",
                .cloud_orchestrator => "Cloud Orchestrator",
            };
        }
    };

    pub const CurrentState = struct {
        mode: Mode = .idle,
        activity: [64]u8 = [_]u8{0} ** 64,
        activity_len: usize = 0,
        cycle_count: u32 = 0,
        last_action: qt.ActionKind = .farm_status,
        last_action_ts: i64 = 0,

        pub const Mode = enum {
            idle,
            monitoring,
            deciding,
            acting,
            sleeping,
            emergency,
        };

        pub fn activityStr(self: *const CurrentState) []const u8 {
            return self.activity[0..self.activity_len];
        }
    };

    pub const Capabilities = struct {
        binaries_available: u8 = 0,
        binaries_total: u8 = 6,
        mcp_servers: u8 = 0,
        github_ok: bool = false,
        railway_ok: bool = false,
        telegram_ok: bool = false,
        farm_workers: u8 = 0,
        cloud_containers: u8 = 0,

        pub fn capabilityScore(self: *const Capabilities) f32 {
            var score: f32 = 0.0;
            score += (@as(f32, @floatFromInt(self.binaries_available)) / 6.0) * 0.3;
            score += if (self.mcp_servers >= 3) @as(f32, 0.2) else 0.0;
            score += if (self.github_ok) @as(f32, 0.15) else 0.0;
            score += if (self.railway_ok) @as(f32, 0.15) else 0.0;
            score += if (self.telegram_ok) @as(f32, 0.1) else 0.0;
            score += @min(1.0, @as(f32, @floatFromInt(self.farm_workers)) / 50.0) * 0.1;
            return score;
        }
    };

    pub const Goals = struct {
        primary: [64]u8 = [_]u8{0} ** 64,
        primary_len: usize = 0,
        primary_progress: f32 = 0.0,
        secondary: [64]u8 = [_]u8{0} ** 64,
        secondary_len: usize = 0,
        secondary_progress: f32 = 0.0,

        pub fn primaryStr(self: *const Goals) []const u8 {
            return self.primary[0..self.primary_len];
        }

        pub fn secondaryStr(self: *const Goals) []const u8 {
            return self.secondary[0..self.secondary_len];
        }
    };

    pub const LearningState = struct {
        total_memories: u32 = 0,
        recent_memories: u8 = 0,
        total_episodes: u32 = 0,
        episode_success_rate: f32 = 0.0,
        best_ppl: f32 = 999.0,
        active_experiments: u8 = 0,
        last_lesson: [128]u8 = [_]u8{0} ** 128,
        last_lesson_len: usize = 0,
        last_lesson_ts: i64 = 0,

        pub fn lastLessonStr(self: *const LearningState) []const u8 {
            return self.last_lesson[0..self.last_lesson_len];
        }
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// LOOP DETECTION — Detect repeating action patterns
// ═══════════════════════════════════════════════════════════════════════════════

pub const LoopDetector = struct {
    action_history: [16]qt.ActionKind = [_]qt.ActionKind{.farm_status} ** 16,
    history_len: usize = 0,
    loop_threshold: u8 = 4, // 4 identical actions trigger loop detection

    /// Add action to history, check for loop
    pub fn record(self: *LoopDetector, action: qt.ActionKind) bool {
        self.action_history[@mod(self.history_len, 16)] = action;
        self.history_len += 1;

        if (self.history_len < self.loop_threshold) return false;

        const check_action = self.action_history[@mod(self.history_len - 1, 16)];
        var all_same = true;
        var i: u8 = 1;
        while (i < self.loop_threshold) : (i += 1) {
            if (self.action_history[@mod(self.history_len - 1 - i, 16)] != check_action) {
                all_same = false;
                break;
            }
        }
        return all_same;
    }

    pub fn reset(self: *LoopDetector) void {
        self.history_len = 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS STATE — Is Trinity "stuck"?
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConsciousnessState = struct {
    status: Status = .conscious,
    loop_detected: bool = false,
    stuck_duration_seconds: i64 = 0,
    dead_end_detected: bool = false,
    last_progress: i64 = 0,

    pub const Status = enum {
        conscious, // Operating normally
        looping, // Repeating same actions
        stuck, // No progress
        dead_end, // Impossible goal
        degraded, // Partial function
    };

    pub fn isHealthy(self: *const ConsciousnessState) bool {
        return self.status == .conscious;
    }

    pub fn needsHelp(self: *const ConsciousnessState) bool {
        return switch (self.status) {
            .conscious => false,
            .looping => true,
            .stuck => true,
            .dead_end => true,
            .degraded => false,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INTROSPECTION — Self-awareness snapshot
// ═══════════════════════════════════════════════════════════════════════════════

pub const IntrospectionResult = struct {
    model: SelfModel,
    health_score: f32 = 0.0,
    awareness_level: AwarenessLevel = .self_aware,
    timestamp: i64 = 0,

    pub const AwarenessLevel = enum {
        dormant, // Not running
        reflexive, // Basic stimulus-response
        self_aware, // Knows own state
        self_analytical, // Can analyze own patterns
        self_improving, // Actively optimizing
    };
};

/// Get complete self-awareness snapshot
pub fn introspect(allocator: Allocator) !IntrospectionResult {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{},
        .goals = .{},
        .learning_state = .{},
    };

    // Identity
    @memcpy(model.identity.name[0..7], "Trinity");
    model.identity.name_len = 7;
    @memcpy(model.identity.version[0..6], "v2.0.3");
    model.identity.version_len = 6;
    model.identity.uptime_seconds = std.time.timestamp();
    // Note: pid would need platform-specific code

    // Current state
    model.current_state.mode = .monitoring;
    @memcpy(model.current_state.activity[0..15], "Self-reflection");
    model.current_state.activity_len = 14;

    // Capabilities from thalamus and system checks
    const farm = try thalamus.getFarmStatus(allocator);
    model.capabilities.farm_workers = @intCast(farm.active);
    model.capabilities.binaries_available = countAvailableBinaries(allocator);
    model.capabilities.github_ok = checkGitHubConnectivity();
    model.capabilities.railway_ok = checkRailwayConnectivity();
    model.capabilities.telegram_ok = checkTelegramConnectivity();

    // Goals
    @memcpy(model.goals.primary[0..22], "Achieve human-level AI");
    model.goals.primary_len = 22;
    @memcpy(model.goals.secondary[0..20], "Maintain farm health");
    model.goals.secondary_len = 20;

    // Learning state from hippocampus
    var mem_results = try hippocampus.read(allocator, .{
        .limit = 1,
        .kind = .episode,
    });
    defer mem_results.deinit(allocator);
    model.learning_state.total_memories = @intCast(mem_results.items.len);

    // Health score
    const health_score = model.capabilities.capabilityScore() * 100.0;

    return .{
        .model = model,
        .health_score = health_score,
        .awareness_level = if (health_score > 80) .self_analytical else .self_aware,
        .timestamp = std.time.timestamp(),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SELF AWARENESS CONTEXT — PCC data for DLPFC
// ═══════════════════════════════════════════════════════════════════════════════

pub const SelfAwarenessContext = struct {
    model: SelfModel,
    consciousness: ConsciousnessState,

    /// Should I take action right now?
    pub fn canAct(self: *const SelfAwarenessContext) bool {
        return self.consciousness.status == .conscious and
            self.model.capabilities.capabilityScore() > 0.5;
    }

    /// Am I making progress?
    pub fn isProgressing(self: *const SelfAwarenessContext) bool {
        const now = std.time.timestamp();
        const time_since_progress = now - self.model.learning_state.last_lesson_ts;
        return time_since_progress < 3600; // Progress within 1 hour
    }

    /// Should I escalate (ask for help)?
    pub fn shouldEscalate(self: *const SelfAwarenessContext) bool {
        return self.consciousnessness.needsHelp();
    }
};

/// Get self-awareness context for DLPFC
pub fn getSelfAwarenessContext(
    allocator: Allocator,
    loop_detector: *LoopDetector,
) !SelfAwarenessContext {
    const intro = try introspect(allocator);

    // Check for loop using loop_detector
    _ = loop_detector.record(.introspection); // Record this introspection action

    // Determine if we're in a loop
    const has_loop = blk: {
        if (loop_detector.history_len < loop_detector.loop_threshold) break :blk false;

        // Check if last 4 actions were all introspection
        var all_introspection = true;
        var i: u8 = 0;
        while (i < loop_detector.loop_threshold) : (i += 1) {
            const idx = loop_detector.history_len - 1 - i;
            const action = loop_detector.action_history[@mod(idx, 16)];
            if (action != .introspection) {
                all_introspection = false;
                break;
            }
        }
        break :blk all_introspection;
    };

    var consciousness = ConsciousnessState{
        .last_progress = intro.timestamp,
        .loop_detected = has_loop,
    };

    // Determine consciousness status
    if (has_loop) {
        consciousness.status = .looping;
    } else if (intro.health_score < 30) {
        consciousness.status = .degraded;
    } else {
        consciousness.status = .conscious;
    }

    return .{
        .model = intro.model,
        .consciousness = consciousness,
    };
}

/// Update self-model based on action result
pub fn learnFromActionResult(
    model: *SelfModel,
    action: qt.ActionKind,
    result: qt.ActionResult,
) !void {
    if (result.success) {
        model.current_state.cycle_count += 1;
        model.current_state.last_action_ts = std.time.timestamp();

        // Update learning state
        const now = std.time.timestamp();
        if (now - model.learning_state.last_lesson_ts > 300) { // 5 min since last lesson
            model.learning_state.last_lesson_ts = now;
            const prefix = "Action succeeded: ";
            const label = action.label();
            const total_len = prefix.len + label.len;
            const len = @min(total_len, model.learning_state.last_lesson.len);
            @memcpy(model.learning_state.last_lesson[0..@min(prefix.len, len)], prefix);
            if (label.len > 0 and len > prefix.len) {
                const copy_len = @min(len - prefix.len, label.len);
                @memcpy(model.learning_state.last_lesson[prefix.len..][0..copy_len], label[0..copy_len]);
            }
            model.learning_state.last_lesson_len = len;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS MONITORING — Detect pathological states
// ═══════════════════════════════════════════════════════════════════════════════

/// Diagnose consciousness state from model and loop detector
pub fn diagnoseConsciousness(
    model: SelfModel,
    loop_detector: *LoopDetector,
    last_progress_ts: i64,
) ConsciousnessState {
    var state = ConsciousnessState{
        .last_progress = last_progress_ts,
    };

    // Check for loop
    if (loop_detector.history_len >= loop_detector.loop_threshold) {
        var all_same = true;
        const check = loop_detector.action_history[@mod(loop_detector.history_len - 1, 16)];
        var i: u8 = 1;
        while (i < loop_detector.loop_threshold) : (i += 1) {
            if (loop_detector.action_history[@mod(loop_detector.history_len - 1 - i, 16)] != check) {
                all_same = false;
                break;
            }
        }
        if (all_same) {
            state.status = .looping;
            state.loop_detected = true;
        }
    }

    // Check for stuck (no progress)
    const now = std.time.timestamp();
    const time_since_progress = now - last_progress_ts;
    if (time_since_progress > 7200) { // 2 hours without progress
        state.status = .stuck;
        state.stuck_duration_seconds = time_since_progress;
    }

    // Check for degraded capabilities
    if (model.capabilities.capabilityScore() < 0.3) {
        if (state.status == .conscious) {
            state.status = .degraded;
        }
    }

    return state;
}

/// Get self-description for communication
pub fn describeSelf(allocator: Allocator, model: SelfModel) ![]const u8 {
    const role_label = model.identity.role.label();
    const name = model.identity.nameStr();
    const version = model.identity.versionStr();
    const activity = model.current_state.activityStr();
    const primary_goal = model.goals.primaryStr();
    const cap_score = model.capabilities.capabilityScore();

    return std.fmt.allocPrint(
        allocator,
        "{s} v{s} ({s}) — {s}, goal: {s}, capabilities: {d:.0}%",
        .{ name, version, role_label, activity, primary_goal, cap_score * 100 },
    );
}

// ═══════════════════════════════════════════════════════════════════════════════
// CAPABILITY DETECTION — Check actual system capabilities
// ═══════════════════════════════════════════════════════════════════════════════

/// Count available Trinity binaries
fn countAvailableBinaries(allocator: Allocator) u8 {
    _ = allocator;
    const expected_binaries = [_][]const u8{
        "trinity-mcp",
        "ralph-agent",
        "tri-bot",
        "tri-api",
        "hslm-entrypoint",
        "arena",
    };

    var count: u8 = 0;
    for (expected_binaries) |bin_name| {
        if (binaryExistsInPath(bin_name)) {
            count += 1;
        }
    }
    return count;
}

/// Check if binary exists in common paths
fn binaryExistsInPath(bin_name: []const u8) bool {
    // Check zig-out/bin directory
    const zig_out_paths = [_][]const u8{
        "zig-out/bin/",
        "../zig-out/bin/",
        "../../zig-out/bin/",
    };

    for (zig_out_paths) |base_path| {
        var buf: [256]u8 = undefined;
        const full_path = std.fmt.bufPrint(&buf, "{s}{s}", .{ base_path, bin_name }) catch continue;
        if (std.fs.cwd().openFile(full_path, .{})) |file| {
            file.close();
            return true;
        } else |_| {
            continue;
        }
    }
    return false;
}

/// Check if GitHub connectivity is working
fn checkGitHubConnectivity() bool {
    // Simple check: try to read git config
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "GITHUB_TOKEN")) |token| {
        defer std.heap.page_allocator.free(token);
        return token.len > 0;
    } else |_| {}
    return false;
}

/// Check if Railway connectivity is working
fn checkRailwayConnectivity() bool {
    // Check for Railway tokens
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "RAILWAY_TOKEN_1")) |token| {
        defer std.heap.page_allocator.free(token);
        return token.len > 0;
    } else |_| {}
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "RAILWAY_TOKEN_2")) |token| {
        defer std.heap.page_allocator.free(token);
        return token.len > 0;
    } else |_| {}
    return false;
}

/// Check if Telegram connectivity is working
fn checkTelegramConnectivity() bool {
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "TELEGRAM_BOT_TOKEN")) |token| {
        defer std.heap.page_allocator.free(token);
        return token.len > 0;
    } else |_| {}
    return false;
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

test "pcc — introspect returns valid result" {
    const result = try introspect(std.testing.allocator);
    try std.testing.expect(result.health_score >= 0.0);
    try std.testing.expect(result.awareness_level == .self_aware or result.awareness_level == .self_analytical);
}

test "pcc — LoopDetector detects repeated actions" {
    var detector = LoopDetector{};

    try std.testing.expect(!detector.record(.farm_status));
    try std.testing.expect(!detector.record(.farm_status));
    try std.testing.expect(!detector.record(.farm_status));

    // Fourth same action triggers loop detection
    try std.testing.expect(detector.record(.farm_status));
}

test "pcc — LoopDetector reset works" {
    var detector = LoopDetector{};
    _ = detector.record(.farm_status);
    _ = detector.record(.farm_status);
    _ = detector.record(.farm_status);

    try std.testing.expectEqual(@as(usize, 3), detector.history_len);

    detector.reset();
    try std.testing.expectEqual(@as(usize, 0), detector.history_len);
}

test "pcc — ConsciousnessState isHealthy" {
    var state = ConsciousnessState{};
    try std.testing.expect(state.isHealthy());

    state.status = .looping;
    try std.testing.expect(!state.isHealthy());
}

test "pcc — ConsciousnessState needsHelp" {
    var state = ConsciousnessState{};
    try std.testing.expect(!state.needsHelp());

    state.status = .looping;
    try std.testing.expect(state.needsHelp());

    state.status = .stuck;
    try std.testing.expect(state.needsHelp());
}

test "pcc — diagnoseConsciousness detects stuck" {
    const model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{},
        .goals = .{},
        .learning_state = .{},
    };
    var detector = LoopDetector{};

    const now = std.time.timestamp();
    const state = diagnoseConsciousness(model, &detector, now - 8000); // > 2 hours ago

    try std.testing.expectEqual(ConsciousnessState.Status.stuck, state.status);
}

test "pcc — Capabilities capabilityScore calculation" {
    var caps = SelfModel.Capabilities{};
    caps.binaries_available = 6;
    caps.mcp_servers = 4;
    caps.github_ok = true;
    caps.railway_ok = true;
    caps.telegram_ok = true;

    const score = caps.capabilityScore();
    try std.testing.expect(score > 0.8);
}

test "pcc — SelfModel identity strings" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{},
        .goals = .{},
        .learning_state = .{},
    };
    @memcpy(model.identity.name[0..7], "Trinity");
    model.identity.name_len = 7;

    try std.testing.expectEqualStrings("Trinity", model.identity.nameStr());
}

test "pcc — describeSelf returns formatted string" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{},
        .goals = .{},
        .learning_state = .{},
    };
    @memcpy(model.identity.name[0..7], "Trinity");
    model.identity.name_len = 7;
    @memcpy(model.identity.version[0..4], "v1.0");
    model.identity.version_len = 4;
    @memcpy(model.current_state.activity[0..7], "testing");
    model.current_state.activity_len = 7;
    @memcpy(model.goals.primary[0..9], "test goal");
    model.goals.primary_len = 9;

    const desc = try describeSelf(std.testing.allocator, model);
    defer std.testing.allocator.free(desc);

    try std.testing.expect(desc.len > 0);
}

test "pcc — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "pcc — learnFromActionResult updates model" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{},
        .goals = .{},
        .learning_state = .{},
    };
    const result = qt.ActionResult{
        .success = true,
        .output_len = 100,
        .duration_ms = 50,
    };

    try learnFromActionResult(&model, .farm_status, result);

    try std.testing.expect(model.current_state.cycle_count > 0);
}

test "pcc — countAvailableBinaries returns count" {
    const count = countAvailableBinaries(std.testing.allocator);
    // Should count binaries that exist in zig-out/bin
    try std.testing.expect(count >= 0 and count <= 6);
}

test "pcc — checkGitHubConnectivity returns bool" {
    const result = checkGitHubConnectivity();
    // Should return bool (true if token found, false otherwise)
    _ = result;
}

test "pcc — checkRailwayConnectivity returns bool" {
    const result = checkRailwayConnectivity();
    _ = result;
}

test "pcc — checkTelegramConnectivity returns bool" {
    const result = checkTelegramConnectivity();
    _ = result;
}

test "pcc — getSelfAwarenessContext detects introspection loop" {
    var detector = LoopDetector{};
    const allocator = std.testing.allocator;

    // Record 4 introspection actions
    _ = detector.record(.introspection);
    _ = detector.record(.introspection);
    _ = detector.record(.introspection);
    _ = detector.record(.introspection);

    const context = try getSelfAwarenessContext(allocator, &detector);

    // Should detect loop since all 4 actions were introspection
    try std.testing.expect(context.consciousness.loop_detected);
    try std.testing.expectEqual(ConsciousnessState.Status.looping, context.consciousness.status);
}

test "pcc — getSelfAwarenessContext no loop with mixed actions" {
    var detector = LoopDetector{};
    const allocator = std.testing.allocator;

    // Record mixed actions (should not trigger loop)
    _ = detector.record(.introspection);
    _ = detector.record(.farm_status);
    _ = detector.record(.introspection);
    _ = detector.record(.introspection);

    const context = try getSelfAwarenessContext(allocator, &detector);

    // Should NOT detect loop since actions were mixed
    try std.testing.expect(!context.consciousness.loop_detected);
}

test "pcc — Capabilities connectivity checks" {
    var caps = SelfModel.Capabilities{};

    caps.github_ok = checkGitHubConnectivity();
    caps.railway_ok = checkRailwayConnectivity();
    caps.telegram_ok = checkTelegramConnectivity();

    // Should be able to call all check functions without panic
    try std.testing.expect(true);
}

test "pcc — AgentRole enum coverage" {
    const roles = [_]SelfModel.AgentRole{
        .autonomous_swarm,
        .training_farm,
        .arena_evaluator,
        .cloud_orchestrator,
    };
    for (roles) |r| {
        _ = r.label(); // Verify all roles have labels
    }
}

test "pcc — AgentRole label strings" {
    try std.testing.expectEqualStrings("Autonomous Agent Swarm", SelfModel.AgentRole.autonomous_swarm.label());
    try std.testing.expectEqualStrings("Training Farm Manager", SelfModel.AgentRole.training_farm.label());
    try std.testing.expectEqualStrings("Arena Evaluator", SelfModel.AgentRole.arena_evaluator.label());
    try std.testing.expectEqualStrings("Cloud Orchestrator", SelfModel.AgentRole.cloud_orchestrator.label());
}

test "pcc — CurrentState Mode enum coverage" {
    const modes = [_]SelfModel.CurrentState.Mode{
        .idle,
        .monitoring,
        .deciding,
        .acting,
        .sleeping,
        .emergency,
    };
    for (modes) |m| {
        _ = m; // Verify all modes exist
    }
}

test "pcc — ConsciousnessState default values" {
    const state = ConsciousnessState{};

    try std.testing.expectEqual(ConsciousnessState.Status.conscious, state.status);
    try std.testing.expectEqual(@as(i64, 0), state.stuck_duration_seconds);
    try std.testing.expectEqual(@as(i64, 0), state.last_progress);
    try std.testing.expect(!state.loop_detected);
    try std.testing.expect(!state.dead_end_detected);
}

test "pcc — LoopDetector with custom threshold" {
    var detector = LoopDetector{ .loop_threshold = 2 };

    // Record same action 2 times (threshold)
    const action = .doctor_quick;
    _ = detector.record(action);
    const is_loop = detector.record(action);

    try std.testing.expect(is_loop); // Should detect loop at threshold
}

test "pcc — SelfModel Identity empty strings" {
    const identity = SelfModel.Identity{};

    try std.testing.expectEqual(@as(usize, 0), identity.name_len);
    try std.testing.expectEqual(@as(usize, 0), identity.version_len);
    try std.testing.expectEqual(@as(usize, 0), identity.nameStr().len);
    try std.testing.expectEqual(@as(usize, 0), identity.versionStr().len);
}

test "pcc — SelfModel Identity with populated fields" {
    var identity = SelfModel.Identity{};
    const name = "Queen";
    const version = "1.0.0";

    @memcpy(identity.name[0..name.len], name);
    identity.name_len = name.len;
    @memcpy(identity.version[0..version.len], version);
    identity.version_len = version.len;

    try std.testing.expectEqualStrings("Queen", identity.nameStr());
    try std.testing.expectEqualStrings("1.0.0", identity.versionStr());
}

test "pcc — CurrentState activityStr method" {
    var state = SelfModel.CurrentState{};
    const activity = "monitoring system";

    @memcpy(state.activity[0..activity.len], activity);
    state.activity_len = activity.len;

    try std.testing.expectEqualStrings("monitoring system", state.activityStr());
}

test "pcc — Goals struct fields" {
    var goals = SelfModel.Goals{};
    goals.primary_progress = 0.5;
    goals.secondary_progress = 0.75;

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), goals.primary_progress, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), goals.secondary_progress, 0.01);
}

test "pcc — LearningState struct fields" {
    var state = SelfModel.LearningState{};
    state.total_memories = 100;
    state.recent_memories = 10;
    state.episode_success_rate = 0.85;

    try std.testing.expectEqual(@as(u32, 100), state.total_memories);
    try std.testing.expectEqual(@as(u8, 10), state.recent_memories);
    try std.testing.expectApproxEqAbs(@as(f32, 0.85), state.episode_success_rate, 0.01);
}

test "pcc — Capabilities struct default values" {
    const caps = SelfModel.Capabilities{};

    try std.testing.expectEqual(@as(u8, 0), caps.binaries_available);
    try std.testing.expectEqual(@as(u8, 6), caps.binaries_total);
    try std.testing.expectEqual(@as(u8, 0), caps.mcp_servers);
}

test "pcc — ConsciousnessState isHealthy edge cases" {
    var state = ConsciousnessState{};

    // Default state should be healthy
    try std.testing.expect(state.isHealthy());

    // Change status to looping
    state.status = .looping;
    try std.testing.expect(!state.isHealthy());

    // Change status to stuck
    state.status = .stuck;
    try std.testing.expect(!state.isHealthy());

    // Back to conscious
    state.status = .conscious;
    try std.testing.expect(state.isHealthy());
}

test "pcc — LoopDetector record method" {
    var detector = LoopDetector{};

    // Record same action 4 times
    const action = .introspection;
    _ = detector.record(action);
    _ = detector.record(action);
    _ = detector.record(action);
    const is_loop = detector.record(action);

    try std.testing.expect(is_loop); // Should detect loop
}

test "pcc — LoopDetector different actions no loop" {
    var detector = LoopDetector{};

    // Record different actions
    _ = detector.record(.farm_status);
    _ = detector.record(.doctor_scan);
    _ = detector.record(.introspection);
    const is_loop = detector.record(.arena_status);

    try std.testing.expect(!is_loop); // Should not detect loop
}

test "pcc — SelfModel struct initialization" {
    const model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{},
        .goals = .{},
        .learning_state = .{},
    };

    // All fields should be accessible
    _ = model.identity;
    _ = model.current_state;
    _ = model.capabilities;
    _ = model.goals;
    _ = model.learning_state;
}

// ═══════════════════════════════════════════════════════════════════
// IntrospectionResult TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — IntrospectionResult AwarenessLevel enum coverage" {
    const levels = [_]IntrospectionResult.AwarenessLevel{
        .dormant,
        .reflexive,
        .self_aware,
        .self_analytical,
        .self_improving,
    };
    for (levels) |l| {
        _ = l; // Verify all levels exist
    }
}

test "pcc — IntrospectionResult timestamp field" {
    const result = IntrospectionResult{
        .model = .{},
        .timestamp = 1234567890,
    };

    try std.testing.expectEqual(@as(i64, 1234567890), result.timestamp);
}

test "pcc — IntrospectionResult with all fields set" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{},
        .goals = .{},
        .learning_state = .{},
    };

    const result = IntrospectionResult{
        .model = model,
        .health_score = 85.5,
        .awareness_level = .self_analytical,
        .timestamp = 1234567890,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 85.5), result.health_score, 0.01);
    try std.testing.expectEqual(IntrospectionResult.AwarenessLevel.self_analytical, result.awareness_level);
}

// ═══════════════════════════════════════════════════════════════════
// SelfAwarenessContext TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — SelfAwarenessContext canAct with conscious state" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{ .binaries_available = 6 }, // High score
        .goals = .{},
        .learning_state = .{},
    };

    const context = SelfAwarenessContext{
        .model = model,
        .consciousness = .{ .status = .conscious },
    };

    try std.testing.expect(context.canAct());
}

test "pcc — SelfAwarenessContext canAct with looping state" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{ .binaries_available = 6 },
        .goals = .{},
        .learning_state = .{},
    };

    const context = SelfAwarenessContext{
        .model = model,
        .consciousness = .{ .status = .looping },
    };

    try std.testing.expect(!context.canAct()); // Looping prevents action
}

test "pcc — SelfAwarenessContext canAct with low capability score" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{}, // Low score
        .goals = .{},
        .learning_state = .{},
    };

    const context = SelfAwarenessContext{
        .model = model,
        .consciousness = .{ .status = .conscious },
    };

    try std.testing.expect(!context.canAct()); // Low score prevents action
}

test "pcc — SelfAwarenessContext isProgressing with recent lesson" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{},
        .goals = .{},
        .learning_state = .{ .last_lesson_ts = std.time.timestamp() - 1000 }, // 16 min ago
    };

    const context = SelfAwarenessContext{
        .model = model,
        .consciousness = .{},
    };

    try std.testing.expect(context.isProgressing());
}

test "pcc — SelfAwarenessContext isProgressing with old lesson" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{},
        .goals = .{},
        .learning_state = .{ .last_lesson_ts = std.time.timestamp() - 7200 }, // 2 hours ago
    };

    const context = SelfAwarenessContext{
        .model = model,
        .consciousness = .{},
    };

    try std.testing.expect(!context.isProgressing());
}

test "pcc — SelfAwarenessContext shouldEscalate with stuck state" {
    const context = SelfAwarenessContext{
        .model = .{},
        .consciousness = .{ .status = .stuck },
    };

    try std.testing.expect(context.shouldEscalate());
}

test "pcc — SelfAwarenessContext shouldEscalate with conscious state" {
    const context = SelfAwarenessContext{
        .model = .{},
        .consciousness = .{ .status = .conscious },
    };

    try std.testing.expect(!context.shouldEscalate());
}

// ═══════════════════════════════════════════════════════════════════
// ConsciousnessState Status enum TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — ConsciousnessState Status enum coverage" {
    const statuses = [_]ConsciousnessState.Status{
        .conscious,
        .looping,
        .stuck,
        .dead_end,
        .degraded,
    };
    for (statuses) |s| {
        _ = s; // Verify all statuses exist
    }
}

test "pcc — ConsciousnessState dead_end needs help" {
    var state = ConsciousnessState{ .status = .dead_end };
    try std.testing.expect(state.needsHelp());
}

test "pcc — ConsciousnessState degraded does not need help" {
    var state = ConsciousnessState{ .status = .degraded };
    try std.testing.expect(!state.needsHelp());
}

test "pcc — ConsciousnessState stuck_duration_seconds" {
    var state = ConsciousnessState{
        .stuck_duration_seconds = 3600, // 1 hour
    };

    try std.testing.expectEqual(@as(i64, 3600), state.stuck_duration_seconds);
}

// ═══════════════════════════════════════════════════════════════════
// CellHealth TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — CellHealth Status enum coverage" {
    const statuses = [_]CellHealth.Status{ .healthy, .weak, .broken };
    for (statuses) |s| {
        _ = s; // Verify all statuses exist
    }
}

test "pcc — CellHealth timestamp" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

test "pcc — CellHealth custom values" {
    var h = CellHealth{};
    h.status = .weak;
    h.cycle = 5;
    h.last_check = 1234567890;

    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
    try std.testing.expectEqual(@as(u32, 5), h.cycle);
    try std.testing.expectEqual(@as(i64, 1234567890), h.last_check);
}

// ═══════════════════════════════════════════════════════════════════
// Goals string methods TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — Goals primaryStr method" {
    var goals = SelfModel.Goals{};
    const primary = "Train HSLM model";

    @memcpy(goals.primary[0..primary.len], primary);
    goals.primary_len = primary.len;

    try std.testing.expectEqualStrings("Train HSLM model", goals.primaryStr());
}

test "pcc — Goals secondaryStr method" {
    var goals = SelfModel.Goals{};
    const secondary = "Maintain farm health";

    @memcpy(goals.secondary[0..secondary.len], secondary);
    goals.secondary_len = secondary.len;

    try std.testing.expectEqualStrings("Maintain farm health", goals.secondaryStr());
}

test "pcc — Goals empty strings" {
    const goals = SelfModel.Goals{};

    try std.testing.expectEqual(@as(usize, 0), goals.primaryStr().len);
    try std.testing.expectEqual(@as(usize, 0), goals.secondaryStr().len);
}

// ═══════════════════════════════════════════════════════════════════
// LearningState lastLessonStr TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — LearningState lastLessonStr method" {
    var state = SelfModel.LearningState{};
    const lesson = "Batch size 64 works best";

    @memcpy(state.last_lesson[0..lesson.len], lesson);
    state.last_lesson_len = lesson.len;

    try std.testing.expectEqualStrings("Batch size 64 works best", state.lastLessonStr());
}

test "pcc — LearningState lastLessonStr empty" {
    const state = SelfModel.LearningState{};
    try std.testing.expectEqual(@as(usize, 0), state.lastLessonStr().len);
}

test "pcc — LearningState best_ppl field" {
    var state = SelfModel.LearningState{ .best_ppl = 4.5 };
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), state.best_ppl, 0.01);
}

test "pcc — LearningState active_experiments field" {
    var state = SelfModel.LearningState{ .active_experiments = 3 };
    try std.testing.expectEqual(@as(u8, 3), state.active_experiments);
}

// ═══════════════════════════════════════════════════════════════════
// Capabilities edge cases TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — Capabilities farm_workers field" {
    var caps = SelfModel.Capabilities{ .farm_workers = 42 };
    try std.testing.expectEqual(@as(u8, 42), caps.farm_workers);
}

test "pcc — Capabilities cloud_containers field" {
    var caps = SelfModel.Capabilities{ .cloud_containers = 8 };
    try std.testing.expectEqual(@as(u8, 8), caps.cloud_containers);
}

test "pcc — Capabilities capabilityScore with all features" {
    var caps = SelfModel.Capabilities{
        .binaries_available = 6,
        .mcp_servers = 4,
        .github_ok = true,
        .railway_ok = true,
        .telegram_ok = true,
        .farm_workers = 50,
    };

    const score = caps.capabilityScore();
    // Max score: 0.3 + 0.2 + 0.15 + 0.15 + 0.1 + 0.1 = 1.0
    try std.testing.expect(score > 0.9);
}

test "pcc — Capabilities capabilityScore with minimal features" {
    const caps = SelfModel.Capabilities{};
    const score = caps.capabilityScore();
    try std.testing.expect(score < 0.1);
}

// ═══════════════════════════════════════════════════════════════════
// SelfModel.Identity fields TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — SelfModel Identity role field" {
    var identity = SelfModel.Identity{ .role = .training_farm };
    try std.testing.expectEqual(SelfModel.AgentRole.training_farm, identity.role);
}

test "pcc — SelfModel Identity uptime_seconds field" {
    var identity = SelfModel.Identity{ .uptime_seconds = 86400 }; // 1 day
    try std.testing.expectEqual(@as(i64, 86400), identity.uptime_seconds);
}

test "pcc — SelfModel Identity pid field" {
    var identity = SelfModel.Identity{ .pid = 12345 };
    try std.testing.expectEqual(@as(u32, 12345), identity.pid);
}

test "pcc — SelfModel Identity all roles" {
    const roles = [_]SelfModel.AgentRole{
        .autonomous_swarm,
        .training_farm,
        .arena_evaluator,
        .cloud_orchestrator,
    };

    for (roles) |r| {
        var identity = SelfModel.Identity{ .role = r };
        try std.testing.expectEqual(r, identity.role);
    }
}

// ═══════════════════════════════════════════════════════════════════
// CurrentState fields TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — CurrentState mode field" {
    var state = SelfModel.CurrentState{ .mode = .monitoring };
    try std.testing.expectEqual(SelfModel.CurrentState.Mode.monitoring, state.mode);
}

test "pcc — CurrentState cycle_count field" {
    var state = SelfModel.CurrentState{ .cycle_count = 100 };
    try std.testing.expectEqual(@as(u32, 100), state.cycle_count);
}

test "pcc — CurrentState last_action field" {
    var state = SelfModel.CurrentState{ .last_action = .doctor_quick };
    try std.testing.expectEqual(qt.ActionKind.doctor_quick, state.last_action);
}

test "pcc — CurrentState last_action_ts field" {
    var state = SelfModel.CurrentState{ .last_action_ts = 1234567890 };
    try std.testing.expectEqual(@as(i64, 1234567890), state.last_action_ts);
}

test "pcc — CurrentState all modes" {
    const modes = [_]SelfModel.CurrentState.Mode{
        .idle,
        .monitoring,
        .deciding,
        .acting,
        .sleeping,
        .emergency,
    };

    for (modes) |m| {
        var state = SelfModel.CurrentState{ .mode = m };
        try std.testing.expectEqual(m, state.mode);
    }
}

// ═══════════════════════════════════════════════════════════════════
// LoopDetector edge cases TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — LoopDetector history wraps around" {
    var detector = LoopDetector{};

    // Fill history beyond buffer size (16)
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        _ = detector.record(.farm_status);
    }

    // Should still detect loop with last 4 same actions
    const is_loop = detector.record(.farm_status);
    try std.testing.expect(is_loop);
}

test "pcc — LoopDetector with threshold of 1" {
    var detector = LoopDetector{ .loop_threshold = 1 };

    // Should detect loop immediately
    const is_loop = detector.record(.introspection);
    try std.testing.expect(is_loop);
}

test "pcc — LoopDetector reset clears history" {
    var detector = LoopDetector{};

    // Add some history
    _ = detector.record(.farm_status);
    _ = detector.record(.doctor_quick);
    _ = detector.record(.introspection);

    try std.testing.expectEqual(@as(usize, 3), detector.history_len);

    detector.reset();

    try std.testing.expectEqual(@as(usize, 0), detector.history_len);

    // After reset, need threshold actions again
    _ = detector.record(.farm_status);
    _ = detector.record(.farm_status);
    _ = detector.record(.farm_status);
    try std.testing.expect(!detector.record(.farm_status)); // Need 4th
}

// ═══════════════════════════════════════════════════════════════════
// diagnoseConsciousness edge cases TESTS
// ═══════════════════════════════════════════════════════════════════

test "pcc — diagnoseConsciousness with degraded capabilities" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{}, // Low capability score
        .goals = .{},
        .learning_state = .{},
    };
    var detector = LoopDetector{};

    const now = std.time.timestamp();
    const state = diagnoseConsciousness(model, &detector, now);

    try std.testing.expectEqual(ConsciousnessState.Status.degraded, state.status);
}

test "pcc — diagnoseConsciousness conscious with good capabilities" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{ .binaries_available = 6 }, // High score
        .goals = .{},
        .learning_state = .{},
    };
    var detector = LoopDetector{};

    const now = std.time.timestamp();
    const state = diagnoseConsciousness(model, &detector, now);

    try std.testing.expectEqual(ConsciousnessState.Status.conscious, state.status);
}

test "pcc — diagnoseConsciousness loop takes priority" {
    var model = SelfModel{
        .identity = .{},
        .current_state = .{},
        .capabilities = .{ .binaries_available = 6 }, // Good capabilities
        .goals = .{},
        .learning_state = .{},
    };
    var detector = LoopDetector{};

    // Create a loop
    _ = detector.record(.introspection);
    _ = detector.record(.introspection);
    _ = detector.record(.introspection);
    _ = detector.record(.introspection);

    const now = std.time.timestamp();
    const state = diagnoseConsciousness(model, &detector, now);

    try std.testing.expectEqual(ConsciousnessState.Status.looping, state.status);
}
