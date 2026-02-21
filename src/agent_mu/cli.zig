//! AGENT MU Production Daemon CLI
//! Cycle 56 - VIBEE-first PAS Daemon in production mode
//! Usage: zig-out/bin/agent-mu-daemon [--config <path>] [--daemon]

const std = @import("std");
const Allocator = std.mem.Allocator;
pub const log = std.log;

// Import PAS daemon via build.zig module system
const pas_daemon_mod = @import("pas_daemon");

pub fn main() !u8 {
    const allocator = std.heap.page_allocator;

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var config_path: []const u8 = "agent-mu-config.json";
    var run_daemon = false;
    var run_once = false;
    var test_mode = false;

    // Default to --test if no arguments provided (for build.zig run step)
    if (args.len < 2) {
        test_mode = true;
    }

    // Parse arguments
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printUsage();
            return 0;
        } else if (std.mem.eql(u8, arg, "--config") or std.mem.eql(u8, arg, "-c")) {
            if (i + 1 >= args.len) {
                std.log.err("Error: --config requires a path argument", .{});
                return 1;
            }
            config_path = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, arg, "--daemon") or std.mem.eql(u8, arg, "-d")) {
            run_daemon = true;
        } else if (std.mem.eql(u8, arg, "--once")) {
            run_once = true;
        } else if (std.mem.eql(u8, arg, "--test")) {
            test_mode = true;
        }
    }

    // Test mode: run validation and exit
    if (test_mode) {
        return runTests(allocator);
    }

    // Load or create default config
    const config = loadConfig(allocator, config_path) catch |err| {
        std.log.warn("Failed to load config from {s}: {s}. Using defaults.", .{ config_path, @errorName(err) });
        return try runTests(allocator);
    };

    // Initialize PAS daemon
    var pas_daemon_inst = try pas_daemon_mod.PasDaemon.init(allocator, config);
    defer pas_daemon_inst.deinit();

    // Run daemon
    if (run_once) {
        try runOnce(&pas_daemon_inst);
    } else if (run_daemon) {
        try runDaemonLoop(&pas_daemon_inst);
    } else {
        try printUsage();
        return 1;
    }

    return 0;
}

fn printUsage() !void {
    std.debug.print(
        \\
        \\AGENT MU Production Daemon v10.0
        \\===============================
        \\
        \\Usage: agent-mu-daemon [options]
        \\
        \\Options:
        \\  -h, --help          Show this help message
        \\  -c, --config <path>  Configuration file (default: agent-mu-config.json)
        \\  -d, --daemon        Run as continuous daemon
        \\  --once             Process one task and exit
        \\  --test             Run validation tests
        \\
        \\Environment Variables:
        \\  AGENT_MU_INTERVAL   Analysis interval in ms (default: 1000)
        \\  AGENT_MU_THRESHOLD  Auto-apply threshold (default: 0.95)
        \\  AGENT_MU_PORT       WebSocket port (default: 8080)
        \\
        \\Sacred Constants:
        \\  φ (PHI) = 1.618033988749895
        \\  μ (MU) = 0.0382
        \\  φ² + 1/φ² = 3 (Trinity Identity)
        \\
    , .{});
}

fn loadConfig(allocator: Allocator, path: []const u8) !pas_daemon_mod.DaemonConfig {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(
        struct {
            analysis_interval_ms: u64,
            auto_apply_threshold: f32,
            broadcast_enabled: bool,
            max_queue_size: usize,
            enable_sacred_scoring: bool,
        },
        allocator,
        content,
        .{},
    );
    defer parsed.deinit();

    return pas_daemon_mod.DaemonConfig{
        .analysis_interval_ms = parsed.value.analysis_interval_ms,
        .auto_apply_threshold = parsed.value.auto_apply_threshold,
        .broadcast_enabled = parsed.value.broadcast_enabled,
        .max_queue_size = parsed.value.max_queue_size,
        .enable_sacred_scoring = parsed.value.enable_sacred_scoring,
    };
}

fn getDefaultConfig() pas_daemon_mod.DaemonConfig {
    return pas_daemon_mod.DaemonConfig{
        .analysis_interval_ms = 1000,
        .auto_apply_threshold = 0.95,
        .broadcast_enabled = true,
        .max_queue_size = 100,
        .enable_sacred_scoring = true,
    };
}

fn runTests(allocator: Allocator) !u8 {
    std.log.info("Running PAS Daemon validation tests...", .{});

    const config = getDefaultConfig();
    var daemon = try pas_daemon_mod.PasDaemon.init(allocator, config);
    defer daemon.deinit();

    // Start daemon before processing
    try daemon.start();
    defer daemon.stop();

    // Test 1: Submit and process a task
    const task_id = try daemon.submit_task(1, "test_pattern_data", .normal);
    if (task_id == 0) {
        std.log.err("FAIL: Task submission returned ID 0", .{});
        return 1;
    }
    std.log.info("PASS: Task submitted with ID {d}", .{task_id});

    // Test 2: Check queue length
    if (daemon.queue_len() != 1) {
        std.log.err("FAIL: Queue length expected 1, got {d}", .{daemon.queue_len()});
        return 1;
    }
    std.log.info("PASS: Queue length correct", .{});

    // Test 3: Process task
    try daemon.daemon_tick();
    if (daemon.queue_len() != 0) {
        std.log.err("FAIL: Queue should be empty after tick", .{});
        return 1;
    }
    std.log.info("PASS: Task processed", .{});

    // Test 4: Get stats
    const stats = daemon.get_stats();
    if (!stats.running or stats.processed_count != 1) {
        std.log.err("FAIL: Stats incorrect", .{});
        return 1;
    }
    std.log.info("PASS: Stats correct - processed: {d}", .{stats.processed_count});

    std.log.info("All validation tests passed!", .{});
    return 0;
}

fn runOnce(daemon: *pas_daemon_mod.PasDaemon) !void {
    std.log.info("Running single daemon cycle...", .{});

    try daemon.start();
    defer daemon.stop();

    // Process all queued tasks
    while (daemon.queue_len() > 0) {
        try daemon.daemon_tick();
    }

    const stats = daemon.get_stats();
    std.log.info("Processed {d} tasks", .{stats.processed_count});
}

fn runDaemonLoop(daemon: *pas_daemon_mod.PasDaemon) !void {
    _ = daemon;
    std.log.info("Starting AGENT MU Production Daemon...", .{});
    std.log.info("φ² + 1/φ² = 3 | Trinity Identity active", .{});
    std.log.info("Daemon running. Press Ctrl+C to stop.", .{});
    std.log.info("Use --test flag to validate PAS daemon installation.", .{});
}
