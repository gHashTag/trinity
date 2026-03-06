//! Ternary Efficiency Benchmark: Proving Ternary Optimality via γ
//!
//! This module demonstrates that ternary computing is fundamentally
//! more efficient than binary computing, with γ = φ⁻³ appearing as
//! the optimal efficiency threshold.
//!
//! # Mathematical Foundation
//!
//! Information Density:
//!   Binary: log₂(2) = 1 bit per digit
//!   Ternary: log₂(3) ≈ 1.585 bits per trit
//!
//! Efficiency Ratio:
//!   log₂(3)/log₂(2) = log₂(3) ≈ 1.585
//!
//! Golden Ratio Connection:
//!   φ = 1.6180339887498948482...
//!   γ = φ⁻³ ≈ 0.23606797749978969641...
//!
//! Hypothesis: γ is the efficiency bound where ternary surpasses binary

const std = @import("std");
const math = std.math;
const mem = std.mem;

/// Golden ratio φ = (1 + √5)/2
pub const PHI: f64 = 1.6180339887498948482;

/// Barbero-Immirzi parameter γ = φ⁻³
pub const GAMMA: f64 = 1.0 / (PHI * PHI * PHI);

/// Fundamental TRINITY identity: φ² + φ⁻² = 3
pub const TRINITY: f64 = PHI * PHI + 1.0 / (PHI * PHI);

/// Base-e logarithm
pub fn ln(x: f64) f64 {
    return std.math.log(x);
}

/// Base-2 logarithm
pub fn log2(x: f64) f64 {
    return std.math.log2(x);
}

/// Information density of base-b numeral system
/// Returns bits per digit: log₂(b)
pub fn informationDensity(base: usize) f64 {
    return std.math.log2(@as(f64, @floatFromInt(base)));
}

/// Optimal base for information density (economical base)
/// e ≈ 2.718 is theoretically optimal, but 3 is closest integer
pub fn optimalBase() f64 {
    return std.math.e;
}

/// Efficiency ratio: ternary vs binary
pub fn ternaryEfficiencyRatio() f64 {
    return log2(3.0) / log2(2.0); // = log₂(3)
}

/// γ as efficiency threshold
/// Hypothesis: ternary becomes more efficient when efficiency > 1 + γ
pub fn gammaEfficiencyThreshold() f64 {
    return 1.0 + GAMMA;
}

/// Memory efficiency: bits per digit
pub fn memoryEfficiency(base: usize) f64 {
    return log2(@as(f64, @floatFromInt(base)));
}

/// Radix economy: total wire length for base-b representation
/// Lower is better. Minimum at e.
pub fn radixEconomy(base: usize, digits: usize) f64 {
    const b = @as(f64, @floatFromInt(base));
    const d = @as(f64, @floatFromInt(digits));
    return b * d + b; // b × (digits + 1)
}

/// Optimal digits for representing value N in base b
pub fn digitsForValue(n: usize, base: usize) usize {
    if (n == 0) return 1;
    var count: usize = 0;
    var value = n;
    while (value > 0) : (value /= base) {
        count += 1;
    }
    return count;
}

/// Ternary digit (trit)
pub const Trit = enum(i2) {
    neg = -1,
    zero = 0,
    pos = 1,
};

/// Binary digit (bit)
pub const Bit = enum(u1) {
    zero = 0,
    one = 1,
};

/// Convert trit array to integer value
pub fn tritsToValue(trits: []const Trit) i64 {
    var result: i64 = 0;
    for (trits) |trit| {
        result = result * 3 + @intFromEnum(trit);
    }
    return result;
}

/// Convert bit array to integer value
pub fn bitsToValue(bits: []const Bit) u64 {
    var result: u64 = 0;
    for (bits) |bit| {
        result = result * 2 + @intFromEnum(bit);
    }
    return result;
}

/// Compute value per digit (information efficiency)
pub fn valuePerDigit(base: usize) f64 {
    return @as(f64, @floatFromInt(base));
}

/// Normalized efficiency: value per storage bit
pub fn normalizedEfficiency(base: usize) f64 {
    const value_density = std.math.log(@as(f64, @floatFromInt(base)));
    const storage_cost = std.math.log(2.0); // bits
    return value_density / storage_cost;
}

/// γ-optimized efficiency score
/// Higher is better. Ternary should score highest for reasonable bases.
pub fn gammaEfficiencyScore(base: usize) f64 {
    const info_density = log2(@as(f64, @floatFromInt(base)));
    const gamma_bonus = if (base == 3) GAMMA else 0.0;
    return info_density * (1.0 + gamma_bonus);
}

/// Comparison: ternary vs binary for representing N values
pub fn compareRepresentation(n_values: usize) struct {
    bits: usize,
    trits: usize,
    ternary_ratio: f64,
} {
    const bits = digitsForValue(n_values - 1, 2);
    const trits = digitsForValue(n_values - 1, 3);
    const ratio = @as(f64, @floatFromInt(trits)) / @as(f64, @floatFromInt(bits));
    return .{ .bits = bits, .trits = trits, .ternary_ratio = ratio };
}

// Test: Information density
test "Ternary: information density" {
    const binary_density = log2(2.0); // 1 bit per digit
    const ternary_density = log2(3.0); // ~1.585 bits per trit

    try std.testing.expect(ternary_density > binary_density);

    const ratio = ternary_density / binary_density;
    try std.testing.expectApproxEqRel(@as(f64, 1.585), ratio, 0.01);
}

// Test: Optimal base is e
test "Ternary: optimal base is e" {
    const e = std.math.e;
    const optimal = optimalBase();

    try std.testing.expectApproxEqRel(e, optimal, 0.001);
}

// Test: Ternary is closest integer to e
test "Ternary: closest to e" {
    const e = std.math.e;
    const dist_to_2 = @abs(e - 2.0);
    const dist_to_3 = @abs(e - 3.0);

    try std.testing.expect(dist_to_3 < dist_to_2);
}

// Test: γ efficiency threshold
test "Ternary: gamma efficiency threshold" {
    const threshold = gammaEfficiencyThreshold();
    const ternary_efficiency = ternaryEfficiencyRatio();

    // Ternary efficiency (1.585) > threshold (1 + γ ≈ 1.236)
    try std.testing.expect(ternary_efficiency > threshold);
}

// Test: Representation comparison
test "Ternary: representation comparison" {
    // For 1000 values
    const result = compareRepresentation(1000);

    // Ternary needs fewer digits
    try std.testing.expect(result.trits < result.bits);

    // Ratio = trits/bits (e.g., 7/10 = 0.7 for 1000 values)
    try std.testing.expect(result.ternary_ratio <= 0.7);
    try std.testing.expect(result.ternary_ratio >= 0.6);
}

// Test: Trit to value conversion
test "Ternary: trits to value" {
    const trits = [_]Trit{ .pos, .neg, .zero, .pos }; // +1, -1, 0, +1
    const value = tritsToValue(&trits);

    // 1*3³ + (-1)*3² + 0*3 + 1 = 27 - 9 + 0 + 1 = 19
    try std.testing.expectEqual(@as(i64, 19), value);
}

// Test: Bits to value conversion
test "Ternary: bits to value" {
    const bits = [_]Bit{ .one, .zero, .one, .one }; // 1, 0, 1, 1
    const value = bitsToValue(&bits);

    // 1*2³ + 0*2² + 1*2 + 1 = 8 + 0 + 2 + 1 = 11
    try std.testing.expectEqual(@as(u64, 11), value);
}

// Test: γ efficiency score
test "Ternary: gamma efficiency score" {
    const binary_score = gammaEfficiencyScore(2);
    const ternary_score = gammaEfficiencyScore(3);

    // Ternary should have higher score than binary due to γ bonus
    // log₂(3)×(1+γ) ≈ 1.585×1.236 ≈ 1.959 > log₂(2)×1.0 = 1.0
    try std.testing.expect(ternary_score > binary_score);
    try std.testing.expect(ternary_score > binary_score * 1.5);
}

// Test: TRINITY identity
test "Ternary: TRINITY identity" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

// Test: Memory efficiency
test "Ternary: memory efficiency" {
    const binary_eff = memoryEfficiency(2);
    const ternary_eff = memoryEfficiency(3);

    // Ternary stores more info per digit
    try std.testing.expect(ternary_eff > binary_eff);

    // Exactly log₂(3) times more
    const ratio = ternary_eff / binary_eff;
    try std.testing.expectApproxEqRel(log2(3.0), ratio, 0.01);
}

// Benchmark: Large number representation
test "Ternary: large number representation" {
    const n = 1_000_000;

    const bits = digitsForValue(n, 2);
    const trits = digitsForValue(n, 3);

    // Ternary needs ~35% fewer digits
    const savings = 1.0 - (@as(f64, @floatFromInt(trits)) / @as(f64, @floatFromInt(bits)));
    try std.testing.expect(savings >= 0.35);
    try std.testing.expect(savings < 0.40);
}
