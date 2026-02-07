// Diagnostic: Check output layer behavior
const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");
const inference = @import("src/vibeec/gguf_inference.zig");
const simd = @import("src/vibeec/simd_matmul.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("=== OUTPUT LAYER DIAGNOSTIC ===\n\n", .{});

    var model = try model_mod.FullModel.init(allocator, path);
    defer model.deinit();
    try model.loadWeights();

    const hidden_size = model.config.hidden_size;
    const vocab_size = model.config.vocab_size;

    std.debug.print("hidden_size={d}, vocab_size={d}\n\n", .{ hidden_size, vocab_size });

    // Check output_weight statistics
    var ow_min: f32 = model.output_weight[0];
    var ow_max: f32 = model.output_weight[0];
    var ow_sum: f64 = 0;

    for (model.output_weight) |w| {
        if (w < ow_min) ow_min = w;
        if (w > ow_max) ow_max = w;
        ow_sum += w;
    }

    std.debug.print("output_weight stats:\n", .{});
    std.debug.print("  min={d:.4}, max={d:.4}, mean={d:.6}\n\n", .{
        ow_min, ow_max, ow_sum / @as(f64, @floatFromInt(model.output_weight.len))
    });

    // Check if specific tokens have high weights
    // For row-major (GGUF): W[out][in] = data[out * hidden_size + in]
    // Token 17994 ("Bibliographie") - check its row in output_weight
    const suspicious_tokens = [_]u32{ 17994, 24109, 28090, 1, 450, 338 };

    std.debug.print("Checking output weight rows for suspicious tokens:\n", .{});
    for (suspicious_tokens) |token| {
        const row_start = @as(usize, token) * hidden_size;
        const row = model.output_weight[row_start..][0..hidden_size];

        var row_sum: f64 = 0;
        var row_sum_sq: f64 = 0;
        var row_max: f32 = row[0];

        for (row) |w| {
            row_sum += w;
            row_sum_sq += @as(f64, w) * @as(f64, w);
            if (@abs(w) > @abs(row_max)) row_max = w;
        }

        const row_mean = row_sum / @as(f64, @floatFromInt(hidden_size));
        const row_norm = @sqrt(row_sum_sq);

        std.debug.print("  Token {d}: mean={d:.6}, max_abs={d:.4}, L2_norm={d:.4}\n", .{
            token, row_mean, row_max, row_norm
        });
    }

    // Check output projection with random input
    std.debug.print("\n=== OUTPUT PROJECTION TEST ===\n\n", .{});

    // Create a random-ish input (hidden state)
    const test_hidden = try allocator.alloc(f32, hidden_size);
    defer allocator.free(test_hidden);

    // Initialize with small values centered around 0
    for (test_hidden, 0..) |*h, i| {
        h.* = @as(f32, @floatFromInt(@as(i32, @intCast(i % 100)) - 50)) / 500.0;
    }

    // Apply output norm
    const normed = try allocator.alloc(f32, hidden_size);
    defer allocator.free(normed);
    inference.rmsNorm(normed, test_hidden, model.output_norm, model.config.rms_norm_eps);

    // Project to vocab
    const logits = try allocator.alloc(f32, vocab_size);
    defer allocator.free(logits);
    simd.simdMatVec(logits, model.output_weight, normed, vocab_size, hidden_size);

    // Find top predictions
    std.debug.print("Top 10 predictions for random input:\n", .{});
    var top_indices: [10]u32 = undefined;
    var top_values: [10]f32 = undefined;
    for (&top_values) |*v| v.* = -std.math.inf(f32);

    for (logits, 0..) |l, i| {
        for (0..10) |j| {
            if (l > top_values[j]) {
                var k: usize = 9;
                while (k > j) : (k -= 1) {
                    top_values[k] = top_values[k - 1];
                    top_indices[k] = top_indices[k - 1];
                }
                top_values[j] = l;
                top_indices[j] = @intCast(i);
                break;
            }
        }
    }

    for (0..10) |j| {
        std.debug.print("  {d}: token {d} = {d:.4}\n", .{ j + 1, top_indices[j], top_values[j] });
    }

    // Check if the same tokens appear regardless of input
    std.debug.print("\n=== TESTING WITH DIFFERENT INPUTS ===\n\n", .{});

    // Test with a few different hidden states
    const test_inputs = [_][2]f32{
        .{ 0.1, 0.0 }, // Positive mean
        .{ -0.1, 0.0 }, // Negative mean
        .{ 0.0, 0.1 }, // Zero mean, high variance
    };

    for (test_inputs) |params| {
        const mean = params[0];
        const offset = params[1];

        // Create test input
        for (test_hidden, 0..) |*h, i| {
            h.* = mean + offset * @sin(@as(f32, @floatFromInt(i)) * 0.1);
        }

        // Normalize and project
        inference.rmsNorm(normed, test_hidden, model.output_norm, model.config.rms_norm_eps);
        simd.simdMatVec(logits, model.output_weight, normed, vocab_size, hidden_size);

        // Find top prediction
        var max_idx: u32 = 0;
        var max_val: f32 = logits[0];
        for (logits[1..], 1..) |l, i| {
            if (l > max_val) {
                max_val = l;
                max_idx = @intCast(i);
            }
        }

        std.debug.print("Input mean={d:.2}: top token={d}, logit={d:.4}\n", .{ mean, max_idx, max_val });
    }

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
