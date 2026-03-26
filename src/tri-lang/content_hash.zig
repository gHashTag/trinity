// ═══════════════════════════════════════════════════════════════════════════════
// Content Hash (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_content_hash.zig");

pub const ContentHash = gen.ContentHash;
pub const NormalizeContext = gen.NormalizeContext;
pub const HashError = gen.HashError;
pub const hashFunction = gen.hashFunction;
pub const hashFunctionDecl = gen.hashFunctionDecl;

// Manual (disabled):
// const manual = @import("content_hash_manual.zig");
// pub const ContentHash = manual.ContentHash;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
