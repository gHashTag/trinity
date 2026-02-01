// MISTRAL LOADER - Загрузчик модели Mistral 7B
// Конвертация Mistral в троичный формат TRINITY
// φ² + 1/φ² = 3 = TRINITY
//
// Mistral 7B архитектура:
// - vocab_size: 32000
// - hidden_size: 4096
// - intermediate_size: 14336
// - num_hidden_layers: 32
// - num_attention_heads: 32
// - num_key_value_heads: 8 (GQA)
// - max_position_embeddings: 32768
// - sliding_window: 4096

const std = @import("std");
const safetensors = @import("safetensors_parser.zig");
const prometheus = @import("prometheus_seed.zig");
const trinity_engine = @import("trinity_inference_engine.zig");
const trinity_llm = @import("trinity_llm.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// MISTRAL CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const MistralConfig = struct {
    vocab_size: usize = 32000,
    hidden_size: usize = 4096,
    intermediate_size: usize = 14336,
    num_hidden_layers: usize = 32,
    num_attention_heads: usize = 32,
    num_key_value_heads: usize = 8,
    max_position_embeddings: usize = 32768,
    sliding_window: usize = 4096,
    rope_theta: f32 = 10000.0,
    rms_norm_eps: f32 = 1e-5,

    pub fn headDim(self: MistralConfig) usize {
        return self.hidden_size / self.num_attention_heads;
    }

    pub fn totalParams(self: MistralConfig) usize {
        var total: usize = 0;

        // Embedding
        total += self.vocab_size * self.hidden_size;

        // Per layer
        const per_layer =
            // Attention
            self.hidden_size * self.hidden_size + // q_proj
            self.hidden_size * (self.hidden_size / self.num_attention_heads * self.num_key_value_heads) + // k_proj
            self.hidden_size * (self.hidden_size / self.num_attention_heads * self.num_key_value_heads) + // v_proj
            self.hidden_size * self.hidden_size + // o_proj
            // MLP
            self.hidden_size * self.intermediate_size + // gate_proj
            self.hidden_size * self.intermediate_size + // up_proj
            self.intermediate_size * self.hidden_size + // down_proj
            // Norms
            self.hidden_size * 2; // input_layernorm + post_attention_layernorm

        total += per_layer * self.num_hidden_layers;

        // Final norm + lm_head
        total += self.hidden_size; // norm
        total += self.hidden_size * self.vocab_size; // lm_head

        return total;
    }

    /// Конфигурация для маленькой тестовой модели
    pub fn tiny() MistralConfig {
        return MistralConfig{
            .vocab_size = 256,
            .hidden_size = 64,
            .intermediate_size = 128,
            .num_hidden_layers = 2,
            .num_attention_heads = 4,
            .num_key_value_heads = 2,
            .max_position_embeddings = 512,
            .sliding_window = 256,
        };
    }

    /// Конфигурация Mistral 7B
    pub fn mistral7B() MistralConfig {
        return MistralConfig{};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER NAMES
// ═══════════════════════════════════════════════════════════════════════════════

pub const LayerNames = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LayerNames {
        return LayerNames{ .allocator = allocator };
    }

    pub fn embedding(self: LayerNames) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.embed_tokens.weight", .{});
    }

    pub fn qProj(self: LayerNames, layer: usize) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.layers.{d}.self_attn.q_proj.weight", .{layer});
    }

    pub fn kProj(self: LayerNames, layer: usize) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.layers.{d}.self_attn.k_proj.weight", .{layer});
    }

    pub fn vProj(self: LayerNames, layer: usize) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.layers.{d}.self_attn.v_proj.weight", .{layer});
    }

    pub fn oProj(self: LayerNames, layer: usize) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.layers.{d}.self_attn.o_proj.weight", .{layer});
    }

    pub fn gateProj(self: LayerNames, layer: usize) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.layers.{d}.mlp.gate_proj.weight", .{layer});
    }

    pub fn upProj(self: LayerNames, layer: usize) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.layers.{d}.mlp.up_proj.weight", .{layer});
    }

    pub fn downProj(self: LayerNames, layer: usize) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.layers.{d}.mlp.down_proj.weight", .{layer});
    }

    pub fn inputLayernorm(self: LayerNames, layer: usize) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.layers.{d}.input_layernorm.weight", .{layer});
    }

    pub fn postAttnLayernorm(self: LayerNames, layer: usize) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.layers.{d}.post_attention_layernorm.weight", .{layer});
    }

    pub fn finalNorm(self: LayerNames) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "model.norm.weight", .{});
    }

    pub fn lmHead(self: LayerNames) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "lm_head.weight", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MISTRAL LOADER
// ═══════════════════════════════════════════════════════════════════════════════

pub const MistralLoader = struct {
    allocator: std.mem.Allocator,
    config: MistralConfig,
    quantizer: prometheus.Quantizer,
    model: prometheus.TritModel,
    stats: LoaderStats,

    pub const LoaderStats = struct {
        tensors_loaded: usize,
        tensors_quantized: usize,
        total_params: usize,
        original_size_mb: f64,
        quantized_size_mb: f64,
        compression_ratio: f64,
    };

    pub fn init(allocator: std.mem.Allocator, config: MistralConfig, threshold: f32) MistralLoader {
        return MistralLoader{
            .allocator = allocator,
            .config = config,
            .quantizer = prometheus.Quantizer.init(threshold),
            .model = prometheus.TritModel.init(allocator, "mistral"),
            .stats = std.mem.zeroes(LoaderStats),
        };
    }

    pub fn deinit(self: *MistralLoader) void {
        self.model.deinit();
    }

    /// Загрузка и квантизация модели из safetensors
    pub fn loadFromSafetensors(self: *MistralLoader, path: []const u8) !void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           PROMETHEUS: LOADING MISTRAL                        ║\n", .{});
        std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Loading: {s:<51} ║\n", .{path});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

        var sf = try safetensors.SafetensorsFile.open(self.allocator, path);
        defer sf.deinit();

        sf.printInfo();

        const names = LayerNames.init(self.allocator);

        // Загружаем embedding
        try self.loadAndQuantizeTensor(&sf, try names.embedding(), .embedding);

        // Загружаем слои
        for (0..self.config.num_hidden_layers) |layer| {
            std.debug.print("  Loading layer {d}/{d}...\n", .{ layer + 1, self.config.num_hidden_layers });

            // Attention
            try self.loadAndQuantizeTensor(&sf, try names.qProj(layer), .attention_qkv);
            try self.loadAndQuantizeTensor(&sf, try names.kProj(layer), .attention_qkv);
            try self.loadAndQuantizeTensor(&sf, try names.vProj(layer), .attention_qkv);
            try self.loadAndQuantizeTensor(&sf, try names.oProj(layer), .attention_out);

            // MLP
            try self.loadAndQuantizeTensor(&sf, try names.gateProj(layer), .mlp_gate);
            try self.loadAndQuantizeTensor(&sf, try names.upProj(layer), .mlp_up);
            try self.loadAndQuantizeTensor(&sf, try names.downProj(layer), .mlp_down);

            // Norms (не квантизуем, сохраняем как есть)
            // try self.loadAndQuantizeTensor(&sf, try names.inputLayernorm(layer), .norm);
            // try self.loadAndQuantizeTensor(&sf, try names.postAttnLayernorm(layer), .norm);
        }

        // Final norm и lm_head
        try self.loadAndQuantizeTensor(&sf, try names.lmHead(), .linear);

        self.printStats();
    }

    fn loadAndQuantizeTensor(
        self: *MistralLoader,
        sf: *safetensors.SafetensorsFile,
        name: []const u8,
        layer_type: prometheus.TritLayer.LayerType,
    ) !void {
        defer self.allocator.free(name);

        // Получаем данные тензора
        const weights = sf.getTensorF32(self.allocator, name) catch |err| {
            std.debug.print("  Warning: tensor '{s}' not found: {}\n", .{ name, err });
            return;
        };
        defer self.allocator.free(weights);

        self.stats.tensors_loaded += 1;
        self.stats.total_params += weights.len;
        self.stats.original_size_mb += @as(f64, @floatFromInt(weights.len * 4)) / (1024 * 1024);

        // Квантизуем
        const info = sf.tensors.get(name) orelse return;
        const tensor = try self.quantizer.quantize(self.allocator, weights, info.shape);

        self.stats.tensors_quantized += 1;
        self.stats.quantized_size_mb += @as(f64, @floatFromInt(weights.len / 4)) / (1024 * 1024);

        // Добавляем в модель
        try self.model.addLayer(prometheus.TritLayer{
            .name = name,
            .weights = tensor,
            .bias = null,
            .layer_type = layer_type,
        });
    }

    fn printStats(self: *const MistralLoader) void {
        const compression_ratio = self.stats.original_size_mb / @max(self.stats.quantized_size_mb, 0.001);

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           PROMETHEUS: QUANTIZATION COMPLETE                  ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Tensors loaded:     {d:>12}                               ║\n", .{self.stats.tensors_loaded});
        std.debug.print("║ Tensors quantized:  {d:>12}                               ║\n", .{self.stats.tensors_quantized});
        std.debug.print("║ Total parameters:   {d:>12}                               ║\n", .{self.stats.total_params});
        std.debug.print("║ Original size:      {d:>12.2} MB                           ║\n", .{self.stats.original_size_mb});
        std.debug.print("║ Quantized size:     {d:>12.2} MB                           ║\n", .{self.stats.quantized_size_mb});
        std.debug.print("║ Compression:        {d:>12.1}x                             ║\n", .{compression_ratio});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ φ² + 1/φ² = 3 = TRINITY | NO MULTIPLICATION                  ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

        self.quantizer.printStats();
    }

    /// Сохранение квантизованной модели
    pub fn save(self: *const MistralLoader, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        const writer = file.writer();

        // Заголовок
        try writer.writeAll("TRINITY_MODEL_V1\n");
        try writer.print("name: mistral\n", .{});
        try writer.print("vocab_size: {d}\n", .{self.config.vocab_size});
        try writer.print("hidden_size: {d}\n", .{self.config.hidden_size});
        try writer.print("num_layers: {d}\n", .{self.config.num_hidden_layers});
        try writer.print("total_params: {d}\n", .{self.stats.total_params});
        try writer.writeAll("---\n");
        try writer.writeAll("END\n");

        std.debug.print("Model saved to: {s}\n", .{path});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY MODEL FILE FORMAT (.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityModelFile = struct {
    allocator: std.mem.Allocator,
    config: MistralConfig,
    layers: std.ArrayList(TrinityLayerData),

    pub const TrinityLayerData = struct {
        name: []const u8,
        shape: []const usize,
        data: []prometheus.TritWeight,
    };

    pub fn init(allocator: std.mem.Allocator, config: MistralConfig) TrinityModelFile {
        return TrinityModelFile{
            .allocator = allocator,
            .config = config,
            .layers = std.ArrayList(TrinityLayerData).init(allocator),
        };
    }

    pub fn deinit(self: *TrinityModelFile) void {
        for (self.layers.items) |layer| {
            self.allocator.free(layer.data);
            self.allocator.free(layer.shape);
        }
        self.layers.deinit();
    }

    /// Сохранение в .tri формат
    pub fn save(self: *const TrinityModelFile, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        const writer = file.writer();

        // Магическое число
        try writer.writeAll("TRI1");

        // Конфигурация
        try writer.writeInt(u32, @intCast(self.config.vocab_size), .little);
        try writer.writeInt(u32, @intCast(self.config.hidden_size), .little);
        try writer.writeInt(u32, @intCast(self.config.intermediate_size), .little);
        try writer.writeInt(u32, @intCast(self.config.num_hidden_layers), .little);
        try writer.writeInt(u32, @intCast(self.config.num_attention_heads), .little);
        try writer.writeInt(u32, @intCast(self.config.num_key_value_heads), .little);

        // Количество слоёв
        try writer.writeInt(u32, @intCast(self.layers.items.len), .little);

        // Слои
        for (self.layers.items) |layer| {
            // Имя слоя
            try writer.writeInt(u32, @intCast(layer.name.len), .little);
            try writer.writeAll(layer.name);

            // Shape
            try writer.writeInt(u32, @intCast(layer.shape.len), .little);
            for (layer.shape) |dim| {
                try writer.writeInt(u32, @intCast(dim), .little);
            }

            // Данные (упакованные триты: 4 трита на байт)
            const packed_size = (layer.data.len + 3) / 4;
            try writer.writeInt(u64, layer.data.len, .little);

            var packed_data = try self.allocator.alloc(u8, packed_size);
            defer self.allocator.free(packed_data);
            @memset(packed_data, 0);

            for (layer.data, 0..) |trit, i| {
                const byte_idx = i / 4;
                const bit_offset: u3 = @intCast((i % 4) * 2);
                const value: u8 = @intCast(@as(i8, trit.toInt()) + 1); // 0, 1, 2
                packed_data[byte_idx] |= value << bit_offset;
            }

            try writer.writeAll(packed_data);
        }
    }

    /// Загрузка из .tri формата
    pub fn load(allocator: std.mem.Allocator, path: []const u8) !TrinityModelFile {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const reader = file.reader();

        // Магическое число
        var magic: [4]u8 = undefined;
        _ = try reader.readAll(&magic);
        if (!std.mem.eql(u8, &magic, "TRI1")) return error.InvalidFormat;

        // Конфигурация
        var config = MistralConfig{};
        config.vocab_size = try reader.readInt(u32, .little);
        config.hidden_size = try reader.readInt(u32, .little);
        config.intermediate_size = try reader.readInt(u32, .little);
        config.num_hidden_layers = try reader.readInt(u32, .little);
        config.num_attention_heads = try reader.readInt(u32, .little);
        config.num_key_value_heads = try reader.readInt(u32, .little);

        var model = TrinityModelFile.init(allocator, config);

        // Количество слоёв
        const num_layers = try reader.readInt(u32, .little);

        // Слои
        for (0..num_layers) |_| {
            // Имя
            const name_len = try reader.readInt(u32, .little);
            const name = try allocator.alloc(u8, name_len);
            _ = try reader.readAll(name);

            // Shape
            const shape_len = try reader.readInt(u32, .little);
            const shape = try allocator.alloc(usize, shape_len);
            for (shape) |*dim| {
                dim.* = try reader.readInt(u32, .little);
            }

            // Данные
            const data_len = try reader.readInt(u64, .little);
            const packed_size = (data_len + 3) / 4;
            const packed_data = try allocator.alloc(u8, packed_size);
            defer allocator.free(packed_data);
            _ = try reader.readAll(packed_data);

            // Распаковка
            const data = try allocator.alloc(prometheus.TritWeight, data_len);
            for (0..data_len) |i| {
                const byte_idx = i / 4;
                const bit_offset: u3 = @intCast((i % 4) * 2);
                const value: u8 = (packed_data[byte_idx] >> bit_offset) & 0x3;
                data[i] = prometheus.TritWeight.fromFloat(@as(f32, @floatFromInt(@as(i8, @intCast(value)) - 1)), 0.0);
            }

            try model.layers.append(TrinityLayerData{
                .name = name,
                .shape = shape,
                .data = data,
            });
        }

        return model;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "mistral config" {
    const config = MistralConfig.mistral7B();
    try std.testing.expectEqual(@as(usize, 32000), config.vocab_size);
    try std.testing.expectEqual(@as(usize, 4096), config.hidden_size);
    try std.testing.expectEqual(@as(usize, 32), config.num_hidden_layers);
}

test "mistral config tiny" {
    const config = MistralConfig.tiny();
    try std.testing.expectEqual(@as(usize, 256), config.vocab_size);
    try std.testing.expectEqual(@as(usize, 64), config.hidden_size);
    try std.testing.expectEqual(@as(usize, 2), config.num_hidden_layers);
}

test "mistral config head dim" {
    const config = MistralConfig.mistral7B();
    try std.testing.expectEqual(@as(usize, 128), config.headDim());
}

test "layer names" {
    const names = LayerNames.init(std.testing.allocator);

    const q_proj = try names.qProj(5);
    defer std.testing.allocator.free(q_proj);
    try std.testing.expect(std.mem.indexOf(u8, q_proj, "layers.5") != null);
    try std.testing.expect(std.mem.indexOf(u8, q_proj, "q_proj") != null);
}

test "mistral loader init" {
    const config = MistralConfig.tiny();
    var loader = MistralLoader.init(std.testing.allocator, config, 0.1);
    defer loader.deinit();

    try std.testing.expectEqual(@as(usize, 256), loader.config.vocab_size);
}
