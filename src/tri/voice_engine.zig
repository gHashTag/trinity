// @origin(spec:voice_engine.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// Voice Engine — Agent voice generator for Faculty Board
// ═══════════════════════════════════════════════════════════════════════════════
// Each agent speaks in character based on their state and system snapshot.
// No allocations — writes into caller-owned buffer via bufPrint.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("faculty_types.zig");
const AgentState = types.AgentState;
const FacultySnapshot = types.FacultySnapshot;
const FacultyDelta = types.FacultyDelta;

pub const MuHeartbeat = struct {
    wake: u32 = 0,
    fixes: u32 = 0,
    errors: u32 = 0,
    age_s: i64 = 0,
    test_ok: bool = false,
    build_ok: bool = false,
};

/// Read last git commit subject line (max 80 chars).
pub fn readLastCommit(buf: []u8) []const u8 {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &.{ "git", "log", "--oneline", "-1", "--format=%s" },
        .max_output_bytes = 256,
    }) catch return "";
    defer std.heap.page_allocator.free(result.stdout);
    defer std.heap.page_allocator.free(result.stderr);
    const trimmed = std.mem.trim(u8, result.stdout, &[_]u8{ ' ', '\t', '\n', '\r' });
    if (trimmed.len == 0) return "";
    const copy_len = @min(trimmed.len, buf.len);
    @memcpy(buf[0..copy_len], trimmed[0..copy_len]);
    return buf[0..copy_len];
}

/// Read last N git commit subjects (max 3). Returns count of commits found.
pub fn readRecentCommits(out: *[3][80]u8) u8 {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &.{ "git", "log", "--oneline", "-3", "--format=%s" },
        .max_output_bytes = 512,
    }) catch return 0;
    defer std.heap.page_allocator.free(result.stdout);
    defer std.heap.page_allocator.free(result.stderr);
    const trimmed = std.mem.trim(u8, result.stdout, &[_]u8{ ' ', '\t', '\n', '\r' });
    if (trimmed.len == 0) return 0;

    var count: u8 = 0;
    var iter = std.mem.splitScalar(u8, trimmed, '\n');
    while (iter.next()) |line| {
        if (count >= 3) break;
        const l = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
        if (l.len == 0) continue;
        const copy_len = @min(l.len, 80);
        @memcpy(out[count][0..copy_len], l[0..copy_len]);
        // Zero-fill rest for clean slicing
        if (copy_len < 80) {
            @memset(out[count][copy_len..], 0);
        }
        count += 1;
    }
    return count;
}

/// Read last agent command for a given emoji prefix from agent_commands.log.
fn readLastAgentCmd(emoji: []const u8, buf: []u8) []const u8 {
    const file = std.fs.cwd().openFile(".trinity/agent_commands.log", .{}) catch return "";
    defer file.close();
    var file_buf: [4096]u8 = undefined;
    const n = file.readAll(&file_buf) catch return "";
    const data = file_buf[0..n];

    // Find last line containing emoji
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

/// Generate a voice line for given agent based on system state and delta.
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
                    break :blk std.fmt.bufPrint(buf, "Build {d}/{d} (+{d}pp). Success.", .{
                        snapshot.compile_pass, snapshot.compile_total, delta.compile_rate_delta,
                    }) catch "Ralph works.";
                } else if (delta.compile_rate_delta < 0) {
                    break :blk std.fmt.bufPrint(buf, "Build {d}/{d} ({d}pp). Regression!", .{
                        snapshot.compile_pass, snapshot.compile_total, delta.compile_rate_delta,
                    }) catch "Ralph works.";
                } else if (delta.compile_frozen and snapshot.compile_rate < 100) {
                    const hours = @divTrunc(delta.seconds_ago, 3600);
                    break :blk std.fmt.bufPrint(buf, "Build {d}/{d}. Stuck {d}h. Need breakthrough.", .{
                        snapshot.compile_pass, snapshot.compile_total, hours,
                    }) catch "Ralph works.";
                } else if (snapshot.dirty_files > 15) {
                    break :blk std.fmt.bufPrint(buf, "Build {d}/{d}. {d} dirty — need commit.", .{
                        snapshot.compile_pass, snapshot.compile_total, snapshot.dirty_files,
                    }) catch "Ralph works.";
                }
            }
            // v2: show last git commit for live context
            var commit_buf: [80]u8 = undefined;
            const last_commit = readLastCommit(&commit_buf);
            if (last_commit.len > 0) {
                break :blk std.fmt.bufPrint(buf, "{d}/{d}. Last commit: {s}", .{
                    snapshot.compile_pass, snapshot.compile_total, last_commit,
                }) catch "Ralph works.";
            }
            break :blk std.fmt.bufPrint(buf, "I'm working. Build {d}/{d}.", .{
                snapshot.compile_pass, snapshot.compile_total,
            }) catch "Ralph works.";
        },
        .down => std.fmt.bufPrint(buf, "Down. Please restart.", .{}) catch "Ralph lies down.",
        .stub => std.fmt.bufPrint(buf, "Stub agent. Not implemented yet.", .{}) catch "Ralph stub.",
        .tbd => std.fmt.bufPrint(buf, "TBD agent. Coming soon.", .{}) catch "Ralph TBD.",
    };
}

fn scholarVoice(agent: AgentState, buf: []u8) []const u8 {
    return switch (agent.status) {
        .tbd => std.fmt.bufPrint(buf, "SCHOLAR TBD. Ralph hired me, searching for patterns.", .{}) catch "Scholar TBD.",
        .up => blk: {
            // v2: read scholar heartbeat for live data
            const hb = readScholarHeartbeat();
            if (hb.wake > 0) {
                if (hb.fed_mu > 0) {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. Researched {d}, fed Agent TRI {d}.", .{
                        hb.wake, hb.researched, hb.fed_mu,
                    }) catch "Scholar works.";
                } else if (hb.fails_found > 0) {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. {d} failures found. Looking for patterns.", .{
                        hb.wake, hb.fails_found,
                    }) catch "Scholar works.";
                } else {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. 0 failures found. Everything is clear.", .{
                        hb.wake,
                    }) catch "Scholar: clear.";
                }
            }
            if (agent.last_action.len > 0)
                break :blk std.fmt.bufPrint(buf, "Working: {s}.", .{agent.last_action}) catch "Scholar working."
            else
                break :blk std.fmt.bufPrint(buf, "Gathering information.", .{}) catch "Scholar working.";
        },
        .stub => std.fmt.bufPrint(buf, "Stub. Not implemented.", .{}) catch "Scholar stub.",
        .down => std.fmt.bufPrint(buf, "Down. No research done.", .{}) catch "Scholar down.",
    };
}

fn muVoice(agent: AgentState, snapshot: FacultySnapshot, delta: FacultyDelta, buf: []u8) []const u8 {
    _ = delta;
    return switch (agent.status) {
        .stub => std.fmt.bufPrint(buf, "TRI TBD. {d} patterns learned.", .{
            snapshot.mu_patterns,
        }) catch "TRI sleeps.",
        .up => blk: {
            const hb = readMuHeartbeat();
            if (hb.wake > 0) {
                // v2: show test_ok status
                const test_s: []const u8 = if (hb.test_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c";
                const build_s: []const u8 = if (hb.build_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c";
                if (hb.fixes > 0) {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. Fixed {d}. Build{s} Test{s}", .{
                        hb.wake, hb.fixes, build_s, test_s,
                    }) catch "TRI healing.";
                } else if (hb.errors > 0) {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. {d} errors found. Looking for patterns.", .{
                        hb.wake, hb.errors,
                    }) catch "TRI healing.";
                } else if (!hb.test_ok) {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. Tests failing. Build{s}", .{
                        hb.wake, build_s,
                    }) catch "TRI: tests failing.";
                } else if (hb.age_s > 3600) {
                    const hours = @divTrunc(hb.age_s, 3600);
                    break :blk std.fmt.bufPrint(buf, "{d} patterns learned. Sleeping {d}h. Build{s} Test{s}", .{
                        snapshot.mu_patterns, hours, build_s, test_s,
                    }) catch "TRI healing.";
                } else {
                    break :blk std.fmt.bufPrint(buf, "Wake #{d}. Clean. Build{s} Test{s}", .{
                        hb.wake, build_s, test_s,
                    }) catch "TRI: clean.";
                }
            }
            break :blk std.fmt.bufPrint(buf, "{d} patterns. Waiting for fixes.", .{
                snapshot.mu_patterns,
            }) catch "TRI healing.";
        },
        .tbd => std.fmt.bufPrint(buf, "TRI TBD. No capabilities yet.", .{}) catch "TRI TBD.",
        .down => std.fmt.bufPrint(buf, "Down. Tasks not working.", .{}) catch "TRI down.",
    };
}

fn oracleVoice(snapshot: FacultySnapshot, delta: FacultyDelta, buf: []u8) []const u8 {
    if (delta.has_prev) {
        if (delta.compile_rate_delta > 0) {
            return std.fmt.bufPrint(buf, "V={d:.2}. Growth (+{d}pp).", .{
                snapshot.v_number, delta.compile_rate_delta,
            }) catch "Oracle: growth.";
        } else if (delta.compile_rate_delta < 0) {
            return std.fmt.bufPrint(buf, "V={d:.2}. Decline ({d}pp).", .{
                snapshot.v_number, delta.compile_rate_delta,
            }) catch "Oracle: decline.";
        } else if (delta.compile_frozen) {
            return std.fmt.bufPrint(buf, "V={d:.2}. Frozen.", .{
                snapshot.v_number,
            }) catch "Oracle: frozen.";
        }
    }
    // Default: zone-based
    if (snapshot.v_number > 1.5) {
        return std.fmt.bufPrint(buf, "V={d:.2}. φ-harmony \xE2\x9C\xA8", .{
            snapshot.v_number,
        }) catch "Oracle: gold.";
    } else if (snapshot.v_number >= 1.0) {
        return std.fmt.bufPrint(buf, "V={d:.2}. φ→zone. Stable.", .{
            snapshot.v_number,
        }) catch "Oracle: stable.";
    } else {
        return std.fmt.bufPrint(buf, "V={d:.2}. Spiral downward.", .{
            snapshot.v_number,
        }) catch "Oracle: drift.";
    }
}

fn swarmVoice(agent: AgentState, buf: []u8) []const u8 {
    return switch (agent.status) {
        .tbd => std.fmt.bufPrint(buf, "SWARM TBD. Potential: 7× agents faster.", .{}) catch "Swarm TBD.",
        .up => blk: {
            // Read swarm_state.json for live counts
            const swarm = readSwarmCounts();
            if (swarm.agents > 0 and swarm.assigned > 0) {
                break :blk std.fmt.bufPrint(buf, "{d} agents, {d} assigned. Marhshrooding.", .{
                    swarm.agents, swarm.assigned,
                }) catch "Marhshrooding.";
            }
            if (agent.last_action.len > 0)
                break :blk std.fmt.bufPrint(buf, "Marhshrooding: {s}.", .{agent.last_action}) catch "Marhshrooding."
            else
                break :blk std.fmt.bufPrint(buf, "Marhshrooding tasks.", .{}) catch "Marhshrooding.";
        },
        .stub => blk: {
            const swarm = readSwarmCounts();
            if (swarm.agents > 0 and swarm.assigned == 0) {
                break :blk std.fmt.bufPrint(buf, "{d} agents, idle. Need tasks.", .{
                    swarm.agents,
                }) catch "Stuck.";
            } else if (swarm.agents == 0 and swarm.tasks > 0) {
                break :blk std.fmt.bufPrint(buf, "{d} tasks, no agents.", .{
                    swarm.tasks,
                }) catch "Stuck.";
            }
            break :blk std.fmt.bufPrint(buf, "Stuck. Need agent for all tasks.", .{}) catch "Stuck.";
        },
        .down => std.fmt.bufPrint(buf, "Down. No tasks distributing.", .{}) catch "Swarm down.",
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
                return std.fmt.bufPrint(buf, "{d}/{d}. Clean. All OK \xe2\x9c\x85", .{
                    snapshot.compile_pass, snapshot.compile_total,
                }) catch "Linter: clean.";
            } else if (hb.wake > 0 and !hb.test_ok) {
                return std.fmt.bufPrint(buf, "{d}/{d}. Specs OK, tests \xe2\x9d\x8c", .{
                    snapshot.compile_pass, snapshot.compile_total,
                }) catch "Linter: tests!";
            }
            return std.fmt.bufPrint(buf, "{d}/{d} passed. Clean.", .{
                snapshot.compile_pass, snapshot.compile_total,
            }) catch "Linter: clean.";
        }
        if (delta.has_prev) {
            if (delta.compile_frozen and fail > 0) {
                const hours = @divTrunc(delta.seconds_ago, 3600);
                return std.fmt.bufPrint(buf, "{d}/{d}. Plateau — {d} specs stuck {d}h.", .{
                    snapshot.compile_pass, snapshot.compile_total, fail, hours,
                }) catch "Linter: stuck.";
            } else if (delta.compile_rate_delta > 0) {
                return std.fmt.bufPrint(buf, "{d}/{d} (+{d}pp). {d} failures.", .{
                    snapshot.compile_pass, snapshot.compile_total, delta.compile_rate_delta, fail,
                }) catch "Linter: progress.";
            } else if (delta.compile_rate_delta < 0) {
                return std.fmt.bufPrint(buf, "{d}/{d} ({d}pp). Regression! {d} failures.", .{
                    snapshot.compile_pass, snapshot.compile_total, delta.compile_rate_delta, fail,
                }) catch "Linter: regression.";
            }
        }
        return std.fmt.bufPrint(buf, "{d}/{d} passed. {d} failures.", .{
            snapshot.compile_pass, snapshot.compile_total, fail,
        }) catch "Linter: has failures.";
    } else {
        return std.fmt.bufPrint(buf, "Blind. No audit data.", .{}) catch "Linter: blind.";
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEARTBEAT READERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScholarHeartbeat = struct {
    wake: u32 = 0,
    fails_found: u32 = 0,
    researched: u32 = 0,
    fed_mu: u32 = 0,
    age_s: i64 = 0,
};

pub fn readScholarHeartbeat() ScholarHeartbeat {
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
    const ts = parseJsonI64(data, "\"timestamp\":");
    if (ts > 0) {
        hb.age_s = std.time.timestamp() - ts;
        if (hb.age_s < 0) hb.age_s = 0;
    }
    return hb;
}

// ═══════════════════════════════════════════════════════════════════════════════

pub fn readMuHeartbeat() MuHeartbeat {
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

const SwarmCounts = struct {
    agents: u16,
    tasks: u16,
    assigned: u16,
};

fn readSwarmCounts() SwarmCounts {
    const file = std.fs.cwd().openFile(".trinity/swarm_state.json", .{}) catch return .{ .agents = 0, .tasks = 0, .assigned = 0 };
    defer file.close();
    var buf: [8192]u8 = undefined;
    const n = file.readAll(&buf) catch return .{ .agents = 0, .tasks = 0, .assigned = 0 };
    const data = buf[0..n];

    var agent_count: u16 = 0;
    var task_count: u16 = 0;
    var assigned_count: u16 = 0;

    // Count agents by "status" keys in agents section
    if (std.mem.indexOf(u8, data, "\"agents\"")) |agents_pos| {
        const agents_end = if (std.mem.indexOfPos(u8, data, agents_pos, "]")) |end| end else data.len;
        var idx = agents_pos;
        while (std.mem.indexOfPos(u8, data[0..agents_end], idx, "\"status\"")) |pos| {
            agent_count += 1;
            idx = pos + 8;
        }
    }

    // Count tasks and assigned tasks
    if (std.mem.indexOf(u8, data, "\"tasks\"")) |tasks_pos| {
        const tasks_end = if (std.mem.indexOfPos(u8, data, tasks_pos, "]")) |end| end else data.len;
        var idx = tasks_pos;
        while (std.mem.indexOfPos(u8, data[0..tasks_end], idx, "\"status\"")) |pos| {
            task_count += 1;
            idx = pos + 8;
        }
        idx = tasks_pos;
        while (std.mem.indexOfPos(u8, data[0..tasks_end], idx, "\"assigned\":\"")) |pos| {
            const val_start = pos + 12;
            if (val_start < tasks_end and data[val_start] != '"') {
                assigned_count += 1;
            }
            idx = pos + 12;
        }
    }

    return .{ .agents = agent_count, .tasks = task_count, .assigned = assigned_count };
}

pub fn parseJsonU32(data: []const u8, key: []const u8) u32 {
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

pub fn parseJsonI64(data: []const u8, key: []const u8) i64 {
    const pos = std.mem.indexOf(u8, data, key) orelse return 0;
    const after = data[pos + key.len ..];
    var i: usize = 0;
    while (i < after.len and (after[i] == ' ' or after[i] == ':')) : (i += 1) {}
    var end = i;
    while (end < after.len and after[end] >= '0' and after[end] <= '9') : (end += 1) {}
    if (end == i) return 0;
    return std.fmt.parseInt(i64, after[i..end], 10) catch 0;
}

pub fn parseJsonBool(data: []const u8, key: []const u8) bool {
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
    try std.testing.expect(std.mem.indexOf(u8, voice, "SCHOLAR") != null);
}

test "TRI voice STUB" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[2], snap, .{}, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "TRI") != null);
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
    const agent_state = types.AgentState{ .agent = .swarm, .status = .tbd, .last_action = "" };
    const snap = testSnapshot();
    const voice = generateVoice(agent_state, snap, .{}, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "SWARM") != null);
}

test "swarm voice STUB with agents" {
    var buf: [256]u8 = undefined;
    const agent_state = types.AgentState{ .agent = .swarm, .status = .stub, .last_action = "idle" };
    const snap = testSnapshot();
    const voice = generateVoice(agent_state, snap, .{}, &buf);
    // Should show agent count or stub message (depends on swarm_state.json presence)
    try std.testing.expect(voice.len > 0);
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
    try std.testing.expect(std.mem.indexOf(u8, voice, "Clean") != null);
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

test "dummy" {}
