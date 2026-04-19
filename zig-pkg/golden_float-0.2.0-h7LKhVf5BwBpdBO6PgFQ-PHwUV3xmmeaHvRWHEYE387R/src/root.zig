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
pub const formats = @import("src/formats/golden_float16.zig");

// ═══════════════════════════════════════════════════════════════
// VSA MODULES
// ═══════════════════════════════════════════════════════════════════

/// Vector Symbolic Architecture core
pub const vsa = @import("src/vsa/core.zig");

/// VSA common types (Trit, HybridBigInt, SIMD)
pub const vsa_common = @import("src/vsa/common.zig");

/// HyperVector10K — 10K-dimensional VSA
pub const vsa_10k = @import("src/vsa/10k_vsa.zig");

/// Holographic Reduced Representations
pub const hrr = @import("src/vsa/hrr.zig");

/// Lock-free data structures for VSA
pub const vsa_concurrency = @import("src/vsa/concurrency.zig");

/// FPGA-accelerated VSA operations
pub const fpga_bind = @import("src/vsa/fpga_bind.zig");

// ═══════════════════════════════════════════════════════════════════
// TERNARY MODULES
// ═════════════════════════════════════════════════════════════════════

/// HybridBigInt — main big integer engine
pub const bigint = @import("src/ternary/hybrid.zig");

/// Packed trit storage
pub const packed_trit = @import("src/ternary/packed_trit.zig");

/// Ternary primitives from bigint
pub const ternary_primitives = @import("src/ternary/bigint.zig");

// ═══════════════════════════════════════════════════════════════
// MATH MODULES
// ═════════════════════════════════════════════════════════════════════════

/// Sacred constants (φ, e, π)
pub const math = @import("src/math/constants.zig");

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
