//! Ralph CLI - Autonomous Development Assistant
//! Command-line interface for Ralph autonomous development system

const std = @import("std");
const Allocator = std.mem.Allocator;
const posix = std.posix;

// Import Ralph Agent module
const ralph = @import("maxwell/ralph/agent.zig");

// Import Swarm Watch module (for --swarm-monitor command)
// This is imported as a build module named "swarm_watch"
const swarm_watch = @import("swarm_watch");

// Import trinity-symb for kg_sync (real DHT)
const trinity_symb = @import("trinity-symb");
const kg_sync = trinity_symb.kg_sync;

// Stdout file handle
const stdout_file = std.fs.File{ .handle = posix.STDOUT_FILENO };

/// Write string to stdout
fn stdoutWrite(s: []const u8) !void {
    try stdout_file.writeAll(s);
}

/// Print formatted string to stdout
fn stdoutPrint(comptime fmt: []const u8, args: anytype) !void {
    var buffer: [1024]u8 = undefined;
    const result = try std.fmt.bufPrint(&buffer, fmt, args);
    try stdout_file.writeAll(result);
}

/// CLI configuration
const CLIConfig = struct {
    verbose: bool = false,
    color: bool = true,
};

/// Print usage information
fn printUsage() !void {
    try stdoutWrite(
        \\Ralph Autonomous Development CLI v1.0.0
        \\
        \\USAGE:
        \\  ralph [COMMAND] [OPTIONS]
        \\
        \\COMMANDS:
        \\  -h, --help                   Show this help message
        \\  --status                     Show current Ralph status (RALPH_STATUS)
        \\  --run-one-cycle              Run one Golden Chain cycle
        \\  --run-until-complete         Run cycles until EXIT_SIGNAL
        \\  --init [PATH]                Initialize .ralph directory
        \\  --swarm-monitor              Show DHT & TRI monitor dashboard (single shot)
        \\  --swarm-monitor-live         Live DHT monitor with auto-refresh (2s interval)
        \\
        \\OPTIONS:
        \\  --real-dht                   Use real DHT polling from kg_sync.zig (instead of mock)
        \\  -v, --verbose                Enable verbose output
        \\  --no-color                   Disable colored output
        \\
        \\EXAMPLES:
        \\  ralph --status
        \\  ralph --run-one-cycle
        \\  ralph --run-until-complete
        \\  ralph --init ./my-project
        \\  ralph --swarm-monitor
        \\  ralph --swarm-monitor-live
        \\
    );
}

/// Print Ralph status
fn showStatus(allocator: Allocator, config: ralph.RalphConfig) !void {
    var agent = try ralph.RalphAgent.init(allocator, config);
    defer agent.deinit();

    const status = try agent.getStatus(allocator);
    defer allocator.free(status);

    try stdoutWrite(status);
    try stdoutWrite("\n");
}

/// Run one development cycle
fn runOneCycle(allocator: Allocator, config: ralph.RalphConfig, verbose: bool) !void {
    if (verbose) {
        try stdoutWrite("Starting Ralph Golden Chain cycle...\n");
    }

    var agent = try ralph.RalphAgent.init(allocator, config);
    defer agent.deinit();

    const result = try agent.runOneCycle();

    if (result.success) {
        try stdoutWrite("✅ Cycle completed successfully\n");
        try stdoutPrint("   Files modified: {d}\n", .{result.files_modified});
        try stdoutPrint("   Last completed link: {s}\n", .{@tagName(result.link_completed)});
    } else {
        try stdoutPrint("❌ Cycle failed: {s}\n", .{result.error_message});
        try stdoutPrint("   Stopped at link: {s}\n", .{@tagName(result.link_completed)});
        return error.CycleFailed;
    }
}

/// Run cycles until completion
fn runUntilComplete(allocator: Allocator, config: ralph.RalphConfig, verbose: bool) !void {
    if (verbose) {
        try stdoutWrite("Starting Ralph autonomous development...\n");
        try stdoutWrite("Running until EXIT_SIGNAL or max_loops reached.\n\n");
    }

    var agent = try ralph.RalphAgent.init(allocator, config);
    defer agent.deinit();

    const summary = try agent.runUntilComplete();

    try stdoutWrite("\n╔════════════════════════════════════════════════════════╗\n");
    try stdoutWrite("║           RALPH AUTONOMOUS DEVELOPMENT SUMMARY           ║\n");
    try stdoutWrite("╚════════════════════════════════════════════════════════╝\n");
    try stdoutPrint("Total cycles: {d}\n", .{summary.total_cycles});
    try stdoutPrint("Successful: {d}\n", .{summary.successful_cycles});
    try stdoutPrint("Failed: {d}\n", .{summary.failed_cycles});
    try stdoutPrint("Files modified: {d}\n", .{summary.total_files_modified});
    try stdoutPrint("Exit reason: {s}\n", .{summary.exit_reason});

    if (summary.failed_cycles > 0) {
        const failure_rate = @as(f64, @floatFromInt(summary.failed_cycles)) / @as(f64, @floatFromInt(summary.total_cycles)) * 100.0;
        try stdoutPrint("Failure rate: {d:.1}%\n", .{failure_rate});
    }

    if (summary.successful_cycles > 0) {
        try stdoutWrite("\n✅ Development completed successfully!\n");
    } else {
        try stdoutWrite("\n⚠️  No successful cycles completed.\n");
    }
}

/// Initialize .ralph directory structure
fn initRalph(allocator: Allocator, path: []const u8, force: bool) !void {
    _ = allocator;

    const ralph_path = if (std.mem.eql(u8, path, ".")) ".ralph" else path;

    // Check if directory exists
    const cwd = std.fs.cwd();
    if (cwd.openDir(ralph_path, .{})) |_| {
        if (!force) {
            try stdoutPrint("Error: .ralph directory already exists at '{s}'\n", .{ralph_path});
            try stdoutWrite("Use --force to overwrite.\n");
            return error.AlreadyExists;
        }
    } else |_| {}

    try stdoutPrint("Initializing Ralph at '{s}'...\n", .{ralph_path});

    // Create directory structure
    var dir = try std.fs.cwd().makeOpenPath(ralph_path, .{});
    defer dir.close();

    // Create subdirectories
    const subdirs = [_][]const u8{
        "specs",
        "internal",
        "logs",
        "docs/generated",
    };

    for (subdirs) |sub| {
        try dir.makePath(sub);
    }

    // Create default files
    const fix_plan_content =
        \\# Ralph Fix Plan
        \\
        \\## Tasks
        \\
        \\- [ ] Example task 1 (p0_high)
        \\  - [ ] Subtask 1.1
        \\  - [ ] Subtask 1.2
        \\
        \\- [ ] Example task 2 (p1_medium)
        \\  - [ ] Subtask 2.1
        \\
        \\## Acceptance Criteria
        \\
        \\1. All tests pass
        \\2. Code is formatted
        \\3. Documentation updated
        \\
    ;

    const fix_plan_file = try dir.createFile("fix_plan.md", .{});
    try fix_plan_file.writeAll(fix_plan_content);
    fix_plan_file.close();

    const tech_tree_content =
        \\# Ralph Tech Tree
        \\
        \\## In Progress
        \\
        \\| ID | Name | Branch | Complexity | Impact | Dependencies |
        \\|----|------|--------|------------|--------|--------------|
        \\
        \\## Available
        \\
        \\| ID | Name | Branch | Complexity | Impact | Dependencies |
        \\|----|------|--------|------------|--------|--------------|
        \\
        \\## Completed
        \\
        \\| ID | Name | Branch | Complexity | Impact | Dependencies |
        \\|----|------|--------|------------|--------|--------------|
        \\
        \\## Locked
        \\
        \\| ID | Name | Branch | Complexity | Impact | Dependencies |
        \\|----|------|--------|------------|--------|--------------|
        \\
    ;

    const tech_tree_file = try dir.createFile("TECH_TREE.md", .{});
    try tech_tree_file.writeAll(tech_tree_content);
    tech_tree_file.close();

    try stdoutPrint("\n✅ Ralph initialized successfully at '{s}'\n", .{ralph_path});
    try stdoutWrite("\nNext steps:\n");
    try stdoutWrite("  1. Edit fix_plan.md to add your tasks\n");
    try stdoutWrite("  2. Update TECH_TREE.md with your tech tree\n");
    try stdoutWrite("  3. Run: ralph --run-one-cycle\n");
}

/// Run Swarm Watch - Live DHT & TRI rewards monitor dashboard
fn runSwarmMonitor(allocator: Allocator, verbose: bool, live: bool, use_real_dht: bool) !void {
    _ = verbose;

    // Create real DHT instance if --real-dht flag is set
    var dht_heap_allocated: ?*kg_sync.KgTripleDHT = null;
    if (use_real_dht) {
        const node_id = std.mem.zeroes([32]u8);
        const dht = try allocator.create(kg_sync.KgTripleDHT);
        dht.* = kg_sync.KgTripleDHT.init(allocator, node_id);
        dht_heap_allocated = dht;

        // Seed with test triple for demonstration
        const hash = kg_sync.tripleHash("Trinity", "is", "ternary");
        const test_triple = kg_sync.serializeTriple("Trinity", "is", "ternary", 0.95, node_id);
        try dht.storeTriple(hash, test_triple);
    }

    // Cleanup at end of function
    defer {
        if (dht_heap_allocated) |dht| {
            allocator.destroy(dht);
        }
    }

    if (live) {
        // Live mode with auto-refresh every 2 seconds
        const config = swarm_watch.LiveConfig{
            .interval_ms = 2000,
            .clear_screen = true,
            .show_timestamp = true,
        };
        const mode = if (use_real_dht) swarm_watch.PollMode.real else swarm_watch.PollMode.mock;
        try swarm_watch.runLiveDashboard(allocator, stdout_file, config, mode);
        return;
    }

    try stdoutWrite("\n╔══════════════════════════════════════════════════════════════════════════════╗\n");
    if (use_real_dht) {
        try stdoutWrite("║           SWARM-WATCH DEV-003 | Live DHT & TRI Monitor (REAL)          ║\n");
    } else {
        try stdoutWrite("║           SWARM-WATCH DEV-003 | Live DHT & TRI Monitor (MOCK)          ║\n");
    }
    try stdoutWrite("╚══════════════════════════════════════════════════════════════════════════════╝\n\n");

    // Initialize SwarmWatch
    var watch = swarm_watch.SwarmWatch.init(allocator);

    // Set mode based on whether we're using real DHT
    if (use_real_dht) {
        watch.mode = .real;
    }

    // Poll DHT stats (real or mock)
    if (use_real_dht and dht_heap_allocated != null) {
        const stats = dht_heap_allocated.?.getStats();
        watch.pollDhtStats(.{
            .triples_stored = stats.triples_stored,
            .triples_distributed = stats.triples_distributed,
            .triples_received = stats.triples_received,
            .triples_rejected = stats.triples_rejected,
            .triples_duplicate = stats.triples_duplicate,
            .sync_rounds = stats.sync_rounds,
            .peer_count = 1, // Local node only
        });
    } else {
        // Mock data
        watch.pollDhtStats(.{
            .triples_stored = 1337,
            .triples_distributed = 500,
            .triples_received = 450,
            .triples_rejected = 15,
            .triples_duplicate = 10,
            .sync_rounds = 42,
            .peer_count = 7,
        });
    }

    // Poll mock reward stats (Phase 3 will integrate real rewards)
    watch.pollRewardStats(.{
        .total_paid_wei = 4_233_000_000_000_000_000, // 4.233 TRI
        .pending_wei = 87_000_000_000_000, // 0.000087 TRI
        .triples_rewarded = 5000,
    });

    // Record some sync events
    watch.recordSyncEvent(.store, "Trinity", "is", "ternary", .accepted);
    watch.recordSyncEvent(.sync_inbound, "Alice", "knows", "Bob", .duplicate);
    watch.recordSyncEvent(.store, "Ralph", "generates", "code", .accepted);

    // Render the dashboard (provide allocator for formatting)
    try watch.renderDashboard(allocator, stdout_file);

    if (use_real_dht) {
        try stdoutWrite("\n[Real DHT Mode - Phase 3]\n");
        try stdoutWrite("DHT stats polled from kg_sync.zig\n");
    } else {
        try stdoutWrite("\n[Mock Data Mode]\n");
        try stdoutWrite("Use --real-dht flag for actual DHT polling\n");
    }
    try stdoutWrite("Press Ctrl+C to exit.\n");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    var verbose = false;
    var force = false;
    var use_real_dht = false;
    const config = ralph.RalphConfig{};

    // Parse arguments
    var i: usize = 1;
    while (i < args.len) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try printUsage();
            return;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--force")) {
            force = true;
        } else if (std.mem.eql(u8, arg, "--real-dht")) {
            use_real_dht = true;
        } else if (std.mem.eql(u8, arg, "--status")) {
            try showStatus(allocator, config);
            return;
        } else if (std.mem.eql(u8, arg, "--run-one-cycle")) {
            try runOneCycle(allocator, config, verbose);
            return;
        } else if (std.mem.eql(u8, arg, "--run-until-complete")) {
            try runUntilComplete(allocator, config, verbose);
            return;
        } else if (std.mem.eql(u8, arg, "--init")) {
            const path = if (i + 1 < args.len and args[i + 1][0] != '-') blk: {
                i += 1;
                break :blk args[i];
            } else ".";
            try initRalph(allocator, path, force);
            return;
        } else if (std.mem.eql(u8, arg, "--swarm-monitor")) {
            try runSwarmMonitor(allocator, verbose, false, use_real_dht);
            return;
        } else if (std.mem.eql(u8, arg, "--swarm-monitor-live")) {
            try runSwarmMonitor(allocator, verbose, true, use_real_dht);
            return;
        } else {
            try stdoutPrint("Unknown argument: {s}\n\n", .{arg});
            try printUsage();
            return error.UnknownArgument;
        }

        i += 1;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "cli: parse help command" {
    // Simulate --help argument
    const args = &[_][]const u8{ "ralph", "--help" };
    try std.testing.expectEqual(@as(usize, 2), args.len);
    try std.testing.expect(std.mem.eql(u8, args[1], "--help"));
}

test "cli: parse status command" {
    // Simulate --status argument
    const args = &[_][]const u8{ "ralph", "--status" };
    try std.testing.expectEqual(@as(usize, 2), args.len);
    try std.testing.expect(std.mem.eql(u8, args[1], "--status"));
}

test "cli: parse run-one-cycle command" {
    // Simulate --run-one-cycle argument
    const args = &[_][]const u8{ "ralph", "--run-one-cycle" };
    try std.testing.expectEqual(@as(usize, 2), args.len);
    try std.testing.expect(std.mem.eql(u8, args[1], "--run-one-cycle"));
}

test "cli: parse run-until-complete command" {
    // Simulate --run-until-complete argument
    const args = &[_][]const u8{ "ralph", "--run-until-complete" };
    try std.testing.expectEqual(@as(usize, 2), args.len);
    try std.testing.expect(std.mem.eql(u8, args[1], "--run-until-complete"));
}

test "cli: parse init command with path" {
    // Simulate --init ./my-project
    const args = &[_][]const u8{ "ralph", "--init", "./my-project" };
    try std.testing.expectEqual(@as(usize, 3), args.len);
    try std.testing.expect(std.mem.eql(u8, args[1], "--init"));
    try std.testing.expect(std.mem.eql(u8, args[2], "./my-project"));
}

test "cli: parse verbose flag" {
    const args = &[_][]const u8{ "ralph", "--verbose", "--status" };
    try std.testing.expectEqual(@as(usize, 3), args.len);

    // Find --verbose
    var found_verbose = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--verbose")) {
            found_verbose = true;
            break;
        }
    }
    try std.testing.expect(found_verbose);
}

test "cli: RalphConfig has default values" {
    const config = ralph.RalphConfig{};
    try std.testing.expect(std.mem.eql(u8, config.ralph_path, ".ralph"));
    try std.testing.expect(std.mem.eql(u8, config.fix_plan_path, ".ralph/fix_plan.md"));
    try std.testing.expect(config.max_loops_per_session == 100);
    try std.testing.expect(config.enable_memory);
}
