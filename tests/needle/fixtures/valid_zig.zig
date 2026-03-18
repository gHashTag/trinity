// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE E2E Test Fixture - Valid Zig Code
// ═══════════════════════════════════════════════════════════════════════════════
//
// This file contains valid Zig code for testing quality gates and search.
//
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Simple arithmetic function for testing
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Function with multiple parameters
pub fn calculate(x: i32, y: i32, multiplier: f32) f32 {
    const sum = @as(f32, @floatFromInt(x + y));
    return sum * multiplier;
}

/// Struct definition
pub const Point = struct {
    x: f32,
    y: f32,

    pub fn distance(self: Point, other: Point) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return @sqrt(dx * dx + dy * dy);
    }
};

/// Enum for testing
pub const Status = enum {
    ok,
    err, // 'error' is a reserved keyword in Zig
    pending,
};

/// Error set for testing
pub const MathError = error{
    DivisionByZero,
    Overflow,
    Underflow,
};

/// Function with error handling
pub fn safeDivide(a: i32, b: i32) !i32 {
    if (b == 0) return MathError.DivisionByZero;
    return @divExact(a, b);
}

/// Loop for testing search patterns
pub fn sumArray(items: []const i32) i32 {
    var sum: i32 = 0;
    for (items) |item| {
        sum += item;
    }
    return sum;
}

/// Generic function
pub fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

// Test that this file parses correctly
test "valid_zig fixture" {
    try std.testing.expectEqual(@as(i32, 5), add(2, 3));
}
