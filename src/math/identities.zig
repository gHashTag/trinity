//! Math Identities Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_identities.zig)
//! DO NOT EDIT: Modify identities.tri spec and regenerate

// Constants
pub const PHI = @import("gen_identities.zig").PHI;
pub const PI = @import("gen_identities.zig").PI;
pub const E = @import("gen_identities.zig").E;
pub const SQRT5 = @import("gen_identities.zig").SQRT5;

// Types
pub const IdentityCategory = @import("gen_identities.zig").IdentityCategory;
pub const Identity = @import("gen_identities.zig").Identity;
pub const VerificationResult = @import("gen_identities.zig").VerificationResult;

// Identities
pub const TRINITY_IDENTITY = @import("gen_identities.zig").TRINITY_IDENTITY;
pub const PHI_SQUARED_IDENTITY = @import("gen_identities.zig").PHI_SQUARED_IDENTITY;
pub const PHI_INVERSE_IDENTITY = @import("gen_identities.zig").PHI_INVERSE_IDENTITY;
pub const PHI_RECIPROCAL_IDENTITY = @import("gen_identities.zig").PHI_RECIPROCAL_IDENTITY;
pub const LUCAS_PHI_POWERS_IDENTITY = @import("gen_identities.zig").LUCAS_PHI_POWERS_IDENTITY;
pub const TRYTE_MAX_IDENTITY = @import("gen_identities.zig").TRYTE_MAX_IDENTITY;
pub const BERRY_PHASE_IDENTITY = @import("gen_identities.zig").BERRY_PHASE_IDENTITY;
pub const SU3_CONSTANT_IDENTITY = @import("gen_identities.zig").SU3_CONSTANT_IDENTITY;

// Collections
pub const ALL_IDENTITIES = @import("gen_identities.zig").ALL_IDENTITIES;
pub const getAllIdentities = @import("gen_identities.zig").getAllIdentities;
