const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var reader = try gguf.GGUFReader.init(allocator, "models/bitnet-2b-fixed.gguf");
    defer reader.deinit();

    std.debug.print("BitNet FFN tensors:\n", .{});
    for (reader.tensors.items) |t| {
        if (std.mem.indexOf(u8, t.name, "blk.0.ffn") != null) {
            std.debug.print("  {s}: [{} x {}] type={}\n", .{
                t.name, t.dims[0], t.dims[1], @intFromEnum(t.tensor_type)
            });
        }
    }
    
    std.debug.print("\nConfig from metadata:\n", .{});
    if (reader.getMetadataU32("bitnet.feed_forward_length")) |v| {
        std.debug.print("  intermediate_size: {}\n", .{v});
    }
    if (reader.getMetadataU32("bitnet.embedding_length")) |v| {
        std.debug.print("  hidden_size: {}\n", .{v});
    }
    
    // Infer actual FFN dimensions from tensors
    std.debug.print("\nInferred FFN flow:\n", .{});
    if (reader.getTensor("blk.0.ffn_gate.weight")) |t| {
        std.debug.print("  gate: {} → {}\n", .{t.dims[0], t.dims[1]});
    }
    if (reader.getTensor("blk.0.ffn_up.weight")) |t| {
        std.debug.print("  up:   {} → {}\n", .{t.dims[0], t.dims[1]});
    }
    if (reader.getTensor("blk.0.ffn_down.weight")) |t| {
        std.debug.print("  down: {} → {}\n", .{t.dims[0], t.dims[1]});
    }
}
