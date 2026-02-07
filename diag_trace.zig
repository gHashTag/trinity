// Diagnostic: Trace through attention to find the bug
const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");
const inference = @import("src/vibeec/gguf_inference.zig");
const simd = @import("src/vibeec/simd_matmul.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("=== ATTENTION TRACE DIAGNOSTIC ===\n\n", .{});

    var model = try model_mod.FullModel.init(allocator, path);
    defer model.deinit();
    try model.loadWeights();

    const hidden_size = model.config.hidden_size;
    const num_heads = model.config.num_heads;
    const num_kv_heads = model.config.num_kv_heads;
    const head_dim = model.config.head_dim;

    std.debug.print("Config: hidden={d}, heads={d}, kv_heads={d}, head_dim={d}\n\n", .{
        hidden_size, num_heads, num_kv_heads, head_dim
    });

    model.resetKVCache();

    // Test with 3 tokens
    const tokens = [_]u32{ 1, 450, 338 }; // BOS, "The", "is"

    for (tokens, 0..) |token, pos| {
        std.debug.print("=== Processing token {d} at pos {d} ===\n", .{ token, pos });

        // Get embedding
        const emb_offset = @as(usize, token) * hidden_size;
        const embedding = model.token_embedding[emb_offset..][0..hidden_size];

        // Check embedding stats
        var emb_sum: f64 = 0;
        for (embedding) |e| emb_sum += e;
        std.debug.print("  Embedding mean: {d:.6}\n", .{emb_sum / @as(f64, @floatFromInt(hidden_size))});

        // Check first layer Q/K projection input (after attn_norm)
        const layer = model.layers[0];
        const normed = try allocator.alloc(f32, hidden_size);
        defer allocator.free(normed);
        inference.rmsNorm(normed, embedding, layer.attn_norm, model.config.rms_norm_eps);

        var normed_sum: f64 = 0;
        for (normed) |n| normed_sum += n;
        std.debug.print("  Normed mean: {d:.6}\n", .{normed_sum / @as(f64, @floatFromInt(hidden_size))});

        // Compute Q
        var q = try allocator.alloc(f32, num_heads * head_dim);
        defer allocator.free(q);
        simd.simdMatVec(q, layer.wq, normed, num_heads * head_dim, hidden_size);

        var q_sum: f64 = 0;
        for (q) |v| q_sum += v;
        std.debug.print("  Q mean (pre-RoPE): {d:.6}\n", .{q_sum / @as(f64, @floatFromInt(num_heads * head_dim))});

        // Apply RoPE to first head's Q
        var q_head0: [64]f32 = undefined;
        @memcpy(&q_head0, q[0..head_dim]);
        model.rope.apply(&q_head0, pos);

        var q_rope_sum: f64 = 0;
        for (q_head0) |v| q_rope_sum += v;
        std.debug.print("  Q[0] mean (post-RoPE): {d:.6}\n", .{q_rope_sum / 64.0});

        // Compute K
        var k = try allocator.alloc(f32, num_kv_heads * head_dim);
        defer allocator.free(k);
        simd.simdMatVec(k, layer.wk, normed, num_kv_heads * head_dim, hidden_size);

        var k_sum: f64 = 0;
        for (k) |v| k_sum += v;
        std.debug.print("  K mean (pre-RoPE): {d:.6}\n", .{k_sum / @as(f64, @floatFromInt(num_kv_heads * head_dim))});

        // Apply RoPE to K
        for (0..num_kv_heads) |h| {
            model.rope.apply(k[h * head_dim ..][0..head_dim], pos);
        }

        var k_rope_sum: f64 = 0;
        for (k) |v| k_rope_sum += v;
        std.debug.print("  K mean (post-RoPE): {d:.6}\n", .{k_rope_sum / @as(f64, @floatFromInt(num_kv_heads * head_dim))});

        // Now run full forward and check logits
        const logits = try model.forward(token, pos);
        defer allocator.free(logits);

        // Find top prediction
        var max_idx: u32 = 0;
        var max_val: f32 = logits[0];
        for (logits[1..], 1..) |l, i| {
            if (l > max_val) {
                max_val = l;
                max_idx = @intCast(i);
            }
        }

        // Check KV cache seq_len for layer 0
        std.debug.print("  KV cache seq_len (layer 0): {d}\n", .{model.kv_caches[0].seq_len});
        std.debug.print("  Top prediction: token {d} with logit {d:.4}\n\n", .{ max_idx, max_val });
    }

    // Now check if attention scores make sense
    std.debug.print("=== ATTENTION SCORE ANALYSIS ===\n", .{});
    std.debug.print("After 3 tokens, checking attention for layer 0, head 0:\n\n", .{});

    // Get Q for a new query (use arbitrary token)
    const query_token: u32 = 263; // "a"
    const emb_offset = @as(usize, query_token) * hidden_size;
    const hidden = try allocator.alloc(f32, hidden_size);
    defer allocator.free(hidden);
    @memcpy(hidden, model.token_embedding[emb_offset..][0..hidden_size]);

    // Normalize
    const normed2 = try allocator.alloc(f32, hidden_size);
    defer allocator.free(normed2);
    inference.rmsNorm(normed2, hidden, model.layers[0].attn_norm, model.config.rms_norm_eps);

    // Q projection
    var q = try allocator.alloc(f32, num_heads * head_dim);
    defer allocator.free(q);
    simd.simdMatVec(q, model.layers[0].wq, normed2, num_heads * head_dim, hidden_size);

    // Apply RoPE at position 3
    for (0..num_heads) |h| {
        model.rope.apply(q[h * head_dim ..][0..head_dim], 3);
    }

    const q_head0 = q[0..head_dim];

    // Compute attention scores for head 0, kv_head 0
    std.debug.print("Attention scores from pos 3 to cached positions:\n", .{});
    const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));
    const seq_len = model.kv_caches[0].seq_len;

    for (0..seq_len) |t| {
        const k_offset = t * num_kv_heads * head_dim; // kv_head 0
        const k_vec = model.kv_caches[0].k_cache[k_offset..][0..head_dim];

        var dot: f32 = 0.0;
        for (0..head_dim) |i| {
            dot += q_head0[i] * k_vec[i];
        }
        const score = dot * scale;
        std.debug.print("  Score to pos {d}: {d:.4}\n", .{ t, score });
    }

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
