//! Tri Error — Generated from specs/tri/tri_error.tri
//! φ² + 1/φ² = 3 | TRINITY

const gen = @import("gen_error.zig");

pub const TriError = gen.TriError;
pub const ErrorContext = gen.ErrorContext;

// Re-export functions
pub const message = gen.message;
pub const toExitCode = gen.toExitCode;
pub const printError = gen.printError;
pub const printSuccess = gen.printSuccess;
pub const printWarning = gen.printWarning;
pub const printInfo = gen.printInfo;
pub const handleUnknownCommand = gen.handleUnknownCommand;
