// HSLM — Trit-wise Attention Weights (Session 35 Quick Win #4)
// Replace float32 attention weights with ternary {-1,0,+1} + per-position scales
// Expected: 3× memory reduction with ~2% PPL impact
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const math = std.math;
const constants = @import("constants.zig");

const EMBED_DIM = constants.EMBED_DIM; // 243
const NUM_HEADS = constants.NUM_HEADS; // 3
const HEAD_DIM = constants.HEAD_DIM; // 81
const CONTEXT_LEN = constants.CONTEXT_LEN; // 81

const PHI_INV: f32 = 0.618033988749895; // φ⁻¹
const SACRED_GAMMA: f64 = constants.SACRED_GAMMA; // φ⁻³ ≈ 0.236

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT-WISE ATTENTION WEIGHTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit-wise attention weights with per-position scale factors
/// Memory layout: weights (ternary) + scales (float32)
/// Original: [NUM_HEADS × CONTEXT_LEN] f32 = 3 × 81 × 4 = 972 bytes
/// Optimized: [NUM_HEADS × CONTEXT_LEN] i8 + [NUM_HEADS × CONTEXT_LEN] f32 = 243 + 972 = 1215 bytes
/// Wait, that's not right. Let me recalculate:
/// Original: 3 × 81 × 4 = 972 bytes
/// Optimized: 3 × 81 × 1 (ternary) + 3 × 81 × 4 (scales) = 243 + 972 = 1215 bytes
///
/// Better approach: Store scales per-head only (not per-position)
/// Optimized: [NUM_HEADS × CONTEXT_LEN] i8 + [NUM_HEADS] f32 = 243 + 12 = 255 bytes
/// Memory reduction: 972 → 255 = 3.8× reduction!
pub const TritAttentionWeights = struct {
    // Ternary weights: {-1, 0, +1} for each (head, position) pair
    weights: [NUM_HEADS * CONTEXT_LEN]i8,

    // Per-head scale factors (preserve magnitude information)
    // Computed as: scale_h = mean(|weights_h|) for head h
    scales: [NUM_HEADS]f32,

    // φ-threshold for quantization (default: φ⁻² = 0.382)
    quantization_threshold: f32 = 0.382,

    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize with zero weights and unit scales
    pub fn init(allocator: std.mem.Allocator) !Self {
        var weights: [NUM_HEADS * CONTEXT_LEN]i8 = undefined;
        @memset(&weights, 0);

        var scales: [NUM_HEADS]f32 = undefined;
        @memset(&scales, 1.0);

        return Self{
            .weights = weights,
            .scales = scales,
            .quantization_threshold = 0.382,
            .allocator = allocator,
        };
    }

    /// Quantize float32 attention scores to ternary weights
    /// Computes per-head scale factors to preserve magnitude information
    pub fn quantizeFromFloat(self: *TritAttentionWeights, float_weights: []const f32, num_heads: usize, seq_len: usize) void {
        std.debug.assert(float_weights.len == num_heads * seq_len);

        // Quantize to ternary and compute per-head scales
        for (0..num_heads) |h| {
            const head_offset = h * seq_len;

            // Step 1: Compute scale for this head (mean of absolute values)
            var abs_sum: f32 = 0.0;
            for (0..seq_len) |pos| {
                abs_sum += @abs(float_weights[head_offset + pos]);
            }
            self.scales[h] = if (abs_sum > 1e-6)
                @max(0.1, abs_sum / @as(f32, @floatFromInt(seq_len)))
            else
                1.0;

            // Step 2: Quantize to ternary {-1, 0, +1}
            const scale_h = self.scales[h];
            for (0..seq_len) |pos| {
                const val = float_weights[head_offset + pos];
                const scaled = val / scale_h;

                // φ-adaptive threshold (slightly tighter than 0.5)
                const thr = self.quantization_threshold;

                self.weights[head_offset + pos] = if (scaled > thr)
                    1
                else if (scaled < -thr)
                    -1
                else
                    0;
            }
        }
    }

    /// Reconstruct float weights from ternary + scales (for backward compatibility)
    pub fn reconstructToFloat(self: *const TritAttentionWeights, output: []f32, num_heads: usize, seq_len: usize) void {
        std.debug.assert(output.len == num_heads * seq_len);

        for (0..num_heads) |h| {
            const head_offset = h * seq_len;
            const scale_h = self.scales[h];

            for (0..seq_len) |pos| {
                const trit = self.weights[head_offset + pos];
                output[head_offset + pos] = @as(f32, @floatFromInt(trit)) * scale_h;
            }
        }
    }

    /// Compute per-head entropy (for analysis/debugging)
    pub fn headEntropy(self: *const TritAttentionWeights, head: usize) f32 {
        const head_offset = head * CONTEXT_LEN;

        var counts: [3]usize = .{ 0, 0, 0 }; // -1, 0, +1
        for (0..CONTEXT_LEN) |pos| {
            const trit = self.weights[head_offset + pos];
            // Map {-1, 0, +1} to {0, 1, 2}
            const idx: usize = if (trit < 0) 0 else if (trit > 0) 2 else 1;
            counts[idx] += 1;
        }

        const total: f32 = @floatFromInt(CONTEXT_LEN);
        var entropy: f32 = 0.0;
        for (counts) |count| {
            if (count > 0) {
                const p = @as(f32, @floatFromInt(count)) / total;
                if (p > 1e-6) {
                    entropy -= p * @log(p);
                }
            }
        }

        return entropy;
    }

    /// Compute sparsity (fraction of zero weights)
    pub fn sparsity(self: *const TritAttentionWeights, head: usize) f32 {
        const head_offset = head * CONTEXT_LEN;
        var zero_count: usize = 0;

        for (0..CONTEXT_LEN) |pos| {
            if (self.weights[head_offset + pos] == 0) zero_count += 1;
        }

        return @as(f32, @floatFromInt(zero_count)) / @as(f32, @floatFromInt(CONTEXT_LEN));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "trit attention: quantization preserves sparsity pattern" {
    const allocator = std.testing.allocator;
    var trit_attn = try TritAttentionWeights.init(allocator);

    // Create float weights with known pattern
    var float_weights: [3 * 10]f32 = undefined;
    {
        var i: usize = 0;
        // Head 0: strong positive values (will quantize to +1)
        for (0..10) |_| {
            float_weights[i] = 1.0;
            i += 1;
        }
        // Head 1: strong negative values (will quantize to -1)
        for (0..10) |_| {
            float_weights[i] = -1.0;
            i += 1;
        }
        // Head 2: weak values (will quantize to 0)
        for (0..10) |_| {
            float_weights[i] = 0.05;
            i += 1;
        }
    }

    trit_attn.quantizeFromFloat(&float_weights, 3, 10);

    // Head 2 should be highly sparse (weak values → zeros)
    const sparsity_h2 = trit_attn.sparsity(2);
    try std.testing.expect(sparsity_h2 > 0.5); // At least 50% sparse

    // Head 0 should be mostly non-zero (strong values → +1)
    const sparsity_h0 = trit_attn.sparsity(0);
    try std.testing.expect(sparsity_h0 < 0.5); // Less than 50% sparse (i.e., mostly active)
}

test "trit attention: reconstruction is consistent" {
    const allocator = std.testing.allocator;
    var trit_attn = try TritAttentionWeights.init(allocator);

    // Create simple float weights (all same value per head)
    var float_weights: [3 * 5]f32 = undefined;
    {
        var i: usize = 0;
        // Head 0: all positive
        for (0..5) |_| {
            float_weights[i] = 1.0;
            i += 1;
        }
        // Head 1: all negative
        for (0..5) |_| {
            float_weights[i] = -1.0;
            i += 1;
        }
        // Head 2: all weak
        for (0..5) |_| {
            float_weights[i] = 0.05;
            i += 1;
        }
    }

    trit_attn.quantizeFromFloat(&float_weights, 3, 5);

    // Reconstruct
    var reconstructed: [3 * 5]f32 = undefined;
    trit_attn.reconstructToFloat(&reconstructed, 3, 5);

    // Check Head 0: all positive values
    for (0..5) |pos| {
        try std.testing.expect(reconstructed[pos] > 0);
    }

    // Check Head 1: all negative values
    for (0..5) |pos| {
        try std.testing.expect(reconstructed[5 + pos] < 0);
    }

    // Check Head 2: mostly zeros (weak values → 0)
    var h2_zeros: usize = 0;
    for (0..5) |pos| {
        if (reconstructed[10 + pos] == 0) h2_zeros += 1;
    }
    try std.testing.expect(h2_zeros >= 3); // At least 3 out of 5 are zeros
}

test "trit attention: entropy is bounded" {
    const allocator = std.testing.allocator;
    var trit_attn = try TritAttentionWeights.init(allocator);

    // Maximum entropy: uniform distribution (-1, 0, +1 each occur 1/3)
    // H_max = -3 × (1/3) × log(1/3) ≈ 1.099

    // Random float weights → quantize → check entropy
    var float_weights: [3 * 81]f32 = undefined;
    {
        var prng = std.Random.DefaultPrng.init(12345);
        const rng = prng.random();
        for (&float_weights) |*w| w.* = rng.float(f32) * 2.0 - 1.0;
    }

    trit_attn.quantizeFromFloat(&float_weights, 3, 81);

    // Check entropy is reasonable [0, H_max]
    const h0 = trit_attn.headEntropy(0);
    const h1 = trit_attn.headEntropy(1);
    const h2 = trit_attn.headEntropy(2);

    try std.testing.expect(h0 >= 0.0 and h0 <= 1.2);
    try std.testing.expect(h1 >= 0.0 and h1 <= 1.2);
    try std.testing.expect(h2 >= 0.0 and h2 <= 1.2);
}

test "trit attention: scales are positive" {
    const allocator = std.testing.allocator;
    var trit_attn = try TritAttentionWeights.init(allocator);

    // Random weights
    var float_weights: [3 * 10]f32 = undefined;
    {
        var prng = std.Random.DefaultPrng.init(54321);
        const rng = prng.random();
        for (&float_weights) |*w| w.* = rng.float(f32) * 2.0 - 1.0;
    }

    trit_attn.quantizeFromFloat(&float_weights, 3, 10);

    // All scales should be positive
    for (trit_attn.scales) |scale| {
        try std.testing.expect(scale > 0.0);
    }
}

test "trit attention: phi-threshold produces correct sparsity" {
    const allocator = std.testing.allocator;
    var trit_attn = try TritAttentionWeights.init(allocator);
    trit_attn.quantization_threshold = 0.382; // φ⁻²

    // Create float weights: some above, some below threshold
    var float_weights: [1 * 10]f32 = undefined;
    {
        var i: usize = 0;
        for (0..10) |pos| {
            // First 5: 0.1 (below threshold), Last 5: 1.0 (above threshold)
            float_weights[i] = if (pos < 5) 0.1 else 1.0;
            i += 1;
        }
    }

    trit_attn.quantizeFromFloat(&float_weights, 1, 10);

    // Check: weak values → 0, strong values → +1
    var zero_count: usize = 0;
    var one_count: usize = 0;
    for (0..10) |pos| {
        if (trit_attn.weights[pos] == 0) zero_count += 1;
        if (trit_attn.weights[pos] == 1) one_count += 1;
    }

    // Should have 5 zeros and 5 ones
    try std.testing.expect(zero_count == 5);
    try std.testing.expect(one_count == 5);
}

test "trit attention: reconstruction with zero input" {
    const allocator = std.testing.allocator;
    var trit_attn = try TritAttentionWeights.init(allocator);

    // Zero input → all weights zero → scales = 1.0
    var float_weights: [3 * 10]f32 = [_]f32{0.0} ** 30;

    trit_attn.quantizeFromFloat(&float_weights, 3, 10);

    // All scales should be 1.0 (minimum)
    for (trit_attn.scales) |scale| {
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), scale, 1e-6);
    }

    // All weights should be 0
    for (trit_attn.weights) |w| {
        try std.testing.expect(w == 0);
    }
}
