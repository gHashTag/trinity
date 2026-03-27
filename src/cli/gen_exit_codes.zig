// TRI Exit Codes — Generated from specs/cli/exit_codes.tri
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const ExitCode = enum(u8) {
    /// Command completed successfully
    success = 0,
    /// Invalid command or arguments
    command_error = 1,
    /// Pre-flight validation failed
    validation_error = 2,
    /// Runtime execution error
    runtime_error = 3,
    /// Command exceeded time limit
    timeout = 4,
    /// Async job failed
    job_failed = 5,
    /// Output generation failed
    artifact_failed = 6,
    /// Internal error (bug)
    internal_error = 7,
};

/// Exit with the specified exit code
pub fn exitWithCode(code: ExitCode) noreturn {
    std.process.exit(@intFromEnum(code));
}

/// Exit with internal error code
pub fn exitInternalError() noreturn {
    std.process.exit(@intFromEnum(ExitCode.internal_error));
}

// ============================================================================
// TESTS
// ============================================================================

test "exit_codes_values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(ExitCode.success));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(ExitCode.command_error));
    try std.testing.expectEqual(@as(u8, 7), @intFromEnum(ExitCode.internal_error));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(ExitCode.timeout));
}
