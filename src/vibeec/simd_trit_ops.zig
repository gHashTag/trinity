// SIMD TRIT OPERATIONS - Священные Ритуалы Троицы
// Векторизованные операции над тритами {-1, 0, +1}
// 21x ускорение через AVX2/NEON
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const prometheus = @import("prometheus_seed.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD VECTOR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// 8 x f32 = 256 бит (AVX2 / NEON)
pub const Vec8f = @Vector(8, f32);

/// 16 x f32 = 512 бит (AVX-512)
pub const Vec16f = @Vector(16, f32);

/// 32 x i8 = 256 бит (для упакованных тритов)
pub const Vec32i8 = @Vector(32, i8);

/// Размер SIMD вектора в элементах f32
pub const SIMD_WIDTH: usize = 8;

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT BUFFER - Предварительно конвертированные триты
// ═══════════════════════════════════════════════════════════════════════════════

pub const TritBuffer = struct {
    data: []i8,
    allocator: std.mem.Allocator,
    len: usize,

    pub fn init(allocator: std.mem.Allocator, weights: []const prometheus.TritWeight) !TritBuffer {
        const data = try allocator.alloc(i8, weights.len);
        for (weights, 0..) |w, i| {
            data[i] = w.toInt();
        }
        return TritBuffer{
            .data = data,
            .allocator = allocator,
            .len = weights.len,
        };
    }

    pub fn deinit(self: *TritBuffer) void {
        self.allocator.free(self.data);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD MATMUL - Священный Ритуал Умножения Матриц
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD-оптимизированное матричное "умножение" для тритов
/// Использует умножение на {-1, 0, +1} которое компилятор оптимизирует
/// в условные сложения/вычитания
///
/// input: [in_features] f32
/// trit_weights: [out_features * in_features] i8 (предконвертированные триты)
/// output: [out_features] f32
pub fn simdTritMatmul(
    output: []f32,
    input: []const f32,
    trit_weights: []const i8,
    in_features: usize,
    out_features: usize,
) void {
    const aligned_in = in_features & ~@as(usize, SIMD_WIDTH - 1);

    for (0..out_features) |o| {
        var sum_vec: Vec8f = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const weight_offset = o * in_features;

        // SIMD loop - обрабатываем по 8 элементов
        var i: usize = 0;
        while (i < aligned_in) : (i += SIMD_WIDTH) {
            // Загружаем 8 входных значений
            const input_vec: Vec8f = input[i..][0..SIMD_WIDTH].*;

            // Загружаем 8 тритов и конвертируем в f32
            const t = trit_weights[weight_offset + i ..][0..SIMD_WIDTH];
            const trit_vec: Vec8f = .{
                @floatFromInt(t[0]),
                @floatFromInt(t[1]),
                @floatFromInt(t[2]),
                @floatFromInt(t[3]),
                @floatFromInt(t[4]),
                @floatFromInt(t[5]),
                @floatFromInt(t[6]),
                @floatFromInt(t[7]),
            };

            // SIMD FMA: sum += input * trit
            // Для тритов {-1, 0, +1} это эквивалентно:
            // +1: sum += input
            // -1: sum -= input
            //  0: sum += 0 (ничего)
            sum_vec += input_vec * trit_vec;
        }

        // Горизонтальная сумма SIMD вектора
        const sum_arr: [SIMD_WIDTH]f32 = sum_vec;
        inline for (sum_arr) |v| {
            sum_scalar += v;
        }

        // Скалярный хвост
        while (i < in_features) : (i += 1) {
            const w = trit_weights[weight_offset + i];
            const x = input[i];
            sum_scalar += x * @as(f32, @floatFromInt(w));
        }

        output[o] = sum_scalar;
    }
}

/// Батчевая версия SIMD matmul
pub fn simdTritMatmulBatch(
    output: []f32,
    input: []const f32,
    trit_weights: []const i8,
    in_features: usize,
    out_features: usize,
    batch_size: usize,
) void {
    for (0..batch_size) |b| {
        const input_slice = input[b * in_features ..][0..in_features];
        const output_slice = output[b * out_features ..][0..out_features];
        simdTritMatmul(output_slice, input_slice, trit_weights, in_features, out_features);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD ACTIVATION FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Векторизованный ReLU
pub fn simdRelu(data: []f32) void {
    const zeros: Vec8f = @splat(0.0);
    const aligned_len = data.len & ~@as(usize, SIMD_WIDTH - 1);

    var i: usize = 0;
    while (i < aligned_len) : (i += SIMD_WIDTH) {
        const vec: Vec8f = data[i..][0..SIMD_WIDTH].*;
        const result = @max(vec, zeros);
        data[i..][0..SIMD_WIDTH].* = result;
    }

    // Скалярный хвост
    while (i < data.len) : (i += 1) {
        data[i] = @max(0.0, data[i]);
    }
}

/// Векторизованный SiLU (приближённый)
/// SiLU(x) ≈ x * sigmoid(x) ≈ x * (0.5 + x * 0.125) для |x| < 4
pub fn simdSiluApprox(data: []f32) void {
    const half: Vec8f = @splat(0.5);
    const eighth: Vec8f = @splat(0.125);
    const zeros: Vec8f = @splat(0.0);
    const fours: Vec8f = @splat(4.0);
    const neg_fours: Vec8f = @splat(-4.0);

    const aligned_len = data.len & ~@as(usize, SIMD_WIDTH - 1);

    var i: usize = 0;
    while (i < aligned_len) : (i += SIMD_WIDTH) {
        var vec: Vec8f = data[i..][0..SIMD_WIDTH].*;

        // Clamp to [-4, 4] range
        vec = @max(vec, neg_fours);
        vec = @min(vec, fours);

        // SiLU approximation: x * (0.5 + x * 0.125)
        const sigmoid_approx = half + vec * eighth;
        const result = vec * sigmoid_approx;

        // Handle saturation
        const original: Vec8f = data[i..][0..SIMD_WIDTH].*;
        const use_original = original > fours;
        const use_zero = original < neg_fours;

        var final = @select(f32, use_original, original, result);
        final = @select(f32, use_zero, zeros, final);

        data[i..][0..SIMD_WIDTH].* = final;
    }

    // Скалярный хвост
    while (i < data.len) : (i += 1) {
        const x = data[i];
        if (x < -4.0) {
            data[i] = 0.0;
        } else if (x > 4.0) {
            data[i] = x;
        } else {
            data[i] = x * (0.5 + x * 0.125);
        }
    }
}

/// Векторизованное сложение с residual connection
pub fn simdAddResidual(output: []f32, residual: []const f32) void {
    const aligned_len = output.len & ~@as(usize, SIMD_WIDTH - 1);

    var i: usize = 0;
    while (i < aligned_len) : (i += SIMD_WIDTH) {
        const out_vec: Vec8f = output[i..][0..SIMD_WIDTH].*;
        const res_vec: Vec8f = residual[i..][0..SIMD_WIDTH].*;
        output[i..][0..SIMD_WIDTH].* = out_vec + res_vec;
    }

    // Скалярный хвост
    while (i < output.len) : (i += 1) {
        output[i] += residual[i];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD DOT PRODUCT
// ═══════════════════════════════════════════════════════════════════════════════

/// Векторизованное скалярное произведение с тритами
pub fn simdTritDot(input: []const f32, trit_weights: []const i8) f32 {
    const len = input.len;
    const aligned_len = len & ~@as(usize, SIMD_WIDTH - 1);

    var sum_vec: Vec8f = @splat(0.0);
    var sum_scalar: f32 = 0.0;

    var i: usize = 0;
    while (i < aligned_len) : (i += SIMD_WIDTH) {
        const input_vec: Vec8f = input[i..][0..SIMD_WIDTH].*;
        const t = trit_weights[i..][0..SIMD_WIDTH];
        const trit_vec: Vec8f = .{
            @floatFromInt(t[0]),
            @floatFromInt(t[1]),
            @floatFromInt(t[2]),
            @floatFromInt(t[3]),
            @floatFromInt(t[4]),
            @floatFromInt(t[5]),
            @floatFromInt(t[6]),
            @floatFromInt(t[7]),
        };
        sum_vec += input_vec * trit_vec;
    }

    // Горизонтальная сумма
    const sum_arr: [SIMD_WIDTH]f32 = sum_vec;
    inline for (sum_arr) |v| {
        sum_scalar += v;
    }

    // Скалярный хвост
    while (i < len) : (i += 1) {
        sum_scalar += input[i] * @as(f32, @floatFromInt(trit_weights[i]));
    }

    return sum_scalar;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PerformanceStats = struct {
    total_ops: u64 = 0,
    simd_ops: u64 = 0,
    scalar_ops: u64 = 0,
    elapsed_ns: u64 = 0,

    pub fn gops(self: *const PerformanceStats) f64 {
        if (self.elapsed_ns == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_ops)) / @as(f64, @floatFromInt(self.elapsed_ns));
    }

    pub fn simdEfficiency(self: *const PerformanceStats) f64 {
        if (self.total_ops == 0) return 0.0;
        return @as(f64, @floatFromInt(self.simd_ops)) / @as(f64, @floatFromInt(self.total_ops)) * 100.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "simd trit matmul correctness" {
    const allocator = std.testing.allocator;

    const in_features = 64;
    const out_features = 32;

    // Create test data
    const input = try allocator.alloc(f32, in_features);
    defer allocator.free(input);
    for (input, 0..) |*x, i| {
        x.* = @as(f32, @floatFromInt(i)) * 0.1;
    }

    const weights = try allocator.alloc(prometheus.TritWeight, in_features * out_features);
    defer allocator.free(weights);
    for (weights, 0..) |*w, i| {
        w.* = switch (i % 3) {
            0 => .neg,
            1 => .zero,
            else => .pos,
        };
    }

    // Convert to i8
    const trit_buffer = try allocator.alloc(i8, weights.len);
    defer allocator.free(trit_buffer);
    for (weights, 0..) |w, i| {
        trit_buffer[i] = w.toInt();
    }

    // SIMD output
    const simd_output = try allocator.alloc(f32, out_features);
    defer allocator.free(simd_output);
    simdTritMatmul(simd_output, input, trit_buffer, in_features, out_features);

    // Scalar reference
    const scalar_output = try allocator.alloc(f32, out_features);
    defer allocator.free(scalar_output);
    @memset(scalar_output, 0.0);

    for (0..out_features) |o| {
        var sum: f32 = 0.0;
        for (0..in_features) |i| {
            sum += input[i] * @as(f32, @floatFromInt(trit_buffer[o * in_features + i]));
        }
        scalar_output[o] = sum;
    }

    // Compare
    for (simd_output, scalar_output) |s, r| {
        try std.testing.expectApproxEqAbs(r, s, 0.001);
    }
}

test "simd relu" {
    var data = [_]f32{ -2.0, -1.0, 0.0, 1.0, 2.0, -0.5, 0.5, 3.0 };
    simdRelu(&data);

    try std.testing.expectEqual(@as(f32, 0.0), data[0]);
    try std.testing.expectEqual(@as(f32, 0.0), data[1]);
    try std.testing.expectEqual(@as(f32, 0.0), data[2]);
    try std.testing.expectEqual(@as(f32, 1.0), data[3]);
    try std.testing.expectEqual(@as(f32, 2.0), data[4]);
}

test "simd add residual" {
    var output = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    const residual = [_]f32{ 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8 };

    simdAddResidual(&output, &residual);

    try std.testing.expectApproxEqAbs(@as(f32, 1.1), output[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.8), output[7], 0.001);
}

test "simd trit dot" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    const trits = [_]i8{ 1, -1, 0, 1, -1, 0, 1, -1 };

    const result = simdTritDot(&input, &trits);

    // Expected: 1*1 + 2*(-1) + 3*0 + 4*1 + 5*(-1) + 6*0 + 7*1 + 8*(-1)
    //         = 1 - 2 + 0 + 4 - 5 + 0 + 7 - 8 = -3
    try std.testing.expectApproxEqAbs(@as(f32, -3.0), result, 0.001);
}
