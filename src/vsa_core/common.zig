// VSA Core — Common Types
// Pure types, no HybridBigInt dependency
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// Basic ternary types
pub const MAX_TRITS = 59049; // 3^10
pub const TRITS_PER_BYTE = 5;
pub const MAX_PACKED_BYTES = (MAX_TRITS + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
pub const Trit = i8;

// SIMD types for parallel operations
pub const Vec32i8 = @Vector(32, i8);
pub const Vec32i16 = @Vector(32, i16);
pub const Vec32i32 = @Vector(32, i32);
pub const SIMD_WIDTH = 32;
pub const SIMD_CHUNKS = MAX_TRITS / SIMD_WIDTH;

// SearchResult type for semantic search
pub const SearchResult = struct {
    index: usize,
    similarity: f64,
};

test "Trit range" {
    const t: Trit = 0;
    try std.testing.expect(@as(i8, 0) == t);
}

test "SIMD vectors" {
    const v: Vec32i8 = @splat(1);
    try std.testing.expectEqual(@as(i8, 1), v[0]);
}
