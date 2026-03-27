// Sacred Constants Selector — Self-hosted from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const gen = @import("gen_constants.zig");

// Re-export all types and constants
pub const SacredConstants = gen.SacredConstants;
pub const ConstantError = gen.ConstantError;

// Convenience exports
pub const PHI = gen.PHI;
pub const PHI_INVERSE = gen.PHI_INVERSE;
pub const PHI_SQ = gen.PHI_SQ;
pub const TRINITY = gen.TRINITY;
pub const SQRT5 = gen.SQRT5;
pub const PI = gen.PI;
pub const E = gen.E;
pub const PHOENIX = gen.PHOENIX;
