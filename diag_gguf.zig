// Diagnostic: Check GGUF tensor dimensions
const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const path = if (args.len > 1) args[1] else "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("Loading GGUF: {s}\n\n", .{path});

    var reader = try gguf.GGUFReader.init(allocator, path);
    defer reader.deinit();

    // Print key tensors
    const key_tensors = [_][]const u8{
        "token_embd.weight",
        "output.weight",
        "output_norm.weight",
        "blk.0.attn_q.weight",
        "blk.0.attn_k.weight",
        "blk.0.attn_v.weight",
        "blk.0.attn_output.weight",
        "blk.0.ffn_gate.weight",
        "blk.0.ffn_up.weight",
        "blk.0.ffn_down.weight",
    };

    std.debug.print("TENSOR DIMENSIONS:\n", .{});
    std.debug.print("==================\n", .{});

    for (key_tensors) |name| {
        if (reader.getTensor(name)) |t| {
            std.debug.print("{s}:\n", .{name});
            std.debug.print("  dims: [{d}", .{t.dims[0]});
            if (t.n_dims > 1) std.debug.print(", {d}", .{t.dims[1]});
            if (t.n_dims > 2) std.debug.print(", {d}", .{t.dims[2]});
            std.debug.print("]\n", .{});
            std.debug.print("  type: {}\n", .{t.tensor_type});
            std.debug.print("  elements: {d}\n\n", .{t.numElements()});
        } else {
            std.debug.print("{s}: NOT FOUND\n\n", .{name});
        }
    }

    // Print model config
    std.debug.print("MODEL CONFIG:\n", .{});
    std.debug.print("=============\n", .{});

    if (reader.getMetadataU64("llama.embedding_length")) |v| {
        std.debug.print("  hidden_size: {d}\n", .{v});
    }
    if (reader.getMetadataU64("llama.feed_forward_length")) |v| {
        std.debug.print("  intermediate_size: {d}\n", .{v});
    }
    if (reader.getMetadataU64("llama.attention.head_count")) |v| {
        std.debug.print("  num_heads: {d}\n", .{v});
    }
    if (reader.getMetadataU64("llama.attention.head_count_kv")) |v| {
        std.debug.print("  num_kv_heads: {d}\n", .{v});
    }
    if (reader.metadata.get("tokenizer.ggml.tokens")) |v| {
        if (v == .array) {
            std.debug.print("  vocab_size: {d}\n", .{v.array.len});
        }
    }
}
