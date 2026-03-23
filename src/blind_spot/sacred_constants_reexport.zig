// @origin(spec:sacred_constants_reexport.tri) @regen(manual-impl)
//! Sacred Constants Re-export
//!
//! This module re-exports sacred constants from src/sacred/constants.zig
//! for use by all submodules that cannot use ".." imports.
// @origin(manual) @regen(pending)

const sacred = @import("sacred/constants.zig");

// Re-export SacredConstants struct
pub const SacredConstants = sacred.SacredConstants;

// Re-export common constants for convenience
pub const PHI = sacred.SacredConstants.PHI;
pub const PHI_INVERSE = sacred.SacredConstants.PHI_INVERSE;
pub const PHI_SQ = sacred.SacredConstants.PHI_SQ;
pub const TRINITY = sacred.SacredConstants.TRINITY;
pub const SQRT5 = sacred.SacredConstants.SQRT5;
pub const PI = sacred.SacredConstants.PI;
pub const E = sacred.SacredConstants.E;
pub const TAU = sacred.SacredConstants.TAU;
pub const PHI_CUBED = sacred.SacredConstants.PHI_CUBED;
