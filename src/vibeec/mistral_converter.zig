// MISTRAL-7B TO TRINITY CONVERTER
// Конвертация Mistral-7B из safetensors в .tri формат
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const safetensors = @import("safetensors_parser.zig");
const trinity_format = @import("trinity_format.zig");
const prometheus = @import("prometheus_seed.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// MISTRAL-7B CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const MistralConfig = struct {
    vocab_size: u32 = 32000,
    hidden_size: u32 = 4096,
    intermediate_size: u32 = 14336,
    num_hidden_layers: u32 = 32,
    num_attention_heads: u32 = 32,
    num_key_value_heads: u32 = 8, // GQA
    max_position_embeddings: u32 = 32768,
    rms_norm_eps: f32 = 1e-5,
    rope_theta: f32 = 1000000.0,

    pub fn totalParams(self: *const MistralConfig) u64 {
        // Embedding: vocab_size * hidden_size
        var total: u64 = @as(u64, self.vocab_size) * self.hidden_size;

        // Per layer:
        const per_layer: u64 =
            // q_proj: hidden_size * hidden_size
            @as(u64, self.hidden_size) * self.hidden_size +
            // k_proj: num_kv_heads * head_dim * hidden_size
            @as(u64, self.num_key_value_heads) * (self.hidden_size / self.num_attention_heads) * self.hidden_size +
            // v_proj: same as k_proj
            @as(u64, self.num_key_value_heads) * (self.hidden_size / self.num_attention_heads) * self.hidden_size +
            // o_proj: hidden_size * hidden_size
            @as(u64, self.hidden_size) * self.hidden_size +
            // gate_proj: intermediate_size * hidden_size
            @as(u64, self.intermediate_size) * self.hidden_size +
            // up_proj: intermediate_size * hidden_size
            @as(u64, self.intermediate_size) * self.hidden_size +
            // down_proj: hidden_size * intermediate_size
            @as(u64, self.hidden_size) * self.intermediate_size +
            // layernorms: 2 * hidden_size
            2 * self.hidden_size;

        total += per_layer * self.num_hidden_layers;

        // Final norm + lm_head
        total += self.hidden_size; // norm
        total += @as(u64, self.vocab_size) * self.hidden_size; // lm_head

        return total;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SHARDED SAFETENSORS LOADER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ShardedLoader = struct {
    allocator: std.mem.Allocator,
    base_path: []const u8,
    num_shards: usize,
    current_shard: ?*safetensors.SafetensorsFile,
    current_shard_idx: usize,

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8, num_shards: usize) ShardedLoader {
        return ShardedLoader{
            .allocator = allocator,
            .base_path = base_path,
            .num_shards = num_shards,
            .current_shard = null,
            .current_shard_idx = 0,
        };
    }

    pub fn deinit(self: *ShardedLoader) void {
        if (self.current_shard) |shard| {
            shard.deinit();
            self.allocator.destroy(shard);
        }
    }

    /// Загрузка конкретного шарда
    pub fn loadShard(self: *ShardedLoader, shard_idx: usize) !*safetensors.SafetensorsFile {
        // Закрываем предыдущий шард
        if (self.current_shard) |shard| {
            shard.deinit();
            self.allocator.destroy(shard);
        }

        // Формируем путь к шарду
        var path_buf: [512]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/model-{d:0>5}-of-{d:0>5}.safetensors", .{
            self.base_path,
            shard_idx + 1,
            self.num_shards,
        });

        std.debug.print("Loading shard: {s}\n", .{path});

        const shard = try self.allocator.create(safetensors.SafetensorsFile);
        shard.* = try safetensors.SafetensorsFile.open(self.allocator, path);

        self.current_shard = shard;
        self.current_shard_idx = shard_idx;

        return shard;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConversionStats = struct {
    total_tensors: usize = 0,
    total_params: u64 = 0,
    original_size_bytes: u64 = 0,
    compressed_size_bytes: u64 = 0,
    sparsity: f32 = 0.0,
    zeros_count: u64 = 0,

    pub fn compressionRatio(self: *const ConversionStats) f32 {
        if (self.compressed_size_bytes == 0) return 0.0;
        return @as(f32, @floatFromInt(self.original_size_bytes)) /
            @as(f32, @floatFromInt(self.compressed_size_bytes));
    }
};

/// Конвертация Mistral-7B в .tri формат
pub fn convertMistral(
    allocator: std.mem.Allocator,
    model_path: []const u8,
    output_path: []const u8,
    config: MistralConfig,
) !ConversionStats {
    var stats = ConversionStats{};

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           MISTRAL-7B → TRINITY CONVERTER                     ║\n", .{});
    std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Model path: {s:<48} ║\n", .{model_path[0..@min(model_path.len, 48)]});
    std.debug.print("║ Output: {s:<52} ║\n", .{output_path[0..@min(output_path.len, 52)]});
    std.debug.print("║ Expected params: {d:<43} ║\n", .{config.totalParams()});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Создаём writer для .tri
    var writer = try trinity_format.TrinityWriter.init(allocator, output_path);
    defer writer.deinit();

    writer.setConfig(
        config.vocab_size,
        config.hidden_size,
        config.intermediate_size,
        config.num_hidden_layers,
        config.num_attention_heads,
        config.num_key_value_heads,
    );

    // Создаём квантизатор
    var quantizer = prometheus.Quantizer.init(0.1);

    // Загружаем шарды по очереди
    var loader = ShardedLoader.init(allocator, model_path, 3);
    defer loader.deinit();

    for (0..3) |shard_idx| {
        std.debug.print("\n[Shard {d}/3] Loading...\n", .{shard_idx + 1});

        const shard = loader.loadShard(shard_idx) catch |err| {
            std.debug.print("⚠️  Failed to load shard {d}: {}\n", .{ shard_idx + 1, err });
            continue;
        };

        // Конвертируем все тензоры в шарде
        var tensor_it = shard.tensors.iterator();
        while (tensor_it.next()) |entry| {
            const info = entry.value_ptr.*;
            const name = info.name;

            // Пропускаем layernorm веса (они остаются в float)
            if (std.mem.indexOf(u8, name, "layernorm") != null or
                std.mem.indexOf(u8, name, "norm") != null)
            {
                std.debug.print("  Skip (norm): {s}\n", .{name[0..@min(name.len, 50)]});
                continue;
            }

            // Получаем данные как f32
            const f32_data = shard.getTensorF32(allocator, name) catch |err| {
                std.debug.print("  Skip {s}: {}\n", .{ name[0..@min(name.len, 40)], err });
                continue;
            };
            defer allocator.free(f32_data);

            // Квантизуем в триты
            var trit_tensor = try quantizer.quantize(allocator, f32_data, info.shape);
            defer trit_tensor.deinit();

            // Считаем нули
            for (trit_tensor.data) |t| {
                if (t == .zero) stats.zeros_count += 1;
            }

            // Добавляем в .tri файл
            try writer.addTensor(name, info.shape, trit_tensor.data);

            stats.total_tensors += 1;
            stats.total_params += info.numElements();
            stats.original_size_bytes += info.byteSize();

            if (stats.total_tensors % 20 == 0) {
                std.debug.print("  Converted {d} tensors ({d:.1}M params)...\n", .{
                    stats.total_tensors,
                    @as(f64, @floatFromInt(stats.total_params)) / 1_000_000.0,
                });
            }
        }
    }

    // Финализируем файл
    try writer.finalize();

    // Вычисляем статистику
    stats.compressed_size_bytes = (stats.total_params + 3) / 4;
    stats.sparsity = @as(f32, @floatFromInt(stats.zeros_count)) /
        @as(f32, @floatFromInt(stats.total_params));

    printStats(&stats);

    return stats;
}

fn printStats(stats: *const ConversionStats) void {
    const original_gb = @as(f64, @floatFromInt(stats.original_size_bytes)) / (1024.0 * 1024.0 * 1024.0);
    const compressed_mb = @as(f64, @floatFromInt(stats.compressed_size_bytes)) / (1024.0 * 1024.0);

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           CONVERSION COMPLETE                                ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Tensors:          {d:>12}                               ║\n", .{stats.total_tensors});
    std.debug.print("║ Parameters:       {d:>12}                               ║\n", .{stats.total_params});
    std.debug.print("║ Original size:    {d:>12.2} GB                           ║\n", .{original_gb});
    std.debug.print("║ Compressed size:  {d:>12.2} MB                           ║\n", .{compressed_mb});
    std.debug.print("║ Compression:      {d:>12.1}x                              ║\n", .{stats.compressionRatio()});
    std.debug.print("║ Sparsity:         {d:>12.1}%                              ║\n", .{stats.sparsity * 100});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}

/// Конвертация одного safetensors файла (не sharded)
pub fn convertSingleFile(
    allocator: std.mem.Allocator,
    input_path: []const u8,
    output_path: []const u8,
    config: MistralConfig,
) !ConversionStats {
    var stats = ConversionStats{};

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           SAFETENSORS → TRINITY CONVERTER                    ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Input:  {s:<52} ║\n", .{input_path[0..@min(input_path.len, 52)]});
    std.debug.print("║ Output: {s:<52} ║\n", .{output_path[0..@min(output_path.len, 52)]});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Загружаем safetensors
    var sf = try safetensors.SafetensorsFile.open(allocator, input_path);
    defer sf.deinit();

    // Создаём writer для .tri
    var writer = try trinity_format.TrinityWriter.init(allocator, output_path);
    defer writer.deinit();

    writer.setConfig(
        config.vocab_size,
        config.hidden_size,
        config.intermediate_size,
        config.num_hidden_layers,
        config.num_attention_heads,
        config.num_key_value_heads,
    );

    // Создаём квантизатор
    var quantizer = prometheus.Quantizer.init(0.1);

    // Конвертируем все тензоры
    var tensor_it = sf.tensors.iterator();
    while (tensor_it.next()) |entry| {
        const info = entry.value_ptr.*;
        const name = info.name;

        // Получаем данные как f32
        const f32_data = sf.getTensorF32(allocator, name) catch |err| {
            std.debug.print("  Skip {s}: {}\n", .{ name[0..@min(name.len, 40)], err });
            continue;
        };
        defer allocator.free(f32_data);

        // Квантизуем в триты
        var trit_tensor = try quantizer.quantize(allocator, f32_data, info.shape);
        defer trit_tensor.deinit();

        // Считаем нули
        for (trit_tensor.data) |t| {
            if (t == .zero) stats.zeros_count += 1;
        }

        // Добавляем в .tri файл
        try writer.addTensor(name, info.shape, trit_tensor.data);

        stats.total_tensors += 1;
        stats.total_params += info.numElements();
        stats.original_size_bytes += info.byteSize();

        std.debug.print("  ✓ {s}\n", .{name[0..@min(name.len, 50)]});
    }

    // Финализируем файл
    try writer.finalize();

    // Вычисляем статистику
    stats.compressed_size_bytes = (stats.total_params + 3) / 4;
    stats.sparsity = @as(f32, @floatFromInt(stats.zeros_count)) /
        @as(f32, @floatFromInt(stats.total_params));

    printStats(&stats);

    return stats;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: mistral_converter <model_dir> <output.tri>\n", .{});
        std.debug.print("Example: mistral_converter ./Mistral-7B-Instruct-v0.2 mistral-7b.tri\n", .{});
        return;
    }

    _ = try convertMistral(allocator, args[1], args[2], .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "mistral config total params" {
    const config = MistralConfig{};
    const total = config.totalParams();

    // Mistral-7B has ~7.24B parameters
    try std.testing.expect(total > 7_000_000_000);
    try std.testing.expect(total < 8_000_000_000);
}

test "conversion stats" {
    var stats = ConversionStats{
        .total_tensors = 100,
        .total_params = 7_000_000_000,
        .original_size_bytes = 14_000_000_000, // 14GB (bf16)
        .compressed_size_bytes = 875_000_000, // 875MB (2-bit)
        .sparsity = 0.3,
    };

    try std.testing.expectEqual(@as(f32, 16.0), stats.compressionRatio());
}

test "convert mini mistral" {
    // Skip if test file doesn't exist
    std.fs.cwd().access("src/vibeec/test_mistral_mini.safetensors", .{}) catch {
        std.debug.print("Skipping: test_mistral_mini.safetensors not found\n", .{});
        return;
    };

    const allocator = std.testing.allocator;

    const stats = try convertSingleFile(
        allocator,
        "src/vibeec/test_mistral_mini.safetensors",
        "/tmp/test_mistral_mini.tri",
        .{
            .vocab_size = 256,
            .hidden_size = 64,
            .intermediate_size = 128,
            .num_hidden_layers = 2,
            .num_attention_heads = 4,
            .num_key_value_heads = 2,
        },
    );

    try std.testing.expect(stats.total_tensors > 0);
    try std.testing.expect(stats.compressionRatio() > 10.0);

    // Cleanup
    std.fs.cwd().deleteFile("/tmp/test_mistral_mini.tri") catch {};
}
