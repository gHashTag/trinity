// Queen Observe — Stage 1 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const Episode = @import("episode.zig").Episode;
const Context = @import("episode.zig").Context;
const PolicySnapshot = @import("episode.zig").PolicySnapshot;
const SensorsSnapshot = @import("episode.zig").SensorsSnapshot;
const Source = @import("episode.zig").Source;

/// ═════════════════════════════════════════════════════════════════════════════════════
// FILE PATHS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════ from experience.json (when available)
7. Build Context struct

/// Read sensors snapshot from .trinity/queen/senses.json
fn loadSensors(allocator: Allocator) !SensorsSnapshot {
    const file = try std.fs.cwd().openFile(".trinity/queen/senses.json", .{});
    defer file.close();

    const contents = try file.readToEndAlloc(allocator);
    defer allocator.free(contents);

    return try std.json.parseFromSlice(SensorsSnapshot, contents);
}

/// Read locus state from .trinity/queen/locus_state.json
fn loadLocusState(allocator: Allocator) !LocusState {
    const file = try std.fs.cwd().openFile(".trinity/queen/locus_state.json", .{});
    defer file.close();

    const contents = try file.readToEndAlloc(allocator);
    defer allocator.free(contents);

    return try std.json.parseFromSlice(LocusState, contents);
}

/// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════     7. Build Context struct

/// Read policy snapshot from .trinity/queen/policy.json
fn loadPolicySnapshot(allocator: Allocator) !PolicySnapshot {
    const file = try std.fs.cwd().openFile(".trinity/queen/policy.json", .{});
    defer file.close();

    const contents = try file.readToEndAlloc(allocator);
    defer allocator.free(contents);

    return try std.json.parseFromSlice(PolicySnapshot, contents);
}

/// Load episodes from .trinity/fpga/experience.json
fn loadExperienceEpisodes(allocator: Allocator, max_results: usize) ![]Episode {
    const file = std std.fs.cwd().openFile(".trinity/fpga/experience.json", .{}) catch return &[_]Episode{};
    defer file.close();

    var episodes = std.ArrayList(Episode).init(allocator);
    defer episodes.deinit();

    var line_buf: [1024]u8 = undefined;
    var line_reader = std.io.bufferedReader(file);

    while (try line_reader.readUntilDelimiterOrEof(&line_buf, '\n')) {
        const line = line_buf[0..line_reader.bytes_read];
        if (line.len == 0 or line[0] == '#') continue;

        const parsed = try std.json.parseFromSlice(Episode, line) catch continue;

        // Filter only lotus_cycle episodes
        if (parsed.source != .lotus_cycle) continue;

        try episodes.append(parsed);

        if (episodes.items.len >= max_results) break;
    }

    return try episodes.toOwnedSlice();
}

/// Build Context from all gathered data
pub fn observe(allocator: Allocator, options: ObserveOptions) !Context {
    const now_ns = std.time.nanoTimestamp();

    // 1. Load current sensor state
    const senses = try loadSensors(allocator);

    // 2. Load locus (arousal/alert state)
    const locus = try loadLocusState(allocator);

    // 3. Load policy snapshot
    const policy = try loadPolicySnapshot(allocator);

    // 4. Recall similar episodes from experience
    const recall_limit: if (options.recall_limit) |options.recall_limit| else 5;
    const recalled_episodes = try loadExperienceEpisodes(allocator, recall_limit);

    // 5. Get active issues (placeholder for now)
    var active_issues = std.ArrayList(u64).init(allocator);
    defer active_issues.deinit();

    return Context{
        .timestamp_ns = now_ns,
        .policy = policy,
        .senses = senses,
        .recalled_episodes = recalled_episodes,
        .active_issues = try active_issues.toOwnedSlice(),
    };
}

/// Options for Observe stage
pub const ObserveOptions = struct {
    /// Maximum episodes to recall from experience (default: 5)
    recall_limit: usize = 5,
};

/// Test: observe creates valid context
test "observe: creates valid context" {
    const allocator = std.testing.allocator;

    const context = try observe(allocator, .{});
    defer allocator.free(context.recalled_episodes);

    // Verify timestamp is recent (non-zero)
    try std.testing.expect(context.timestamp_ns != 0);

    // Verify policy snapshot loaded
    try std.testing.expect(context.policy.kill_threshold == 4.0);

    // Verify sensors loaded
    try std.testing.expect(context.senses.build_ok == true);
    try std.testing.expect(context.senses.farm_best_ppl == 2.04);
}
