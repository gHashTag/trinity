// ═══════════════════════════════════════════════════════════════════════════════
// LOGITS DIAGNOSTIC - Debug BitNet-2B generation issues
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");
const tokenizer_mod = @import("src/vibeec/gguf_tokenizer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     LOGITS DIAGNOSTIC - BitNet-2B Debug                      ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Load model
    std.debug.print("Loading model...\n", .{});
    var model = model_mod.FullModel.init(allocator, "models/bitnet-2b-fixed.gguf") catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();
    try model.loadWeights();

    // Load tokenizer
    var tokenizer = try tokenizer_mod.Tokenizer.init(allocator, &model.reader);
    defer tokenizer.deinit();

    std.debug.print("\n=== Model Config ===\n", .{});
    std.debug.print("  vocab_size:    {}\n", .{model.config.vocab_size});
    std.debug.print("  hidden_size:   {}\n", .{model.config.hidden_size});
    std.debug.print("  num_layers:    {}\n", .{model.config.num_layers});
    std.debug.print("  num_heads:     {}\n", .{model.config.num_heads});
    std.debug.print("  num_kv_heads:  {}\n", .{model.config.num_kv_heads});
    std.debug.print("  head_dim:      {}\n", .{model.config.head_dim});

    // Test prompt
    const prompt = "Hello";
    const tokens = try tokenizer.encode(allocator, prompt);
    defer allocator.free(tokens);

    std.debug.print("\n=== Prompt: \"{s}\" ===\n", .{prompt});
    std.debug.print("Tokens ({d}): ", .{tokens.len});
    for (tokens) |t| {
        std.debug.print("{d} ", .{t});
    }
    std.debug.print("\n", .{});

    // Forward pass through prompt
    var pos: usize = 0;
    var logits: []f32 = undefined;

    for (tokens) |token| {
        if (pos > 0) allocator.free(logits);
        logits = try model.forward(token, pos);
        pos += 1;
    }
    defer allocator.free(logits);

    // Analyze logits
    std.debug.print("\n=== Logits Analysis (after prompt) ===\n", .{});

    var min_val: f32 = logits[0];
    var max_val: f32 = logits[0];
    var sum: f64 = 0;
    var sum_sq: f64 = 0;
    var zero_count: usize = 0;
    var nan_count: usize = 0;
    var inf_count: usize = 0;

    for (logits) |l| {
        if (std.math.isNan(l)) {
            nan_count += 1;
            continue;
        }
        if (std.math.isInf(l)) {
            inf_count += 1;
            continue;
        }
        if (l < min_val) min_val = l;
        if (l > max_val) max_val = l;
        sum += l;
        sum_sq += @as(f64, l) * @as(f64, l);
        if (@abs(l) < 1e-6) zero_count += 1;
    }

    const n = @as(f64, @floatFromInt(logits.len));
    const mean = sum / n;
    const variance = (sum_sq / n) - (mean * mean);
    const stddev = @sqrt(variance);

    std.debug.print("  Logits length: {}\n", .{logits.len});
    std.debug.print("  Min:           {d:.4}\n", .{min_val});
    std.debug.print("  Max:           {d:.4}\n", .{max_val});
    std.debug.print("  Mean:          {d:.4}\n", .{mean});
    std.debug.print("  Std:           {d:.4}\n", .{stddev});
    std.debug.print("  Zeros:         {} ({d:.2}%)\n", .{zero_count, @as(f64, @floatFromInt(zero_count)) / n * 100});
    std.debug.print("  NaN count:     {}\n", .{nan_count});
    std.debug.print("  Inf count:     {}\n", .{inf_count});

    // Top-10 tokens
    std.debug.print("\n=== Top 10 Token Probabilities (Greedy) ===\n", .{});

    // Find top 10
    var top_indices: [10]u32 = undefined;
    var top_values: [10]f32 = undefined;
    for (0..10) |i| {
        top_indices[i] = 0;
        top_values[i] = -std.math.inf(f32);
    }

    for (logits, 0..) |l, idx| {
        if (std.math.isNan(l) or std.math.isInf(l)) continue;

        // Check if this is higher than the lowest in top-10
        if (l > top_values[9]) {
            // Insert in sorted order
            var insert_pos: usize = 9;
            while (insert_pos > 0 and l > top_values[insert_pos - 1]) : (insert_pos -= 1) {}

            // Shift down
            var j: usize = 9;
            while (j > insert_pos) : (j -= 1) {
                top_indices[j] = top_indices[j - 1];
                top_values[j] = top_values[j - 1];
            }
            top_indices[insert_pos] = @intCast(idx);
            top_values[insert_pos] = l;
        }
    }

    // Compute softmax for top tokens
    var exp_sum: f64 = 0;
    for (logits) |l| {
        if (!std.math.isNan(l) and !std.math.isInf(l)) {
            exp_sum += @exp(@as(f64, l - max_val));
        }
    }

    for (0..10) |i| {
        const prob = @exp(@as(f64, top_values[i] - max_val)) / exp_sum;
        const token_text = tokenizer.getToken(top_indices[i]);
        std.debug.print("  [{d}] {d:>6} ({d:>8.4}) p={d:.4}  \"{s}\"\n", .{
            i + 1, top_indices[i], top_values[i], prob, token_text
        });
    }

    // Generate 5 tokens with greedy
    std.debug.print("\n=== Greedy Generation (5 tokens) ===\n", .{});
    std.debug.print("  ", .{});

    var prev_token = top_indices[0];
    for (0..5) |_| {
        const text = tokenizer.getToken(prev_token);
        std.debug.print("{s}", .{text});

        const next_logits = try model.forward(prev_token, pos);
        defer allocator.free(next_logits);
        pos += 1;

        // Find max
        var max_idx: u32 = 0;
        var max_v: f32 = next_logits[0];
        for (next_logits[1..], 1..) |l, idx| {
            if (!std.math.isNan(l) and l > max_v) {
                max_v = l;
                max_idx = @intCast(idx);
            }
        }
        prev_token = max_idx;
    }
    std.debug.print("\n", .{});

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n\n", .{});
}
