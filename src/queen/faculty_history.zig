// @origin(manual)
// ═══════════════════════════════════════════════════════════════════════════════
// FACULTY HISTORY — Persistent metrics storage for trend analysis
// ═══════════════════════════════════════════════════════════════════════════════
// Resolves FIXME in queen_dlpfc.zig
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const faculty_types = @import("faculty_types.zig");

const FacultyMetrics = @This();
const FacultySnapshot = faculty_types.FacultySnapshot;
const FacultyDelta = faculty_types.FacultyDelta;

/// History storage path
const HISTORY_PATH = ".tri-queen/faculty_history.jsonl";

/// Maximum history entries (append-only rotation)
const MAX_HISTORY: usize = 100;

/// Load faculty metrics history from disk
pub fn loadHistory(allocator: Allocator) ![]FacultyMetrics {
    const cwd = std.fs.cwd();

    // Try to open history file
    const file = cwd.openFile(HISTORY_PATH, .{}) catch |err| switch (err) {
        error.FileNotFound => return &.{};
        else => return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024); // Max 1MB
    defer allocator.free(content);

    if (content.len == 0) return &.{};

    // Parse JSONL (one JSON object per line)
    var history = std.ArrayList(FacultyMetrics).init(allocator);
    errdefer history.deinit(allocator);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // Parse FacultySnapshot from JSON
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            allocator,
            line,
        );
        defer allocator.free(parsed);

        const snapshot = try parseFacultySnapshot(allocator, parsed);
        var delta: FacultyDelta = .{};

        // Calculate delta from previous entry if available
        if (history.items.len > 0) {
            const prev = &history.items[history.items.len - 1];
            delta = try calculateDelta(&prev.snapshot, snapshot, prev.collected_at);
        }

        try history.append(.{
            .snapshot = snapshot,
            .delta = delta,
            .collected_at = std.time.timestamp(),
        });
    }

    return history.toOwnedSlice(allocator);
}

/// Save faculty metrics to history (append)
pub fn appendToHistory(allocator: Allocator, metrics: FacultyMetrics) !void {
    const cwd = std.fs.cwd();

    // Create .tri-queen directory if needed
    {
        var parts = std.mem.splitSequence(u8, HISTORY_PATH, "/");
        var path_buf: [1024]u8 = undefined;
        var accumulated: usize = 0;

        while (parts.next()) |part| {
            if (part.len == 0) continue;
            const path = path_buf[0..accumulated + part.len];
            @memcpy(path, part);
            accumulated += part.len;

            // Try to create directory
            cwd.makePath(path_buf[0..accumulated]) catch {};
        }
    }

    // Open file for append (create if doesn't exist)
    const file = try cwd.openFile(HISTORY_PATH, .{ .mode = .write });
    defer file.close();

    try file.seekFromEnd(0);

    // Serialize metrics as JSON
    const json = try std.json.stringifyAlloc(allocator, metrics.snapshot, .{ .whitespace = .minified });
    defer allocator.free(json);

    try file.writeAll(json);
    try file.writeAll("\n");
}

/// Rotate history if exceeds MAX_HISTORY
pub fn rotateHistory(allocator: Allocator) !void {
    const history = try loadHistory(allocator);
    defer {
        for (history) |h| {
            allocator.free(h.snapshot.json_raw);
        }
        allocator.free(history);
    };

    if (history.len <= MAX_HISTORY) return;

    // Keep only last MAX_HISTORY entries
    const cwd = std.fs.cwd();
    const file = try cwd.createFile(HISTORY_PATH, .{ .truncate = true });
    defer file.close();

    const start = history.len - MAX_HISTORY;
    for (history[start..]) |entry| {
        const json = try std.json.stringifyAlloc(allocator, entry.snapshot, .{ .whitespace = .minified });
        defer allocator.free(json);

        try file.writeAll(json);
        try file.writeAll("\n");
    }
}

/// Parse FacultySnapshot from JSON value
fn parseFacultySnapshot(allocator: Allocator, value: std.json.Value) !FacultySnapshot {
    _ = allocator;
    const obj = &value.object;

    var snapshot: FacultySnapshot = undefined;

    // Parse agents array
    if (obj.get("agents")) |agents_val| {
        const agents_array = agents_val.array;
        var i: usize = 0;
        for (agents_array) |agent_val| {
            if (i >= snapshot.agents.len) break;
            const agent_obj = agent_val.object;
            const agent_state = &snapshot.agents[i];

            // Parse agent type
            if (agent_obj.get("agent")) |agent_type| {
                agent_state.agent = parseAgent(agent_type.string);
            }

            // Parse status
            if (agent_obj.get("status")) |status_val| {
                agent_state.status = parseAgentStatus(status_val.string);
            }

            i += 1;
        }
    }

    // Parse simple fields
    if (obj.get("build_ok")) |v| snapshot.build_ok = v.bool;
    if (obj.get("binaries")) |v| snapshot.binaries = @intCast(v.integer);
    if (obj.get("compile_pass")) |v| snapshot.compile_pass = @intCast(v.integer);
    if (obj.get("compile_total")) |v| snapshot.compile_total = @intCast(v.integer);
    if (obj.get("compile_rate")) |v| snapshot.compile_rate = @intCast(v.integer);
    if (obj.get("v_number")) |v| snapshot.v_number = @floatCast(v.float);
    if (obj.get("dirty_files")) |v| snapshot.dirty_files = @intCast(v.integer);
    if (obj.get("open_issues")) |v| snapshot.open_issues = @intCast(v.integer);
    if (obj.get("mu_patterns")) |v| snapshot.mu_patterns = @intCast(v.integer);

    // Parse v_zone
    if (obj.get("v_zone")) |v| snapshot.v_zone = parseVZone(v.string);

    return snapshot;
}

fn parseAgent(name: []const u8) faculty_types.Agent {
    return std.mem.eql(u8, name, "ralph") or
        std.mem.indexOf(u8, name, "ralph") != null
    {
        .ralph
    } else std.mem.eql(u8, name, "scholar") or
        std.mem.indexOf(u8, name, "scholar") != null
    {
        .scholar
    } else std.mem.eql(u8, name, "mu") or
        std.mem.indexOf(u8, name, "mu") != null
    {
        .mu
    } else std.mem.eql(u8, name, "oracle") or
        std.mem.indexOf(u8, name, "oracle") != null
    {
        .oracle
    } else std.mem.eql(u8, name, "swarm") or
        std.mem.indexOf(u8, name, "swarm") != null
    {
        .swarm
    } else {
        .linter
    };
}

fn parseAgentStatus(status: []const u8) faculty_types.AgentStatus {
    return std.mem.eql(u8, status, "up") or
        std.mem.indexOf(u8, status, "up") != null
    {
        .up
    } else std.mem.eql(u8, status, "down") or
        std.mem.indexOf(u8, status, "down") != null
    {
        .down
    } else std.mem.eql(u8, status, "stub") or
        std.mem.indexOf(u8, status, "stub") != null
    {
        .stub
    } else {
        .tbd
    };
}

fn parseVZone(zone: []const u8) faculty_types.VZone {
    return std.mem.eql(u8, zone, "gold") or
        std.mem.indexOf(u8, zone, "gold") != null
    {
        .gold
    } else std.mem.eql(u8, zone, "stable") or
        std.mem.indexOf(u8, zone, "stable") != null
    {
        .stable
    } else {
        .drift
    };
}

/// Calculate delta between two snapshots
pub fn calculateDelta(prev: *const FacultySnapshot, curr: FacultySnapshot, prev_ts: i64) !FacultyDelta {
    const now = std.time.timestamp();
    const seconds_ago = now - prev_ts;

    return FacultyDelta{
        .has_prev = true,
        .seconds_ago = seconds_ago,
        .compile_rate_delta = @intCast(curr.compile_rate) - @intCast(prev.compile_rate),
        .active_delta = @intCast(curr.activeFaculty()) - @intCast(prev.activeFaculty()),
        .dirty_delta = @intCast(curr.dirty_files) - @intCast(prev.dirty_files),
        .prev_compile_rate = prev.compile_rate,
        .prev_active = prev.activeFaculty(),
        .prev_dirty = prev.dirty_files,
        .prev_compile_pass = prev.compile_pass,
        .prev_compile_total = prev.compile_total,
        .prev_issues = prev.open_issues,
    };
}

test "faculty history load/save roundtrip" {
    const allocator = std.testing.allocator;

    // Save a test entry
    var test_snapshot: FacultySnapshot = .{
        .agents = undefined, // Would need full init
        .build_ok = true,
        .binaries = 50,
        .compile_pass = 45,
        .compile_total = 50,
        .compile_rate = 90,
        .v_number = 1.5,
        .v_zone = .gold,
        .git_branch = "main",
        .dirty_files = 10,
        .open_issues = 5,
        .mu_patterns = 100,
        .cycle = .working,
    };

    const test_metrics = FacultyMetrics{
        .snapshot = test_snapshot,
        .delta = .{},
        .collected_at = std.time.timestamp(),
    };

    try appendToHistory(allocator, test_metrics);

    // Load and verify
    const loaded = try loadHistory(allocator);
    defer allocator.free(loaded);

    try std.testing.expect(loaded.len > 0);
}
