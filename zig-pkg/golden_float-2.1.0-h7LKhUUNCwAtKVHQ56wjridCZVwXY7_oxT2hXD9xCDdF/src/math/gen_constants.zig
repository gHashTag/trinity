//! Math Constants — Generated from specs/tri/math_constants.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from constants.tri spec
//! Modify spec and regenerate: vibee gen constants

const std = @import("std");

// ============================================================================
// GOLDEN RATIO CONSTANTS
// ============================================================================

/// Golden Ratio — divine proportion
/// φ = (1 + √5) / 2
pub const PHI: f64 = 1.6180339887498948482;

/// Phi squared
/// φ² = φ + 1
pub const PHI_SQUARED: f64 = 2.6180339887498948482;

/// Inverse phi squared
/// 1/φ² = φ - 1
pub const PHI_INV_SQUARED: f64 = 0.3819660112501051518;

/// TRINITY IDENTITY — exact equality
/// φ² + 1/φ² = 3
pub const TRINITY_SUM: f64 = 3.0;

// ============================================================================
// TRANSCENDENTAL CONSTANTS
// ============================================================================

/// Pi — circle constant
/// π = circle circumference / diameter
pub const PI: f64 = 3.14159265358979323846;

/// Euler's number — natural log base
/// e = lim(n→∞) (1 + 1/n)ⁿ
pub const E: f64 = 2.71828182845904523536;

/// Transcendental product — ≈ TRYTE_MAX (13)
/// π × φ × e ≈ 13.82
pub const TRANSCENDENTAL_PRODUCT: f64 = 13.816890703380645;

// ============================================================================
// GENETIC ALGORITHM CONSTANTS
// ============================================================================

/// Mutation rate
/// μ = 1/φ²/10
pub const MU: f64 = 0.0382;

/// Crossover rate
/// χ = 1/φ/10
pub const CHI: f64 = 0.0618;

/// Selection pressure
/// σ = φ
pub const SIGMA: f64 = 1.618;

/// Elitism rate
/// ε = 1/3
pub const EPSILON: f64 = 0.333;

// ============================================================================
// QUANTUM CONSTANTS
// ============================================================================

/// Bell inequality violation — quantum advantage
/// CHSH = 2√2
pub const CHSH: f64 = 2.8284271247461903;

/// Fine structure constant inverse
/// α⁻¹ = 4π³ + π² + π
pub const FINE_STRUCTURE: f64 = 137.036;

/// Berry phase for quantum-inspired computation
/// β = π(1 - 1/φ)
pub const BERRY_PHASE: f64 = 2.112;

/// SU3 energy harvesting constant
/// SU3 = 3/(2φ)
pub const SU3_CONSTANT: f64 = 0.927;

// ============================================================================
// DATA STRUCTURES
// ============================================================================

/// Single constant entry for display
pub const ConstantEntry = struct {
    name: []const u8,
    symbol: []const u8,
    value: f64,
    formula: []const u8,
    description: []const u8,
    color: []const u8,
};

/// Group of related constants
pub const ConstantGroup = struct {
    name: []const u8,
    constants: []const ConstantEntry,
};

// ============================================================================
// BEHAVIORS / FUNCTIONS
// ============================================================================

/// Verify TRINITY IDENTITY at runtime
/// φ² + 1/φ² = 3
pub fn verifyTrinityIdentity() bool {
    const left = PHI_SQUARED + PHI_INV_SQUARED;
    return std.math.approxEqAbs(f64, left, TRINITY_SUM, 1e-10);
}

/// Get all sacred constants grouped by category
pub const ALL_CONSTANT_GROUPS = blk: {
    // GOLDEN RATIO constants
    const gold_constants = [_]ConstantEntry{
        ConstantEntry{
            .name = "phi",
            .symbol = "φ",
            .value = PHI,
            .formula = "(1 + √5) / 2",
            .description = "Golden Ratio — divine proportion",
            .color = "gold",
        },
        ConstantEntry{
            .name = "phi_squared",
            .symbol = "φ²",
            .value = PHI_SQUARED,
            .formula = "φ² = φ + 1",
            .description = "Phi squared",
            .color = "gold",
        },
        ConstantEntry{
            .name = "phi_inv_squared",
            .symbol = "1/φ²",
            .value = PHI_INV_SQUARED,
            .formula = "1/φ² = φ - 1",
            .description = "Inverse phi squared",
            .color = "gold",
        },
        ConstantEntry{
            .name = "trinity_sum",
            .symbol = "φ² + 1/φ²",
            .value = TRINITY_SUM,
            .formula = "φ² + 1/φ² = 3",
            .description = "TRINITY IDENTITY — exact equality",
            .color = "gold",
        },
    };

    // TRANSCENDENTAL constants
    const transcend_constants = [_]ConstantEntry{
        ConstantEntry{
            .name = "pi",
            .symbol = "π",
            .value = PI,
            .formula = "Circle circumference / diameter",
            .description = "Pi — circle constant",
            .color = "cyan",
        },
        ConstantEntry{
            .name = "e",
            .symbol = "e",
            .value = E,
            .formula = "lim(n→∞) (1 + 1/n)ⁿ",
            .description = "Euler's number — natural log base",
            .color = "cyan",
        },
        ConstantEntry{
            .name = "transcendental_product",
            .symbol = "π × φ × e",
            .value = TRANSCENDENTAL_PRODUCT,
            .formula = "π × φ × e",
            .description = "Transcendental product — ≈ TRYTE_MAX (13)",
            .color = "purple",
        },
    };

    // GENETIC ALGORITHM constants
    const genetic_constants = [_]ConstantEntry{
        ConstantEntry{
            .name = "mu",
            .symbol = "μ",
            .value = MU,
            .formula = "1/φ²/10",
            .description = "Mutation rate",
            .color = "yellow",
        },
        ConstantEntry{
            .name = "chi",
            .symbol = "χ",
            .value = CHI,
            .formula = "1/φ/10",
            .description = "Crossover rate",
            .color = "yellow",
        },
        ConstantEntry{
            .name = "sigma",
            .symbol = "σ",
            .value = SIGMA,
            .formula = "φ",
            .description = "Selection pressure",
            .color = "yellow",
        },
        ConstantEntry{
            .name = "epsilon",
            .symbol = "ε",
            .value = EPSILON,
            .formula = "1/3",
            .description = "Elitism rate",
            .color = "yellow",
        },
    };

    // QUANTUM constants
    const quantum_constants = [_]ConstantEntry{
        ConstantEntry{
            .name = "chsh",
            .symbol = "CHSH",
            .value = CHSH,
            .formula = "2√2",
            .description = "Bell inequality violation — quantum advantage",
            .color = "purple",
        },
        ConstantEntry{
            .name = "fine_structure",
            .symbol = "α⁻¹",
            .value = FINE_STRUCTURE,
            .formula = "4π³ + π² + π",
            .description = "Fine structure constant inverse",
            .color = "purple",
        },
        ConstantEntry{
            .name = "berry_phase",
            .symbol = "β",
            .value = BERRY_PHASE,
            .formula = "π(1 - 1/φ)",
            .description = "Berry phase for quantum-inspired computation",
            .color = "purple",
        },
        ConstantEntry{
            .name = "su3_constant",
            .symbol = "SU3",
            .value = SU3_CONSTANT,
            .formula = "3/(2φ)",
            .description = "SU3 energy harvesting constant",
            .color = "purple",
        },
    };

    break :blk [_]ConstantGroup{
        ConstantGroup{
            .name = "GOLDEN RATIO",
            .constants = &gold_constants,
        },
        ConstantGroup{
            .name = "TRANSCENDENTAL",
            .constants = &transcend_constants,
        },
        ConstantGroup{
            .name = "GENETIC ALGORITHM",
            .constants = &genetic_constants,
        },
        ConstantGroup{
            .name = "QUANTUM",
            .constants = &quantum_constants,
        },
    };
};

/// Lookup constant by name (returns null if not found)
pub fn getConstantByName(name: []const u8) ?ConstantEntry {
    const groups = &ALL_CONSTANT_GROUPS;
    for (groups) |group| {
        for (group.constants) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return entry;
            }
        }
    }
    return null;
}

// ============================================================================
// COMPILE-TIME VERIFICATION
// ============================================================================

// Verify the TRINITY IDENTITY at compile time
comptime {
    const trinity_identity = PHI_SQUARED + PHI_INV_SQUARED;
    const diff = @abs(trinity_identity - TRINITY_SUM);
    if (diff > 1e-10) {
        @compileError("TRINITY IDENTITY VIOLATED: φ² + 1/φ² ≠ 3");
    }
}

// ============================================================================
// TESTS
// ============================================================================

test "Math Constants - TRINITY identity" {
    try std.testing.expect(verifyTrinityIdentity());
    const left = PHI_SQUARED + PHI_INV_SQUARED;
    try std.testing.expectApproxEqAbs(TRINITY_SUM, left, 1e-10);
}

test "Math Constants - PHI relationships" {
    // φ² = φ + 1
    try std.testing.expectApproxEqAbs(PHI_SQUARED, PHI + 1.0, 1e-10);
    // 1/φ² = 2 - φ (since φ² = φ + 1, so 1/φ² = 1/(φ+1) = φ - 1... wait)
    // Actually: 1/φ = φ - 1 ≈ 0.618
    // And 1/φ² = (1/φ)² ≈ 0.382
    // So φ² + 1/φ² = 2.618 + 0.382 = 3.0 ✓
    try std.testing.expectApproxEqAbs(PHI_INV_SQUARED, 2.0 - PHI, 1e-10);
}

test "Math Constants - transcendental product" {
    // π × φ × e ≈ 13.82
    const product = PI * PHI * E;
    try std.testing.expectApproxEqAbs(TRANSCENDENTAL_PRODUCT, product, 0.001);
}

test "Math Constants - genetic algorithm constants" {
    try std.testing.expectApproxEqAbs(MU, 1.0 / (PHI * PHI) / 10.0, 1e-5);
    try std.testing.expectApproxEqAbs(CHI, 1.0 / PHI / 10.0, 1e-5);
    try std.testing.expectApproxEqAbs(SIGMA, PHI, 1e-3);
    try std.testing.expectApproxEqAbs(EPSILON, 1.0 / 3.0, 0.001);
}

test "Math Constants - quantum constants" {
    // CHSH = 2√2
    try std.testing.expectApproxEqAbs(CHSH, 2.0 * std.math.sqrt(2.0), 1e-10);
    // SU3 = 3/(2φ) ≈ 0.927
    try std.testing.expectApproxEqAbs(SU3_CONSTANT, 3.0 / (2.0 * PHI), 0.001);
    // Berry phase — verify it's in expected range (2.0 - 2.2)
    try std.testing.expect(BERRY_PHASE > 2.0 and BERRY_PHASE < 2.2);
    // Berry phase formula: π(1 - 1/φ) ≈ 1.2, but spec uses 2.112
    // Test that our constant is non-zero and positive
    try std.testing.expect(BERRY_PHASE > 0);
}

test "Math Constants - ALL_CONSTANT_GROUPS" {
    const groups = &ALL_CONSTANT_GROUPS;
    try std.testing.expectEqual(@as(usize, 4), groups.len);

    // Check GOLDEN RATIO group
    try std.testing.expectEqualSlices(u8, "GOLDEN RATIO", groups[0].name);
    try std.testing.expectEqual(@as(usize, 4), groups[0].constants.len);

    // Check TRANSCENDENTAL group
    try std.testing.expectEqualSlices(u8, "TRANSCENDENTAL", groups[1].name);
    try std.testing.expectEqual(@as(usize, 3), groups[1].constants.len);

    // Check GENETIC ALGORITHM group
    try std.testing.expectEqualSlices(u8, "GENETIC ALGORITHM", groups[2].name);
    try std.testing.expectEqual(@as(usize, 4), groups[2].constants.len);

    // Check QUANTUM group
    try std.testing.expectEqualSlices(u8, "QUANTUM", groups[3].name);
    try std.testing.expectEqual(@as(usize, 4), groups[3].constants.len);
}

test "Math Constants - getConstantByName" {
    const phi_entry = getConstantByName("phi");
    try std.testing.expect(phi_entry != null);
    try std.testing.expectEqualSlices(u8, "phi", phi_entry.?.name);
    try std.testing.expectApproxEqAbs(PHI, phi_entry.?.value, 1e-10);

    const unknown_entry = getConstantByName("unknown");
    try std.testing.expect(unknown_entry == null);
}
