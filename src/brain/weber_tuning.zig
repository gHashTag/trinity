const std = @import("std");

pub const PHI: f64 = 1.6180339887498948482;

pub const WeberLevel = enum(u8) {
    fine = 0,
    medium = 1,
    coarse = 2,
};

pub fn weberQuantize(value: f64, jnd_fraction: f64) i2 {
    if (@abs(value) < jnd_fraction * 0.5) return 0;
    if (value > 0) return 1;
    if (value < 0) return -1;
    return 0;
}

pub fn weberQuantizeLevels(value: f64, levels: usize) i64 {
    if (value == 0) return 0;
    const sign: i64 = if (value > 0) 1 else -1;
    const abs_v = @abs(value);
    const log_val = std.math.log(f64, std.math.e, abs_v + 1.0);
    const quantized = @round(log_val * @as(f64, @floatFromInt(levels)) / 5.0);
    return sign * @as(i64, @intFromFloat(@min(@abs(quantized), @as(f64, @floatFromInt(levels)))));
}

pub fn adaptiveJND(base_jnd: f64, magnitude: f64) f64 {
    return base_jnd * (1.0 + std.math.log1p(@abs(magnitude)));
}

pub fn ternaryEncode(values: []const f64, jnd: f64, output: []i2) void {
    for (values, output) |v, *o| {
        o.* = weberQuantize(v, jnd);
    }
}

pub fn ternaryStats(encoded: []const i2) struct { pos: usize, neg: usize, zero: usize, sparsity: f64 } {
    var pos: usize = 0;
    var neg: usize = 0;
    var zero: usize = 0;
    for (encoded) |v| {
        if (v > 0) pos += 1;
        if (v < 0) neg += 1;
        if (v == 0) zero += 1;
    }
    return .{
        .pos = pos,
        .neg = neg,
        .zero = zero,
        .sparsity = @as(f64, @floatFromInt(zero)) / @as(f64, @floatFromInt(encoded.len)),
    };
}

test "weber quantize" {
    try std.testing.expectEqual(@as(i2, 1), weberQuantize(0.5, 0.1));
    try std.testing.expectEqual(@as(i2, -1), weberQuantize(-0.5, 0.1));
    try std.testing.expectEqual(@as(i2, 0), weberQuantize(0.01, 0.1));
}

test "adaptive JND" {
    const jnd_small = adaptiveJND(0.1, 0.1);
    const jnd_large = adaptiveJND(0.1, 10.0);
    try std.testing.expect(jnd_large > jnd_small);
}

test "ternary encode and stats" {
    const values = [_]f64{ 0.5, -0.3, 0.01, 0.8, -0.02 };
    var encoded: [5]i2 = undefined;
    ternaryEncode(&values, 0.1, &encoded);

    const stats = ternaryStats(&encoded);
    try std.testing.expectEqual(@as(usize, 2), stats.pos);
    try std.testing.expectEqual(@as(usize, 1), stats.neg);
    try std.testing.expectEqual(@as(usize, 2), stats.zero);
}
