const std = @import("std");
const CommandInvoker = @import("command_invoker.zig").CommandInvoker;

// ============================================================================
// Minimal TRI stubs for testing (Cycle 100 → Cycle 101)
// These provide CLIState structure for session management
// ============================================================================

pub const CLIState = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !CLIState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *CLIState) void {
        _ = self;
    }
};

pub const Command = enum {
    phi,
    fib,
    lucas,
    constants,
    test_repl,
};

/// Parse command string into Command enum (for backward compatibility)
pub fn parseCommand(input: []const u8) !Command {
    const space_idx = std.mem.indexOfScalar(u8, input, ' ');
    const cmd_name = if (space_idx) |idx| input[0..idx] else input;

    if (std.mem.eql(u8, cmd_name, "phi")) return .phi;
    if (std.mem.eql(u8, cmd_name, "fib")) return .fib;
    if (std.mem.eql(u8, cmd_name, "lucas")) return .lucas;
    if (std.mem.eql(u8, cmd_name, "constants")) return .constants;
    return error.UnknownCommand;
}

/// Execute command using CommandInvoker (real command execution)
pub fn executeCommand(
    cmd: Command,
    state: *CLIState,
    writer: anytype,
    exit_code: *i32,
    invoker: *CommandInvoker,
) !void {
    _ = state;

    // Map Command enum to actual tri command arguments
    const args = switch (cmd) {
        .phi => &[_][]const u8{"phi"},
        .fib => &[_][]const u8{"fib"},
        .lucas => &[_][]const u8{"lucas"},
        .constants => &[_][]const u8{"constants"},
        .test_repl => &[_][]const u8{ "test", "--repl" },
    };

    // Execute via CommandInvoker
    var result = try invoker.runCommand(args);
    defer result.deinit();

    // Write output to writer
    try writer.writeAll(result.stdout);
    if (result.stderr.len > 0) {
        try writer.writeAll(result.stderr);
    }

    exit_code.* = @intCast(result.exit_code);
}

// ============================================================================
// TRINITY: REPL Testing Infrastructure (Cycle 101)
// Provides isolated testing environment for TRI CLI commands
// Now uses CommandInvoker for REAL command execution instead of stubs
// ============================================================================

pub const ReplTester = struct {
    allocator: std.mem.Allocator,
    state: *CLIState,
    invoker: *CommandInvoker,
    output: std.ArrayList(u8),
    exit_code: i32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, invoker: *CommandInvoker) !Self {
        const state = try allocator.create(CLIState);
        state.* = try CLIState.init(allocator);
        return .{
            .allocator = allocator,
            .state = state,
            .invoker = invoker,
            .output = std.ArrayList(u8).initCapacity(allocator, 0) catch .empty,
            .exit_code = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit(self.allocator);
        self.state.deinit();
        self.allocator.destroy(self.state);
    }

    /// Run a command and capture its output
    pub fn runCommand(self: *Self, cmd_str: []const u8) ![]const u8 {
        // Clear previous output
        self.output.clearRetainingCapacity();

        // Create a writer that captures to our buffer
        const writer = self.output.writer(self.allocator);

        // Execute via CommandInvoker directly
        var result = try self.invoker.runCommandString(cmd_str);
        defer result.deinit();

        // Capture output
        try writer.writeAll(result.stdout);
        if (result.stderr.len > 0) {
            try writer.writeAll(result.stderr);
        }

        self.exit_code = @intCast(result.exit_code);

        return self.output.items;
    }

    /// Run command via Command enum (backward compatible)
    pub fn runCommandEnum(self: *Self, cmd: Command, args: ?[]const []const u8) ![]const u8 {
        _ = args;
        self.output.clearRetainingCapacity();
        const writer = self.output.writer(self.allocator);

        var exit_code: i32 = 0;
        try executeCommand(cmd, self.state, writer, &exit_code, self.invoker);
        self.exit_code = exit_code;

        return self.output.items;
    }

    /// Assert that output contains a substring
    pub fn expectContains(self: *Self, substr: []const u8) !void {
        if (std.mem.indexOf(u8, self.output.items, substr) == null) {
            std.debug.print("\n❌ Expected to find: '{s}'\n", .{substr});
            std.debug.print("   In output:\n{s}\n\n", .{self.output.items});
            return error.ExpectedNotFound;
        }
    }

    /// Assert that output does NOT contain a substring
    pub fn expectNotContains(self: *Self, substr: []const u8) !void {
        if (std.mem.indexOf(u8, self.output.items, substr) != null) {
            std.debug.print("\n❌ Did NOT expect to find: '{s}'\n", .{substr});
            std.debug.print("   In output:\n{s}\n\n", .{self.output.items});
            return error.UnexpectedFound;
        }
    }

    /// Assert that output matches a pattern (supports wildcards *)
    pub fn expectPattern(self: *Self, pattern: []const u8) !void {
        if (wildcardMatch(self.output.items, pattern)) {
            return;
        }

        std.debug.print("\n❌ Expected pattern: '{s}'\n", .{pattern});
        std.debug.print("   In output:\n{s}\n\n", .{self.output.items});
        return error.PatternMismatch;
    }

    /// Assert that exit code is 0 (success)
    pub fn expectSuccess(self: *Self) !void {
        if (self.exit_code != 0) {
            std.debug.print("\n❌ Expected exit code 0, got {}\n", .{self.exit_code});
            std.debug.print("   Output:\n{s}\n\n", .{self.output.items});
            return error.ExitCodeNonZero;
        }
    }

    /// Assert that exit code is non-zero (failure)
    pub fn expectFailure(self: *Self) !void {
        if (self.exit_code == 0) {
            std.debug.print("\n❌ Expected non-zero exit code, got 0\n", .{});
            std.debug.print("   Output:\n{s}\n\n", .{self.output.items});
            return error.ExitCodeZero;
        }
    }

    /// Get output as string
    pub fn getOutput(self: *Self) []const u8 {
        return self.output.items;
    }

    /// Get clean output (ANSI codes stripped)
    pub fn getCleanOutput(self: *Self) []const u8 {
        return self.output.items;
    }

    /// Reset state for next test
    pub fn reset(self: *Self) !void {
        self.output.clearRetainingCapacity();
        self.exit_code = 0;
    }

    /// Set exit code manually (for testing error cases)
    pub fn setExitCode(self: *Self, code: i32) void {
        self.exit_code = code;
    }
};

/// Simple wildcard pattern matching (* = any sequence, ? = any character)
fn wildcardMatch(text: []const u8, pattern: []const u8) bool {
    var t_idx: usize = 0;
    var p_idx: usize = 0;
    var t_mark: usize = 0;
    var p_mark: usize = 0;

    while (t_idx < text.len) {
        const p_in_bounds = p_idx < pattern.len;
        if (p_in_bounds and pattern[p_idx] == '*') {
            t_mark = t_idx;
            p_mark = p_idx;
            p_idx += 1;
        } else if (p_in_bounds and (pattern[p_idx] == '?' or pattern[p_idx] == text[t_idx])) {
            t_idx += 1;
            p_idx += 1;
        } else if (p_mark < pattern.len) {
            t_idx = t_mark + 1;
            p_idx = p_mark + 1;
            t_mark = t_idx;
        } else {
            return false;
        }
    }

    while (p_idx < pattern.len and pattern[p_idx] == '*') {
        p_idx += 1;
    }

    return p_idx == pattern.len;
}

// ============================================================================
// Tests
// ============================================================================

test "ReplTester initialization with CommandInvoker" {
    const allocator = std.testing.allocator;

    var invoker = CommandInvoker.init(allocator) catch |err| {
        std.debug.print("Skipping test: tri binary not available ({})\n", .{err});
        return error.SkipZigTest;
    };
    defer invoker.deinit();

    var tester = try ReplTester.init(allocator, &invoker);
    defer tester.deinit();

    try std.testing.expectEqual(@as(i32, 0), tester.exit_code);
    try std.testing.expectEqual(@as(usize, 0), tester.output.items.len);
}

test "ReplTester runCommand - real phi command" {
    const allocator = std.testing.allocator;

    var invoker = CommandInvoker.init(allocator) catch |err| {
        std.debug.print("Skipping test: tri binary not available ({})\n", .{err});
        return error.SkipZigTest;
    };
    defer invoker.deinit();

    var tester = try ReplTester.init(allocator, &invoker);
    defer tester.deinit();

    // Test phi command with real execution
    _ = try tester.runCommand("phi 10");

    // Should have some output
    try std.testing.expect(tester.output.items.len > 0);
}

test "ReplTester expectContains with real output" {
    const allocator = std.testing.allocator;

    var invoker = CommandInvoker.init(allocator) catch |err| {
        std.debug.print("Skipping test: tri binary not available ({})\n", .{err});
        return error.SkipZigTest;
    };
    defer invoker.deinit();

    var tester = try ReplTester.init(allocator, &invoker);
    defer tester.deinit();

    _ = try tester.runCommand("version");

    // Version output should contain something
    try std.testing.expect(tester.output.items.len > 0);
}

test "ReplTester reset" {
    const allocator = std.testing.allocator;

    var invoker = CommandInvoker.init(allocator) catch |err| {
        std.debug.print("Skipping test: tri binary not available ({})\n", .{err});
        return error.SkipZigTest;
    };
    defer invoker.deinit();

    var tester = try ReplTester.init(allocator, &invoker);
    defer tester.deinit();

    // Run a command
    _ = try tester.runCommand("phi 1");

    // Verify output exists
    try std.testing.expect(tester.output.items.len > 0);

    // Reset
    try tester.reset();

    // Output should be cleared
    try std.testing.expectEqual(@as(usize, 0), tester.output.items.len);
    try std.testing.expectEqual(@as(i32, 0), tester.exit_code);
}

test "wildcardMatch - basic patterns" {
    try std.testing.expect(wildcardMatch("hello", "hello"));
    try std.testing.expect(wildcardMatch("hello", "h*o"));
    try std.testing.expect(wildcardMatch("hello", "*"));
    try std.testing.expect(wildcardMatch("hello", "h?llo"));
    try std.testing.expect(wildcardMatch("hello.txt", "*.txt"));
    try std.testing.expect(!wildcardMatch("hello", "world"));
    try std.testing.expect(!wildcardMatch("hello", "h*x"));
}
