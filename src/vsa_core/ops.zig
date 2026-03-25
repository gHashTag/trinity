// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Operations (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_ops.zig");

pub const bind = gen.bind;
pub const unbind = gen.unbind;
pub const bundle2 = gen.bundle2;
pub const bundle3 = gen.bundle3;
pub const bundleN = gen.bundleN;
pub const permute = gen.permute;
pub const inversePermute = gen.inversePermute;
pub const randomVector = gen.randomVector;
pub const encodeSequence = gen.encodeSequence;
pub const probeSequence = gen.probeSequence;
pub const cosineSimilarity = gen.cosineSimilarity;
pub const hammingDistance = gen.hammingDistance;
pub const hammingSimilarity = gen.hammingSimilarity;
pub const dotSimilarity = gen.dotSimilarity;
pub const vectorNorm = gen.vectorNorm;
pub const countNonZero = gen.countNonZero;

// Manual (disabled):
// const manual = @import("ops_manual.zig");
// pub const bind = manual.bind;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
