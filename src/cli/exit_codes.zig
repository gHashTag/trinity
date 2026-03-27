// Exit Codes Selector — Self-hosted from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const gen = @import("gen_exit_codes.zig");

// Re-export all types and functions
pub const ExitCode = gen.ExitCode;
pub const exitWithCode = gen.exitWithCode;
pub const exitInternalError = gen.exitInternalError;
