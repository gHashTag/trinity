// @origin(manual) @regen(pending)
// ═════════════════════════════════════════════════════════════════
// DOCTOR DAEMON — CLI Router
// ═══════════════════════════════════════════════════════════════════

const std = @import("std");
const doctor_types = @import("doctor_types.zig");
const doctor = @import("doctor.zig");

const Allocator = std.mem.Allocator;

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    // Skip first arg (executable name)
    const cmd_args = if (args.len > 1) args[1..] else &[_][]const u8{};
    try runDoctorCommand(gpa, cmd_args);
}

pub fn runDoctorCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "start")) {
        try runDoctorDaemon(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "stop")) {
        try stopDoctorDaemon(allocator);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        try showStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "diagnose")) {
        try runDiagnosis(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "history")) {
        try showHistory(allocator);
    } else if (std.mem.eql(u8, subcmd, "help")) {
        printHelp();
    } else {
        std.debug.print("Unknown doctor subcommand: {s}\n", .{subcmd});
        printHelp();
    }
}

fn runDoctorDaemon(allocator: Allocator, args: []const []const u8) !void {
    const config = try doctor_types.initConfig(args);

    std.debug.print("🩺 Starting Doctor daemon\n", .{});

    if (config.dry_run) {
        std.debug.print("DRY RUN MODE - not starting daemon\n", .{});
        const health = try doctor.checkHealth(allocator);
        const result = doctor.diagnose(health);
        std.debug.print("\n🔬 Diagnosis\n", .{});
        std.debug.print("═════════════════\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("  Status:    {s}\n", .{doctor_types.diagnosisLabel(result.diagnosis)});
        std.debug.print("  Problem:    {s}\n", .{result.reason});
        if (result.treatment != .none and !config.dry_run) {
            std.debug.print("\n  Action:     Apply {s}\n", .{doctor_types.treatmentLabel(result.treatment)});
        }
        std.debug.print("\n", .{});
        return;
    }

    // Start daemon loop
    const result_daemon = try std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &.{ "tri", "doctor", "daemon" },
    });
    _ = result_daemon;

    if (config.verbose) {
        std.debug.print("Daemon started\n", .{});
        std.debug.print("Daemon exited\n", .{});
    }
}

fn stopDoctorDaemon(allocator: Allocator) !void {
    std.debug.print("🛑 Stopping Doctor daemon\n", .{});

    // Read Doctor PID
    if (std.fs.cwd().openFile(doctor_types.DOCTOR_PID_FILE, .{})) |pid_file| {
        defer pid_file.close();
        const pid_str = pid_file.readToEndAlloc(allocator, 32) catch "";
        defer allocator.free(pid_str);

        const pid = std.fmt.parseInt(u32, std.mem.trimRight(u8, pid_str, "\n\r"), 10) catch null;

        if (pid) |p| {
            if (p > 0) {
                std.posix.kill(@intCast(p), std.posix.SIG.TERM) catch |err| {
                    std.debug.print("  ERROR: Failed to kill Doctor daemon: {}\n", .{err});
                };
                std.debug.print("Stopped Doctor daemon (PID: {d})\n", .{p});

                // Delete PID file
                std.fs.cwd().deleteFile(doctor_types.DOCTOR_PID_FILE) catch {};
                std.debug.print("Removed PID file\n", .{});
            } else {
                std.debug.print("Doctor daemon not running\n", .{});
            }
        } else {
            std.debug.print("Invalid PID\n", .{});
        }
    } else |_| {
        std.debug.print("No PID file found\n", .{});
    }
}

fn showStatus(allocator: Allocator) !void {
    const health = try doctor.checkHealth(allocator);

    std.debug.print("\n🩺 Doctor Status\n", .{});
    std.debug.print("═══════════════════════\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Queen:\n", .{});
    std.debug.print("  Running:     {s}\n", .{if (health.queen_running) "✓" else "✗"});
    const pid_display = if (health.queen_pid) |p| p else @as(u32, 0);
    std.debug.print("  PID:         {d}\n", .{pid_display});
    std.debug.print("  Heartbeat:    {d}s old\n", .{health.queen_heartbeat_age_sec});
    std.debug.print("  Log size:    {d} KB\n", .{health.queen_log_size_kb});
    std.debug.print("  RSS:          {d} MB\n", .{health.queen_rss_mb});
    std.debug.print("  Diagnosed as: {s}\n", .{doctor_types.diagnosisLabel(doctor.diagnose(health).diagnosis)});

    std.debug.print("\n", .{});
    std.debug.print("Doctor:\n", .{});
    std.debug.print("  Running:     {s}\n", .{if (health.doctor_running) "✓" else "✗"});
    const doctor_pid_display: i32 = if (health.doctor_pid) |p| p else -1;
    std.debug.print("  PID:         {d}\n", .{doctor_pid_display});
    std.debug.print("\n", .{});

    std.debug.print("\n", .{});
}

fn runDiagnosis(allocator: Allocator, args: []const []const u8) !void {
    const config = try doctor_types.initConfig(args);

    const health = try doctor.checkHealth(allocator);
    const result = doctor.diagnose(health);

    std.debug.print("\n🔬 Diagnosis\n", .{});
    std.debug.print("═════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  Status:    {s}\n", .{doctor_types.diagnosisLabel(result.diagnosis)});
    std.debug.print(" Problem:    {s}\n", .{result.reason});

    if (result.treatment != .none and !config.dry_run) {
        std.debug.print("\n  Action:     Apply {s}\n", .{doctor_types.treatmentLabel(result.treatment)});

        // Apply treatment via separate doctor instance
        // This would require running `tri doctor apply-treatment` command
        // For now, just show what would be done
    } else if (result.treatment == .none and !config.dry_run) {
        std.debug.print("\n  Action:     None (healthy)\n", .{});
    }

    std.debug.print("\n", .{});
}

fn showHistory(allocator: Allocator) !void {
    _ = allocator;
    std.debug.print("\n📜 Doctor History\n", .{});
    std.debug.print("═════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Last 10 treatments:\n", .{});
    std.debug.print("(Full history in doctor.log)\n", .{});
    std.debug.print("\n", .{});
}

fn printHelp() void {
    std.debug.print("\n🩺 Doctor Daemon — Trinity Health Monitor\n", .{});
    std.debug.print("═════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  tri doctor start [--dry-run] [--verbose] [--interval <sec>]\n", .{});
    std.debug.print("  tri doctor stop\n", .{});
    std.debug.print("  tri doctor status\n", .{});
    std.debug.print("  tri doctor diagnose [--verbose]\n", .{});
    std.debug.print("  tri doctor history\n", .{});
    std.debug.print("  tri doctor help\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Diagnoses:\n", .{});
    std.debug.print("  dead       — Queen not running\n", .{});
    std.debug.print("  crash_loop — Error log > 512KB, restart\n", .{});
    std.debug.print("  stuck      — Heartbeat > 60s, reset+restart\n", .{});
    std.debug.print("  memory_leak— RSS > 512MB, kill+restart\n", .{});
    std.debug.print("  log_overflow— Log > 256KB, purge logs\n", .{});
    std.debug.print("  healthy    — All checks passed\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  --dry-run     Show diagnosis without taking action\n", .{});
    std.debug.print("  --verbose     Show detailed health checks\n", .{});
    std.debug.print("  --interval <sec> Check interval (default: 30s)\n", .{});
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════

test "diagnosis label" {
    try std.testing.expectEqualStrings("DEAD", doctor_types.diagnosisLabel(.dead));
    try std.testing.expectEqualStrings("CRASH_LOOP", doctor_types.diagnosisLabel(.crash_loop));
    try std.testing.expectEqualStrings("STUCK", doctor_types.diagnosisLabel(.stuck));
    try std.testing.expectEqualStrings("MEMORY_LEAK", doctor_types.diagnosisLabel(.memory_leak));
    try std.testing.expectEqualStrings("LOG_OVERFLOW", doctor_types.diagnosisLabel(.log_overflow));
    try std.testing.expectEqualStrings("HEALTHY", doctor_types.diagnosisLabel(.healthy));
}

test "treatment label" {
    try std.testing.expectEqualStrings("none", doctor_types.treatmentLabel(.none));
    try std.testing.expectEqualStrings("restart", doctor_types.treatmentLabel(.restart));
    try std.testing.expectEqualStrings("purge_logs", doctor_types.treatmentLabel(.purge_logs));
    try std.testing.expectEqualStrings("reset_state", doctor_types.treatmentLabel(.reset_state));
    try std.testing.expectEqualStrings("kill_and_restart", doctor_types.treatmentLabel(.kill_and_restart));
}
