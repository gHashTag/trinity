// Diagnostic: Test inference components step by step
const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");
const inference = @import("src/vibeec/gguf_inference.zig");
const model_mod = @import("src/vibeec/gguf_model.zig");

fn printStats(name: []const u8, data: []const f32) void {
    if (data.len == 0) {
        std.debug.print("{s}: EMPTY\n", .{name});
        return;
    }

    var min: f32 = data[0];
    var max: f32 = data[0];
    var sum: f64 = 0;
    var sum_sq: f64 = 0;
    var zeros: usize = 0;
    var nans: usize = 0;
    var infs: usize = 0;

    for (data) |v| {
        if (std.math.isNan(v)) {
            nans += 1;
            continue;
        }
        if (std.math.isInf(v)) {
            infs += 1;
            continue;
        }
        if (v < min) min = v;
        if (v > max) max = v;
        sum += v;
        sum_sq += @as(f64, v) * @as(f64, v);
        if (v == 0) zeros += 1;
    }

    const n: f64 = @floatFromInt(data.len);
    const mean = sum / n;
    const variance = (sum_sq / n) - (mean * mean);
    const std_dev = @sqrt(@abs(variance));

    std.debug.print("{s}:\n", .{name});
    std.debug.print("  len={d}, min={d:.4}, max={d:.4}\n", .{ data.len, min, max });
    std.debug.print("  mean={d:.4}, std={d:.4}\n", .{ mean, std_dev });
    std.debug.print("  zeros={d}, nans={d}, infs={d}\n", .{ zeros, nans, infs });
    std.debug.print("  first 5: ", .{});
    for (data[0..@min(5, data.len)]) |v| {
        std.debug.print("{d:.4} ", .{v});
    }
    std.debug.print("\n\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("=== INFERENCE DIAGNOSTIC ===\n\n", .{});
    std.debug.print("Loading model: {s}\n\n", .{path});

    var model = try model_mod.FullModel.init(allocator, path);
    defer model.deinit();

    try model.loadWeights();
    model.printConfig();

    std.debug.print("\n=== WEIGHT STATISTICS ===\n\n", .{});

    // Check token embeddings
    printStats("token_embedding", model.token_embedding);

    // Check output weights
    printStats("output_weight", model.output_weight);

    // Check output norm
    printStats("output_norm", model.output_norm);

    // Check first layer weights
    if (model.layers.len > 0) {
        const layer = model.layers[0];
        printStats("layer0.attn_norm", layer.attn_norm);
        printStats("layer0.wq (first 1000)", layer.wq[0..@min(1000, layer.wq.len)]);
        printStats("layer0.wk (first 1000)", layer.wk[0..@min(1000, layer.wk.len)]);
    }

    std.debug.print("\n=== FORWARD PASS TEST ===\n\n", .{});

    // Test forward pass with a single token (BOS = 1)
    const test_token: u32 = 1;
    std.debug.print("Testing forward pass with token {d} (BOS)...\n", .{test_token});

    const logits = try model.forward(test_token, 0);
    defer allocator.free(logits);

    printStats("logits", logits);

    // Check top 5 tokens
    std.debug.print("Top 5 predicted tokens:\n", .{});
    var indices: [5]usize = undefined;
    var values: [5]f32 = undefined;
    for (&indices, &values) |*i, *v| {
        i.* = 0;
        v.* = -std.math.inf(f32);
    }

    for (logits, 0..) |l, i| {
        if (std.math.isNan(l) or std.math.isInf(l)) continue;
        for (0..5) |j| {
            if (l > values[j]) {
                // Shift down
                var k: usize = 4;
                while (k > j) : (k -= 1) {
                    values[k] = values[k - 1];
                    indices[k] = indices[k - 1];
                }
                values[j] = l;
                indices[j] = i;
                break;
            }
        }
    }

    // Initialize tokenizer using model's reader
    const tokenizer = @import("src/vibeec/gguf_tokenizer.zig");
    var tok = try tokenizer.Tokenizer.init(allocator, &model.reader);
    defer tok.deinit();

    for (0..5) |j| {
        const token_id = @as(u32, @intCast(indices[j]));
        const token_arr = [_]u32{token_id};
        const decoded = tok.decode(allocator, &token_arr) catch "<error>";
        defer if (decoded.ptr != "<error>".ptr) allocator.free(decoded);
        std.debug.print("  {d}: token {d} = {d:.4} -> \"{s}\"\n", .{ j + 1, indices[j], values[j], decoded });
    }

    // Also decode a few sample generations with actual prompt
    std.debug.print("\nSample generation with prompt:\n", .{});
    model.resetKVCache();

    // Tokenize a simple prompt in TinyLlama format
    const prompt = "<|system|>\nYou are helpful.</s>\n<|user|>\nWhat is 2+2?</s>\n<|assistant|>\n";
    const prompt_tokens = tok.encode(allocator, prompt) catch &[_]u32{1};
    defer if (prompt_tokens.ptr != (&[_]u32{1}).ptr) allocator.free(prompt_tokens);

    std.debug.print("  Prompt tokens ({d}): ", .{prompt_tokens.len});
    for (prompt_tokens[0..@min(10, prompt_tokens.len)]) |t| {
        std.debug.print("{d} ", .{t});
    }
    if (prompt_tokens.len > 10) std.debug.print("...", .{});
    std.debug.print("\n", .{});

    // Prefill: process all prompt tokens
    var pos: usize = 0;
    var last_logits: ?[]f32 = null;
    for (prompt_tokens) |t| {
        if (last_logits) |l| allocator.free(l);
        last_logits = model.forward(t, pos) catch null;
        pos += 1;
    }

    // Generate using last logits from prefill
    var gen_tokens: [10]u32 = undefined;

    if (last_logits) |initial_logits| {
        var current_logits: []f32 = initial_logits;
        var owns_logits = false;

        for (0..10) |step| {
            // Greedy: find max
            var max_idx: u32 = 0;
            var max_val: f32 = current_logits[0];
            for (current_logits[1..], 1..) |l, i| {
                if (l > max_val) {
                    max_val = l;
                    max_idx = @intCast(i);
                }
            }

            // Print logits stats for each step
            var sum: f64 = 0;
            for (current_logits) |l| sum += l;
            const mean = sum / @as(f64, @floatFromInt(current_logits.len));
            std.debug.print("  Step {d}: token={d}, max_logit={d:.4}, mean={d:.4}\n",
                .{ step, max_idx, max_val, mean });

            gen_tokens[step] = max_idx;

            // Free previous logits if we own them
            if (owns_logits) {
                allocator.free(current_logits);
            }

            // Get next logits
            current_logits = model.forward(max_idx, pos) catch break;
            owns_logits = true;
            pos += 1;
        }

        if (owns_logits) {
            allocator.free(current_logits);
        } else {
            allocator.free(initial_logits);
        }
    }

    // Decode generated tokens
    const gen_decoded = tok.decode(allocator, &gen_tokens) catch "<error>";
    defer if (gen_decoded.ptr != "<error>".ptr) allocator.free(gen_decoded);
    std.debug.print("  Tokens: ", .{});
    for (gen_tokens) |t| {
        std.debug.print("{d} ", .{t});
    }
    std.debug.print("\n  Decoded: \"{s}\"\n", .{gen_decoded});

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
