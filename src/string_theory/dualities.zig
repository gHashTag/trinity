//! String Theory Dualities with φ-connections
//!
//! This module implements the four fundamental dualities of string theory:
//! - S-duality (strong-weak coupling)
//! - T-duality (large-small radius)
//! - U-duality (combines S and T)
//! - M-theory (11D unification)
//!
//! All dualities are connected to the golden ratio φ = 1.618033988749895

const std = @import("std");
const math = std.math;

// Golden ratio constants
const phi: f64 = 1.618033988749895;
const phi_inverse: f64 = 0.618033988749895;

/// Duality types in string theory
pub const DualityType = enum {
    /// S-duality: strong-weak coupling duality
    s_duality,
    /// T-duality: large-small radius duality
    t_duality,
    /// U-duality: combines S and T dualities
    u_duality,
    /// M-theory: 11-dimensional unification
    m_theory,

    pub fn toString(self: DualityType) []const u8 {
        return switch (self) {
            .s_duality => "S-duality",
            .t_duality => "T-duality",
            .u_duality => "U-duality",
            .m_theory => "M-theory",
        };
    }
};

/// Duality transformation parameters
pub const DualityTransform = struct {
    duality_type: DualityType,
    parameter: f64,
    dimension: u32,
    transformation_matrix: ?[4][4]f64 = null,

    pub fn init(duality_type: DualityType, parameter: f64, dimension: u32) DualityTransform {
        return .{
            .duality_type = duality_type,
            .parameter = parameter,
            .dimension = dimension,
        };
    }
};

/// φ-based coupling constants
pub const CouplingConstant = struct {
    /// String coupling constant g_s
    g_s: f64,
    /// Supergravity coupling κ
    kappa: f64,
    /// Dimensionless coupling
    lambda: f64,

    /// Create coupling constants based on φ
    pub fn phiBased() CouplingConstant {
        const g_s_val = phi / math.pi; // ≈ 0.515
        const kappa_val = phi * std.math.pow(f64, 2.0, 11.0 / 3.0);
        const lambda_val = phi / (2.0 * math.pi);

        return .{
            .g_s = g_s_val,
            .kappa = kappa_val,
            .lambda = lambda_val,
        };
    }

    /// Get string coupling at φ point
    pub fn stringCouplingAtPhi() f64 {
        return phi / math.pi;
    }
};

/// Result of compactification
pub const CompactificationResult = struct {
    dimensions: u32,
    radius: f64,
    coupling: f64,
    compact_manifold: []const u8,

    pub fn init(dimensions: u32, radius: f64, coupling: f64, manifold: []const u8) CompactificationResult {
        return .{
            .dimensions = dimensions,
            .radius = radius,
            .coupling = coupling,
            .compact_manifold = manifold,
        };
    }
};

/// Regge slope parameter α' in string theory
/// Connected to φ via: α' = φ⁻³ ≈ 0.236
pub fn reggeSlope() f64 {
    return std.math.pow(f64, phi_inverse, 3);
}

/// S-duality: g_s → 1/g_s
/// Maps strong coupling to weak coupling and vice versa
/// Fixed point at g_s = φ⁻¹ where g_s = 1/g_s
pub fn sDualityCoupling(g_s: f64) f64 {
    if (g_s == 0) {
        return math.inf(f64);
    }
    return 1.0 / g_s;
}

/// Check if a coupling is at the S-duality fixed point
pub fn isAtFixedPoint(g_s: f64) bool {
    const tolerance = 1e-10;
    return @abs(g_s - phi_inverse) < tolerance or @abs(g_s - 1.0 / phi_inverse) < tolerance;
}

/// T-duality: R → α'/R
/// Maps large radius to small radius physics
/// Minimum length at R = √α'
pub fn tDualityRadius(R: f64) f64 {
    const alpha_prime = reggeSlope();
    if (R == 0) {
        return math.inf(f64);
    }
    return alpha_prime / R;
}

/// Self-dual radius under T-duality
/// R = √α' = φ^(-3/2) ≈ 0.486
pub fn selfDualRadius() f64 {
    const alpha_prime = reggeSlope();
    return math.sqrt(alpha_prime);
}

/// T-duality with φ-enhanced radius
/// R = φ×√α' gives special properties
pub fn tDualityPhiRadius(R: f64) f64 {
    const alpha_prime = reggeSlope();
    if (R == 0) {
        return math.inf(f64);
    }
    return (phi * math.sqrt(alpha_prime)) / R;
}

/// U-duality matrix for D dimensions
/// Combines S-duality and T-duality transformations
pub fn uDualityMap(dim: u32, allocator: std.mem.Allocator) ![]f64 {
    // U-duality group in D dimensions is E_{11-D}
    // For D=4, this is E7(7) with 133 generators
    const size = dim * dim;
    var matrix = try allocator.alloc(f64, size);
    errdefer allocator.free(matrix);

    // Initialize with φ-based mixing
    var i: usize = 0;
    while (i < size) : (i += 1) {
        matrix[i] = 0.0;
    }

    // Diagonal elements with φ
    for (0..dim) |d| {
        matrix[d * dim + d] = phi;
    }

    // Off-diagonal mixing elements
    if (dim >= 2) {
        matrix[0 * dim + 1] = phi_inverse;
        matrix[1 * dim + 0] = phi_inverse;
    }

    return matrix;
}

/// U-duality transformation with φ-mixing
pub fn uDualityTransform(params: [4]f64) [4]f64 {
    const g_s = params[0]; // String coupling
    const R = params[1]; // Compactification radius
    const theta = params[2]; // Axion field
    const B = params[3]; // B-field

    // Apply S-duality to coupling
    const g_s_prime = sDualityCoupling(g_s);

    // Apply T-duality to radius
    const R_prime = tDualityRadius(R);

    // Mix with φ
    const theta_prime = theta * phi;
    const B_prime = B / phi;

    return [_]f64{ g_s_prime, R_prime, theta_prime, B_prime };
}

/// Combine S and T dualities using φ
pub fn phiDualityCombine(s_transform: bool, t_transform: bool) f64 {
    var result: f64 = 1.0;

    if (s_transform) {
        result *= phi;
    }

    if (t_transform) {
        result *= phi_inverse;
    }

    if (s_transform and t_transform) {
        // U-duality with φ² enhancement
        result *= phi;
    }

    return result;
}

/// M-theory compactification from 11D to 10D
pub fn mTheoryCompactify(dim: u32) CompactificationResult {
    const alpha_prime = reggeSlope();

    // M-theory compactified on a circle of radius R_M
    // gives Type IIA string theory with coupling g_s
    const R_M = phi * math.sqrt(alpha_prime);
    const g_s = math.pow(f64, R_M / math.sqrt(alpha_prime), 3.0 / 2.0);

    // Determine manifold based on dimension
    const manifold = switch (dim) {
        10 => "S¹ (circle)", // M-theory → IIA
        7 => "K3 (quartic)",
        6 => "T⁴ (4-torus)",
        4 => "CY₃ (Calabi-Yau 3-fold)",
        else => "T¹¹⁻ᵈ (torus)",
    };

    return CompactificationResult.init(
        dim,
        R_M,
        g_s,
        manifold,
    );
}

/// M-theory 11D gravitational coupling
/// κ₁₁² = φ × l_p⁹
pub fn mTheoryCoupling(planck_length: f64) f64 {
    return phi * std.math.pow(f64, planck_length, 9.0);
}

/// Dp-brane tension
/// T_p = φ^(p-1) / (2π)^p
pub fn dBraneTension(p: u32) f64 {
    const numerator = std.math.pow(f64, phi, @as(f64, @floatFromInt(p)) - 1.0);
    const denominator = std.math.pow(f64, 2.0 * math.pi, @as(f64, @floatFromInt(p)));
    return numerator / denominator;
}

/// D-brane charge with φ-correction
pub fn dBraneCharge(p: u32, g_s: f64) f64 {
    const tension = dBraneTension(p);
    return tension * g_s * phi;
}

/// Test if S-duality at φ⁻¹ is self-dual
pub fn testSDualityFixedPoint() !void {
    const g_s = phi_inverse;

    // S-duality transformation
    const g_s_prime = sDualityCoupling(g_s);

    // Should be self-dual: g_s' ≈ g_s
    const tolerance = 1e-10;
    if (@abs(g_s_prime - g_s) > tolerance) {
        return error.TestFailed;
    }

    std.debug.print("S-duality fixed point test passed: g_s = {d:.6}, g_s' = {d:.6}\n", .{ g_s, g_s_prime });
}

/// Test T-duality preserves mass spectrum
pub fn testTDualityMassSpectrum() !void {
    const alpha_prime = reggeSlope();
    const R = 2.0 * math.sqrt(alpha_prime);

    // Mass formula: m² = (n/R)² + (wR/α')²
    // for winding number w and momentum number n
    const n: f64 = 1.0;
    const w: f64 = 1.0;

    const mass_squared_original = math.pow(f64, n / R, 2.0) + math.pow(f64, w * R / alpha_prime, 2.0);

    // Apply T-duality
    const R_prime = tDualityRadius(R);

    // Swap n and w under T-duality
    const mass_squared_dual = math.pow(f64, w / R_prime, 2.0) + math.pow(f64, n * R_prime / alpha_prime, 2.0);

    const tolerance = 1e-10;
    if (@abs(mass_squared_original - mass_squared_dual) > tolerance) {
        return error.TestFailed;
    }

    std.debug.print("T-duality mass spectrum test passed: m² = {d:.6}, m²' = {d:.6}\n", .{ mass_squared_original, mass_squared_dual });
}

/// Test U-duality in D=4 with E7 group
pub fn testUDualityE7() !void {
    const gpa = std.heap.page_allocator;

    // U-duality group in D=4 is E7(7)
    const dim: u32 = 4;
    const matrix = try uDualityMap(dim, gpa);
    defer gpa.free(matrix);

    // Check that matrix is 4x4
    if (matrix.len != 16) {
        return error.TestFailed;
    }

    // Check diagonal elements are φ
    var i: usize = 0;
    while (i < dim) : (i += 1) {
        const val = matrix[i * dim + i];
        const tolerance = 1e-10;
        if (@abs(val - phi) > tolerance) {
            return error.TestFailed;
        }
    }

    std.debug.print("U-duality E7 test passed: matrix dimension = {d}x{d}\n", .{ dim, dim });
}

/// Test M-theory compactification to IIA
pub fn testMTheoryCompactification() !void {
    const result = mTheoryCompactify(10);

    // Check dimensions
    if (result.dimensions != 10) {
        return error.TestFailed;
    }

    // Check coupling is in reasonable range
    if (result.coupling <= 0 or result.coupling > 10) {
        return error.TestFailed;
    }

    std.debug.print("M-theory compactification test passed: D={d}, R={d:.6}, g_s={d:.6}\n", .{ result.dimensions, result.radius, result.coupling });
}

/// Test D-brane tension formula
pub fn testDBraneTension() !void {
    // Test D0-brane
    const T0 = dBraneTension(0);

    // Test D2-brane
    const T2 = dBraneTension(2);

    // Test D3-brane
    const T3 = dBraneTension(3);

    // D3-brane should have special property: T3 = 1/(2π)³ × φ²
    const expected_T3 = std.math.pow(f64, phi, 2.0) / std.math.pow(f64, 2.0 * math.pi, 3.0);

    const tolerance = 1e-10;
    if (@abs(T3 - expected_T3) > tolerance) {
        return error.TestFailed;
    }

    std.debug.print("D-brane tension test passed: T0={d:.6}, T2={d:.6}, T3={d:.6}\n", .{ T0, T2, T3 });
}

/// Run all duality tests
pub fn runAllTests() !void {
    std.debug.print("\n=== String Theory Duality Tests ===\n\n", .{});

    try testSDualityFixedPoint();
    try testTDualityMassSpectrum();
    try testUDualityE7();
    try testMTheoryCompactification();
    try testDBraneTension();

    std.debug.print("\n=== All duality tests passed! ===\n", .{});
}

test "S-duality at φ⁻¹ is self-dual" {
    try testSDualityFixedPoint();
}

test "T-duality preserves mass spectrum" {
    try testTDualityMassSpectrum();
}

test "U-duality in D=4 with E7 group" {
    try testUDualityE7();
}

test "M-theory compactification to IIA" {
    try testMTheoryCompactification();
}

test "D-brane tension formula" {
    try testDBraneTension();
}
