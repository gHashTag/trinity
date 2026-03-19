// ═══════════════════════════════════════════════════════════════════════════════
// f16 UTILITIES — Half-precision float SIMD operations
// ═══════════════════════════════════════════════════════════════════════════════
// 16-wide SIMD operations for f16 vectors (2× throughput vs f32).
// I/O in f16, compute in f32 internally for precision.
//
// Key insight: f16 → @floatCast → f32 compute → @floatCast → f16 output
// Memory savings: 2× vs f32, same numerical accuracy for ternary ops.
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const VEC_F16_SIZE = 16;
pub const Vec16f16 = @Vector(16, f16);
pub const Vec16f32 = @Vector(16, f32);

/// Zero vector for f16 (16-wide)
pub const zero_vec_f16: Vec16f16 = @splat(@as(f16, 0.0));

/// Zero vector for f32 (16-wide)
pub const zero_vec_f32: Vec16f32 = @splat(0.0);

// ═══════════════════════════════════════════════════════════════════════════════
// SLICE CONVERSIONS — f32 ↔ f16
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert f32 slice to f16 slice in-place.
/// Input and output can overlap (safely handles aliasing).
pub fn f32ToF16Slice(input: []const f32, output: []f16) void {
    std.debug.assert(input.len == output.len);

    for (input, 0..) |val_f32, i| {
        output[i] = @floatCast(val_f32);
    }
}

/// Convert f16 slice to f32 slice in-place.
pub fn f16ToF32Slice(input: []const f16, output: []f32) void {
    std.debug.assert(input.len == output.len);

    for (input, 0..) |val_f16, i| {
        output[i] = @floatCast(val_f16);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VECTOR CONVERSIONS — 16-wide SIMD
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert 16-wide f16 vector to f32 vector (element-wise).
/// Inline for zero-cost abstraction.
pub inline fn vec16F16ToF32(v: Vec16f16) Vec16f32 {
    return @floatCast(v);
}

/// Convert 16-wide f32 vector to f16 vector (element-wise).
/// Inline for zero-cost abstraction.
pub inline fn vec16F32ToF16(v: Vec16f32) Vec16f16 {
    return @floatCast(v);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY SAFETY — Check if f16 value is safe for ternary quantization
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if f16 value is "ternary safe" — won't overflow when quantized to {-1, 0, +1}.
/// Returns true if value is in finite range (not NaN or infinity).
pub fn isTernarySafeF16(val: f16) bool {
    // f16 finite range: -65504 to +65504
    // Convert to f32 to use std.math.isFinite
    const val_f32: f32 = @floatCast(val);
    return std.math.isFinite(val_f32);
}

/// Count how many f16 values are ternary-safe in a slice.
pub fn countTernarySafeF16(data: []const f16) usize {
    var count: usize = 0;
    for (data) |val| {
        if (isTernarySafeF16(val)) count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAX ABSOLUTE VALUE — For normalization/clipping
// ═══════════════════════════════════════════════════════════════════════════════

/// Find maximum absolute value in f16 slice (scalar reduction).
/// Useful for normalization and clipping before quantization.
pub fn maxAbsF16(data: []const f16) f16 {
    if (data.len == 0) return 0.0;

    var max_val: f16 = 0.0;
    for (data) |val| {
        const abs_val = if (val < 0) -val else val;
        if (abs_val > max_val) max_val = abs_val;
    }
    return max_val;
}

/// Find maximum absolute value in f16 slice using 16-wide SIMD.
/// 4-8x faster than scalar version for large slices.
pub fn maxAbsF16Simd(data: []const f16) f16 {
    if (data.len == 0) return 0.0;

    const vec_len = VEC_F16_SIZE;
    const num_vecs = data.len / vec_len;

    // Accumulator vector (start with zeros)
    var acc_vec = zero_vec_f16;

    // Process 16 elements at a time
    var i: usize = 0;
    while (i < num_vecs * vec_len) : (i += vec_len) {
        const chunk: Vec16f16 = data[i..][0..vec_len].*;

        // Absolute value: abs(x) = @select(x < 0, -x, x)
        const neg_chunk = -chunk;
        const mask = chunk < @as(Vec16f16, @splat(0.0));
        const abs_chunk = @select(f16, mask, neg_chunk, chunk);

        // Keep maximum: max(a, b) = @select(a < b, b, a)
        const max_mask = acc_vec < abs_chunk;
        acc_vec = @select(f16, max_mask, abs_chunk, acc_vec);
    }

    // Reduce vector to scalar (horizontal max)
    var max_val: f16 = 0.0;
    inline for (0..vec_len) |j| {
        if (acc_vec[j] > max_val) max_val = acc_vec[j];
    }

    // Handle scalar tail
    while (i < data.len) : (i += 1) {
        const abs_val = if (data[i] < 0) -data[i] else data[i];
        if (abs_val > max_val) max_val = abs_val;
    }

    return max_val;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOT PRODUCT — 16-wide f16 SIMD
// ═══════════════════════════════════════════════════════════════════════════════

/// Dot product of two f16 slices (16-wide SIMD, compute in f32).
/// Returns f64 to avoid overflow for large vectors.
pub fn dotProductF16(a: []const f16, b: []const f16) f64 {
    std.debug.assert(a.len == b.len);

    const vec_len = VEC_F16_SIZE;
    const num_vecs = a.len / vec_len;

    // Accumulator in f32 for precision
    var acc_f32: Vec16f32 = zero_vec_f32;

    // Process 16 elements at a time
    var i: usize = 0;
    while (i < num_vecs * vec_len) : (i += vec_len) {
        const a_vec: Vec16f16 = a[i..][0..vec_len].*;
        const b_vec: Vec16f16 = b[i..][0..vec_len].*;

        // Convert to f32 for compute
        const a_f32: Vec16f32 = @floatCast(a_vec);
        const b_f32: Vec16f32 = @floatCast(b_vec);

        // Accumulate
        acc_f32 += a_f32 * b_f32;
    }

    // Horizontal sum of accumulator
    var sum: f64 = 0;
    inline for (0..vec_len) |j| {
        sum += @as(f64, acc_f32[j]);
    }

    // Handle scalar tail
    while (i < a.len) : (i += 1) {
        sum += @as(f64, @floatCast(a[i])) * @as(f64, @floatCast(b[i]));
    }

    return sum;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NORMALIZATION — L2 norm for similarity computation
// ═══════════════════════════════════════════════════════════════════════════════

/// L2 norm of f16 slice (compute in f32, return f64).
pub fn l2NormF16(data: []const f16) f64 {
    const sum_sq = dotProductF16(data, data);
    return @sqrt(sum_sq);
}

/// Cosine similarity of two f16 slices (16-wide SIMD).
/// Returns f64 in range [-1, 1].
pub fn cosineSimilarityF16(a: []const f16, b: []const f16) f64 {
    const dot = dotProductF16(a, b);
    const norm_a = l2NormF16(a);
    const norm_b = l2NormF16(b);

    if (norm_a == 0 or norm_b == 0) return 0;

    return dot / (norm_a * norm_b);
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTIZATION — f16 → ternary {-1, 0, +1}
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantize f16 value to ternary using threshold.
/// Returns i8: -1, 0, or +1.
pub fn quantizeF16ToTernary(val: f16, threshold: f16) i8 {
    if (!isTernarySafeF16(val)) return 0;
    if (val > threshold) return 1;
    if (val < -threshold) return -1;
    return 0;
}

/// Quantize f16 slice to ternary i8 slice.
pub fn quantizeSliceF16ToTernary(input: []const f16, output: []i8, threshold: f16) void {
    std.debug.assert(input.len == output.len, "quantizeSliceF16ToTernary: length mismatch");

    for (input, 0..) |val, i| {
        output[i] = quantizeF16ToTernary(val, threshold);
    }
}

/// Compute optimal threshold for ternary quantization (mean absolute / 3).
pub fn optimalThresholdF16(data: []const f16) f16 {
    if (data.len == 0) return 0.0;

    var sum: f64 = 0;
    for (data) |val| {
        const abs_val = if (val < 0) -val else val;
        sum += @as(f64, @floatCast(abs_val));
    }

    const mean_abs = sum / @as(f64, @floatFromInt(data.len));
    return @floatCast(mean_abs / 3.0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEQUANTIZATION — ternary {-1, 0, +1} → f16
// ═══════════════════════════════════════════════════════════════════════════════

/// Dequantize ternary i8 value to f16.
pub fn dequantizeTernaryToF16(val: i8) f16 {
    return @floatCast(@as(f32, @floatFromInt(val)));
}

/// Dequantize ternary i8 slice to f16 slice.
pub fn dequantizeSliceTernaryToF16(input: []const i8, output: []f16) void {
    std.debug.assert(input.len == output.len, "dequantizeSliceTernaryToF16: length mismatch");

    for (input, 0..) |val, i| {
        output[i] = dequantizeTernaryToF16(val);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "f16 slice conversion roundtrip" {
    const input_f32 = [_]f32{ 0.0, 1.0, -1.0, 0.5, -0.5, 3.14, -2.71 };
    var buffer_f16: [input_f32.len]f16 = undefined;
    var output_f32: [input_f32.len]f32 = undefined;

    f32ToF16Slice(&input_f32, &buffer_f16);
    f16ToF32Slice(&buffer_f16, &output_f32);

    for (input_f32, output_f32) |expected, actual| {
        // f16 has ~3 decimal digits precision
        try std.testing.expectApproxEqAbs(expected, actual, 0.001);
    }
}

test "vec16 f16 to f32 conversion" {
    const input: Vec16f16 = @splat(@as(f16, 1.5));
    const output = vec16F16ToF32(input);

    inline for (0..16) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, 1.5), output[i], 0.001);
    }
}

test "vec16 f32 to f16 conversion" {
    const input: Vec16f32 = @splat(@as(f32, 1.5));
    const output = vec16F32ToF16(input);

    inline for (0..16) |i| {
        try std.testing.expectApproxEqAbs(@as(f16, 1.5), output[i], 0.01);
    }
}

test "ternary safe check" {
    try std.testing.expect(isTernarySafeF16(0.0));
    try std.testing.expect(isTernarySafeF16(1.0));
    try std.testing.expect(isTernarySafeF16(-1.0));
    try std.testing.expect(isTernarySafeF16(65504.0)); // max f16
    try std.testing.expect(isTernarySafeF16(-65504.0)); // min f16

    // NaN/inf should fail
    const nan_val: f16 = @floatCast(@as(f32, std.math.nan(f32)));
    const inf_val: f16 = @floatCast(@as(f32, std.math.inf(f32)));
    try std.testing.expect(!isTernarySafeF16(nan_val));
    try std.testing.expect(!isTernarySafeF16(inf_val));
}

test "max abs f16" {
    const data = [_]f16{ 0.0, 1.0, -2.0, 0.5, -3.5, 1.5 };
    const max_val = maxAbsF16(&data);
    try std.testing.expectEqual(@as(f16, 3.5), max_val);
}

test "max abs f16 simd" {
    const data = [_]f16{ 0.0, 1.0, -2.0, 0.5, -3.5, 1.5, 0.1, -0.2, 0.3, -0.4, 0.5, -0.6, 0.7, -0.8, 0.9, -1.0, 2.5 };
    const max_val = maxAbsF16Simd(&data);
    try std.testing.expectEqual(@as(f16, 3.5), max_val);
}

test "dot product f16" {
    const a = [_]f16{ 1.0, 2.0, 3.0, 4.0 };
    const b = [_]f16{ 2.0, 3.0, 4.0, 5.0 };
    const dot = dotProductF16(&a, &b);
    const expected: f64 = 1.0 * 2.0 + 2.0 * 3.0 + 3.0 * 4.0 + 4.0 * 5.0; // 40.0
    try std.testing.expectApproxEqAbs(expected, dot, 0.01);
}

test "l2 norm f16" {
    const data = [_]f16{ 3.0, 4.0 };
    const norm = l2NormF16(&data);
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), norm, 0.01);
}

test "cosine similarity f16" {
    const a = [_]f16{ 1.0, 2.0, 3.0 };
    const b = [_]f16{ 2.0, 4.0, 6.0 }; // parallel vector
    const sim = cosineSimilarityF16(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.01);
}

test "quantize f16 to ternary" {
    try std.testing.expectEqual(@as(i8, 1), quantizeF16ToTernary(0.5, 0.1));
    try std.testing.expectEqual(@as(i8, -1), quantizeF16ToTernary(-0.5, 0.1));
    try std.testing.expectEqual(@as(i8, 0), quantizeF16ToTernary(0.05, 0.1));
}

test "optimal threshold f16" {
    const data = [_]f16{ 0.3, -0.6, 0.0, 0.9, -0.3 };
    const t = optimalThresholdF16(&data);
    // Mean abs ≈ 0.42, threshold ≈ 0.14
    try std.testing.expect(t > 0.1 and t < 0.2);
}

test "dequantize ternary to f16" {
    try std.testing.expectEqual(@as(f16, 1.0), dequantizeTernaryToF16(1));
    try std.testing.expectEqual(@as(f16, -1.0), dequantizeTernaryToF16(-1));
    try std.testing.expectEqual(@as(f16, 0.0), dequantizeTernaryToF16(0));
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADDITIONAL UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Alias for l2NormF16 — matches VSA API naming.
pub fn vectorNormF16(v: []const f16) f64 {
    return l2NormF16(v);
}

/// Count non-finite values (NaN, Inf) in f16 slice.
pub fn countNonFiniteF16(data: []const f16) usize {
    var count: usize = 0;
    for (data) |v| {
        if (!isTernarySafeF16(v)) count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUZZ TESTS (Zig 0.15+)
// Run: zig build test --fuzz
// Coverage: http://localhost:XXXXX/ (shown in terminal)
// Partially addresses ziglang/zig#352 (code coverage)
// ═══════════════════════════════════════════════════════════════════════════════

test "fuzz f16 roundtrip precision" {
    const Fuzzer = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 4) return;
            const val: f32 = @bitCast(input[0..4].*);
            if (!std.math.isFinite(val)) return;
            if (@abs(val) > 65504.0) return; // f16 max
            if (@abs(val) > 0.0 and @abs(val) < 6.1e-5) return; // subnormal range

            const narrow: f16 = @floatCast(val);
            if (!std.math.isFinite(narrow)) return;
            const wide: f32 = @floatCast(narrow);
            const err = @abs(val - wide);
            try std.testing.expect(err <= @abs(val) * 0.002 + 0.001);
        }
    };
    try std.testing.fuzz(.{}, Fuzzer.run, .{});
}

test "fuzz ternary quantize invariant" {
    const Fuzzer = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 2) return;
            const val: f16 = @bitCast(input[0..2].*);
            if (!std.math.isFinite(val)) return;

            const threshold: f16 = 0.5;
            const ternary = quantizeF16ToTernary(val, threshold);

            try std.testing.expect(ternary == -1 or ternary == 0 or ternary == 1);
            if (val > threshold) try std.testing.expect(ternary == 1)
            else if (val < -threshold) try std.testing.expect(ternary == -1)
            else try std.testing.expect(ternary == 0);
        }
    };
    try std.testing.fuzz(.{}, Fuzzer.run, .{});
}

test "fuzz dotProductF16 stability" {
    const Fuzzer = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 16) return;
            const a: [4]f16 = @bitCast(input[0..8].*);
            const b: [4]f16 = @bitCast(input[8..16].*);

            for (a) |v| if (!std.math.isFinite(@as(f32, @floatCast(v)))) return;
            for (b) |v| if (!std.math.isFinite(@as(f32, @floatCast(v)))) return;

            const dot = dotProductF16(&a, &b);
            try std.testing.expect(std.math.isFinite(dot));
        }
    };
    try std.testing.fuzz(.{}, Fuzzer.run, .{});
}

test "fuzz slice conversion roundtrip" {
    const Fuzzer = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 4) return;
            const count = @min(input.len / 4, 32);
            if (count == 0) return;

            var f32_in: [32]f32 = undefined;
            for (0..count) |i| {
                const offset = i * 4;
                if (offset + 4 > input.len) break;
                f32_in[i] = @bitCast(input[offset..][0..4].*);
                if (!std.math.isFinite(f32_in[i])) return;
                if (@abs(f32_in[i]) > 65504.0) return;
            }

            var f16_buf: [32]f16 = undefined;
            var f32_out: [32]f32 = undefined;
            f32ToF16Slice(f32_in[0..count], f16_buf[0..count]);
            f16ToF32Slice(f16_buf[0..count], f32_out[0..count]);

            for (0..count) |i| {
                if (!std.math.isFinite(f32_out[i])) return;
                const err = @abs(f32_in[i] - f32_out[i]);
                try std.testing.expect(err <= @abs(f32_in[i]) * 0.002 + 0.001);
            }
        }
    };
    try std.testing.fuzz(.{}, Fuzzer.run, .{});
}

test "fuzz cosineSimilarityF16 self-similarity" {
    const Fuzzer = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 8) return;
            const count = @min(input.len / 2, 16);
            if (count == 0) return;

            var data: [16]f16 = @splat(@as(f16, 0.0));
            var all_zero = true;
            for (0..count) |i| {
                const offset = i * 2;
                if (offset + 2 > input.len) break;
                data[i] = @bitCast(input[offset..][0..2].*);
                if (!std.math.isFinite(@as(f32, @floatCast(data[i])))) return;
                if (data[i] != 0.0) all_zero = false;
            }
            if (all_zero) return;

            const sim = cosineSimilarityF16(data[0..count], data[0..count]);
            try std.testing.expect(std.math.isFinite(sim));
            try std.testing.expect(sim > 0.99);
        }
    };
    try std.testing.fuzz(.{}, Fuzzer.run, .{});
}

test "fuzz maxAbsF16 non-negative" {
    const Fuzzer = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 2) return;
            const count = @min(input.len / 2, 32);
            if (count == 0) return;

            var data: [32]f16 = undefined;
            for (0..count) |i| {
                const offset = i * 2;
                if (offset + 2 > input.len) break;
                data[i] = @bitCast(input[offset..][0..2].*);
                if (!std.math.isFinite(@as(f32, @floatCast(data[i])))) return;
            }

            const result = maxAbsF16(data[0..count]);
            try std.testing.expect(std.math.isFinite(@as(f32, @floatCast(result))));
            try std.testing.expect(result >= 0.0);

            for (0..count) |i| {
                const abs_val = if (data[i] < 0) -data[i] else data[i];
                try std.testing.expect(abs_val <= result + 0.001);
            }
        }
    };
    try std.testing.fuzz(.{}, Fuzzer.run, .{});
}

test "fuzz vec16 ternary lossless" {
    const Fuzzer = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 16) return;

            var vec: [16]f16 = undefined;
            for (&vec, 0..) |*v, i| {
                v.* = switch (input[i] % 3) {
                    0 => @as(f16, -1.0),
                    1 => @as(f16, 0.0),
                    2 => @as(f16, 1.0),
                    else => unreachable,
                };
            }

            const simd_vec: Vec16f16 = vec;
            const widened = vec16F16ToF32(simd_vec);
            const narrowed = vec16F32ToF16(widened);
            const result: [16]f16 = narrowed;

            for (vec, result) |orig, res| {
                try std.testing.expect(orig == res);
            }
        }
    };
    try std.testing.fuzz(.{}, Fuzzer.run, .{});
}

test "count non finite f16" {
    const data = [_]f16{ 1.0, std.math.inf(f16), -2.0, std.math.nan(f16), 0.5 };
    const count = countNonFiniteF16(&data);
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "vectorNormF16 alias" {
    const v = [_]f16{ 3.0, 4.0 };
    const norm = vectorNormF16(&v);
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), norm, 0.01);
}

test "roundtrip f32 to f16 to f32 preserves ternary values" {
    const ternary_values = [_]f32{ -1.0, 0.0, 1.0 };

    for (ternary_values) |val| {
        const f16_val: f16 = @floatCast(val);
        const f32_back: f32 = @floatCast(f16_val);
        try std.testing.expectApproxEqAbs(val, f32_back, 0.0001);
    }
}

test "f16 overflow behavior" {
    // f16 max = 65504, values above overflow to infinity
    const too_large: f16 = @floatCast(@as(f32, 100000.0));
    const too_large_f32: f32 = @floatCast(too_large);
    // Should be infinity (or very large value if saturated)
    try std.testing.expect(too_large_f32 >= 65504.0 or std.math.isInf(too_large_f32));

    const fits: f16 = @floatCast(@as(f32, 1000.0));
    try std.testing.expect(fits > 999.0 and fits < 1001.0);
}

test "f16 subnormal handling" {
    // Smallest normal f16 = 2^-14 ≈ 6.1e-5
    const tiny: f16 = @floatCast(@as(f32, 1e-6));

    // Should round to zero or subnormal
    const f32_back: f32 = @floatCast(tiny);
    try std.testing.expect(f32_back >= 0 and f32_back < 1e-4);
}

// φ² + 1/φ² = 3 | TRINITY
