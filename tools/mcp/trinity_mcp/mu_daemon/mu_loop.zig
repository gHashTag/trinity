// mu_loop.zig — Core MU self-healing loop
// Each cycle: SCAN → LEARN → HEAL → VERIFY → HEARTBEAT → REPORT
const std = @import("std");
const mu_state = @import("mu_state.zig");
const telegram = @import("telegram");

pub const Config = struct {
    project_root: []const u8,
    sleep_interval_s: u64,
    max_wakes: u32,
    single_shot: bool,
    tg_config: telegram.TelegramConfig,
    report_issue: []const u8 = "", // GitHub issue number for progress reports
};

const CmdResult = struct {
    stdout: []const u8,
    exit_code: u8,
};

/// Run a tri subcommand in the project root directory.
/// Max 8 args supported (mu subcommands use 1-3).
/// Prepends `env AGENT_NAME=mu` so tri CLI logs the command source.
fn runTriCmd(allocator: std.mem.Allocator, project_root: []const u8, args: []const []const u8) CmdResult {
    // Build path to tri binary
    var bin_buf: [512]u8 = undefined;
    const tri_bin = std.fmt.bufPrint(&bin_buf, "{s}/zig-out/bin/tri", .{project_root}) catch
        return .{ .stdout = "", .exit_code = 1 };

    // Fixed-size argv: env AGENT_NAME=mu tri_bin + up to 16 args
    var argv_buf: [19][]const u8 = undefined;
    argv_buf[0] = "env";
    argv_buf[1] = "AGENT_NAME=mu";
    argv_buf[2] = tri_bin;
    const n = @min(args.len, 16);
    for (0..n) |i| {
        argv_buf[3 + i] = args[i];
    }

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv_buf[0 .. 3 + n],
        .cwd = project_root,
        .max_output_bytes = 64 * 1024,
    }) catch return .{ .stdout = "", .exit_code = 1 };

    allocator.free(result.stderr);

    const code: u8 = switch (result.term) {
        .Exited => |c| c,
        else => 1,
    };

    return .{ .stdout = result.stdout, .exit_code = code };
}

/// Run zig build in the project root to verify compilation.
fn runZigBuild(allocator: std.mem.Allocator, project_root: []const u8) bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "build" },
        .cwd = project_root,
        .max_output_bytes = 64 * 1024,
    }) catch return false;

    allocator.free(result.stdout);
    allocator.free(result.stderr);

    return switch (result.term) {
        .Exited => |c| c == 0,
        else => false,
    };
}

/// Write heartbeat JSON to .trinity/mu/heartbeat.json
fn writeHeartbeat(
    allocator: std.mem.Allocator,
    project_root: []const u8,
    wake: u32,
    errors_scanned: u32,
    fixes_applied: u32,
    build_ok: bool,
    test_ok: bool,
) void {
    var path_buf: [512]u8 = undefined;
    const dir_path = std.fmt.bufPrint(&path_buf, "{s}/.trinity/mu", .{project_root}) catch return;
    std.fs.cwd().makePath(dir_path) catch |err| {
        std.log.debug("mu_loop: failed to create heartbeat dir: {}", .{err});
    };

    var file_buf: [512]u8 = undefined;
    const file_path = std.fmt.bufPrint(&file_buf, "{s}/.trinity/mu/heartbeat.json", .{project_root}) catch return;

    const ts_raw = std.time.timestamp();
    const timestamp: u64 = if (ts_raw >= 0) @intCast(ts_raw) else 0;
    const json = std.fmt.allocPrint(
        allocator,
        "{{\"agent\":\"mu\",\"wake\":{d},\"timestamp\":{d},\"errors_scanned\":{d},\"fixes_applied\":{d},\"build_ok\":{s},\"test_ok\":{s}}}",
        .{ wake, timestamp, errors_scanned, fixes_applied, if (build_ok) "true" else "false", if (test_ok) "true" else "false" },
    ) catch return;
    defer allocator.free(json);

    const file = std.fs.cwd().createFile(file_path, .{}) catch return;
    defer file.close();
    file.writeAll(json) catch |err| {
        std.log.warn("mu_loop: failed to write heartbeat: {}", .{err});
    };
}

/// Parse a number from the first line of tri command output.
fn parseCount(allocator: std.mem.Allocator, stdout: []const u8) u32 {
    _ = allocator;
    // Look for a number at the start or after common prefixes
    var iter = std.mem.tokenizeAny(u8, stdout, " \t\n:=");
    while (iter.next()) |tok| {
        if (std.fmt.parseInt(u32, tok, 10)) |n| return n else |_| continue;
    }
    return 0;
}

/// Read errors_scanned directly from .trinity/mu/learning_db.json
/// This bypasses the unreliable `tri mu stats` table parsing.
fn readErrorsFromDb(allocator: std.mem.Allocator, project_root: []const u8) u32 {
    var path_buf: [512]u8 = undefined;
    const db_path = std.fmt.bufPrint(&path_buf, "{s}/.trinity/mu/learning_db.json", .{project_root}) catch return 0;

    const file = std.fs.cwd().openFile(db_path, .{}) catch return 0;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 64 * 1024) catch return 0;
    defer allocator.free(content);

    // Find "total_errors_scanned": N
    const key = "\"total_errors_scanned\":";
    const idx = std.mem.indexOf(u8, content, key) orelse return 0;
    const after = content[idx + key.len ..];

    // Skip whitespace then parse the number
    var start: usize = 0;
    while (start < after.len and (after[start] == ' ' or after[start] == '\t')) : (start += 1) {}

    var end: usize = start;
    while (end < after.len and after[end] >= '0' and after[end] <= '9') : (end += 1) {}

    if (end == start) return 0;
    return std.fmt.parseInt(u32, after[start..end], 10) catch 0;
}

/// Report cycle results to GitHub issue via `tri issue comment`.
fn reportToIssue(
    allocator: std.mem.Allocator,
    project_root: []const u8,
    issue_num: []const u8,
    wake: u32,
    errors_scanned: u32,
    fixes_applied: u32,
    build_ok: bool,
    test_ok: bool,
) void {
    if (issue_num.len == 0) return;

    var result_buf: [256]u8 = undefined;
    const result_text = std.fmt.bufPrint(&result_buf, "Wake #{d}: scanned {d} errors, fixed {d}. Build {s}, Test {s}", .{
        wake,
        errors_scanned,
        fixes_applied,
        if (build_ok) "OK" else "FAIL",
        if (test_ok) "PASS" else "FAIL",
    }) catch return;

    const next_text: []const u8 = if (fixes_applied > 0 and !build_ok)
        "Build broken after fix — rollback needed"
    else if (fixes_applied > 0)
        "Fixes applied, monitoring next cycle"
    else
        "No matching patterns — waiting for new data";

    const r = runTriCmd(allocator, project_root, &.{
        "issue",    "comment",   issue_num,
        "--agent",  "mu",        "--step",
        "HEAL",     "--status",  "DONE",
        "--result", result_text, "--next",
        next_text,
    });
    allocator.free(r.stdout);
}

pub fn run(allocator: std.mem.Allocator, config: Config) !void {
    var state = try mu_state.State.init(allocator, config.project_root);
    defer state.deinit();

    while (true) {
        const wake = try state.incrementWakeCount();
        std.debug.print("[mu-agent] Wake #{d}\n", .{wake});

        // 1. SCAN: read error count from learning_db.json (direct file read)
        // tri mu stats outputs a table that parseCount() can't parse reliably.
        // Reading the DB file directly gives us the real total_errors_scanned.
        const stats_result = runTriCmd(allocator, config.project_root, &.{ "mu", "stats" });
        allocator.free(stats_result.stdout);
        const errors_scanned = readErrorsFromDb(allocator, config.project_root);
        std.debug.print("[mu-agent] Scanned errors: {d}\n", .{errors_scanned});

        // Telegram: after SCAN
        {
            var scan_buf: [256]u8 = undefined;
            telegram.sendFmt(config.tg_config, &scan_buf, "\xf0\x9f\xa7\xa0 TRI     Wake #{d}. {d} \xd0\xbe\xd1\x88\xd0\xb8\xd0\xb1\xd0\xbe\xd0\xba.", .{ wake, errors_scanned });
        }

        // 2. LEARN: tri mu learn → update pattern DB
        const learn_result = runTriCmd(allocator, config.project_root, &.{ "mu", "learn" });
        allocator.free(learn_result.stdout);
        std.debug.print("[mu-agent] Learn: exit={d}\n", .{learn_result.exit_code});

        // 3. HEAL: tri mu fix --all → apply known fixes
        const fix_result = runTriCmd(allocator, config.project_root, &.{ "mu", "fix", "--all" });
        const fixes_applied = parseCount(allocator, fix_result.stdout);
        allocator.free(fix_result.stdout);
        std.debug.print("[mu-agent] Fixes applied: {d}\n", .{fixes_applied});

        // Telegram: after HEAL (only if fixes > 0)
        if (fixes_applied > 0) {
            var heal_buf: [256]u8 = undefined;
            telegram.sendFmt(config.tg_config, &heal_buf, "\xf0\x9f\xa7\xa0 TRI     tri mu fix \xe2\x86\x92 {d} healed", .{fixes_applied});
        }

        // 3.5 TEST: tri test → verify tests pass after fix
        const test_result = runTriCmd(allocator, config.project_root, &.{"test"});
        const test_ok = test_result.exit_code == 0;
        allocator.free(test_result.stdout);
        std.debug.print("[mu-agent] Test: {s}\n", .{if (test_ok) "PASS" else "FAIL"});

        // Telegram: test result (only if fixes were applied)
        if (fixes_applied > 0) {
            var test_buf: [256]u8 = undefined;
            const test_icon: []const u8 = if (test_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c";
            telegram.sendFmt(config.tg_config, &test_buf, "\xf0\x9f\xa7\xa0 TRI     tri test {s}", .{test_icon});
        }

        // 4. VERIFY: zig build → check compilation
        const build_ok = runZigBuild(allocator, config.project_root);
        std.debug.print("[mu-agent] Build: {s}\n", .{if (build_ok) "OK" else "FAIL"});

        // 5. HEARTBEAT
        writeHeartbeat(allocator, config.project_root, wake, errors_scanned, fixes_applied, build_ok, test_ok);
        std.debug.print("[mu-agent] Heartbeat written\n", .{});

        // 5.5. REPORT TO GITHUB ISSUE (Protocol v2)
        reportToIssue(allocator, config.project_root, config.report_issue, wake, errors_scanned, fixes_applied, build_ok, test_ok);

        // 6. REPORT via Telegram — final summary
        {
            var msg_buf: [256]u8 = undefined;
            const build_icon: []const u8 = if (build_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c";
            const test_icon: []const u8 = if (test_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c";
            telegram.sendFmt(config.tg_config, &msg_buf, "\xf0\x9f\xa7\xa0 TRI     Build {s} Test {s}. \xf0\x9f\x98\xb4 {d}\xd0\xbc\xd0\xb8\xd0\xbd.", .{ build_icon, test_icon, config.sleep_interval_s / 60 });
        }

        if (config.single_shot) break;
        if (config.max_wakes > 0 and wake >= config.max_wakes) break;

        std.debug.print("[mu-agent] Sleeping {d}s...\n", .{config.sleep_interval_s});
        std.Thread.sleep(config.sleep_interval_s * std.time.ns_per_s);
    }

    std.debug.print("[mu-agent] Done.\n", .{});
}
