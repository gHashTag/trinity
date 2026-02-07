const std = @import("std");
const gguf_reader = @import("src/vibeec/gguf_reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Loading BitNet model metadata...\n", .{});
    
    var gguf = try gguf_reader.GGUFReader.init(allocator, "models/bitnet-2b-fixed.gguf");
    defer gguf.deinit();

    std.debug.print("\nModel Config:\n", .{});
    
    if (gguf.getMetadataU32("llama.embedding_length")) |v| {
        std.debug.print("  hidden_size: {}\n", .{v});
    }
    if (gguf.getMetadataU32("llama.block_count")) |v| {
        std.debug.print("  num_layers: {}\n", .{v});
    }
    if (gguf.getMetadataU32("llama.attention.head_count")) |v| {
        std.debug.print("  num_heads: {}\n", .{v});
    }
    if (gguf.getMetadataU32("llama.attention.head_count_kv")) |v| {
        std.debug.print("  num_kv_heads: {}\n", .{v});
    }
    if (gguf.getMetadataU32("llama.feed_forward_length")) |v| {
        std.debug.print("  intermediate_size: {}\n", .{v});
    }
    if (gguf.getMetadataU32("llama.rope.dimension_count")) |v| {
        std.debug.print("  rope_dim: {}\n", .{v});
    }
    if (gguf.getMetadataU32("llama.context_length")) |v| {
        std.debug.print("  context_length: {}\n", .{v});
    }
    if (gguf.getMetadataString("general.architecture")) |v| {
        std.debug.print("  architecture: {s}\n", .{v});
    }
    if (gguf.getMetadataString("general.name")) |v| {
        std.debug.print("  name: {s}\n", .{v});
    }
    
    std.debug.print("\nTensor count: {}\n", .{gguf.header.tensor_count});
    
    // Print first few tensor names and shapes
    std.debug.print("\nKey tensors:\n", .{});
    for (gguf.tensors.items) |tensor| {
        // Only show attention/ffn weights
        if (std.mem.indexOf(u8, tensor.name, "attn") != null or
            std.mem.indexOf(u8, tensor.name, "ffn") != null or
            std.mem.indexOf(u8, tensor.name, "embed") != null or
            std.mem.indexOf(u8, tensor.name, "output") != null) 
        {
            if (std.mem.indexOf(u8, tensor.name, "blk.0") != null or
                std.mem.indexOf(u8, tensor.name, "token") != null or
                std.mem.indexOf(u8, tensor.name, "output.weight") != null)
            {
                std.debug.print("  {s}: [{} x {}] type={}\n", .{
                    tensor.name,
                    tensor.dims[0],
                    tensor.dims[1],
                    @intFromEnum(tensor.tensor_type),
                });
            }
        }
    }
    
    // Calculate expected sizes
    std.debug.print("\nDimension analysis:\n", .{});
    const hidden = gguf.getMetadataU32("llama.embedding_length") orelse 0;
    const heads = gguf.getMetadataU32("llama.attention.head_count") orelse 0;
    const kv_heads = gguf.getMetadataU32("llama.attention.head_count_kv") orelse heads;
    const ffn = gguf.getMetadataU32("llama.feed_forward_length") orelse 0;
    
    if (hidden > 0 and heads > 0) {
        const head_dim = hidden / heads;
        std.debug.print("  head_dim = hidden/heads = {}/{} = {}\n", .{hidden, heads, head_dim});
        std.debug.print("  Q/K/V size = heads * head_dim = {} * {} = {}\n", .{heads, head_dim, heads * head_dim});
        std.debug.print("  KV size = kv_heads * head_dim = {} * {} = {}\n", .{kv_heads, head_dim, kv_heads * head_dim});
        std.debug.print("  FFN gate/up = {} x {}\n", .{ffn, hidden});
        std.debug.print("  FFN down = {} x {}\n", .{hidden, ffn});
    }
}
