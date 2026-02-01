// PROMETHEUS SEED - Семя Прометея
// Квантизация весов нейросети в триты {-1, 0, +1}
// БЕЗ УМНОЖЕНИЯ. БЕЗ GPU. БЕЗ NVIDIA.
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const trit_logic = @import("trit_logic.zig");

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT WEIGHT - Троичный вес
// ═══════════════════════════════════════════════════════════════════════════════

pub const TritWeight = enum(i8) {
    neg = -1,  // Отрицательный вес
    zero = 0,  // Нулевой вес (пропуск)
    pos = 1,   // Положительный вес

    pub fn fromFloat(f: f32, threshold: f32) TritWeight {
        if (f > threshold) return .pos;
        if (f < -threshold) return .neg;
        return .zero;
    }

    pub fn toInt(self: TritWeight) i8 {
        return @intFromEnum(self);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT TENSOR - Троичный тензор
// ═══════════════════════════════════════════════════════════════════════════════

pub const TritTensor = struct {
    allocator: std.mem.Allocator,
    data: []TritWeight,
    shape: []usize,
    sparsity: f32,  // Доля нулей

    pub fn init(allocator: std.mem.Allocator, shape: []const usize) !TritTensor {
        var total: usize = 1;
        for (shape) |dim| total *= dim;

        const shape_copy = try allocator.dupe(usize, shape);
        const data = try allocator.alloc(TritWeight, total);
        @memset(data, .zero);

        return TritTensor{
            .allocator = allocator,
            .data = data,
            .shape = shape_copy,
            .sparsity = 1.0,
        };
    }

    pub fn deinit(self: *TritTensor) void {
        self.allocator.free(self.data);
        self.allocator.free(self.shape);
    }

    pub fn size(self: *const TritTensor) usize {
        return self.data.len;
    }

    pub fn computeSparsity(self: *TritTensor) void {
        var zeros: usize = 0;
        for (self.data) |w| {
            if (w == .zero) zeros += 1;
        }
        self.sparsity = @as(f32, @floatFromInt(zeros)) / @as(f32, @floatFromInt(self.data.len));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTIZER - Квантизатор весов
// ═══════════════════════════════════════════════════════════════════════════════

pub const Quantizer = struct {
    threshold: f32,
    stats: QuantizationStats,

    pub const QuantizationStats = struct {
        total_weights: usize,
        positive_weights: usize,
        negative_weights: usize,
        zero_weights: usize,
        original_bits: usize,
        quantized_bits: usize,
        compression_ratio: f32,
    };

    pub fn init(threshold: f32) Quantizer {
        return Quantizer{
            .threshold = threshold,
            .stats = std.mem.zeroes(QuantizationStats),
        };
    }

    /// Квантизация float32 весов в триты
    pub fn quantize(self: *Quantizer, allocator: std.mem.Allocator, weights: []const f32, shape: []const usize) !TritTensor {
        var tensor = try TritTensor.init(allocator, shape);

        self.stats.total_weights = weights.len;
        self.stats.positive_weights = 0;
        self.stats.negative_weights = 0;
        self.stats.zero_weights = 0;

        for (weights, 0..) |w, i| {
            const trit = TritWeight.fromFloat(w, self.threshold);
            tensor.data[i] = trit;

            switch (trit) {
                .pos => self.stats.positive_weights += 1,
                .neg => self.stats.negative_weights += 1,
                .zero => self.stats.zero_weights += 1,
            }
        }

        tensor.computeSparsity();

        // Статистика сжатия
        self.stats.original_bits = weights.len * 32;  // float32
        self.stats.quantized_bits = weights.len * 2;   // 2 бита на трит
        self.stats.compression_ratio = @as(f32, @floatFromInt(self.stats.original_bits)) / 
                                       @as(f32, @floatFromInt(self.stats.quantized_bits));

        return tensor;
    }

    pub fn printStats(self: *const Quantizer) void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           PROMETHEUS QUANTIZATION STATS                      ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Total weights:    {d:>12}                               ║\n", .{self.stats.total_weights});
        std.debug.print("║ Positive (+1):    {d:>12} ({d:.1}%)                       ║\n", .{
            self.stats.positive_weights,
            @as(f32, @floatFromInt(self.stats.positive_weights)) / @as(f32, @floatFromInt(self.stats.total_weights)) * 100,
        });
        std.debug.print("║ Negative (-1):    {d:>12} ({d:.1}%)                       ║\n", .{
            self.stats.negative_weights,
            @as(f32, @floatFromInt(self.stats.negative_weights)) / @as(f32, @floatFromInt(self.stats.total_weights)) * 100,
        });
        std.debug.print("║ Zero (0):         {d:>12} ({d:.1}%)                       ║\n", .{
            self.stats.zero_weights,
            @as(f32, @floatFromInt(self.stats.zero_weights)) / @as(f32, @floatFromInt(self.stats.total_weights)) * 100,
        });
        std.debug.print("║ Compression:      {d:.1}x (32-bit → 2-bit)                  ║\n", .{self.stats.compression_ratio});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT MODEL - Троичная модель
// ═══════════════════════════════════════════════════════════════════════════════

pub const TritLayer = struct {
    name: []const u8,
    weights: TritTensor,
    bias: ?TritTensor,
    layer_type: LayerType,

    pub const LayerType = enum {
        linear,
        embedding,
        attention_qkv,
        attention_out,
        mlp_gate,
        mlp_up,
        mlp_down,
        norm,
    };
};

pub const TritModel = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    layers: std.ArrayList(TritLayer),
    vocab_size: usize,
    hidden_size: usize,
    num_layers: usize,
    total_params: usize,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) TritModel {
        return TritModel{
            .allocator = allocator,
            .name = name,
            .layers = std.ArrayList(TritLayer).init(allocator),
            .vocab_size = 0,
            .hidden_size = 0,
            .num_layers = 0,
            .total_params = 0,
        };
    }

    pub fn deinit(self: *TritModel) void {
        for (self.layers.items) |*layer| {
            layer.weights.deinit();
            if (layer.bias) |*b| b.deinit();
        }
        self.layers.deinit();
    }

    pub fn addLayer(self: *TritModel, layer: TritLayer) !void {
        self.total_params += layer.weights.size();
        if (layer.bias) |b| self.total_params += b.size();
        try self.layers.append(layer);
    }

    /// Сохранение в .tri формат
    pub fn save(self: *const TritModel, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        const writer = file.writer();

        // Заголовок
        try writer.writeAll("TRINITY_MODEL_V1\n");
        try writer.print("name: {s}\n", .{self.name});
        try writer.print("vocab_size: {d}\n", .{self.vocab_size});
        try writer.print("hidden_size: {d}\n", .{self.hidden_size});
        try writer.print("num_layers: {d}\n", .{self.num_layers});
        try writer.print("total_params: {d}\n", .{self.total_params});
        try writer.writeAll("---\n");

        // Слои (бинарно)
        for (self.layers.items) |layer| {
            try writer.print("LAYER: {s}\n", .{layer.name});
            for (layer.weights.data) |w| {
                try writer.writeByte(@as(u8, @bitCast(w.toInt() + 1)));  // 0, 1, 2
            }
            try writer.writeAll("\n");
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "trit weight from float" {
    try std.testing.expectEqual(TritWeight.pos, TritWeight.fromFloat(0.5, 0.1));
    try std.testing.expectEqual(TritWeight.neg, TritWeight.fromFloat(-0.5, 0.1));
    try std.testing.expectEqual(TritWeight.zero, TritWeight.fromFloat(0.05, 0.1));
}

test "quantizer basic" {
    var quantizer = Quantizer.init(0.1);
    const weights = [_]f32{ 0.5, -0.3, 0.02, 0.8, -0.9, 0.0 };
    const shape = [_]usize{6};

    var tensor = try quantizer.quantize(std.testing.allocator, &weights, &shape);
    defer tensor.deinit();

    try std.testing.expectEqual(@as(usize, 6), tensor.size());
    try std.testing.expectEqual(TritWeight.pos, tensor.data[0]);
    try std.testing.expectEqual(TritWeight.neg, tensor.data[1]);
    try std.testing.expectEqual(TritWeight.zero, tensor.data[2]);
}

test "trit tensor sparsity" {
    var quantizer = Quantizer.init(0.1);
    const weights = [_]f32{ 0.0, 0.0, 0.5, 0.0, -0.5, 0.0 };
    const shape = [_]usize{6};

    var tensor = try quantizer.quantize(std.testing.allocator, &weights, &shape);
    defer tensor.deinit();

    // 4 из 6 = 66.7% нулей
    try std.testing.expect(tensor.sparsity > 0.6);
}

test "trit model init" {
    var model = TritModel.init(std.testing.allocator, "test_model");
    defer model.deinit();

    try std.testing.expect(std.mem.eql(u8, model.name, "test_model"));
}
