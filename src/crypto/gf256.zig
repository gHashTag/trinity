// GF256 Galois Field Selector — Self-hosted from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const gen = @import("gen_gf256.zig");

// Re-export all types and functions
pub const GF256 = gen.GF256;
pub const PRIMITIVE_POLY = gen.PRIMITIVE_POLY;
pub const FIELD_SIZE = gen.FIELD_SIZE;
