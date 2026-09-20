const std = @import("std");

pub const PHI: f64 = 1.6180339887498948482;
pub const PHI_SQ: f64 = PHI * PHI;
pub const PHI_INV: f64 = 1.0 / PHI;
pub const PHI_INV_SQ: f64 = 1.0 / PHI_SQ;
pub const TRINITY: f64 = PHI_SQ + PHI_INV_SQ;

pub const ALPHA_PHI: f64 = PHI - 1.5;

pub const FIBONACCI = [_]u32{
    1,    1,    2,    3,    5,    8,   13,   21,
    34,   55,   89,  144,  233,  377,  610,  987,
};

pub const D_MODEL: u32 = 144;
pub const N_HEADS: u32 = 8;
pub const D_HEAD: u32 = D_MODEL / N_HEADS;
pub const D_FFN: u32 = 233;
pub const N_LAYERS: u32 = 7;
pub const VOCAB: u32 = 50257;

pub const GAUGE_INIT_STD: f64 = ALPHA_PHI;
pub const HIGGS_INIT_STD: f64 = ALPHA_PHI * PHI_INV;
pub const LEPTON_INIT_STD: f64 = ALPHA_PHI * PHI_INV_SQ;
pub const COSMOLOGY_INIT_STD: f64 = ALPHA_PHI * PHI_INV * PHI_INV_SQ;

pub const LR_INIT: f64 = ALPHA_PHI;
pub const LR_WARMUP_STEPS: u32 = 21;
pub const LR_TAU: f64 = 228.9;

pub fn phiLrSchedule(step: u32, total_steps: u32) f64 {
    if (step <= LR_WARMUP_STEPS) {
        return LR_INIT * @as(f64, @floatFromInt(step)) / @as(f64, @floatFromInt(LR_WARMUP_STEPS));
    }
    const t = @as(f64, @floatFromInt(step - LR_WARMUP_STEPS)) / @as(f64, @floatFromInt(total_steps));
    return LR_INIT * std.math.pow(f64, PHI, -t / LR_TAU * @as(f64, @floatFromInt(total_steps)) / LR_TAU);
}

pub fn trinityInitStd(layer_kind: enum { gauge, higgs, lepton, cosmology }) f64 {
    return switch (layer_kind) {
        .gauge => GAUGE_INIT_STD,
        .higgs => HIGGS_INIT_STD,
        .lepton => LEPTON_INIT_STD,
        .cosmology => COSMOLOGY_INIT_STD,
    };
}

test "Trinity Identity: PHI^2 + PHI^(-2) = 3" {
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), TRINITY, 1e-12);
}

test "ALPHA_PHI = PHI - 1.5 = 0.118034" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.118033988749895), ALPHA_PHI, 1e-12);
}

test "Fibonacci: 144 * PHI = 233" {
    const result = @as(f64, @floatFromInt(FIBONACCI[11])) * PHI;
    try std.testing.expectApproxEqAbs(@as(f64, 233.0), result, 0.1);
}

test "Architecture: d_model=144, n_heads=8, d_head=18" {
    try std.testing.expectEqual(@as(u32, 144), D_MODEL);
    try std.testing.expectEqual(@as(u32, 8), N_HEADS);
    try std.testing.expectEqual(@as(u32, 18), D_HEAD);
    try std.testing.expectEqual(@as(u32, 233), D_FFN);
}

test "Trinity init stds decrease by 1/PHI" {
    try std.testing.expect(GAUGE_INIT_STD > HIGGS_INIT_STD);
    try std.testing.expect(HIGGS_INIT_STD > LEPTON_INIT_STD);
    try std.testing.expect(LEPTON_INIT_STD > COSMOLOGY_INIT_STD);
    const ratio = GAUGE_INIT_STD / HIGGS_INIT_STD;
    try std.testing.expectApproxEqAbs(PHI, ratio, 1e-10);
}

test "LR schedule: warmup then decay" {
    const lr_0 = phiLrSchedule(0, 10000);
    try std.testing.expect(lr_0 < LR_INIT);
    const lr_warmup = phiLrSchedule(LR_WARMUP_STEPS, 10000);
    try std.testing.expectApproxEqAbs(LR_INIT, lr_warmup, 1e-10);
}
