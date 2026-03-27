//! Sacred Math Constants Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_constants.zig)
//! DO NOT EDIT: Modify specs/tri/math/math_constants.tri and regenerate

// Golden Ratio Constants
pub const PHI = @import("gen_constants.zig").PHI;
pub const PHI_SQUARED = @import("gen_constants.zig").PHI_SQUARED;
pub const PHI_INV_SQUARED = @import("gen_constants.zig").PHI_INV_SQUARED;
pub const TRINITY_SUM = @import("gen_constants.zig").TRINITY_SUM;

// Transcendental Constants
pub const PI = @import("gen_constants.zig").PI;
pub const E = @import("gen_constants.zig").E;
pub const TRANSCENDENTAL_PRODUCT = @import("gen_constants.zig").TRANSCENDENTAL_PRODUCT;

// Genetic Algorithm Constants
pub const MU = @import("gen_constants.zig").MU;
pub const CHI = @import("gen_constants.zig").CHI;
pub const SIGMA = @import("gen_constants.zig").SIGMA;
pub const EPSILON = @import("gen_constants.zig").EPSILON;

// Quantum Constants
pub const CHSH = @import("gen_constants.zig").CHSH;
pub const FINE_STRUCTURE = @import("gen_constants.zig").FINE_STRUCTURE;
pub const BERRY_PHASE = @import("gen_constants.zig").BERRY_PHASE;
pub const SU3_CONSTANT = @import("gen_constants.zig").SU3_CONSTANT;

// Data Structures
pub const Color = @import("gen_constants.zig").Color;
pub const ConstantEntry = @import("gen_constants.zig").ConstantEntry;
pub const ConstantGroup = @import("gen_constants.zig").ConstantGroup;

// Functions
pub const verifyTrinityIdentity = @import("gen_constants.zig").verifyTrinityIdentity;
pub const printAllConstants = @import("gen_constants.zig").printAllConstants;
pub const printConstantsTable = @import("gen_constants.zig").printConstantsTable;

// Constant Groups
pub const GOLDEN_RATIO_GROUP = @import("gen_constants.zig").GOLDEN_RATIO_GROUP;
pub const TRANSCENDENTAL_GROUP = @import("gen_constants.zig").TRANSCENDENTAL_GROUP;
pub const GENETIC_ALGORITHM_GROUP = @import("gen_constants.zig").GENETIC_ALGORITHM_GROUP;
pub const QUANTUM_GROUP = @import("gen_constants.zig").QUANTUM_GROUP;
