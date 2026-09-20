const std = @import("std");
const tc = @import("trinity_constants.zig");

pub const EncoderLayers: u32 = 6;
pub const PredictorLayers: u32 = 3;
pub const PhiSplit: f64 = @as(f64, @floatFromInt(EncoderLayers)) / @as(f64, @floatFromInt(EncoderLayers + PredictorLayers));

pub fn encoderParams() u64 {
    const embed_params = @as(u64, tc.VOCAB) * tc.D_MODEL;
    const per_layer = 4 * @as(u64, tc.D_MODEL) * tc.D_MODEL + 2 * @as(u64, tc.D_MODEL) * tc.D_FFN + 4 * tc.D_MODEL;
    return embed_params + EncoderLayers * per_layer;
}

pub fn predictorParams() u64 {
    const per_layer = 4 * @as(u64, tc.D_MODEL) * tc.D_MODEL + 2 * @as(u64, tc.D_MODEL) * tc.D_FFN + 4 * tc.D_MODEL;
    return PredictorLayers * per_layer;
}

pub fn totalParams() u64 {
    return encoderParams() + predictorParams();
}

pub fn totalBytesGF16() u64 {
    return totalParams() * 2;
}

pub fn totalMB() f64 {
    return @as(f64, @floatFromInt(totalBytesGF16())) / (1024.0 * 1024.0);
}

pub fn jepaLoss(
    pred: []const f64,
    target: []const f64,
) f64 {
    std.debug.assert(pred.len == target.len);
    var sum: f64 = 0;
    for (pred, target) |p, t| {
        const d = p - t;
        sum += d * d;
    }
    return sum / @as(f64, @floatFromInt(pred.len));
}

test "JEPA-T: phi split ratio" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.667), PhiSplit, 0.01);
}

test "JEPA-T: total params fit in 17MB GF16" {
    const mb = totalMB();
    try std.testing.expect(mb <= 17.0);
    try std.testing.expect(mb > 10.0);
}

test "JEPA-T: jepaLoss correct" {
    const pred = [_]f64{ 1.0, 2.0, 3.0 };
    const tgt = [_]f64{ 1.0, 2.0, 3.0 };
    const loss = jepaLoss(&pred, &tgt);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), loss, 1e-10);
}

test "JEPA-T: jepaLoss nonzero for mismatch" {
    const pred = [_]f64{ 1.0, 0.0 };
    const tgt = [_]f64{ 0.0, 1.0 };
    const loss = jepaLoss(&pred, &tgt);
    try std.testing.expect(loss > 0);
}

test "JEPA-T: encoder > predictor" {
    try std.testing.expect(encoderParams() > predictorParams());
}
