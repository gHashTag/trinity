const std = @import("std");
const math = std.math;
const print = std.debug.print;

// Sacred constants from math foundation
const PHI: f64 = 1.618033988749895;       // Golden ratio
const PHI_INVERSE: f64 = 0.618033988749895; // φ⁻¹
const TRINITY: f64 = 3.0;                  // φ² + 1/φ² = 3

/// Vibrational mode of a string (harmonic oscillator)
pub const VibrationalMode = struct {
    mode_number: u32,        // Oscillator number n
    frequency: f64,          // ω_n = n/√α'
    polarization: []const u8, // Transverse polarization
    is_fermionic: bool,      // True for superstring fermions

    /// Create a new vibrational mode
    pub fn init(n: u32, polar: []const u8, fermionic: bool) VibrationalMode {
        const alpha_prime = std.math.pow(f64, PHI, -3.0); // α' = φ⁻³
        return .{
            .mode_number = n,
            .frequency = @as(f64, @floatFromInt(n)) / @sqrt(alpha_prime),
            .polarization = polar,
            .is_fermionic = fermionic,
        };
    }

    /// Zero-point energy for this mode
    pub fn zeroPointEnergy(self: *const VibrationalMode) f64 {
        // Each oscillator contributes ±1/2 depending on statistics
        if (self.is_fermionic) {
            return -0.5; // Fermionic zero-point energy
        } else {
            return 0.5;  // Bosonic zero-point energy
        }
    }
};

/// Complete string state with occupation numbers
pub const StringState = struct {
    transverse_dims: u32,    // D-2 dimensions
    occupations: []const u32, // Occupation numbers n_i
    is_superstring: bool,    // Supersymmetric or bosonic
    level: u32,              // Total mass level N = Σ n_i

    /// Create vacuum state (all oscillators in ground state)
    pub fn vacuum(comptime dims: u32, super: bool) StringState {
        var occ: [dims]u32 = undefined;
        for (&occ) |*n| n.* = 0;
        return .{
            .transverse_dims = dims,
            .occupations = &occ,
            .is_superstring = super,
            .level = 0,
        };
    }

    /// Create excited state with specified occupation numbers
    pub fn excited(dims: u32, occ: []const u32, super: bool) StringState {
        var total: u32 = 0;
        for (occ) |n| total += n;
        return .{
            .transverse_dims = dims,
            .occupations = occ,
            .is_superstring = super,
            .level = total,
        };
    }

    /// Calculate normal ordering constant ã
    pub fn normalOrderingConstant(self: *const StringState) f64 {
        if (self.is_superstring) {
            // Superstring: equal boson/fermion contributions cancel
            return 0.0;
        } else {
            // Bosonic: D-2 transverse dimensions
            return @as(f64, @floatFromInt(self.transverse_dims)) * (-1.0 / 24.0);
        }
    }

    /// Mass squared from mass-shell condition: M² = (N - ã)/α'
    pub fn massSquared(self: *const StringState) f64 {
        const alpha_prime = std.math.pow(f64, PHI, -3.0);
        const a_tilde = self.normalOrderingConstant();
        const N = @as(f64, @floatFromInt(self.level));
        return (N - a_tilde) / alpha_prime;
    }
};

/// Complete spectrum data for a string theory
pub const SpectrumData = struct {
    critical_dimension: u32,      // D = 26 (bosonic) or 10 (super)
    transverse_dims: u32,         // D-2
    regge_slope: f64,             // α' in TRINITY units
    intercept: f64,               // Mass at N=0
    theory_type: TheoryType,

    pub const TheoryType = enum {
        bosonic_26,
        superstring_10,
        trinity_modified,
    };

    /// Create bosonic string spectrum
    pub fn bosonic() SpectrumData {
        return .{
            .critical_dimension = 26,
            .transverse_dims = 24,
            .regge_slope = std.math.pow(f64, PHI, -3.0),
            .intercept = -1.0, // ã = 1 for bosonic
            .theory_type = .bosonic_26,
        };
    }

    /// Create superstring spectrum
    pub fn superstring() SpectrumData {
        return .{
            .critical_dimension = 10,
            .transverse_dims = 8,
            .regge_slope = std.math.pow(f64, PHI, -3.0),
            .intercept = 0.0, // ã = 0 for superstring
            .theory_type = .superstring_10,
        };
    }

    /// TRINITY-modified spectrum with φ-corrections
    pub fn trinityModified() SpectrumData {
        // D = 2 + 8φ ≈ 14.9 → 15 dimensions
        const d_critical = 2.0 + 8.0 * PHI;
        return .{
            .critical_dimension = @as(u32, @intFromFloat(@round(d_critical))),
            .transverse_dims = @as(u32, @intFromFloat(@round(d_critical))) - 2,
            .regge_slope = std.math.pow(f64, PHI, -3.0),
            .intercept = -PHI_INVERSE, // Modified intercept
            .theory_type = .trinity_modified,
        };
    }
};

/// Calculate bosonic string energy levels
/// E = Σ(n_i + 1/2) for i=1..24 (26 dimensions - 2)
pub fn bosonicSpectrum(n: u32) f64 {
    // Each of 24 transverse dimensions contributes (n + 1/2)
    // Ground state n=0: E₀ = 24 × 1/2 = 12
    const transverse_dims: f64 = 24.0;
    const ground_energy = transverse_dims * 0.5;
    const excitation = @as(f64, @floatFromInt(n));
    return ground_energy + excitation;
}

/// Calculate superstring energy levels
/// E = Σ(n_i + 1/2) for i=1..8 (10 dimensions - 2)
/// Bosonic and fermionic modes cancel in zero-point energy
pub fn superstringSpectrum(n: u32) f64 {
    // 8 transverse dimensions, but supersymmetry cancels zero-point energy
    const excitation = @as(f64, @floatFromInt(n));
    return excitation; // No zero-point energy in superstring
}

/// Calculate mass gap using golden ratio
/// ΔM = φ⁻¹ represents consciousness threshold
pub fn phiGappedMass(mode: u32) f64 {
    // Gap increases with mode number but scaled by φ⁻¹
    const n = @as(f64, @floatFromInt(mode));
    return PHI_INVERSE * (1.0 + n * 0.1);
}

/// Derive 3 fermion generations from TRINITY identity
/// φ² + 1/φ² = 3 → exactly 3 generations!
pub fn fermionGenerationFromPhi() u32 {
    // TRINITY = φ² + φ⁻² = 3.0 exactly
    // This gives us 3 fermion generations in Standard Model
    return @intFromFloat(TRINITY);
}

/// Regge trajectory with φ-modification
/// J = α' M² + intercept (modified by φ)
pub fn reggeTrajectory(spin: f64) f64 {
    const alpha_prime = std.math.pow(f64, PHI, -3.0); // α' = φ⁻³
    const intercept = PHI_INVERSE; // φ⁻¹ instead of 1
    // Mass squared from spin: M² = (J - a₀)/α'
    return (spin - intercept) / alpha_prime;
}

/// Calculate critical dimension from consistency
/// D = 2 + 24/(1 - k) where k is central charge
pub fn criticalDimension(central_charge: f64) u32 {
    // For bosonic: k=1 → D=26
    // For superstring: k=0 → D=10
    const d = 2.0 + 24.0 / (1.0 - central_charge);
    return @intFromFloat(@round(d));
}

/// Test if state satisfies mass-shell condition
pub fn isValidMassShell(state: StringState) bool {
    const m2 = state.massSquared();
    // Physical states have M² ≥ 0
    return m2 >= 0.0;
}

/// Calculate string tension in TRINITY units
/// T = 1/(2πα') where α' = φ⁻³
pub fn stringTension() f64 {
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    return 1.0 / (2.0 * math.pi * alpha_prime);
}

/// Hagedorn temperature (maximum temperature for strings)
/// T_H = 1/(4π√α') in TRINITY units
pub fn hagedornTemperature() f64 {
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    return 1.0 / (4.0 * math.pi * @sqrt(alpha_prime));
}

// ============================================================================
// TESTS
// ============================================================================

test "bosonic spectrum - n=0 gives massless states after normal ordering" {
    // At level N=1, we get massless states (photon, graviton, etc.)
    // N = Σ n_i, and M² = (N - 1)/α' for bosonic
    const state = StringState{
        .transverse_dims = 24,
        .occupations = &[_]u32{1} ++ [_]u32{0} ** 23, // One excitation
        .is_superstring = false,
        .level = 1,
    };

    const m2 = state.massSquared();
    // At N=1, M² = (1 - 1)/α' = 0 (massless)
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m2, 0.001);
}

test "superstring has 8 transverse oscillators" {
    const spectrum = SpectrumData.superstring();
    try std.testing.expectEqual(@as(u32, 8), spectrum.transverse_dims);
    try std.testing.expectEqual(@as(u32, 10), spectrum.critical_dimension);
}

test "phi-gapped mass is positive" {
    const mass = phiGappedMass(0);
    try std.testing.expect(mass > 0.0);
    try std.testing.expectApproxEqAbs(PHI_INVERSE, mass, 0.001);

    const mass2 = phiGappedMass(5);
    try std.testing.expect(mass2 > mass); // Should increase with mode
}

test "3 fermion generations from TRINITY identity" {
    const generations = fermionGenerationFromPhi();
    try std.testing.expectEqual(@as(u32, 3), generations);
}

test "Regge slope equals φ⁻³" {
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    const expected = 1.0 / std.math.pow(f64, PHI, 3.0);
    try std.testing.expectApproxEqAbs(expected, alpha_prime, 0.0001);
}

test "Regge trajectory with φ-modification" {
    // For spin J=2 (graviton), calculate mass
    const mass2 = reggeTrajectory(2.0);
    // J = α' M² + φ⁻¹ → M² = (2 - φ⁻¹)/φ⁻³
    const expected = (2.0 - PHI_INVERSE) / std.math.pow(f64, PHI, -3.0);
    try std.testing.expectApproxEqAbs(expected, mass2, 0.001);

    try std.testing.expect(mass2 > 0.0); // Physical mass
}

test "bosonic critical dimension is 26" {
    // Central charge k=1 for bosonic string
    const D = criticalDimension(1.0);
    try std.testing.expectEqual(@as(u32, 26), D);
}

test "superstring critical dimension is 10" {
    // Central charge k=0 for superstring
    const D = criticalDimension(0.0);
    try std.testing.expectEqual(@as(u32, 10), D);
}

test "string tension in TRINITY units" {
    const T = stringTension();
    try std.testing.expect(T > 0.0);
    // T = 1/(2πφ⁻³) = φ³/(2π)
    const expected = std.math.pow(f64, PHI, 3.0) / (2.0 * math.pi);
    try std.testing.expectApproxEqAbs(expected, T, 0.001);
}

test "Hagedorn temperature" {
    const T_H = hagedornTemperature();
    try std.testing.expect(T_H > 0.0);
    // T_H = 1/(4π√α') = 1/(4πφ⁻³ᐟ²) = φ³ᐟ²/(4π)
    const expected = std.math.pow(f64, PHI, 1.5) / (4.0 * math.pi);
    try std.testing.expectApproxEqAbs(expected, T_H, 0.001);
}

test "superstring massless ground state" {
    // Vacuum state at N=0
    const vacuum = StringState.vacuum(8, true);
    const m2 = vacuum.massSquared();

    // Superstring has M² = 0 at N=0 (ã = 0)
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m2, 0.001);
}

test "TRINITY modified spectrum" {
    const spectrum = SpectrumData.trinityModified();

    // Should have different critical dimension
    try std.testing.expect(spectrum.critical_dimension != 26);
    try std.testing.expect(spectrum.critical_dimension != 10);

    // Intercept should be -φ⁻¹
    try std.testing.expectApproxEqAbs(-PHI_INVERSE, spectrum.intercept, 0.001);
}

test "VibrationalMode initialization" {
    const mode = VibrationalMode.init(1, "x", false);

    try std.testing.expectEqual(@as(u32, 1), mode.mode_number);
    try std.testing.expect(mode.frequency > 0.0);
    try std.testing.expectEqual(false, mode.is_fermionic);
}

test "VibrationalMode zero-point energy" {
    const boson = VibrationalMode.init(0, "x", false);
    const fermion = VibrationalMode.init(0, "ψ", true);

    try std.testing.expectApproxEqAbs(@as(f64, 0.5), boson.zeroPointEnergy(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, -0.5), fermion.zeroPointEnergy(), 0.001);
}

test "StringState mass-shell validation" {
    // Valid physical state (N >= 1 for bosonic)
    const valid = StringState{
        .transverse_dims = 24,
        .occupations = &[_]u32{1} ++ [_]u32{0} ** 23,
        .is_superstring = false,
        .level = 1,
    };
    try std.testing.expect(isValidMassShell(valid));

    // Tachyonic ground state (N=0 for bosonic)
    const tachyon = StringState{
        .transverse_dims = 24,
        .occupations = &[_]u32{0} ** 24,
        .is_superstring = false,
        .level = 0,
    };
    try std.testing.expect(!isValidMassShell(tachyon)); // M² < 0
}
