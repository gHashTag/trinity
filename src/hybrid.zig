// TVC HybridBigInt - Optimal Memory/Speed Trade-off
// Uses packed storage, unpacked computation with SIMD acceleration
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
//
//! THIN WRAPPER: Re-exports from zig-golden-float package
//! (Package exports via .ternary module)

const std = @import("std");

// Import from golden-float package
const gf = @import("golden-float");

// Re-export ternary types from package (zig-golden-float API update)
pub const bigint = gf.ternary_primitives; // TVCBigInt
pub const packed_trit = gf.packed_trit;

// Re-export ternary module symbols (using gf.bigint module)
pub const ternary = gf.bigint;
pub const HybridBigInt = gf.bigint.HybridBigInt;
pub const TritVector = gf.bigint.TritVector;
pub const SIMD = gf.bigint.SIMD;

// Re-export core types for convenience
pub const Trit = gf.ternary_primitives.Trit;
pub const MAX_TRITS = 59049; // HybridBigInt max: 3^10 - 59049 trits
pub const TRITS_PER_BYTE = gf.packed_trit.TRITS_PER_BYTE;

// Keep Trinity-specific benchmarks (if any)
pub fn runBenchmarks() void {
    _ = gf; // Mark as used
    // Benchmarks moved to package
}
