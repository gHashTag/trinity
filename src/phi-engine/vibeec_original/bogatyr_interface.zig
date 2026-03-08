// VIBEE BOGATYR PLUGIN INTERFACE - Core Validator Architecture
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Allocator = std.mem.Allocator;

/// towith inandyesand - and data for inwith
pub const ValidationContext = struct {
    allocator: Allocator,
    spec_path: []const u8,
    source: []const u8,
    config: ValidatorConfig,

    // AST (if  with)
    ast: ?*const struct {
        nodes: []const AstNode,
    },

    // and withandinin (if  bywithon)
    symbol_table: ?*const struct {
        symbols: std.StringHashMap(Symbol),
    },
};

pub const ValidatorConfig = struct {
    strict_mode: bool = false,
    warning_as_error: bool = false,
    cache_enabled: bool = true,
    parallel_enabled: bool = true,
    timeout_ms: u32 = 30000,
};

/// Result intoand
pub const BogatyrVerdict = enum {
    Pass, // ✅ Check
    Fail, // ❌ Check not
    Warning, // ⚠️ beforeand
    Skip, // ⊘
};

/// andto inandyesand
pub const ValidationError = struct {
    code: []const u8,
    message: []const u8,
    severity: BogatyrVerdict,
    line: usize,
    column: usize,
};

/// andtoand inbynotand
pub const BogatyrMetrics = struct {
    duration_ns: i64,
    checks_performed: usize,
};

/// with  - each  and this
pub const BogatyrPlugin = struct {
    name: []const u8,
    version: []const u8,
    category: []const u8,
    priority: u32,

    /// toand inandyesand - andwith to
    validate: *const fn (*const ValidationContext) anyerror!BogatyrResult,
};

/// Result from
pub const BogatyrResult = struct {
    verdict: BogatyrVerdict,
    errors: []const ValidationError,
    metrics: BogatyrMetrics,
};

/// withby and
pub const AstNode = struct {
    kind: []const u8,
    value: ?[]const u8,
    line: usize,
};

pub const Symbol = struct {
    name: []const u8,
    kind: []const u8,
    line: usize,
};

/// Creates andto inandyesand
pub fn createError(allocator: Allocator, code: []const u8, message: []const u8, line: usize, column: usize) !ValidationError {
    return ValidationError{
        .code = try allocator.dupe(u8, code),
        .message = try allocator.dupe(u8, message),
        .severity = .Fail,
        .line = line,
        .column = column,
    };
}
