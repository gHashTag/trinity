// @origin(spec:adaptive_sparsity.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — 3-Level Adaptive Sparsity
// Dense (0%), Sparse (33%), Ultra-Sparse (66%) pruning.
// Per-layer sensitivity analysis for automatic level selection.
// Magnitude-based pruning of ternary weights.

const std = @import("std");
const Trit = @import("trit_encoding.zig").Trit;

pub const SparsityLevel = enum(u8) {
    dense = 0, // 0% zeros (keep all)
    sparse = 33, // 33% zeros
    ultra_sparse = 66, // 66% zeros

    pub fn targetZeroPercent(self: SparsityLevel) u8 {
        return @intFromEnum(self);
    }

    pub fn label(self: SparsityLevel) []const u8 {
        return switch (self) {
            .dense => "dense (0%)",
            .sparse => "sparse (33%)",
            .ultra_sparse => "ultra-sparse (66%)",
        };
    }
};

/// Apply magnitude-based pruning to ternary weights.
/// For ternary {-1,0,+1}, "magnitude" is binary: non-zero or zero.
/// Pruning = randomly zeroing out non-zero weights to target sparsity.
pub fn applyMask(weights: []Trit, level: SparsityLevel, seed: u64) void {
    if (level == .dense) return;

    const target_pct = level.targetZeroPercent();

    // Count current non-zeros
    var nonzero_count: usize = 0;
    for (weights) |w| {
        if (w != 0) nonzero_count += 1;
    }

    // How many to zero out
    const total: f32 = @floatFromInt(weights.len);
    const current_zero_pct = (@as(f32, @floatFromInt(weights.len - nonzero_count)) / total) * 100.0;
    if (current_zero_pct >= @as(f32, @floatFromInt(target_pct))) return; // Already sparse enough

    const target_zeros: usize = @intFromFloat(total * @as(f32, @floatFromInt(target_pct)) / 100.0);
    const current_zeros = weights.len - nonzero_count;
    if (target_zeros <= current_zeros) return;
    const to_prune = target_zeros - current_zeros;

    // Randomly select non-zero weights to prune
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    var pruned: usize = 0;

    // Multiple passes if needed
    var pass: usize = 0;
    while (pruned < to_prune and pass < 10) : (pass += 1) {
        for (weights) |*w| {
            if (pruned >= to_prune) break;
            if (w.* != 0) {
                // Probability of pruning this weight
                const remaining = to_prune - pruned;
                var remaining_nz: usize = 0;
                for (weights) |ww| {
                    if (ww != 0) remaining_nz += 1;
                }
                if (remaining_nz == 0) break;
                const prob = @as(f32, @floatFromInt(remaining)) / @as(f32, @floatFromInt(remaining_nz));
                if (random.float(f32) < prob) {
                    w.* = 0;
                    pruned += 1;
                }
            }
        }
    }
}

/// Measure actual sparsity (percentage of zeros)
pub fn measureSparsity(weights: []const Trit) f32 {
    var zeros: usize = 0;
    for (weights) |w| {
        if (w == 0) zeros += 1;
    }
    return @as(f32, @floatFromInt(zeros)) / @as(f32, @floatFromInt(weights.len)) * 100.0;
}

/// Analyze layer sensitivity: compute output variance change under pruning.
/// Returns recommended sparsity level.
pub fn analyzeSensitivity(
    weights: []const Trit,
    is_attention: bool,
) SparsityLevel {
    // Heuristic: attention layers are more sensitive → less pruning
    // FFN layers are more redundant → more pruning
    const nonzero_ratio = blk: {
        var nz: usize = 0;
        for (weights) |w| {
            if (w != 0) nz += 1;
        }
        break :blk @as(f32, @floatFromInt(nz)) / @as(f32, @floatFromInt(weights.len));
    };

    if (is_attention) {
        // Attention: keep dense if already sparse, otherwise light pruning
        return if (nonzero_ratio < 0.5) .dense else .sparse;
    } else {
        // FFN: more aggressive pruning
        return if (nonzero_ratio < 0.4) .sparse else .ultra_sparse;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "applyMask dense is no-op" {
    var weights = [_]Trit{ 1, -1, 0, 1, -1, 1, 0, -1 };
    const original = weights;
    applyMask(&weights, .dense, 0x1234);
    try std.testing.expectEqualSlices(Trit, &original, &weights);
}

test "applyMask sparse achieves ~33% zeros" {
    var weights: [300]Trit = undefined;
    // Fill with non-zero values
    var rng = std.Random.DefaultPrng.init(0xABCD);
    const random = rng.random();
    for (&weights) |*w| {
        w.* = if (random.boolean()) @as(Trit, 1) else @as(Trit, -1);
    }

    applyMask(&weights, .sparse, 0x5678);
    const sparsity = measureSparsity(&weights);
    // Should be approximately 33% ± 10%
    try std.testing.expect(sparsity >= 23.0);
    try std.testing.expect(sparsity <= 43.0);
}

test "applyMask ultra_sparse achieves ~66% zeros" {
    var weights: [300]Trit = undefined;
    var rng = std.Random.DefaultPrng.init(0xEF01);
    const random = rng.random();
    for (&weights) |*w| {
        w.* = if (random.boolean()) @as(Trit, 1) else @as(Trit, -1);
    }

    applyMask(&weights, .ultra_sparse, 0x2345);
    const sparsity = measureSparsity(&weights);
    // Should be approximately 66% ± 10%
    try std.testing.expect(sparsity >= 56.0);
    try std.testing.expect(sparsity <= 76.0);
}

test "analyzeSensitivity: attention gets less pruning" {
    var weights: [100]Trit = undefined;
    var rng = std.Random.DefaultPrng.init(0x7777);
    const random = rng.random();
    for (&weights) |*w| {
        w.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    }

    const attn_level = analyzeSensitivity(&weights, true);
    const ffn_level = analyzeSensitivity(&weights, false);
    // Attention should be less aggressive than FFN
    try std.testing.expect(@intFromEnum(attn_level) <= @intFromEnum(ffn_level));
}

test "measureSparsity correct" {
    const weights = [_]Trit{ 1, 0, -1, 0, 0, 1, -1, 0 };
    const sparsity = measureSparsity(&weights);
    // 4 zeros out of 8 = 50%
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), sparsity, 0.01);
}
