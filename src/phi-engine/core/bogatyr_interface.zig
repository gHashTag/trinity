// VIBEE BOGATYR PLUGIN INTERFACE - Core Validator Architecture
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Validation context - общandе data for inwithех богатырей
pub const ValidationContext = struct {
    allocator: Allocator,
    spec_path: []const u8,
    source: []const u8,
    config: ValidatorConfig,

    // AST (if уже withпарwithен)
    ast: ?*const struct {
        nodes: []const AstNode,
    },

    // Таблandца withandмinолоin (if уже bywithтроеon)
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

/// Результат проinерtoand богатыря
pub const BogatyrVerdict = enum {
    Pass, // ✅ Check прошла
    Fail, // ❌ Check не прошла
    Warning, // ⚠️ Предуbeforeнandе
    Skip, // ⊘ Богатырь пропущен
};

/// Ошandбtoа inалandyesцandand
pub const ValidationError = struct {
    code: []const u8,
    message: []const u8,
    severity: BogatyrVerdict,
    line: usize,
    column: usize,
};

/// Метрandtoand inыbyлненandя богатыря
pub const BogatyrMetrics = struct {
    duration_ns: i64,
    checks_performed: usize,
};

/// Bogatyr interface - each богатырь реалandзует this трейт
pub const BogatyrPlugin = struct {
    name: []const u8,
    version: []const u8,
    category: []const u8,
    priority: u32,

    /// Фунtoцandя inалandyesцandand - реалandзуетwithя toаждым богатырем
    validate: *const fn (*const ValidationContext) anyerror!BogatyrResult,
};

/// Результат рабfromы богатыря
pub const BogatyrResult = struct {
    verdict: BogatyrVerdict,
    errors: []const ValidationError,
    metrics: BogatyrMetrics,
};

/// Вwithbyмогательные тandпы
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

/// Creates ошandбtoу inалandyesцandand
pub fn createError(allocator: Allocator, code: []const u8, message: []const u8, line: usize, column: usize) !ValidationError {
    return ValidationError{
        .code = try allocator.dupe(u8, code),
        .message = try allocator.dupe(u8, message),
        .severity = .Fail,
        .line = line,
        .column = column,
    };
}
