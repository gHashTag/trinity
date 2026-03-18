const std = @import("std");
const ReplTester = @import("repl_tester.zig").ReplTester;
const CommandInvoker = @import("command_invoker.zig").CommandInvoker;
const sacred = @import("testing/assertions.zig");

// ============================================================================
// TRINITY: REPL Test Suite (Cycle 101)
// Table-driven tests for TRI CLI commands
// Now uses REAL command execution via CommandInvoker
// ============================================================================

// Global invoker shared across tests
var global_invoker: ?CommandInvoker = null;

fn setupInvoker() !CommandInvoker {
    if (global_invoker == null) {
        global_invoker = try CommandInvoker.init(std.testing.allocator);
    }
    return global_invoker.?;
}

// ============================================================================
// Sacred Math Tests
// ============================================================================

test "math: phi command" {
    var invoker = try setupInvoker();
    defer _ = global_invoker; // Keep for other tests

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    const cases = [_]struct {
        input: []const u8,
        expected_substring: []const u8,
    }{
        .{ .input = "phi 1", .expected_substring = "1.618" },
        .{ .input = "phi 2", .expected_substring = "2.618" },
    };

    for (cases) |case| {
        try tester.reset();
        _ = try tester.runCommand(case.input);
        try tester.expectContains(case.expected_substring);
    }
}

test "math: constants command" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    _ = try tester.runCommand("constants");

    // Should display sacred constants
    try tester.expectContains("φ");
    try sacred.expectSacredConstants(tester.getOutput());
}

test "math: Fibonacci command" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    const cases = [_]struct {
        input: []const u8,
        expected: []const u8,
    }{
        .{ .input = "fib 0", .expected = "0" },
        .{ .input = "fib 1", .expected = "1" },
        .{ .input = "fib 10", .expected = "55" },
    };

    for (cases) |case| {
        try tester.reset();
        _ = try tester.runCommand(case.input);
        try tester.expectContains(case.expected);
    }
}

test "math: Lucas command" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    _ = try tester.runCommand("lucas 2");

    // L(2) = 3 = TRINITY
    try tester.expectContains("3");
}

test "math: phi power validation" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    // Test that phi powers are computed correctly
    _ = try tester.runCommand("phi 0");
    try tester.expectContains("1");

    try tester.reset();
    _ = try tester.runCommand("phi 1");
    try tester.expectContains("1.618");
}

// ============================================================================
// Sacred Agent Tests
// ============================================================================

test "agent: identity command" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    _ = try tester.runCommand("identity");

    // Should affirm sacred intelligence identity
    try sacred.expectSacredIntelligence(tester.getOutput());
}

test "agent: omega command" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    _ = try tester.runCommand("omega");

    // Should mention omega
    try tester.expectContains("Ω");
}

// ============================================================================
// Info Tests
// ============================================================================

test "info: version command" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    _ = try tester.runCommand("version");

    // Should show version
    try tester.expectContains("TRINITY");
}

test "info: help command" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    _ = try tester.runCommand("help");

    // Should show help sections
    try tester.expectContains("COMMANDS");
}

test "info: info command" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    _ = try tester.runCommand("info");

    // Should show system information
    try tester.expectContains("TRINITY");
}

// ============================================================================
// Integration Tests
// ============================================================================

test "integration: multiple commands in sequence" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    // Run multiple commands
    _ = try tester.runCommand("phi 1");
    try tester.expectContains("1.618");

    try tester.reset();
    _ = try tester.runCommand("fib 10");
    try tester.expectContains("55");

    try tester.reset();
    _ = try tester.runCommand("constants");
    try sacred.expectPhiPresent(tester.getOutput());
}

test "integration: sacred mathematics flow" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    // Test the sacred math workflow
    _ = try tester.runCommand("phi 2");
    try tester.expectContains("2.618"); // φ²
}

// ============================================================================
// Performance Tests
// ============================================================================

test "performance: fast command execution" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    const start = std.time.nanoTimestamp();

    // Execute commands quickly
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        try tester.reset();
        _ = try tester.runCommand("phi 1");
    }

    const end = std.time.nanoTimestamp();
    const elapsed_ms = @divTrunc(end - start, 1_000_000);

    // Should complete 5 commands in reasonable time (< 10 seconds)
    try std.testing.expect(elapsed_ms < 10000);
}

// ============================================================================
// Edge Cases
// ============================================================================

test "edge: empty command" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    // Empty command should handle gracefully
    _ = try tester.runCommand("");
}

test "edge: whitespace only" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    _ = try tester.runCommand("   ");
    // Should handle gracefully
}

// ============================================================================
// Regression Tests
// ============================================================================

test "regression: phi values are accurate" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    // Known phi values
    _ = try tester.runCommand("phi 1");
    try tester.expectContains("1.618");

    try tester.reset();
    _ = try tester.runCommand("phi 2");
    try tester.expectContains("2.618");
}

test "regression: Fibonacci sequence correctness" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    const fib_values = [_]struct {
        n: []const u8,
        expected: []const u8,
    }{
        .{ .n = "0", .expected = "0" },
        .{ .n = "1", .expected = "1" },
        .{ .n = "2", .expected = "1" },
        .{ .n = "3", .expected = "2" },
        .{ .n = "4", .expected = "3" },
        .{ .n = "5", .expected = "5" },
    };

    for (fib_values) |case| {
        try tester.reset();
        const cmd = try std.fmt.allocPrint(std.testing.allocator, "fib {s}", .{case.n});
        defer std.testing.allocator.free(cmd);

        _ = try tester.runCommand(cmd);
        try tester.expectContains(case.expected);
    }
}

test "regression: Lucas sequence correctness" {
    var invoker = try setupInvoker();
    defer _ = global_invoker;

    var tester = try ReplTester.init(std.testing.allocator, &invoker);
    defer tester.deinit();

    const lucas_values = [_]struct {
        n: []const u8,
        expected: []const u8,
    }{
        .{ .n = "0", .expected = "2" },
        .{ .n = "1", .expected = "1" },
        .{ .n = "2", .expected = "3" }, // Trinity
        .{ .n = "3", .expected = "4" },
        .{ .n = "4", .expected = "7" },
    };

    for (lucas_values) |case| {
        try tester.reset();
        const cmd = try std.fmt.allocPrint(std.testing.allocator, "lucas {s}", .{case.n});
        defer std.testing.allocator.free(cmd);

        _ = try tester.runCommand(cmd);
        try tester.expectContains(case.expected);
    }
}
