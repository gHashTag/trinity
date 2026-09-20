//! GoldenFloat — φ-Optimized Zig Kernel for ML
//!
//! **Modules:**
//! - formats: GF16, TF3 number formats
//! - vsa: Vector Symbolic Architecture (bind, bundle, similarity)
//! - ternary: Ternary computing primitives (HybridBigInt, packed trit)
//! - math: Sacred constants (φ, e, π)
//!
//! **Quick Start:**
//! ```zig
//! const golden = @import("golden-float");
//! const gf = golden.formats.GF16.fromF32(3.14159);
//! ```

// ═══════════════════════════════════════════════════════════════════
// PUBLIC API — RE-EXPORTS
// ═══════════════════════════════════════════════════════════════════

/// Number formats: GF16, TF3
pub const formats = @import("formats/golden_float16.zig");

/// GF-T ternary-exponent ladder: GFT4 / GFT8 / GFT16 / GFT32 (+ generic `GFT(E, M)`).
/// ```zig
/// const golden = @import("golden-float");
/// const x = golden.gft.GFT16.fromF32(3.14159);
/// ```
pub const gft = @import("formats/gft.zig");
/// Convenience re-exports of the four GF-T rungs.
pub const GFT4 = gft.GFT4;
pub const GFT8 = gft.GFT8;
pub const GFT16 = gft.GFT16;
pub const GFT32 = gft.GFT32;

/// Binary GF ladder derived from the φ² sizing rule: GF4/8/12/16/20/24/32 (+ `GF(bits)`).
/// GF8/GF16 also have dedicated φ-FMA implementations in `formats`; this is the full
/// ladder / reference for the other rungs.
/// ```zig
/// const golden = @import("golden-float");
/// const x = golden.gf_binary.GF12.fromF32(3.14159);
/// ```
pub const gf_binary = @import("formats/gf_binary.zig");

// ═══════════════════════════════════════════════════════════════
// VSA MODULES
// ═══════════════════════════════════════════════════════════════════

/// Vector Symbolic Architecture core
pub const vsa = @import("vsa/core.zig");

/// VSA common types (Trit, HybridBigInt, SIMD)
pub const vsa_common = @import("vsa/common.zig");

/// HyperVector10K — 10K-dimensional VSA
pub const vsa_10k = @import("vsa/10k_vsa.zig");

/// Holographic Reduced Representations
pub const hrr = @import("vsa/hrr.zig");

/// Lock-free data structures for VSA
pub const vsa_concurrency = @import("vsa/concurrency.zig");

/// FPGA-accelerated VSA operations
pub const fpga_bind = @import("vsa/fpga_bind.zig");

// ═══════════════════════════════════════════════════════════════════
// TERNARY MODULES
// ═════════════════════════════════════════════════════════════════════

/// HybridBigInt — main big integer engine
pub const bigint = @import("ternary/hybrid.zig");

/// Packed trit storage
pub const packed_trit = @import("ternary/packed_trit.zig");

// packed_vsa was reachable from nowhere: not from root, not through
// vsa/core.zig. Its five functions are the packed-representation half of the
// VSA surface, and a downstream package that wanted them had to vendor a copy
// of the file — which is exactly how the copies in this fleet started
// diverging. Same failure as vsa_jit: present, correct, unexported.
pub const packed_vsa = @import("vsa/packed_vsa.zig");

/// Ternary primitives from bigint
pub const ternary_primitives = @import("ternary/bigint.zig");

// ═══════════════════════════════════════════════════════════════
// MATH MODULES
// ═════════════════════════════════════════════════════════════════════════

/// Sacred constants (φ, e, π)
pub const math = @import("math/constants.zig");

// ═══════════════════════════════════════════════════════════════════════
// TRINITY CONSTANTS (re-exported for convenience)
// ═════════════════════════════════════════════════════════════════════════════════

/// Golden ratio φ = (1 + √5) / 2
pub const PHI = formats.PHI;

/// φ² = φ × φ
pub const PHI_SQ = formats.PHI_SQ;

/// 1/φ²
pub const PHI_INV_SQ = formats.PHI_INV_SQ;

/// Trinity Identity: φ² + 1/φ² = 3
pub const TRINITY = formats.TRINITY;

test "every public declaration of this module is analysed" {
    // src/root.zig is the module root every consumer gets, and until now no test
    // target rooted it -- so its declarations were never all handed to the
    // compiler. Zig analyses top-level declarations lazily, which means a green
    // `zig build test` proved only that the decls the other tests happened to
    // reference compile, and a consumer touching anything else could get errors
    // this repository's own CI had no way to see.
    //
    // That is not hypothetical. The same omission in gHashTag/zig-hdc hid five
    // distinct API-drift errors against the version of this package it pins,
    // while its CI stayed green throughout (zig-hdc#2).
    @import("std").testing.refAllDeclsRecursive(@This());
}

// vsa_jit was never exported, so nothing ever compiled it, so nobody found
// that vm/jit_unified.zig imported "../../jit_arm64.zig" — a path that
// escapes the module root and could not resolve on any machine. The file
// sat beside it the whole time. Exporting it is what makes the compiler
// look, and the compiler looking is the only reason the defect surfaced.
pub const vsa_jit = @import("vsa_jit.zig");
