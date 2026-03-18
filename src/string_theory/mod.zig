//! TRINITY String Theory Module
//!
//! This module integrates string theory mathematics with the golden ratio (φ)
//! and provides a comprehensive framework for:
//! - E8 lattice and exceptional groups
//! - String vibrational spectrum
//! - String theory dualities (S/T/U/M)
//! - Calabi-Yau compactification
//! - String-φ bridge connecting string theory to sacred mathematics
//!
//! # Module Structure
//!
//! - **e8_lattice**: E8 Lie group, root system, γ-deformation
//! - **spectrum**: String vibrational modes, Regge trajectories, mass spectrum
//! - **dualities**: S-duality, T-duality, U-duality, M-theory
//! - **manifold**: Calabi-Yau manifolds, Hodge diamond, moduli stabilization
//! - **string_phi_bridge**: Bridge between string theory and φ-mathematics
//!
//! # Key Constants
//!
//! ```
//! φ  = 1.6180339887498948482  (golden ratio)
//! γ  = φ⁻³ = 0.23606797749978969641  (Barbero-Immirzi parameter)
//! φ² + φ⁻² = 3  (TRINITY identity)
//! ```
//!
//! # Usage
//!
//! ```zig
//! const string_theory = @import("string_theory");
//!
//! // E8 lattice operations
//! const lattice = string_theory.e8_lattice;
//! const e8 = lattice.E8Lattice.init();
//!
//! // String spectrum
//! const mass = string_theory.spectrum.superstringSpectrum(0);
//!
//! // Dualities
//! const g_coupling = string_theory.dualities.sDualityCoupling(1.0);
//!
//! // Calabi-Yau
//! const cy = string_theory.manifold.quinticThreefold();
//!
//! // String-φ bridge
//! const tension = string_theory.string_phi_bridge.stringTensionPhi();
//! ```

const std = @import("std");

/// Golden ratio φ = (1 + √5) / 2
pub const PHI: f64 = 1.6180339887498948482;

/// Gamma constant γ = φ⁻³
pub const GAMMA_PHI: f64 = 0.23606797749978969641;

/// TRINITY identity: φ² + φ⁻² = 3
pub const TRINITY_IDENTITY: f64 = PHI * PHI + 1.0 / (PHI * PHI);

pub const e8_lattice = @import("e8_lattice.zig");
pub const spectrum = @import("spectrum.zig");
pub const dualities = @import("dualities.zig");
pub const manifold = @import("manifold.zig");
pub const string_phi_bridge = @import("string_phi_bridge.zig");

// Re-export key types and constants for convenience
pub const E8Vector = e8_lattice.E8Vector;
pub const E8Lattice = e8_lattice.E8Lattice;
pub const StringState = spectrum.StringState;
pub const VibrationalMode = spectrum.VibrationalMode;
pub const DualityType = dualities.DualityType;
pub const CalabiYau = manifold.CalabiYau;
pub const HodgeNumbers = manifold.HodgeNumbers;

/// String theory framework identifier
pub const Framework = enum {
    /// Bosonic string theory (26 dimensions)
    bosonic,
    /// Type I superstring
    type_I,
    /// Type IIA superstring
    type_IIA,
    /// Type IIB superstring
    type_IIB,
    /// Heterotic SO(32)
    heterotic_SO32,
    /// Heterotic E8×E8
    heterotic_E8xE8,
    /// M-theory (11 dimensions)
    m_theory,
    /// F-theory (12 dimensions)
    f_theory,
};

/// Get dimension for a given framework
pub fn frameworkDimension(fw: Framework) u32 {
    return switch (fw) {
        .bosonic => 26,
        .type_I, .type_IIA, .type_IIB, .heterotic_SO32, .heterotic_E8xE8 => 10,
        .m_theory => 11,
        .f_theory => 12,
    };
}

/// Check if framework has supersymmetry
pub fn hasSupersymmetry(fw: Framework) bool {
    return switch (fw) {
        .bosonic => false,
        else => true,
    };
}

/// Get gauge group for heterotic theories
pub fn heteroticGaugeGroup(fw: Framework) ?[]const u8 {
    return switch (fw) {
        .heterotic_SO32 => "SO(32)",
        .heterotic_E8xE8 => "E8×E8",
        else => null,
    };
}

// ============== TESTS ==============

test "string theory module exports" {
    // Test that all submodules are accessible
    _ = e8_lattice;
    _ = spectrum;
    _ = dualities;
    _ = manifold;
    _ = string_phi_bridge;

    // Test re-exports
    _ = E8Vector;
    _ = E8Lattice;
    _ = StringState;
    _ = VibrationalMode;
    _ = DualityType;
    _ = CalabiYau;
    _ = HodgeNumbers;
}

test "framework dimensions" {
    const std = @import("std");

    try std.testing.expectEqual(@as(u32, 26), frameworkDimension(.bosonic));
    try std.testing.expectEqual(@as(u32, 10), frameworkDimension(.type_I));
    try std.testing.expectEqual(@as(u32, 10), frameworkDimension(.type_IIA));
    try std.testing.expectEqual(@as(u32, 11), frameworkDimension(.m_theory));
}

test "supersymmetry check" {
    const std = @import("std");

    try std.testing.expect(!hasSupersymmetry(.bosonic));
    try std.testing.expect(hasSupersymmetry(.type_IIA));
    try std.testing.expect(hasSupersymmetry(.m_theory));
}

test "TRINITY identity" {
    const std = @import("std");
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY_IDENTITY, 1e-10);
}

test "golden ratio constants" {
    const std = @import("std");

    // φ² = φ + 1
    try std.testing.expectApproxEqRel(PHI + 1.0, PHI * PHI, 1e-10);

    // γ = φ⁻³
    try std.testing.expectApproxEqRel(1.0 / (PHI * PHI * PHI), GAMMA_PHI, 1e-10);
}
