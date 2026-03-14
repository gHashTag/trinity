// @origin(spec:phi_scaling.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — φ-Scaled Dimensions
// Golden ratio scaling for transformer architecture.
// φ = (1+√5)/2, Trinity identity: φ² + 1/φ² = 3.
// Per-depth scaling, φ× FFN expansion, 1/√3 residual, Xavier init for ternary.

const std = @import("std");

/// Golden ratio
pub const PHI: f32 = 1.6180339887;
/// 1/φ
pub const INV_PHI: f32 = 0.6180339887;
/// φ²
pub const PHI_SQ: f32 = 2.6180339887;
/// 1/φ²
pub const INV_PHI_SQ: f32 = 0.3819660113;

/// Per-depth scaling: φ^(-depth)
/// Depth 0: 1.0, Depth 1: 0.618, Depth 2: 0.382, ...
pub fn layerScale(depth: u32) f32 {
    var scale: f32 = 1.0;
    for (0..depth) |_| {
        scale *= INV_PHI;
    }
    return scale;
}

/// FFN expansion: φ× instead of 4× (round to nearest multiple of 3)
pub fn ffnExpansion(model_dim: u32) u32 {
    const expanded: f32 = @as(f32, @floatFromInt(model_dim)) * PHI;
    const rounded: u32 = @intFromFloat(@round(expanded));
    // Round to nearest multiple of 3 (ternary alignment)
    return ((rounded + 1) / 3) * 3;
}

/// Residual scaling: 1/√3
pub fn residualScale() f32 {
    return 1.0 / @sqrt(3.0);
}

/// Xavier init for ternary: target variance = 2/(fan_in + fan_out)
/// For ternary {-1,0,+1} with E[w²] = p where p = P(w≠0):
/// Set p = 2/(fan_in + fan_out) / 1.0 = 2/(fan_in + fan_out)
/// Typical: p ≈ 0.667 for balanced layers
pub fn ternaryInitProbability(fan_in: u32, fan_out: u32) f32 {
    const total: f32 = @floatFromInt(fan_in + fan_out);
    const p = 2.0 / total;
    return std.math.clamp(p, 0.1, 1.0); // Clamp to reasonable range
}

/// Generate ternary weights with Xavier-appropriate density
pub fn ternaryInit(
    weights: []i8,
    fan_in: u32,
    fan_out: u32,
    seed: u64,
) void {
    const p = ternaryInitProbability(fan_in, fan_out);
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    for (weights) |*w| {
        if (random.float(f32) < p) {
            w.* = if (random.boolean()) @as(i8, 1) else @as(i8, -1);
        } else {
            w.* = 0;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Trinity identity: φ² + 1/φ² = 3" {
    const result = PHI_SQ + INV_PHI_SQ;
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), result, 1e-5);
}

test "layerScale decreases monotonically" {
    var prev: f32 = 2.0;
    for (0..6) |depth| {
        const scale = layerScale(@intCast(depth));
        try std.testing.expect(scale < prev);
        try std.testing.expect(scale > 0.0);
        prev = scale;
    }
}

test "layerScale known values" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), layerScale(0), 1e-5);
    try std.testing.expectApproxEqAbs(INV_PHI, layerScale(1), 1e-5);
    try std.testing.expectApproxEqAbs(INV_PHI_SQ, layerScale(2), 1e-5);
}

test "ffnExpansion divisible by 3" {
    for ([_]u32{ 64, 128, 243, 256, 512 }) |dim| {
        const expanded = ffnExpansion(dim);
        try std.testing.expectEqual(@as(u32, 0), expanded % 3);
        // Should be roughly φ× the input
        const ratio = @as(f32, @floatFromInt(expanded)) / @as(f32, @floatFromInt(dim));
        try std.testing.expect(ratio > 1.4 and ratio < 1.9);
    }
}

test "residualScale = 1/√3" {
    const scale = residualScale();
    try std.testing.expectApproxEqAbs(@as(f32, 0.57735), scale, 1e-4);
}

test "ternaryInit variance approximately correct" {
    var weights: [10000]i8 = undefined;
    ternaryInit(&weights, 100, 100, 0xABCD);

    // E[w²] should be close to 2/(100+100) = 0.01 × count_nonzero
    var sum_sq: f64 = 0.0;
    for (weights) |w| {
        const wf: f64 = @floatFromInt(w);
        sum_sq += wf * wf;
    }
    const variance = sum_sq / 10000.0;
    // Should be approximately 2/200 = 0.01, but clamp ensures p >= 0.1
    // With p=0.1: ~10% non-zero, E[w²] ≈ 0.1
    try std.testing.expect(variance > 0.05 and variance < 0.2);
}
