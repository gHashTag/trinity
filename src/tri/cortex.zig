// @origin(spec:faculty_board.tri) @regen(manual-impl)
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
const tri_state = @import("tri_state.zig");
const hippocampus = @import("hippocampus.zig");
const FacultySnapshot = types.FacultySnapshot;
const FacultyDelta = types.FacultyDelta;
const AgentState = types.AgentState;
const Path = three_paths.Path;

pub const Lang = enum {
    ru,
    en,

    pub fn parse(s: []const u8) ?Lang {
        if (std.mem.eql(u8, s, "en")) return .en;
        if (std.mem.eql(u8, s, "ru")) return .ru;
        return null;
    }
};

const PREV_PATH = ".trinity/faculty_prev.dat";
const TG_HASH_PATH = ".trinity/faculty_tg_hash.dat";
const THOUGHT_HASH_PATH = ".trinity/faculty_thought_hash.dat";
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

    // Read swarm state from swarm_state.json
    const swarm = readSwarmState(allocator);
    if (swarm.agents > 0 and swarm.assigned_tasks > 0) {
        snap.agents[4].status = .up;
        snap.agents[4].last_action = swarm.action_desc;
    } else if (swarm.agents > 0 and swarm.assigned_tasks == 0) {
        snap.agents[4].status = .stub;
        snap.agents[4].last_action = swarm.action_desc;
    } else if (swarm.agents == 0 and swarm.total_tasks > 0) {
        snap.agents[4].status = .stub;
        snap.agents[4].last_action = swarm.action_desc;
    }
    // else: agents == 0 AND tasks == 0 → keep .tbd default

    // Build health: if we have 9 binaries, build is OK
    snap.build_ok = (snap.binaries >= 9);

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
// THOUGHT RENDERER — conversational delta report, TTS-ready
// ═══════════════════════════════════════════════════════════════════════════════

/// Render agent thought — conversational delta report.
/// Supports Russian (ru) and English (en). Ready for TTS and Telegram.
/// Returns number of bytes written into buf.
pub fn renderThought(
    snapshot: FacultySnapshot,
    delta: FacultyDelta,
    mu_hb: voice_engine.MuHeartbeat,
    scholar_hb: voice_engine.ScholarHeartbeat,
    buf: []u8,
) usize {
    return renderThoughtLang(snapshot, delta, mu_hb, scholar_hb, buf, .ru);
}

/// Render agent thought with explicit language selection.
pub fn renderThoughtLang(
    snapshot: FacultySnapshot,
    delta: FacultyDelta,
    mu_hb: voice_engine.MuHeartbeat,
    scholar_hb: voice_engine.ScholarHeartbeat,
    buf: []u8,
    lang: Lang,
) usize {
    var pos: usize = 0;

    const append = struct {
        fn f(b: []u8, p: *usize, comptime fmt: []const u8, args: anytype) void {
            const written = std.fmt.bufPrint(b[p.*..], fmt, args) catch return;
            p.* += written.len;
        }
    }.f;

    const L = struct {
        fn pick(l: Lang, comptime ru: []const u8, comptime en: []const u8) []const u8 {
            return if (l == .en) en else ru;
        }
    };

    // ── Paragraph 1: Opening + compile + scan + build (one flow) ──

    // Opening
    if (delta.has_prev and delta.seconds_ago > 0) {
        if (delta.seconds_ago < 60) {
            append(buf, &pos, "{s}, {s}.", .{ L.pick(lang, "\xd0\x92\xd0\xb5\xd1\x80\xd0\xbd\xd1\x83\xd0\xbb\xd1\x81\xd1\x8f", "Back"), L.pick(lang, "\xd1\x82\xd0\xbe\xd0\xbb\xd1\x8c\xd0\xba\xd0\xbe \xd1\x87\xd1\x82\xd0\xbe", "just now") });
        } else if (delta.seconds_ago < 3600) {
            append(buf, &pos, "{s}, {d} {s}.", .{ L.pick(lang, "\xd0\x92\xd0\xb5\xd1\x80\xd0\xbd\xd1\x83\xd0\xbb\xd1\x81\xd1\x8f", "Back"), @divTrunc(delta.seconds_ago, 60), L.pick(lang, "\xd0\xbc\xd0\xb8\xd0\xbd\xd1\x83\xd1\x82 \xd0\xbf\xd1\x80\xd0\xbe\xd1\x88\xd0\xbb\xd0\xbe", "minutes passed") });
        } else {
            append(buf, &pos, "{s}, {d} {s}.", .{ L.pick(lang, "\xd0\x92\xd0\xb5\xd1\x80\xd0\xbd\xd1\x83\xd0\xbb\xd1\x81\xd1\x8f", "Back"), @divTrunc(delta.seconds_ago, 3600), L.pick(lang, "\xd1\x87\xd0\xb0\xd1\x81\xd0\xbe\xd0\xb2 \xd0\xbf\xd1\x80\xd0\xbe\xd1\x88\xd0\xbb\xd0\xbe", "hours passed") });
        }
    } else {
        append(buf, &pos, "{s}.", .{L.pick(lang, "\xd0\x92\xd0\xb5\xd1\x80\xd0\xbd\xd1\x83\xd0\xbb\xd1\x81\xd1\x8f", "Back")});
    }

    // Compile (space-joined, same paragraph)
    if (snapshot.compile_rate == 100) {
        append(buf, &pos, " {s} \xe2\x80\x94 {s} {d} {s}.", .{
            L.pick(lang, "\xd0\x9a\xd0\xbe\xd0\xbc\xd0\xbf\xd0\xb8\xd0\xbb\xd1\x8f\xd1\x86\xd0\xb8\xd1\x8f \xd0\xb2 \xd0\xbf\xd0\xbe\xd0\xbb\xd0\xbd\xd0\xbe\xd0\xbc \xd0\xbf\xd0\xbe\xd1\x80\xd1\x8f\xd0\xb4\xd0\xba\xd0\xb5", "Compilation solid"),
            L.pick(lang, "\xd0\xb2\xd1\x81\xd0\xb5", "all"),
            snapshot.compile_total,
            L.pick(lang, "\xd1\x81\xd0\xbf\xd0\xb5\xd0\xba\xd0\xbe\xd0\xb2 \xd0\xbf\xd1\x80\xd0\xbe\xd1\x85\xd0\xbe\xd0\xb4\xd1\x8f\xd1\x82", "specs pass clean"),
        });
    } else if (delta.has_prev and delta.compile_rate_delta > 0) {
        append(buf, &pos, " {s} {d}/{d} (+{d}pp).", .{
            L.pick(lang, "\xd0\x9a\xd0\xbe\xd0\xbc\xd0\xbf\xd0\xb8\xd0\xbb\xd1\x8f\xd1\x86\xd0\xb8\xd1\x8f", "Compilation"),
            snapshot.compile_pass,
            snapshot.compile_total,
            delta.compile_rate_delta,
        });
    } else if (delta.has_prev and delta.compile_rate_delta < 0) {
        append(buf, &pos, " {s} {d}/{d} ({d}pp).", .{
            L.pick(lang, "\xd0\x9a\xd0\xbe\xd0\xbc\xd0\xbf\xd0\xb8\xd0\xbb\xd1\x8f\xd1\x86\xd0\xb8\xd1\x8f", "Compilation"),
            snapshot.compile_pass,
            snapshot.compile_total,
            delta.compile_rate_delta,
        });
    } else {
        append(buf, &pos, " {s} {d}/{d}.", .{
            L.pick(lang, "\xd0\x9a\xd0\xbe\xd0\xbc\xd0\xbf\xd0\xb8\xd0\xbb\xd1\x8f\xd1\x86\xd0\xb8\xd1\x8f", "Compilation"),
            snapshot.compile_pass,
            snapshot.compile_total,
        });
    }

    // Scan + build status (same paragraph)
    if (mu_hb.wake > 0) {
        if (mu_hb.errors > 0) {
            append(buf, &pos, " {s} {d} {s}.", .{ L.pick(lang, "\xd0\x9f\xd0\xbe\xd1\x81\xd0\xba\xd0\xb0\xd0\xbd\xd0\xb8\xd0\xbb", "Scanned"), mu_hb.errors, L.pick(lang, "\xd0\xbe\xd1\x88\xd0\xb8\xd0\xb1\xd0\xbe\xd0\xba", "errors") });
        } else {
            append(buf, &pos, " {s} \xe2\x80\x94 {s}.", .{ L.pick(lang, "\xd0\x9f\xd0\xbe\xd1\x81\xd0\xba\xd0\xb0\xd0\xbd\xd0\xb8\xd0\xbb", "Scanned"), L.pick(lang, "\xd1\x87\xd0\xb8\xd1\x81\xd1\x82\xd0\xbe", "clean") });
        }
        if (mu_hb.fixes > 0) {
            append(buf, &pos, " {s} {d}.", .{ L.pick(lang, "\xd0\x92\xd1\x8b\xd0\xbb\xd0\xb5\xd1\x87\xd0\xb8\xd0\xbb", "Fixed"), mu_hb.fixes });
        }
        if (!mu_hb.build_ok) {
            append(buf, &pos, " {s}.", .{L.pick(lang, "\xd0\x9f\xd1\x80\xd0\xb0\xd0\xb2\xd0\xb4\xd0\xb0 \xd0\xb1\xd0\xb8\xd0\xbb\xd0\xb4 \xd1\x83\xd0\xbf\xd0\xb0\xd0\xbb", "Though the build is failing")});
        } else if (!mu_hb.test_ok) {
            append(buf, &pos, " {s}.", .{L.pick(lang, "\xd0\xa2\xd0\xb5\xd1\x81\xd1\x82\xd1\x8b \xd0\xba\xd1\x80\xd0\xb0\xd1\x81\xd0\xbd\xd1\x8b\xd0\xb5", "Tests are red")});
        }
    }
    append(buf, &pos, "\n\n", .{});

    // ── Paragraph 2: Scholar + MU heartbeat ages ──
    var has_p2 = false;
    if (scholar_hb.wake > 0) {
        has_p2 = true;
        if (scholar_hb.researched > 0) {
            append(buf, &pos, "Scholar {s} {d} {s}.", .{ L.pick(lang, "\xd0\xbd\xd0\xb0\xd1\x88\xd1\x91\xd0\xbb", "found"), scholar_hb.researched, L.pick(lang, "\xd0\xbf\xd0\xb0\xd1\x82\xd1\x82\xd0\xb5\xd1\x80\xd0\xbd\xd0\xbe\xd0\xb2", "patterns") });
        } else if (scholar_hb.fails_found > 0) {
            append(buf, &pos, "Scholar {s} {d} {s}.", .{ L.pick(lang, "\xd0\xb2\xd0\xb8\xd0\xb4\xd0\xb8\xd1\x82", "sees"), scholar_hb.fails_found, L.pick(lang, "\xd1\x84\xd0\xb5\xd0\xb9\xd0\xbb\xd0\xbe\xd0\xb2", "failures") });
        } else {
            append(buf, &pos, "Scholar {s}.", .{L.pick(lang, "\xd1\x81\xd0\xbf\xd0\xb8\xd1\x82, \xd0\xbd\xd0\xb8\xd1\x87\xd0\xb5\xd0\xb3\xd0\xbe \xd0\xbd\xd0\xbe\xd0\xb2\xd0\xbe\xd0\xb3\xd0\xbe \xd0\xbd\xd0\xb5 \xd0\xbd\xd0\xb0\xd1\x80\xd1\x8b\xd0\xbb", "sleeping, nothing new found")});
        }
        if (scholar_hb.age_s > 3600) {
            const sch_hours = @divTrunc(scholar_hb.age_s, 3600);
            append(buf, &pos, " {s} {d}{s}", .{ L.pick(lang, "\xd0\x9c\xd0\xbe\xd0\xbb\xd1\x87\xd0\xb8\xd1\x82", "Silent"), sch_hours, L.pick(lang, "\xd1\x87!", "h!") });
        }
    }
    if (mu_hb.wake > 0 and mu_hb.age_s > 3600) {
        if (has_p2) append(buf, &pos, " ", .{});
        has_p2 = true;
        const mu_hours = @divTrunc(mu_hb.age_s, 3600);
        append(buf, &pos, "MU {s} {d}{s}", .{ L.pick(lang, "\xd0\xbc\xd0\xbe\xd0\xbb\xd1\x87\xd0\xb8\xd1\x82 \xd1\x83\xd0\xb6\xd0\xb5", "silent for"), mu_hours, L.pick(lang, "\xd1\x87 \xe2\x80\x94 \xd0\xbd\xd0\xb0\xd0\xb4\xd0\xbe \xd0\xb1\xd1\x8b \xd0\xbf\xd1\x80\xd0\xbe\xd0\xb2\xd0\xb5\xd1\x80\xd0\xb8\xd1\x82\xd1\x8c.", "h \xe2\x80\x94 should check.") });
    }
    if (has_p2) append(buf, &pos, "\n\n", .{});

    // ── Paragraph 3: Commits (comma-separated, not bullets) ──
    // Helper: strip "type(scope): " prefix from conventional commits
    const stripPrefix = struct {
        fn f(raw: []const u8) []const u8 {
            // Find ": " after type(scope) — e.g. "feat(cloud): description"
            if (std.mem.indexOf(u8, raw, ": ")) |colon_pos| {
                if (colon_pos < 30) return raw[colon_pos + 2 ..];
            }
            return raw;
        }
    };
    {
        var commit_bufs: [3][80]u8 = undefined;
        const commit_count = voice_engine.readRecentCommits(&commit_bufs);
        if (commit_count > 0) {
            var clens: [3]usize = .{ 0, 0, 0 };
            for (0..commit_count) |ci| {
                while (clens[ci] < 80 and commit_bufs[ci][clens[ci]] != 0) : (clens[ci] += 1) {}
            }
            // Strip conventional commit prefixes for human-readable output
            const c0 = if (clens[0] > 0) stripPrefix.f(commit_bufs[0][0..clens[0]]) else "";
            const c1 = if (clens[1] > 0) stripPrefix.f(commit_bufs[1][0..clens[1]]) else "";
            const c2 = if (clens[2] > 0) stripPrefix.f(commit_bufs[2][0..clens[2]]) else "";
            if (commit_count == 1 and c0.len > 0) {
                append(buf, &pos, "{s} {s}.", .{ L.pick(lang, "\xd0\x9f\xd0\xbe\xd1\x81\xd0\xbb\xd0\xb5\xd0\xb4\xd0\xbd\xd0\xb5\xd0\xb5 \xe2\x80\x94", "Latest \xe2\x80\x94"), c0 });
            } else if (commit_count == 2) {
                append(buf, &pos, "{s} {s} {s} {s}.", .{ L.pick(lang, "\xd0\x98\xd0\xb7 \xd0\xbf\xd0\xbe\xd1\x81\xd0\xbb\xd0\xb5\xd0\xb4\xd0\xbd\xd0\xb5\xd0\xb3\xd0\xbe:", "Recent:"), c0, L.pick(lang, "\xd0\xb8", "and"), c1 });
            } else if (commit_count >= 3) {
                append(buf, &pos, "{s} {s}, {s}, {s} {s}.", .{ L.pick(lang, "\xd0\x98\xd0\xb7 \xd0\xbf\xd0\xbe\xd1\x81\xd0\xbb\xd0\xb5\xd0\xb4\xd0\xbd\xd0\xb5\xd0\xb3\xd0\xbe:", "Recent:"), c0, c1, L.pick(lang, "\xd0\xb8", "and"), c2 });
            }
            if (snapshot.agents[0].status == .down) {
                append(buf, &pos, " {s}.", .{L.pick(lang, "\xd0\xa0\xd0\xb0\xd0\xbb\xd1\x8c\xd1\x84 \xd0\xbb\xd0\xb5\xd0\xb6\xd0\xb8\xd1\x82", "Ralph is down")});
            }
            append(buf, &pos, "\n\n", .{});
        } else if (snapshot.agents[0].status == .down) {
            append(buf, &pos, "{s}.\n\n", .{L.pick(lang, "\xd0\xa0\xd0\xb0\xd0\xbb\xd1\x8c\xd1\x84 \xd0\xbb\xd0\xb5\xd0\xb6\xd0\xb8\xd1\x82", "Ralph is down")});
        }
    }

    // ── Paragraph 4: Dirty + agents + closing (one flow) ──
    if (snapshot.dirty_files > 0) {
        append(buf, &pos, "{d} {s}. ", .{ snapshot.dirty_files, L.pick(lang, "\xd1\x84\xd0\xb0\xd0\xb9\xd0\xbb\xd0\xbe\xd0\xb2 \xd0\xbd\xd0\xb5\xd0\xb7\xd0\xb0\xd0\xba\xd0\xbe\xd0\xbc\xd0\xbc\xd0\xb8\xd1\x87\xd0\xb5\xd0\xbd\xd0\xbe \xe2\x80\x94 \xd0\xbf\xd0\xbe\xd1\x80\xd0\xb0 \xd0\xbf\xd1\x80\xd0\xb8\xd0\xb1\xd1\x80\xd0\xb0\xd1\x82\xd1\x8c\xd1\x81\xd1\x8f", "files uncommitted \xe2\x80\x94 should clean up") });
    }
    {
        const active = snapshot.activeFaculty();
        append(buf, &pos, "{d}/6 {s}", .{ active, L.pick(lang, "\xd1\x84\xd0\xb0\xd0\xba\xd1\x83\xd0\xbb\xd1\x8c\xd1\x82\xd0\xb5\xd1\x82\xd0\xbe\xd0\xb2 \xd0\xbd\xd0\xb0 \xd0\xbd\xd0\xbe\xd0\xb3\xd0\xb0\xd1\x85", "faculties running") });
    }
    if (snapshot.cycle == .emergency) {
        if (!snapshot.build_ok) {
            append(buf, &pos, " \xe2\x80\x94 {s}.\n", .{L.pick(lang, "\xd0\xbd\xd0\xb0\xd0\xb4\xd0\xbe \xd1\x87\xd0\xb8\xd0\xbd\xd0\xb8\xd1\x82\xd1\x8c \xd0\xb1\xd0\xb8\xd0\xbb\xd0\xb4", "need to fix the build")});
        } else {
            append(buf, &pos, " \xe2\x80\x94 {s}.\n", .{L.pick(lang, "\xd0\xbd\xd0\xb0\xd0\xb4\xd0\xbe \xd1\x87\xd0\xb8\xd0\xbd\xd0\xb8\xd1\x82\xd1\x8c \xd1\x81\xd0\xbf\xd0\xb5\xd0\xba\xd0\xb8", "need to fix specs")});
        }
    } else if (snapshot.open_issues > 0) {
        append(buf, &pos, ", {d} {s}.\n", .{ snapshot.open_issues, L.pick(lang, "\xd0\xb7\xd0\xb0\xd0\xb4\xd0\xb0\xd1\x87 \xd0\xbe\xd1\x82\xd0\xba\xd1\x80\xd1\x8b\xd1\x82\xd0\xbe \xe2\x80\x94 \xd0\xb5\xd1\x81\xd1\x82\xd1\x8c \xd1\x87\xd0\xb5\xd0\xbc \xd0\xb7\xd0\xb0\xd0\xbd\xd1\x8f\xd1\x82\xd1\x8c\xd1\x81\xd1\x8f", "tasks open \xe2\x80\x94 plenty to do") });
    } else {
        append(buf, &pos, ".\n", .{});
    }

    return pos;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RAW DATA OUTPUT (for hybrid neuro-rendering)
// ═══════════════════════════════════════════════════════════════════════════════

/// Render structured key=value data for Claude to narrate.
/// Used by `tri faculty --raw`. Machine-readable, human-narrated.
const RawContext = struct {
    snapshot: FacultySnapshot,
    delta: FacultyDelta,
    mu_hb: voice_engine.MuHeartbeat,
    scholar_hb: voice_engine.ScholarHeartbeat,
    swarm: SwarmInfo,
    pipeline: ?tri_state.PipelineCheckpoint,
};

fn renderRaw(ctx: RawContext, buf: []u8) usize {
    var pos: usize = 0;
    const append = struct {
        fn f(b: []u8, p: *usize, comptime fmt: []const u8, args: anytype) void {
            const written = std.fmt.bufPrint(b[p.*..], fmt, args) catch return;
            p.* += written.len;
        }
    }.f;

    // Strip "type(scope): " from conventional commit messages
    const stripPrefix = struct {
        fn f(raw: []const u8) []const u8 {
            if (std.mem.indexOf(u8, raw, ": ")) |colon_pos| {
                if (colon_pos < 30) return raw[colon_pos + 2 ..];
            }
            return raw;
        }
    };

    const snapshot = ctx.snapshot;
    const delta = ctx.delta;
    const mu_hb = ctx.mu_hb;
    const scholar_hb = ctx.scholar_hb;

    // Time
    if (delta.has_prev and delta.seconds_ago > 0) {
        append(buf, &pos, "seconds_ago={d}\n", .{delta.seconds_ago});
    }

    // Compile
    append(buf, &pos, "compile_pass={d}\ncompile_total={d}\ncompile_rate={d}\n", .{ snapshot.compile_pass, snapshot.compile_total, snapshot.compile_rate });
    if (delta.has_prev) {
        append(buf, &pos, "compile_delta={d}\n", .{delta.compile_rate_delta});
        if (delta.compile_frozen) append(buf, &pos, "compile_frozen=true\n", .{});
    }

    // MU scan
    if (mu_hb.wake > 0) {
        append(buf, &pos, "mu_wake={d}\nmu_errors={d}\nmu_fixes={d}\n", .{ mu_hb.wake, mu_hb.errors, mu_hb.fixes });
        append(buf, &pos, "build_ok={}\ntest_ok={}\n", .{ snapshot.build_ok, mu_hb.test_ok });
        if (mu_hb.age_s > 300) append(buf, &pos, "mu_age_s={d}\n", .{mu_hb.age_s});
    }

    // Scholar
    if (scholar_hb.wake > 0) {
        append(buf, &pos, "scholar_wake={d}\nscholar_researched={d}\nscholar_fails={d}\n", .{ scholar_hb.wake, scholar_hb.researched, scholar_hb.fails_found });
        if (scholar_hb.age_s > 300) append(buf, &pos, "scholar_age_s={d}\n", .{scholar_hb.age_s});
    }

    // Commits (stripped of conventional prefix)
    {
        var commit_bufs: [3][80]u8 = undefined;
        const commit_count = voice_engine.readRecentCommits(&commit_bufs);
        for (0..commit_count) |ci| {
            var clen: usize = 0;
            while (clen < 80 and commit_bufs[ci][clen] != 0) : (clen += 1) {}
            if (clen > 0) {
                append(buf, &pos, "commit={s}\n", .{stripPrefix.f(commit_bufs[ci][0..clen])});
            }
        }
    }

    // Status
    append(buf, &pos, "dirty={d}\n", .{snapshot.dirty_files});
    append(buf, &pos, "active_faculty={d}\ntotal_faculty=6\n", .{snapshot.activeFaculty()});
    append(buf, &pos, "open_issues={d}\n", .{snapshot.open_issues});
    append(buf, &pos, "cycle={s}\n", .{switch (snapshot.cycle) {
        .emergency => "emergency",
        .working => "working",
        .quiet => "quiet",
    }});
    if (snapshot.agents[0].status == .down) append(buf, &pos, "ralph_down=true\n", .{});

    // === Tier 1: V-number, zone, branch, binaries ===
    append(buf, &pos, "v_number={d:.3}\nv_zone={s}\n", .{ snapshot.v_number, snapshot.v_zone.label() });
    append(buf, &pos, "branch={s}\nbinaries={d}\n", .{ snapshot.git_branch, snapshot.binaries });

    // Pipeline (with timestamp guard)
    if (ctx.pipeline) |p| {
        const now = std.time.timestamp();
        const age_s: i64 = if (now > p.timestamp) now - p.timestamp else 0;
        const age_h = @divTrunc(age_s, 3600);
        append(buf, &pos, "pipeline={s}:link{d}:{d}h\n", .{ p.status, p.last_link, age_h });
    } else {
        append(buf, &pos, "pipeline=no_data\n", .{});
    }

    // Swarm
    const idle = if (ctx.swarm.agents > ctx.swarm.assigned_tasks) ctx.swarm.agents - ctx.swarm.assigned_tasks else 0;
    append(buf, &pos, "swarm={d}idle/{d}busy:{d}pending\n", .{ idle, ctx.swarm.assigned_tasks, ctx.swarm.total_tasks });

    // === Tier 2: MU rules, scholar age, agent statuses ===
    append(buf, &pos, "mu_rules={d}\n", .{snapshot.mu_patterns});
    if (scholar_hb.age_s > 0) {
        append(buf, &pos, "scholar_age_h={d}\n", .{@divTrunc(scholar_hb.age_s, 3600)});
    }

    // Agent statuses
    for (snapshot.agents) |a| {
        append(buf, &pos, "agent_{s}={s}\n", .{ @tagName(a.agent), @tagName(a.status) });
    }

    return pos;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

/// Run `tri faculty` command.
/// Default: thought mode (conversational delta). `tri faculty full` → old dashboard.
pub fn runFacultyCommand(allocator: Allocator, args: []const []const u8) !void {
    const snapshot = try collectSnapshot(allocator);
    const delta = loadPrevDelta(allocator, snapshot);

    // Parse arguments
    var full_mode = false;
    var raw_mode = false;
    var lang: Lang = .ru;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "full")) {
            full_mode = true;
        } else if (std.mem.eql(u8, arg, "--raw")) {
            raw_mode = true;
        } else if (std.mem.startsWith(u8, arg, "--lang=")) {
            lang = Lang.parse(arg[7..]) orelse .ru;
        } else if (std.mem.eql(u8, arg, "en")) {
            lang = .en;
        } else if (std.mem.eql(u8, arg, "ru")) {
            lang = .ru;
        }
    }

    var buf: [16384]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);

    if (raw_mode) {
        var mu_hb = voice_engine.readMuHeartbeat();
        var scholar_hb = voice_engine.readScholarHeartbeat();
        enrichFromHippocampus(allocator, &mu_hb, &scholar_hb);
        const swarm = readSwarmState(allocator);
        const pipeline = tri_state.loadPipelineCheckpoint(allocator);
        const raw_len = renderRaw(.{
            .snapshot = snapshot,
            .delta = delta,
            .mu_hb = mu_hb,
            .scholar_hb = scholar_hb,
            .swarm = swarm,
            .pipeline = pipeline,
        }, &buf);
        stream.pos = raw_len;
    } else if (full_mode) {
        renderCompact(snapshot, delta, stream.writer()) catch {
            std.debug.print("Faculty Board render error\n", .{});
            return;
        };
    } else {
        var mu_hb = voice_engine.readMuHeartbeat();
        var scholar_hb = voice_engine.readScholarHeartbeat();
        enrichFromHippocampus(allocator, &mu_hb, &scholar_hb);
        const thought_len = renderThoughtLang(snapshot, delta, mu_hb, scholar_hb, &buf, lang);
        stream.pos = thought_len;

        // Stale report detection: hash thought output, compare with previous
        const thought_hash = std.hash.Fnv1a_64.hash(buf[0..thought_len]);
        const stale = detectStaleReport(thought_hash);
        if (stale.is_stale) {
            const stale_msg = if (lang == .en)
                std.fmt.bufPrint(buf[thought_len..], "\n\xe2\x9a\xa0\xef\xb8\x8f STALE: report repeats {d}x in a row. Agents stuck?\n", .{stale.count}) catch ""
            else
                std.fmt.bufPrint(buf[thought_len..], "\n\xe2\x9a\xa0\xef\xb8\x8f STALE: \xd0\xbe\xd1\x82\xd1\x87\xd1\x91\xd1\x82 \xd0\xbf\xd0\xbe\xd0\xb2\xd1\x82\xd0\xbe\xd1\x80\xd1\x8f\xd0\xb5\xd1\x82\xd1\x81\xd1\x8f {d}\xd1\x85 \xd0\xbf\xd0\xbe\xd0\xb4\xd1\x80\xd1\x8f\xd0\xb4. \xd0\x90\xd0\xb3\xd0\xb5\xd0\xbd\xd1\x82\xd1\x8b \xd0\xb7\xd0\xb0\xd1\x81\xd1\x82\xd1\x80\xd1\x8f\xd0\xbb\xd0\xb8?\n", .{stale.count}) catch "";
            stream.pos = thought_len + stale_msg.len;
        }
    }

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
// STALE REPORT DETECTION — detect when agents are stuck (identical output)
// ═══════════════════════════════════════════════════════════════════════════════

const StaleResult = struct { is_stale: bool, count: u16 };

/// Compare thought hash with previous. If identical 3+ times in a row, report stale.
/// File format: "{hash}\n{count}\n"
fn detectStaleReport(current_hash: u64) StaleResult {
    const file = std.fs.cwd().openFile(THOUGHT_HASH_PATH, .{}) catch {
        saveThoughtHash(current_hash, 1);
        return .{ .is_stale = false, .count = 1 };
    };
    defer file.close();
    var read_buf: [48]u8 = undefined;
    const n = file.readAll(&read_buf) catch {
        saveThoughtHash(current_hash, 1);
        return .{ .is_stale = false, .count = 1 };
    };
    const data = read_buf[0..n];

    var lines = std.mem.splitScalar(u8, data, '\n');
    const hash_str = lines.next() orelse {
        saveThoughtHash(current_hash, 1);
        return .{ .is_stale = false, .count = 1 };
    };
    const count_str = lines.next() orelse "0";
    const prev_hash = std.fmt.parseInt(u64, hash_str, 10) catch 0;
    const prev_count = std.fmt.parseInt(u16, count_str, 10) catch 0;

    if (current_hash == prev_hash) {
        const new_count = prev_count +| 1;
        saveThoughtHash(current_hash, new_count);
        return .{ .is_stale = new_count >= 3, .count = new_count };
    } else {
        saveThoughtHash(current_hash, 1);
        return .{ .is_stale = false, .count = 1 };
    }
}

fn saveThoughtHash(hash: u64, count: u16) void {
    var write_buf: [48]u8 = undefined;
    const content = std.fmt.bufPrint(&write_buf, "{d}\n{d}\n", .{ hash, count }) catch return;
    const file = std.fs.cwd().createFile(THOUGHT_HASH_PATH, .{}) catch return;
    defer file.close();
    file.writeAll(content) catch {};
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

    // Lines 5-7: compile_pass, compile_total, open_issues (saved by savePrevSnapshot)
    const prev_compile_pass = std.fmt.parseInt(u16, lines.next() orelse "0", 10) catch 0;
    const prev_compile_total = std.fmt.parseInt(u16, lines.next() orelse "0", 10) catch 0;
    const prev_issues = std.fmt.parseInt(u16, lines.next() orelse "0", 10) catch 0;

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
        .prev_compile_pass = prev_compile_pass,
        .prev_compile_total = prev_compile_total,
        .prev_issues = prev_issues,
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
    // Get GH token — keyring may not be accessible from child process
    const token = getGhToken(allocator);
    defer if (token) |t| allocator.free(t);

    // Use --repo explicitly — gh can't always detect repo from subprocess context
    const result = runCmdWithToken(allocator, &.{
        "gh", "issue", "list", "--repo", "gHashTag/trinity", "--state=open", "--json=number", "--limit=200",
    }, token) catch return 0;
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

/// Get GitHub token: `gh auth token` (keyring, always current) → env GH_TOKEN / GITHUB_TOKEN
fn getGhToken(allocator: Allocator) ?[]u8 {
    // Prefer `gh auth token` — always returns current token from keyring.
    // Env vars (loaded from .env) may contain stale/revoked tokens.
    if (getGhAuthToken(allocator)) |t| return t;
    if (std.process.getEnvVarOwned(allocator, "GH_TOKEN") catch null) |t| return t;
    if (std.process.getEnvVarOwned(allocator, "GITHUB_TOKEN") catch null) |t| return t;
    return null;
}

fn getGhAuthToken(allocator: Allocator) ?[]u8 {
    // Run with clean env (only PATH + HOME) so gh reads from keyring,
    // not from a possibly-stale GH_TOKEN in the process environment.
    var clean_env = std.process.EnvMap.init(allocator);
    defer clean_env.deinit();
    // EnvMap.put copies the value, so we can use string literals for fallbacks
    const path = std.process.getEnvVarOwned(allocator, "PATH") catch null;
    defer if (path) |p| allocator.free(p);
    clean_env.put("PATH", path orelse "/usr/bin:/usr/local/bin") catch return null;
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch null;
    defer if (home) |h| allocator.free(h);
    clean_env.put("HOME", home orelse "/tmp") catch return null;
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "gh", "auth", "token" },
        .max_output_bytes = 4096,
        .env_map = &clean_env,
    }) catch return null;
    allocator.free(result.stderr);
    if (result.term != .Exited or result.term.Exited != 0 or result.stdout.len == 0) {
        allocator.free(result.stdout);
        return null;
    }
    // Trim trailing newline
    const len = std.mem.trimRight(u8, result.stdout, "\n\r").len;
    if (len == 0) {
        allocator.free(result.stdout);
        return null;
    }
    if (len < result.stdout.len) {
        const trimmed = allocator.alloc(u8, len) catch {
            allocator.free(result.stdout);
            return null;
        };
        @memcpy(trimmed, result.stdout[0..len]);
        allocator.free(result.stdout);
        return trimmed;
    }
    return result.stdout;
}

/// Run command with optional GH_TOKEN injected into environment
fn runCmdWithToken(allocator: Allocator, argv: []const []const u8, gh_token: ?[]const u8) ![]u8 {
    if (gh_token) |token| {
        // Get current environment and inject fresh GH_TOKEN (overrides stale .env value)
        var env_map = std.process.getEnvMap(allocator) catch return error.CommandFailed;
        defer env_map.deinit();
        env_map.put("GH_TOKEN", token) catch return error.CommandFailed;
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = argv,
            .max_output_bytes = 1024 * 1024,
            .env_map = &env_map,
        }) catch return error.CommandFailed;
        allocator.free(result.stderr);
        if (result.term != .Exited or result.term.Exited != 0) {
            allocator.free(result.stdout);
            return error.CommandFailed;
        }
        return result.stdout;
    }
    return runCmd(allocator, argv);
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

const SWARM_STATE_PATH = ".trinity/swarm_state.json";

const SwarmInfo = struct {
    agents: u16,
    total_tasks: u16,
    assigned_tasks: u16,
    action_desc: []const u8,
};

/// Enrich file-based heartbeats with hippocampus data (use fresher age if available)
fn enrichFromHippocampus(allocator: Allocator, mu_hb: *voice_engine.MuHeartbeat, scholar_hb: *voice_engine.ScholarHeartbeat) void {
    // Try phoenix heartbeat from hippocampus — if fresher, update mu age
    if (hippocampus.latestHeartbeat(allocator, "phoenix") catch null) |hb| {
        if (hb.ts > 0) {
            const now: u64 = @intCast(std.time.timestamp());
            const hipp_age: i64 = @intCast(now -| hb.ts);
            if (mu_hb.age_s == 0 or hipp_age < mu_hb.age_s) {
                mu_hb.age_s = hipp_age;
            }
        }
    }

    // Try scholar heartbeat from hippocampus
    if (hippocampus.latestHeartbeat(allocator, "scholar") catch null) |hb| {
        if (hb.ts > 0) {
            const now: u64 = @intCast(std.time.timestamp());
            const hipp_age: i64 = @intCast(now -| hb.ts);
            if (scholar_hb.age_s == 0 or hipp_age < scholar_hb.age_s) {
                scholar_hb.age_s = hipp_age;
            }
        }
    }
}

fn readSwarmState(allocator: Allocator) SwarmInfo {
    const content = std.fs.cwd().readFileAlloc(allocator, SWARM_STATE_PATH, 64 * 1024) catch
        return .{ .agents = 0, .total_tasks = 0, .assigned_tasks = 0, .action_desc = "" };
    defer allocator.free(content);

    // Count agents by counting "id" keys inside agents array
    var agent_count: u16 = 0;
    var task_count: u16 = 0;
    var assigned_count: u16 = 0;

    // Find agents section and count entries with "status"
    if (std.mem.indexOf(u8, content, "\"agents\"")) |agents_pos| {
        // Count "status" occurrences after agents key (each agent has one)
        var idx = agents_pos;
        // Find closing bracket of agents array
        const agents_end = if (std.mem.indexOfPos(u8, content, agents_pos, "]")) |end| end else content.len;
        while (std.mem.indexOfPos(u8, content[0..agents_end], idx, "\"status\"")) |pos| {
            agent_count += 1;
            idx = pos + 8;
        }
    }

    // Find tasks section and count entries
    if (std.mem.indexOf(u8, content, "\"tasks\"")) |tasks_pos| {
        var idx = tasks_pos;
        const tasks_end = if (std.mem.indexOfPos(u8, content, tasks_pos, "]")) |end| end else content.len;
        while (std.mem.indexOfPos(u8, content[0..tasks_end], idx, "\"status\"")) |pos| {
            task_count += 1;
            idx = pos + 8;
        }
        // Count assigned tasks (non-empty "assigned" field)
        idx = tasks_pos;
        while (std.mem.indexOfPos(u8, content[0..tasks_end], idx, "\"assigned\":\"")) |pos| {
            const val_start = pos + 12; // after "assigned":"
            if (val_start < tasks_end and content[val_start] != '"') {
                // Non-empty assigned value
                assigned_count += 1;
            }
            idx = pos + 12;
        }
    }

    // Build description string (static, no alloc needed)
    const desc: []const u8 = if (agent_count > 0 and assigned_count > 0)
        "routing"
    else if (agent_count > 0 and assigned_count == 0)
        "idle"
    else if (agent_count == 0 and task_count > 0)
        "no agents"
    else
        "";

    return .{
        .agents = agent_count,
        .total_tasks = task_count,
        .assigned_tasks = assigned_count,
        .action_desc = desc,
    };
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

test "renderThought produces conversational output" {
    const snap = types.FacultySnapshot{
        .agents = .{
            .{ .agent = .ralph, .status = .up, .last_action = "build" },
            .{ .agent = .scholar, .status = .tbd, .last_action = "" },
            .{ .agent = .mu, .status = .stub, .last_action = "" },
            .{ .agent = .oracle, .status = .up, .last_action = "watch" },
            .{ .agent = .swarm, .status = .stub, .last_action = "idle" },
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

    const mu_hb = voice_engine.MuHeartbeat{ .wake = 3, .fixes = 1, .errors = 2, .build_ok = true, .test_ok = true };
    const scholar_hb = voice_engine.ScholarHeartbeat{ .wake = 1, .researched = 5 };
    const delta = FacultyDelta{ .has_prev = true, .compile_rate_delta = 3 };

    var buf: [4096]u8 = undefined;
    const len = renderThought(snap, delta, mu_hb, scholar_hb, &buf);
    const output = buf[0..len];

    // Must produce non-trivial output
    try std.testing.expect(len > 20);
    // Must contain compile delta
    try std.testing.expect(std.mem.indexOf(u8, output, "+3pp") != null);
    // Must mention errors scanned
    try std.testing.expect(std.mem.indexOf(u8, output, "2") != null);
    // Must mention fixes
    try std.testing.expect(std.mem.indexOf(u8, output, "1") != null);
    // Must mention scholar researched
    try std.testing.expect(std.mem.indexOf(u8, output, "5") != null);
}

test "renderThought English mode" {
    const snap = types.FacultySnapshot{
        .agents = .{
            .{ .agent = .ralph, .status = .up, .last_action = "build" },
            .{ .agent = .scholar, .status = .tbd, .last_action = "" },
            .{ .agent = .mu, .status = .stub, .last_action = "" },
            .{ .agent = .oracle, .status = .up, .last_action = "watch" },
            .{ .agent = .swarm, .status = .stub, .last_action = "idle" },
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

    const mu_hb = voice_engine.MuHeartbeat{ .wake = 3, .fixes = 1, .errors = 2, .build_ok = true, .test_ok = true };
    const scholar_hb = voice_engine.ScholarHeartbeat{ .wake = 1, .researched = 5 };
    const delta = FacultyDelta{ .has_prev = true, .compile_rate_delta = 3 };

    var buf: [4096]u8 = undefined;
    const len = renderThoughtLang(snap, delta, mu_hb, scholar_hb, &buf, .en);
    const output = buf[0..len];

    // English output
    try std.testing.expect(len > 20);
    try std.testing.expect(std.mem.indexOf(u8, output, "Back") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "+3pp") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Scanned") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Scholar found") != null);
}

test "renderThought minimal output without delta" {
    const snap = types.FacultySnapshot{
        .agents = .{
            .{ .agent = .ralph, .status = .up, .last_action = "" },
            .{ .agent = .scholar, .status = .tbd, .last_action = "" },
            .{ .agent = .mu, .status = .stub, .last_action = "" },
            .{ .agent = .oracle, .status = .up, .last_action = "" },
            .{ .agent = .swarm, .status = .tbd, .last_action = "" },
            .{ .agent = .linter, .status = .up, .last_action = "" },
        },
        .build_ok = true,
        .binaries = 5,
        .compile_pass = 47,
        .compile_total = 47,
        .compile_rate = 100,
        .v_number = 1.618,
        .v_zone = .gold,
        .git_branch = "main",
        .dirty_files = 0,
        .open_issues = 0,
        .mu_patterns = 0,
        .cycle = .quiet,
    };

    var buf: [4096]u8 = undefined;
    const len = renderThought(snap, .{}, .{}, .{}, &buf);
    // Even with no data, should produce at least the opening line
    try std.testing.expect(len > 5);
}

test "stale detection triggers after 3 identical hashes" {
    // First call: new hash → not stale
    const hash1: u64 = 0xDEADBEEF;
    const r1 = detectStaleReport(hash1);
    try std.testing.expect(!r1.is_stale);
    try std.testing.expectEqual(@as(u16, 1), r1.count);

    // Second call: same hash → count=2, not stale yet
    const r2 = detectStaleReport(hash1);
    try std.testing.expect(!r2.is_stale);
    try std.testing.expectEqual(@as(u16, 2), r2.count);

    // Third call: same hash → count=3, STALE
    const r3 = detectStaleReport(hash1);
    try std.testing.expect(r3.is_stale);
    try std.testing.expectEqual(@as(u16, 3), r3.count);

    // Different hash → reset, not stale
    const hash2: u64 = 0xCAFEBABE;
    const r4 = detectStaleReport(hash2);
    try std.testing.expect(!r4.is_stale);
    try std.testing.expectEqual(@as(u16, 1), r4.count);

    // Cleanup
    std.fs.cwd().deleteFile(THOUGHT_HASH_PATH) catch {};
}

test "renderCompact produces output" {
    const snap = types.FacultySnapshot{
        .agents = .{
            .{ .agent = .ralph, .status = .up, .last_action = "build" },
            .{ .agent = .scholar, .status = .tbd, .last_action = "" },
            .{ .agent = .mu, .status = .stub, .last_action = "" },
            .{ .agent = .oracle, .status = .up, .last_action = "watch" },
            .{ .agent = .swarm, .status = .stub, .last_action = "idle" },
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

test "renderRaw full observatory output" {
    const snap = types.FacultySnapshot{
        .agents = .{
            .{ .agent = .ralph, .status = .up, .last_action = "build" },
            .{ .agent = .scholar, .status = .tbd, .last_action = "" },
            .{ .agent = .mu, .status = .stub, .last_action = "" },
            .{ .agent = .oracle, .status = .up, .last_action = "watch" },
            .{ .agent = .swarm, .status = .stub, .last_action = "idle" },
            .{ .agent = .linter, .status = .up, .last_action = "scan" },
        },
        .build_ok = true,
        .binaries = 9,
        .compile_pass = 334,
        .compile_total = 334,
        .compile_rate = 100,
        .v_number = 1.618,
        .v_zone = .gold,
        .git_branch = "main",
        .dirty_files = 42,
        .open_issues = 70,
        .mu_patterns = 12,
        .cycle = .working,
    };

    const mu_hb = voice_engine.MuHeartbeat{ .wake = 3, .fixes = 1, .errors = 2, .build_ok = true, .test_ok = true };
    const scholar_hb = voice_engine.ScholarHeartbeat{ .wake = 1, .researched = 5, .age_s = 120 };
    const delta = FacultyDelta{ .has_prev = true, .compile_rate_delta = 0, .seconds_ago = 333 };

    var buf: [8192]u8 = undefined;
    const len = renderRaw(.{
        .snapshot = snap,
        .delta = delta,
        .mu_hb = mu_hb,
        .scholar_hb = scholar_hb,
        .swarm = .{ .agents = 3, .total_tasks = 1, .assigned_tasks = 0, .action_desc = "idle" },
        .pipeline = null,
    }, &buf);
    const output = buf[0..len];

    // Existing fields
    try std.testing.expect(std.mem.indexOf(u8, output, "compile_pass=334") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "dirty=42") != null);

    // Tier 1: new fields
    try std.testing.expect(std.mem.indexOf(u8, output, "v_number=") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "v_zone=GOLD") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "branch=main") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "binaries=9") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "pipeline=no_data") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "swarm=3idle/0busy:1pending") != null);

    // Tier 2: agent statuses
    try std.testing.expect(std.mem.indexOf(u8, output, "mu_rules=12") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "agent_ralph=up") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "agent_scholar=tbd") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "agent_mu=stub") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "agent_oracle=up") != null);
}
