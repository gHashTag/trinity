//! TRI Error — Generated from specs/tri/tri_error.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// ERROR TYPES
// ============================================================================

/// Core TRI error types
pub const TriError = enum(u8) {
    command_not_found,
    invalid_arguments,
    missing_argument,
    file_not_found,
    io_error,
    permission_denied,
    parse_error,
    validation_error,
    out_of_memory,
};

// ============================================================================
// CONSTANTS
// ============================================================================

pub const EXIT_SUCCESS: u8 = 0;
pub const EXIT_ERROR: u8 = 1;
pub const EXIT_COMMAND_NOT_FOUND: u8 = 127;

// ============================================================================
// ERROR FUNCTIONS
// ============================================================================

/// Get human-readable error message
pub fn getMessage(err: TriError) []const u8 {
    return switch (err) {
        TriError.command_not_found => "Command not found",
        TriError.invalid_arguments => "Invalid arguments",
        TriError.missing_argument => "Missing required argument",
        TriError.file_not_found => "File not found",
        TriError.io_error => "I/O error",
        TriError.permission_denied => "Permission denied",
        TriError.parse_error => "Parse error",
        TriError.validation_error => "Validation error",
        TriError.out_of_memory => "Out of memory",
    };
}

/// Convert error to exit code (1-9)
pub fn toExitCode(err: TriError) u8 {
    return switch (err) {
        TriError.command_not_found => EXIT_COMMAND_NOT_FOUND,
        TriError.out_of_memory => 1,
        TriError.io_error => 1,
        TriError.permission_denied => 1,
        else => EXIT_ERROR,
    };
}

/// Get standard Unix exit code for error
pub fn getExitCode(err: TriError) u8 {
    return toExitCode(err);
}

/// Get suggestion for fixing error
pub fn suggest(err: TriError) []const u8 {
    return switch (err) {
        TriError.command_not_found => "Check the command name and try 'tri help'",
        TriError.invalid_arguments => "Check the arguments for the command",
        TriError.missing_argument => "Provide all required arguments",
        TriError.file_not_found => "Check the file path and permissions",
        TriError.io_error => "Check file permissions and disk space",
        TriError.permission_denied => "Check file permissions",
        TriError.parse_error => "Check the file format and syntax",
        TriError.validation_error => "Check the input values",
        TriError.out_of_memory => "Close other applications and try again",
    };
}

/// Create error context
pub const ErrorContext = struct {
    error_code: TriError,
    message: []const u8,
    suggestion: []const u8,
    details: [][]const u8,

    pub fn init(err: TriError) ErrorContext {
        return .{
            .error_code = err,
            .message = getMessage(err),
            .suggestion = suggest(err),
            .details = &.{},
        };
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Error: getMessage" {
    try std.testing.expectEqualStrings("Command not found", getMessage(TriError.command_not_found));
    try std.testing.expectEqualStrings("Invalid arguments", getMessage(TriError.invalid_arguments));
    try std.testing.expectEqualStrings("Out of memory", getMessage(TriError.out_of_memory));
}

test "Error: toExitCode" {
    try std.testing.expectEqual(@as(u8, 127), toExitCode(TriError.command_not_found));
    try std.testing.expectEqual(@as(u8, 1), toExitCode(TriError.io_error));
    try std.testing.expectEqual(@as(u8, 1), toExitCode(TriError.out_of_memory));
}

test "Error: getExitCode" {
    try std.testing.expectEqual(@as(u8, 127), getExitCode(TriError.command_not_found));
    try std.testing.expectEqual(@as(u8, 1), getExitCode(TriError.io_error));
}

test "Error: suggest" {
    try std.testing.expect(std.mem.indexOf(u8, suggest(TriError.command_not_found), "help") != null);
    try std.testing.expect(std.mem.indexOf(u8, suggest(TriError.out_of_memory), "Close") != null);
}

test "Error: ErrorContext init" {
    const ctx = ErrorContext.init(TriError.command_not_found);
    try std.testing.expectEqual(TriError.command_not_found, ctx.error_code);
    try std.testing.expectEqualStrings("Command not found", ctx.message);
}

test "Error: constants" {
    try std.testing.expectEqual(@as(u8, 0), EXIT_SUCCESS);
    try std.testing.expectEqual(@as(u8, 1), EXIT_ERROR);
    try std.testing.expectEqual(@as(u8, 127), EXIT_COMMAND_NOT_FOUND);
}
