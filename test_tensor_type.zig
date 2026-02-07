// Check tensor types and raw data
const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== TENSOR TYPE CHECK ===\n\n", .{});

    var reader = try gguf.GGUFReader.init(allocator, "models/bitnet-2b-fixed.gguf");
    defer reader.deinit();

    // Check embedding tensor
    if (reader.getTensor("token_embd.weight")) |info| {
        std.debug.print("token_embd.weight:\n", .{});
        std.debug.print("  type:        {} ({})\n", .{ info.tensor_type, @intFromEnum(info.tensor_type) });
        std.debug.print("  n_dims:      {}\n", .{info.n_dims});
        std.debug.print("  dims:        ", .{});
        for (0..info.n_dims) |i| {
            std.debug.print("{} ", .{info.dims[i]});
        }
        std.debug.print("\n", .{});
        std.debug.print("  elements:    {}\n", .{info.numElements()});
        std.debug.print("  offset:      {}\n", .{info.offset});

        // Read first 64 bytes of raw data
        const data = try reader.readTensorData(info);
        defer allocator.free(data);
        std.debug.print("  raw_bytes:   {}\n", .{data.len});
        std.debug.print("  first 32 bytes: ", .{});
        for (data[0..@min(data.len, 32)]) |b| {
            std.debug.print("{x:0>2} ", .{b});
        }
        std.debug.print("\n", .{});

        // Check if all zeros
        var zero_count: usize = 0;
        for (data[0..@min(data.len, 10000)]) |b| {
            if (b == 0) zero_count += 1;
        }
        std.debug.print("  zeros in first 10000: {}\n", .{zero_count});
    } else {
        std.debug.print("token_embd.weight NOT FOUND\n", .{});
    }

    // Check output weight
    if (reader.getTensor("output.weight")) |info| {
        std.debug.print("\noutput.weight:\n", .{});
        std.debug.print("  type:        {} ({})\n", .{ info.tensor_type, @intFromEnum(info.tensor_type) });
        std.debug.print("  elements:    {}\n", .{info.numElements()});
    }

    // Check a layer weight
    if (reader.getTensor("blk.0.attn_q.weight")) |info| {
        std.debug.print("\nblk.0.attn_q.weight:\n", .{});
        std.debug.print("  type:        {} ({})\n", .{ info.tensor_type, @intFromEnum(info.tensor_type) });
        std.debug.print("  elements:    {}\n", .{info.numElements()});

        const data = try reader.readTensorData(info);
        defer allocator.free(data);
        std.debug.print("  first 32 bytes: ", .{});
        for (data[0..@min(data.len, 32)]) |b| {
            std.debug.print("{x:0>2} ", .{b});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n=== CHECK COMPLETE ===\n\n", .{});
}
