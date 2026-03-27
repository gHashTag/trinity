// Exit Codes Codegen — Generate Zig from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const EXIT_CODES_TEMPLATE =
    \\// TRI Exit Codes — Generated from specs/cli/exit_codes.tri
    \\// φ² + 1/φ² = 3 | TRINITY
    \\
    \\const std = @import("std");
    \\
    \\pub const ExitCode = enum(u8) {
    \\    /// Command completed successfully
    \\    success = 0,
    \\    /// Invalid command or arguments
    \\    command_error = 1,
    \\    /// Pre-flight validation failed
    \\    validation_error = 2,
    \\    /// Runtime execution error
    \\    runtime_error = 3,
    \\    /// Command exceeded time limit
    \\    timeout = 4,
    \\    /// Async job failed
    \\    job_failed = 5,
    \\    /// Output generation failed
    \\    artifact_failed = 6,
    \\    /// Internal error (bug)
    \\    internal_error = 7,
    \\};
    \\
    \\/// Exit with the specified exit code
    \\pub fn exitWithCode(code: ExitCode) noreturn {
    \\    std.process.exit(@intFromEnum(code));
    \\}
    \\
    \\/// Exit with internal error code
    \\pub fn exitInternalError() noreturn {
    \\    std.process.exit(@intFromEnum(ExitCode.internal_error));
    \\}
    \\
    \\// ============================================================================
    \\// TESTS
    \\// ============================================================================
    \\
    \\test "exit_codes_values" {
    \\    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(ExitCode.success));
    \\    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(ExitCode.command_error));
    \\    try std.testing.expectEqual(@as(u8, 7), @intFromEnum(ExitCode.internal_error));
    \\    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(ExitCode.timeout));
    \\}
    \\
;

pub fn generateExitCodes(allocator: Allocator) ![]const u8 {
    return allocator.dupe(u8, EXIT_CODES_TEMPLATE);
}

pub fn writeExitCodes(allocator: Allocator, path: []const u8) !void {
    const content = try generateExitCodes(allocator);
    defer allocator.free(content);

    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    try file.writeAll(content);
}

test "exit_codes codegen" {
    const content = try generateExitCodes(std.testing.allocator);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "pub const ExitCode") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "success = 0") != null);
}
