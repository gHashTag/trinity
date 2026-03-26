// @origin(manual) @regen(pending)
// ═════════════════════════════════════════════════════════════════
// DOCTOR DAEMON — Core Logic
// ═════════════════════════════════════════════════════════════════

const std = @import("std");
const fs = std.fs;
const doctor_types = @import("doctor_types.zig");

pub const Diagnosis = doctor_types.Diagnosis;
pub const Treatment = doctor_types.Treatment;
pub const SystemHealth = doctor_types.SystemHealth;
pub const DiagnosisResult = doctor_types.DiagnosisResult;
pub const DoctorConfig = doctor_types.DoctorConfig;

const QUEEN_PID_FILE = doctor_types.QUEEN_PID_FILE;
const DOCTOR_PID_FILE = doctor_types.DOCTOR_PID_FILE;
const QUEEN_HEARTBEAT = doctor_types.QUEEN_HEARTBEAT;
const DOCTOR_LOG = doctor_types.DOCTOR_LOG;
const QUEEN_ERR_LOG = doctor_types.QUEEN_ERR_LOG;

const STUCK_THRESHOLD_SEC = doctor_types.STUCK_THRESHOLD_SEC;
const MEMORY_LEAK_THRESHOLD_MB = doctor_types.MEMORY_LEAK_THRESHOLD_MB;
const LOG_OVERFLOW_THRESHOLD_KB = doctor_types.LOG_OVERFLOW_THRESHOLD_KB;

const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════
// HEALTH CHECK
// ═══════════════════════════════════════════════════════════════════════════

pub fn checkHealth(allocator: Allocator) !SystemHealth {
    var health = SystemHealth{
        .timestamp_ms = @intCast(std.time.milliTimestamp()),
    };

    // Check Queen PID
    if (fs.cwd().openFile(QUEEN_PID_FILE, .{})) |pid_file| {
        defer pid_file.close();
        const pid_str = pid_file.readToEndAlloc(allocator, 32) catch "";
        defer allocator.free(pid_str);

        if (std.fmt.parseInt(i32, std.mem.trimRight(u8, pid_str, "\n\r"), 10)) |pid| {
            health.queen_pid = pid;
            health.queen_running = isPidAlive(pid);
        } else |_| {}
    } else |_| {}

    // Check Doctor PID
    if (fs.cwd().openFile(DOCTOR_PID_FILE, .{})) |pid_file| {
        defer pid_file.close();
        const pid_str = pid_file.readToEndAlloc(allocator, 32) catch "";
        defer allocator.free(pid_str);

        if (std.fmt.parseInt(i32, std.mem.trimRight(u8, pid_str, "\n\r"), 10)) |pid| {
            health.doctor_pid = pid;
            health.doctor_running = isPidAlive(pid);
        } else |_| {}
    } else |_| {}

    // Check Queen heartbeat
    if (fs.cwd().openFile(QUEEN_HEARTBEAT, .{})) |hb_file| {
        defer hb_file.close();
        const hb_str = hb_file.readToEndAlloc(allocator, 32) catch "";
        defer allocator.free(hb_str);

        if (std.fmt.parseInt(i64, std.mem.trimRight(u8, hb_str, "\n\r"), 10)) |hb_ms| {
            const now_ms = std.time.milliTimestamp();
            const age_ms = if (now_ms > hb_ms) now_ms - hb_ms else 0;
            health.queen_heartbeat_age_sec = @intCast(@divTrunc(age_ms, 1000));
        } else |_| {}
    } else |_| {}

    // Check Queen log size
    if (fs.cwd().statFile(QUEEN_ERR_LOG)) |stat| {
        health.queen_log_size_kb = @intCast(stat.size / 1024);
    } else |_| {}

    // Get Queen RSS if running
    if (health.queen_running) {
        if (health.queen_pid) |pid| {
            health.queen_rss_mb = getProcessRssMb(pid);
        }
    }

    return health;
}

pub fn diagnose(health: SystemHealth) DiagnosisResult {
    // Priority order: dead > crash_loop > stuck > memory_leak > log_overflow > healthy

    // 0. NEW: Check heartbeat file exists (Queen is DEAD if no heartbeat)
    const heartbeat_exists = fs.cwd().openFile(QUEEN_HEARTBEAT, .{}) catch null;
    if (heartbeat_exists == null) {
        return .{
            .diagnosis = .dead,
            .treatment = .restart,
            .reason = "Queen heartbeat file missing",
        };
    }

    // 1. Check if Queen is dead
    if (!health.queen_running) {
        return .{
            .diagnosis = .dead,
            .treatment = .restart,
            .reason = "Queen PID not running",
        };
    }

    // 2. Check for crash loop (large error log)
    if (health.queen_log_size_kb > LOG_OVERFLOW_THRESHOLD_KB) {
        return .{
            .diagnosis = .crash_loop,
            .treatment = .purge_logs,
            .reason = "Error log too large",
        };
    }

    // 3. Check for stuck (old heartbeat)
    if (health.queen_heartbeat_age_sec > STUCK_THRESHOLD_SEC) {
        return .{
            .diagnosis = .stuck,
            .treatment = .kill_and_restart,
            .reason = "Heartbeat too old",
        };
    }

    // 4. Check for memory leak
    if (health.queen_rss_mb > MEMORY_LEAK_THRESHOLD_MB) {
        return .{
            .diagnosis = .memory_leak,
            .treatment = .kill_and_restart,
            .reason = "Memory too high",
        };
    }

    // 5. Check for log overflow
    if (health.queen_log_size_kb > LOG_OVERFLOW_THRESHOLD_KB / 2) {
        return .{
            .diagnosis = .log_overflow,
            .treatment = .purge_logs,
            .reason = "Log growing large",
        };
    }

    return .{
        .diagnosis = .healthy,
        .treatment = .none,
        .reason = "All checks passed",
    };
}

pub fn applyTreatment(allocator: Allocator, result: DiagnosisResult, dry_run: bool) !void {
    if (result.treatment == .none) return;

    const log_file = try std.fs.cwd().createFile(DOCTOR_LOG, .{ .append = true });
    defer log_file.close();

    const writer = log_file.writer();
    const timestamp = std.time.timestamp();
    try writer.print("{d} DIAGNOSIS: {s} TREATMENT: {s} REASON: {s}\n", .{
        timestamp,
        doctor_types.diagnosisLabel(result.diagnosis),
        doctor_types.treatmentLabel(result.treatment),
        result.reason,
    });

    if (dry_run) {
        try writer.print("{d} DRY-RUN: Would apply {s}\n", .{ timestamp, doctor_types.treatmentLabel(result.treatment) });
        return;
    }

    switch (result.treatment) {
        .none => {},
        .restart => try restartQueen(allocator, writer, timestamp),
        .purge_logs => try purgeQueenLogs(writer, timestamp),
        .purge_logs_and_restart => {
            try purgeQueenLogs(writer, timestamp);
            try restartQueen(allocator, writer, timestamp);
        },
        .reset_state_and_restart => {
            try resetQueenState(writer, timestamp);
            try restartQueen(allocator, writer, timestamp);
        },
        .kill_and_restart => {
            try killQueen(writer, timestamp);
            try restartQueen(allocator, writer, timestamp);
        },
    }

    try writer.print("{d} TREATMENT_APPLIED: {s}\n", .{ timestamp, doctor_types.treatmentLabel(result.treatment) });
}

fn restartQueen(allocator: Allocator, writer: anytype, timestamp: i64) !void {
    _ = allocator;
    try writer.print("{d} TREATMENT: Restarting Queen\n", .{timestamp});

    // Run: tri queen start --daemon
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &.{ "tri", "queen", "start", "--daemon" },
    }) catch |err| {
        try writer.print("{d} ERROR: Failed to start Queen: {}\n", .{ timestamp, err });
        return;
    };
    defer {
        std.heap.page_allocator.free(result.stdout);
        std.heap.page_allocator.free(result.stderr);
    }
}

fn purgeQueenLogs(writer: anytype, timestamp: i64) !void {
    try writer.print("{d} TREATMENT: Purging Queen logs\n", .{timestamp});

    // Clear error log
    if (fs.cwd().createFile(QUEEN_ERR_LOG, .{})) |file| {
        file.close();
    } else |_| {}
}

fn resetQueenState(writer: anytype, timestamp: i64) !void {
    try writer.print("{d} TREATMENT: Resetting Queen state\n", .{timestamp});

    // Reset heartbeat
    if (fs.cwd().deleteFile(QUEEN_HEARTBEAT)) |_| {} else |_| {}
}

fn killQueen(writer: anytype, timestamp: i64) !void {
    try writer.print("{d} TREATMENT: Killing Queen\n", .{timestamp});

    // Read PID
    const pid_str = fs.cwd().readFileAlloc(std.heap.page_allocator, QUEEN_PID_FILE, 32) catch "";
    defer std.heap.page_allocator.free(pid_str);

    const pid = std.fmt.parseInt(u32, std.mem.trimRight(u8, pid_str, "\n\r"), 10) catch return;

    // Kill process
    std.posix.kill(@intCast(pid), std.posix.SIG.TERM) catch |err| {
        try writer.print("{d} ERROR: Failed to kill Queen: {}\n", .{ timestamp, err });
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

fn isPidAlive(pid: i32) bool {
    // Use kill(pid, 0) to check if process exists
    // Returns ProcessNotFound if PID doesn't exist
    std.posix.kill(@intCast(pid), 0) catch return false;
    return true;
}

fn getProcessRssMb(pid: i32) u64 {
    _ = pid;
    // TODO: Implement RSS reading from /proc or ps
    // For now, return 0
    return 0;
}
