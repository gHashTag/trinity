// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Common Types (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_common.zig");

pub const MAX_TRITS = gen.MAX_TRITS;
pub const TRITS_PER_BYTE = gen.TRITS_PER_BYTE;
pub const MAX_PACKED_BYTES = gen.MAX_PACKED_BYTES;
pub const Trit = gen.Trit;
pub const Vec32i8 = gen.Vec32i8;
pub const Vec32i16 = gen.Vec32i16;
pub const Vec32i32 = gen.Vec32i32;
pub const SIMD_WIDTH = gen.SIMD_WIDTH;
pub const SIMD_CHUNKS = gen.SIMD_CHUNKS;
pub const SearchResult = gen.SearchResult;

// Manual (disabled):
// const manual = @import("common_manual.zig");
// pub const Trit = manual.Trit;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
