// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MODULE — Root export for all sacred mathematics
// φ² + 1/φ² = 3 = TRINITY
//
// This is the module entry point for the sacred library.
// All sacred exports are available through this file.
// ═══════════════════════════════════════════════════════════════════════════════

// Import sacred constants using relative path
const sacred_const = @import("const.zig");

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

// Re-export everything else from math.zig
pub const TemporalMoment = @import("temporal_engine.zig").TemporalMoment;
pub const TimeArrow = @import("temporal_engine.zig").TimeArrow;
pub const TemporalEngine = @import("temporal_engine.zig").TemporalEngine;
pub const bootTemporalEngine = @import("temporal_engine.zig").bootTemporalEngine;

// Export formula engine types
pub const FormulaEngine = @import("formula_engine.zig").FormulaEngine;
pub const SacredFormula = @import("registry.zig").SacredFormula;
pub const Registry = @import("registry.zig").Registry;
pub const initRegistry = @import("registry.zig").initRegistry;
