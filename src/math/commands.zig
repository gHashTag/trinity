//! Math Commands Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_commands.zig)
//! DO NOT EDIT: Modify math_commands.tri spec and regenerate

// Types
pub const OutputFormat = @import("gen_commands.zig").OutputFormat;

// Help text
pub const MATH_HELP_TEXT = @import("gen_commands.zig").MATH_HELP_TEXT;

// Parsing functions
pub const parseFlag = @import("gen_commands.zig").parseFlag;
pub const parseFormatFlag = @import("gen_commands.zig").parseFormatFlag;

// Command dispatchers
pub const runMathCommand = @import("gen_commands.zig").runMathCommand;
pub const runConstantsCommand = @import("gen_commands.zig").runConstantsCommand;
pub const runEvalCommand = @import("gen_commands.zig").runEvalCommand;
pub const runPhiCommand = @import("gen_commands.zig").runPhiCommand;
pub const runFibCommand = @import("gen_commands.zig").runFibCommand;
pub const runLucasCommand = @import("gen_commands.zig").runLucasCommand;
pub const runComputeCommand = @import("gen_commands.zig").runComputeCommand;
pub const runSpiralCommand = @import("gen_commands.zig").runSpiralCommand;
pub const runVerifyCommand = @import("gen_commands.zig").runVerifyCommand;
pub const runCompareCommand = @import("gen_commands.zig").runCompareCommand;
pub const runBenchCommand = @import("gen_commands.zig").runBenchCommand;
pub const runIdentitiesCommand = @import("gen_commands.zig").runIdentitiesCommand;
pub const showMathHelp = @import("gen_commands.zig").showMathHelp;
