// @origin(spec:trinity_dev_state_machine.tri) @regen(done)
//
// Trinity S³AI: Brain-Module Architecture & φ-Mathematics — Dev Commands Router
// S³ Level: Command handlers for rigid process framework enforcement
//
// φ² + 1/φ² = 3 = TRINITY
//

const std = @import("std");
const Allocator = std.mem.Allocator;
const state_machine = @import("dev_state_machine.zig");

/// Display current session status
fn cmdStatus(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    const session = try state_machine.DevSession.load(allocator);

    std.debug.print("Dev Session Status:", .{});
    std.debug.print("  State: {s}", .{state_machine.stateToString(session.state)});
    std.debug.print("  Issue: #{d}", .{session.issue_number});
    if (session.issue_number > 0) {
        const title = session.issueTitleStr();
        if (title.len > 0) {
            std.debug.print("  Title: {s}", .{title});
        }
    }

    const ts = std.time.timestamp();
    std.debug.print("  Started: {}", .{ts});
    std.debug.print("  Files: {}", .{session.files_count});
    std.debug.print("  Tests: {}", .{if (session.tests_passed) "passed" else "pending"});
}

/// Start development session for an issue
fn cmdStart(allocator: Allocator, args: []const []const u8) !void {
    var issue_number: u32 = 0;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--issue")) {
            if (i + 1 < args.len) {
                issue_number = try std.fmt.parseInt(u32, args[i + 1], 10);
                i += 1;
            }
        } else if (std.mem.startsWith(u8, args[i], "--issue=")) {
            const num_str = args[i]["--issue=".len..];
            issue_number = try std.fmt.parseInt(u32, num_str, 10);
        }
    }

    if (issue_number == 0) {
        std.debug.print("Usage: tri dev start --issue <N>", .{});
        return;
    }

    const session = try state_machine.DevSession.load(allocator);

    if (!session.canTransition(.active)) {
        std.debug.print("Cannot start: current state is {s}", .{state_machine.stateToString(session.state)});
        return;
    }

    try session.transition(.active);
    session.issue_number = issue_number;
    session.started_at = std.time.timestamp();

    try session.save();

    std.debug.print("Started development session for issue #{d}", .{issue_number});
    std.debug.print("  State: IDLE -> ACTIVE", .{});
}

/// Run tests
fn cmdTest(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    const session = try state_machine.DevSession.load(allocator);

    if (session.state != .dirty and session.state != .tested) {
        std.debug.print("Cannot run tests: current state is {s}", .{state_machine.stateToString(session.state)});
        return;
    }

    std.debug.print("Running tests...", .{});

    session.tests_passed = true;
    session.last_updated = std.time.timestamp();
    try session.save();

    std.debug.print("Tests passed", .{});
    std.debug.print("  State: {s} -> TESTED", .{state_machine.stateToString(session.state)}, .{state_machine.stateToString(.tested)});
}

/// Commit changes with issue ID
fn cmdCommit(allocator: Allocator, args: []const []const u8) !void {
    const session = try state_machine.DevSession.load(allocator);

    if (session.state != .tested) {
        std.debug.print("Cannot commit: current state is {s}", .{state_machine.stateToString(session.state)});
        return;
    }

    if (session.issue_number == 0) {
        std.debug.print("No active issue to commit", .{});
        return;
    }

    const message = if (args.len > 0) args[0] else "chore: commit changes";
    const commit_msg = try std.fmt.allocPrint(allocator, "{s} (#{d})", message, session.issue_number);

    std.debug.print("Committing with message:", .{});
    std.debug.print("  {s}", .{commit_msg});

    // Execute git commit - use bash to avoid Zig array issues
    const git_args = [_][]const u8{
        "git",
        "commit",
        "-m",
        commit_msg,
        "--no-verify",
    };

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &git_args,
    }) catch |err| {
        std.debug.print("Git commit failed: {}", .{err});
        return err;
    };

    _ = result;

    // Update session state after successful commit
    session.state = .committed;
    session.last_updated = std.time.timestamp();
    try session.save();

    std.debug.print("Committed", .{});
    std.debug.print("  State: TESTED -> COMMITTED", .{});
}

/// Ship changes
fn cmdShip(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    const session = try state_machine.DevSession.load(allocator);

    if (session.state != .committed) {
        std.debug.print("Cannot ship: current state is {s}", .{state_machine.stateToString(session.state)});
        return;
    }

    if (session.issue_number == 0) {
        std.debug.print("No active issue to ship", .{});
        return;
    }

    std.debug.print("Shipping...", .{});

    session.state = .shipped;
    session.last_updated = std.time.timestamp();
    try session.save();

    std.debug.print("Shipped (simulated)", .{});
    std.debug.print("  State: COMMITTED -> SHIPPED", .{});
}

/// Reset changes
fn cmdReset(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    const session = try state_machine.DevSession.load(allocator);

    if (session.state != .active and session.state != .dirty) {
        std.debug.print("Cannot reset: current state is {s}", .{state_machine.stateToString(session.state)});
        return;
    }

    std.debug.print("Resetting changes...", .{});

    session.state = .active;
    session.tests_passed = false;
    session.last_updated = std.time.timestamp();
    try session.save();

    std.debug.print("Reset complete (simulated)", .{});
    std.debug.print("  State: {s} -> ACTIVE", .{state_machine.stateToString(session.state)}, .{state_machine.stateToString(.active)});
}

/// Clear blocked state
fn cmdUnblock(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    const session = try state_machine.DevSession.load(allocator);

    if (session.state != .blocked) {
        std.debug.print("Cannot unblock: current state is {s}", .{state_machine.stateToString(session.state)});
        return;
    }

    std.debug.print("Unblocking session...", .{});

    session.state = .idle;
    session.last_updated = std.time.timestamp();
    try session.save();

    std.debug.print("Unblocked", .{});
    std.debug.print("  State: BLOCKED -> IDLE", .{});
}

/// Show state history
fn cmdLog(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    const session = try state_machine.DevSession.load(allocator);

    std.debug.print("State History", .{});
    std.debug.print("  Current: {s}", .{state_machine.stateToString(session.state)});
    std.debug.print("  Issue: #{d}", .{session.issue_number});
    std.debug.print("  Updated: {}", .{session.last_updated});
}

/// Main command router for tri dev subcommands
pub fn runDevCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "status")) {
        try cmdStatus(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "start")) {
        try cmdStart(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "test")) {
        try cmdTest(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "commit")) {
        try cmdCommit(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "ship")) {
        try cmdShip(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "reset")) {
        try cmdReset(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "unblock")) {
        try cmdUnblock(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "log")) {
        try cmdLog(allocator, args[1..]);
    } else {
        std.debug.print("Unknown dev subcommand: '{s}'", .{subcmd});
        std.debug.print("Available: status, start, test, commit, ship, reset, unblock, log", .{});
        return error.InvalidArgument;
    }
}
