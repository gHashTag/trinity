// Queen Self-Learning — Phase 5 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Import from existing phases
pub const Episode = @import("episodes.zig").Episode;
pub const WindowEvaluation = @import("evaluate.zig").WindowEvaluation;
pub const PolicyDelta = @import("plan.zig").PolicyDelta;
pub const Outcome = @import("act.zig").Outcome;
const loadRecentEpisodes = @import("episodes.zig").loadRecentEpisodes;
const evaluateWindow = @import("evaluate.zig").evaluateWindow;
const generatePlan = @import("plan.zig").generatePlan;
const appendEpisode = @import("episodes.zig").appendEpisode;
const Context = @import("observe.zig").Context;
const PolicySnapshot = @import("observe.zig").PolicySnapshot;

/// Environment status for TRI-27
pub const EnvStatus = enum {
    active, // Normal operation
    degraded, // Reduced capacity but functional
    maintenance, // Under maintenance
};

/// TRI-27 configuration with self-learning parameters
pub const Tri27Config = struct {
    kill_threshold: f64 = 5.0, // PPL threshold for recycling workers
    crash_rate_limit: f64 = 0.1, // Maximum acceptable crash rate (0.0-1.0)
    byzantine_rate_limit: f64 = 0.1, // Maximum byzantine ratio (0.0-1.0)
    env_status: EnvStatus = .active, // Current environment status
    max_retries: u32 = 3, // Maximum retry attempts
    auto_adapt: bool = true, // Enable/disable self-learning
};

/// Self-learning cycle result
pub const SelfLearningResult = struct {
    config: Tri27Config,
    evaluation: WindowEvaluation,
    applied_deltas: u32,
    episode_recorded: bool,
};

/// Config file path
const CONFIG_PATH = ".trinity/queen/tri27_config.json";

/// Load configuration from file, create defaults if missing
pub fn loadConfig(allocator: std.mem.Allocator) !Tri27Config {
    const file = std.fs.cwd().openFile(CONFIG_PATH, .{}) catch {
        // File doesn't exist, create with defaults
        const default_config = Tri27Config{};
        try saveConfig(allocator, default_config);
        return default_config;
    };
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        // Parse error - return defaults
        const default_config = Tri27Config{};
        try saveConfig(allocator, default_config);
        return default_config;
    };
    defer allocator.free(contents);

    const parsed = std.json.parseFromSlice(Tri27Config, allocator, contents, .{}) catch {
        // Parse error - return defaults
        return Tri27Config{};
    };
    defer parsed.deinit();
    return parsed.value;
}

/// Save configuration to file
pub fn saveConfig(allocator: std.mem.Allocator, config: Tri27Config) !void {
    const dir = ".trinity/queen";
    try std.fs.cwd().makePath(dir);

    const file_path = try std.fmt.allocPrint(allocator, "{s}/tri27_config.json", .{dir});
    defer allocator.free(file_path);

    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    const json = try std.json.Stringify.valueAlloc(allocator, config, .{ .whitespace = .indent_2 });
    defer allocator.free(json);

    try file.writeAll(json);
}

/// Apply a PolicyDelta to Tri27Config with boundary clamping
pub fn applyPolicyDelta(config: *Tri27Config, delta: PolicyDelta) !bool {
    var modified: bool = false;

    switch (delta) {
        .scale_up => |su| {
            if (std.mem.eql(u8, su.key, "kill_threshold")) {
                const new_value = config.kill_threshold * su.factor;
                config.kill_threshold = @min(new_value, 10.0); // Clamp at 10.0
                modified = true;
            } else if (std.mem.eql(u8, su.key, "crash_rate_limit")) {
                const new_value = config.crash_rate_limit * su.factor;
                config.crash_rate_limit = @min(new_value, 1.0); // Clamp at 1.0
                modified = true;
            } else if (std.mem.eql(u8, su.key, "byzantine_rate_limit")) {
                const new_value = config.byzantine_rate_limit * su.factor;
                config.byzantine_rate_limit = @min(new_value, 1.0); // Clamp at 1.0
                modified = true;
            }
        },

        .scale_down => |sd| {
            if (std.mem.eql(u8, sd.key, "kill_threshold")) {
                const new_value = config.kill_threshold * sd.factor;
                config.kill_threshold = @max(new_value, 0.0); // Clamp at 0.0
                modified = true;
            } else if (std.mem.eql(u8, sd.key, "crash_rate_limit")) {
                const new_value = config.crash_rate_limit * sd.factor;
                config.crash_rate_limit = @max(new_value, 0.0); // Clamp at 0.0
                modified = true;
            } else if (std.mem.eql(u8, sd.key, "byzantine_rate_limit")) {
                const new_value = config.byzantine_rate_limit * sd.factor;
                config.byzantine_rate_limit = @max(new_value, 0.0); // Clamp at 0.0
                modified = true;
            }
        },

        .set => |s| {
            if (std.mem.eql(u8, s.key, "kill_threshold")) {
                config.kill_threshold = std.math.clamp(s.value, 0.0, 10.0);
                modified = true;
            } else if (std.mem.eql(u8, s.key, "crash_rate_limit")) {
                config.crash_rate_limit = std.math.clamp(s.value, 0.0, 1.0);
                modified = true;
            } else if (std.mem.eql(u8, s.key, "byzantine_rate_limit")) {
                config.byzantine_rate_limit = std.math.clamp(s.value, 0.0, 1.0);
                modified = true;
            }
        },

        .wait => {
            // No changes needed
        },
    }

    return modified;
}

/// Run full self-learning cycle: load episodes, evaluate, generate plan, apply deltas, save
pub fn runSelfLearningCycle(allocator: std.mem.Allocator, window_size: usize) !SelfLearningResult {
    // 1. Load current config
    var config = try loadConfig(allocator);

    // 2. Load recent episodes
    const episodes = try loadRecentEpisodes(allocator, window_size);
    defer {
        // Free memory for episodes
        for (episodes) |ep| {
            if (ep.context.active_issues.len > 0) allocator.free(ep.context.active_issues);
        }
        allocator.free(episodes);
    }

    // 3. Evaluate window
    const evaluation = evaluateWindow(episodes);

    // 4. Generate policy deltas if auto_adapt is enabled
    var applied_deltas: u32 = 0;
    if (config.auto_adapt and evaluation.quality != .unknown) {
        const deltas = try generatePlan(evaluation, allocator);
        defer allocator.free(deltas);

        // 5. Apply deltas to config
        for (deltas) |delta| {
            _ = try applyPolicyDelta(&config, delta);
            applied_deltas += 1;
        }

        // 6. Save config if modified
        if (applied_deltas > 0) {
            try saveConfig(allocator, config);
        }
    }

    // 7. Record episode about self-learning cycle
    // Create minimal episode for self-learning
    const now_ns_i128 = std.time.nanoTimestamp();
    const now_ns: u64 = @as(u64, @intCast(@abs(now_ns_i128)));
    const now_ms = std.time.milliTimestamp();
    const timestamp: u64 = @intCast(@divTrunc(now_ms, 1000));

    const episode = Episode{
        .id = now_ns,
        .timestamp = timestamp,
        .source = .external, // Self-learning comes from external system
        .context = Context{
            .timestamp_ns = now_ns,
            .policy = PolicySnapshot{
                .kill_threshold = config.kill_threshold,
                .crash_rate_limit = config.crash_rate_limit,
                .byzantine_rate_limit = config.byzantine_rate_limit,
                .god_mode = false,
                .max_auto_level = 2,
            },
            .senses = .{},
            .active_issues = try allocator.alloc(u64, 0),
            .recalled_episodes = &[_]Episode{},
        },
        .action = @import("episodes.zig").Action{
            .set = .{
                .key = "self_learning",
                .value = .{ .f64 = evaluation.success_rate },
            },
        },
        .result = @import("act.zig").Result{
            .success = applied_deltas > 0,
            .@"error" = null,
            .timing = .{
                .start_ns = now_ns,
                .end_ns = now_ns + 1_000_000,
                .duration_ms = 1,
            },
            .output = null,
            .new_senses = .{},
        },
        .outcome = if (applied_deltas > 0)
            .success
        else if (config.auto_adapt)
            .partial
        else
            .blocked,
    };

    // Write episode to JSONL
    try appendEpisode(episode, allocator);

    // Clean up allocated memory
    allocator.free(episode.context.active_issues);

    return SelfLearningResult{
        .config = config,
        .evaluation = evaluation,
        .applied_deltas = applied_deltas,
        .episode_recorded = true,
    };
}

// ═════════════════════════════════════════════════════════════════════════════
// Self-Learning Tests
// ═════════════════════════════════════════════════════════════════════════════

test "self_learning: loadConfig creates defaults when file missing" {
    const allocator = std.testing.allocator;

    // Ensure file doesn't exist (remove if present)
    std.fs.cwd().deleteFile(CONFIG_PATH) catch {};

    // loadConfig should create file with defaults
    const config = try loadConfig(allocator);

    try std.testing.expectEqual(@as(f64, 5.0), config.kill_threshold);
    try std.testing.expectEqual(@as(f64, 0.1), config.crash_rate_limit);
    try std.testing.expectEqual(@as(f64, 0.1), config.byzantine_rate_limit);
    try std.testing.expectEqual(EnvStatus.active, config.env_status);
    try std.testing.expectEqual(@as(u32, 3), config.max_retries);
    try std.testing.expectEqual(true, config.auto_adapt);

    // Clean up created file
    std.fs.cwd().deleteFile(CONFIG_PATH) catch {};
}

test "self_learning: applyPolicyDelta set operation" {
    var config = Tri27Config{ .kill_threshold = 5.0 };
    const delta = PolicyDelta{ .set = .{ .key = "kill_threshold", .value = 7.0 } };

    const modified = try applyPolicyDelta(&config, delta);

    try std.testing.expect(modified);
    try std.testing.expectEqual(@as(f64, 7.0), config.kill_threshold);
}

test "self_learning: applyPolicyDelta clamps kill_threshold at 10.0" {
    var config = Tri27Config{ .kill_threshold = 9.5 };
    const delta = PolicyDelta{ .scale_up = .{ .key = "kill_threshold", .factor = 1.2 } };

    _ = try applyPolicyDelta(&config, delta);

    // 9.5 * 1.2 = 11.4, should be clamped to 10.0
    try std.testing.expectEqual(@as(f64, 10.0), config.kill_threshold);
}

test "self_learning: full feedback loop improves quality" {
    const allocator = std.testing.allocator;

    // Ensure clean slate
    std.fs.cwd().deleteFile(CONFIG_PATH) catch {};
    const episodes_path = ".trinity/queen/episodes.jsonl";
    std.fs.cwd().deleteFile(episodes_path) catch {};

    // 1. Create 20 episodes: 14 success + 6 failure (70% → quality = bad)
    const create_episode = @import("episodes.zig").createTestEpisode;

    // First batch: 70% success rate (bad quality)
    for (0..14) |_| {
        const ep = try create_episode(allocator, .success);
        try appendEpisode(ep, allocator);
    }
    for (0..6) |_| {
        const ep = try create_episode(allocator, .failure_learned);
        try appendEpisode(ep, allocator);
    }

    // Run self-learning cycle
    const result1 = try runSelfLearningCycle(allocator, 20);

    // Check: plan contains scale_down for kill_threshold (bad quality)
    try std.testing.expect(result1.applied_deltas > 0);
    try std.testing.expect(result1.evaluation.quality == .bad);
    try std.testing.expect(result1.config.kill_threshold < 5.0); // Should have scaled down

    // 2. Add 5 more successful episodes to improve quality
    for (0..5) |_| {
        const ep = try create_episode(allocator, .success);
        try appendEpisode(ep, allocator);
    }

    // Run self-learning again
    const result2 = try runSelfLearningCycle(allocator, 25);

    // Check: quality should have improved
    // 19/25 = 76% → unstable (not bad anymore)
    try std.testing.expect(result2.evaluation.quality != .bad);
    try std.testing.expect(result2.applied_deltas > 0);
    try std.testing.expect(result2.episode_recorded);

    // Clean up
    std.fs.cwd().deleteFile(CONFIG_PATH) catch {};
    std.fs.cwd().deleteFile(episodes_path) catch {};
}
