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
const AgentState = types.AgentState;
const Path = three_paths.Path;

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

/// Render compact Faculty Board to writer.
pub fn renderCompact(snapshot: FacultySnapshot, writer: anytype) !void {
    const R = colors.RESET;
    const G = colors.GOLDEN;
    const GR = colors.GREEN;
    const RD = colors.RED;
    const CY = colors.CYAN;
    const GY = colors.GRAY;

    // Header
    try writer.print("\n{s}═══ TRI СТАТУС ═══{s}\n\n", .{ G, R });

    // Metrics block
    const build_icon: []const u8 = if (snapshot.build_ok) "✅" else "❌";
    const build_color: []const u8 = if (snapshot.build_ok) GR else RD;
    try writer.print("  {s}Build:{s}   {s} {s}{d} бинарей{s}\n", .{
        CY, R, build_icon, build_color, snapshot.binaries, R,
    });
    try writer.print("  {s}Compile:{s} {d}/{d} ({d}%)\n", .{
        CY, R, snapshot.compile_pass, snapshot.compile_total, snapshot.compile_rate,
    });
    try writer.print("  {s}Git:{s}     {s} | {d} dirty\n", .{
        CY, R, snapshot.git_branch, snapshot.dirty_files,
    });
    try writer.print("  {s}Issues:{s}  {d} open\n", .{ CY, R, snapshot.open_issues });
    try writer.print("  {s}V:{s}       {s}{d:.3}{s} ({s})\n", .{
        CY, R, snapshot.v_zone.color(), snapshot.v_number, R, snapshot.v_zone.label(),
    });

    // Faculty table
    try writer.print("\n  {s}─── ФАКУЛЬТЕТ ───{s}\n", .{ G, R });
    for (snapshot.agents) |a| {
        try writer.print("  {s} {s}{s:<8}{s} {s}{s:<4}{s}", .{
            a.agent.emoji(),  R,                a.agent.name(), R,
            a.status.color(), a.status.label(), R,
        });
        // Voice
        var voice_buf: [256]u8 = undefined;
        const voice = voice_engine.generateVoice(a, snapshot, &voice_buf);
        try writer.print(" {s}{s}{s}\n", .{ GY, voice, R });
    }

    // Analysis
    try writer.print("\n  {s}─── АНАЛИЗ ───{s}\n", .{ G, R });
    var analysis_buf: [512]u8 = undefined;
    const analysis = analysis_engine.generateAnalysis(snapshot, &analysis_buf);
    try writer.print("  {s}\n", .{analysis});

    // Problems
    {
        var has_problems = false;
        if (!snapshot.build_ok) {
            if (!has_problems) {
                try writer.print("\n  {s}─── ПРОБЛЕМЫ ───{s}\n", .{ RD, R });
                has_problems = true;
            }
            try writer.print("  {s}🔥 Build сломан{s}\n", .{ RD, R });
        }
        if (snapshot.compile_rate < 80 and snapshot.compile_total > 0) {
            if (!has_problems) {
                try writer.print("\n  {s}─── ПРОБЛЕМЫ ───{s}\n", .{ RD, R });
                has_problems = true;
            }
            try writer.print("  {s}⚠️  Compile rate {d}% < 80%{s}\n", .{ RD, snapshot.compile_rate, R });
        }
        for (snapshot.agents) |a| {
            if (a.status == .down) {
                if (!has_problems) {
                    try writer.print("\n  {s}─── ПРОБЛЕМЫ ───{s}\n", .{ RD, R });
                    has_problems = true;
                }
                try writer.print("  {s}💀 {s} DOWN{s}\n", .{ RD, a.agent.name(), R });
            }
        }
        if (snapshot.dirty_files > 15) {
            if (!has_problems) {
                try writer.print("\n  {s}─── ПРОБЛЕМЫ ───{s}\n", .{ RD, R });
                has_problems = true;
            }
            try writer.print("  {s}📁 {d} dirty файлов{s}\n", .{ RD, snapshot.dirty_files, R });
        }
    }

    // Three paths
    try writer.print("\n  {s}─── ТРИ ПУТИ ───{s}\n", .{ G, R });
    var paths: [3]Path = undefined;
    three_paths.generatePaths(snapshot, &paths);
    for (paths) |p| {
        try writer.print("  {s} {s}{s}{s}: {s}\n", .{
            p.tier.emoji(), CY, p.label, R, p.action,
        });
    }

    // φ poetry footer
    try writer.print("\n  {s}", .{GY});
    var phi_buf: [256]u8 = undefined;
    const phi_line = phi_poetry.generatePhiLine(snapshot, &phi_buf);
    try writer.print("{s}", .{phi_line});
    try writer.print("{s}\n\n", .{R});
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

/// Run `tri faculty` command.
pub fn runFacultyCommand(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    const snapshot = try collectSnapshot(allocator);
    // Render to a buffer, then print via std.debug.print
    var buf: [8192]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    renderCompact(snapshot, stream.writer()) catch {
        std.debug.print("Faculty Board render error\n", .{});
        return;
    };
    std.debug.print("{s}", .{stream.getWritten()});
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
    const content = std.fs.cwd().readFileAlloc(allocator, "specs/REGENERATION_REPORT.md", 256 * 1024) catch
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
    const content = std.fs.cwd().readFileAlloc(allocator, ".trinity/mu/learning_db.json", 64 * 1024) catch
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

    var out_buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&out_buf);
    try renderCompact(snap, stream.writer());
    const output = stream.getWritten();
    try std.testing.expect(output.len > 100);
    try std.testing.expect(std.mem.indexOf(u8, output, "TRI") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "ФАКУЛЬТЕТ") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "АНАЛИЗ") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "ТРИ ПУТИ") != null);
}
