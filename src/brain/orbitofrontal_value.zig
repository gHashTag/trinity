const std = @import("std");

pub const PHI: f64 = 1.6180339887498948482;

pub const FormatDecision = enum {
    gf16,
    bf16,
    fp16,
    ternary,
};

pub const LayerAnalysis = struct {
    layer_idx: usize,
    weight_std: f64,
    weight_range: f64,
    recommended: FormatDecision,
    confidence: f64,
};

pub fn recommendFormat(weight_std: f64, weight_range: f64) FormatDecision {
    if (weight_std < 0.1) return .ternary;
    if (weight_range < 2.0 and weight_std < 0.5) return .gf16;
    if (weight_range > 100.0) return .bf16;
    return .fp16;
}

pub fn analyzeLayer(weights: []const f64, layer_idx: usize) LayerAnalysis {
    var sum: f64 = 0;
    var sum_sq: f64 = 0;
    var min_val: f64 = std.math.inf(f64);
    var max_val: f64 = -std.math.inf(f64);

    for (weights) |w| {
        sum += w;
        sum_sq += w * w;
        if (w < min_val) min_val = w;
        if (w > max_val) max_val = w;
    }

    const n: f64 = @floatFromInt(weights.len);
    const mean = sum / n;
    const variance = sum_sq / n - mean * mean;
    const std_dev = @sqrt(@max(variance, 0));
    const range = max_val - min_val;

    const recommended = recommendFormat(std_dev, range);

    var confidence: f64 = 0.5;
    switch (recommended) {
        .gf16 => confidence = 1.0 - @abs(std_dev - PHI_INV) / PHI_INV,
        .ternary => confidence = 1.0 - std_dev,
        .bf16 => confidence = @min(range / 1000.0, 0.95),
        .fp16 => confidence = 0.7,
    }

    return .{
        .layer_idx = layer_idx,
        .weight_std = std_dev,
        .weight_range = range,
        .recommended = recommended,
        .confidence = std.math.clamp(confidence, 0.0, 1.0),
    };
}

test "recommend format for small weights" {
    try std.testing.expectEqual(FormatDecision.ternary, recommendFormat(0.05, 0.3));
}

test "recommend format for medium weights" {
    try std.testing.expectEqual(FormatDecision.gf16, recommendFormat(0.3, 1.5));
}

test "recommend format for large range" {
    try std.testing.expectEqual(FormatDecision.bf16, recommendFormat(5.0, 500.0));
}

test "analyze layer" {
    const weights = [_]f64{ 0.1, 0.2, -0.1, 0.3, -0.2, 0.05 };
    const analysis = analyzeLayer(&weights, 0);
    try std.testing.expect(analysis.weight_std > 0);
    try std.testing.expect(analysis.weight_range > 0);
}
