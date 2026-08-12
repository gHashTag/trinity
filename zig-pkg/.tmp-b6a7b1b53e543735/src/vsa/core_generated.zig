// VSA Core — HybridBigInt Operations Selector
// TTT Dogfood Stage 2.0: Using generated code from Tri spec

const gen = @import("gen_core.zig");

pub const bind = gen.bind;
pub const unbind = gen.unbind;
pub const bundle2 = gen.bundle2;
pub const permute = gen.permute;
pub const inversePermute = gen.inversePermute;

// Re-export from original for functions not yet generated
const original = @import("core.zig");
pub const bundle3 = original.bundle3;
pub const cosineSimilarity = original.cosineSimilarity;
pub const cosineSimilarityF16 = original.cosineSimilarityF16;
pub const dotProduct = original.dotProduct;
pub const vectorNorm = original.vectorNorm;
