//! tri/softmax — Softmax activation
//! TTT Dogfood v0.2 Stage 285

const std = @import("std");

pub fn softmax(allocator: std.mem.Allocator, inputs: []const f64) ![]f64 {
    const result = try allocator.alloc(f64, inputs.len);

    var max: f64 = inputs[0];
    for (inputs) |v| {
        if (v > max) max = v;
    }

    var sum: f64 = 0;
    for (inputs, 0..) |v, i| {
        result[i] = @exp(v - max);
        sum += result[i];
    }

    for (0..result.len) |i| {
        result[i] /= sum;
    }

    return result;
}

test "softmax" {
    const inputs = &[_]f64{ 1, 2, 3 };
    const result = try softmax(std.testing.allocator, inputs);
    defer std.testing.allocator.free(result);
    try std.testing.expect(result.len == 3);
}
