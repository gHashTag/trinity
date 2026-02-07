// Diagnostic: Trace layer 2 step by step to find the explosion source
const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");
const inference = @import("src/vibeec/gguf_inference.zig");
const simd = @import("src/vibeec/simd_matmul.zig");

fn printStats(name: []const u8, data: []const f32) void {
    var sum: f64 = 0;
    var sum_sq: f64 = 0;
    var min: f32 = data[0];
    var max: f32 = data[0];

    for (data) |v| {
        sum += v;
        sum_sq += @as(f64, v) * @as(f64, v);
        if (v < min) min = v;
        if (v > max) max = v;
    }

    const n: f64 = @floatFromInt(data.len);
    const mean = sum / n;
    const l2 = @sqrt(sum_sq);

    std.debug.print("{s}: mean={d:.4}, min={d:.3}, max={d:.3}, L2={d:.2}\n", .{
        name, mean, min, max, l2
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("=== LAYER 2 STEP-BY-STEP TRACE ===\n\n", .{});

    var model = try model_mod.FullModel.init(allocator, path);
    defer model.deinit();
    try model.loadWeights();

    const hidden_size = model.config.hidden_size;
    const num_heads = model.config.num_heads;
    const num_kv_heads = model.config.num_kv_heads;
    const head_dim = model.config.head_dim;
    const intermediate_size = model.config.intermediate_size;
    const rms_eps = model.config.rms_norm_eps;

    model.resetKVCache();

    // Process through layers 0 and 1 first
    const token: u32 = 1;
    const emb_offset = @as(usize, token) * hidden_size;
    @memcpy(model.buf_hidden, model.token_embedding[emb_offset..][0..hidden_size]);

    model.forwardLayerOptimized(model.buf_temp, model.buf_hidden, 0, 0);
    @memcpy(model.buf_hidden, model.buf_temp);
    model.forwardLayerOptimized(model.buf_temp, model.buf_hidden, 1, 0);
    @memcpy(model.buf_hidden, model.buf_temp);

    std.debug.print("Input to layer 2:\n", .{});
    printStats("hidden", model.buf_hidden);

    // Now trace layer 2 step by step
    const layer = model.layers[2];
    const layer_idx: usize = 2;
    const pos: usize = 0;

    std.debug.print("\n=== LAYER 2 ATTENTION ===\n", .{});

    // Pre-attention norm
    inference.rmsNorm(model.buf_normed, model.buf_hidden, layer.attn_norm, rms_eps);
    printStats("After attn_norm", model.buf_normed);

    // Q projection
    simd.simdMatVec(model.buf_q, layer.wq, model.buf_normed, num_heads * head_dim, hidden_size);
    printStats("After Q projection", model.buf_q);

    // K projection
    simd.simdMatVec(model.buf_k, layer.wk, model.buf_normed, num_kv_heads * head_dim, hidden_size);
    printStats("After K projection", model.buf_k);

    // V projection
    simd.simdMatVec(model.buf_v, layer.wv, model.buf_normed, num_kv_heads * head_dim, hidden_size);
    printStats("After V projection", model.buf_v);

    // Apply RoPE
    for (0..num_heads) |h| {
        model.rope.apply(model.buf_q[h * head_dim ..][0..head_dim], pos);
    }
    for (0..num_kv_heads) |h| {
        model.rope.apply(model.buf_k[h * head_dim ..][0..head_dim], pos);
    }
    printStats("Q after RoPE", model.buf_q);
    printStats("K after RoPE", model.buf_k);

    // Update KV cache
    model.kv_caches[layer_idx].append(model.buf_k, model.buf_v);

    // Compute attention
    const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));
    const kv_group_size = num_heads / num_kv_heads;
    const seq_len = model.kv_caches[layer_idx].seq_len;

    std.debug.print("\nseq_len={d}, scale={d:.4}\n", .{ seq_len, scale });

    // Just check attention for head 0
    const kv_h: usize = 0;
    const q_head = model.buf_q[0..head_dim];
    const k_offset = 0 * num_kv_heads * head_dim + kv_h * head_dim;
    const k_vec = model.kv_caches[layer_idx].k_cache[k_offset..][0..head_dim];

    var dot: f32 = 0.0;
    for (0..head_dim) |i| {
        dot += q_head[i] * k_vec[i];
    }
    std.debug.print("Attention score head 0: raw_dot={d:.4}, scaled={d:.4}\n", .{ dot, dot * scale });

    // The attention output should be a weighted sum of V
    // For single token, softmax([x]) = [1.0], so attn_out = V
    @memset(model.buf_attn_out, 0.0);
    for (0..num_heads) |h| {
        const out_head = model.buf_attn_out[h * head_dim ..][0..head_dim];
        const kv_idx = h / kv_group_size;
        const v_offset2 = 0 * num_kv_heads * head_dim + kv_idx * head_dim;
        const v_vec = model.kv_caches[layer_idx].v_cache[v_offset2..][0..head_dim];
        // With single token, score is 1.0
        @memcpy(out_head, v_vec);
    }
    printStats("Attention output (pre-proj)", model.buf_attn_out);

    // Output projection
    simd.simdMatVec(model.buf_attn_proj, layer.wo, model.buf_attn_out, hidden_size, num_heads * head_dim);
    printStats("After O projection", model.buf_attn_proj);

    // Residual connection
    const output = try allocator.alloc(f32, hidden_size);
    defer allocator.free(output);
    @memcpy(output, model.buf_hidden);
    simd.simdResidualAdd(output, model.buf_attn_proj);
    printStats("After attention residual", output);

    std.debug.print("\n=== LAYER 2 FFN ===\n", .{});

    // Pre-FFN norm
    inference.rmsNorm(model.buf_normed, output, layer.ffn_norm, rms_eps);
    printStats("After ffn_norm", model.buf_normed);

    // Gate projection
    simd.simdMatVec(model.buf_ffn_gate, layer.w_gate, model.buf_normed, intermediate_size, hidden_size);
    printStats("After gate projection", model.buf_ffn_gate);

    // Up projection
    simd.simdMatVec(model.buf_ffn_up, layer.w_up, model.buf_normed, intermediate_size, hidden_size);
    printStats("After up projection", model.buf_ffn_up);

    // SwiGLU
    simd.simdSwiGLU(model.buf_ffn_gate, model.buf_ffn_gate, model.buf_ffn_up);
    printStats("After SwiGLU", model.buf_ffn_gate);

    // Down projection
    simd.simdMatVec(model.buf_ffn_out, layer.w_down, model.buf_ffn_gate, hidden_size, intermediate_size);
    printStats("After down projection", model.buf_ffn_out);

    // FFN residual
    simd.simdResidualAdd(output, model.buf_ffn_out);
    printStats("After FFN residual (layer 2 output)", output);

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
