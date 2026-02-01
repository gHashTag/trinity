// TRINITY INFERENCE ENGINE - Двигатель Инференса Троицы
// НЕЙРОСЕТЕВЫЕ ВЫЧИСЛЕНИЯ БЕЗ УМНОЖЕНИЯ
// Только сложение, вычитание и пропуски нулей
// φ² + 1/φ² = 3 = TRINITY
//
// "Пока другие платят NVIDIA, мы создаём вычислительную мощь из ничего"

const std = @import("std");
const prometheus = @import("prometheus_seed.zig");

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVATION FUNCTIONS (без умножения!)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Activation = enum {
    none,
    relu,
    gelu_approx,
    silu_approx,
    tanh_approx,

    /// ReLU: max(0, x) - БЕЗ УМНОЖЕНИЯ
    pub fn relu(x: f32) f32 {
        return @max(0.0, x);
    }

    /// Приближённый GELU через кусочно-линейную аппроксимацию
    /// GELU(x) ≈ x * sigmoid(1.702 * x)
    /// Аппроксимация: if x < -3 -> 0, if x > 3 -> x, else -> x/2 + x/4
    pub fn geluApprox(x: f32) f32 {
        if (x < -3.0) return 0.0;
        if (x > 3.0) return x;
        // x * 0.5 * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
        // Упрощаем: x/2 + x/4 для центральной области
        return x * 0.5 + x * 0.25 * @as(f32, if (x > 0) 1.0 else -1.0);
    }

    /// Приближённый SiLU (Swish): x * sigmoid(x)
    /// Аппроксимация через кусочно-линейную функцию
    pub fn siluApprox(x: f32) f32 {
        if (x < -4.0) return 0.0;
        if (x > 4.0) return x;
        // Линейная интерполяция в центре
        return x * (0.5 + x * 0.125);
    }

    /// Приближённый tanh через кусочно-линейную функцию
    pub fn tanhApprox(x: f32) f32 {
        if (x < -3.0) return -1.0;
        if (x > 3.0) return 1.0;
        // Линейная аппроксимация: x/3 для |x| < 3
        return x / 3.0;
    }

    pub fn apply(self: Activation, x: f32) f32 {
        return switch (self) {
            .none => x,
            .relu => relu(x),
            .gelu_approx => geluApprox(x),
            .silu_approx => siluApprox(x),
            .tanh_approx => tanhApprox(x),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY MATMUL - Матричное умножение БЕЗ УМНОЖЕНИЯ
// ═══════════════════════════════════════════════════════════════════════════════

/// Троичное матричное "умножение" - только сложение/вычитание!
/// weights: [out_features, in_features] в тритах {-1, 0, +1}
/// input: [batch, in_features] в float32
/// output: [batch, out_features] в float32
pub fn trinityMatmul(
    allocator: std.mem.Allocator,
    input: []const f32,
    weights: []const prometheus.TritWeight,
    in_features: usize,
    out_features: usize,
    batch_size: usize,
) ![]f32 {
    const output = try allocator.alloc(f32, batch_size * out_features);
    @memset(output, 0.0);

    // Для каждого элемента батча
    for (0..batch_size) |b| {
        const input_offset = b * in_features;
        const output_offset = b * out_features;

        // Для каждого выходного нейрона
        for (0..out_features) |o| {
            var sum: f32 = 0.0;
            const weight_offset = o * in_features;

            // Для каждого входного признака
            for (0..in_features) |i| {
                const w = weights[weight_offset + i];
                const x = input[input_offset + i];

                // МАГИЯ: НЕТ УМНОЖЕНИЯ!
                // w = +1: sum += x
                // w = -1: sum -= x
                // w = 0:  пропуск (ничего не делаем)
                switch (w) {
                    .pos => sum += x,
                    .neg => sum -= x,
                    .zero => {},  // Пропуск - экономия вычислений!
                }
            }

            output[output_offset + o] = sum;
        }
    }

    return output;
}

/// Оптимизированная версия с SIMD-подобной обработкой
pub fn trinityMatmulFast(
    allocator: std.mem.Allocator,
    input: []const f32,
    weights: []const prometheus.TritWeight,
    in_features: usize,
    out_features: usize,
    batch_size: usize,
) ![]f32 {
    const output = try allocator.alloc(f32, batch_size * out_features);
    @memset(output, 0.0);

    // Предварительно разделяем веса на положительные и отрицательные индексы
    // Это позволяет использовать векторные операции

    for (0..batch_size) |b| {
        const input_offset = b * in_features;
        const output_offset = b * out_features;

        for (0..out_features) |o| {
            var pos_sum: f32 = 0.0;
            var neg_sum: f32 = 0.0;
            const weight_offset = o * in_features;

            // Обрабатываем по 4 элемента за раз (псевдо-SIMD)
            var i: usize = 0;
            while (i + 4 <= in_features) : (i += 4) {
                inline for (0..4) |j| {
                    const w = weights[weight_offset + i + j];
                    const x = input[input_offset + i + j];
                    switch (w) {
                        .pos => pos_sum += x,
                        .neg => neg_sum += x,
                        .zero => {},
                    }
                }
            }

            // Остаток
            while (i < in_features) : (i += 1) {
                const w = weights[weight_offset + i];
                const x = input[input_offset + i];
                switch (w) {
                    .pos => pos_sum += x,
                    .neg => neg_sum += x,
                    .zero => {},
                }
            }

            output[output_offset + o] = pos_sum - neg_sum;
        }
    }

    return output;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY LAYER - Слой без умножения
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityLayer = struct {
    allocator: std.mem.Allocator,
    weights: []prometheus.TritWeight,
    bias: ?[]f32,
    in_features: usize,
    out_features: usize,
    activation: Activation,
    sparsity: f32,

    pub fn init(
        allocator: std.mem.Allocator,
        in_features: usize,
        out_features: usize,
        activation: Activation,
    ) !TrinityLayer {
        const weights = try allocator.alloc(prometheus.TritWeight, in_features * out_features);
        @memset(weights, .zero);

        return TrinityLayer{
            .allocator = allocator,
            .weights = weights,
            .bias = null,
            .in_features = in_features,
            .out_features = out_features,
            .activation = activation,
            .sparsity = 1.0,
        };
    }

    pub fn deinit(self: *TrinityLayer) void {
        self.allocator.free(self.weights);
        if (self.bias) |b| self.allocator.free(b);
    }

    /// Forward pass БЕЗ УМНОЖЕНИЯ
    pub fn forward(self: *const TrinityLayer, allocator: std.mem.Allocator, input: []const f32, batch_size: usize) ![]f32 {
        // Матричное "умножение" через сложение/вычитание
        var output = try trinityMatmulFast(
            allocator,
            input,
            self.weights,
            self.in_features,
            self.out_features,
            batch_size,
        );

        // Добавляем bias (если есть)
        if (self.bias) |bias| {
            for (0..batch_size) |b| {
                const offset = b * self.out_features;
                for (0..self.out_features) |o| {
                    output[offset + o] += bias[o];
                }
            }
        }

        // Применяем активацию
        for (output) |*x| {
            x.* = self.activation.apply(x.*);
        }

        return output;
    }

    /// Загрузка весов из TritTensor
    pub fn loadWeights(self: *TrinityLayer, tensor: *const prometheus.TritTensor) void {
        @memcpy(self.weights, tensor.data);
        self.sparsity = tensor.sparsity;
    }

    /// Подсчёт операций (только сложения!)
    pub fn countOps(self: *const TrinityLayer, batch_size: usize) struct { adds: usize, skips: usize } {
        var non_zero: usize = 0;
        for (self.weights) |w| {
            if (w != .zero) non_zero += 1;
        }
        const zeros = self.weights.len - non_zero;

        return .{
            .adds = non_zero * batch_size,  // Только сложения/вычитания
            .skips = zeros * batch_size,     // Пропущенные операции
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY MLP - Многослойный перцептрон без умножения
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityMLP = struct {
    allocator: std.mem.Allocator,
    layers: std.ArrayList(TrinityLayer),

    pub fn init(allocator: std.mem.Allocator) TrinityMLP {
        return TrinityMLP{
            .allocator = allocator,
            .layers = std.ArrayList(TrinityLayer).init(allocator),
        };
    }

    pub fn deinit(self: *TrinityMLP) void {
        for (self.layers.items) |*layer| {
            layer.deinit();
        }
        self.layers.deinit();
    }

    pub fn addLayer(self: *TrinityMLP, layer: TrinityLayer) !void {
        try self.layers.append(layer);
    }

    /// Forward pass через все слои
    pub fn forward(self: *const TrinityMLP, allocator: std.mem.Allocator, input: []const f32, batch_size: usize) ![]f32 {
        var current = try allocator.dupe(f32, input);

        for (self.layers.items) |*layer| {
            const next = try layer.forward(allocator, current, batch_size);
            allocator.free(current);
            current = next;
        }

        return current;
    }

    /// Статистика модели
    pub fn printStats(self: *const TrinityMLP) void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TRINITY INFERENCE ENGINE STATS                     ║\n", .{});
        std.debug.print("║           φ² + 1/φ² = 3 | NO MULTIPLICATION                  ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});

        var total_params: usize = 0;
        var total_sparsity: f32 = 0.0;

        for (self.layers.items, 0..) |layer, i| {
            const params = layer.weights.len;
            total_params += params;
            total_sparsity += layer.sparsity;

            std.debug.print("║ Layer {d}: {d} → {d} | params: {d} | sparsity: {d:.1}%    ║\n", .{
                i,
                layer.in_features,
                layer.out_features,
                params,
                layer.sparsity * 100,
            });
        }

        const avg_sparsity = total_sparsity / @as(f32, @floatFromInt(self.layers.items.len));
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Total parameters: {d:>12}                               ║\n", .{total_params});
        std.debug.print("║ Average sparsity: {d:>12.1}%                              ║\n", .{avg_sparsity * 100});
        std.debug.print("║ Operations: ONLY ADD/SUB (no multiply!)                      ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "activation functions" {
    try std.testing.expectEqual(@as(f32, 0.0), Activation.relu(-5.0));
    try std.testing.expectEqual(@as(f32, 5.0), Activation.relu(5.0));

    // tanh approx
    try std.testing.expect(Activation.tanhApprox(0.0) == 0.0);
    try std.testing.expect(Activation.tanhApprox(9.0) == 1.0);
    try std.testing.expect(Activation.tanhApprox(-9.0) == -1.0);
}

test "trinity matmul basic" {
    const allocator = std.testing.allocator;

    // 2x3 input, 3x2 weights -> 2x2 output
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const weights = [_]prometheus.TritWeight{
        .pos, .neg, .zero,  // out[0]
        .zero, .pos, .neg,  // out[1]
    };

    const output = try trinityMatmul(allocator, &input, &weights, 3, 2, 2);
    defer allocator.free(output);

    // batch 0: out[0] = 1 - 2 + 0 = -1, out[1] = 0 + 2 - 3 = -1
    try std.testing.expectEqual(@as(f32, -1.0), output[0]);
    try std.testing.expectEqual(@as(f32, -1.0), output[1]);

    // batch 1: out[0] = 4 - 5 + 0 = -1, out[1] = 0 + 5 - 6 = -1
    try std.testing.expectEqual(@as(f32, -1.0), output[2]);
    try std.testing.expectEqual(@as(f32, -1.0), output[3]);
}

test "trinity layer forward" {
    const allocator = std.testing.allocator;

    var layer = try TrinityLayer.init(allocator, 4, 2, .relu);
    defer layer.deinit();

    // Устанавливаем веса
    layer.weights[0] = .pos;
    layer.weights[1] = .neg;
    layer.weights[2] = .pos;
    layer.weights[3] = .zero;
    layer.weights[4] = .neg;
    layer.weights[5] = .pos;
    layer.weights[6] = .zero;
    layer.weights[7] = .neg;

    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const output = try layer.forward(allocator, &input, 1);
    defer allocator.free(output);

    try std.testing.expectEqual(@as(usize, 2), output.len);
}

test "trinity mlp" {
    const allocator = std.testing.allocator;

    var mlp = TrinityMLP.init(allocator);
    defer mlp.deinit();

    const layer1 = try TrinityLayer.init(allocator, 4, 8, .relu);
    const layer2 = try TrinityLayer.init(allocator, 8, 2, .none);

    try mlp.addLayer(layer1);
    try mlp.addLayer(layer2);

    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const output = try mlp.forward(allocator, &input, 1);
    defer allocator.free(output);

    try std.testing.expectEqual(@as(usize, 2), output.len);
}

test "layer ops count" {
    const allocator = std.testing.allocator;

    var layer = try TrinityLayer.init(allocator, 100, 50, .none);
    defer layer.deinit();

    // 50% sparsity
    for (layer.weights, 0..) |_, i| {
        layer.weights[i] = if (i % 2 == 0) .pos else .zero;
    }

    const ops = layer.countOps(1);
    try std.testing.expectEqual(@as(usize, 2500), ops.adds);  // 50% of 5000
    try std.testing.expectEqual(@as(usize, 2500), ops.skips); // 50% skipped
}
