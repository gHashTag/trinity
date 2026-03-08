// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Error Handling v2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Enhanced error messages with colors and "did you mean?" suggestions
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const tri_colors = @import("tri_colors.zig");

pub const TriError = enum {
    command_not_found,
    invalid_arguments,
    missing_argument,
    file_not_found,
    io_error,
    permission_denied,

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

pub const ErrorContext = struct {
    command: []const u8 = "",
    suggestion: ?[]const u8 = null,
    similar_commands: []const []const u8 = &.{},
    details: []const u8 = "",
};

/// Print colored error message with optional suggestions
pub fn printError(err: TriError, ctx: ErrorContext) void {
    // Print error header in RED
    tri_colors.printRed("Error: {s}", .{err.message()});

    // Print command that failed
    if (ctx.command.len > 0) {
        std.debug.print(": '{s}'", .{ctx.command});
    }
    std.debug.print("\n", .{});

    // Print suggestion if available
    if (ctx.suggestion) |sug| {
        tri_colors.printGold("→ {s}\n", .{sug});
    }

    // Print details if available
    if (ctx.details.len > 0) {
        std.debug.print("\n", .{});
        tri_colors.printGray("{s}\n", .{ctx.details});
    }

    // Print "Did you mean?" suggestions
    if (ctx.similar_commands.len > 0) {
        std.debug.print("\n", .{});
        tri_colors.printCyan("Did you mean?\n", .{});
        for (ctx.similar_commands, 0..) |cmd, i| {
            std.debug.print("  {d}. tri {s}\n", .{ i + 1, cmd });
        }
    }

    tri_colors.printWhite("", .{}); // Reset color
}

/// Print success message
pub fn printSuccess(msg: []const u8) void {
    tri_colors.printGreen("✓ {s}\n", .{msg});
}

/// Print warning message
pub fn printWarning(msg: []const u8) void {
    tri_colors.printYellow("⚠ {s}\n", .{msg});
}

/// Print info message
pub fn printInfo(msg: []const u8) void {
    tri_colors.printCyan("ℹ {s}\n", .{msg});
}

/// Handle unknown command with suggestions
pub fn handleUnknownCommand(registry: anytype, command: []const u8) !void {
    const similar = try registry.findSimilar(command, 3);

    var details_buf: [256]u8 = undefined;
    const details = std.fmt.bufPrint(&details_buf, "Type 'tri help' to see all available commands", .{}) catch "Use 'tri help' for available commands";

    printError(TriError.command_not_found, .{
        .command = command,
        .suggestion = "Check your spelling",
        .similar_commands = similar,
        .details = details,
    });
}
