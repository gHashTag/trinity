const std = @import("std");
const tc = @import("trinity_constants.zig");

pub const FIB_VISIBLE = [_]u32{ 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144 };

pub fn isFibVisible(pos: u32) bool {
    for (FIB_VISIBLE) |f| {
        if (pos == f) return true;
    }
    return false;
}

pub fn fibonacciDistanceMask(comptime seq_len: u32) [seq_len]bool {
    var mask: [seq_len]bool = @splat(false);
    for (FIB_VISIBLE) |f| {
        if (f < seq_len) mask[f] = true;
    }
    return mask;
}

pub fn phiAttentionScale() f64 {
    return std.math.pow(f64, @as(f64, @floatFromInt(tc.D_HEAD)), -tc.PHI_INV);
}

pub fn applyPhiAttention(
    q: []const f64,
    k: []const f64,
    v: []const f64,
    output: []f64,
    seq_len: usize,
) void {
    const scale = phiAttentionScale();
    for (0..seq_len) |i| {
        var sum: f64 = 0;
        var weight_sum: f64 = 0;
        for (0..seq_len) |j| {
            if (!isFibVisible(@intCast(if (j >= i) j - i else i - j))) continue;
            const dot = q[i] * k[j] * scale;
            const w = std.math.exp(dot);
            sum += w * v[j];
            weight_sum += w;
        }
        output[i] = if (weight_sum > 0) sum / weight_sum else 0;
    }
}

test "Fibonacci mask: visible positions" {
    const mask = fibonacciDistanceMask(200);
    try std.testing.expect(mask[1]);
    try std.testing.expect(mask[2]);
    try std.testing.expect(mask[3]);
    try std.testing.expect(mask[5]);
    try std.testing.expect(mask[144]);
    try std.testing.expect(!mask[4]);
    try std.testing.expect(!mask[100]);
}

test "Fibonacci mask: sparsity" {
    const mask = fibonacciDistanceMask(512);
    var visible: u32 = 0;
    for (mask) |m| {
        if (m) visible += 1;
    }
    const sparsity = @as(f64, @floatFromInt(visible)) / 512.0;
    try std.testing.expect(sparsity < 0.05);
}

test "phi attention scale" {
    const s = phiAttentionScale();
    try std.testing.expect(s > 0);
    try std.testing.expect(s < 1.0);
}

test "phi attention: output non-zero for valid input" {
    const n = 16;
    var q: [n]f64 = @splat(1.0);
    var k: [n]f64 = @splat(1.0);
    var v: [n]f64 = @splat(2.0);
    var out: [n]f64 = @splat(0.0);
    applyPhiAttention(&q, &k, &v, &out, n);
    var any_nonzero = false;
    for (out) |o| {
        if (o != 0.0) any_nonzero = true;
    }
    try std.testing.expect(any_nonzero);
}
