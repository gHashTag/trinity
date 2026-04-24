// 🤖 TRINITY v0.11.0: Suborbital Order
// Common types and imports for VSA module

const std = @import("std");
const tvc_hybrid = @import("../hybrid.zig");

pub const HybridBigInt = tvc_hybrid.HybridBigInt;
pub const Trit = tvc_hybrid.Trit;
pub const Vec32i8 = tvc_hybrid.Vec32i8;
pub const SIMD_WIDTH = tvc_hybrid.SIMD_WIDTH;
pub const MAX_TRITS = tvc_hybrid.MAX_TRITS;
pub const MAX_PACKED_BYTES = tvc_hybrid.MAX_PACKED_BYTES;

pub const SearchResult = struct {
    index: usize,
    similarity: f64,
};

// φ² + 1/φ² = 3 | TRINITY
