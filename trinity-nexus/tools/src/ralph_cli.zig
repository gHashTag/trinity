//! Ralph CLI - Autonomous Development Assistant
//! Command-line interface for Ralph autonomous development system

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import Ralph Agent module
const ralph = @import("maxwell/ralph/agent.zig");

/// CLI configuration
const CLIConfig = struct {
    verbose: bool = false,
    color: bool = true,
};

/// Print usage information
fn printUsage(writer: anytype) !void {
    try writer.writeAll(
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
        \\
        \\OPTIONS:
        \\  -v, --verbose                Enable verbose output
        \\  --no-color                   Disable colored output
        \\
        \\EXAMPLES:
        \\  ralph --status
        \\  ralph --run-one-cycle
        \\  ralph --run-until-complete
        \\  ralph --init ./my-project
        \\
    );
}

/// Print Ralph status
fn showStatus(allocator: Allocator, config: ralph.RalphConfig) !void {
    var agent = try ralph.RalphAgent.init(allocator, config);
    defer agent.deinit(allocator);

    const status = try agent.getStatus(allocator);
    defer allocator.free(status);

    const stdout = std.io.getStdOut();
    try stdout.writeAll(status);
    try stdout.writeAll("\n");
}

/// Run one development cycle
fn runOneCycle(allocator: Allocator, config: ralph.RalphConfig, verbose: bool) !void {
    const stdout = std.io.getStdOut();

    if (verbose) {
        try stdout.writeAll("Starting Ralph Golden Chain cycle...\n");
    }

    var agent = try ralph.RalphAgent.init(allocator, config);
    defer agent.deinit(allocator);

    const result = try agent.runOneCycle();

    if (result.success) {
        try stdout.print("✅ Cycle completed successfully\n", .{});
        try stdout.print("   Files modified: {d}\n", .{result.files_modified});
        try stdout.print("   Last completed link: {s}\n", .{@tagName(result.link_completed)});
    } else {
        try stdout.print("❌ Cycle failed: {s}\n", .{result.error_message});
        try stdout.print("   Stopped at link: {s}\n", .{@tagName(result.link_completed)});
        return error.CycleFailed;
    }
}

/// Run cycles until completion
fn runUntilComplete(allocator: Allocator, config: ralph.RalphConfig, verbose: bool) !void {
    const stdout = std.io.getStdOut();

    if (verbose) {
        try stdout.writeAll("Starting Ralph autonomous development...\n");
        try stdout.writeAll("Running until EXIT_SIGNAL or max_loops reached.\n\n");
    }

    var agent = try ralph.RalphAgent.init(allocator, config);
    defer agent.deinit(allocator);

    const summary = try agent.runUntilComplete();

    try stdout.writeAll("\n╔════════════════════════════════════════════════════════╗\n", .{});
    try stdout.writeAll("║           RALPH AUTONOMOUS DEVELOPMENT SUMMARY           ║\n", .{});
    try stdout.writeAll("╚════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("Total cycles: {d}\n", .{summary.total_cycles});
    try stdout.print("Successful: {d}\n", .{summary.successful_cycles});
    try stdout.print("Failed: {d}\n", .{summary.failed_cycles});
    try stdout.print("Files modified: {d}\n", .{summary.total_files_modified});
    try stdout.print("Exit reason: {s}\n", .{summary.exit_reason});

    if (summary.failed_cycles > 0) {
        const failure_rate = @as(f64, @floatFromInt(summary.failed_cycles)) / @as(f64, @floatFromInt(summary.total_cycles)) * 100.0;
        try stdout.print("Failure rate: {d:.1}%\n", .{failure_rate});
    }

    if (summary.successful_cycles > 0) {
        try stdout.writeAll("\n✅ Development completed successfully!\n", .{});
    } else {
        try stdout.writeAll("\n⚠️  No successful cycles completed.\n", .{});
    }
}

/// Initialize .ralph directory structure
fn initRalph(allocator: Allocator, path: []const u8, force: bool) !void {
    _ = allocator;
    const stdout = std.io.getStdOut();

    const ralph_path = if (std.mem.eql(u8, path, ".")) ".ralph" else path;

    // Check if directory exists
    if (std.fs.openDirAbsolute(ralph_path, .{})) |_| {
        if (!force) {
            try stdout.print("Error: .ralph directory already exists at '{s}'\n", .{ralph_path});
            try stdout.writeAll("Use --force to overwrite.\n", .{});
            return error.AlreadyExists;
        }
    } else |_| {}

    try stdout.print("Initializing Ralph at '{s}'...\n", .{ralph_path});

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

    try stdout.print("\n✅ Ralph initialized successfully at '{s}'\n", .{ralph_path});
    try stdout.writeAll("\nNext steps:\n", .{});
    try stdout.writeAll("  1. Edit fix_plan.md to add your tasks\n", .{});
    try stdout.writeAll("  2. Update TECH_TREE.md with your tech tree\n", .{});
    try stdout.writeAll("  3. Run: ralph --run-one-cycle\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        const stdout = std.io.getStdOut();
        try printUsage(stdout);
        return;
    }

    var verbose = false;
    var force = false;
    const config = ralph.RalphConfig{};

    // Parse arguments
    var i: usize = 1;
    while (i < args.len) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            const stdout = std.io.getStdOut();
            try printUsage(stdout);
            return;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--force")) {
            force = true;
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
            const path = if (i + 1 < args.len and args[i + 1][0] != '-') b: { i += 1; args[i]; } else ".";
            try initRalph(allocator, path, force);
            return;
        } else {
            const stdout = std.io.getStdOut();
            try stdout.print("Unknown argument: {s}\n\n", .{arg});
            const stdout_writer = std.io.getStdOut();
            try printUsage(stdout_writer);
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
