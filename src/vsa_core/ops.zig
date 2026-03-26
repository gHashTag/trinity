// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Operations (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Using MANUAL implementation (gen_ops.zig not available):
const manual = @import("ops_manual.zig");

pub const bind = manual.bind;
pub const unbind = manual.unbind;
pub const bundle2 = manual.bundle2;
pub const bundle3 = manual.bundle3;
pub const bundleN = manual.bundleN;
pub const permute = manual.permute;
pub const inversePermute = manual.inversePermute;
pub const randomVector = manual.randomVector;
pub const encodeSequence = manual.encodeSequence;
pub const probeSequence = manual.probeSequence;
pub const cosineSimilarity = manual.cosineSimilarity;
pub const hammingDistance = manual.hammingDistance;
pub const hammingSimilarity = manual.hammingSimilarity;
pub const dotSimilarity = manual.dotSimilarity;
pub const vectorNorm = manual.vectorNorm;
pub const countNonZero = manual.countNonZero;
// pub const bind = manual.bind;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
