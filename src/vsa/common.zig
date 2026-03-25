// 🤖 TRINITY v0.11.0: Suborbital Order
// Common types and imports for VSA module

const std = @import("std");

// Import hybrid types through named module (if available) or direct import
// This file is part of vsa module, which re-exports these types
const tvc_hybrid = @import("hybrid");  // Uses named module

pub const HybridBigInt = tvc_hybrid.HybridBigInt;
pub const Trit = tvc_hybrid.Trit;
pub const Vec32i8 = tvc_hybrid.Vec32i8;
pub const SIMD_WIDTH = tvc_hybrid.SIMD_WIDTH;
pub const MAX_TRITS = tvc_hybrid.MAX_TRITS;

pub const SearchResult = struct {
    index: usize,
    similarity: f64,
};

// φ² + 1/φ² = 3 | TRINITY
