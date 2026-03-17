// Sacred Physics — Baryon Asymmetry Formulas
// Migrated from archive/debug_baryo.zig
// High-precision nucleosynthesis calculations using phi and gamma constants

const std = @import("std");

pub const PHI: f64 = 1.6180339887498948482;
pub const GAMMA: f64 = 0.23606797749978969641; // phi^(-3)
pub const PI: f64 = 3.14159265358979323846;
pub const PHI_INV_SQ: f64 = 0.38196601125010515;
pub const PHI_4: f64 = 6.854101966249685; // phi^4

/// Formula 141: baryon-to-photon ratio eta = gamma^8 * pi^2 / phi^3
pub fn baryonPhotonRatio() f64 {
    const gamma_8 = std.math.pow(f64, GAMMA, 8);
    const pi_sq = PI * PI;
    const phi_cubed = PHI * PHI * PHI;
    return gamma_8 * pi_sq / phi_cubed;
}

/// Formula 145: baryon yield Y_B = phi^6 * 10^(-9)
pub fn baryonYield() f64 {
    return std.math.pow(f64, PHI, 6) * 1e-9;
}

/// Formula 146: neutron-to-proton ratio n/p = phi^(-2) * gamma * 10
pub fn neutronProtonRatio() f64 {
    return PHI_INV_SQ * GAMMA * 10.0;
}

/// Formula 148: helium-4 binding B_He4 = phi^4 * 0.28 * 4
pub fn helium4Binding() f64 {
    return PHI_4 * 0.28 * 4.0;
}

/// Formula 149: lithium radius R_Li = gamma^(-2) * 10^(-10)
pub fn lithiumRadius() f64 {
    return (1.0 / (GAMMA * GAMMA)) * 1e-10;
}

/// Formula 156: deuterium/hydrogen D/H = phi^(-3) * 10^(-4)
pub fn deuteriumHydrogenRatio() f64 {
    return (1.0 / (PHI * PHI * PHI)) * 1e-4;
}

/// Verify gamma = phi^(-3) identity
pub fn verifyGammaIdentity() bool {
    const phi_inv_cubed = 1.0 / (PHI * PHI * PHI);
    return @abs(GAMMA - phi_inv_cubed) < 1e-12;
}

test "gamma identity" {
    try std.testing.expect(verifyGammaIdentity());
}

test "baryon-photon ratio order of magnitude" {
    const eta = baryonPhotonRatio();
    // Should be ~6e-10 order
    try std.testing.expect(eta > 1e-11 and eta < 1e-8);
}

test "neutron-proton ratio" {
    const ratio = neutronProtonRatio();
    // Should be near 1:7 = 0.143
    try std.testing.expect(ratio > 0.05 and ratio < 0.5);
}

test "helium binding" {
    const binding = helium4Binding();
    // Should be in MeV range
    try std.testing.expect(binding > 1.0 and binding < 100.0);
}

test "deuterium-hydrogen ratio" {
    const dh = deuteriumHydrogenRatio();
    // Should be ~2.5e-5
    try std.testing.expect(dh > 1e-6 and dh < 1e-3);
}
