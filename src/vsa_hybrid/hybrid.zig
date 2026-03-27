// VSA Hybrid Module — Self-contained HybridBigInt for codegen
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const bigint_mod = @import("bigint.zig");
const trit_packed = @import("packed_trit.zig");
const hybrid_impl = @import("hybrid_impl.zig");

pub const HybridBigInt = hybrid_impl.HybridBigInt;
pub const Trit = hybrid_impl.Trit;
pub const Vec32i8 = hybrid_impl.Vec32i8;
pub const Vec32i16 = hybrid_impl.Vec32i16;
pub const SIMD_WIDTH = hybrid_impl.SIMD_WIDTH;
pub const MAX_TRITS = hybrid_impl.MAX_TRITS;
pub const StorageMode = hybrid_impl.StorageMode;

// Re-export packed operations
pub const encodePack = trit_packed.encodePack;
pub const decodePack = trit_packed.decodePack;

// Re-export bigint operations
pub const BigInt = bigint_mod.BigInt;
pub const fromI64 = bigint_mod.fromI64;
pub const toI64 = bigint_mod.toI64;
