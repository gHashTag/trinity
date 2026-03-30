// 🤖 TRINITY v0.11.0: Suborbital Order
//! Strand III: Language & Hardware Bridge
//!
//! VSA operations for Trinity S³AI — bind, unbind, bundle, similarity.
//!
//! THIN WRAPPER: Re-exports from zig-golden-float package + Trinity-specific modules
// ───────────────────────────────────────────────────────────────
// Import from golden-float package (now external dependency)
// ───────────────────────────────────────────────────────────────────────

const std = @import("std");

// Import from golden-float package
const gf = @import("golden-float");

// ───────────────────────────────────────────────────────────────
// Re-exports from zig-golden-float package
// ───────────────────────────────────────────────────────────────────────

// VSA core from package
pub const vsa_core = gf.vsa;
pub const vsa_common = gf.vsa_common;

// Re-export MAX_TRITS for convenience (used by sdk.zig, e2e_test.zig, etc.)
pub const MAX_TRITS = gf.vsa_common.MAX_TRITS;
pub const vsa_10k = gf.vsa_10k;
pub const hrr = gf.hrr;
pub const vsa_concurrency = gf.vsa_concurrency;
pub const fpga_bind = gf.fpga_bind;

// Re-export key VSA functions (from gf.vsa)
pub const bind = gf.vsa.bind;
pub const unbind = gf.vsa.unbind;
pub const bundle2 = gf.vsa.bundle2;
pub const bundle3 = gf.vsa.bundle3;
pub const cosineSimilarity = gf.vsa.cosineSimilarity;
pub const hammingDistance = gf.vsa.hammingDistance;
pub const hammingSimilarity = gf.vsa.hammingSimilarity;
pub const dotSimilarity = gf.vsa.dotSimilarity;
pub const permute = gf.vsa.permute;
pub const inversePermute = gf.vsa.inversePermute;
pub const encodeSequence = gf.vsa.encodeSequence;
pub const probeSequence = gf.vsa.probeSequence;
pub const randomVector = gf.vsa.randomVector;
pub const bundleN = gf.vsa.bundleN;
pub const countNonZero = gf.vsa.countNonZero;
pub const vectorNorm = gf.vsa.vectorNorm;

// VSA composite modules - NOT in golden-float yet, use local files
pub const encoding = @import("vsa/encoding.zig");
pub const storage = @import("vsa/storage.zig");
pub const agent = @import("vsa/agent.zig");

pub const concurrency = gf.vsa_concurrency;

// ───────────────────────────────────────────────────────────────────────
// Trinity-specific modules (NOT in zig-golden-float)
// ───────────────────────────────────────────────────────────────────────────────

pub const formats = gf.formats; // Only available via full package import

test {
    // Note: vsa_tests module removed in golden-float 0.2.0
    // VSA tests now run via zig build test
    _ = gf.vsa;
}
