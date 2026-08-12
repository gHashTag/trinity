//! HybridBigInt wrapper — imports from zig-golden-float
//!
//! This module re-exports HybridBigInt from zig-golden-float dependency.

const golden = @import("zig_golden_float");

// Re-export from zig-golden-float
pub const HybridBigInt = golden.bigint.HybridBigInt;
pub const Trit = golden.vsa_common.Trit;
pub const Pack = golden.vsa_common.Pack;
pub const PACK_SIZE = golden.vsa_common.PACK_SIZE;
