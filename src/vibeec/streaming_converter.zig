// STREAMING CONVERTER - Low-memory conversion for large models
// Обрабатывает тензоры по одному, не загружая всю модель в память
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const trinity_format = @import("trinity_format.zig");
const prometheus = @import("prometheus_seed.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// STREAMING SAFETENSORS READER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TensorMeta = struct {
    name: []const u8,
    dtype: []const u8,
    shape: []usize,
    data_start: usize,
    data_end: usize,

    pub fn numElements(self: *const TensorMeta) usize {
        var total: usize = 1;
        for (self.shape) |dim| {
            total *= dim;
        }
        return total;
    }

    pub fn byteSize(self: *const TensorMeta) usize {
        return self.data_end - self.data_start;
    }
};

/// Streaming reader - reads tensors one at a time
pub const StreamingSafetensors = struct {
    allocator: std.mem.Allocator,
    file: std.fs.File,
    header_size: usize,
    tensors: std.ArrayList(TensorMeta),

    pub fn open(allocator: std.mem.Allocator, path: []const u8) !StreamingSafetensors {
        const file = try std.fs.cwd().openFile(path, .{});
        errdefer file.close();

        // Read header size
        var header_size_bytes: [8]u8 = undefined;
        _ = try file.readAll(&header_size_bytes);
        const header_size = std.mem.readInt(u64, &header_size_bytes, .little);

        // Read header JSON
        const header_json = try allocator.alloc(u8, header_size);
        defer allocator.free(header_json);
        _ = try file.readAll(header_json);

        // Parse header (simplified - just extract tensor info)
        var tensors = std.ArrayList(TensorMeta).init(allocator);

        // Simple JSON parsing for tensor metadata
        var i: usize = 0;
        while (i < header_json.len) {
            // Find tensor name
            if (std.mem.indexOf(u8, header_json[i..], "\"")) |start| {
                const name_start = i + start + 1;
                if (std.mem.indexOf(u8, header_json[name_start..], "\"")) |end| {
                    const name = header_json[name_start..][0..end];

                    // Skip metadata entries
                    if (std.mem.eql(u8, name, "__metadata__")) {
                        i = name_start + end + 1;
                        continue;
                    }

                    // Find data_offsets
                    if (std.mem.indexOf(u8, header_json[name_start + end ..], "data_offsets")) |_| {
                        // Extract offsets (simplified)
                        if (std.mem.indexOf(u8, header_json[name_start + end ..], "[")) |arr_start| {
                            const offset_str_start = name_start + end + arr_start + 1;
                            if (std.mem.indexOf(u8, header_json[offset_str_start..], ",")) |comma| {
                                const start_str = header_json[offset_str_start..][0..comma];
                                if (std.mem.indexOf(u8, header_json[offset_str_start + comma + 1 ..], "]")) |end_bracket| {
                                    const end_str = std.mem.trim(u8, header_json[offset_str_start + comma + 1 ..][0..end_bracket], " ");

                                    const data_start = std.fmt.parseInt(usize, start_str, 10) catch 0;
                                    const data_end = std.fmt.parseInt(usize, end_str, 10) catch 0;

                                    if (data_end > data_start) {
                                        const shape = try allocator.alloc(usize, 1);
                                        shape[0] = (data_end - data_start) / 2; // bfloat16
                                        const meta = TensorMeta{
                                            .name = try allocator.dupe(u8, name),
                                            .dtype = "BF16",
                                            .shape = shape,
                                            .data_start = data_start,
                                            .data_end = data_end,
                                        };
                                        try tensors.append(meta);
                                    }
                                }
                            }
                        }
                    }

                    i = name_start + end + 1;
                } else {
                    i += 1;
                }
            } else {
                break;
            }
        }

        return StreamingSafetensors{
            .allocator = allocator,
            .file = file,
            .header_size = @intCast(header_size + 8),
            .tensors = tensors,
        };
    }

    pub fn deinit(self: *StreamingSafetensors) void {
        for (self.tensors.items) |meta| {
            self.allocator.free(meta.name);
            self.allocator.free(meta.shape);
        }
        self.tensors.deinit();
        self.file.close();
    }

    /// Read a single tensor's data as f32
    pub fn readTensorF32(self: *StreamingSafetensors, meta: *const TensorMeta) ![]f32 {
        const byte_size = meta.byteSize();
        const num_elements = byte_size / 2; // bfloat16 = 2 bytes

        // Seek to tensor data
        try self.file.seekTo(self.header_size + meta.data_start);

        // Read raw bytes
        const raw_bytes = try self.allocator.alloc(u8, byte_size);
        defer self.allocator.free(raw_bytes);
        _ = try self.file.readAll(raw_bytes);

        // Convert bfloat16 to f32
        const result = try self.allocator.alloc(f32, num_elements);
        var i: usize = 0;
        while (i < num_elements) : (i += 1) {
            // bfloat16: just the upper 16 bits of f32
            const bf16_bits: u16 = std.mem.readInt(u16, raw_bytes[i * 2 ..][0..2], .little);
            const f32_bits: u32 = @as(u32, bf16_bits) << 16;
            result[i] = @bitCast(f32_bits);
        }

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STREAMING CONVERTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConversionStats = struct {
    total_tensors: usize = 0,
    total_params: u64 = 0,
    original_size_bytes: u64 = 0,
    zeros_count: u64 = 0,
};

/// Convert a single shard file to .tri format (streaming)
pub fn convertShardStreaming(
    allocator: std.mem.Allocator,
    shard_path: []const u8,
    writer: *trinity_format.TrinityWriter,
    stats: *ConversionStats,
) !void {
    std.debug.print("  Loading: {s}\n", .{shard_path[0..@min(shard_path.len, 50)]});

    var reader = try StreamingSafetensors.open(allocator, shard_path);
    defer reader.deinit();

    std.debug.print("  Found {d} tensors\n", .{reader.tensors.items.len});

    var quantizer = prometheus.Quantizer.init(0.1);

    for (reader.tensors.items) |*meta| {
        const name = meta.name;

        // Skip layernorm weights
        if (std.mem.indexOf(u8, name, "layernorm") != null or
            std.mem.indexOf(u8, name, "norm") != null)
        {
            continue;
        }

        // Skip bias (small, keep in float)
        if (std.mem.indexOf(u8, name, "bias") != null) {
            continue;
        }

        // Read tensor data
        const f32_data = reader.readTensorF32(meta) catch |err| {
            std.debug.print("    Skip {s}: {}\n", .{ name[0..@min(name.len, 30)], err });
            continue;
        };
        defer allocator.free(f32_data);

        // Quantize to trits
        const shape = [_]usize{f32_data.len};
        var trit_tensor = try quantizer.quantize(allocator, f32_data, &shape);
        defer trit_tensor.deinit();

        // Count zeros
        for (trit_tensor.data) |t| {
            if (t == .zero) stats.zeros_count += 1;
        }

        // Add to .tri file
        try writer.addTensor(name, &shape, trit_tensor.data);

        stats.total_tensors += 1;
        stats.total_params += f32_data.len;
        stats.original_size_bytes += meta.byteSize();

        if (stats.total_tensors % 10 == 0) {
            std.debug.print("    Converted {d} tensors ({d:.1}M params)\n", .{
                stats.total_tensors,
                @as(f64, @floatFromInt(stats.total_params)) / 1_000_000.0,
            });
        }
    }
}

/// Convert multiple shards to single .tri file
pub fn convertModel(
    allocator: std.mem.Allocator,
    model_dir: []const u8,
    output_path: []const u8,
    num_shards: usize,
) !ConversionStats {
    var stats = ConversionStats{};

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           STREAMING TRINITY CONVERTER                        ║\n", .{});
    std.debug.print("║           Low-memory conversion for large models             ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Model: {s:<53} ║\n", .{model_dir[0..@min(model_dir.len, 53)]});
    std.debug.print("║ Output: {s:<52} ║\n", .{output_path[0..@min(output_path.len, 52)]});
    std.debug.print("║ Shards: {d:<52} ║\n", .{num_shards});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Create writer
    var writer = try trinity_format.TrinityWriter.init(allocator, output_path);
    defer writer.deinit();

    // Qwen2.5-Coder-7B config
    writer.setConfig(152064, 3584, 18944, 28, 28, 4);

    // Process each shard
    for (0..num_shards) |shard_idx| {
        var path_buf: [512]u8 = undefined;
        const shard_path = try std.fmt.bufPrint(&path_buf, "{s}/model-{d:0>5}-of-{d:0>5}.safetensors", .{
            model_dir,
            shard_idx + 1,
            num_shards,
        });

        std.debug.print("\n[Shard {d}/{d}]\n", .{ shard_idx + 1, num_shards });

        convertShardStreaming(allocator, shard_path, &writer, &stats) catch |err| {
            std.debug.print("  ⚠️  Error: {}\n", .{err});
            continue;
        };
    }

    // Finalize
    try writer.finalize();

    // Print stats
    const original_gb = @as(f64, @floatFromInt(stats.original_size_bytes)) / (1024.0 * 1024.0 * 1024.0);
    const compressed_mb = @as(f64, @floatFromInt(stats.total_params / 4)) / (1024.0 * 1024.0);
    const sparsity = @as(f64, @floatFromInt(stats.zeros_count)) / @as(f64, @floatFromInt(stats.total_params)) * 100.0;

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           CONVERSION COMPLETE                                ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Tensors:          {d:>12}                               ║\n", .{stats.total_tensors});
    std.debug.print("║ Parameters:       {d:>12}                               ║\n", .{stats.total_params});
    std.debug.print("║ Original size:    {d:>12.2} GB                           ║\n", .{original_gb});
    std.debug.print("║ Compressed size:  {d:>12.2} MB                           ║\n", .{compressed_mb});
    std.debug.print("║ Compression:      {d:>12.1}x                              ║\n", .{original_gb * 1024.0 / compressed_mb});
    std.debug.print("║ Sparsity:         {d:>12.1}%                              ║\n", .{sparsity});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    return stats;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: streaming_converter <model_dir> <output.tri> [num_shards]\n", .{});
        std.debug.print("Example: streaming_converter ./qwen-coder-7b qwen-coder-7b.tri 4\n", .{});
        return;
    }

    const model_dir = args[1];
    const output_path = args[2];
    const num_shards: usize = if (args.len > 3) std.fmt.parseInt(usize, args[3], 10) catch 4 else 4;

    _ = try convertModel(allocator, model_dir, output_path, num_shards);
}

test "streaming converter" {
    // Skip if model not present
    std.fs.cwd().access("models/qwen-coder-7b/model-00001-of-00004.safetensors", .{}) catch {
        std.debug.print("Skipping: model not found\n", .{});
        return;
    };

    const allocator = std.testing.allocator;
    _ = try convertModel(allocator, "models/qwen-coder-7b", "/tmp/test_qwen.tri", 4);
}
