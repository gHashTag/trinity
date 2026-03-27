//! VSA Core Common — Generated from specs/vsa/common.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from common.tri spec
//!
//! Core type definitions for VSA operations

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

/// Balanced ternary value {-1, 0, 1}
pub const Trit = i8;

/// SIMD vector width (32 trits)
pub const SIMD_WIDTH: usize = 32;

/// 32-bit signed integer vector
pub const Vec32i8 = @Vector(32, i8);

/// 32-bit signed integer vector (for accumulation)
pub const Vec32i16 = @Vector(32, i16);

/// Search result struct
pub const SearchResult = struct {
    index: usize,
    similarity: f64,
};

/// Trit range check
pub const TritRange = struct {
    min: Trit,
    max: Trit,

    pub fn contains(self: *const TritRange, value: Trit) bool {
        return value >= self.min and value <= self.max;
    }

    pub fn clamp(self: *const TritRange, value: Trit) Trit {
        if (value < self.min) return self.min;
        if (value > self.max) return self.max;
        return value;
    }
};

/// Trit constants
pub const NEGATIVE: Trit = -1;
pub const ZERO: Trit = 0;
pub const POSITIVE: Trit = 1;

// ============================================================================
// TRIT UTILITIES
// ============================================================================

/// Check if trit is negative
pub fn isNegative(t: Trit) bool {
    return t < 0;
}

/// Check if trit is zero
pub fn isZero(t: Trit) bool {
    return t == 0;
}

/// Check if trit is positive
pub fn isPositive(t: Trit) bool {
    return t > 0;
}

/// Check if trit is non-zero
pub fn isNonZero(t: Trit) bool {
    return t != 0;
}

/// Get trit value as integer
pub fn tritValue(t: Trit) i8 {
    return t;
}

/// Create trit from integer with clamping
pub fn tritFromInt(i: i8) Trit {
    if (i < -1) return NEGATIVE;
    if (i > 1) return POSITIVE;
    return @as(Trit, @intCast(i));
}

/// Check if trit is in valid range
pub fn isTritValid(t: Trit) bool {
    return t >= NEGATIVE and t <= POSITIVE;
}

/// Normalize trit to valid range
pub fn normalizeTrit(t: Trit) Trit {
    if (t < NEGATIVE) return NEGATIVE;
    if (t > POSITIVE) return POSITIVE;
    return t;
}

/// Count non-zero trits in a slice
pub fn countNonZero(trits: []const Trit) usize {
    var count: usize = 0;
    for (trits) |t| {
        if (t != 0) count += 1;
    }
    return count;
}

/// Check if all trits are the same value
pub fn allSame(trits: []const Trit) bool {
    if (trits.len == 0) return true;
    const first = trits[0];
    for (trits[1..]) |t| {
        if (t != first) return false;
    }
    return true;
}

/// Count occurrences of a specific trit value
pub fn countTrit(trits: []const Trit, target: Trit) usize {
    var count: usize = 0;
    for (trits) |t| {
        if (t == target) count += 1;
    }
    return count;
}

/// Create TritRange
pub const ValidRange = TritRange{ .min = NEGATIVE, .max = POSITIVE };

// ============================================================================
// SIMD UTILITIES
// ============================================================================

/// Broadcast a trit value to a vector
pub fn broadcastTrit(t: Trit) Vec32i8 {
    return @as(Vec32i8, @splat(t));
}

/// Load trits from slice into vector
pub fn loadTrits(trits: []const Trit) Vec32i8 {
    var result: Vec32i8 = @as(Vec32i8, @splat(ZERO));
    const len = @min(SIMD_WIDTH, trits.len);

    var i: usize = 0;
    while (i < len) : (i += 1) {
        result[i] = trits[i];
    }

    return result;
}

/// Store vector to trits slice
pub fn storeTrits(vec: Vec32i8, trits: []Trit) void {
    const len = @min(SIMD_WIDTH, trits.len);

    var i: usize = 0;
    while (i < len) : (i += 1) {
        trits[i] = vec[i];
    }
}

// ============================================================================
// TESTS
// ============================================================================

test "VSA Common: Trit range" {
    const range = ValidRange;

    try std.testing.expect(range.contains(-1));
    try std.testing.expect(range.contains(0));
    try std.testing.expect(range.contains(1));
    try std.testing.expect(!range.contains(2));
    try std.testing.expect(!range.contains(-2));

    try std.testing.expectEqual(@as(Trit, -1), range.clamp(-2));
    try std.testing.expectEqual(@as(Trit, 0), range.clamp(0));
    try std.testing.expectEqual(@as(Trit, 1), range.clamp(2));
}

test "VSA Common: Trit predicates" {
    try std.testing.expect(isNegative(-1));
    try std.testing.expect(isNegative(0) == false);
    try std.testing.expect(isNegative(1) == false);

    try std.testing.expect(isZero(0));
    try std.testing.expect(isZero(-1) == false);
    try std.testing.expect(isZero(1) == false);

    try std.testing.expect(isPositive(1));
    try std.testing.expect(isPositive(0) == false);
    try std.testing.expect(isPositive(-1) == false);

    try std.testing.expect(isNonZero(-1));
    try std.testing.expect(isNonZero(1));
    try std.testing.expect(isNonZero(0) == false);
}

test "VSA Common: Trit conversion" {
    try std.testing.expectEqual(@as(i8, -1), tritValue(-1));
    try std.testing.expectEqual(@as(i8, 0), tritValue(0));
    try std.testing.expectEqual(@as(i8, 1), tritValue(1));

    try std.testing.expectEqual(@as(Trit, -1), tritFromInt(-2));
    try std.testing.expectEqual(@as(Trit, -1), tritFromInt(-1));
    try std.testing.expectEqual(@as(Trit, 0), tritFromInt(0));
    try std.testing.expectEqual(@as(Trit, 1), tritFromInt(1));
    try std.testing.expectEqual(@as(Trit, 1), tritFromInt(2));
}

test "VSA Common: isTritValid" {
    try std.testing.expect(isTritValid(-1));
    try std.testing.expect(isTritValid(0));
    try std.testing.expect(isTritValid(1));
    try std.testing.expect(!isTritValid(2));
    try std.testing.expect(!isTritValid(-2));
}

test "VSA Common: normalizeTrit" {
    try std.testing.expectEqual(@as(Trit, -1), normalizeTrit(-2));
    try std.testing.expectEqual(@as(Trit, -1), normalizeTrit(-1));
    try std.testing.expectEqual(@as(Trit, 0), normalizeTrit(0));
    try std.testing.expectEqual(@as(Trit, 1), normalizeTrit(1));
    try std.testing.expectEqual(@as(Trit, 1), normalizeTrit(2));
}

test "VSA Common: countNonZero" {
    const trits = [_]Trit{ -1, 0, 1, -1, 0 };
    try std.testing.expectEqual(@as(usize, 3), countNonZero(&trits));
}

test "VSA Common: allSame" {
    const all_pos = [_]Trit{ 1, 1, 1 };
    const mixed = [_]Trit{ -1, 0, 1 };

    try std.testing.expect(allSame(&all_pos));
    try std.testing.expect(!allSame(&mixed));
}

test "VSA Common: countTrit" {
    const trits = [_]Trit{ -1, -1, 0, 1, 1 };
    try std.testing.expectEqual(@as(usize, 2), countTrit(&trits, -1));
    try std.testing.expectEqual(@as(usize, 1), countTrit(&trits, 0));
    try std.testing.expectEqual(@as(usize, 2), countTrit(&trits, 1));
}

test "VSA Common: broadcastTrit" {
    const vec = broadcastTrit(1);

    var i: usize = 0;
    while (i < SIMD_WIDTH) : (i += 1) {
        try std.testing.expectEqual(@as(i8, 1), vec[i]);
    }
}

test "VSA Common: Vec32i8 type" {
    try std.testing.expectEqual(@as(usize, 32), @typeInfo(Vec32i8).vector.len);
}

test "VSA Common: SearchResult" {
    const result = SearchResult{ .index = 5, .similarity = 0.95 };

    try std.testing.expectEqual(@as(usize, 5), result.index);
    try std.testing.expectApproxEqAbs(@as(f64, 0.95), result.similarity, 0.001);
}
