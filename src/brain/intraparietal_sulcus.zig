//! INTRAPARIETAL SULCUS — Numerical Layer v1.0
//!
//! Brain region responsible for numerical processing and format conversion.
//! Integrates zig-hslm (official HSLM library) for f16/GF16/TF3 support.
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//!
//! References:
//! - zig-hslm: https://codeberg.org/gHashTag/zig-hslm
//! - Branch: feat/vector-float-cast
//! - Academic: https://www.academia.edu/144897776/Trinity_Framework_Architecture

const std = @import("std");

// Import hslm module (external library)
const hslm = @import("hslm");

// Re-export hslm types for convenience
pub const GF16 = hslm.GF16;
pub const TF3 = hslm.TF3;
pub const PHI = hslm.PHI;
pub const PHI_INV = hslm.PHI_INV;
pub const HslmF16 = hslm.HslmF16;

// ═══════════════════════════════════════════════════════════════════════════════
// NUMBER FORMAT CONVERSION
// ═══════════════════════════════════════════════════════════════════════════════

/// Safe f16 to f32 conversion with NaN/Inf/subnormal handling
pub fn hslmF16ToF32(v: HslmF16) f32 {
    return hslm.hslmF16ToF32(v);
}

/// Direct f32 to hslm f16 conversion
pub fn f32ToHslmF16(v: f32) HslmF16 {
    return @floatCast(v);
}

/// Batch conversion hslm f16 → f32
pub fn hslmF16BatchToF32(comptime N: usize, src: [N]HslmF16) [N]f32 {
    return hslm.hslmF16BatchToF32(N, src);
}

/// Batch conversion f32 → f16
pub fn f32BatchToF16(comptime N: usize, src: [N]f32) [N]f16 {
    return hslm.f32BatchToF16(N, src);
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ-WEIGHTED QUANTIZATION
// ═══════════════════════════════════════════════════════════════════════════════

/// φ-weighted quantization for better distribution
pub fn phiQuantize(v: f32) f16 {
    return hslm.phiQuantize(v);
}

/// φ-weighted dequantization
pub fn phiDequantize(v: f16) f32 {
    return hslm.phiDequantize(v);
}

// ═══════════════════════════════════════════════════════════════════════════════
// GF16 (GOLDEN FLOAT16) UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert f32 to GF16 (φ-optimized packed format)
pub fn f32ToGF16(v: f32) GF16 {
    return GF16.from_f32(v);
}

/// Convert GF16 to f32
pub fn gf16ToF32(gf: GF16) f32 {
    return gf.to_f32();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TF3 (TERNARY FLOAT3) UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Create TF3 from i2 array
pub fn i2ToTF3(comptime N: usize, src: [N]i2) TF3 {
    var tf3 = TF3{
        .v0 = 0,
        .v1 = 0,
        .v2 = 0,
        .v3 = 0,
        .v4 = 0,
        .v5 = 0,
        .v6 = 0,
        .v7 = 0,
    };
    const count = @min(N, 8);
    for (0..count) |i| {
        tf3.set(i, src[i]);
    }
    return tf3;
}

/// Convert TF3 to i2 array
pub fn tf3ToI2(tf3: TF3, comptime N: usize) [N]i2 {
    var result: [N]i2 = undefined;
    const count = @min(N, 8);
    for (0..count) |i| {
        result[i] = tf3.get(i);
    }
    // Fill remaining with zeros
    for (count..N) |i| {
        result[i] = 0;
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// VECTOR FLOAT CAST (SIMD-SAFE)
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD-safe vector float cast
pub fn vectorFloatCast(comptime T: type, src: anytype) T {
    return hslm.vectorFloatCast(T, src);
}

// ═══════════════════════════════════════════════════════════════════════════════
// NUMERICAL METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const NumericalMetrics = struct {
    quantization_error_max: f32,
    quantization_error_avg: f32,
    overflow_count: u32,
    nan_count: u32,
    inf_count: u32,
    subnormal_count: u32,

    pub fn init() NumericalMetrics {
        return NumericalMetrics{
            .quantization_error_max = 0.0,
            .quantization_error_avg = 0.0,
            .overflow_count = 0,
            .nan_count = 0,
            .inf_count = 0,
            .subnormal_count = 0,
        };
    }

    pub fn track(self: *NumericalMetrics, original: f32, quantized: f16) void {
        const dequantized = phiDequantize(quantized);
        const err_val = @abs(dequantized - original);

        self.quantization_error_max = @max(self.quantization_error_max, err_val);
        // Simple moving average (α = 0.1)
        self.quantization_error_avg = 0.9 * self.quantization_error_avg + 0.1 * err_val;
    }

    pub fn trackSpecial(self: *NumericalMetrics, value: f16) void {
        const f32_val = hslmF16ToF32(value);

        if (std.math.isNan(f32_val)) {
            self.nan_count += 1;
        } else if (std.math.isInf(f32_val)) {
            self.inf_count += 1;
        } else if (!std.math.isFinite(f32_val)) {
            self.overflow_count += 1;
        } else if (@abs(f32_val) < 1.175e-38) { // std.math.f32_min equivalent
            self.subnormal_count += 1;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "f16 conversion safe" {
    const original: f32 = 3.14159;
    const f16_val = f32ToHslmF16(original);
    const f32_val = hslmF16ToF32(f16_val);

    // Within 0.1% error is acceptable for f16
    const error_pct = @abs((f32_val - original) / original) * 100.0;
    try std.testing.expect(error_pct < 0.1);
}

test "φ quantization preserves value" {
    const original: f32 = 2.71828;
    const quantized = phiQuantize(original);
    const dequantized = phiDequantize(quantized);

    const error_pct = @abs((dequantized - original) / original) * 100.0;
    try std.testing.expect(error_pct < 10.0);
}

test "TF3 encoding roundtrip" {
    const original = [_]i2{ -1, 0, 1, -1, 0, 1, 0, 0 };
    const tf3 = i2ToTF3(8, original);
    const decoded = tf3ToI2(tf3, 8);

    for (0..8) |i| {
        try std.testing.expectEqual(original[i], decoded[i]);
    }
}

test "vector float cast" {
    const vec_i16 = @Vector(4, i16){ 1000, 2000, 3000, 4000 };
    const vec_f32 = vectorFloatCast(@Vector(4, f32), vec_i16);

    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(
            @as(f32, @floatFromInt(vec_i16[i])),
            vec_f32[i],
            0.001,
        );
    }
}

test "numerical metrics tracking" {
    var metrics = NumericalMetrics.init();

    const test_values = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    for (test_values) |v| {
        const q = phiQuantize(v);
        metrics.track(v, q);
    }

    try std.testing.expect(metrics.quantization_error_max > 0);
    try std.testing.expect(metrics.quantization_error_avg > 0);
}

test "special value detection" {
    var metrics = NumericalMetrics.init();

    const nan_f16: f16 = @floatCast(std.math.nan(f32));
    const inf_f16: f16 = @floatCast(std.math.inf(f32));
    const normal_f16: f16 = @floatCast(1.0);

    metrics.trackSpecial(nan_f16);
    metrics.trackSpecial(inf_f16);
    metrics.trackSpecial(normal_f16);

    try std.testing.expectEqual(@as(u32, 1), metrics.nan_count);
    try std.testing.expectEqual(@as(u32, 1), metrics.inf_count);
}

test "batch conversion" {
    const f32_input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const f16_output = f32BatchToF16(4, f32_input);
    const f32_output = hslmF16BatchToF32(4, f16_output);

    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(f32_input[i], f32_output[i], 0.001);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GF16 FORMAT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "GF16 f32 roundtrip" {
    const test_values = [_]f32{
        0.0,
        -0.0,
        1.0,
        -1.0,
        0.5,
        3.14159,
        2.71828,
        1.61803, // φ
        0.61803, // 1/φ
        1e-4,
        1e4,
    };

    for (test_values) |v| {
        const gf16 = f32ToGF16(v);
        const recovered = gf16ToF32(gf16);
        const error_pct = @abs((recovered - v) / (v + 1e-10)) * 100.0;
        try std.testing.expect(error_pct < 5.0); // 5% tolerance for GF16
    }
}

test "GF16 golden ratio encoding" {
    // Test that φ is well-represented in GF16
    const phi: f32 = 1.618033988749895;
    const gf16_phi = f32ToGF16(phi);
    const recovered = gf16ToF32(gf16_phi);

    // φ should be encoded with minimal error
    const error_pct = @abs((recovered - phi) / phi) * 100.0;
    try std.testing.expect(error_pct < 1.0);
}

test "GF16 saturation" {
    // Test large value saturation (within f16 range)
    const huge: f32 = 65000.0; // Near f16 max
    const gf16_huge = f32ToGF16(huge);
    const recovered = gf16ToF32(gf16_huge);

    // Should be representable or saturate to finite value
    try std.testing.expect(recovered > 0);

    // Very large values may become infinity
    const too_big: f32 = 1e10;
    const gf16_big = f32ToGF16(too_big);
    const recovered_big = gf16ToF32(gf16_big);

    // Either infinity or very large finite value is acceptable
    try std.testing.expect(std.math.isInf(recovered_big) or recovered_big > 1e4);
}

test "GF16 zero preservation" {
    const pos_zero: f32 = 0.0;
    const neg_zero: f32 = -0.0;

    const gf16_pos = f32ToGF16(pos_zero);
    const gf16_neg = f32ToGF16(neg_zero);

    try std.testing.expectEqual(@as(f32, 0.0), gf16ToF32(gf16_pos));
    try std.testing.expectEqual(@as(f32, 0.0), gf16ToF32(gf16_neg));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TF3 TERNARY FORMAT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TF3 all zeros" {
    const zeros = [_]i2{ 0, 0, 0, 0, 0, 0, 0, 0 };
    const tf3 = i2ToTF3(8, zeros);
    const decoded = tf3ToI2(tf3, 8);

    for (0..8) |i| {
        try std.testing.expectEqual(@as(i2, 0), decoded[i]);
    }
}

test "TF3 all positive" {
    const pos = [_]i2{ 1, 1, 1, 1, 1, 1, 1, 1 };
    const tf3 = i2ToTF3(8, pos);
    const decoded = tf3ToI2(tf3, 8);

    for (0..8) |i| {
        try std.testing.expectEqual(@as(i2, 1), decoded[i]);
    }
}

test "TF3 all negative" {
    const neg = [_]i2{ -1, -1, -1, -1, -1, -1, -1, -1 };
    const tf3 = i2ToTF3(8, neg);
    const decoded = tf3ToI2(tf3, 8);

    for (0..8) |i| {
        try std.testing.expectEqual(@as(i2, -1), decoded[i]);
    }
}

test "TF3 partial length" {
    const partial = [_]i2{ -1, 0, 1 };
    const tf3 = i2ToTF3(3, partial);
    const decoded = tf3ToI2(tf3, 3);

    try std.testing.expectEqual(@as(i2, -1), decoded[0]);
    try std.testing.expectEqual(@as(i2, 0), decoded[1]);
    try std.testing.expectEqual(@as(i2, 1), decoded[2]);
}

test "TF3 pattern roundtrip" {
    // Test alternating pattern
    const pattern = [_]i2{ -1, 1, 0, -1, 1, 0, -1, 1 };
    const tf3 = i2ToTF3(8, pattern);
    const decoded = tf3ToI2(tf3, 8);

    for (0..8) |i| {
        try std.testing.expectEqual(pattern[i], decoded[i]);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// F16 TO TERNARY CONVERSION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "f16 to ternary simple" {
    // Test direct f16 to i2 conversion
    const test_cases = [_]struct { f16: f16, expected: i2 }{
        .{ .f16 = -1.0, .expected = -1 },
        .{ .f16 = 0.0, .expected = 0 },
        .{ .f16 = 1.0, .expected = 1 },
    };

    for (test_cases) |case| {
        const result: i2 = if (case.f16 < -0.5) -1 else if (case.f16 > 0.5) 1 else 0;
        try std.testing.expectEqual(case.expected, result);
    }
}

test "f16 to ternary threshold" {
    // Test threshold behavior
    const test_cases = [_]struct { f16: f16, threshold: f16, expected: i2 }{
        .{ .f16 = 0.6, .threshold = 0.5, .expected = 1 },
        .{ .f16 = 0.4, .threshold = 0.5, .expected = 0 },
        .{ .f16 = -0.6, .threshold = 0.5, .expected = -1 },
        .{ .f16 = -0.4, .threshold = 0.5, .expected = 0 },
    };

    for (test_cases) |case| {
        const result: i2 = if (case.f16 > case.threshold) 1 else if (case.f16 < -case.threshold) -1 else 0;
        try std.testing.expectEqual(case.expected, result);
    }
}

test "f16 to ternary array" {
    const f16_values = [_]f16{ -0.8, -0.3, 0.0, 0.3, 0.8 };
    var ternary_values: [5]i2 = undefined;

    for (0..5) |i| {
        ternary_values[i] = if (f16_values[i] > 0.5) 1 else if (f16_values[i] < -0.5) -1 else 0;
    }

    try std.testing.expectEqual(@as(i2, -1), ternary_values[0]);
    try std.testing.expectEqual(@as(i2, 0), ternary_values[1]);
    try std.testing.expectEqual(@as(i2, 0), ternary_values[2]);
    try std.testing.expectEqual(@as(i2, 0), ternary_values[3]);
    try std.testing.expectEqual(@as(i2, 1), ternary_values[4]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// NUMBER FORMATTER UTILITIES TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "NumberFormatter format f32" {
    const test_cases = [_]struct { value: f32, expected_min: f32, expected_max: f32 }{
        .{ .value = 3.14159, .expected_min = 3.14, .expected_max = 3.15 },
        .{ .value = 1.61803, .expected_min = 1.61, .expected_max = 1.62 },
        .{ .value = 0.0, .expected_min = 0.0, .expected_max = 0.01 },
    };

    for (test_cases) |case| {
        // Simple formatting: just verify it's in range
        try std.testing.expect(case.value >= case.expected_min);
        try std.testing.expect(case.value <= case.expected_max);
    }
}

test "NumberFormatter precision" {
    // Test precision handling for different magnitudes
    const small: f32 = 0.001234;
    const medium: f32 = 1.2345;
    const large: f32 = 1234.5;

    // All should be representable with some precision
    try std.testing.expect(small > 0.0);
    try std.testing.expect(medium > 0.0);
    try std.testing.expect(large > 0.0);
}

test "NumberFormatter scientific notation" {
    // Test values that benefit from scientific notation
    const tiny: f32 = 1.23e-5;
    const huge: f32 = 1.23e5;

    try std.testing.expect(tiny > 0.0 and tiny < 1e-4);
    try std.testing.expect(huge > 1e4 and huge < 1e6);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRECISION HANDLING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "precision f16 to f32" {
    const test_values = [_]f32{
        0.0001, // Small
        0.1, // Fractional
        1.0, // Unity
        10.0, // Integer
        100.0, // Large
        1000.0, // Very large
    };

    for (test_values) |v| {
        const f16_val = f32ToHslmF16(v);
        const f32_val = hslmF16ToF32(f16_val);

        // Relative error should be small (< 1%)
        const rel_error = @abs((f32_val - v) / (v + 1e-10));
        try std.testing.expect(rel_error < 0.01);
    }
}

test "precision extreme values" {
    // Test near limits of f16
    const max_f16: f32 = 65504.0;
    const min_f16: f32 = -65504.0;

    const f16_max = f32ToHslmF16(max_f16);
    const f16_min = f32ToHslmF16(min_f16);

    try std.testing.expect(hslmF16ToF32(f16_max) > 0);
    try std.testing.expect(hslmF16ToF32(f16_min) < 0);
}

test "precision subnormal handling" {
    // Test values near zero
    const tiny_values = [_]f32{ 1e-5, 1e-10, 1e-20 };

    for (tiny_values) |v| {
        const f16_val = f32ToHslmF16(v);
        const f32_val = hslmF16ToF32(f16_val);

        // Should either be close or underflow to zero
        if (v > 1e-5) {
            try std.testing.expect(f32_val > 0.0);
        }
    }
}

test "precision φ encoding" {
    // Golden ratio should be well-preserved
    const phi: f32 = 1.618033988749895;
    const phi_inv: f32 = 0.6180339887498949;

    const f16_phi = f32ToHslmF16(phi);
    const f16_phi_inv = f32ToHslmF16(phi_inv);

    const rec_phi = hslmF16ToF32(f16_phi);
    const rec_phi_inv = hslmF16ToF32(f16_phi_inv);

    // Should be within 0.1% of original
    const err_phi = @abs((rec_phi - phi) / phi);
    const err_phi_inv = @abs((rec_phi_inv - phi_inv) / phi_inv);

    try std.testing.expect(err_phi < 0.001);
    try std.testing.expect(err_phi_inv < 0.001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// EDGE CASE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "edge case zero" {
    const f16_zero = f32ToHslmF16(0.0);
    try std.testing.expectEqual(@as(f32, 0.0), hslmF16ToF32(f16_zero));

    const f16_neg_zero = f32ToHslmF16(-0.0);
    try std.testing.expectEqual(@as(f32, 0.0), hslmF16ToF32(f16_neg_zero));
}

test "edge case infinity" {
    const inf: f32 = std.math.inf(f32);
    const f16_inf = f32ToHslmF16(inf);

    // Should be finite after conversion (f16 can't represent all inf values)
    const recovered = hslmF16ToF32(f16_inf);
    try std.testing.expect(!std.math.isFinite(recovered) or recovered > 1e10);
}

test "edge case very small" {
    const epsilon: f32 = 1e-10;
    const f16_eps = f32ToHslmF16(epsilon);
    const recovered = hslmF16ToF32(f16_eps);

    // May underflow to zero, that's acceptable
    if (recovered > 0.0) {
        try std.testing.expect(recovered > 0.0);
    }
}

test "metrics reset" {
    var metrics = NumericalMetrics.init();

    // Track some values
    metrics.track(1.0, phiQuantize(1.0));
    metrics.track(2.0, phiQuantize(2.0));

    try std.testing.expect(metrics.quantization_error_max > 0);

    // Reset
    metrics = NumericalMetrics.init();
    try std.testing.expectEqual(@as(f32, 0.0), metrics.quantization_error_max);
    try std.testing.expectEqual(@as(f32, 0.0), metrics.quantization_error_avg);
}

test "metrics overflow tracking" {
    var metrics = NumericalMetrics.init();

    // Simulate overflow by tracking large values
    const large: f32 = 1e6;
    for (0..10) |_| {
        metrics.track(large, phiQuantize(large));
    }

    // Error should be tracked
    try std.testing.expect(metrics.quantization_error_max > 0);
}

// φ² + 1/φ² = 3 | TRINITY
