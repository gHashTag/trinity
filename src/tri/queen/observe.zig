// Queen Observe — Stage 1 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const Episode = @import("episodes.zig").Episode;

pub const PolicySnapshot = struct {
    kill_threshold: f64 = 4.0,
    crash_rate_limit: f64 = 0.2,
    byzantine_rate_limit: f64 = 0.15,
    god_mode: bool = true,
    max_auto_level: u8 = 2,
};

pub const SensorsSnapshot = struct {
    build_ok: bool = true,
    test_rate: f64 = 100.0,
    dirty_files: u32 = 0,
    farm_services: u32 = 104,
    farm_best_ppl: f64 = 2.04,
    farm_idle_count: u32 = 0,
    arena_battles: u32 = 28,
    ouroboros_score: f64 = 0.0,
    network_ok: bool = true,
    disk_free_gb: f64 = 27.7,
    agent_count: u32 = 0,
    experience_episodes: u32 = 197,
};

pub const Context = struct {
    timestamp_ns: u64,
    policy: PolicySnapshot,
    senses: SensorsSnapshot,
    active_issues: []const u64,
    recalled_episodes: []const Episode,
};

/// Read sensors from .trinity/queen/senses.json
fn loadSensors(allocator: std.mem.Allocator) !SensorsSnapshot {
    const file = std.fs.cwd().openFile(".trinity/queen/senses.json", .{}) catch {
        return SensorsSnapshot{};
    };
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        return SensorsSnapshot{};
    };
    defer allocator.free(contents);

    const parsed = std.json.parseFromSlice(SensorsSnapshot, std.heap.page_allocator, contents, .{}) catch return SensorsSnapshot{};
    defer parsed.deinit();
    return parsed.value;
}

/// Read policy from .trinity/queen/policy.json
fn loadPolicy(allocator: std.mem.Allocator) !PolicySnapshot {
    const file = std.fs.cwd().openFile(".trinity/queen/policy.json", .{}) catch {
        return PolicySnapshot{};
    };
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        return PolicySnapshot{};
    };
    defer allocator.free(contents);

    const parsed = std.json.parseFromSlice(PolicySnapshot, std.heap.page_allocator, contents, .{}) catch return PolicySnapshot{};
    defer parsed.deinit();
    return parsed.value;
}

/// Save policy to .trinity/queen/policy.json
pub fn savePolicy(allocator: std.mem.Allocator, policy: PolicySnapshot) !void {
    const dir = ".trinity/queen";
    try std.fs.cwd().makePath(dir);

    const file_path = try std.fmt.allocPrint(allocator, "{s}/policy.json", .{dir});
    defer allocator.free(file_path);

    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    const json = try std.json.Stringify.valueAlloc(allocator, policy, .{ .whitespace = .indent_2 });
    defer allocator.free(json);

    try file.writeAll(json);
}

/// Write sensors to .trinity/queen/senses.json
pub fn writeSensors(allocator: std.mem.Allocator, sensors: SensorsSnapshot) !void {
    const dir = ".trinity/queen";
    try std.fs.cwd().makePath(dir);

    const file_path = try std.fmt.allocPrint(allocator, "{s}/senses.json", .{dir});
    defer allocator.free(file_path);

    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    const json = try std.json.Stringify.valueAlloc(allocator, sensors, .{ .whitespace = .indent_2 });
    defer allocator.free(json);

    try file.writeAll(json);
}

/// Update sensors from farm metrics (call after farm operation)
pub fn updateSensorsFromFarm(allocator: std.mem.Allocator, farm_metrics: anytype) !void {
    const dir = ".trinity/queen";
    try std.fs.cwd().makePath(dir);

    const file_path = try std.fmt.allocPrint(allocator, "{s}/senses.json", .{dir});
    defer allocator.free(file_path);

    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    // Extract metrics from farm metrics structure
    const build_ok = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "build_ok") orelse true;

    const test_rate = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "test_rate") orelse 100.0;

    const dirty_files = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "dirty_files") orelse 0;

    const farm_services = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "services") orelse 104;

    const farm_best_ppl = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "best_ppl") orelse 2.04;

    const farm_idle_count = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "idle_count") orelse 0;

    const arena_battles = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "battles") orelse 28;

    const ouroboros_score = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "ouroboros") orelse 0.0;

    const network_ok = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "network") orelse true;

    const disk_free_gb = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "disk") orelse 27.7;

    const agent_count = if (@TypeOf(farm_metrics) == std.type.Struct)
        @field(farm_metrics, "agents") orelse 0;

    // Update sensors with farm data
    const updated = SensorsSnapshot{
        .build_ok = build_ok,
        .test_rate = test_rate,
        .dirty_files = dirty_files,
        .farm_services = farm_services,
        .farm_best_ppl = farm_best_ppl,
        .farm_idle_count = farm_idle_count,
        .arena_battles = arena_battles,
        .ouroboros_score = ouroboros_score,
        .network_ok = network_ok,
        .disk_free_gb = disk_free_gb,
        .agent_count = agent_count,
        .experience_episodes = 197,
    };

    const json = try std.json.Stringify.valueAlloc(allocator, updated, .{ .whitespace = .indent_2 });
    defer allocator.free(json);

    try file.writeAll(json);
}

/// Observe: gather current state from sensors and policy
/// Observe: gather current state from sensors and policy
/// Caller owns returned slices: free active_issues and recalled_episodes
pub fn observe(allocator: std.mem.Allocator) !Context {
    const now_ns: u64 = @as(u64, @intCast(std.time.nanoTimestamp()));

    const senses = try loadSensors(allocator);
    const policy = try loadPolicy(allocator);

    const active_issues = try allocator.alloc(u64, 0);

    // Recall similar episodes from experience
    const experience = @import("experience.zig");
    const base_context = Context{
        .timestamp_ns = now_ns,
        .policy = policy,
        .senses = senses,
        .active_issues = active_issues,
        .recalled_episodes = &[_]Episode{},
    };
    const recall_scores = try experience.recallSimilarEpisodes(allocator, base_context, .{});
    defer allocator.free(recall_scores);

    // Load full recalled episodes
    var recalled = try std.ArrayList(Episode).initCapacity(allocator, recall_scores.len);
    defer recalled.deinit(allocator);

    if (recall_scores.len > 0) {
        const all_episodes = try @import("episodes.zig").loadEpisodes(allocator);
        defer allocator.free(all_episodes);

        for (recall_scores) |score| {
            for (all_episodes) |ep| {
                if (ep.id == score.episode_id) {
                    try recalled.append(allocator, ep);
                    break;
                }
            }
        }
    }

    // Return owned slices - caller must free them
    const recalled_slice = try recalled.toOwnedSlice(allocator);
    return Context{
        .timestamp_ns = now_ns,
        .policy = policy,
        .senses = senses,
        .active_issues = active_issues,
        .recalled_episodes = recalled_slice,
    };
}

test "observe: creates valid context" {
    const allocator = std.testing.allocator;

    const context = try observe(allocator);
    defer allocator.free(context.active_issues);
    defer allocator.free(context.recalled_episodes);

    try std.testing.expect(context.timestamp_ns != 0);
    try std.testing.expect(context.policy.kill_threshold > 0.0);
    try std.testing.expect(context.senses.test_rate > 0.0);
}

test "observe: savePolicy writes policy.json" {
    const allocator = std.testing.allocator;

    const policy = PolicySnapshot{
        .kill_threshold = 5.0,
        .crash_rate_limit = 0.3,
        .byzantine_rate_limit = 0.2,
        .god_mode = false,
        .max_auto_level = 3,
    };

    try savePolicy(allocator, policy);

    // Verify file was created and can be read back
    const loaded = try loadPolicy(allocator);
    try std.testing.expectEqual(5.0, loaded.kill_threshold);
    try std.testing.expectEqual(0.3, loaded.crash_rate_limit);
}

test "observe: writeSensors writes senses.json" {
    const allocator = std.testing.allocator;

    const sensors = SensorsSnapshot{
        .build_ok = false,
        .test_rate = 95.0,
        .dirty_files = 5,
        .farm_services = 100,
        .farm_best_ppl = 2.5,
    };

    try writeSensors(allocator, sensors);

    // Verify file was created and can be read back
    const loaded = try loadSensors(allocator);
    try std.testing.expectEqual(false, loaded.build_ok);
    try std.testing.expectEqual(95.0, loaded.test_rate);
    try std.testing.expectEqual(@as(u32, 5), loaded.dirty_files);
}
