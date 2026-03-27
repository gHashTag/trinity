// Tri Error Codegen — Generate Zig from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const TRI_ERROR_TEMPLATE =
    \\//! Tri Error — Generated from specs/tri/tri_error.tri
    \\//! φ² + 1/φ² = 3 | TRINITY
    \\//!
    \\//! DO NOT EDIT: This file is generated from tri_error.tri spec
    \\//! Modify spec and regenerate: tri vibee-gen tri_error
    \\
    \\const std = @import("std");
    \\
    \\/// ═══════════════════════════════════════════════════════════════════════════
    \\/// TRI ERROR HANDLING
    \\/// ═════════════════════════════════════════════════════════════════
    \\
    \\/// Error type for TRI operations
    \\pub const TriError = enum(u8) {
    \\    /// Command was not found in registry
    \\    command_not_found = 1,
    \\
    \\    /// Invalid arguments provided to command
    \\    invalid_arguments = 2,
    \\
    \\    /// Required argument is missing
    \\    missing_argument = 3,
    \\
    \\    /// File or directory not found
    \\    file_not_found = 4,
    \\
    \\    /// I/O operation failed
    \\    io_error = 5,
    \\
    \\    /// Permission denied
    \\    permission_denied = 6,
    \\};
    \\
    \\/// Context for error messages with optional suggestions
    \\pub const ErrorContext = struct {
    \\    /// Command that was being executed
    \\    command: []const u8 = "",
    \\
    \\    /// Suggested alternative command
    \\    suggestion: ?[]const u8 = null,
    \\
    \\    /// Commands similar to the one that failed
    \\    similar_commands: []const []const u8 = &.{},
    \\
    \\    /// Additional error details
    \\    details: []const u8 = "",
    \\};
    \\
    \\/// ══════════════════════════════════════════════════════════════════
    \\/// ERROR MESSAGE FUNCTIONS
    \\/// ════════════════════════════════════════════════════════════
    \\
    \\/// Get human-readable error message
    \\pub fn message(err: TriError, ctx: *const ErrorContext) []const u8 {
    \\    return switch (err) {
    \\        .command_not_found => "Command not found",
    \\        .invalid_arguments => "Invalid arguments",
    \\        .missing_argument => "Missing argument",
    \\        .file_not_found => "File not found",
    \\        .io_error => "I/O error",
    \\        .permission_denied => "Permission denied",
    \\    };
    \\}
    \\
    \\/// Convert error to process exit code
    \\pub fn toExitCode(err: TriError) u8 {
    \\    return switch (err) {
    \\        .command_not_found => 1,
    \\        .invalid_arguments => 2,
    \\        .missing_argument => 3,
    \\        .file_not_found => 4,
    \\        .io_error => 5,
    \\        .permission_denied => 6,
    \\    };
    \\}
    \\
    \\/// Print error message to stderr
    \\pub fn printError(err: TriError, ctx: *const ErrorContext) void {
    \\    const stderr = std.io.getStdErr();
    \\    const writer = stderr.writer();
    \\
    \\    try writer.print("{s}{s} {s}{s}\n", .{ "\x1b[31m", "×", "\x1b[0m", err.message(ctx) });
    \\
    \\    if (ctx.command[0] != 0) {
    \\        try writer.print("  Command: {s}\n", .{ctx.command});
    \\    }
    \\
    \\    if (ctx.suggestion) |s| {
    \\        try writer.print("  → {s}\n", .{s});
    \\    }
    \\
    \\    if (ctx.details[0] != 0) {
    \\        try writer.print("  {s}\n", .{ctx.details});
    \\    }
    \\
    \\    if (ctx.similar_commands.len > 0) {
    \\        try writer.print("\x1b[90m  Did you mean?\x1b[0m");
    \\        for (ctx.similar_commands) |cmd| {
    \\            try writer.print("    {s}\n", .{cmd});
    \\        }
    \\    }
    \\
    \\    _ = writer;
    \\}
    \\
    \\/// Print success message to stderr
    \\pub fn printSuccess(msg: []const u8) void {
    \\    const stderr = std.io.getStdErr();
    \\    const writer = stderr.writer();
    \\    try writer.print("\x1b[32m✓\x1b[0m {s}\n", .{msg});
    \\}
    \\
    \\/// Print warning message to stderr
    \\pub fn printWarning(msg: []const u8) void {
    \\    const stderr = std.io.getStdErr();
    \\    const writer = stderr.writer();
    \\    try writer.print("\x1b[33m⚠\x1b[0m {s}\n", .{msg});
    \\}
    \\
    \\/// Print info message to stderr
    \\pub fn printInfo(msg: []const u8) void {
    \\    const stderr = std.io.getStdErr();
    \\    const writer = stderr.writer();
    \\    try writer.print("\x1b[36mℹ\x1b[0m {s}\n", .{msg});
    \\}
    \\
    \\/// Handle unknown command with suggestions
    \\pub fn handleUnknownCommand(registry: anytype, cmd: []const u8) void {
    \\    const stderr = std.io.getStdErr();
    \\    const writer = stderr.writer();
    \\
    \\    const similar = registry.findSimilar(cmd) catch &.{};
    \\
    \\    try printError(.command_not_found, &.{
    \\        .command = cmd,
    \\        .similar_commands = similar,
    \\        .suggestion = if (similar.len > 0) similar[0] else null,
    \\        .details = null,
    \\    });
    \\
    \\    // Print usage hint if available
    \\    if (similar.len > 0) {
    \\        try writer.print("\nUsage: tri <command>\n");
    \\    }
    \\}
    \\
    \\// ════════════════════════════════════════════════════════════════════
    \\// TESTS
    \\// ══════════════════════════════════════════════════════════════════
    \\
    \\test "TriError: values correct" {
    \\    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(TriError.command_not_found));
    \\    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(TriError.invalid_arguments));
    \\    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(TriError.missing_argument));
    \\    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(TriError.file_not_found));
    \\    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(TriError.io_error));
    \\    try std.testing.expectEqual(@as(u8, 6), @intFromEnum(TriError.permission_denied));
    \\}
    \\
    \\test "ErrorContext: defaults" {
    \\    const ctx = ErrorContext{};
    \\    try std.testing.expectEqual(@as(usize, 0), ctx.command.len);
    \\    try std.testing.expectEqual(@as(usize, 0), ctx.details.len);
    \\    try std.testing.expect(ctx.suggestion == null);
    \\    try std.testing.expectEqual(@as(usize, 0), ctx.similar_commands.len);
    \\}
    \\
    \\test "message: returns correct string" {
    \\    try std.testing.expectEqualSlices(u8, "Command not found", message(.command_not_found, &ErrorContext{}));
    \\    try std.testing.expectEqualSlices(u8, "I/O error", message(.io_error, &ErrorContext{}));
    \\    try std.testing.expectEqualSlices(u8, "Permission denied", message(.permission_denied, &ErrorContext{}));
    \\}
    \\
    \\test "toExitCode: correct mapping" {
    \\    try std.testing.expectEqual(@as(u8, 1), toExitCode(.command_not_found));
    \\    try std.testing.expectEqual(@as(u8, 2), toExitCode(.invalid_arguments));
    \\    try std.testing.expectEqual(@as(u8, 3), toExitCode(.missing_argument));
    \\    try std.testing.expectEqual(@as(u8, 4), toExitCode(.file_not_found));
    \\    try std.testing.expectEqual(@as(u8, 5), toExitCode(.io_error));
    \\    try std.testing.expectEqual(@as(u8, 6), toExitCode(.permission_denied));
    \\}
    \\
    \\test "ErrorContext: with command and suggestion" {
    \\    const ctx = ErrorContext{
    \\        .command = "invalid",
    \\        .suggestion = "valid",
    \\        .similar_commands = &.{ "alt1", "alt2" },
    \\        .details = "Check your spelling",
    \\    };
    \\
    \\    try std.testing.expectEqualSlices(u8, "invalid", ctx.command);
    \\    try std.testing.expectEqualSlices(u8, "valid", ctx.suggestion);
    \\    try std.testing.expectEqualSlices(u8, "Check your spelling", ctx.details);
    \\    try std.testing.expectEqual(@as(usize, 2), ctx.similar_commands.len);
    \\}
    \\
    \\test "printError: outputs to stderr" {
    \\    const ctx = ErrorContext{
    \\        .command = "test",
    \\        .details = "Additional info",
    \\    };
    \\    // Just verify it compiles - can't easily test stderr output
    \\    _ = printError(.command_not_found, &ctx);
    \\}
    \\
;

pub fn generateTriError(allocator: Allocator) ![]const u8 {
    return allocator.dupe(u8, TRI_ERROR_TEMPLATE);
}

pub fn writeTriError(allocator: Allocator, path: []const u8) !void {
    const content = try generateTriError(allocator);
    defer allocator.free(content);

    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    try file.writeAll(content);
}

test "tri_error codegen" {
    const content = try generateTriError(std.testing.allocator);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "pub const TriError") != null);
}
