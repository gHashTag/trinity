// Diagnostic: Test attention mechanism in isolation
const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");
const simd = @import("src/vibeec/simd_matmul.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("=== ATTENTION DIAGNOSTIC ===\n\n", .{});

    var model = try model_mod.FullModel.init(allocator, path);
    defer model.deinit();
    try model.loadWeights();

    // Reset KV cache
    model.resetKVCache();

    // Test sequence: BOS token followed by a few tokens
    const test_tokens = [_]u32{ 1, 450, 338, 263, 1243 }; // BOS + "This is a test"

    std.debug.print("Processing tokens: ", .{});
    for (test_tokens) |t| {
        std.debug.print("{d} ", .{t});
    }
    std.debug.print("\n\n", .{});

    // Process each token and examine logits
    for (test_tokens, 0..) |token, pos| {
        const logits = try model.forward(token, pos);
        defer allocator.free(logits);

        // Find top 3 predictions
        var top_indices: [3]u32 = undefined;
        var top_values: [3]f32 = undefined;
        for (&top_values) |*v| v.* = -std.math.inf(f32);

        for (logits, 0..) |l, i| {
            for (0..3) |j| {
                if (l > top_values[j]) {
                    var k: usize = 2;
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

        // Calculate logits stats
        var sum: f64 = 0;
        var max_val: f32 = logits[0];
        var min_val: f32 = logits[0];
        for (logits) |l| {
            sum += l;
            if (l > max_val) max_val = l;
            if (l < min_val) min_val = l;
        }
        const mean = sum / @as(f64, @floatFromInt(logits.len));

        std.debug.print("Pos {d}: token={d}, logits: min={d:.2}, max={d:.2}, mean={d:.4}\n", .{
            pos, token, min_val, max_val, mean
        });
        std.debug.print("  Top 3: [{d}]={d:.2}, [{d}]={d:.2}, [{d}]={d:.2}\n\n", .{
            top_indices[0], top_values[0],
            top_indices[1], top_values[1],
            top_indices[2], top_values[2],
        });
    }

    // Now check if attention is causal - generate a few tokens
    std.debug.print("=== GENERATION TEST ===\n", .{});
    model.resetKVCache();

    // Process BOS
    var last_logits = try model.forward(1, 0);
    var pos: usize = 1;

    // Generate 5 tokens
    for (0..5) |step| {
        // Greedy select
        var max_idx: u32 = 0;
        var max_val: f32 = last_logits[0];
        for (last_logits[1..], 1..) |l, i| {
            if (l > max_val) {
                max_val = l;
                max_idx = @intCast(i);
            }
        }

        std.debug.print("Step {d}: generated token {d}, logit={d:.2}\n", .{ step, max_idx, max_val });

        allocator.free(last_logits);
        last_logits = try model.forward(max_idx, pos);
        pos += 1;
    }
    allocator.free(last_logits);

    std.debug.print("\n=== MATRIX MULTIPLICATION TEST ===\n", .{});

    // Test column-major matVec directly
    // Create a simple 3x3 test matrix in column-major order
    // Conceptual matrix: [[1,2,3], [4,5,6], [7,8,9]]
    // Column-major: col0=[1,4,7], col1=[2,5,8], col2=[3,6,9]
    // Storage: [1,4,7, 2,5,8, 3,6,9]
    const mat = [_]f32{ 1, 4, 7, 2, 5, 8, 3, 6, 9 };
    const vec = [_]f32{ 1, 1, 1 };
    var output: [3]f32 = undefined;

    simd.simdMatVecColMajor(&output, &mat, &vec, 3, 3);

    // Expected: each row sums to:
    // row 0: 1+2+3 = 6
    // row 1: 4+5+6 = 15
    // row 2: 7+8+9 = 24
    std.debug.print("Column-major matVec test:\n", .{});
    std.debug.print("  Output: [{d:.0}, {d:.0}, {d:.0}]\n", .{ output[0], output[1], output[2] });
    std.debug.print("  Expected: [6, 15, 24]\n", .{});

    if (output[0] == 6 and output[1] == 15 and output[2] == 24) {
        std.debug.print("  ✓ Column-major matVec is CORRECT!\n", .{});
    } else {
        std.debug.print("  ✗ Column-major matVec is WRONG!\n", .{});
    }

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
