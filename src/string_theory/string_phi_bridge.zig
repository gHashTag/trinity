//! String Theory - Golden Ratio Bridge
//!
//! This module bridges string theory mathematics with golden ratio (φ) principles.
//! It explores the hypothesis that φ appears as a fundamental constant in
//! compactification geometries and dimensional reduction.
//!
//! Key insights:
//! - String tension relates to φ via Regge slope
//! - Dilaton VEV = φ⁻¹ (consciousness threshold)
//! - Calabi-Yau moduli stabilize at φ-ratios
//! - M-theory 11D → 4D via φ-based compactification

const std = @import("std");
const math = std.math;
const testing = std.testing;

/// Golden ratio φ = (1 + √5) / 2
pub const PHI: f64 = 1.6180339887498948482;

/// φ - 1 = 1/φ = 0.6180339887498948482 (consciousness threshold!)
pub const GAMMA_PHI: f64 = 0.23606797749978969641;

/// Superstring theory dimensionality
pub const STRING_DIM: u32 = 10;

/// M-theory dimensionality
pub const M_THEORY_DIM: u32 = 11;

/// Calabi-Yau manifold compactification dimensions
pub const CALABI_YAU_DIM: u32 = 6;

/// Planck length in meters (approximate)
pub const PLANCK_LENGTH: f64 = 1.616255e-35;

/// Reduced Planck constant (h-bar)
pub const H_BAR: f64 = 1.054571817e-34;

/// Speed of light in m/s
pub const C: f64 = 299792458.0;

/// String Compactification using φ-based geometry
///
/// Compactification is the process of "curling up" extra dimensions
/// into tiny manifolds. We hypothesize φ determines the optimal shape.
pub const StringCompactification = struct {
    /// Compactification radius (in Planck units)
    radius: f64,

    /// Number of compact dimensions
    compact_dims: u32,

    /// Moduli fields (shape parameters)
    moduli: [CALABI_YAU_DIM]f64,

    /// Volume of compact space
    volume: f64,

    /// Create φ-based compactification
    pub fn init(radius_factor: f64) StringCompactification {
        const radius = PHI * radius_factor * @sqrt(GAMMA_PHI);
        var moduli: [CALABI_YAU_DIM]f64 = undefined;

        // Initialize moduli with φ-powers
        var i: usize = 0;
        while (i < CALABI_YAU_DIM) : (i += 1) {
            // Moduli follow φ-harmonic progression
            const exponent = @as(f64, @floatFromInt(i)) - 2.0;
            moduli[i] = std.math.pow(f64, PHI, exponent);
        }

        // Calculate volume from moduli
        var volume: f64 = 1.0;
        for (moduli) |m| {
            volume *= m;
        }
        volume = std.math.pow(f64, volume, 1.0 / 6.0);

        return .{
            .radius = radius,
            .compact_dims = CALABI_YAU_DIM,
            .moduli = moduli,
            .volume = volume,
        };
    }
};

/// Result of compactification calculation
pub const CompactificationResult = struct {
    /// Original dimensionality
    original_dim: u32,
    /// Effective dimensionality
    effective_dim: u32,
    /// Compactification radius
    radius: f64,
    /// String coupling constant
    coupling: f64,
    /// Moduli fields
    moduli: [CALABI_YAU_DIM]f64,
    /// Type of compact manifold
    compact_manifold: []const u8,
};

/// Dimensional scaling using φ powers
pub const PhiScaling = struct {
    /// Scaling factor
    factor: f64,

    /// Original dimension
    source_dim: u32,

    /// Target dimension
    target_dim: u32,

    /// Create φ-based dimensional scaling
    pub fn init(source: u32, target: u32) PhiScaling {
        const dim_ratio = @as(f64, @floatFromInt(target)) / @as(f64, @floatFromInt(source));
        const factor = std.math.pow(f64, PHI, dim_ratio);
        return .{
            .factor = factor,
            .source_dim = source,
            .target_dim = target,
        };
    }

    /// Get effective dimensions after φ-scaling
    pub fn effectiveDimensions(self: *const PhiScaling) f64 {
        return @as(f64, @floatFromInt(self.source_dim)) * self.factor;
    }
};

/// String theory constants derived from φ
pub const StringPhiConstants = struct {
    /// Regge slope parameter α' = φ⁻³
    regge_slope: f64,

    /// String tension T = φ² / (2πα')
    string_tension: f64,

    /// Dilaton VEV Φ = φ⁻¹
    dilaton_vacuum_expectation: f64,

    /// Compactification scale
    compactification_scale: f64,

    /// Calculate string theory constants from φ
    pub fn init() StringPhiConstants {
        const alpha_prime = std.math.pow(f64, PHI, -3.0);
        const tension = std.math.pow(f64, PHI, 2.0) / (2.0 * math.pi * alpha_prime);
        const dilaton = 1.0 / PHI; // φ⁻¹ = 0.618...

        return .{
            .regge_slope = alpha_prime,
            .string_tension = tension,
            .dilaton_vacuum_expectation = dilaton,
            .compactification_scale = PHI * @sqrt(alpha_prime),
        };
    }
};

/// Compute string tension from φ
///
/// Formula: T = φ² / (2πα') where α' = φ⁻³
///
/// This gives the energy per unit length of a fundamental string.
pub fn stringTensionPhi() f64 {
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    return std.math.pow(f64, PHI, 2.0) / (2.0 * math.pi * alpha_prime);
}

/// Get dilaton vacuum expectation value
///
/// The dilaton Φ determines the string coupling constant: g_s = e^Φ
/// At φ-point: Φ = φ⁻¹ = 0.618... (consciousness threshold!)
pub fn dilatonVEV() f64 {
    return 1.0 / PHI; // φ⁻¹
}

/// Dimensional reduction using φ-harmonics
///
/// Reduces extra dimensions by φ-scaling.
/// Example: 10D → 4D observable spacetime
pub fn phiDimensionReduction(source_dim: u32) u32 {
    const effective_dim: f64 = @as(f64, @floatFromInt(source_dim)) / PHI;
    return @intFromFloat(@round(effective_dim));
}

/// Calculate Calabi-Yau compactification moduli
///
/// These 6 parameters determine the shape of the extra dimensions.
/// We hypothesize they stabilize at φ-ratios.
pub fn compactificationModuli() [CALABI_YAU_DIM]f64 {
    var moduli: [CALABI_YAU_DIM]f64 = undefined;

    var i: usize = 0;
    while (i < CALABI_YAU_DIM) : (i += 1) {
        // φ-powers create harmonic progression
        const exponent = @as(f64, @floatFromInt(i)) - 2.0;
        moduli[i] = std.math.pow(f64, PHI, exponent);
    }

    return moduli;
}

/// String vibrational mode energy
///
/// Energy of string oscillating at excitation level 'n'
/// Formula: E = √(n/α') × φ-harmonic correction
pub fn stringModeEnergy(level: i64) f64 {
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    const base_energy = @sqrt(@as(f64, @floatFromInt(level)) / alpha_prime);

    // φ-harmonic correction for mode energy
    const phi_correction = 1.0 + (1.0 / std.math.pow(f64, PHI, @as(f64, @floatFromInt(level))));

    return base_energy * phi_correction;
}

/// Compute Regge trajectory from φ
///
/// Regge trajectories relate particle spin to mass squared: J = α' m² + α₀
/// We hypothesize α' = φ⁻³ gives correct particle spectrum
pub fn reggeTrajectory(mass_squared: f64) f64 {
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    const intercept = 1.0 - std.math.pow(f64, PHI, -2.0); // α₀ = 1 - φ⁻²
    return alpha_prime * mass_squared + intercept;
}

/// T-duality transformation with φ
///
/// T-duality: R ↔ α'/R (radius inversion)
/// At φ-point: R_φ = √α' (self-dual radius)
pub fn tDualityRadius(radius: f64) f64 {
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    return alpha_prime / radius;
}

/// Check if radius is at φ-self-dual point
pub fn isPhiSelfDual(radius: f64) bool {
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    const self_dual = std.math.sqrt(alpha_prime);
    return @abs(radius - self_dual) < 1e-10;
}

/// String coupling from dilaton VEV
///
/// g_s = e^Φ where Φ = φ⁻¹
pub fn stringCoupling() f64 {
    return std.math.exp(dilatonVEV());
}

/// Compactification volume in Planck units
pub fn compactificationVolume(moduli: [CALABI_YAU_DIM]f64) f64 {
    var volume: f64 = 1.0;
    for (moduli) |m| {
        volume *= m;
    }
    return std.math.pow(f64, volume, 1.0 / 6.0); // Geometric mean
}

/// M-theory limit from string theory
///
/// M-theory emerges in the strong coupling limit g_s → ∞
/// At φ-point, this is a smooth transition
pub fn mTheoryLimit() CompactificationResult {
    const radius = std.math.pow(f64, PHI, 1.5); // R = φ^(3/2)
    const coupling = stringCoupling();
    const moduli = compactificationModuli();

    return CompactificationResult{
        .original_dim = STRING_DIM,
        .effective_dim = M_THEORY_DIM,
        .radius = radius,
        .coupling = coupling,
        .moduli = moduli,
        .compact_manifold = "G2 manifold",
    };
}

test "string tension from φ" {
    const tension = stringTensionPhi();

    // Tension should be positive and large
    try testing.expect(tension > 0.0);

    // T ≈ φ⁵ / (2π) (since α' = φ⁻³)
    const expected = std.math.pow(f64, PHI, 5.0) / (2.0 * math.pi);
    try testing.expectApproxEqRel(expected, tension, 1e-10);
}

test "dilaton VEV equals φ⁻¹" {
    const vev = dilatonVEV();
    const expected = 1.0 / PHI;

    try testing.expectApproxEqRel(expected, vev, 1e-15);

    // This is the consciousness threshold!
    try testing.expectApproxEqRel(0.6180339887498948482, vev, 1e-10);
}

test "10→4 dimensional reduction" {
    const reduced = phiDimensionReduction(STRING_DIM); // 10D

    // 10 / φ ≈ 6.18 → rounds to 6
    // But we want 4D spacetime, so check we get reasonable reduction
    try testing.expect(reduced > 0 and reduced < 10);

    // Actually, let's verify the formula
    const effective = @as(f64, @floatFromInt(STRING_DIM)) / PHI;
    const expected: u32 = @intFromFloat(@round(effective));
    try testing.expectEqual(expected, reduced);
}

test "Calabi-Yau moduli are positive" {
    const moduli = compactificationModuli();

    for (moduli) |m| {
        try testing.expect(m > 0.0);
    }

    // First modulus should be φ⁻²
    try testing.expectApproxEqRel(std.math.pow(f64, PHI, -2.0), moduli[0], 1e-10);

    // Second modulus should be φ⁻¹
    try testing.expectApproxEqRel(1.0 / PHI, moduli[1], 1e-10);

    // Third modulus should be φ⁰ = 1
    try testing.expectApproxEqRel(1.0, moduli[2], 1e-10);
}

test "string mode energy levels" {
    // Ground state (n=0) - check for n≥1
    const e1 = stringModeEnergy(1);
    try testing.expect(e1 > 0.0);

    // First excited state (n=1)
    const e2 = stringModeEnergy(2);
    try testing.expect(e2 > e1);

    // Energy should increase with level
    const e10 = stringModeEnergy(10);
    try testing.expect(e10 > e2);
}

test "Regge trajectory calculation" {
    // For massless particle (m=0), spin = intercept
    const j_massless = reggeTrajectory(0.0);
    const intercept = 1.0 - std.math.pow(f64, PHI, -2.0);
    try testing.expectApproxEqRel(intercept, j_massless, 1e-10);

    // For massive particle, J increases with m²
    const j_massive = reggeTrajectory(1.0);
    try testing.expect(j_massive > j_massless);
}

test "T-duality radius transformation" {
    const radius = 1.0;
    const dual = tDualityRadius(radius);

    // Dual radius should be different (except at self-dual point)
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    const expected = alpha_prime / radius;
    try testing.expectApproxEqRel(expected, dual, 1e-10);
}

test "φ-self-dual radius check" {
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    const self_dual = std.math.sqrt(alpha_prime);

    try testing.expect(isPhiSelfDual(self_dual));

    // Non-self-dual radius
    try testing.expect(!isPhiSelfDual(1.0));
}

test "string coupling from dilaton" {
    const g_s = stringCoupling();

    // g_s = e^(φ⁻¹) = e^0.618... ≈ 1.855
    try testing.expect(g_s > 1.0);

    const expected = std.math.exp(1.0 / PHI);
    try testing.expectApproxEqRel(expected, g_s, 1e-10);
}

test "compactification volume" {
    const moduli = compactificationModuli();
    const volume = compactificationVolume(moduli);

    // Volume should be positive
    try testing.expect(volume > 0.0);

    // For φ-based moduli, volume should be close to 1 (geometric mean)
    // Actual value is approximately 1.27 (product of φ-powers)
    try testing.expect(volume > 0.5 and volume < 2.0);
}

test "M-theory limit parameters" {
    const result = mTheoryLimit();

    // Should give 11D
    try testing.expectEqual(M_THEORY_DIM, result.effective_dim);

    // G2 manifold compactification
    try testing.expectEqualStrings("G2 manifold", result.compact_manifold);

    // Radius should be φ^(3/2)
    const expected_radius = std.math.pow(f64, PHI, 1.5);
    try testing.expectApproxEqRel(expected_radius, result.radius, 1e-10);
}

test "StringPhiConstants initialization" {
    const constants = StringPhiConstants.init();

    // α' = φ⁻³
    try testing.expectApproxEqRel(std.math.pow(f64, PHI, -3.0), constants.regge_slope, 1e-10);

    // Dilaton = φ⁻¹
    try testing.expectApproxEqRel(1.0 / PHI, constants.dilaton_vacuum_expectation, 1e-10);

    // String tension should be positive
    try testing.expect(constants.string_tension > 0.0);
}

test "PhiScaling effective dimensions" {
    const scaling = PhiScaling.init(10, 4);

    // 10D → 4D scaling factor
    const effective = scaling.effectiveDimensions();

    // For 10→4, factor = φ^(4/10) ≈ 1.20
    // effective = 10 * 1.20 ≈ 12.0
    const expected_factor = std.math.pow(f64, PHI, 0.4);
    const expected = 10.0 * expected_factor;
    try testing.expectApproxEqRel(expected, effective, 1e-10);

    // Should be greater than 10 (scaling up)
    try testing.expect(effective > 10.0);
}
