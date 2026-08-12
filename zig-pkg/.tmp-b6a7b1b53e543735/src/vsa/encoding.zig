//! VSA Encoding Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_encoding.zig)
//! DO NOT EDIT: Modify encoding.tri spec and regenerate

// Types
pub const TritEncoding = @import("gen_encoding.zig").TritEncoding;
pub const EncodedTrits = @import("gen_encoding.zig").EncodedTrits;
pub const Codebook = @import("gen_encoding.zig").Codebook;

// Encoding functions
pub const encodeTrits = @import("gen_encoding.zig").encodeTrits;
pub const decodeTrits = @import("gen_encoding.zig").decodeTrits;
pub const encodingSize = @import("gen_encoding.zig").encodingSize;

// Codebook functions
pub const codebookBind = @import("gen_encoding.zig").codebookBind;
pub const codebookMajority = @import("gen_encoding.zig").codebookMajority;
pub const GLOBAL_CODEBOOK = @import("gen_encoding.zig").GLOBAL_CODEBOOK;

// Text encoding functions (stubs - TODO: full implementation)
// NOTE: Use text_encoding.zig for production implementation
pub const charToVector = @import("gen_encoding.zig").charToVector;
pub const encodeText = @import("gen_encoding.zig").encodeText;
pub const decodeText = @import("gen_encoding.zig").decodeText;
pub const encodeTextWords = @import("gen_encoding.zig").encodeTextWords;
pub const textSimilarity = @import("gen_encoding.zig").textSimilarity;
pub const textsAreSimilar = @import("gen_encoding.zig").textsAreSimilar;
pub const TEXT_VECTOR_DIM = @import("gen_encoding.zig").TEXT_VECTOR_DIM;

// Full text encoding implementation
pub const text = @import("text_encoding.zig");
