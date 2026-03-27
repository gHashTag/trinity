// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Text Encoding (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
// TTT Dogfood v0.1: Using generated code from Tri spec
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const gen = @import("gen_encoding.zig");

pub const TEXT_VECTOR_DIM = gen.TEXT_VECTOR_DIM;
pub const Codebook = gen.Codebook;
pub const SearchResult = gen.SearchResult;
pub const initCodebook = gen.initCodebook;
pub const encodeText = gen.encodeText;
pub const encodeTextWords = gen.encodeTextWords;
pub const decodeText = gen.decodeText;
pub const textSimilarity = gen.textSimilarity;
pub const textsAreSimilar = gen.textsAreSimilar;
pub const findBestMatch = gen.findBestMatch;
