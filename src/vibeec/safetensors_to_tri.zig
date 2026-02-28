// SAFETENSORS TO TRINITY CONVERTER
// [CYR:[EN]]in[CYR:[EN]]and[EN] in[EN]with[EN]in and[EN] safetensors in .tri format
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const safetensors = @import("safetensors_parser.zig");
const trinity = @import("trinity_format.zig");
const prometheus = @import("prometheus_seed.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConversionStats = struct {
    total_tensors: usize = 0,
    total_params: usize = 0,
    original_size_bytes: usize = 0,
    compressed_size_bytes: usize = 0,
    sparsity: f32 = 0.0,

    pub fn compressionRatio(self: *const ConversionStats) f32 {
        if (self.compressed_size_bytes == 0) return 0.0;
        return @as(f32, @floatFromInt(self.original_size_bytes)) /
            @as(f32, @floatFromInt(self.compressed_size_bytes));
    }
};

pub const ConverterConfig = struct {
    vocab_size: u32 = 32000,
    hidden_size: u32 = 4096,
    intermediate_size: u32 = 11008,
    num_layers: u32 = 32,
    num_heads: u32 = 32,
    num_kv_heads: u32 = 8,
};

/// [CYR:[EN]]in[CYR:[EN]]and[EN] safetensors in .tri format
pub fn convert(
    allocator: std.mem.Allocator,
    input_path: []const u8,
    output_path: []const u8,
    config: ConverterConfig,
) !ConversionStats {
    var stats = ConversionStats{};

    // 1. [EN]to[EN]in[CYR:[EN]] safetensors
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           SAFETENSORS → TRINITY CONVERTER                    ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Input:  {s:<52} ║\n", .{input_path[0..@min(input_path.len, 52)]});
    std.debug.print("║ Output: {s:<52} ║\n", .{output_path[0..@min(output_path.len, 52)]});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    var sf = try safetensors.SafetensorsFile.open(allocator, input_path);
    defer sf.deinit();

    // 2. [CYR:[EN]]yes[EN] writer for .tri
    var writer = try trinity.TrinityWriter.init(allocator, output_path);
    defer writer.deinit();

    writer.setConfig(
        config.vocab_size,
        config.hidden_size,
        config.intermediate_size,
        config.num_layers,
        config.num_heads,
        config.num_kv_heads,
    );

    // 3. [CYR:[EN]]yes[EN] toin[CYR:[EN]]and[CYR:[EN]]
    var quantizer = prometheus.Quantizer.init(0.1); // threshold = 0.1

    // 4. [CYR:[EN]]in[CYR:[EN]]and[CYR:[EN]] each [CYR:[EN]]
    var tensor_it = sf.tensors.iterator();
    var total_zeros: usize = 0;

    while (tensor_it.next()) |entry| {
        const info = entry.value_ptr.*;
        const name = info.name;

        // Get data how f32
        const f32_data = sf.getTensorF32(allocator, name) catch |err| {
            std.debug.print("⚠️  Skip {s}: {}\n", .{ name, err });
            continue;
        };
        defer allocator.free(f32_data);

        // [EN]in[CYR:[EN]]and[CYR:[EN]] in [EN]and[EN]
        var trit_tensor = try quantizer.quantize(allocator, f32_data, info.shape);
        defer trit_tensor.deinit();

        // [EN]and[CYR:[EN]] [CYR:[EN]]and for sparsity
        for (trit_tensor.data) |t| {
            if (t == .zero) total_zeros += 1;
        }

        // Add in .tri file
        try writer.addTensor(name, info.shape, trit_tensor.data);

        stats.total_tensors += 1;
        stats.total_params += info.numElements();
        stats.original_size_bytes += info.byteSize();

        // [CYR:[EN]]withwith
        if (stats.total_tensors % 10 == 0) {
            std.debug.print("  Converted {d} tensors...\n", .{stats.total_tensors});
        }
    }

    // 5. [EN]andon[EN]and[EN]and[CYR:[EN]] file
    try writer.finalize();

    // 6. Compute with[CYR:[EN]]andwith[EN]andto[EN]
    stats.compressed_size_bytes = (stats.total_params + 3) / 4; // 4 trits per byte
    stats.sparsity = @as(f32, @floatFromInt(total_zeros)) /
        @as(f32, @floatFromInt(stats.total_params));

    // 7. [CYR:[EN]] result
    printStats(&stats);

    return stats;
}

fn printStats(stats: *const ConversionStats) void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           CONVERSION COMPLETE                                ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Tensors:          {d:>12}                               ║\n", .{stats.total_tensors});
    std.debug.print("║ Parameters:       {d:>12}                               ║\n", .{stats.total_params});
    std.debug.print("║ Original size:    {d:>12} bytes                         ║\n", .{stats.original_size_bytes});
    std.debug.print("║ Compressed size:  {d:>12} bytes                         ║\n", .{stats.compressed_size_bytes});
    std.debug.print("║ Compression:      {d:>12.1}x                              ║\n", .{stats.compressionRatio()});
    std.debug.print("║ Sparsity:         {d:>12.1}%                              ║\n", .{stats.sparsity * 100});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: safetensors_to_tri <input.safetensors> <output.tri>\n", .{});
        return;
    }

    const input_path = args[1];
    const output_path = args[2];

    _ = try convert(allocator, input_path, output_path, .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "conversion stats" {
    var stats = ConversionStats{
        .total_tensors = 10,
        .total_params = 1000000,
        .original_size_bytes = 4000000, // 4MB (f32)
        .compressed_size_bytes = 250000, // 250KB (2 bits per trit)
        .sparsity = 0.5,
    };

    try std.testing.expectEqual(@as(f32, 16.0), stats.compressionRatio());
}

test "converter config defaults" {
    const config = ConverterConfig{};
    try std.testing.expectEqual(@as(u32, 32000), config.vocab_size);
    try std.testing.expectEqual(@as(u32, 4096), config.hidden_size);
}
