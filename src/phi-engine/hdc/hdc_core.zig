//! HDC Core - Базовые операции гиперразмерных вычислений
//! с онлайн-обучением для самообучающихся AI моделей.
//!
//! Научная база:
//! - Kanerva (2009): Hyperdimensional Computing
//! - BitNet b1.58 (2024): Троичные веса {-1, 0, +1}
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// Константы
pub const DEFAULT_DIM: usize = 10240;
pub const LEARNING_RATE: f64 = 0.01;
pub const SIMILARITY_THRESHOLD: f64 = 0.7;
pub const SIMD_WIDTH: usize = 32;

pub const PHI: f64 = 1.618033988749895;

// Типы
pub const Trit = i8; // {-1, 0, +1}
pub const Vec32i8 = @Vector(32, i8);

/// Троичный гипервектор
pub const HyperVector = struct {
    data: []Trit,
    dim: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, dim: usize) !HyperVector {
        const data = try allocator.alloc(Trit, dim);
        @memset(data, 0);
        return .{ .data = data, .dim = dim, .allocator = allocator };
    }

    pub fn deinit(self: *HyperVector) void {
        self.allocator.free(self.data);
    }

    pub fn clone(self: *const HyperVector) !HyperVector {
        const new = try HyperVector.init(self.allocator, self.dim);
        @memcpy(new.data, self.data);
        return new;
    }
};

/// Float аккумулятор для онлайн усреднения
pub const FloatAccumulator = struct {
    data: []f64,
    dim: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, dim: usize) !FloatAccumulator {
        const data = try allocator.alloc(f64, dim);
        @memset(data, 0.0);
        return .{ .data = data, .dim = dim, .allocator = allocator };
    }

    pub fn deinit(self: *FloatAccumulator) void {
        self.allocator.free(self.data);
    }
};

/// Прототип класса
pub const Prototype = struct {
    label: []const u8,
    accumulator: FloatAccumulator,
    vector: HyperVector,
    count: u64,
};

/// Результат сходства
pub const SimilarityResult = struct {
    label: []const u8,
    similarity: f64,
};

// ═══════════════════════════════════════════════════════════════
// БАЗОВЫЕ HDC ОПЕРАЦИИ
// ═══════════════════════════════════════════════════════════════

/// Bind: поэлементное умножение (создание ассоциации)
pub fn bind(a: []const Trit, b: []const Trit, result: []Trit) void {
    const len = @min(a.len, @min(b.len, result.len));
    const chunks = len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b[i..][0..SIMD_WIDTH].*;
        result[i..][0..SIMD_WIDTH].* = a_vec * b_vec;
    }

    while (i < len) : (i += 1) {
        result[i] = a[i] * b[i];
    }
}

/// Unbind: то же что bind (самообратимость)
pub fn unbind(bound: []const Trit, key: []const Trit, result: []Trit) void {
    bind(bound, key, result);
}

/// Bundle: мажоритарное голосование для 2 векторов
pub fn bundle2(a: []const Trit, b: []const Trit, result: []Trit) void {
    const len = @min(a.len, @min(b.len, result.len));

    for (0..len) |i| {
        const sum: i16 = @as(i16, a[i]) + @as(i16, b[i]);
        if (sum > 0) {
            result[i] = 1;
        } else if (sum < 0) {
            result[i] = -1;
        } else {
            result[i] = 0;
        }
    }
}

/// Bundle: мажоритарное голосование для N векторов
pub fn bundleN(vectors: []const []const Trit, result: []Trit) void {
    if (vectors.len == 0) return;

    const dim = result.len;
    for (0..dim) |i| {
        var sum: i32 = 0;
        for (vectors) |v| {
            if (i < v.len) sum += v[i];
        }
        if (sum > 0) {
            result[i] = 1;
        } else if (sum < 0) {
            result[i] = -1;
        } else {
            result[i] = 0;
        }
    }
}

/// Permute: циклический сдвиг
pub fn permute(v: []const Trit, k: usize, result: []Trit) void {
    const len = v.len;
    if (len == 0) return;
    const shift = k % len;

    for (0..len) |i| {
        const new_pos = (i + shift) % len;
        result[new_pos] = v[i];
    }
}

// ═══════════════════════════════════════════════════════════════
// СХОДСТВО
// ═══════════════════════════════════════════════════════════════

/// Dot product с SIMD
pub fn dotProduct(a: []const Trit, b: []const Trit) i64 {
    const len = @min(a.len, b.len);
    var dot: i64 = 0;
    const chunks = len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b[i..][0..SIMD_WIDTH].*;
        const a_wide: @Vector(32, i16) = a_vec;
        const b_wide: @Vector(32, i16) = b_vec;
        dot += @reduce(.Add, a_wide * b_wide);
    }

    while (i < len) : (i += 1) {
        dot += @as(i64, a[i]) * @as(i64, b[i]);
    }

    return dot;
}

/// Косинусное сходство
pub fn similarity(a: []const Trit, b: []const Trit) f64 {
    const dot = dotProduct(a, b);
    var norm_a: i64 = 0;
    var norm_b: i64 = 0;

    for (0..@min(a.len, b.len)) |i| {
        norm_a += @as(i64, a[i]) * @as(i64, a[i]);
        norm_b += @as(i64, b[i]) * @as(i64, b[i]);
    }

    if (norm_a == 0 or norm_b == 0) return 0;
    return @as(f64, @floatFromInt(dot)) /
        (@sqrt(@as(f64, @floatFromInt(norm_a))) * @sqrt(@as(f64, @floatFromInt(norm_b))));
}

/// Расстояние Хэмминга
pub fn hammingDistance(a: []const Trit, b: []const Trit) usize {
    var dist: usize = 0;
    for (0..@min(a.len, b.len)) |i| {
        if (a[i] != b[i]) dist += 1;
    }
    return dist;
}

// ═══════════════════════════════════════════════════════════════
// СОЗДАНИЕ ВЕКТОРОВ
// ═══════════════════════════════════════════════════════════════

/// Случайный вектор
pub fn randomVector(allocator: std.mem.Allocator, dim: usize, seed: u64) !HyperVector {
    const vec = try HyperVector.init(allocator, dim);
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    for (vec.data) |*t| {
        t.* = @as(Trit, @intCast(random.intRangeAtMost(i8, -1, 1)));
    }
    return vec;
}

/// Нулевой вектор
pub fn zeroVector(allocator: std.mem.Allocator, dim: usize) !HyperVector {
    return HyperVector.init(allocator, dim);
}

/// Вектор из единиц
pub fn onesVector(allocator: std.mem.Allocator, dim: usize) !HyperVector {
    const vec = try HyperVector.init(allocator, dim);
    @memset(vec.data, 1);
    return vec;
}

// ═══════════════════════════════════════════════════════════════
// КВАНТИЗАЦИЯ
// ═══════════════════════════════════════════════════════════════

/// Float -> Ternary
pub fn quantizeToTernary(float_data: []const f64, result: []Trit) void {
    for (0..@min(float_data.len, result.len)) |i| {
        if (float_data[i] > 0.5) {
            result[i] = 1;
        } else if (float_data[i] < -0.5) {
            result[i] = -1;
        } else {
            result[i] = 0;
        }
    }
}

/// Ternary -> Float
pub fn dequantizeToFloat(trit_data: []const Trit, result: []f64) void {
    for (0..@min(trit_data.len, result.len)) |i| {
        result[i] = @floatFromInt(trit_data[i]);
    }
}

// ═══════════════════════════════════════════════════════════════
// ОНЛАЙН ОБУЧЕНИЕ
// ═══════════════════════════════════════════════════════════════

/// Онлайн обновление прототипа: P ← P + η(v - P)
pub fn onlineUpdate(accumulator: []f64, input: []const Trit, lr: f64) void {
    for (0..@min(accumulator.len, input.len)) |i| {
        const v: f64 = @floatFromInt(input[i]);
        accumulator[i] += lr * (v - accumulator[i]);
    }
}

/// Найти наиболее похожий прототип
pub fn findBestMatch(input: []const Trit, prototypes: []const Prototype) ?SimilarityResult {
    var best_sim: f64 = -2.0;
    var best_label: []const u8 = "";

    for (prototypes) |p| {
        const sim = similarity(input, p.vector.data);
        if (sim > best_sim) {
            best_sim = sim;
            best_label = p.label;
        }
    }

    if (best_sim > -2.0) {
        return .{ .label = best_label, .similarity = best_sim };
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════

test "bind self-inverse" {
    const allocator = std.testing.allocator;
    var a = try randomVector(allocator, 100, 12345);
    defer a.deinit();
    var b = try randomVector(allocator, 100, 67890);
    defer b.deinit();

    var bound = try HyperVector.init(allocator, 100);
    defer bound.deinit();
    var recovered = try HyperVector.init(allocator, 100);
    defer recovered.deinit();

    bind(a.data, b.data, bound.data);
    unbind(bound.data, b.data, recovered.data);

    // a * b * b = a * (b * b)
    // Для b != 0: b * b = 1, поэтому recovered = a
    // Для b == 0: a * 0 * 0 = 0, поэтому recovered = 0
    var matches: usize = 0;
    var nonzero_b: usize = 0;
    for (0..100) |i| {
        if (b.data[i] != 0) {
            nonzero_b += 1;
            if (recovered.data[i] == a.data[i]) matches += 1;
        }
    }
    // Должно совпадать для всех ненулевых b
    try std.testing.expect(matches == nonzero_b);
}

test "similarity identical" {
    const allocator = std.testing.allocator;
    var a = try randomVector(allocator, 100, 11111);
    defer a.deinit();

    const sim = similarity(a.data, a.data);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}

test "similarity orthogonal" {
    const allocator = std.testing.allocator;
    var a = try randomVector(allocator, 1000, 11111);
    defer a.deinit();
    var b = try randomVector(allocator, 1000, 22222);
    defer b.deinit();

    const sim = similarity(a.data, b.data);
    try std.testing.expect(@abs(sim) < 0.2);
}

test "quantization roundtrip" {
    var float_data = [_]f64{ 0.7, -0.3, 0.1, 0.9, -0.8 };
    var trit_data: [5]Trit = undefined;
    var back: [5]f64 = undefined;

    quantizeToTernary(&float_data, &trit_data);
    try std.testing.expectEqual(@as(Trit, 1), trit_data[0]);
    try std.testing.expectEqual(@as(Trit, 0), trit_data[1]);
    try std.testing.expectEqual(@as(Trit, 0), trit_data[2]);
    try std.testing.expectEqual(@as(Trit, 1), trit_data[3]);
    try std.testing.expectEqual(@as(Trit, -1), trit_data[4]);

    dequantizeToFloat(&trit_data, &back);
    try std.testing.expectEqual(@as(f64, 1.0), back[0]);
    try std.testing.expectEqual(@as(f64, -1.0), back[4]);
}

test "online update" {
    var acc = [_]f64{ 0.0, 0.0, 0.0 };
    const input = [_]Trit{ 1, -1, 1 };

    onlineUpdate(&acc, &input, 0.1);

    try std.testing.expectApproxEqAbs(@as(f64, 0.1), acc[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, -0.1), acc[1], 0.001);
}

test "bundle majority" {
    var a = [_]Trit{ 1, 1, -1 };
    var b = [_]Trit{ 1, -1, -1 };
    var result: [3]Trit = undefined;

    bundle2(&a, &b, &result);

    try std.testing.expectEqual(@as(Trit, 1), result[0]);
    try std.testing.expectEqual(@as(Trit, 0), result[1]);
    try std.testing.expectEqual(@as(Trit, -1), result[2]);
}
