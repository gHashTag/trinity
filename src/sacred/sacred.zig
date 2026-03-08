// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MODULE — Root export for all sacred mathematics
// φ² + 1/φ² = 3 = TRINITY
//
// This is the module entry point for the sacred library.
// All sacred exports are available through this file.
// ═══════════════════════════════════════════════════════════════════════════════

// Import sacred constants (provided as module import in build.zig)
const sacred_const = @import("const");

// Export math namespace
pub const math = sacred_const.math;
pub const physics = sacred_const.physics;
pub const cosmology = sacred_const.cosmology;
pub const chemistry = sacred_const.chemistry;

// Export commonly-used constants directly
pub const PHI = math.PHI;
pub const PI = math.PI;
pub const E = math.E;
pub const TRINITY = 3.0;

// Note: Other exports (temporal_engine, proof_builder, registry, etc.)
// are available through the sacred_const module or can be imported directly
// Import the specific module needed when using those features
