// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Common Types
// ═══════════════════════════════════════════════════════════════════════════════
// Core type definitions for VSA operations
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

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

test "Trit range" {
    const t1: Trit = -1;
    const t2: Trit = 0;
    const t3: Trit = 1;

    try std.testing.expectEqual(@as(i8, -1), t1);
    try std.testing.expectEqual(@as(i8, 0), t2);
    try std.testing.expectEqual(@as(i8, 1), t3);
}

test "SIMD vectors" {
    const v: Vec32i8 = @splat(1);
    try std.testing.expectEqual(@as(i8, 1), v[0]);
    try std.testing.expectEqual(@as(i8, 1), v[31]);
}
