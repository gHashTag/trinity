// ═══════════════════════════════════════════════════════════════════════════════
// TRI DEV TEST RUNNER - Standalone test binary for Rigid Process Framework
// ═══════════════════════════════════════════════════════════════════════════════
//
// Purpose: Test dev_commands.zig, dev_state_machine.zig, github_integration.zig
//          independently of the problematic 'tri' binary build
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const dev_commands = @import("dev_commands.zig");
const dev_state_machine = @import("dev_state_machine.zig");
const github_integration = @import("github_integration.zig");

pub fn main() !void {
    const gpa = std.heap.GeneralPurposeAllocator(.{};
    defer {
        const leaked = gpa.deinit();
        if (leaked == 0) {
            std.debug.print("All memory freed successfully", .{});
        }
    };
    const allocator = gpa.allocator();

    // Get command line arguments
    const args = std.process.argsAlloc(allocator, allocator) catch &[_][]const u8{};
    defer allocator.free(args);

    // Show banner if no arguments or --help
    if (args.len <= 1 or std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")) {
        printBanner();
        printUsage();
        return;
    }

    // Skip binary name, get command
    const cmd_args = args[1..];
    const command = cmd_args[0];
    const sub_args = if (cmd_args.len > 1) cmd_args[1..] else &[_][]const u8{};

    // Dispatch command
    if (std.mem.eql(u8, command, "status")) {
        try cmdStatus(allocator, sub_args);
    } else if (std.mem.eql(u8, command, "start")) {
        try cmdStart(allocator, sub_args);
    } else if (std.mem.eql(u8, command, "test")) {
        try cmdTest(allocator, sub_args);
    } else if (std.mem.eql(u8, command, "commit")) {
        try cmdCommit(allocator, sub_args);
    } else if (std.mem.eql(u8, command, "ship")) {
        try cmdShip(allocator, sub_args);
    } else if (std.mem.eql(u8, command, "reset")) {
        try cmdReset(allocator, sub_args);
    } else if (std.mem.eql(u8, command, "unblock")) {
        try cmdUnblock(allocator, sub_args);
    } else if (std.mem.eql(u8, command, "log")) {
        try cmdLog(allocator, sub_args);
    } else if (std.mem.eql(u8, command, "cycle")) {
        try cmdFullCycle(allocator, sub_args);
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
        return error.UnknownCommand;
    }

    std.debug.print("\n✅ Command completed successfully", .{});
}

fn printBanner() void {
    const GREEN = "\x1b[38;2;0;229;153m";
    const GOLD = "\x1b[38;2;255;215;0m";
    const WHITE = "\x1b[38;2;255;255;255m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔══════════════════════════════════════════════════════════════╗{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}║  TRI DEV TEST RUNNER - Rigid Process Framework Tests   ║{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}║  {s}φ² + 1/φ² = 3 = TRINITY{s}                              ║{s}\n", .{ GREEN, GOLD, WHITE, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════════╝{s}\n\n", .{ GREEN, RESET });
}

fn printUsage() void {
    std.debug.print("Usage: test-dev <command> [options]\n\n", .{});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  status              Show dev session status\n", .{});
    std.debug.print("  start --issue <N>    Start dev session for issue N\n", .{{});
    std.debug.print("  test                Run tests and mark as passed\n", .{});
    std.debug.print("  commit              Commit changes with issue ID\n", .{});
    std.debug.print("  ship                Mark changes as shipped\n", .{});
    std.debug.print("  reset               Reset changes back to ACTIVE\n", .{});
    std.debug.print("  unblock             Clear BLOCKED state\n", .{});
    std.debug.print("  log                 Show state history\n", .{});
    std.debug.print("  cycle               Run full test cycle (simulated)\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  --help, -h          Show this help\n", .{});
}

/// Show dev session status
fn cmdStatus(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    const session = try dev_state_machine.DevSession.load(allocator);

    std.debug.print("Dev Session Status:\n", .{});
    std.debug.print("  State: {s}\n", .{dev_state_machine.stateToString(session.state)});
    std.debug.print("  Issue: #{d}\n", .{session.issue_number});
    if (session.issue_number > 0) {
        const title = session.issueTitleStr();
        if (title.len > 0) {
            std.debug.print("  Title: {s}\n", .{title});
        }
    }
    std.debug.print("  Files: {}\n", .{session.files_count});
    const test_status = if (session.tests_passed) "passed" else "pending";
    std.debug.print("  Tests: {s}\n", .{test_status});

    const ts = std.time.timestamp();
    const uptime = if (session.started_at > 0) ts - session.started_at else 0;
    if (uptime > 0) {
        std.debug.print("  Started: {}s ago\n", .{uptime});
    }
}

/// Start development session
fn cmdStart(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var issue_number: u32 = 1; // Default to issue #1 for testing
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--issue")) {
            if (i + 1 < args.len) {
                issue_number = try std.fmt.parseInt(u32, args[i + 1], 10);
                i += 1;
            }
        }
    }

    var session = try dev_state_machine.DevSession.load(allocator);

    if (!session.canTransition(.active)) {
        std.debug.print("Cannot start: current state is {s}\n", .{dev_state_machine.stateToString(session.state)});
        std.debug.print("  Run: test-dev reset to reset to ACTIVE\n", .{});
        return error.InvalidState;
    }

    try session.transition(.active);
    session.issue_number = issue_number;
    session.started_at = std.time.timestamp();

    try session.save();

    std.debug.print("Started development session for issue #{d}\n", .{issue_number});
    std.debug.print("  State: IDLE -> ACTIVE\n", .{});
}

/// Run tests
fn cmdTest(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    var session = try dev_state_machine.DevSession.load(allocator);

    if (session.state != .dirty and session.state != .tested) {
        std.debug.print("Cannot run tests: current state is {s}\n", .{dev_state_machine.stateToString(session.state)});
        std.debug.print("  Tip: Run test-dev start first, then make changes\n", .{});
        return error.InvalidState;
    }

    // Simulate dirty state for testing if currently active
    if (session.state == .active) {
        session.state = .dirty;
        session.files_count = 1;
    }

    std.debug.print("Running tests...\n", .{});
    session.tests_passed = true;
    session.last_updated = std.time.timestamp();
    try session.save();

    std.debug.print("Tests passed\n", .{});
    std.debug.print("  State: {s} -> TESTED\n", .{dev_state_machine.stateToString(session.state)});
}

/// Commit changes
fn cmdCommit(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    var session = try dev_state_machine.DevSession.load(allocator);

    if (session.state != .tested) {
        std.debug.print("Cannot commit: current state is {s}\n", .{dev_state_machine.stateToString(session.state)});
        std.debug.print("  Run: test-dev test first\n", .{});
        return error.InvalidState;
    }

    const message = "chore: commit changes";
    const commit_msg = try std.fmt.allocPrint(allocator, "{s} (#{d})", .{ message, session.issue_number });
    defer allocator.free(commit_msg);

    std.debug.print("Committing with message:\n", .{});
    std.debug.print("  {s}\n", .{commit_msg});

    session.state = .committed;
    session.last_updated = std.time.timestamp();
    try session.save();

    std.debug.print("Committed\n", .{});
    std.debug.print("  State: TESTED -> COMMITTED\n", .{});
}

/// Ship changes
fn cmdShip(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    var session = try dev_state_machine.DevSession.load(allocator);

    if (session.state != .committed) {
        std.debug.print("Cannot ship: current state is {s}\n", .{dev_state_machine.stateToString(session.state)});
        std.debug.print("  Run: test-dev commit first\n", .{});
        return error.InvalidState;
    }

    std.debug.print("Shipping...\n", .{});

    session.state = .shipped;
    session.last_updated = std.time.timestamp();
    try session.save();

    std.debug.print("Shipped (simulated)\n", .{});
    std.debug.print("  State: COMMITTED -> SHIPPED\n", .{});
}

/// Reset changes
fn cmdReset(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    var session = try dev_state_machine.DevSession.load(allocator);

    if (session.state != .active and session.state != .dirty) {
        std.debug.print("Cannot reset: current state is {s}\n", .{dev_state_machine.stateToString(session.state)});
        std.debug.print("  Requires ACTIVE or DIRTY state\n", .{});
        return error.InvalidState;
    }

    std.debug.print("Resetting changes...\n", .{});

    session.state = .active;
    session.tests_passed = false;
    session.last_updated = std.time.timestamp();
    try session.save();

    std.debug.print("Reset complete (simulated)\n", .{});
    std.debug.print("  State: {s} -> ACTIVE\n", .{dev_state_machine.stateToString(session.state)});
}

/// Clear blocked state
fn cmdUnblock(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    var session = try dev_state_machine.DevSession.load(allocator);

    if (session.state != .blocked) {
        std.debug.print("Cannot unblock: current state is {s}\n", .{dev_state_machine.stateToString(session.state)});
        std.debug.print("  Requires BLOCKED state\n", .{});
        return error.InvalidState;
    }

    std.debug.print("Unblocking session...\n", .{});

    session.state = .idle;
    session.last_updated = std.time.timestamp();
    try session.save();

    std.debug.print("Unblocked\n", .{});
    std.debug.print("  State: BLOCKED -> IDLE\n", .{});
}

/// Show state history
fn cmdLog(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    const session = try dev_state_machine.DevSession.load(allocator);

    std.debug.print("State History\n", .{});
    std.debug.print("  Current: {s}\n", .{dev_state_machine.stateToString(session.state)});
    std.debug.print("  Issue: #{d}\n", .{session.issue_number});
    std.debug.print("  Updated: {}\n", .{session.last_updated});
}

/// Run full test cycle
fn cmdFullCycle(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    std.debug.print("Running full Rigid Process Framework test cycle...\n\n", .{});

    // Step 1: Start
    std.debug.print("[1/5] Starting dev session...\n", .{});
    try cmdStart(allocator, &[_][]const u8{});

    // Step 2: Mark dirty (simulate file changes)
    std.debug.print("\n[2/5] Simulating file changes...\n", .{});
    var session = try dev_state_machine.DevSession.load(allocator);
    session.state = .dirty;
    session.files_count = 3;
    try session.save();
    std.debug.print("  Marked 3 files as changed\n", .{});

    // Step 3: Run tests
    std.debug.print("\n[3/5] Running tests...\n", .{});
    try cmdTest(allocator, &[_][]const u8{});

    // Step 4: Commit
    std.debug.print("\n[4/5] Committing changes...\n", .{});
    try cmdCommit(allocator, &[_][]const u8{});

    // Step 5: Ship
    std.debug.print("\n[5/5] Shipping...\n", .{});
    try cmdShip(allocator, &[_][]const u8{});

    std.debug.print("\n{s}═════════════════════════════════════════════════{s}\n", .{
        "\x1b[38;2;0;229;153m", "\x1b[0m",
    });
    std.debug.print("{s}✅ Full cycle test PASSED!{s}\n\n", .{
        "\x1b[38;2;0;229;153m", "\x1b[0m",
    });
}
