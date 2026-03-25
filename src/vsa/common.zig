// 🤖 TRINITY v0.11.0: Suborbital Order
// Common types and imports for VSA module
//
// Types inlined from hybrid.zig to avoid module ownership conflict
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// Inlined types from hybrid.zig
pub const MAX_TRITS = 59049; // 3^10
pub const TRITS_PER_BYTE = 5;
pub const MAX_PACKED_BYTES = (MAX_TRITS + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
pub const Trit = i8;

// SIMD types
pub const Vec32i8 = @Vector(32, i8);
pub const Vec32i16 = @Vector(32, i16);
pub const SIMD_WIDTH = 32;
pub const SIMD_CHUNKS = MAX_TRITS / SIMD_WIDTH;

// SearchResult type for semantic search
pub const SearchResult = struct {
    index: usize,
    similarity: f64,
};

// HybridBigInt is NOT re-exported here to avoid module ownership conflict.
// Use @import("hybrid").HybridBigInt directly when needed.

// φ² + 1/φ² = 3 | TRINITY
