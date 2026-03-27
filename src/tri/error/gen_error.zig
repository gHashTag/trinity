//! Tri Error — Generated from specs/tri/tri_error.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from tri_error.tri spec
//! Modify spec and regenerate: tri vibee-gen tri_error

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════════════════
/// TRI ERROR HANDLING
/// ═════════════════════════════════════════════════════════════════
/// Error type for TRI operations
pub const TriError = enum {
    /// Command was not found in registry
    command_not_found,

    /// Invalid arguments provided to command
    invalid_arguments,

    /// Required argument is missing
    missing_argument,

    /// File or directory not found
    file_not_found,

    /// I/O operation failed
    io_error,

    /// Permission denied
    permission_denied,

    /// Get human-readable error message
    pub fn message(self: TriError) []const u8 {
        return switch (self) {
            .command_not_found => "Command not found",
            .invalid_arguments => "Invalid arguments provided",
            .missing_argument => "Required argument missing",
            .file_not_found => "File not found",
            .io_error => "Input/output error",
            .permission_denied => "Permission denied",
        };
    }

    /// Convert error to process exit code
    pub fn toExitCode(self: TriError) u8 {
        return switch (self) {
            .command_not_found => 1,
            .invalid_arguments => 2,
            .missing_argument => 2,
            .file_not_found => 3,
            .io_error => 4,
            .permission_denied => 5,
        };
    }
};

/// Context for error messages with optional suggestions
pub const ErrorContext = struct {
    /// Command that was being executed
    command: []const u8 = "",

    /// Suggested alternative command
    suggestion: ?[]const u8 = null,

    /// Commands similar to the one that failed
    similar_commands: []const []const u8 = &.{},

    /// Additional error details
    details: []const u8 = "",
};

/// ANSI color codes
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const GOLD = "\x1b[38;5;220m";
const GRAY = "\x1b[90m";
const RESET = "\x1b[0m";

/// Print colored error message with optional suggestions
pub fn printError(err: TriError, ctx: ErrorContext) void {
    // Print error header in RED
    std.debug.print("{s}×{s} {s}{s}", .{ RED, RESET, err.message(), RED });

    // Print command that failed
    if (ctx.command.len > 0) {
        std.debug.print(": '{s}'", .{ctx.command});
    }
    std.debug.print("{s}\n", .{RESET});

    // Print suggestion if available
    if (ctx.suggestion) |sug| {
        std.debug.print("{s}→ {s}{s}\n", .{ GOLD, sug, RESET });
    }

    // Print details if available
    if (ctx.details.len > 0) {
        std.debug.print("\n", .{});
        std.debug.print("{s}{s}{s}\n", .{ GRAY, ctx.details, RESET });
    }

    // Print "Did you mean?" suggestions
    if (ctx.similar_commands.len > 0) {
        std.debug.print("\n", .{});
        std.debug.print("{s}Did you mean?{s}\n", .{ CYAN, RESET });
        for (ctx.similar_commands, 0..) |cmd, i| {
            std.debug.print("  {d}. tri {s}\n", .{ i + 1, cmd });
        }
    }
}

/// Print success message
pub fn printSuccess(msg: []const u8) void {
    std.debug.print("{s}✓{s} {s}\n", .{ GREEN, RESET, msg });
}

/// Print warning message
pub fn printWarning(msg: []const u8) void {
    std.debug.print("{s}⚠{s} {s}\n", .{ YELLOW, RESET, msg });
}

/// Print info message
pub fn printInfo(msg: []const u8) void {
    std.debug.print("{s}ℹ{s} {s}\n", .{ CYAN, RESET, msg });
}

/// Handle unknown command with suggestions
pub fn handleUnknownCommand(registry: anytype, command: []const u8) !void {
    const similar = if (@hasField(@TypeOf(registry), "findSimilar"))
        try registry.findSimilar(command, 3)
    else
        &.{};

    printError(.command_not_found, .{
        .command = command,
        .suggestion = if (similar.len > 0) "Check your spelling" else null,
        .similar_commands = similar,
        .details = "Type 'tri help' to see all available commands",
    });
}

// ════════════════════════════════════════════════════════════════════
// TESTS
// ══════════════════════════════════════════════════════════════════

test "TriError: message returns correct strings" {
    try std.testing.expectEqualStrings("Command not found", TriError.command_not_found.message());
    try std.testing.expectEqualStrings("Invalid arguments provided", TriError.invalid_arguments.message());
    try std.testing.expectEqualStrings("Required argument missing", TriError.missing_argument.message());
    try std.testing.expectEqualStrings("File not found", TriError.file_not_found.message());
    try std.testing.expectEqualStrings("Input/output error", TriError.io_error.message());
    try std.testing.expectEqualStrings("Permission denied", TriError.permission_denied.message());
}

test "TriError: toExitCode correct mapping" {
    try std.testing.expectEqual(@as(u8, 1), TriError.command_not_found.toExitCode());
    try std.testing.expectEqual(@as(u8, 2), TriError.invalid_arguments.toExitCode());
    try std.testing.expectEqual(@as(u8, 2), TriError.missing_argument.toExitCode());
    try std.testing.expectEqual(@as(u8, 3), TriError.file_not_found.toExitCode());
    try std.testing.expectEqual(@as(u8, 4), TriError.io_error.toExitCode());
    try std.testing.expectEqual(@as(u8, 5), TriError.permission_denied.toExitCode());
}

test "ErrorContext: defaults" {
    const ctx = ErrorContext{};
    try std.testing.expectEqual(@as(usize, 0), ctx.command.len);
    try std.testing.expectEqual(@as(?[]const u8, null), ctx.suggestion);
    try std.testing.expectEqual(@as(usize, 0), ctx.similar_commands.len);
    try std.testing.expectEqual(@as(usize, 0), ctx.details.len);
}

test "ErrorContext: with values" {
    const ctx = ErrorContext{
        .command = "invalid",
        .suggestion = "valid",
        .similar_commands = &.{ "alt1", "alt2" },
        .details = "Check your spelling",
    };

    try std.testing.expectEqualStrings("invalid", ctx.command);
    try std.testing.expectEqualStrings("valid", ctx.suggestion orelse "");
    try std.testing.expectEqual(@as(usize, 2), ctx.similar_commands.len);
    try std.testing.expectEqualStrings("Check your spelling", ctx.details);
}

test "printError: compiles and runs" {
    const ctx = ErrorContext{
        .command = "test",
        .details = "Additional info",
    };
    // Just verify it compiles and runs without panic
    printError(.command_not_found, ctx);
}

test "printSuccess: compiles and runs" {
    printSuccess("Operation completed");
}

test "printWarning: compiles and runs" {
    printWarning("This is a warning");
}

test "printInfo: compiles and runs" {
    printInfo("Information message");
}
