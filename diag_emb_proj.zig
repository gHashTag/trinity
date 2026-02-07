// Diagnostic: Test embedding -> output projection directly (bypass layers)
const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");
const inference = @import("src/vibeec/gguf_inference.zig");
const model_mod = @import("src/vibeec/gguf_model.zig");
const simd = @import("src/vibeec/simd_matmul.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("=== EMBEDDING -> OUTPUT PROJECTION DIAGNOSTIC ===\n\n", .{});

    var model = try model_mod.FullModel.init(allocator, path);
    defer model.deinit();
    try model.loadWeights();

    const hidden_size = model.config.hidden_size;
    const vocab_size = model.config.vocab_size;

    // Test different tokens
    const test_tokens = [_]u32{ 1, 2, 100, 1000, 10000, 25646, 17994 };

    for (test_tokens) |token| {
        // Get embedding
        const emb_offset = @as(usize, token) * hidden_size;
        const embedding = model.token_embedding[emb_offset..][0..hidden_size];

        // Print embedding stats
        var emb_sum: f64 = 0;
        var emb_max: f32 = embedding[0];
        for (embedding) |e| {
            emb_sum += e;
            if (e > emb_max) emb_max = e;
        }

        // Apply RMS norm to embedding
        const normed = try allocator.alloc(f32, hidden_size);
        defer allocator.free(normed);
        inference.rmsNorm(normed, embedding, model.output_norm, model.config.rms_norm_eps);

        // Output projection
        const logits = try allocator.alloc(f32, vocab_size);
        defer allocator.free(logits);
        simd.parallelMatVec(logits, model.output_weight, normed, vocab_size, hidden_size);

        // Find top prediction
        var max_idx: u32 = 0;
        var max_val: f32 = logits[0];
        for (logits[1..], 1..) |l, i| {
            if (l > max_val) {
                max_val = l;
                max_idx = @intCast(i);
            }
        }

        std.debug.print("Token {d}: emb_mean={d:.4}, emb_max={d:.4}, max_logit={d:.4}, top_pred={d}\n",
            .{ token, emb_sum / @as(f64, @floatFromInt(hidden_size)), emb_max, max_val, max_idx });
    }

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
