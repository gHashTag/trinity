// ═══════════════════════════════════════════════════════════════════
// ContentHashV2 (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_content_hash_v2.zig");

pub const ContentHash = gen.ContentHash;
pub const normalizeBinary = gen.normalizeBinary;
pub const HashCache = gen.HashCache;
pub const hashFunctionBinary = gen.hashFunctionBinary;
pub const hashFunction = gen.hashFunction;
pub const hashFunctionDecl = gen.hashFunctionDecl;
pub const ImprovedHashMapContext = gen.ImprovedHashMapContext;

// Manual (disabled):
// const manual = @import("content_hash_v2_manual.zig");
// pub const ContentHash = manual.ContentHash;
// ... (all other exports)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════
