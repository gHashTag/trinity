// @origin(manual) @regen(pending)
// T-JEPA — MSE Loss + Anti-Collapse Mechanisms
// L2-normalized MSE on predicted vs target representations
// Collapse monitoring via representation variance
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// L2 NORMALIZATION (CRITICAL anti-collapse for ternary JEPA)
// ═══════════════════════════════════════════════════════════════════════════════

/// Normalize vector to unit length: vec = vec / ||vec||
/// Without this, ternary JEPA WILL collapse to constant vector
pub fn l2Normalize(vec: []f32, dim: usize) void {
    std.debug.assert(vec.len >= dim);
    var norm_sq: f64 = 0.0;
    for (vec[0..dim]) |v| {
        norm_sq += @as(f64, v) * @as(f64, v);
    }
    const norm: f32 = @floatCast(@sqrt(norm_sq + 1e-8));
    const inv_norm = 1.0 / norm;
    for (vec[0..dim]) |*v| {
        v.* *= inv_norm;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MSE LOSS
// ═══════════════════════════════════════════════════════════════════════════════

/// Forward MSE: L = (1/N) * sum_i ||pred_i - target_i||^2
/// Caller must L2-normalize both predicted and target before calling
pub fn forwardMse(predicted: []const f32, target: []const f32, count: usize, dim: usize) f32 {
    std.debug.assert(predicted.len >= count * dim);
    std.debug.assert(target.len >= count * dim);
    if (count == 0) return 0.0;

    var total: f64 = 0.0;
    for (0..count * dim) |i| {
        const diff = @as(f64, predicted[i]) - @as(f64, target[i]);
        total += diff * diff;
    }
    return @floatCast(total / @as(f64, @floatFromInt(count)));
}

/// Backward MSE: dL/d(pred_i) = 2 * (pred_i - target_i) / N
/// Target gets ZERO gradient (stop-gradient in JEPA)
pub fn backwardMse(predicted: []const f32, target: []const f32, grad_out: []f32, count: usize, dim: usize) void {
    std.debug.assert(predicted.len >= count * dim);
    std.debug.assert(target.len >= count * dim);
    std.debug.assert(grad_out.len >= count * dim);
    if (count == 0) return;

    const scale = 2.0 / @as(f32, @floatFromInt(count));
    for (0..count * dim) |i| {
        grad_out[i] = (predicted[i] - target[i]) * scale;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLLAPSE MONITORING
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute average per-dimension standard deviation across representations
/// Returns ~0 if all representations are identical (collapse detected)
pub fn representationVariance(reps: []const f32, count: usize, dim: usize) f32 {
    if (count <= 1) return 0.0;
    std.debug.assert(reps.len >= count * dim);

    var total_std: f64 = 0.0;

    for (0..dim) |d| {
        // Compute mean for this dimension
        var mean: f64 = 0.0;
        for (0..count) |i| {
            mean += @as(f64, reps[i * dim + d]);
        }
        mean /= @as(f64, @floatFromInt(count));

        // Compute variance
        var var_sum: f64 = 0.0;
        for (0..count) |i| {
            const diff = @as(f64, reps[i * dim + d]) - mean;
            var_sum += diff * diff;
        }
        total_std += @sqrt(var_sum / @as(f64, @floatFromInt(count)));
    }

    return @floatCast(total_std / @as(f64, @floatFromInt(dim)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "mse zero for identical" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const loss = forwardMse(&a, &a, 2, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), loss, 1e-7);
}

test "mse positive for different" {
    const pred = [_]f32{ 1.0, 0.0, 0.0 };
    const targ = [_]f32{ 0.0, 1.0, 0.0 };
    const loss = forwardMse(&pred, &targ, 1, 3);
    // (1-0)^2 + (0-1)^2 + (0-0)^2 = 2.0, / 1 count = 2.0
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), loss, 1e-5);
}

test "mse backward direction" {
    const pred = [_]f32{ 1.0, 0.0 };
    const targ = [_]f32{ 0.0, 1.0 };
    var grad: [2]f32 = undefined;
    backwardMse(&pred, &targ, &grad, 1, 2);
    // grad = 2*(pred-targ)/1 = [2.0, -2.0]
    // Gradient should point from pred toward target (negative = move toward target)
    try std.testing.expect(grad[0] > 0.0); // pred > targ, grad positive (push down)
    try std.testing.expect(grad[1] < 0.0); // pred < targ, grad negative (push up)
}

test "variance detects collapse" {
    // All identical reps → variance ≈ 0
    const collapsed = [_]f32{ 1.0, 2.0, 3.0, 1.0, 2.0, 3.0, 1.0, 2.0, 3.0 };
    const v = representationVariance(&collapsed, 3, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 1e-7);

    // Different reps → variance > 0
    const varied = [_]f32{ 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 };
    const v2 = representationVariance(&varied, 3, 3);
    try std.testing.expect(v2 > 0.1);
}

test "l2 normalize unit length" {
    var vec = [_]f32{ 3.0, 4.0 };
    l2Normalize(&vec, 2);
    // ||vec|| should be ≈ 1.0
    const norm = @sqrt(vec[0] * vec[0] + vec[1] * vec[1]);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), norm, 1e-5);
    // 3/5 = 0.6, 4/5 = 0.8
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), vec[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), vec[1], 1e-5);
}
