//! Riemann-γ Module Selector
//! φ² + 1/φ² = 3 | TRINITY
//!
//! This file re-exports from generated code (gen_riemann_gamma.zig)
//! DO NOT EDIT: Modify math_riemann_gamma.tri spec and regenerate

// Constants
pub const PHI = @import("gen_riemann_gamma.zig").PHI;
pub const PHI_CUBED = @import("gen_riemann_gamma.zig").PHI_CUBED;
pub const GAMMA = @import("gen_riemann_gamma.zig").GAMMA;
pub const TRINITY = @import("gen_riemann_gamma.zig").TRINITY;
pub const PI = @import("gen_riemann_gamma.zig").PI;

// Complex type
pub const Complex = @import("gen_riemann_gamma.zig").Complex;

// Gamma and zeta functions
pub const gammaFn = @import("gen_riemann_gamma.zig").gammaFn;
pub const zeta = @import("gen_riemann_gamma.zig").zeta;
pub const isZetaZero = @import("gen_riemann_gamma.zig").isZetaZero;

// Prime counting functions
pub const primeCountPhi = @import("gen_riemann_gamma.zig").primeCountPhi;
pub const primeCountStandard = @import("gen_riemann_gamma.zig").primeCountStandard;
pub const primeCountGamma = @import("gen_riemann_gamma.zig").primeCountGamma;

// Critical line functions
pub const onCriticalLine = @import("gen_riemann_gamma.zig").onCriticalLine;
pub const gammaCriticalLine = @import("gen_riemann_gamma.zig").gammaCriticalLine;

// Zero spacing functions
pub const zeroSpacingPhi = @import("gen_riemann_gamma.zig").zeroSpacingPhi;
pub const zeroSpacingStandard = @import("gen_riemann_gamma.zig").zeroSpacingStandard;
