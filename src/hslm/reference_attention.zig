// @origin(manual) @regen(pending)
// HSLM Reference — Attention Implementations
// Migrated from archive/implementations/zig/src/attention.zig
// Standard attention (O(N^2)) and Flash Attention (O(N) memory)

const std = @import("std");

pub const FlashAttentionConfig = struct {
    num_heads: usize = 12,
    head_dim: usize = 64,
    dropout: f32 = 0.0,
    is_causal: bool = true,
    block_size: usize = 64,
};

/// Softmax with numerical stability (max subtraction)
pub fn softmax(x: []f32, out: []f32) void {
    var max_val: f32 = x[0];
    for (x[1..]) |v| {
        if (v > max_val) max_val = v;
    }
    var sum: f32 = 0.0;
    for (x, 0..) |v, i| {
        out[i] = @exp(v - max_val);
        sum += out[i];
    }
    for (out) |*v| {
        v.* /= sum;
    }
}

/// Standard attention: Q @ K^T / sqrt(d) -> softmax -> @ V
pub fn standardAttention(
    allocator: std.mem.Allocator,
    q: []const f32,
    k: []const f32,
    v: []const f32,
    seq_len: usize,
    head_dim: usize,
    is_causal: bool,
) ![]f32 {
    const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));

    var scores = try allocator.alloc(f32, seq_len * seq_len);
    defer allocator.free(scores);

    for (0..seq_len) |i| {
        for (0..seq_len) |j| {
            var dot: f32 = 0.0;
            for (0..head_dim) |d| {
                dot += q[i * head_dim + d] * k[j * head_dim + d];
            }
            scores[i * seq_len + j] = dot * scale;
            if (is_causal and j > i) {
                scores[i * seq_len + j] = -std.math.inf(f32);
            }
        }
    }

    var probs = try allocator.alloc(f32, seq_len * seq_len);
    defer allocator.free(probs);
    for (0..seq_len) |i| {
        const row_start = i * seq_len;
        softmax(scores[row_start .. row_start + seq_len], probs[row_start .. row_start + seq_len]);
    }

    var output = try allocator.alloc(f32, seq_len * head_dim);
    @memset(output, 0.0);
    for (0..seq_len) |i| {
        for (0..seq_len) |j| {
            const prob = probs[i * seq_len + j];
            for (0..head_dim) |d| {
                output[i * head_dim + d] += prob * v[j * head_dim + d];
            }
        }
    }

    return output;
}

/// Flash Attention — simplified reference (O(N) memory via online softmax)
pub fn flashAttention(
    allocator: std.mem.Allocator,
    q: []const f32,
    k: []const f32,
    v: []const f32,
    seq_len: usize,
    head_dim: usize,
    config: FlashAttentionConfig,
) ![]f32 {
    const block_size = config.block_size;
    const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));

    var output = try allocator.alloc(f32, seq_len * head_dim);
    @memset(output, 0.0);

    var row_max = try allocator.alloc(f32, seq_len);
    defer allocator.free(row_max);
    @memset(row_max, -std.math.inf(f32));

    var row_sum = try allocator.alloc(f32, seq_len);
    defer allocator.free(row_sum);
    @memset(row_sum, 0.0);

    var j: usize = 0;
    while (j < seq_len) : (j += block_size) {
        const j_end = @min(j + block_size, seq_len);
        for (0..seq_len) |i| {
            if (config.is_causal and j > i) continue;
            for (j..j_end) |jj| {
                if (config.is_causal and jj > i) continue;
                var dot: f32 = 0.0;
                for (0..head_dim) |d| {
                    dot += q[i * head_dim + d] * k[jj * head_dim + d];
                }
                dot *= scale;
                const old_max = row_max[i];
                row_max[i] = @max(row_max[i], dot);
                const exp_diff = @exp(old_max - row_max[i]);
                row_sum[i] = row_sum[i] * exp_diff + @exp(dot - row_max[i]);
                const weight = @exp(dot - row_max[i]);
                for (0..head_dim) |d| {
                    output[i * head_dim + d] = output[i * head_dim + d] * exp_diff + weight * v[jj * head_dim + d];
                }
            }
        }
    }

    for (0..seq_len) |i| {
        for (0..head_dim) |d| {
            output[i * head_dim + d] /= row_sum[i];
        }
    }

    return output;
}

test "softmax" {
    var input = [_]f32{ 1.0, 2.0, 3.0 };
    var output_buf: [3]f32 = undefined;
    softmax(&input, &output_buf);
    var sum: f32 = 0.0;
    for (output_buf) |val| sum += val;
    try std.testing.expect(@abs(sum - 1.0) < 1e-5);
    try std.testing.expect(output_buf[2] > output_buf[1]);
    try std.testing.expect(output_buf[1] > output_buf[0]);
}

test "standard attention" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const seq_len: usize = 4;
    const head_dim: usize = 8;
    var q: [seq_len * head_dim]f32 = undefined;
    var k: [seq_len * head_dim]f32 = undefined;
    var v: [seq_len * head_dim]f32 = undefined;
    for (0..seq_len * head_dim) |i| {
        q[i] = @as(f32, @floatFromInt(i % head_dim)) * 0.1;
        k[i] = @as(f32, @floatFromInt(i % head_dim)) * 0.1;
        v[i] = @as(f32, @floatFromInt(i % head_dim)) * 0.1;
    }

    const output = try standardAttention(allocator, &q, &k, &v, seq_len, head_dim, true);
    defer allocator.free(output);
    try std.testing.expectEqual(seq_len * head_dim, output.len);
}
