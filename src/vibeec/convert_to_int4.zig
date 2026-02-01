// TRINITY INT4 CONVERTER
// Converts .tri (BF16) to .tri.int4 (INT4 quantized)

const std = @import("std");
const quantizer = @import("trinity_quantizer.zig");
const trinity_format = @import("trinity_format.zig");

pub const Int4Header = extern struct {
    magic: u32 = quantizer.INT4_MAGIC,
    version: u32 = 1,
    num_tensors: u32 = 0,
    vocab_size: u32 = 0,
    hidden_size: u32 = 0,
    intermediate_size: u32 = 0,
    num_layers: u32 = 0,
    num_heads: u32 = 0,
    num_kv_heads: u32 = 0,
    total_params: u64 = 0,
    quantized_size: u64 = 0,
    block_size: u32 = quantizer.BLOCK_SIZE,
    reserved: [4]u8 = [_]u8{0} ** 4,
};

pub fn convert(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8) !void {
    std.debug.print("\n", .{});
    std.debug.print("INT4 CONVERTER - TRINITY DEMIURGE\n", .{});
    std.debug.print("Input:  {s}\n", .{input_path});
    std.debug.print("Output: {s}\n", .{output_path});

    // Open input .tri file
    var reader = try trinity_format.TrinityReader.init(allocator, input_path);
    defer reader.deinit();

    // Create output file
    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();

    // Write header (will update later)
    var header = Int4Header{
        .vocab_size = reader.header.vocab_size,
        .hidden_size = reader.header.hidden_size,
        .intermediate_size = reader.header.intermediate_size,
        .num_layers = reader.header.num_layers,
        .num_heads = reader.header.num_heads,
        .num_kv_heads = reader.header.num_kv_heads,
        .total_params = reader.header.total_params,
    };

    try out_file.writeAll(std.mem.asBytes(&header));

    var total_quantized: u64 = 0;
    var tensor_count: u32 = 0;

    // Process each tensor
    const tensors = reader.listTensors();
    for (tensors) |entry| {
        const name = entry.name;

        // Get tensor data as f32
        const f32_data = reader.getTensor(name) catch |err| {
            std.debug.print("  Skip {s}: {}\n", .{ name, err });
            continue;
        };
        defer allocator.free(f32_data);

        // Quantize
        var quant = try quantizer.quantizeTensor(allocator, f32_data);
        defer quantizer.deinitPacked(allocator, &quant);

        // Write tensor name length and name
        try out_file.writer().writeInt(u32, @intCast(name.len), .little);
        try out_file.writeAll(name);

        // Write num_elements
        try out_file.writer().writeInt(u64, @intCast(quant.num), .little);

        // Write scales
        try out_file.writer().writeInt(u32, @intCast(quant.scales.len), .little);
        try out_file.writeAll(std.mem.sliceAsBytes(quant.scales));

        // Write packed data
        try out_file.writer().writeInt(u32, @intCast(quant.data.len), .little);
        try out_file.writeAll(quant.data);

        total_quantized += quant.size();
        tensor_count += 1;

        if (tensor_count % 50 == 0) {
            std.debug.print("  Processed {d} tensors...\n", .{tensor_count});
        }
    }

    // Update header
    header.num_tensors = tensor_count;
    header.quantized_size = total_quantized;

    try out_file.seekTo(0);
    try out_file.writeAll(std.mem.asBytes(&header));

    const orig_size = reader.header.total_params * 2; // BF16 = 2 bytes
    const ratio = @as(f64, @floatFromInt(orig_size)) / @as(f64, @floatFromInt(total_quantized));

    std.debug.print("\n", .{});
    std.debug.print("CONVERSION COMPLETE\n", .{});
    std.debug.print("  Tensors:     {d}\n", .{tensor_count});
    std.debug.print("  Original:    {d:.2} GB\n", .{@as(f64, @floatFromInt(orig_size)) / 1e9});
    std.debug.print("  Quantized:   {d:.2} GB\n", .{@as(f64, @floatFromInt(total_quantized)) / 1e9});
    std.debug.print("  Compression: {d:.2}x\n", .{ratio});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: convert_to_int4 <input.tri> [output.tri.int4]\n", .{});
        return;
    }

    const input = args[1];
    const output = if (args.len > 2) args[2] else blk: {
        var buf: [256]u8 = undefined;
        const len = @min(input.len, 250);
        @memcpy(buf[0..len], input[0..len]);
        @memcpy(buf[len..][0..5], ".int4");
        break :blk buf[0 .. len + 5];
    };

    try convert(allocator, input, output);
}

test "header_size" {
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(Int4Header));
}
