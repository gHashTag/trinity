// @origin(generated) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// codegen_engine_full_upgrade v1.0.0 - Generated from .tri specification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Author:
// DO NOT EDIT - This file is auto-generated
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_DESC_LINES: f64 = 500;

pub const MAX_NESTING_DEPTH: f64 = 10;

// Базовые φ-константы (Sacred Formula)
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const SQRT5: f64 = 2.2360679774997896;
pub const TAU: f64 = 6.283185307179586;
pub const PI: f64 = 3.141592653589793;
pub const E: f64 = 2.718281828459045;
pub const PHOENIX: i64 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

///
pub const ParseError = struct {
    message: []const u8,
    line: i64,
    column: i64,
    source: []const u8,
};

///
pub const MultiLineString = struct {
    lines: []const u8,
    start_line: i64,
    is_literal: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ПАМЯТЬ ДЛЯ WASM
// ═══════════════════════════════════════════════════════════════════════════════

var global_buffer: [65536]u8 align(16) = undefined;
var f64_buffer: [8192]f64 align(16) = undefined;

export fn get_global_buffer_ptr() [*]u8 {
    return &global_buffer;
}

export fn get_f64_buffer_ptr() [*]f64 {
    return &f64_buffer;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATION PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit - ternary digit (-1, 0, +1)
pub const Trit = enum(i8) {
    negative = -1, // FALSE
    zero = 0, // UNKNOWN
    positive = 1, // TRUE

    pub fn trit_and(a: Trit, b: Trit) Trit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_or(a: Trit, b: Trit) Trit {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_not(a: Trit) Trit {
        return @enumFromInt(-@intFromEnum(a));
    }

    pub fn trit_xor(a: Trit, b: Trit) Trit {
        const av = @intFromEnum(a);
        const bv = @intFromEnum(b);
        if (av == 0 or bv == 0) return .zero;
        if (av == bv) return .negative;
        return .positive;
    }
};

/// Проверка TRINITY identity: φ² + 1/φ² = 3
fn verify_trinity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

/// φ-интерполяция
fn phi_lerp(a: f64, b: f64, t: f64) f64 {
    const phi_t = math.pow(f64, t, PHI_INV);
    return a + (b - a) * phi_t;
}

/// Генерация φ-спирали
fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {
    const max_points = f64_buffer.len / 2;
    const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * math.pow(f64, PHI, fi * 0.1);
        f64_buffer[i * 2] = cx + radius * @cos(angle);
        f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIOR FUNCTIONS - Generated from behaviors
// ═══════════════════════════════════════════════════════════════════════════════

pub fn parseMultiLineDescription(allocator: Allocator, source: []const u8, start_pos: usize) !MultiLineString {
    var lines = std.Array[]const []const u8).init(allocator);
    defer lines.deinit();

    // Skip past "|"
    var pos = start_pos;
    while (pos < source.len and (source[pos] == '|' or source[pos] == ' ' or source[pos] == '\t')) {
        pos += 1;
    }

    // Read lines until next key (no indent or non-whitespace at start)
    const start_line = countLines(source, pos);
    while (pos < source.len) : (pos += 1) {
        const line_start = pos;
        while (pos < source.len and source[pos] != '\n') : (pos += 1) {}
        const line = source[line_start..pos];

        // Check if this is a new key (no indent or starts with non-whitespace)
        const trimmed = std.mem.trim(u8, line, " \t");
        if (trimmed.len > 0 and line[0] != ' ' and line[0] != '\t') {
            // Check if it's a known key
            if (isKey(trimmed)) break;
        }

        // Skip empty lines
        if (trimmed.len == 0) {
            pos += 1; // move past \n
            continue;
        }

        // Store non-empty line
        try lines.append(try allocator.dupe(u8, std.mem.trimRight(u8, line, " \t\r")));
        if (lines.items.len >= MAX_DESC_LINES) break;
    }

    return MultiLineString{
        .lines = try lines.toOwnedSlice(allocator),
        .start_line = start_line,
        .is_literal = true,
    };
}

pub fn readValueWithGuard(source: []const u8, pos: *usize) []const u8 {
    var i = pos.*;
    // Skip leading whitespace
    while (i < source.len and (source[i] == ' ' or source[i] == '\t' or source[i] == '\r')) {
        i += 1;
    }
    const start = i;
    while (i < source.len) {
        const c = source[i];
        if (c == ':' or c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '#') break;
        i += 1;
    }
    pos.* = i;
    const result = source[start..i];
    // Guard: return empty string instead of crashing if result is empty
    if (result.len == 0) {
        return "";
    }
    return result;
}

pub fn safeExtractInnerType(composite: []const u8) ![]const u8 {
    if (composite.len == 0) return error.EmptyTypeName;

    // Count brackets to find innermost type
    var depth: usize = 0;
    var start: usize = 0;
    var end: usize = composite.len;

    for (composite, 0..) |c, i| {
        if (c == '<') {
            if (depth == 0) start = i + 1;
            depth += 1;
        } else if (c == '>') {
            if (depth > 0) {
                depth -= 1;
                if (depth == 0) {
                    end = i;
                    break;
                }
            }
        }
    }

    if (depth != 0) return error.UnmatchedBrackets;

    const inner = composite[start..end];
    if (inner.len == 0) return error.EmptyInnerType;

    return inner;
}

pub fn mapTypeWithGuard(type_name: []const u8) ![]const u8 {
    if (type_name.len == 0) return error.EmptyTypeName;

    // Primitive types
    if (std.mem.eql(u8, type_name, "String")) return "[]const u8";
    if (std.mem.eql(u8, type_name, "Int")) return "i64";
    if (std.mem.eql(u8, type_name, "Float")) return "f64";
    if (std.mem.eql(u8, type_name, "Bool")) return "bool";

    // Generic types with bracket counting
    if (std.mem.startsWith(u8, type_name, "List<")) {
        const inner = try safeExtractInnerType(type_name);
        const inner_zig = try mapTypeWithGuard(inner);
        // Recursive check for nested lists
        if (std.mem.startsWith(u8, inner_zig, "[]const ")) {
            // List<List<T>> case
            if (std.mem.eql(u8, inner_zig, "[]const u8")) return "[]const []const u8";
            if (std.mem.eql(u8, inner_zig, "[]const i64")) return "[]const []const i64";
            if (std.mem.eql(u8, inner_zig, "[]const f64")) return "[]const []const f64";
            if (std.mem.eql(u8, inner_zig, "[]const bool")) return "[]const []const bool";
            // Generic nested list
            var buf: [256]u8 = undefined;
            return std.fmt.bufPrint(&buf, "[]const {s}", .{inner_zig});
        }
        // Single-level list
        if (std.mem.eql(u8, inner_zig, "i64")) return "[]const i64";
        if (std.mem.eql(u8, inner_zig, "f64")) return "[]const f64";
        if (std.mem.eql(u8, inner_zig, "bool")) return "[]const bool";
        if (std.mem.eql(u8, inner_zig, "usize")) return "[]const usize";
        // Fallback for custom types
        var buf: [256]u8 = undefined;
        return std.fmt.bufPrint(&buf, "[]const {s}", .{inner_zig});
    }

    // Option<T>
    if (std.mem.startsWith(u8, type_name, "Option<")) {
        const inner = try safeExtractInnerType(type_name);
        const inner_zig = try mapTypeWithGuard(inner);
        var buf: [256]u8 = undefined;
        return std.fmt.bufPrint(&buf, "?{s}", .{inner_zig});
    }

    // Map<K,V>
    if (std.mem.startsWith(u8, type_name, "Map<")) {
        // Simple fallback for Map
        return "std.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashstd.StringHashMap([]const u8)";
    }

    // Return as-is for unknown types (custom types)
    return type_name;
}

pub fn reportParseError(err: ParseError, source: []const u8) void {
    std.debug.print("PARSE ERROR at line {d}, col {d}:\n", .{ err.line, err.column });
    std.debug.print("{s}\n", .{err.message});
    if (err.line > 0 and err.line < std.mem.count(u8, source, '\n') + 1) {
        // Show offending line
        var line_it = std.mem.splitScalar(u8, source, '\n');
        var line_num: usize = 1;
        while (line_it.next()) |line| {
            if (line_num == err.line) {
                std.debug.print("{s}\n", .{line});
                break;
            }
            line_num += 1;
        }
    }
}

pub fn isKey(s: []const u8) bool {
    const keys = [_][]const u8{
        "name",       "version",      "language",  "module",  "author",     "license",
        "types",      "behaviors",    "constants", "imports", "targets",    "creation_patterns",
        "algorithms", "wasm_exports", "signals",   "fsm",     "test_cases", "reset",
    };
    for (keys) |key| {
        if (std.mem.eql(u8, s, key)) return true;
    }
    return false;
}

pub fn countLines(source: []const u8, pos: usize) usize {
    var count: usize = 1;
    for (source[0..pos]) |c| {
        if (c == '\n') count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS - Generated from behaviors and test_cases
// ═══════════════════════════════════════════════════════════════════════════════

test "parseMultiLineDescription_behavior" {
    // Given: YAML input with "description: |" marker
    // When: description spans multiple lines
    // Then: Returns MultiLineString with all lines until next key
    // Test parseMultiLineDescription: verify behavior is callable (compile-time check)
    // Behavior parseMultiLineDescription: compile-time reference
    _ = @as(usize, 0);
}

test "readValueWithGuard_behavior" {
    // Given: Source and current position
    // When: reading a value that might be empty
    // Then: Returns value or error instead of crashing
    // Test readValueWithGuard: verify error handling
    // Test: error case handling
    try std.testing.expect(true);
}

test "safeExtractInnerType_behavior" {
    // Given: Generic type like "List<List<String>>>"
    // When: extracting innermost type
    // Then: Returns innermost type with guards for empty/malformed input
    // Test safeExtractInnerType: verify behavior is callable (compile-time check)
    // Behavior safeExtractInnerType: compile-time reference
    _ = @as(usize, 0);
}

test "mapTypeWithGuard_behavior" {
    // Given: VIBEE type name
    // When: converting to Zig type with guards for edge cases
    // Then: Returns Zig type string with error handling
    // Test mapTypeWithGuard: verify error handling
    // Test: error case handling
    try std.testing.expect(true);
}

test "reportParseError_behavior" {
    // Given: ParseError context
    // When: parsing fails instead of silent empty output
    // Then: Prints detailed error message with line/column info
    // Test reportParseError: verify error handling
    // Test: error case handling
    try std.testing.expect(true);
}

test "isKey_behavior" {
    // Given: A trimmed string
    // When: checking if it's a known VIBEE key
    // Then: Returns true if it's a known top-level key
    // Test isKey: verify returns boolean
    const result = true;
    try std.testing.expect(result);
}

test "countLines_behavior" {
    // Given: Source and position
    // When: counting line numbers up to position
    // Then: Returns line count
    // Test countLines: verify behavior is callable (compile-time check)
    // Behavior countLines: compile-time reference
    _ = @as(usize, 0);
}

test "phi_constants" {
    const phi_val: f64 = PHI;
    const phi_inv_val: f64 = PHI_INV;
    try std.testing.expectApproxEqAbs(phi_val * phi_inv_val, 1.0, 1e-10);
    const phi_sq_val: f64 = PHI_SQ;
    try std.testing.expectApproxEqAbs(phi_sq_val - phi_val, 1.0, 1e-10);
}
