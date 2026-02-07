// ═══════════════════════════════════════════════════════════════════════════════
// FORWARD PASS DEBUG - Step-by-step analysis
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");
const tokenizer_mod = @import("src/vibeec/gguf_tokenizer.zig");
const inference = @import("src/vibeec/gguf_inference.zig");

fn analyzeSlice(name: []const u8, data: []const f32) void {
    var min_val: f32 = data[0];
    var max_val: f32 = data[0];
    var sum: f64 = 0;
    var sum_sq: f64 = 0;
    var zero_count: usize = 0;
    var nan_count: usize = 0;

    for (data) |v| {
        if (std.math.isNan(v)) {
            nan_count += 1;
            continue;
        }
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
        sum += v;
        sum_sq += @as(f64, v) * @as(f64, v);
        if (@abs(v) < 1e-9) zero_count += 1;
    }

    const n = @as(f64, @floatFromInt(data.len));
    const mean = sum / n;
    const stddev = @sqrt((sum_sq / n) - (mean * mean));
    const zero_pct = @as(f64, @floatFromInt(zero_count)) / n * 100;

    std.debug.print("  {s:<20}: len={:>8}, min={d:>10.4}, max={d:>10.4}, mean={d:>10.4}, std={d:>10.4}, zeros={d:.1}%, nan={}\n", .{
        name, data.len, min_val, max_val, mean, stddev, zero_pct, nan_count
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     FORWARD PASS DEBUG - Step Analysis                       ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Load model
    std.debug.print("Loading model...\n", .{});
    var model = model_mod.FullModel.init(allocator, "models/bitnet-2b-fixed.gguf") catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return;
    };
    defer model.deinit();
    try model.loadWeights();

    std.debug.print("\n=== Weight Analysis ===\n", .{});
    analyzeSlice("token_embedding", model.token_embedding[0..@min(model.token_embedding.len, 100000)]);
    analyzeSlice("output_weight", model.output_weight[0..@min(model.output_weight.len, 100000)]);
    analyzeSlice("output_norm", model.output_norm);

    // Sample from layer 0 weights
    if (model.layers.len > 0) {
        const layer0 = model.layers[0];
        analyzeSlice("layer0.wq", layer0.wq[0..@min(layer0.wq.len, 50000)]);
        analyzeSlice("layer0.wk", layer0.wk[0..@min(layer0.wk.len, 50000)]);
        analyzeSlice("layer0.w_gate", layer0.w_gate[0..@min(layer0.w_gate.len, 50000)]);
    }

    // Load tokenizer
    var tokenizer = try tokenizer_mod.Tokenizer.init(allocator, &model.reader);
    defer tokenizer.deinit();

    // Single token forward
    const token: u32 = 9906; // "Hello" second token
    std.debug.print("\n=== Forward pass for token {d} ===\n", .{token});

    const hidden_size = model.config.hidden_size;

    // Step 1: Embedding
    const emb_start = token * hidden_size;
    const embedding = model.token_embedding[emb_start..][0..hidden_size];
    analyzeSlice("1. embedding", embedding);

    // Copy to buf_hidden
    @memcpy(model.buf_hidden, embedding);

    // Step 2: Full forward pass
    std.debug.print("\n=== Full forward pass ===\n", .{});
    const logits_full = try model.forward(token, 0);
    defer allocator.free(logits_full);

    // After forward, buf_temp contains post-RMSnorm hidden state
    analyzeSlice("2. post_forward_hidden", model.buf_temp);
    analyzeSlice("3. forward_logits", logits_full);

    // Check output projection manually
    std.debug.print("\n=== Output projection debug ===\n", .{});
    std.debug.print("  output_weight shape: {} x {}\n", .{ model.config.vocab_size, hidden_size });

    // Manual matmul for first few tokens (verify against logits_full)
    std.debug.print("\n=== First 10 logits values ===\n", .{});
    for (0..10) |i| {
        const token_text = tokenizer.getToken(@intCast(i));
        std.debug.print("  [{d}] logit={d:.4}  \"{s}\"\n", .{ i, logits_full[i], token_text });
    }

    // Find top 5 logits
    std.debug.print("\n=== Top 5 logits ===\n", .{});
    var top_indices: [5]u32 = .{ 0, 0, 0, 0, 0 };
    var top_values: [5]f32 = .{ -std.math.inf(f32), -std.math.inf(f32), -std.math.inf(f32), -std.math.inf(f32), -std.math.inf(f32) };

    for (logits_full, 0..) |l, idx| {
        if (std.math.isNan(l)) continue;
        if (l > top_values[4]) {
            var insert_pos: usize = 4;
            while (insert_pos > 0 and l > top_values[insert_pos - 1]) : (insert_pos -= 1) {}
            var j: usize = 4;
            while (j > insert_pos) : (j -= 1) {
                top_indices[j] = top_indices[j - 1];
                top_values[j] = top_values[j - 1];
            }
            top_indices[insert_pos] = @intCast(idx);
            top_values[insert_pos] = l;
        }
    }

    for (0..5) |i| {
        const token_text = tokenizer.getToken(top_indices[i]);
        std.debug.print("  [{d}] token={d}, logit={d:.4}  \"{s}\"\n", .{ i + 1, top_indices[i], top_values[i], token_text });
    }

    std.debug.print("\n=== DEBUG COMPLETE ===\n\n", .{});
}
