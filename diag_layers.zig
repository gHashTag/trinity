// Diagnostic: Trace hidden state through layers
const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");
const inference = @import("src/vibeec/gguf_inference.zig");

fn printHiddenStats(name: []const u8, data: []const f32) void {
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
    const variance = (sum_sq / n) - (mean * mean);
    const std_dev = @sqrt(@abs(variance));
    const l2_norm = @sqrt(sum_sq);

    std.debug.print("{s}: mean={d:.4}, std={d:.4}, min={d:.2}, max={d:.2}, L2={d:.2}\n", .{
        name, mean, std_dev, min, max, l2_norm
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("=== LAYER-BY-LAYER TRACE ===\n\n", .{});

    var model = try model_mod.FullModel.init(allocator, path);
    defer model.deinit();
    try model.loadWeights();

    const hidden_size = model.config.hidden_size;
    model.resetKVCache();

    // Process token 1 (BOS) at position 0
    const token: u32 = 1;
    const pos: usize = 0;

    std.debug.print("Processing token {d} at position {d}\n\n", .{ token, pos });

    // Get embedding
    const emb_offset = @as(usize, token) * hidden_size;
    const hidden = try allocator.alloc(f32, hidden_size);
    defer allocator.free(hidden);
    @memcpy(hidden, model.token_embedding[emb_offset..][0..hidden_size]);

    printHiddenStats("After embedding", hidden);

    // Process through each layer manually
    const temp = try allocator.alloc(f32, hidden_size);
    defer allocator.free(temp);

    for (0..model.config.num_layers) |layer_idx| {
        model.forwardLayerOptimized(temp, hidden, layer_idx, pos);
        @memcpy(hidden, temp);

        if (layer_idx < 5 or layer_idx >= model.config.num_layers - 3) {
            var buf: [32]u8 = undefined;
            const name = std.fmt.bufPrint(&buf, "After layer {d}", .{layer_idx}) catch "layer";
            printHiddenStats(name, hidden);
        } else if (layer_idx == 5) {
            std.debug.print("... (layers 5-18 omitted) ...\n", .{});
        }
    }

    // Final norm
    const normed = try allocator.alloc(f32, hidden_size);
    defer allocator.free(normed);
    inference.rmsNorm(normed, hidden, model.output_norm, model.config.rms_norm_eps);
    printHiddenStats("After final norm", normed);

    // Output logits
    const logits = try model.forward(token, 0); // Note: This reprocesses, just for reference
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

    std.debug.print("\nTop prediction: token {d} with logit {d:.4}\n", .{ max_idx, max_val });

    // Now compare with a different token
    std.debug.print("\n=== COMPARING WITH TOKEN 450 ('The') ===\n\n", .{});

    model.resetKVCache();

    const token2: u32 = 450;
    const emb_offset2 = @as(usize, token2) * hidden_size;
    @memcpy(hidden, model.token_embedding[emb_offset2..][0..hidden_size]);

    printHiddenStats("After embedding (450)", hidden);

    for (0..model.config.num_layers) |layer_idx| {
        model.forwardLayerOptimized(temp, hidden, layer_idx, pos);
        @memcpy(hidden, temp);

        if (layer_idx < 5 or layer_idx >= model.config.num_layers - 3) {
            var buf: [32]u8 = undefined;
            const name = std.fmt.bufPrint(&buf, "After layer {d}", .{layer_idx}) catch "layer";
            printHiddenStats(name, hidden);
        } else if (layer_idx == 5) {
            std.debug.print("... (layers 5-18 omitted) ...\n", .{});
        }
    }

    inference.rmsNorm(normed, hidden, model.output_norm, model.config.rms_norm_eps);
    printHiddenStats("After final norm", normed);

    model.resetKVCache();
    const logits2 = try model.forward(token2, 0);
    defer allocator.free(logits2);

    var max_idx2: u32 = 0;
    var max_val2: f32 = logits2[0];
    for (logits2[1..], 1..) |l, i| {
        if (l > max_val2) {
            max_val2 = l;
            max_idx2 = @intCast(i);
        }
    }

    std.debug.print("\nTop prediction: token {d} with logit {d:.4}\n", .{ max_idx2, max_val2 });

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
