// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Operations (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
// TTT Dogfood v0.2: FULLY SELF-HOSTED from .tri spec
// Source: specs/vsa/ops.tri → VIBEE codegen → gen_ops.zig → this selector
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const generated = @import("gen_ops.zig");

pub const bind = generated.bind;
pub const unbind = generated.unbind;
pub const bundle2 = generated.bundle2;
pub const bundle3 = generated.bundle3;
pub const bundleN = generated.bundleN;
pub const permute = generated.permute;
pub const inversePermute = generated.inversePermute;
pub const randomVector = generated.randomVector;
pub const encodeSequence = generated.encodeSequence;
pub const probeSequence = generated.probeSequence;
pub const cosineSimilarity = generated.cosineSimilarity;
pub const hammingDistance = generated.hammingDistance;
pub const hammingSimilarity = generated.hammingSimilarity;
pub const dotSimilarity = generated.dotSimilarity;
pub const vectorNorm = generated.vectorNorm;
pub const countNonZero = generated.countNonZero;
pub const dotProduct = generated.dotProduct;
