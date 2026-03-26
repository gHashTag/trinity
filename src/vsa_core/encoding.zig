// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Text Encoding (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_encoding.zig");

pub const TEXT_VECTOR_DIM = gen.TEXT_VECTOR_DIM;
pub const Codebook = gen.Codebook;
pub const encodeText = gen.encodeText;
pub const encodeTextWords = gen.encodeTextWords;
pub const decodeText = gen.decodeText;
pub const textSimilarity = gen.textSimilarity;
pub const textsAreSimilar = gen.textsAreSimilar;
pub const findBestMatch = gen.findBestMatch;

// Manual (disabled):
// const manual = @import("encoding_manual.zig");
// pub const Codebook = manual.Codebook;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
