// Diagnostic: Check tensor dimensions to verify matrix layout
const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("=== TENSOR DIMENSION DIAGNOSTIC ===\n\n", .{});

    var reader = try gguf.GGUFReader.init(allocator, path);
    defer reader.deinit();

    // Key weight tensors to check
    const tensor_names = [_][]const u8{
        "token_embd.weight",
        "blk.0.attn_q.weight",
        "blk.0.attn_k.weight",
        "blk.0.attn_v.weight",
        "blk.0.attn_output.weight",
        "blk.0.ffn_gate.weight",
        "blk.0.ffn_up.weight",
        "blk.0.ffn_down.weight",
        "output.weight",
        "output_norm.weight",
    };

    for (tensor_names) |name| {
        if (reader.getTensor(name)) |tensor| {
            std.debug.print("{s}:\n", .{name});
            std.debug.print("  dims: [", .{});
            for (0..tensor.n_dims) |d| {
                if (d > 0) std.debug.print(", ", .{});
                std.debug.print("{d}", .{tensor.dims[d]});
            }
            std.debug.print("]\n", .{});
            std.debug.print("  type: {}\n", .{tensor.tensor_type});
            std.debug.print("  elements: {d}\n\n", .{tensor.numElements()});
        } else {
            std.debug.print("{s}: NOT FOUND\n\n", .{name});
        }
    }

    // Model config
    const arch = reader.getMetadataString("general.architecture") orelse "llama";
    std.debug.print("Architecture: {s}\n\n", .{arch});

    var key_buf: [64]u8 = undefined;
    const hidden_size = reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.embedding_length", .{arch}) catch "") orelse 0;
    const num_heads = reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.attention.head_count", .{arch}) catch "") orelse 0;
    const num_kv_heads = reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.attention.head_count_kv", .{arch}) catch "") orelse 0;
    const intermediate_size = reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.feed_forward_length", .{arch}) catch "") orelse 0;

    std.debug.print("Config:\n", .{});
    std.debug.print("  hidden_size: {d}\n", .{hidden_size});
    std.debug.print("  num_heads: {d}\n", .{num_heads});
    std.debug.print("  num_kv_heads: {d}\n", .{num_kv_heads});
    std.debug.print("  intermediate_size: {d}\n", .{intermediate_size});
    std.debug.print("  head_dim (inferred): {d}\n", .{hidden_size / num_heads});
    std.debug.print("  q_dim (num_heads * head_dim): {d}\n", .{num_heads * (hidden_size / num_heads)});
    std.debug.print("  kv_dim (num_kv_heads * head_dim): {d}\n", .{num_kv_heads * (hidden_size / num_heads)});

    std.debug.print("\n=== LAYOUT ANALYSIS ===\n\n", .{});

    // For attn_k.weight:
    // - Conceptual shape: [kv_dim, hidden_size] where kv_dim = num_kv_heads * head_dim
    // - For TinyLlama: kv_dim = 4 * 64 = 256, hidden_size = 2048
    // - So weight should be [256, 2048] conceptually
    // - In GGUF column-major: if dims = [256, 2048], then innermost is 256
    // - This means we read: for each input j, get all kv_dim outputs

    if (reader.getTensor("blk.0.attn_k.weight")) |k_tensor| {
        std.debug.print("attn_k.weight analysis:\n", .{});
        std.debug.print("  GGUF dims: [{d}, {d}]\n", .{ k_tensor.dims[0], k_tensor.dims[1] });

        const expected_kv_dim = num_kv_heads * (hidden_size / num_heads);
        const expected_hidden = hidden_size;

        if (k_tensor.dims[0] == expected_kv_dim and k_tensor.dims[1] == expected_hidden) {
            std.debug.print("  Layout: [kv_dim, hidden_size] - dims[0] is output, dims[1] is input\n", .{});
            std.debug.print("  This means: W[out][in] = data[in * kv_dim + out]\n", .{});
            std.debug.print("  Column-major: each column (input) stores all outputs contiguously\n", .{});
        } else if (k_tensor.dims[0] == expected_hidden and k_tensor.dims[1] == expected_kv_dim) {
            std.debug.print("  Layout: [hidden_size, kv_dim] - dims[0] is input, dims[1] is output\n", .{});
            std.debug.print("  This means: W[out][in] = data[out * hidden + in]\n", .{});
            std.debug.print("  ⚠️ This is TRANSPOSED from expected!\n", .{});
        } else {
            std.debug.print("  ⚠️ Unexpected dimensions!\n", .{});
        }
    }

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
