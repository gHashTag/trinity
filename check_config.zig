const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var reader = try gguf.GGUFReader.init(allocator, "models/bitnet-2b-fixed.gguf");
    defer reader.deinit();

    const arch = reader.getMetadataString("general.architecture") orelse "llama";
    std.debug.print("Architecture: {s}\n", .{arch});
    
    // Check both bitnet.* and llama.* prefixed keys
    const prefixes = [_][]const u8{ "bitnet", "llama" };
    
    for (prefixes) |prefix| {
        std.debug.print("\nChecking {s}.* keys:\n", .{prefix});
        
        var key_buf: [64]u8 = undefined;
        
        if (reader.getMetadataU32(std.fmt.bufPrint(&key_buf, "{s}.embedding_length", .{prefix}) catch "")) |v| {
            std.debug.print("  embedding_length: {}\n", .{v});
        }
        if (reader.getMetadataU32(std.fmt.bufPrint(&key_buf, "{s}.block_count", .{prefix}) catch "")) |v| {
            std.debug.print("  block_count: {}\n", .{v});
        }
        if (reader.getMetadataU32(std.fmt.bufPrint(&key_buf, "{s}.attention.head_count", .{prefix}) catch "")) |v| {
            std.debug.print("  attention.head_count: {}\n", .{v});
        }
        if (reader.getMetadataU32(std.fmt.bufPrint(&key_buf, "{s}.attention.head_count_kv", .{prefix}) catch "")) |v| {
            std.debug.print("  attention.head_count_kv: {}\n", .{v});
        }
        if (reader.getMetadataU32(std.fmt.bufPrint(&key_buf, "{s}.feed_forward_length", .{prefix}) catch "")) |v| {
            std.debug.print("  feed_forward_length: {}\n", .{v});
        }
    }
    
    // Get tensor dims to infer
    std.debug.print("\nInferred from tensors:\n", .{});
    for (reader.tensors.items) |t| {
        if (std.mem.eql(u8, t.name, "blk.0.attn_q.weight")) {
            std.debug.print("  attn_q: {} x {}\n", .{t.dims[0], t.dims[1]});
        }
        if (std.mem.eql(u8, t.name, "blk.0.attn_k.weight")) {
            std.debug.print("  attn_k: {} x {}\n", .{t.dims[0], t.dims[1]});
        }
        if (std.mem.eql(u8, t.name, "token_embd.weight")) {
            std.debug.print("  embeddings: {} x {}\n", .{t.dims[0], t.dims[1]});
        }
    }
}
