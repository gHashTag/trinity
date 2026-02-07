const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var reader = try gguf.GGUFReader.init(allocator, "models/bitnet-2b-fixed.gguf");
    defer reader.deinit();

    std.debug.print("All FFN tensors for blk.0:\n", .{});
    for (reader.tensors.items) |t| {
        if (std.mem.indexOf(u8, t.name, "blk.0.ffn") != null or
            std.mem.indexOf(u8, t.name, "blk.0.attn") != null) {
            const total = t.dims[0] * @max(t.dims[1], 1);
            std.debug.print("  {s}: [{} x {}] = {} elements, type={}\n", .{
                t.name, t.dims[0], t.dims[1], total, @intFromEnum(t.tensor_type)
            });
        }
    }
    
    // Check gate weight total size
    if (reader.getTensor("blk.0.ffn_gate.weight")) |t| {
        std.debug.print("\nFFN gate weight size: {} bytes, {} elements\n", .{
            t.dataSize(), t.numElements()
        });
    }
    if (reader.getTensor("blk.0.ffn_up.weight")) |t| {
        std.debug.print("FFN up weight size: {} bytes, {} elements\n", .{
            t.dataSize(), t.numElements()
        });
    }
    if (reader.getTensor("blk.0.ffn_down.weight")) |t| {
        std.debug.print("FFN down weight size: {} bytes, {} elements\n", .{
            t.dataSize(), t.numElements()
        });
    }
}
