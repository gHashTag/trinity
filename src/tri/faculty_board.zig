// ═══════════════════════════════════════════════════════════════════════════════
// Faculty Board — Orchestrator for Trinity A2A Dashboard
// ═══════════════════════════════════════════════════════════════════════════════
// Wires 4 engines: voice, analysis, three_paths, phi_poetry.
// Single entry point: `tri faculty`
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("faculty_types.zig");
const voice_engine = @import("voice_engine.zig");
const analysis_engine = @import("analysis_engine.zig");
const three_paths = @import("three_paths.zig");
const phi_poetry = @import("phi_poetry.zig");
const colors = @import("tri_colors.zig");
const Sacred = @import("train_types.zig").Sacred;
const FacultySnapshot = types.FacultySnapshot;
const FacultyDelta = types.FacultyDelta;
const AgentState = types.AgentState;
const Path = three_paths.Path;

const PREV_PATH = ".trinity/faculty_prev.dat";
const TG_HASH_PATH = ".trinity/faculty_tg_hash.dat";
const AGENT_CMD_LOG = ".trinity/agent_commands.log";
const REGEN_REPORT = "specs/REGENERATION_REPORT.md";
const MU_LEARNING_DB = ".trinity/mu/learning_db.json";

// ═══════════════════════════════════════════════════════════════════════════════
// DATA COLLECTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Collect a snapshot of the current system state.
pub fn collectSnapshot(allocator: Allocator) !FacultySnapshot {
    var snap: FacultySnapshot = .{
        .agents = undefined,
        .build_ok = true,
        .binaries = 0,
        .compile_pass = 0,
        .compile_total = 0,
        .compile_rate = 0,
        .v_number = 0,
        .v_zone = .drift,
        .git_branch = "main",
        .dirty_files = 0,
        .open_issues = 0,
        .mu_patterns = 0,
        .cycle = .quiet,
    };

    // Initialize agents with defaults
    const agent_defaults = [_]struct { agent: types.Agent, default_status: types.AgentStatus }{
        .{ .agent = .ralph, .default_status = .up },
        .{ .agent = .scholar, .default_status = .tbd },
        .{ .agent = .mu, .default_status = .stub },
        .{ .agent = .oracle, .default_status = .up },
        .{ .agent = .swarm, .default_status = .tbd },
        .{ .agent = .linter, .default_status = .up },
    };
    for (agent_defaults, 0..) |d, i| {
        snap.agents[i] = .{
            .agent = d.agent,
            .status = d.default_status,
            .last_action = "",
        };
    }

    // Count binaries in zig-out/bin/
    snap.binaries = countBinaries();

    // Parse REGENERATION_REPORT for compile stats
    const regen = parseRegenReport(allocator);
    snap.compile_pass = regen.pass;
    snap.compile_total = regen.total;
    snap.compile_rate = if (regen.total > 0)
        @intCast((@as(u32, regen.pass) * 100) / @as(u32, regen.total))
    else
        0;

    // Git branch + dirty files
    snap.git_branch = getGitBranch(allocator);
    snap.dirty_files = countDirtyFiles(allocator);

    // Open issues
    snap.open_issues = countOpenIssues(allocator);

    // MU patterns
    snap.mu_patterns = countMuPatterns(allocator);

    // Check if ralph-agent is running
    if (isProcessRunning(allocator, "ralph-agent")) {
        snap.agents[0].status = .up;
        snap.agents[0].last_action = "daemon";
    }

    // Check if scholar-agent is running
    if (isProcessRunning(allocator, "scholar-agent")) {
        snap.agents[1].status = .up;
        snap.agents[1].last_action = "research";
    }

    // Check if mu-agent is running
    if (isProcessRunning(allocator, "mu-agent")) {
        snap.agents[2].status = .up;
        snap.agents[2].last_action = "healing";
    }

    // Compute V-number: φ·(rate/100)²
    const rate_f: f64 = @as(f64, @floatFromInt(snap.compile_rate)) / 100.0;
    snap.v_number = Sacred.PHI * rate_f * rate_f;
    snap.v_zone = if (snap.v_number > 1.5) .gold else if (snap.v_number >= 1.0) .stable else .drift;

    // Determine cycle type
    if (!snap.build_ok or snap.compile_rate < 50) {
        snap.cycle = .emergency;
    } else if (snap.dirty_files > 10 or snap.open_issues > 15) {
        snap.cycle = .working;
    } else {
        snap.cycle = .quiet;
    }

    return snap;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDERING
// ═══════════════════════════════════════════════════════════════════════════════

/// Render compact Faculty Board — Social Dashboard format.
pub fn renderCompact(snapshot: FacultySnapshot, delta: FacultyDelta, writer: anytype) !void {
    const R = colors.RESET;
    const G = colors.GOLDEN;
    const GR = colors.GREEN;
    const CY = colors.CYAN;
    const GY = colors.GRAY;

    // ═══ HEADER: V + delta + compile% + faculty count ═══
    const active_count = snapshot.activeFaculty();
    const v_delta_str: []const u8 = if (delta.has_prev)
        (if (delta.compile_rate_delta > 0) "\xe2\x96\xb2" else if (delta.compile_rate_delta < 0) "\xe2\x96\xbc" else "\xe2\x94\x80")
    else
        "";
    try writer.print("\n{s}\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90 \xf0\x9f\x94\xba TRINITY \xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90{s}\n\n", .{ G, R });
    try writer.print("  V {s}{d:.3}{s} {s}   {d}% compile   {d}/6 faculty\n", .{
        snapshot.v_zone.color(), snapshot.v_number, R, v_delta_str, snapshot.compile_rate, active_count,
    });

    // ═══ V-BAR: Visual progress ═══
    const v_ratio: f64 = snapshot.v_number / Sacred.PHI;
    const bar_filled: u8 = @intFromFloat(@min(24.0, @max(0.0, v_ratio * 24.0)));
    try writer.print("  ", .{});
    var bar_i: u8 = 0;
    while (bar_i < 24) : (bar_i += 1) {
        if (bar_i < bar_filled) {
            try writer.print("{s}\xe2\x96\x88{s}", .{ GR, R });
        } else {
            try writer.print("{s}\xe2\x96\x91{s}", .{ GY, R });
        }
    }
    try writer.print("  {d:.2} \xe2\x94\x80\xe2\x94\x80\xe2\x94\x80 {d:.2} \xcf\x86\n", .{ snapshot.v_number, Sacred.PHI });

    // ═══ ЛЕНТА — last agent commands ═══
    try writer.print("\n  {s}\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80 \xd0\x9b\xd0\x95\xd0\x9d\xd0\xa2\xd0\x90 \xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80{s}\n\n", .{ G, R });
    var cmd_lines: [5][]const u8 = undefined;
    var cmd_log_buf: [1024]u8 = undefined;
    const cmd_count = lastNCommands(5, &cmd_lines, &cmd_log_buf);
    if (cmd_count > 0) {
        for (cmd_lines[0..cmd_count]) |line| {
            try writer.print("  {s}{s}{s}\n", .{ GY, line, R });
        }
    } else {
        try writer.print("  {s}(\xd0\xbf\xd1\x83\xd1\x81\xd1\x82\xd0\xbe){s}\n", .{ GY, R });
    }

    // ═══ ОНЛАЙН — agent statuses with time ═══
    try writer.print("\n  {s}\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80 \xd0\x9e\xd0\x9d\xd0\x9b\xd0\x90\xd0\x99\xd0\x9d \xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80{s}\n\n", .{ G, R });
    for (snapshot.agents) |a| {
        const status_icon: []const u8 = switch (a.status) {
            .up => "\xf0\x9f\x9f\xa2",
            .down => "\xf0\x9f\x94\xb4",
            .stub => "\xf0\x9f\x9f\xa1",
            .tbd => "\xe2\xac\x9c",
        };
        const status_label: []const u8 = switch (a.status) {
            .up => if (a.last_action.len > 0) a.last_action else "active",
            .down => "offline",
            .stub => "stub",
            .tbd => "\xd0\xbd\xd0\xb5 \xd0\xbd\xd0\xb0\xd0\xbd\xd1\x8f\xd1\x82",
        };
        // Voice line from voice_engine
        var voice_buf: [256]u8 = undefined;
        const voice = voice_engine.generateVoice(a, snapshot, delta, &voice_buf);
        try writer.print("  {s} {s:<8} {s} {s:<10} {s}{s}{s}\n", .{
            a.agent.emoji(), a.agent.name(), status_icon, status_label, GY, voice, R,
        });
    }

    // ═══ ТРИ ПУТИ ═══
    try writer.print("\n  {s}\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80 \xd0\xa2\xd0\xa0\xd0\x98 \xd0\x9f\xd0\xa3\xd0\xa2\xd0\x98 \xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80{s}\n\n", .{ G, R });
    var paths: [3]Path = undefined;
    var action_bufs: [3][128]u8 = undefined;
    const issues = three_paths.fetchIssues(std.heap.page_allocator);
    three_paths.generatePathsWithIssues(snapshot, &issues, &paths, &action_bufs);
    for (paths) |p| {
        try writer.print("  {s} {s}{s}{s}: {s}\n", .{
            p.tier.emoji(), CY, p.label, R, p.action,
        });
    }

    // ═══ φ poetry footer ═══
    try writer.print("\n  {s}", .{GY});
    var phi_buf: [256]u8 = undefined;
    const phi_line = phi_poetry.generatePhiLine(snapshot, &phi_buf);
    try writer.print("\xcf\x86: \"{s}\"", .{phi_line});
    try writer.print("{s}\n{s}\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90{s}\n\n", .{ R, G, R });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

/// Run `tri faculty` command.
pub fn runFacultyCommand(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    const snapshot = try collectSnapshot(allocator);
    const delta = loadPrevDelta(allocator, snapshot);
    // Render to a buffer, then print via std.debug.print
    var buf: [16384]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    renderCompact(snapshot, delta, stream.writer()) catch {
        std.debug.print("Faculty Board render error\n", .{});
        return;
    };
    std.debug.print("{s}", .{stream.getWritten()});
    savePrevSnapshot(snapshot);
    sendFacultyTelegram(snapshot, delta);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TELEGRAM NOTIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Send faculty dashboard to Telegram. Fire-and-forget — errors are logged, never crash.
fn sendFacultyTelegram(snapshot: FacultySnapshot, delta: FacultyDelta) void {
    const bot_token = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse return;
    const chat_id = std.posix.getenv("TELEGRAM_CHAT_ID") orelse return;

    // Build plain-text message (no ANSI)
    var msg_buf: [3072]u8 = undefined;
    var msg_stream = std.io.fixedBufferStream(&msg_buf);
    const w = msg_stream.writer();

    // Header with stats
    w.print("\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90 TRI \xd0\xa1\xd0\xa2\xd0\x90\xd0\xa2\xd0\xa3\xd0\xa1 \xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\n", .{}) catch return;
    w.print("Build: {s} {d} | Compile: {d}% | V: {d:.3}\n", .{
        if (snapshot.build_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c",
        snapshot.binaries,
        snapshot.compile_rate,
        snapshot.v_number,
    }) catch |err| {
        std.log.debug("faculty_board: write build stats failed: {}", .{err});
    };

    // Agent commands (last 5 from log)
    var cmd_lines: [5][]const u8 = undefined;
    var cmd_log_buf: [1024]u8 = undefined;
    const cmd_count = lastNCommands(5, &cmd_lines, &cmd_log_buf);
    if (cmd_count > 0) {
        w.print("\n\xf0\x9f\x93\xa1 \xd0\x9a\xd0\x9e\xd0\x9c\xd0\x90\xd0\x9d\xd0\x94\xd0\xab ({d}):\n", .{cmd_count}) catch |err| {
            std.log.debug("faculty_board: write commands header failed: {}", .{err});
        };
        for (cmd_lines[0..cmd_count]) |line| {
            w.print("  {s}\n", .{line}) catch |err| {
                std.log.debug("faculty_board: write command line failed: {}", .{err});
            };
        }
    }

    // Analysis summary
    w.print("\n", .{}) catch |err| {
        std.log.debug("faculty_board: write newline failed: {}", .{err});
    };
    var analysis_buf: [512]u8 = undefined;
    const analysis = analysis_engine.generateAnalysis(snapshot, delta, &analysis_buf);
    w.print("{s}\n", .{analysis}) catch |err| {
        std.log.debug("faculty_board: write analysis failed: {}", .{err});
    };

    const msg = msg_stream.getWritten();

    // Deduplication: FNV-1a hash → skip if unchanged
    const hash = std.hash.Fnv1a_64.hash(msg);
    if (loadTgHash()) |prev_hash| {
        if (prev_hash == hash) return;
    }

    // Build URL
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/sendMessage", .{bot_token}) catch return;

    // Build JSON body with manual escaping
    var body_buf: [6144]u8 = undefined;
    var i: usize = 0;

    const prefix = "{\"chat_id\":\"";
    @memcpy(body_buf[i..][0..prefix.len], prefix);
    i += prefix.len;
    @memcpy(body_buf[i..][0..chat_id.len], chat_id);
    i += chat_id.len;

    const mid = "\",\"text\":\"";
    @memcpy(body_buf[i..][0..mid.len], mid);
    i += mid.len;

    // JSON-escape message text
    for (msg) |c| {
        if (i + 2 >= body_buf.len - 30) break;
        switch (c) {
            '"' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = 'n';
                i += 2;
            },
            '\r' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = 'r';
                i += 2;
            },
            else => {
                body_buf[i] = c;
                i += 1;
            },
        }
    }

    const suffix = "\"}";
    if (i + suffix.len <= body_buf.len) {
        @memcpy(body_buf[i..][0..suffix.len], suffix);
        i += suffix.len;
    }

    const body = body_buf[0..i];

    // Fire-and-forget HTTP POST
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var client = std.http.Client{ .allocator = gpa.allocator() };
    defer client.deinit();

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = body,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    }) catch |err| {
        std.debug.print("[faculty-tg] send error: {s}\n", .{@errorName(err)});
        return;
    };

    if (result.status != .ok) {
        std.debug.print("[faculty-tg] API status {d}\n", .{@intFromEnum(result.status)});
    }

    // Save hash for dedup
    saveTgHash(hash);
}

fn loadTgHash() ?u64 {
    const file = std.fs.cwd().openFile(TG_HASH_PATH, .{}) catch return null;
    defer file.close();
    var buf: [20]u8 = undefined;
    const n = file.readAll(&buf) catch return null;
    const trimmed = std.mem.trimRight(u8, buf[0..n], "\n\r ");
    return std.fmt.parseInt(u64, trimmed, 10) catch null;
}

fn saveTgHash(hash: u64) void {
    var buf: [20]u8 = undefined;
    const content = std.fmt.bufPrint(&buf, "{d}", .{hash}) catch return;
    const file = std.fs.cwd().createFile(TG_HASH_PATH, .{}) catch return;
    defer file.close();
    file.writeAll(content) catch |err| {
        std.log.debug("faculty_board: write TG hash failed: {}", .{err});
    };
}

/// Read last N lines from agent_commands.log.
/// Returns slices into `buf`. Returns count of lines found.
fn lastNCommands(comptime max: usize, out: *[max][]const u8, buf: *[1024]u8) usize {
    const file = std.fs.cwd().openFile(AGENT_CMD_LOG, .{}) catch return 0;
    defer file.close();

    // Read tail of file (last 1KB is enough for ~10 lines)
    const stat = file.stat() catch return 0;
    if (stat.size == 0) return 0;

    const skip = if (stat.size > buf.len) stat.size - buf.len else 0;
    file.seekTo(skip) catch return 0;
    const n = file.readAll(buf) catch return 0;
    if (n == 0) return 0;

    // Split into lines, collect last `max`
    var all_lines: [64][]const u8 = undefined;
    var total: usize = 0;
    var iter = std.mem.splitScalar(u8, buf[0..n], '\n');
    while (iter.next()) |line| {
        if (line.len > 0 and total < 64) {
            all_lines[total] = line;
            total += 1;
        }
    }

    // Take last `max` lines
    const start = if (total > max) total - max else 0;
    const count = total - start;
    for (0..count) |idx| {
        out[idx] = all_lines[start + idx];
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DELTA PERSISTENCE — save/load previous snapshot for delta computation
// ═══════════════════════════════════════════════════════════════════════════════

fn loadPrevDelta(allocator: Allocator, snapshot: FacultySnapshot) FacultyDelta {
    const content = std.fs.cwd().readFileAlloc(allocator, PREV_PATH, 1024) catch return .{};
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    const ts_str = lines.next() orelse return .{};
    const rate_str = lines.next() orelse return .{};
    const active_str = lines.next() orelse return .{};
    const dirty_str = lines.next() orelse return .{};

    const prev_ts = std.fmt.parseInt(i64, ts_str, 10) catch return .{};
    const prev_rate = std.fmt.parseInt(u8, rate_str, 10) catch return .{};
    const prev_active = std.fmt.parseInt(u8, active_str, 10) catch return .{};
    const prev_dirty = std.fmt.parseInt(u16, dirty_str, 10) catch return .{};

    const now = std.time.timestamp();
    const seconds_ago = now - prev_ts;
    const cur_active = snapshot.activeFaculty();

    const cur_rate: i16 = @intCast(snapshot.compile_rate);
    const pr: i16 = @intCast(prev_rate);
    const cur_a: i8 = @intCast(cur_active);
    const pa: i8 = @intCast(prev_active);
    const cur_d: i32 = @intCast(snapshot.dirty_files);
    const pd: i32 = @intCast(prev_dirty);

    return .{
        .has_prev = true,
        .seconds_ago = seconds_ago,
        .compile_rate_delta = cur_rate - pr,
        .active_delta = cur_a - pa,
        .dirty_delta = cur_d - pd,
        .compile_frozen = snapshot.compile_rate == prev_rate and seconds_ago > 3600,
        .prev_compile_rate = prev_rate,
        .prev_active = prev_active,
        .prev_dirty = prev_dirty,
    };
}

fn savePrevSnapshot(snapshot: FacultySnapshot) void {
    const active = snapshot.activeFaculty();
    var buf: [256]u8 = undefined;
    const content = std.fmt.bufPrint(&buf, "{d}\n{d}\n{d}\n{d}\n{d}\n{d}\n{d}\n", .{
        std.time.timestamp(),
        @as(u16, snapshot.compile_rate),
        @as(u16, active),
        snapshot.dirty_files,
        snapshot.compile_pass,
        snapshot.compile_total,
        snapshot.open_issues,
    }) catch return;

    const file = std.fs.cwd().createFile(PREV_PATH, .{}) catch return;
    defer file.close();
    file.writeAll(content) catch |err| {
        std.log.debug("faculty_board: write prev snapshot failed: {}", .{err});
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA HELPERS (exec subprocesses, parse files)
// ═══════════════════════════════════════════════════════════════════════════════

fn countBinaries() u8 {
    var count: u8 = 0;
    var dir = std.fs.cwd().openDir("zig-out/bin", .{ .iterate = true }) catch return 0;
    defer dir.close();
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file) count +|= 1;
    }
    return count;
}

const RegenStats = struct { pass: u16, total: u16 };

fn parseRegenReport(allocator: Allocator) RegenStats {
    const content = std.fs.cwd().readFileAlloc(allocator, REGEN_REPORT, 256 * 1024) catch
        return .{ .pass = 0, .total = 0 };
    defer allocator.free(content);

    var pass: u16 = 0;
    var total: u16 = 0;
    var iter = std.mem.splitScalar(u8, content, '\n');
    while (iter.next()) |line| {
        if (std.mem.indexOf(u8, line, "✅") != null or std.mem.indexOf(u8, line, "❌") != null) {
            total += 1;
            if (std.mem.indexOf(u8, line, "✅") != null) pass += 1;
        }
    }
    return .{ .pass = pass, .total = total };
}

fn getGitBranch(allocator: Allocator) []const u8 {
    const result = runCmd(allocator, &.{ "git", "branch", "--show-current" }) catch return "unknown";
    defer allocator.free(result);
    // Result is allocated, but we return a static fallback or leak intentionally for CLI
    // (program exits after printing)
    if (result.len > 0) {
        const trimmed = std.mem.trimRight(u8, result, "\n\r ");
        if (trimmed.len > 0) {
            return allocator.dupe(u8, trimmed) catch "unknown";
        }
    }
    return "unknown";
}

fn countDirtyFiles(allocator: Allocator) u16 {
    const result = runCmd(allocator, &.{ "git", "status", "--porcelain" }) catch return 0;
    defer allocator.free(result);
    var count: u16 = 0;
    var iter = std.mem.splitScalar(u8, result, '\n');
    while (iter.next()) |line| {
        if (line.len > 0) count += 1;
    }
    return count;
}

fn countOpenIssues(allocator: Allocator) u16 {
    const result = runCmd(allocator, &.{ "gh", "issue", "list", "--state=open", "--json=number", "--limit=200" }) catch return 0;
    defer allocator.free(result);
    // Count occurrences of "number" in JSON array
    var count: u16 = 0;
    var idx: usize = 0;
    while (std.mem.indexOfPos(u8, result, idx, "\"number\"")) |pos| {
        count += 1;
        idx = pos + 8;
    }
    return count;
}

fn countMuPatterns(allocator: Allocator) u16 {
    const content = std.fs.cwd().readFileAlloc(allocator, MU_LEARNING_DB, 64 * 1024) catch
        return 0;
    defer allocator.free(content);
    // Count pattern entries
    var count: u16 = 0;
    var idx: usize = 0;
    while (std.mem.indexOfPos(u8, content, idx, "\"pattern\"")) |pos| {
        count += 1;
        idx = pos + 9;
    }
    // Fallback: count lines if no "pattern" key
    if (count == 0) {
        var iter = std.mem.splitScalar(u8, content, '\n');
        while (iter.next()) |line| {
            if (line.len > 2) count += 1;
        }
    }
    return count;
}

fn isProcessRunning(allocator: Allocator, name: []const u8) bool {
    const result = runCmd(allocator, &.{ "pgrep", "-f", name }) catch return false;
    defer allocator.free(result);
    return result.len > 0;
}

fn runCmd(allocator: Allocator, argv: []const []const u8) ![]u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 1024 * 1024,
    }) catch return error.CommandFailed;
    allocator.free(result.stderr);
    return result.stdout;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "countBinaries returns number" {
    const count = countBinaries();
    // May be 0 if not built, that's fine
    try std.testing.expect(count <= 50);
}

test "parseRegenReport handles missing file" {
    const stats = parseRegenReport(std.testing.allocator);
    // File may or may not exist in test env
    _ = stats;
}

test "renderCompact produces output" {
    const snap = types.FacultySnapshot{
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

    var out_buf: [8192]u8 = undefined;
    var stream = std.io.fixedBufferStream(&out_buf);
    try renderCompact(snap, .{}, stream.writer());
    const output = stream.getWritten();
    try std.testing.expect(output.len > 100);
    try std.testing.expect(std.mem.indexOf(u8, output, "TRINITY") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "compile") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "faculty") != null);
}
