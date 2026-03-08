// ═══════════════════════════════════════════════════════════════════════════════
// TRI EXIT CODES
// ═══════════════════════════════════════════════════════════════════════════════
// Standard exit codes for TRI CLI
//
// Exit Codes:
// 0 - success
// 1 - command_error (invalid args, command not found)
// 2 - validation_error (pre-flight checks failed)
// 3 - runtime_error (execution failed)
// 4 - timeout (command exceeded time limit)
// 5 - job_failed (async job failed)
// 6 - artifact_failed (output generation failed)
// 7 - internal_error (bug, unexpected state)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

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
pub fn exitWithCode(code: ExitCode) void {
    std.process.exit(@intFromEnum(code));
}

/// Exit with internal error code
pub fn exitInternalError() void {
    std.process.exit(@intFromEnum(ExitCode.internal_error));
}
