// ═══════════════════════════════════════════════════════════════════════════════
// VSA Root Module (GENERATED from .tri spec)
// TTT Dogfood v0.1: Self-hosted codegen
// DO NOT EDIT — Generated from specs/vsa/root.tri
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa_core = @import("vsa_core");
const hybrid_mod = @import("hybrid");

// ═══════════════════════════════════════════════════════════════════════════════
// Re-export from vsa_core (pure algorithms, no HybridBigInt)
// ═══════════════════════════════════════════════════════════════════════════════

pub const common = vsa_core.common;
pub const ops = vsa_core.ops;
pub const sparse = vsa_core.sparse;
pub const encoding = vsa_core.encoding;

// Re-export core types from vsa_core
pub const Trit = vsa_core.Trit;
pub const Vec32i8 = vsa_core.Vec32i8;
pub const Vec32i16 = vsa_core.Vec32i16;
pub const SIMD_WIDTH = vsa_core.SIMD_WIDTH;
pub const MAX_TRITS = vsa_core.MAX_TRITS;
pub const SearchResult = vsa_core.SearchResult;

// ═══════════════════════════════════════════════════════════════════════════════
// HybridBigInt from hybrid module (re-export for convenience)
// ═══════════════════════════════════════════════════════════════════════════════

pub const HybridBigInt = hybrid_mod.HybridBigInt;

// ═══════════════════════════════════════════════════════════════════════════════
// Backward Compatibility: re-export VSA submodules from src/vsa/
// ═══════════════════════════════════════════════════════════════════════════════
//
// NOTE: In Zig 0.15, importing files from the same module creates conflicts.
// These re-exports are now handled by src/vsa.zig which can import its own
// subfiles without module ownership issues.

// ═══════════════════════════════════════════════════════════════════════════════
// HybridBigInt VSA Operations (from vsa_core)
// ═══════════════════════════════════════════════════════════════════════════════
//
// These are now available via vsa_core.ops for the self-hosted implementation.

// Re-export core operations from vsa_core.ops
pub const bind = vsa_core.ops.bind;
pub const unbind = vsa_core.ops.unbind;
pub const bundle2 = vsa_core.ops.bundle2;
pub const bundle3 = vsa_core.ops.bundle3;
pub const permute = vsa_core.ops.permute;
pub const inversePermute = vsa_core.ops.inversePermute;
pub const cosineSimilarity = vsa_core.ops.cosineSimilarity;
pub const hammingDistance = vsa_core.ops.hammingDistance;
pub const hammingSimilarity = vsa_core.ops.hammingSimilarity;
pub const dotSimilarity = vsa_core.ops.dotSimilarity;
pub const vectorNorm = vsa_core.ops.vectorNorm;
pub const bundleN = vsa_core.ops.bundleN;
pub const countNonZero = vsa_core.ops.countNonZero;
pub const randomVector = vsa_core.ops.randomVector;
pub const encodeSequence = vsa_core.ops.encodeSequence;
pub const probeSequence = vsa_core.ops.probeSequence;

test "vsa module imports vsa_core" {
    _ = vsa_core.ops;
    _ = vsa_core.sparse;
    _ = vsa_core.encoding;

    // Verify HybridBigInt is available
    _ = hybrid_mod.HybridBigInt;
}

test "vsa module backward compatibility" {
    // Old code using @import("vsa").bind should still work
    const a = try hybrid_mod.HybridBigInt.fromI64(123);
    const b = try hybrid_mod.HybridBigInt.fromI64(456);

    _ = bind(&a, &b);
    _ = unbind(&a, &b);
}
