// VSA Core — Single Source of Truth for VSA Algorithms
// Anti-Fragile Import Law: one owner, no conflicts
//
// This module contains pure VSA algorithms without HybridBigInt dependency.
// HybridBigInt consumers should use vsa module as glue layer.
//
// φ² + 1/φ² = 3 | TRINITY

pub const common = @import("common.zig");
pub const ops = @import("ops.zig");
pub const sparse = @import("sparse.zig");
pub const encoding = @import("encoding.zig");

// Re-export core types
pub const Trit = common.Trit;
pub const Vec32i8 = common.Vec32i8;
pub const Vec32i16 = common.Vec32i16;
pub const SIMD_WIDTH = common.SIMD_WIDTH;
pub const MAX_TRITS = common.MAX_TRITS;
pub const SearchResult = common.SearchResult;
