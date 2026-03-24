// @origin(manual) @regen(pending)
// ═════════════════════════════════════════════════════════════════
// DOCTOR DAEMON — Types and Constants
// ═════════════════════════════════════════════════════════════════

const std = @import("std");

// ═════════════════════════════════════════════════════════
// PATHS
// ═══════════════════════════════════════════════════════════════════

pub const QUEEN_PID_FILE = ".trinity/queen/supervisor.pid";
pub const DOCTOR_PID_FILE = ".trinity/doctor/doctor.pid";
pub const QUEEN_HEARTBEAT = ".trinity/queen/heartbeat";
pub const DOCTOR_LOG = ".trinity/doctor/doctor.log";
pub const QUEEN_ERR_LOG = ".trinity/queen/launcher.err";

// ═══════════════════════════════════════════════════════════════
// DIAGNOSIS
// ═════════════════════════════════════════════════════════════════════

pub const Diagnosis = enum {
    dead,
    crash_loop,
    stuck,
    memory_leak,
    log_overflow,
    healthy,
};

pub const Treatment = enum {
    none,
    restart,
    purge_logs,
    reset_state,
    kill_and_restart,
};

// ═════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═════════════════════════════════════════════════════════════════════════

pub const CHECK_INTERVAL_SEC: u64 = 30;  // Check every 30s
pub const STUCK_THRESHOLD_SEC: u64 = 60;  // Heartbeat > 60s = stuck
pub const MEMORY_LEAK_THRESHOLD_MB: u64 = 512;  // RSS > 512MB
pub const LOG_OVERFLOW_THRESHOLD_KB: u64 = 512;  // Log > 512KB

pub const DoctorConfig = struct {
    interval_sec: u64 = CHECK_INTERVAL_SEC,
    dry_run: bool = false,
    verbose: bool = false,
};

pub const DiagnosisResult = struct {
    diagnosis: Diagnosis,
    treatment: Treatment,
    reason: []const u8,
};

pub const SystemHealth = struct {
    queen_running: bool = false,
    queen_pid: ?i32 = null,
    queen_heartbeat_age_sec: u64 = 0,
    queen_log_size_kb: u64 = 0,
    queen_rss_mb: u64 = 0,
    doctor_running: bool = false,
    doctor_pid: ?i32 = null,
    timestamp_ms: u64 = 0,
};

pub fn initConfig(args: []const []const u8) !DoctorConfig {
    var config = DoctorConfig{};
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--dry-run")) {
            config.dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--verbose") or std.mem.eql(u8, args[i], "-v")) {
            config.verbose = true;
        } else if (std.mem.eql(u8, args[i], "--interval")) {
            i += 1;
            if (i < args.len) {
                config.interval_sec = std.fmt.parseInt(u64, args[i], 10) catch CHECK_INTERVAL_SEC;
            }
        }
    }
    return config;
}

pub fn diagnosisLabel(diagnosis: Diagnosis) []const u8 {
    return switch (diagnosis) {
        .dead => "DEAD",
        .crash_loop => "CRASH_LOOP",
        .stuck => "STUCK",
        .memory_leak => "MEMORY_LEAK",
        .log_overflow => "LOG_OVERFLOW",
        .healthy => "HEALTHY",
    };
}

pub fn treatmentLabel(treatment: Treatment) []const u8 {
    return switch (treatment) {
        .none => "none",
        .restart => "restart",
        .purge_logs => "purge_logs",
        .reset_state => "reset_state",
        .kill_and_restart => "kill_and_restart",
    };
}
