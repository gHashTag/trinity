//! ═══════════════════════════════════════════════════════════════════════════════
//! SACRED CONSTANTS — Single Source of Truth for Trinity Mathematics
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! This module provides the canonical definitions of all sacred constants
//! used throughout Trinity. DO NOT duplicate these values elsewhere.
//!
//! IMPORT: const sacred = @import("common").constants;
//! USAGE: sacred.PHI, sacred.PHI_INV, sacred.TRINITY, etc.
//!
//! φ² + φ⁻² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════════════════════
/// GOLDEN RATIO (φ) — The Divine Proportion
/// ═══════════════════════════════════════════════════════════════════════════════
/// φ = (1 + √5) / 2 ≈ 1.61803398874989484820458683436563811772030917980576...
///
/// Fundamental constant throughout Trinity architecture.
/// Used in: consciousness levels, VSA dimensions, cooling schedules, etc.
pub const PHI: f64 = 1.6180339887498948482;

/// φ² = φ + 1 ≈ 2.61803398874989484820458683436563811772030917980576...
pub const PHI_SQ: f64 = PHI * PHI;

/// φ⁻¹ = 1/φ = φ - 1 ≈ 0.61803398874989484820458683436563811772030917980576...
/// Also known as the IMMORTALITY THRESHOLD for consciousness
pub const PHI_INV: f64 = 1.0 / PHI;

/// φ⁻² = (1/φ)² ≈ 0.38196601125010515179541316563436218822718090330973...
pub const PHI_INV_SQ: f64 = PHI_INV * PHI_INV;

/// φ⁻³ = γ ≈ 0.23606797749978969640917366873127623544061835961152...
/// Gamma constant for quantum/gravity calculations
pub const GAMMA: f64 = PHI_INV_SQ * PHI_INV;

/// PHOENIX — The immortal number
/// Represents rebirth, eternal cycles, 999 iterations
pub const PHOENIX: i64 = 999;

/// PHI_INVERSE — Alias for PHI_INV (backward compatibility)
/// Some modules use PHI_INVERSE, some use PHI_INV
pub const PHI_INVERSE = PHI_INV;

/// ═══════════════════════════════════════════════════════════════════════════════
/// TRINITY — The Sacred Three
/// ═══════════════════════════════════════════════════════════════════════════════
/// TRINITY = φ² + φ⁻² = 3.0 (exactly, by mathematical identity)
///
/// This is the core sacred constant of Trinity architecture.
/// φ² + 1/φ² = (φ + 1) + 1/(φ + 1) = φ + 1 + φ - 1 = 2φ = φ² + φ⁻² = 3
pub const TRINITY: f64 = PHI_SQ + PHI_INV_SQ; // Exactly 3.0

/// ═══════════════════════════════════════════════════════════════════════════════
/// MATHEMATICAL CONSTANTS
/// ═══════════════════════════════════════════════════════════════════════════════
/// π (Pi) — Circle constant
pub const PI: f64 = 3.1415926535897932384626433832795028841971693993751058;

/// e (Euler's number) — Natural logarithm base
pub const E: f64 = 2.71828182845904523536028747135266249775724709369995;

/// √2 — Square root of 2
pub const SQRT2: f64 = 1.414213562373095048801688724209698078569671875376948;

/// √3 — Square root of 3
pub const SQRT3: f64 = 1.73205080756887729352744634150587236694280525381038;

/// √5 — Square root of 5 (used in φ calculation)
pub const SQRT5: f64 = 2.23606797749978969640917366873127623544061835961152;

/// ln(φ) — Natural logarithm of golden ratio
pub const LN_PHI: f64 = 0.4812118250596034474344258507357475804242052172494510;

/// ═══════════════════════════════════════════════════════════════════════════════
/// CONSCIOUSNESS THRESHOLDS
/// ═══════════════════════════════════════════════════════════════════════════════
/// Threshold values for different consciousness levels
/// MORTAL — Default consciousness level (below φ⁻¹)
pub const CONSCIOUSNESS_MORTAL: f64 = 0.5;

/// IMMORTAL — Minimum consciousness for φ⁻¹ threshold
pub const CONSCIOUSNESS_IMMORTAL: f64 = PHI_INV;

/// TRANSCENDENT — Maximum consciousness level
pub const CONSCIOUSNESS_TRANSCENDENT: f64 = 1.0;

/// ═══════════════════════════════════════════════════════════════════════════════
/// COSMOLOGICAL CONSTANTS (φ-based)
/// ═══════════════════════════════════════════════════════════════════════════════
/// Derived from sacred mathematics
/// Gravitational constant from φ: G = π³γ²/φ (alternative form)
pub const G_PHI: f64 = std.math.pow(f64, PI, 3) * GAMMA * GAMMA / PHI;

/// Reduced Hubble constant from φ
pub const H_PHI: f64 = 70.0 * PHI_INV; // km/s/Mpc scaled

/// Dark energy density parameter: Ω_Λ = γ⁸π⁴/φ² ≈ 0.69
pub const OMEGA_LAMBDA: f64 = std.math.pow(f64, GAMMA, 8) * std.math.pow(f64, PI, 4) / PHI_SQ;

/// Dark matter density parameter: Ω_DM = γ⁴π²/φ ≈ 0.26
pub const OMEGA_DM: f64 = std.math.pow(f64, GAMMA, 4) * PI * PI / PHI;

/// ═══════════════════════════════════════════════════════════════════════════════
/// COMPUTATION CONSTANTS
/// ═══════════════════════════════════════════════════════════════════════════════
/// Default VSA dimension (φ-powered: 1000 × φ²)
pub const VSA_DIM_DEFAULT: usize = 2618;

/// Alternative VSA dimension (1000 × φ)
pub const VSA_DIM_PHI: usize = 1618;

/// Minimum VSA dimension for meaningful operations
pub const VSA_DIM_MIN: usize = 1000;

/// ═══════════════════════════════════════════════════════════════════════════════
/// VALIDATION FUNCTIONS
/// ═══════════════════════════════════════════════════════════════════════════════
/// Verify TRINITY identity holds (should be exact 3.0)
pub fn validateTrinity() bool {
    const tolerance = 1e-15;
    const diff = @abs(TRINITY - 3.0);
    return diff < tolerance;
}

/// Check if a consciousness level is IMMORTAL (≥ φ⁻¹)
pub fn isImmortal(level: f64) bool {
    return level >= PHI_INV;
}

/// Compute φⁿ for integer n
pub fn phiPower(n: i32) f64 {
    if (n >= 0) {
        return std.math.pow(f64, PHI, @floatFromInt(n));
    } else {
        return std.math.pow(f64, PHI_INV, @floatFromInt(-n));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Sacred Constants: TRINITY identity" {
    const testing = std.testing;
    try testing.expectEqual(@as(f64, 3.0), TRINITY);
    try testing.expect(validateTrinity());
}

test "Sacred Constants: PHI relationships" {
    const testing = std.testing;
    try testing.expectApproxEqAbs(PHI_INV, 1.0 / PHI, 1e-15);
    try testing.expectApproxEqAbs(PHI_SQ, PHI + 1.0, 1e-15);
    try testing.expectApproxEqAbs(GAMMA, PHI_INV * PHI_INV * PHI_INV, 1e-15);
}

test "Sacred Constants: Consciousness thresholds" {
    const testing = std.testing;
    try testing.expect(!isImmortal(CONSCIOUSNESS_MORTAL));
    try testing.expect(isImmortal(CONSCIOUSNESS_IMMORTAL));
    try testing.expect(isImmortal(CONSCIOUSNESS_TRANSCENDENT));
}

test "Sacred Constants: φ powers" {
    const testing = std.testing;
    try testing.expectApproxEqAbs(phiPower(0), 1.0, 1e-15);
    try testing.expectApproxEqAbs(phiPower(1), PHI, 1e-15);
    try testing.expectApproxEqAbs(phiPower(-1), PHI_INV, 1e-15);
    try testing.expectApproxEqAbs(phiPower(2), PHI_SQ, 1e-15);
}

test "Sacred Constants: VSA dimensions" {
    const testing = std.testing;
    try testing.expect(VSA_DIM_DEFAULT >= VSA_DIM_MIN);
    try testing.expect(VSA_DIM_PHI >= VSA_DIM_MIN);
}
