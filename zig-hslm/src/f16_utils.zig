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
pub const f16 = hslm.f16;
pub const GF16 = hslm.GF16;
pub const TF3 = hslm.TF3;
pub const PHI = hslm.PHI;
pub const PHI_INV = hslm.PHI_INV;

// ═══════════════════════════════════════════════════════════════════════════════
// NUMBER FORMAT CONVERSION
// ═══════════════════════════════════════════════════════════════════════════════

/// Safe f16 to f32 conversion with NaN/Inf/subnormal handling
pub fn f16ToF32(v: f16) f32 {
    return hslm.safeF16ToF32(v);
}

/// Direct f32 to f16 conversion
pub fn f32ToF16(v: f32) f16 {
    return @floatCast(v);
}

/// Batch conversion f16 → f32
pub fn f16BatchToF32(comptime N: usize, src: [N]f16) [N]f32 {
    return hslm.f16BatchToF32(N, src);
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
        .v0 = 0, .v1 = 0, .v2 = 0, .v3 = 0,
        .v4 = 0, .v5 = 0, .v6 = 0, .v7 = 0,
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
        const error = std.math.abs(dequantized - original);

        self.quantization_error_max = @max(self.quantization_error_max, error);
        // Simple moving average (α = 0.1)
        self.quantization_error_avg = 0.9 * self.quantization_error_avg + 0.1 * error;
    }

    pub fn trackSpecial(self: *NumericalMetrics, value: f16) void {
        const f32_val = safeF16ToF32(value);

        if (std.math.isNan(f32_val)) {
            self.nan_count += 1;
        } else if (std.math.isInf(f32_val)) {
            self.inf_count += 1;
        } else if (!std.math.isFinite(f32_val)) {
            self.overflow_count += 1;
        } else if (std.math.abs(f32_val) < std.math.f32_min) {
            self.subnormal_count += 1;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "f16 conversion safe" {
    const original: f32 = 3.14159;
    const f16_val = f32ToF16(original);
    const f32_val = f16ToF32(f16_val);

    // Within 0.1% error is acceptable for f16
    const error_pct = std.math.abs((f32_val - original) / original) * 100.0;
    try std.testing.expect(error_pct < 0.1);
}

test "φ quantization preserves value" {
    const original: f32 = 2.71828;
    const quantized = phiQuantize(original);
    const dequantized = phiDequantize(quantized);

    const error_pct = std.math.abs((dequantized - original) / original) * 100.0;
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
    const f32_output = f16BatchToF32(4, f16_output);

    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(f32_input[i], f32_output[i], 0.001);
    }
}
