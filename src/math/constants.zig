//! Math Constants Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_constants.zig)
//! DO NOT EDIT: Modify math_constants.tri spec and regenerate

// Golden Ratio constants
pub const PHI = @import("gen_constants.zig").PHI;
pub const PHI_SQUARED = @import("gen_constants.zig").PHI_SQUARED;
pub const PHI_INV_SQUARED = @import("gen_constants.zig").PHI_INV_SQUARED;
pub const TRINITY_SUM = @import("gen_constants.zig").TRINITY_SUM;

// Transcendental constants
pub const PI = @import("gen_constants.zig").PI;
pub const E = @import("gen_constants.zig").E;
pub const TRANSCENDENTAL_PRODUCT = @import("gen_constants.zig").TRANSCENDENTAL_PRODUCT;

// Genetic algorithm constants
pub const MU = @import("gen_constants.zig").MU;
pub const CHI = @import("gen_constants.zig").CHI;
pub const SIGMA = @import("gen_constants.zig").SIGMA;
pub const EPSILON = @import("gen_constants.zig").EPSILON;

// Quantum constants
pub const CHSH = @import("gen_constants.zig").CHSH;
pub const FINE_STRUCTURE = @import("gen_constants.zig").FINE_STRUCTURE;
pub const BERRY_PHASE = @import("gen_constants.zig").BERRY_PHASE;
pub const SU3_CONSTANT = @import("gen_constants.zig").SU3_CONSTANT;

// Types
pub const ConstantEntry = @import("gen_constants.zig").ConstantEntry;
pub const ConstantGroup = @import("gen_constants.zig").ConstantGroup;
pub const ALL_CONSTANT_GROUPS = @import("gen_constants.zig").ALL_CONSTANT_GROUPS;

// Functions
pub const verifyTrinityIdentity = @import("gen_constants.zig").verifyTrinityIdentity;
pub const getConstantByName = @import("gen_constants.zig").getConstantByName;
