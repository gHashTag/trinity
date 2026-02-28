// VIBEE BOGATYR PLUGIN INTERFACE - Core Validator Architecture
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Allocator = std.mem.Allocator;

/// [CYR:[EN]]towith[EN] in[EN]andyes[EN]andand - [CYR:[EN]]and[EN] data for inwith[EN] [CYR:[EN]]
pub const ValidationContext = struct {
    allocator: Allocator,
    spec_path: []const u8,
    source: []const u8,
    config: ValidatorConfig,

    // AST (if [CYR:[EN]] with[CYR:[EN]]with[EN])
    ast: ?*const struct {
        nodes: []const AstNode,
    },

    // [CYR:[EN]]and[EN] withand[EN]in[CYR:[EN]]in (if [CYR:[EN]] bywith[CYR:[EN]]on)
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

/// Result [CYR:[EN]]in[EN]toand [CYR:[EN]]
pub const BogatyrVerdict = enum {
    Pass, // ✅ Check [CYR:[EN]]
    Fail, // ❌ Check not [CYR:[EN]]
    Warning, // ⚠️ [CYR:[EN]]before[EN]and[EN]
    Skip, // ⊘ [CYR:[EN]] [CYR:[EN]]
};

/// [EN]and[EN]to[EN] in[EN]andyes[EN]andand
pub const ValidationError = struct {
    code: []const u8,
    message: []const u8,
    severity: BogatyrVerdict,
    line: usize,
    column: usize,
};

/// [CYR:[EN]]andtoand in[EN]by[EN]not[EN]and[EN] [CYR:[EN]]
pub const BogatyrMetrics = struct {
    duration_ns: i64,
    checks_performed: usize,
};

/// [CYR:[EN]]with [CYR:[EN]] - each [CYR:[EN]] [CYR:[EN]]and[CYR:[EN]] this [CYR:[EN]]
pub const BogatyrPlugin = struct {
    name: []const u8,
    version: []const u8,
    category: []const u8,
    priority: u32,

    /// [CYR:[EN]]to[EN]and[EN] in[EN]andyes[EN]andand - [CYR:[EN]]and[CYR:[EN]]with[EN] to[CYR:[EN]] [CYR:[EN]]
    validate: *const fn (*const ValidationContext) anyerror!BogatyrResult,
};

/// Result [CYR:[EN]]from[EN] [CYR:[EN]]
pub const BogatyrResult = struct {
    verdict: BogatyrVerdict,
    errors: []const ValidationError,
    metrics: BogatyrMetrics,
};

/// [EN]withby[CYR:[EN]] [EN]and[EN]
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

/// Creates [EN]and[EN]to[EN] in[EN]andyes[EN]andand
pub fn createError(allocator: Allocator, code: []const u8, message: []const u8, line: usize, column: usize) !ValidationError {
    return ValidationError{
        .code = try allocator.dupe(u8, code),
        .message = try allocator.dupe(u8, message),
        .severity = .Fail,
        .line = line,
        .column = column,
    };
}
