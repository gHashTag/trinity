// ═══════════════════════════════════════════════════════════════════════════════
// Voice Engine — Agent voice generator for Faculty Board
// ═══════════════════════════════════════════════════════════════════════════════
// Each agent speaks in character based on their state and the system snapshot.
// No allocations — writes into caller-owned buffer via bufPrint.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("faculty_types.zig");
const AgentState = types.AgentState;
const FacultySnapshot = types.FacultySnapshot;
const FacultyDelta = types.FacultyDelta;

const MuHeartbeat = struct {
    wake: u32 = 0,
    fixes: u32 = 0,
    errors: u32 = 0,
    age_s: i64 = 0,
    test_ok: bool = false,
    build_ok: bool = false,
};

/// Read last git commit subject line (max 80 chars).
fn readLastCommit(buf: []u8) []const u8 {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &.{ "git", "log", "--oneline", "-1", "--format=%s" },
        .max_output_bytes = 256,
    }) catch return "";
    defer std.heap.page_allocator.free(result.stdout);
    defer std.heap.page_allocator.free(result.stderr);
    const trimmed = std.mem.trim(u8, result.stdout, " \t\n\r");
    if (trimmed.len == 0) return "";
    const copy_len = @min(trimmed.len, buf.len);
    @memcpy(buf[0..copy_len], trimmed[0..copy_len]);
    return buf[0..copy_len];
}

/// Read last agent command for a given emoji prefix from agent_commands.log.
fn readLastAgentCmd(emoji: []const u8, buf: []u8) []const u8 {
    const file = std.fs.cwd().openFile(".trinity/agent_commands.log", .{}) catch return "";
    defer file.close();
    var file_buf: [4096]u8 = undefined;
    const n = file.readAll(&file_buf) catch return "";
    const data = file_buf[0..n];

    // Find last line containing the emoji
    var last_line: ?[]const u8 = null;
    var iter = std.mem.splitScalar(u8, data, '\n');
    while (iter.next()) |line| {
        if (std.mem.indexOf(u8, line, emoji) != null) {
            last_line = line;
        }
    }
    const line = last_line orelse return "";
    // Extract command after emoji (skip "HH:MM 🤖 " prefix)
    if (std.mem.indexOf(u8, line, "tri ")) |pos| {
        const cmd = line[pos..];
        const copy_len = @min(cmd.len, buf.len);
        @memcpy(buf[0..copy_len], cmd[0..copy_len]);
        return buf[0..copy_len];
    }
    return "";
}

/// Generate a voice line for the given agent based on system state and delta.
/// Returns a slice into `buf`.
pub fn generateVoice(agent: AgentState, snapshot: FacultySnapshot, delta: FacultyDelta, buf: []u8) []const u8 {
    return switch (agent.agent) {
        .ralph => ralphVoice(agent, snapshot, delta, buf),
        .scholar => scholarVoice(agent, buf),
        .mu => muVoice(agent, snapshot, delta, buf),
        .oracle => oracleVoice(snapshot, delta, buf),
        .swarm => swarmVoice(agent, buf),
        .linter => linterVoice(agent, snapshot, delta, buf),
    };
}

fn ralphVoice(agent: AgentState, snapshot: FacultySnapshot, delta: FacultyDelta, buf: []u8) []const u8 {
    return switch (agent.status) {
        .up => blk: {
            if (delta.has_prev) {
                if (delta.compile_rate_delta > 0) {
                    break :blk std.fmt.bufPrint(buf, "Build {d}/{d} (+{d}pp). \xd0\x94\xd0\xb2\xd0\xb8\xd0\xb3\xd0\xb0\xd0\xb5\xd0\xbc\xd1\x81\xd1\x8f.", .{
                        snapshot.compile_pass, snapshot.compile_total, delta.compile_rate_delta,
                    }) catch "Ralph работает.";
                } else if (delta.compile_rate_delta < 0) {
                    break :blk std.fmt.bufPrint(buf, "Build {d}/{d} ({d}pp). \xd0\xa0\xd0\xb5\xd0\xb3\xd1\x80\xd0\xb5\xd1\x81\xd1\x81\xd0\xb8\xd1\x8f!", .{
                        snapshot.compile_pass, snapshot.compile_total, delta.compile_rate_delta,
                    }) catch "Ralph работает.";
                } else if (delta.compile_frozen and snapshot.compile_rate < 100) {
                    const hours = @divTrunc(delta.seconds_ago, 3600);
                    break :blk std.fmt.bufPrint(buf, "Build {d}/{d}. \xd0\x9f\xd0\xbb\xd0\xb0\xd1\x82\xd0\xbe {d}\xd1\x87. \xd0\x9d\xd1\x83\xd0\xb6\xd0\xb5\xd0\xbd \xd1\x82\xd0\xbe\xd0\xbb\xd1\x87\xd0\xbe\xd0\xba.", .{
                        snapshot.compile_pass, snapshot.compile_total, hours,
                    }) catch "Ralph работает.";
                } else if (snapshot.dirty_files > 15) {
                    break :blk std.fmt.bufPrint(buf, "Build {d}/{d}. {d} dirty \xe2\x80\x94 \xd0\xbd\xd0\xb0\xd0\xb4\xd0\xbe \xd0\xba\xd0\xbe\xd0\xbc\xd0\xbc\xd0\xb8\xd1\x82\xd0\xb8\xd1\x82\xd1\x8c.", .{
                        snapshot.compile_pass, snapshot.compile_total, snapshot.dirty_files,
                    }) catch "Ralph работает.";
                }
            }
            // v2: show last git commit for live context
            var commit_buf: [80]u8 = undefined;
            const last_commit = readLastCommit(&commit_buf);
            if (last_commit.len > 0) {
                break :blk std.fmt.bufPrint(buf, "{d}/{d}. \xd0\x9f\xd0\xbe\xd1\x81\xd0\xbb\xd0\xb5\xd0\xb4\xd0\xbd\xd0\xb8\xd0\xb9: {s}", .{
                    snapshot.compile_pass, snapshot.compile_total, last_commit,
                }) catch "Ralph работает.";
            }
            break :blk std.fmt.bufPrint(buf, "\xd0\x9d\xd0\xb0 \xd0\xbf\xd0\xbe\xd1\x81\xd1\x82\xd1\x83. Build {d}/{d}.", .{
                snapshot.compile_pass, snapshot.compile_total,
            }) catch "Ralph работает.";
        },
        .down => std.fmt.bufPrint(buf, "\xd0\x9b\xd0\xb5\xd0\xb6\xd1\x83. \xd0\x9f\xd0\xb5\xd1\x80\xd0\xb5\xd0\xb7\xd0\xb0\xd0\xbf\xd1\x83\xd1\x81\xd1\x82\xd0\xb8\xd1\x82\xd0\xb5.", .{}) catch "Ralph лежит.",
        .stub, .tbd => std.fmt.bufPrint(buf, "\xd0\x9d\xd0\xb5 \xd0\xb0\xd0\xba\xd1\x82\xd0\xb8\xd0\xb2\xd0\xb8\xd1\x80\xd0\xbe\xd0\xb2\xd0\xb0\xd0\xbd.", .{}) catch "Ralph не активен.",
    };
}

fn scholarVoice(agent: AgentState, buf: []u8) []const u8 {
    return switch (agent.status) {
        .tbd => std.fmt.bufPrint(buf, "\xd0\x9d\xd0\x95 \xd0\x9d\xd0\x90\xd0\x9d\xd0\xaf\xd0\xa2. Ralph \xd0\xb3\xd0\xb0\xd0\xb4\xd0\xb0\xd0\xb5\xd1\x82 \xd0\xb1\xd0\xb5\xd0\xb7 \xd0\xba\xd0\xbe\xd0\xbd\xd1\x82\xd0\xb5\xd0\xba\xd1\x81\xd1\x82\xd0\xb0.", .{}) catch "Scholar TBD.",
        .up => blk: {
            // v2: read scholar heartbeat for live data
            const hb = readScholarHeartbeat();
            if (hb.wake > 0) {
                if (hb.fed_mu > 0) {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. Researched {d}, fed MU {d}.", .{
                        hb.wake, hb.researched, hb.fed_mu,
                    }) catch "Scholar \xd0\xb8\xd1\x89\xd0\xb5\xd1\x82.";
                } else if (hb.fails_found > 0) {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. {d} \xd1\x84\xd0\xb5\xd0\xb9\xd0\xbb\xd0\xbe\xd0\xb2. \xd0\x98\xd1\x89\xd1\x83 \xd0\xbf\xd0\xb0\xd1\x82\xd1\x82\xd0\xb5\xd1\x80\xd0\xbd\xd1\x8b.", .{
                        hb.wake, hb.fails_found,
                    }) catch "Scholar \xd0\xb8\xd1\x89\xd0\xb5\xd1\x82.";
                } else {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. 0 \xd1\x84\xd0\xb5\xd0\xb9\xd0\xbb\xd0\xbe\xd0\xb2. \xd0\x92\xd1\x81\xd1\x91 \xd1\x87\xd0\xb8\xd1\x81\xd1\x82\xd0\xbe.", .{
                        hb.wake,
                    }) catch "Scholar: \xd1\x87\xd0\xb8\xd1\x81\xd1\x82\xd0\xbe.";
                }
            }
            if (agent.last_action.len > 0)
                break :blk std.fmt.bufPrint(buf, "\xd0\x98\xd1\x89\xd1\x83: {s}.", .{agent.last_action}) catch "Scholar \xd0\xb8\xd1\x89\xd0\xb5\xd1\x82."
            else
                break :blk std.fmt.bufPrint(buf, "\xd0\x98\xd1\x89\xd1\x83 \xd0\xb8\xd0\xbd\xd1\x84\xd0\xbe\xd1\x80\xd0\xbc\xd0\xb0\xd1\x86\xd0\xb8\xd1\x8e.", .{}) catch "Scholar \xd0\xb8\xd1\x89\xd0\xb5\xd1\x82.";
        },
        .stub => std.fmt.bufPrint(buf, "\xd0\x97\xd0\xb0\xd0\xb3\xd0\xbb\xd1\x83\xd1\x88\xd0\xba\xd0\xb0. \xd0\x9d\xd1\x83\xd0\xb6\xd0\xbd\xd0\xb0 \xd0\xb8\xd0\xbc\xd0\xbf\xd0\xbb\xd0\xb5\xd0\xbc\xd0\xb5\xd0\xbd\xd1\x82\xd0\xb0\xd1\x86\xd0\xb8\xd1\x8f.", .{}) catch "Scholar stub.",
        .down => std.fmt.bufPrint(buf, "\xd0\xa3\xd0\xbf\xd0\xb0\xd0\xbb. \xd0\x98\xd1\x81\xd1\x81\xd0\xbb\xd0\xb5\xd0\xb4\xd0\xbe\xd0\xb2\xd0\xb0\xd0\xbd\xd0\xb8\xd1\x8f \xd0\xb2\xd1\x81\xd1\x82\xd0\xb0\xd0\xbb\xd0\xb8.", .{}) catch "Scholar down.",
    };
}

fn muVoice(agent: AgentState, snapshot: FacultySnapshot, delta: FacultyDelta, buf: []u8) []const u8 {
    _ = delta;
    return switch (agent.status) {
        .stub => std.fmt.bufPrint(buf, "\xd0\xa1\xd0\x9f\xd0\x98\xd0\xa2. {d} \xd0\xbf\xd0\xb0\xd1\x82\xd1\x82\xd0\xb5\xd1\x80\xd0\xbd\xd0\xbe\xd0\xb2 \xd0\xb2\xd1\x80\xd1\x83\xd1\x87\xd0\xbd\xd1\x83\xd1\x8e.", .{
            snapshot.mu_patterns,
        }) catch "MU спит.",
        .up => blk: {
            const hb = readMuHeartbeat();
            if (hb.wake > 0) {
                // v2: show test_ok status
                const test_s: []const u8 = if (hb.test_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c";
                const build_s: []const u8 = if (hb.build_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c";
                if (hb.fixes > 0) {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. \xd0\x92\xd1\x8b\xd0\xbb\xd0\xb5\xd1\x87\xd0\xb8\xd0\xbb {d}. Build{s} Test{s}", .{
                        hb.wake, hb.fixes, build_s, test_s,
                    }) catch "MU лечит.";
                } else if (hb.errors > 0) {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. {d} \xd0\xbe\xd1\x88\xd0\xb8\xd0\xb1\xd0\xbe\xd0\xba. \xd0\x9f\xd0\xb0\xd1\x82\xd1\x82\xd0\xb5\xd1\x80\xd0\xbd\xd1\x8b \xd0\xbd\xd0\xb5 \xd0\xbc\xd0\xb0\xd1\x82\xd1\x87\xd0\xb0\xd1\x82.", .{
                        hb.wake, hb.errors,
                    }) catch "MU лечит.";
                } else if (!hb.test_ok) {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. \xd0\xa2\xd0\xb5\xd1\x81\xd1\x82\xd1\x8b \xd0\xbd\xd0\xb5 \xd0\xbf\xd1\x80\xd0\xbe\xd1\x85\xd0\xbe\xd0\xb4\xd1\x8f\xd1\x82. Build{s}", .{
                        hb.wake, build_s,
                    }) catch "MU: тесты падают.";
                } else if (hb.age_s > 3600) {
                    const hours = @divTrunc(hb.age_s, 3600);
                    break :blk std.fmt.bufPrint(buf, "{d} \xd0\xbf\xd0\xb0\xd1\x82\xd1\x82\xd0\xb5\xd1\x80\xd0\xbd\xd0\xbe\xd0\xb2. \xd0\xa1\xd0\xbf\xd0\xb0\xd0\xbb {d}\xd1\x87. Build{s} Test{s}", .{
                        snapshot.mu_patterns, hours, build_s, test_s,
                    }) catch "MU лечит.";
                } else {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. \xd0\xa7\xd0\xb8\xd1\x81\xd1\x82\xd0\xbe. Build{s} Test{s}", .{
                        hb.wake, build_s, test_s,
                    }) catch "MU: чисто.";
                }
            }
            break :blk std.fmt.bufPrint(buf, "{d} \xd0\xbf\xd0\xb0\xd1\x82\xd1\x82\xd0\xb5\xd1\x80\xd0\xbd\xd0\xbe\xd0\xb2. \xd0\x9b\xd0\xb5\xd1\x87\xd1\x83 \xd0\xbf\xd0\xb0\xd0\xb9\xd0\xbf\xd0\xbb\xd0\xb0\xd0\xb9\xd0\xbd.", .{
                snapshot.mu_patterns,
            }) catch "MU лечит.";
        },
        .tbd => std.fmt.bufPrint(buf, "\xd0\x92 \xd0\x9f\xd0\xa0\xd0\x9e\xd0\x95\xd0\x9a\xd0\xa2\xd0\x95. \xd0\x9e\xd1\x88\xd0\xb8\xd0\xb1\xd0\xba\xd0\xb8 \xd0\xba\xd0\xbe\xd0\xbf\xd1\x8f\xd1\x82\xd1\x81\xd1\x8f.", .{}) catch "MU TBD.",
        .down => std.fmt.bufPrint(buf, "\xd0\xa3\xd0\xbf\xd0\xb0\xd0\xbb. \xd0\x9e\xd1\x88\xd0\xb8\xd0\xb1\xd0\xba\xd0\xb8 \xd0\xbd\xd0\xb5 \xd0\xbb\xd0\xbe\xd0\xb2\xd1\x8f\xd1\x82\xd1\x81\xd1\x8f.", .{}) catch "MU down.",
    };
}

fn oracleVoice(snapshot: FacultySnapshot, delta: FacultyDelta, buf: []u8) []const u8 {
    if (delta.has_prev) {
        if (delta.compile_rate_delta > 0) {
            return std.fmt.bufPrint(buf, "V={d:.2}. \xd0\xa0\xd0\xb0\xd1\x81\xd1\x82\xd1\x91\xd1\x82 (+{d}pp).", .{
                snapshot.v_number, delta.compile_rate_delta,
            }) catch "Oracle: рост.";
        } else if (delta.compile_rate_delta < 0) {
            return std.fmt.bufPrint(buf, "V={d:.2}. \xd0\x9f\xd0\xb0\xd0\xb4\xd0\xb0\xd0\xb5\xd1\x82 ({d}pp).", .{
                snapshot.v_number, delta.compile_rate_delta,
            }) catch "Oracle: падение.";
        } else if (delta.compile_frozen) {
            return std.fmt.bufPrint(buf, "V={d:.2}. \xd0\x97\xd0\xb0\xd0\xbc\xd1\x91\xd1\x80\xd0\xb7.", .{
                snapshot.v_number,
            }) catch "Oracle: заморозка.";
        }
    }
    // Default: zone-based
    if (snapshot.v_number > 1.5) {
        return std.fmt.bufPrint(buf, "V={d:.2}. \xCF\x86-\xd0\xb3\xd0\xb0\xd1\x80\xd0\xbc\xd0\xbe\xd0\xbd\xd0\xb8\xd1\x8f \xE2\x9C\xA8", .{
            snapshot.v_number,
        }) catch "Oracle: золото.";
    } else if (snapshot.v_number >= 1.0) {
        return std.fmt.bufPrint(buf, "V={d:.2}. \xCF\x86\xE2\x81\xBB\xE2\x81\xB0\xC2\xB7\xC2\xB3 \xd0\xb7\xd0\xbe\xd0\xbd\xd0\xb0. \xd0\xa1\xd1\x82\xd0\xb0\xd0\xb1\xd0\xb8\xd0\xbb\xd1\x8c\xd0\xbd\xd0\xbe.", .{
            snapshot.v_number,
        }) catch "Oracle: стабильно.";
    } else {
        return std.fmt.bufPrint(buf, "V={d:.2}. \xd0\xa1\xd0\xbf\xd0\xb8\xd1\x80\xd0\xb0\xd0\xbb\xd1\x8c \xd1\x82\xd0\xb5\xd1\x80\xd1\x8f\xd0\xb5\xd1\x82 \xd1\x84\xd0\xbe\xd1\x80\xd0\xbc\xd1\x83.", .{
            snapshot.v_number,
        }) catch "Oracle: дрифт.";
    }
}

fn swarmVoice(agent: AgentState, buf: []u8) []const u8 {
    return switch (agent.status) {
        .tbd => std.fmt.bufPrint(buf, "В ЗАРОДЫШЕ. Потенциал: 5\xC3\x97 быстрее.", .{}) catch "Swarm TBD.",
        .up => if (agent.last_action.len > 0)
            std.fmt.bufPrint(buf, "Маршрутизирую: {s}.", .{agent.last_action}) catch "Swarm работает."
        else
            std.fmt.bufPrint(buf, "Маршрутизирую задачи.", .{}) catch "Swarm работает.",
        .stub => std.fmt.bufPrint(buf, "Заглушка. Один агент за всех.", .{}) catch "Swarm stub.",
        .down => std.fmt.bufPrint(buf, "Упал. Задачи не распределяются.", .{}) catch "Swarm down.",
    };
}

fn linterVoice(agent: AgentState, snapshot: FacultySnapshot, delta: FacultyDelta, buf: []u8) []const u8 {
    _ = agent;
    if (snapshot.compile_total > 0) {
        const fail = snapshot.compile_total - snapshot.compile_pass;
        if (fail == 0) {
            // v2: also check MU test status
            const hb = readMuHeartbeat();
            if (hb.wake > 0 and hb.test_ok) {
                return std.fmt.bufPrint(buf, "{d}/{d}. \xd0\xa7\xd0\xb8\xd1\x81\xd1\x82\xd0\xbe. \xd0\xa2\xd0\xb5\xd1\x81\xd1\x82\xd1\x8b \xe2\x9c\x85", .{
                    snapshot.compile_pass, snapshot.compile_total,
                }) catch "Linter: чисто.";
            } else if (hb.wake > 0 and !hb.test_ok) {
                return std.fmt.bufPrint(buf, "{d}/{d}. Specs OK, \xd1\x82\xd0\xb5\xd1\x81\xd1\x82\xd1\x8b \xe2\x9d\x8c", .{
                    snapshot.compile_pass, snapshot.compile_total,
                }) catch "Linter: тесты!";
            }
            return std.fmt.bufPrint(buf, "{d}/{d} \xd0\xbf\xd1\x80\xd0\xbe\xd1\x85\xd0\xbe\xd0\xb4\xd1\x8f\xd1\x82. \xd0\xa7\xd0\xb8\xd1\x81\xd1\x82\xd0\xbe.", .{
                snapshot.compile_pass, snapshot.compile_total,
            }) catch "Linter: чисто.";
        }
        if (delta.has_prev) {
            if (delta.compile_frozen and fail > 0) {
                const hours = @divTrunc(delta.seconds_ago, 3600);
                return std.fmt.bufPrint(buf, "{d}/{d}. \xd0\x9f\xd0\xbb\xd0\xb0\xd1\x82\xd0\xbe \xe2\x80\x94 \xd1\x82\xd0\xb5 \xd0\xb6\xd0\xb5 {d} \xd1\x81\xd0\xb1\xd0\xbe\xd0\xb5\xd0\xb2 \xd1\x83\xd0\xb6\xd0\xb5 {d}\xd1\x87.", .{
                    snapshot.compile_pass, snapshot.compile_total, fail, hours,
                }) catch "Linter: плато.";
            } else if (delta.compile_rate_delta > 0) {
                return std.fmt.bufPrint(buf, "{d}/{d} (+{d}pp). {d} \xd0\xbe\xd1\x81\xd1\x82\xd0\xb0\xd0\xbb\xd0\xbe\xd1\x81\xd1\x8c.", .{
                    snapshot.compile_pass, snapshot.compile_total, delta.compile_rate_delta, fail,
                }) catch "Linter: прогресс.";
            } else if (delta.compile_rate_delta < 0) {
                return std.fmt.bufPrint(buf, "{d}/{d} ({d}pp). \xd0\xa0\xd0\xb5\xd0\xb3\xd1\x80\xd0\xb5\xd1\x81\xd1\x81\xd0\xb8\xd1\x8f! {d} \xd1\x81\xd0\xb1\xd0\xbe\xd0\xb5\xd0\xb2.", .{
                    snapshot.compile_pass, snapshot.compile_total, delta.compile_rate_delta, fail,
                }) catch "Linter: регрессия.";
            }
        }
        return std.fmt.bufPrint(buf, "{d}/{d} \xd0\xbf\xd1\x80\xd0\xbe\xd1\x85\xd0\xbe\xd0\xb4\xd1\x8f\xd1\x82. {d} \xd1\x81\xd0\xb1\xd0\xbe\xd0\xb5\xd0\xb2.", .{
            snapshot.compile_pass, snapshot.compile_total, fail,
        }) catch "Linter: есть сбои.";
    } else {
        return std.fmt.bufPrint(buf, "\xd0\xa1\xd0\xbb\xd0\xb5\xd0\xbf\xd0\xbe\xd0\xb9. \xd0\x9d\xd0\xb5\xd1\x82 \xd0\xb4\xd0\xb0\xd0\xbd\xd0\xbd\xd1\x8b\xd1\x85 \xd0\xb0\xd1\x83\xd0\xb4\xd0\xb8\xd1\x82\xd0\xb0.", .{}) catch "Linter: слепой.";
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEARTBEAT READERS
// ═══════════════════════════════════════════════════════════════════════════════

const ScholarHeartbeat = struct {
    wake: u32 = 0,
    fails_found: u32 = 0,
    researched: u32 = 0,
    fed_mu: u32 = 0,
};

fn readScholarHeartbeat() ScholarHeartbeat {
    const file = std.fs.cwd().openFile(".trinity/scholar/heartbeat.json", .{}) catch return .{};
    defer file.close();
    var buf: [512]u8 = undefined;
    const n = file.readAll(&buf) catch return .{};
    const data = buf[0..n];

    var hb: ScholarHeartbeat = .{};
    hb.wake = parseJsonU32(data, "\"wake\":");
    hb.fails_found = parseJsonU32(data, "\"fails_found\":");
    hb.researched = parseJsonU32(data, "\"researched\":");
    hb.fed_mu = parseJsonU32(data, "\"fed_mu\":");
    return hb;
}

// ═══════════════════════════════════════════════════════════════════════════════

fn readMuHeartbeat() MuHeartbeat {
    const file = std.fs.cwd().openFile(".trinity/mu/heartbeat.json", .{}) catch return .{};
    defer file.close();
    var buf: [512]u8 = undefined;
    const n = file.readAll(&buf) catch return .{};
    const data = buf[0..n];

    var hb: MuHeartbeat = .{};
    hb.wake = parseJsonU32(data, "\"wake\":");
    hb.fixes = parseJsonU32(data, "\"fixes_applied\":");
    hb.errors = parseJsonU32(data, "\"errors_scanned\":");
    hb.test_ok = parseJsonBool(data, "\"test_ok\":");
    hb.build_ok = parseJsonBool(data, "\"build_ok\":");
    const ts = parseJsonI64(data, "\"timestamp\":");
    if (ts > 0) {
        hb.age_s = std.time.timestamp() - ts;
        if (hb.age_s < 0) hb.age_s = 0;
    }
    return hb;
}

fn parseJsonU32(data: []const u8, key: []const u8) u32 {
    const pos = std.mem.indexOf(u8, data, key) orelse return 0;
    const after = data[pos + key.len ..];
    // Skip whitespace
    var i: usize = 0;
    while (i < after.len and (after[i] == ' ' or after[i] == ':')) : (i += 1) {}
    // Parse digits
    var end = i;
    while (end < after.len and after[end] >= '0' and after[end] <= '9') : (end += 1) {}
    if (end == i) return 0;
    return std.fmt.parseInt(u32, after[i..end], 10) catch 0;
}

fn parseJsonI64(data: []const u8, key: []const u8) i64 {
    const pos = std.mem.indexOf(u8, data, key) orelse return 0;
    const after = data[pos + key.len ..];
    var i: usize = 0;
    while (i < after.len and (after[i] == ' ' or after[i] == ':')) : (i += 1) {}
    var end = i;
    while (end < after.len and after[end] >= '0' and after[end] <= '9') : (end += 1) {}
    if (end == i) return 0;
    return std.fmt.parseInt(i64, after[i..end], 10) catch 0;
}

fn parseJsonBool(data: []const u8, key: []const u8) bool {
    const pos = std.mem.indexOf(u8, data, key) orelse return false;
    const after = data[pos + key.len ..];
    var i: usize = 0;
    while (i < after.len and (after[i] == ' ' or after[i] == ':')) : (i += 1) {}
    if (i + 4 <= after.len and std.mem.eql(u8, after[i..][0..4], "true")) return true;
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

fn testSnapshot() FacultySnapshot {
    return .{
        .agents = .{
            .{ .agent = .ralph, .status = .up, .last_action = "build" },
            .{ .agent = .scholar, .status = .tbd, .last_action = "" },
            .{ .agent = .mu, .status = .stub, .last_action = "" },
            .{ .agent = .oracle, .status = .up, .last_action = "watch" },
            .{ .agent = .swarm, .status = .tbd, .last_action = "" },
            .{ .agent = .linter, .status = .up, .last_action = "scan" },
        },
        .build_ok = true,
        .binaries = 5,
        .compile_pass = 40,
        .compile_total = 47,
        .compile_rate = 85,
        .v_number = 1.17,
        .v_zone = .stable,
        .git_branch = "main",
        .dirty_files = 5,
        .open_issues = 10,
        .mu_patterns = 12,
        .cycle = .working,
    };
}

test "ralph voice UP default" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[0], snap, .{}, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "40/47") != null);
}

test "ralph voice UP with positive delta" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const delta = FacultyDelta{ .has_prev = true, .compile_rate_delta = 5 };
    const voice = generateVoice(snap.agents[0], snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "+5pp") != null);
}

test "ralph voice UP with dirty files" {
    var buf: [256]u8 = undefined;
    var snap = testSnapshot();
    snap.dirty_files = 20;
    const delta = FacultyDelta{ .has_prev = true, .compile_rate_delta = 0 };
    const voice = generateVoice(snap.agents[0], snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "20 dirty") != null);
}

test "scholar voice TBD" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[1], snap, .{}, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "\xd0\x9d\xd0\x95 \xd0\x9d\xd0\x90\xd0\x9d\xd0\xaf\xd0\xa2") != null);
}

test "mu voice STUB" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[2], snap, .{}, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "\xd0\xa1\xd0\x9f\xd0\x98\xd0\xa2") != null);
    try std.testing.expect(std.mem.indexOf(u8, voice, "12") != null);
}

test "oracle voice stable zone" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[3], snap, .{}, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "1.17") != null);
}

test "oracle voice gold zone" {
    var buf: [256]u8 = undefined;
    var snap = testSnapshot();
    snap.v_number = 1.62;
    snap.v_zone = .gold;
    const voice = oracleVoice(snap, .{}, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "1.62") != null);
}

test "oracle voice with delta rising" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const delta = FacultyDelta{ .has_prev = true, .compile_rate_delta = 3 };
    const voice = oracleVoice(snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "+3pp") != null);
}

test "swarm voice TBD" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[4], snap, .{}, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "\xd0\x97\xd0\x90\xd0\xa0\xd0\x9e\xd0\x94\xd0\xab\xd0\xa8\xd0\x95") != null);
}

test "linter voice with failures" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[5], snap, .{}, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "40/47") != null);
    try std.testing.expect(std.mem.indexOf(u8, voice, "7") != null);
}

test "linter voice clean" {
    var buf: [256]u8 = undefined;
    var snap = testSnapshot();
    snap.compile_pass = 47;
    const agent_state = types.AgentState{ .agent = .linter, .status = .up, .last_action = "" };
    const voice = generateVoice(agent_state, snap, .{}, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "\xd0\xa7\xd0\xb8\xd1\x81\xd1\x82\xd0\xbe") != null);
}

test "linter voice frozen plateau" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const delta = FacultyDelta{ .has_prev = true, .compile_frozen = true, .seconds_ago = 7200 };
    const agent_state = types.AgentState{ .agent = .linter, .status = .up, .last_action = "" };
    const voice = generateVoice(agent_state, snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "40/47") != null);
}

test "readMuHeartbeat returns defaults on missing file" {
    // Just verify it doesn't crash — file may or may not exist
    const hb = readMuHeartbeat();
    try std.testing.expect(hb.age_s >= 0);
}

test "parseJsonU32 extracts number" {
    const data = "{\"wake\":42,\"fixes_applied\":3}";
    try std.testing.expectEqual(@as(u32, 42), parseJsonU32(data, "\"wake\":"));
    try std.testing.expectEqual(@as(u32, 3), parseJsonU32(data, "\"fixes_applied\":"));
    try std.testing.expectEqual(@as(u32, 0), parseJsonU32(data, "\"missing\":"));
}
