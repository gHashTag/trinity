// Simple test - just load model and check dimensions
const std = @import("std");
const gguf = @import("src/vibeec/gguf_model.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Loading BitNet model...\n", .{});

    var model = gguf.FullModel.init(allocator, "models/bitnet-2b-fixed.gguf") catch |err| {
        std.debug.print("Failed to init model: {}\n", .{err});
        return err;
    };
    defer model.deinit();

    std.debug.print("Loading weights...\n", .{});
    model.loadWeights() catch |err| {
        std.debug.print("Failed to load weights: {}\n", .{err});
        return err;
    };

    std.debug.print("\n=== Model Config ===\n", .{});
    std.debug.print("hidden_size: {}\n", .{model.config.hidden_size});
    std.debug.print("num_heads: {}\n", .{model.config.num_heads});
    std.debug.print("num_kv_heads: {}\n", .{model.config.num_kv_heads});
    std.debug.print("head_dim: {}\n", .{model.config.head_dim});
    std.debug.print("intermediate_size: {}\n", .{model.config.intermediate_size});
    std.debug.print("ffn_gate_dim: {}\n", .{model.config.ffn_gate_dim});
    std.debug.print("ffn_down_out_dim: {}\n", .{model.config.ffn_down_out_dim});
    std.debug.print("num_layers: {}\n", .{model.config.num_layers});
    std.debug.print("vocab_size: {}\n", .{model.config.vocab_size});

    // Test single token forward pass
    std.debug.print("\n=== Testing forward pass ===\n", .{});
    const test_token: u32 = 1; // BOS token

    const logits = model.forward(test_token, 0) catch |err| {
        std.debug.print("Forward pass failed: {}\n", .{err});
        return err;
    };

    std.debug.print("Forward pass succeeded!\n", .{});
    std.debug.print("Logits length: {}\n", .{logits.len});

    // Print first few logits
    std.debug.print("First 5 logits: ", .{});
    for (logits[0..@min(5, logits.len)]) |l| {
        std.debug.print("{d:.4} ", .{l});
    }
    std.debug.print("\n", .{});

    std.debug.print("\n=== SUCCESS ===\n", .{});
}
