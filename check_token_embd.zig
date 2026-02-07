const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var reader = try gguf.GGUFReader.init(allocator, "models/bitnet-2b-fixed.gguf");
    defer reader.deinit();

    std.debug.print("Checking token_embd.weight:\n", .{});
    if (reader.getTensor("token_embd.weight")) |t| {
        std.debug.print("  name: {s}\n", .{t.name});
        std.debug.print("  dims: [{} x {}]\n", .{t.dims[0], t.dims[1]});
        std.debug.print("  type: {} (raw enum)\n", .{@intFromEnum(t.tensor_type)});
        std.debug.print("  num_elements: {}\n", .{t.numElements()});
        std.debug.print("  dataSize: {}\n", .{t.dataSize()});
    } else {
        std.debug.print("  NOT FOUND!\n", .{});
    }

    std.debug.print("\nChecking output.weight:\n", .{});
    if (reader.getTensor("output.weight")) |t| {
        std.debug.print("  name: {s}\n", .{t.name});
        std.debug.print("  dims: [{} x {}]\n", .{t.dims[0], t.dims[1]});
        std.debug.print("  type: {} (raw enum)\n", .{@intFromEnum(t.tensor_type)});
    } else {
        std.debug.print("  NOT FOUND!\n", .{});
    }

    std.debug.print("\nFirst 10 tensor names:\n", .{});
    for (reader.tensors.items[0..@min(10, reader.tensors.items.len)]) |t| {
        std.debug.print("  {s}: type={}\n", .{t.name, @intFromEnum(t.tensor_type)});
    }
}
