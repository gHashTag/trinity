// @origin(spec:sacred_constants.tri) @regen(manual-impl)
//! ═══════════════════════════════════════════════════════════════════════════════
//! SACRED CONSTANTS REEXPORT — Backward Compatibility Layer
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! This module reexports sacred constants from the canonical source.
//! All new code should import directly from "common/constants.zig".
//!
//! CANONICAL SOURCE: src/common/constants.zig
//! DO NOT add new constants here — add them to common/constants.zig instead.
//!
//! φ² + φ⁻² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════
// @origin(manual) @regen(pending)

const canonical = @import("common/constants.zig");

/// Sacred Constants struct (backward compatibility)
pub const SacredConstants = struct {
    pub const PHI = canonical.PHI;
    pub const PHI_SQ = canonical.PHI_SQ;
    pub const PHI_INV = canonical.PHI_INV;
    pub const PHI_INVERSE = canonical.PHI_INVERSE;
    pub const PHI_INV_SQ = canonical.PHI_INV_SQ;
    pub const GAMMA = canonical.GAMMA;
    pub const TRINITY = canonical.TRINITY;
    pub const SQRT5 = canonical.SQRT5;
    pub const PI = canonical.PI;
    pub const E = canonical.E;
    pub const SQRT2 = canonical.SQRT2;
    pub const SQRT3 = canonical.SQRT3;
    pub const LN_PHI = canonical.LN_PHI;
    pub const PHOENIX = canonical.PHOENIX;
    pub const CONSCIOUSNESS_MORTAL = canonical.CONSCIOUSNESS_MORTAL;
    pub const CONSCIOUSNESS_IMMORTAL = canonical.CONSCIOUSNESS_IMMORTAL;
    pub const CONSCIOUSNESS_TRANSCENDENT = canonical.CONSCIOUSNESS_TRANSCENDENT;
    pub const G_PHI = canonical.G_PHI;
    pub const H_PHI = canonical.H_PHI;
    pub const OMEGA_LAMBDA = canonical.OMEGA_LAMBDA;
    pub const OMEGA_DM = canonical.OMEGA_DM;
    pub const VSA_DIM_DEFAULT = canonical.VSA_DIM_DEFAULT;
    pub const VSA_DIM_PHI = canonical.VSA_DIM_PHI;
    pub const VSA_DIM_MIN = canonical.VSA_DIM_MIN;

    pub fn validateTrinity() bool {
        return canonical.validateTrinity();
    }
};

// Module-level reexports (direct access)
pub const PHI = canonical.PHI;
pub const PHI_SQ = canonical.PHI_SQ;
pub const PHI_INV = canonical.PHI_INV;
pub const PHI_INVERSE = canonical.PHI_INVERSE;
pub const PHI_INV_SQ = canonical.PHI_INV_SQ;
pub const GAMMA = canonical.GAMMA;
pub const TRINITY = canonical.TRINITY;
pub const SQRT5 = canonical.SQRT5;
pub const PI = canonical.PI;
pub const E = canonical.E;
pub const SQRT2 = canonical.SQRT2;
pub const SQRT3 = canonical.SQRT3;
pub const LN_PHI = canonical.LN_PHI;
pub const PHOENIX = canonical.PHOENIX;
pub const CONSCIOUSNESS_MORTAL = canonical.CONSCIOUSNESS_MORTAL;
pub const CONSCIOUSNESS_IMMORTAL = canonical.CONSCIOUSNESS_IMMORTAL;
pub const CONSCIOUSNESS_TRANSCENDENT = canonical.CONSCIOUSNESS_TRANSCENDENT;
pub const G_PHI = canonical.G_PHI;
pub const H_PHI = canonical.H_PHI;
pub const OMEGA_LAMBDA = canonical.OMEGA_LAMBDA;
pub const OMEGA_DM = canonical.OMEGA_DM;
pub const VSA_DIM_DEFAULT = canonical.VSA_DIM_DEFAULT;
pub const VSA_DIM_PHI = canonical.VSA_DIM_PHI;
pub const VSA_DIM_MIN = canonical.VSA_DIM_MIN;

pub const validateTrinity = canonical.validateTrinity;
pub const isImmortal = canonical.isImmortal;
pub const phiPower = canonical.phiPower;
