// Trinity Queen API — C FFI bridge for SwiftUI dashboard
// Buffer-based JSON API (same pattern as c_api.zig)
//
// Every function: takes buf + len, writes JSON, returns bytes written.
// Swift calls these via libtrinity-queen.dylib.

const std = @import("std");

const allocator = std.heap.c_allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// VERSION
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_version() [*:0]const u8 {
    return "1.0.0";
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn readFileIntoBuffer(path: []const u8, buf: [*]u8, len: usize) usize {
    const file = std.fs.openFileAbsolute(path, .{}) catch return 0;
    defer file.close();
    const bytes_read = file.readAll(buf[0..len]) catch return 0;
    return bytes_read;
}

fn readRelativeFile(rel_path: []const u8, buf: [*]u8, len: usize) usize {
    const cwd = std.fs.cwd();
    const file = cwd.openFile(rel_path, .{}) catch return 0;
    defer file.close();
    const bytes_read = file.readAll(buf[0..len]) catch return 0;
    return bytes_read;
}

fn writeJsonField(writer: anytype, key: []const u8, value: []const u8) void {
    writer.print("\"{s}\":{s}", .{ key, value }) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_sacred_constants(buf: [*]u8, len: usize) usize {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const phi_sq = phi * phi;
    const inv_phi_sq = 1.0 / phi_sq;
    const trinity_identity = phi_sq + inv_phi_sq; // = 3.0

    var fbs = std.io.fixedBufferStream(buf[0..len]);
    const w = fbs.writer();

    w.print(
        \\{{"phi":{d:.10},"phi_squared":{d:.10},"inv_phi_squared":{d:.10},
    , .{ phi, phi_sq, inv_phi_sq }) catch return 0;

    w.print(
        \\"trinity_identity":{d:.10},"bits_per_trit":1.58496,
    , .{trinity_identity}) catch return 0;

    w.print(
        \\"max_dim":59049,"dim_3k":[3,9,27,81,243,729,2187,6561,19683,59049],
    , .{}) catch return 0;

    w.print(
        \\"delta_cp":248.75,"w0":-0.618}}
    , .{}) catch return 0;

    return fbs.pos;
}

// ═══════════════════════════════════════════════════════════════════════════════
// OUROBOROS STATE
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_ouroboros_state(buf: [*]u8, len: usize) usize {
    return readRelativeFile(".trinity/ouroboros_state.json", buf, len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FACULTY SNAPSHOT
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_faculty_snapshot(buf: [*]u8, len: usize) usize {
    // Read heartbeats from all agents
    var fbs = std.io.fixedBufferStream(buf[0..len]);
    const w = fbs.writer();

    w.print("{{\"agents\":[", .{}) catch return 0;

    const agents = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "mu", .path = ".trinity/mu/heartbeat.json" },
        .{ .name = "scholar", .path = ".trinity/scholar/heartbeat.json" },
    };

    for (agents, 0..) |agent, idx| {
        if (idx > 0) w.print(",", .{}) catch {};

        // Try to read heartbeat file
        var hb_buf: [1024]u8 = undefined;
        const hb_len = readRelativeFile(agent.path, &hb_buf, hb_buf.len);

        if (hb_len > 0) {
            w.print("{{\"name\":\"{s}\",\"status\":\"UP\",\"heartbeat\":{s}}}", .{ agent.name, hb_buf[0..hb_len] }) catch {};
        } else {
            w.print("{{\"name\":\"{s}\",\"status\":\"DOWN\",\"heartbeat\":null}}", .{agent.name}) catch {};
        }
    }

    w.print("]}}", .{}) catch return 0;
    return fbs.pos;
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVOLUTION SUMMARY (last N lines from farm events)
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_farm_events(buf: [*]u8, len: usize, last_n: usize) usize {
    const cwd = std.fs.cwd();
    const file = cwd.openFile(".trinity/farm/events.jsonl", .{}) catch return 0;
    defer file.close();

    // Read entire file into temp buffer, then extract last N lines
    var temp_buf = allocator.alloc(u8, 256 * 1024) catch return 0;
    defer allocator.free(temp_buf);

    const total = file.readAll(temp_buf) catch return 0;
    if (total == 0) return 0;

    // Find last N newlines
    var line_starts = std.ArrayListUnmanaged(usize){};
    defer line_starts.deinit(allocator);

    line_starts.append(allocator, 0) catch return 0;
    for (0..total) |i| {
        if (temp_buf[i] == '\n' and i + 1 < total) {
            line_starts.append(allocator, i + 1) catch return 0;
        }
    }

    const n = @min(last_n, line_starts.items.len);
    const start_idx = line_starts.items.len - n;
    const start_pos = line_starts.items[start_idx];

    var fbs = std.io.fixedBufferStream(buf[0..len]);
    const w = fbs.writer();

    w.print("{{\"events\":[", .{}) catch return 0;

    var count: usize = 0;
    var line_begin = start_pos;
    for (start_pos..total) |i| {
        if (temp_buf[i] == '\n' or i == total - 1) {
            const end = if (temp_buf[i] == '\n') i else i + 1;
            if (end > line_begin) {
                if (count > 0) w.print(",", .{}) catch {};
                w.writeAll(temp_buf[line_begin..end]) catch {};
                count += 1;
            }
            line_begin = i + 1;
        }
    }

    w.print("]}}", .{}) catch return 0;
    return fbs.pos;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SWARM STATE
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_swarm_state(buf: [*]u8, len: usize) usize {
    return readRelativeFile(".trinity/swarm_state.json", buf, len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUILD STATUS
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_build_status(buf: [*]u8, len: usize) usize {
    var fbs = std.io.fixedBufferStream(buf[0..len]);
    const w = fbs.writer();

    // Check build by reading e2e results
    var e2e_buf: [4096]u8 = undefined;
    const e2e_len = readRelativeFile(".trinity/e2e_results.json", &e2e_buf, e2e_buf.len);

    w.print("{{\"binaries\":[\"trinity-mcp\",\"ralph-agent\",\"ralph-hook\",\"tri-bot\",\"tri-api\",\"hslm-entrypoint\"]", .{}) catch return 0;
    w.print(",\"binary_count\":6", .{}) catch return 0;

    if (e2e_len > 0) {
        w.print(",\"e2e_results\":{s}", .{e2e_buf[0..e2e_len]}) catch {};
    }

    w.print("}}", .{}) catch return 0;
    return fbs.pos;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PATENT STATUS
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_patent_status(buf: [*]u8, len: usize) usize {
    return readRelativeFile(".trinity/patent/status.json", buf, len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TECH TREE
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_tech_tree(buf: [*]u8, len: usize) usize {
    return readRelativeFile(".trinity/tech_tree.json", buf, len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ARENA LEADERBOARD (computed from results)
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_arena_leaderboard(buf: [*]u8, len: usize) usize {
    return readRelativeFile(".trinity/arena_results.json", buf, len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPERIENCE RECENT
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_experience_recent(buf: [*]u8, len: usize, n: usize) usize {
    _ = n;
    // List recent experience episodes
    const cwd = std.fs.cwd();
    var dir = cwd.openDir(".trinity/experience/episodes", .{ .iterate = true }) catch {
        var fbs = std.io.fixedBufferStream(buf[0..len]);
        const w = fbs.writer();
        w.print("{{\"episodes\":[]}}", .{}) catch return 0;
        return fbs.pos;
    };
    defer dir.close();

    var fbs = std.io.fixedBufferStream(buf[0..len]);
    const w = fbs.writer();
    w.print("{{\"episodes\":[", .{}) catch return 0;

    var count: usize = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        if (count > 0) w.print(",", .{}) catch {};
        w.print("\"{s}\"", .{entry.name}) catch {};
        count += 1;
        if (count >= 20) break;
    }

    w.print("],\"count\":{d}}}", .{count}) catch return 0;
    return fbs.pos;
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN v4 — Senses, State, Actions, Audit
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_queen_senses(buf: [*]u8, len: usize) usize {
    return readRelativeFile(".trinity/queen/senses.json", buf, len);
}

export fn trinity_queen_queen_state(buf: [*]u8, len: usize) usize {
    return readRelativeFile(".trinity/queen_state.json", buf, len);
}

export fn trinity_queen_actions_list(buf: [*]u8, len: usize) usize {
    return readRelativeFile(".trinity/queen/actions.json", buf, len);
}

export fn trinity_queen_audit_recent(n: usize, buf: [*]u8, len: usize) usize {
    const cwd = std.fs.cwd();
    const file = cwd.openFile(".trinity/queen/audit.jsonl", .{}) catch return 0;
    defer file.close();

    var temp_buf = allocator.alloc(u8, 128 * 1024) catch return 0;
    defer allocator.free(temp_buf);

    const total = file.readAll(temp_buf) catch return 0;
    if (total == 0) return 0;

    // Find last N newlines
    var line_starts = std.ArrayListUnmanaged(usize){};
    defer line_starts.deinit(allocator);

    line_starts.append(allocator, 0) catch return 0;
    for (0..total) |i| {
        if (temp_buf[i] == '\n' and i + 1 < total) {
            line_starts.append(allocator, i + 1) catch return 0;
        }
    }

    const count = @min(n, line_starts.items.len);
    const start_idx = line_starts.items.len - count;
    const start_pos = line_starts.items[start_idx];

    var fbs = std.io.fixedBufferStream(buf[0..len]);
    const w = fbs.writer();

    w.print("{{\"entries\":[", .{}) catch return 0;

    var entry_count: usize = 0;
    var line_begin = start_pos;
    for (start_pos..total) |i| {
        if (temp_buf[i] == '\n' or i == total - 1) {
            const end = if (temp_buf[i] == '\n') i else i + 1;
            if (end > line_begin) {
                if (entry_count > 0) w.print(",", .{}) catch {};
                w.writeAll(temp_buf[line_begin..end]) catch {};
                entry_count += 1;
            }
            line_begin = i + 1;
        }
    }

    w.print("]}}", .{}) catch return 0;
    return fbs.pos;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "sacred constants JSON" {
    var buf: [2048]u8 = undefined;
    const n = trinity_queen_sacred_constants(&buf, buf.len);
    try std.testing.expect(n > 0);

    // Should contain phi
    const json = buf[0..n];
    try std.testing.expect(std.mem.indexOf(u8, json, "phi") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "1.618") != null);
}

test "version" {
    const v = trinity_queen_version();
    try std.testing.expectEqualStrings("1.0.0", std.mem.span(v));
}

test "faculty snapshot produces valid JSON" {
    var buf: [4096]u8 = undefined;
    const n = trinity_queen_faculty_snapshot(&buf, buf.len);
    try std.testing.expect(n > 0);
    const json = buf[0..n];
    try std.testing.expect(std.mem.indexOf(u8, json, "agents") != null);
}

test "build status produces valid JSON" {
    var buf: [4096]u8 = undefined;
    const n = trinity_queen_build_status(&buf, buf.len);
    try std.testing.expect(n > 0);
    const json = buf[0..n];
    try std.testing.expect(std.mem.indexOf(u8, json, "binaries") != null);
}
