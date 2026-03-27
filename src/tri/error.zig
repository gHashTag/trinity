//! TRI Error Module Selector
//! φ² + 1/φ² = 3 | TRINITY

pub const TriError = @import("gen_error.zig").TriError;
pub const EXIT_SUCCESS = @import("gen_error.zig").EXIT_SUCCESS;
pub const EXIT_ERROR = @import("gen_error.zig").EXIT_ERROR;
pub const EXIT_COMMAND_NOT_FOUND = @import("gen_error.zig").EXIT_COMMAND_NOT_FOUND;
pub const getMessage = @import("gen_error.zig").getMessage;
pub const toExitCode = @import("gen_error.zig").toExitCode;
pub const getExitCode = @import("gen_error.zig").getExitCode;
pub const suggest = @import("gen_error.zig").suggest;
pub const ErrorContext = @import("gen_error.zig").ErrorContext;
