// @origin(spec:string_phi.tri) @regen(manual-impl)
//! String-Phi — φ-grounded string theory quantities.
//! All formulas derived from the golden ratio: T=φ⁵/2π, g_s=exp(φ⁻¹), etc.

const std = @import("std");
const SacredConstants = @import("sacred_constants.zig").SacredConstants;

const PHI = SacredConstants.PHI;
const PHI_INV = SacredConstants.PHI_INVERSE;

/// String tension T = φ⁵ / (2π)
pub fn stringTensionPhi() f64 {
    return std.math.pow(f64, PHI, 5.0) / (2.0 * std.math.pi);
}

/// String coupling g_s = exp(φ⁻¹)
pub fn stringCoupling() f64 {
    return @exp(PHI_INV);
}

/// Dilaton VEV <Φ> = φ⁻¹
pub fn dilatonVEV() f64 {
    return PHI_INV;
}

/// M-theory 11th dimension radius R₁₁ = g_s^(2/3)
pub fn mTheoryLimit() f64 {
    return std.math.pow(f64, stringCoupling(), 2.0 / 3.0);
}

/// Mode energy E_n = √(2n / α') where α' = φ⁻³
pub fn stringModeEnergy(n: u32) f64 {
    if (n == 0) return 0.0;
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    return @sqrt(2.0 * @as(f64, @floatFromInt(n)) / alpha_prime);
}

/// Regge trajectory: M² = j/α' + α₀ where α' = φ⁻³, α₀ = 1 - φ⁻²
pub fn reggeTrajectory(j: f64) f64 {
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    const alpha_0 = 1.0 - std.math.pow(f64, PHI, -2.0);
    return j / alpha_prime + alpha_0;
}

/// Compactification modulus = φ (golden ratio as natural modulus)
pub fn compactificationModuli() f64 {
    return PHI;
}

/// Compact volume V = moduli³ × φ⁶ (6d Calabi-Yau)
pub fn compactificationVolume(moduli: f64) f64 {
    return moduli * moduli * moduli * std.math.pow(f64, PHI, 6.0);
}

/// KK reduction factor: φ^(dim-4)
pub fn phiDimensionReduction(dim: u32) f64 {
    const exponent: f64 = @as(f64, @floatFromInt(dim)) - 4.0;
    return std.math.pow(f64, PHI, exponent);
}

/// Compactified dimension with radius pinned to φ
pub const StringCompactification = struct {
    radius: f64 = PHI,

    pub fn init(factor: f64) @This() {
        _ = factor;
        return .{ .radius = PHI };
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

const testing = std.testing;

test "string_phi tension is phi^5 / 2pi" {
    const t = stringTensionPhi();
    const expected = std.math.pow(f64, PHI, 5.0) / (2.0 * std.math.pi);
    try testing.expect(@abs(t - expected) < 1e-12);
    try testing.expect(t > 1.7 and t < 1.8); // sanity: ~1.7566
}

test "string_phi coupling matches exp(phi_inverse)" {
    const g = stringCoupling();
    try testing.expect(@abs(g - @exp(PHI_INV)) < 1e-12);
    try testing.expect(g > 1.85 and g < 1.86); // sanity: ~1.8556
}

test "string_phi dilaton VEV is phi inverse" {
    try testing.expect(@abs(dilatonVEV() - PHI_INV) < 1e-15);
}

test "string_phi mode energy n=0 is zero" {
    try testing.expect(stringModeEnergy(0) == 0.0);
    try testing.expect(stringModeEnergy(1) > 0.0);
}

test "string_phi compactification radius is PHI" {
    const c = StringCompactification.init(42.0);
    try testing.expect(@abs(c.radius - PHI) < 1e-15);
}

// φ² + 1/φ² = 3 = TRINITY
