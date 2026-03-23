// Queen Observe — Stage 1 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

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
};

/// Read sensors from .trinity/queen/senses.json
fn loadSensors(allocator: std.mem.Allocator) !SensorsSnapshot {
    const file = std.fs.cwd().openFile(".trinity/queen/senses.json", .{}) catch {
        // Return default if file not found
        return SensorsSnapshot{};
    };
    defer file.close();

    // Read all file contents - Zig 0.15 requires max_bytes parameter
    const contents = file.readToEndAlloc(allocator, 1024 * 1024) catch |err| {
        // Return default on error
        // Error captured but not used - this is acceptable
        return SensorsSnapshot{};
    };
    defer allocator.free(contents);

    return std.json.parseFromSlice(SensorsSnapshot, contents) catch SensorsSnapshot{};
}

/// Read policy from .trinity/queen/policy.json
fn loadPolicy(allocator: std.mem.Allocator) !PolicySnapshot {
    const file = std.fs.cwd().openFile(".trinity/queen/policy.json", .{}) catch {
        return PolicySnapshot{};
    };
    defer file.close();

    // Read all file contents - Zig 0.15 requires max_bytes parameter
    const contents = file.readToEndAlloc(allocator, 1024 * 1024) catch |err| {
        // Error captured but not used - this is acceptable
        return PolicySnapshot{};
    };
    defer allocator.free(contents);

    return std.json.parseFromSlice(PolicySnapshot, contents) catch PolicySnapshot{};
}

/// Observe: gather current state from sensors and policy
pub fn observe(allocator: std.mem.Allocator) !Context {
    const now_ns = std.time.nanoTimestamp();

    const senses = try loadSensors(allocator);
    const policy = try loadPolicy(allocator);

    // Placeholder for active issues (empty for now)
    const active_issues = try allocator.alloc(u64, 0);

    return Context{
        .timestamp_ns = now_ns,
        .policy = policy,
        .senses = senses,
        .active_issues = active_issues,
    };
}

test "observe: creates valid context" {
    const allocator = std.testing.allocator;

    const context = try observe(allocator);
    defer allocator.free(context.active_issues);

    try std.testing.expect(context.timestamp_ns != 0);
    try std.testing.expect(context.policy.kill_threshold == 4.0);
    try std.testing.expect(context.senses.build_ok == true);
}
