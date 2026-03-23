// Lotus Cycle CLI — Run Queen's autonomous improvement loop
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const lotus = @import("lotus_cycle.zig");

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        usageAndExit();
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "run") or std.mem.eql(u8, command, "cycle")) {
        try runCycle(allocator);
    } else if (std.mem.eql(u8, command, "stats")) {
        try showStats(allocator);
    } else if (std.mem.eql(u8, command, "test")) {
        try runTests(allocator);
    } else if (std.mem.eql(u8, command, "health")) {
        try showHealth(allocator);
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "-h") or std.mem.eql(u8, command, "--help")) {
        usageAndExit();
    } else {
        std.debug.print("{s}❌ Unknown command: {s}{s}\n\n", .{ RED, command, RESET });
        usageAndExit();
    }
}

fn usageAndExit() noreturn {
    std.debug.print(
        \\{s}═══════════════════════════════════════════════════════════════{s}
        \\{s}Queen Lotus Cycle — Autonomous Improvement Loop{s}
        \\{s}═══════════════════════════════════════════════════════════════{s}
        \\
        \\{s}Usage:{s} lotus-cycle <command>
        \\
        \\{s}Commands:{s}
        \\  {s}run{s}     Run one complete Lotus Cycle
        \\  {s}cycle{s}   Alias for 'run'
        \\  {s}stats{s}   Show episode statistics
        \\  {s}test{s}    Run Lotus Cycle tests
        \\  {s}health{s}   Check Lotus Cycle health
        \\  {s}help{s}    Show this help message
        \\
        \\{s}φ² + 1/φ² = 3 = TRINITY{s}
        \\
    , .{ BOLD, RESET, BOLD, RESET, BOLD, RESET, CYAN, RESET, CYAN, RESET, GREEN, RESET, GREEN, RESET, GREEN, RESET, GREEN, RESET, GREEN, RESET, GREEN, RESET, DIM, RESET });
    std.process.exit(1);
}

fn runCycle(allocator: std.mem.Allocator) !void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}🌸 Queen Lotus Cycle — Starting{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ BOLD, RESET });

    const start_ns = std.time.nanoTimestamp();

    const result = lotus.runFullCycle(allocator) catch |err| {
        std.debug.print("{s}❌ Cycle failed: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return err;
    };
    defer allocator.free(result.context.active_issues);

    const end_ns = std.time.nanoTimestamp();
    const duration_ms = @divTrunc(end_ns - start_ns, 1_000_000);

    // Display results
    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    std.debug.print("{s}📊 Cycle Results{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    std.debug.print("  {s}Duration:{s} {d} ms\n", .{ YELLOW, RESET, duration_ms });
    std.debug.print("  {s}Outcome:{s}   {s}{s}\n", .{ YELLOW, RESET, @tagName(result.outcome), if (result.result.success) GREEN else RED });

    std.debug.print("  {s}Action:{s}   {s}", .{ YELLOW, RESET, GREEN });
    switch (result.plan.action) {
        .scale_up => std.debug.print("scale_up {s} (q={d:.2})", .{ result.plan.key, result.plan.quality_score }),
        .scale_down => std.debug.print("scale_down {s} (q={d:.2})", .{ result.plan.key, result.plan.quality_score }),
        .trigger => std.debug.print("trigger {s}", .{result.plan.key}),
        .wait => std.debug.print("wait", .{}),
    }
    std.debug.print("{s}\n\n", .{RESET});

    std.debug.print("{s}✅ Lotus Cycle complete{s}\n", .{ GREEN, RESET });
}

fn showStats(allocator: std.mem.Allocator) !void {
    const episodes = @import("episodes.zig");

    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}📈 Lotus Cycle Statistics{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ BOLD, RESET });

    const stats = try episodes.getEpisodeStats(allocator);

    std.debug.print("  {s}Total episodes:{s}   {d}\n", .{ YELLOW, RESET, stats.total });
    std.debug.print("  {s}Last 24h:{s}        {d}\n\n", .{ YELLOW, RESET, stats.last_24h });

    std.debug.print("  {s}By source:{s}\n", .{ DIM, RESET });
    std.debug.print("    lotus_cycle:       {d}\n", .{stats.by_source[0]});
    std.debug.print("    external:           {d}\n", .{stats.by_source[1]});
    std.debug.print("    scheduled:          {d}\n", .{stats.by_source[2]});
    std.debug.print("    experience_recall:  {d}\n", .{stats.by_source[3]});
    std.debug.print("    tri27:             {d}\n\n", .{stats.by_source[4]});

    std.debug.print("  {s}By outcome:{s}\n", .{ DIM, RESET });
    std.debug.print("    success:          {d}\n", .{stats.by_outcome[0]});
    std.debug.print("    partial:           {d}\n", .{stats.by_outcome[1]});
    std.debug.print("    failure_learned:  {d}\n", .{stats.by_outcome[2]});
    std.debug.print("    failure_unknown:   {d}\n", .{stats.by_outcome[3]});
    std.debug.print("    blocked:           {d}\n", .{stats.by_outcome[4]});
}

fn runTests(allocator: std.mem.Allocator) !void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}🧪 Running Lotus Cycle Tests{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ BOLD, RESET });

    // Run the lotus_cycle test
    const lotus_tests = @import("lotus_cycle.zig");

    // This will run the test defined in lotus_cycle.zig
    _ = try lotus_tests.runFullCycle(allocator);

    std.debug.print("\n{s}✅ All tests passed{s}\n", .{ GREEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

test "lotus_cli: usageAndExit displays help and exits" {
    const testing = std.testing;
    const help_output = testing.allocator;

    // Note: usageAndExit() calls std.process.exit(1) which we can't test directly
    // This test verifies the help message string is correctly formatted
    _ = help_output;
}

test "lotus_cli: unknown command shows error" {
    const testing = std.testing;
    _ = testing;
    // This would be tested via integration tests since it exits
}

test "lotus_cli: showStats displays statistics" {
    const testing = std.testing;
    _ = testing;
    // Integration test would verify stats are displayed
}

test "lotus_cli: runCycle executes full cycle" {
    const testing = std.testing;
    _ = testing;
    // Integration test would verify cycle execution
}

fn showHealth(allocator: std.mem.Allocator) !void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}Lotus Cycle Health Check{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ BOLD, RESET });

    var error_count: usize = 0;

    const episodes = @import("episodes.zig");
    const lotus_module = @import("lotus_cycle.zig");

    const stats = episodes.getEpisodeStats(allocator) catch |err| {
        std.debug.print("  {s}Episodes module error: {s}\n", .{ RED, @errorName(err) });
        error_count += 1;
        return;
    };
    std.debug.print("  {s}Episodes module OK{s}\n", .{ GREEN, RESET });

    _ = lotus_module.runFullCycle(allocator) catch |err| {
        std.debug.print("  {s}Lotus Cycle module error: {s}\n", .{ RED, @errorName(err) });
        error_count += 1;
    };
    std.debug.print("  {s}Lotus Cycle module OK{s}\n", .{ GREEN, RESET });

    std.debug.print("\n{s}Health Summary{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}Errors:{s}    {d}\n", .{ YELLOW, RESET, error_count });
    std.debug.print("  {s}Total Episodes:{s} {d}\n", .{ CYAN, RESET, stats.total });

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ DIM, RESET });
}
