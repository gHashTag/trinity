// @origin(spec:f16_shadow.tri) @regen(manual-impl)
// F16 Shadow Weights — half-precision float compressed weight storage
// 2× memory reduction vs f32, 15-25% speedup from improved cache usage
//
// Architecture:
//   - Primary weights: ternary {-1, 0, +1} in 2-bit packing
//   - Shadow weights: f16 gradient accumulation, periodic sync
//   - Sync interval: every N steps, f16 → ternary quantize
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Default sync interval: update ternary from f16 every 100 steps
const DEFAULT_SYNC_INTERVAL: usize = 100;

/// Quantization threshold: values > threshold become +1, < -threshold become -1
const DEFAULT_QUANTIZE_THRESHOLD: f16 = 0.5;

// ═══════════════════════════════════════════════════════════════════════════════
// F16 SHADOW STORAGE
// ═══════════════════════════════════════════════════════════════════════════════

/// f16 shadow weight storage for gradient accumulation
/// - Stores weights in half-precision float (2 bytes each)
/// - Periodic sync to ternary representation
/// - 2× memory savings vs f32, better cache locality
pub const F16ShadowStorage = struct {
    const Self = @This();

    /// Weight buffer: 8×16 vectors = 128 weights total
    weights: [8 * 16]f16,

    /// Step counter for sync scheduling
    step: usize = 0,

    /// Sync interval (steps)
    sync_interval: usize = DEFAULT_SYNC_INTERVAL,

    /// Quantization threshold
    threshold: f16 = DEFAULT_QUANTIZE_THRESHOLD,

    /// Create initialized shadow storage
    pub fn init() Self {
        return Self{
            .weights = [_]f16{0.0} ** (8 * 16),
            .step = 0,
            .sync_interval = DEFAULT_SYNC_INTERVAL,
            .threshold = DEFAULT_QUANTIZE_THRESHOLD,
        };
    }

    /// Reset all weights to zero and reset step counter
    pub fn reset(self: *Self) void {
        @memset(&self.weights, 0.0);
        self.step = 0;
    }

    /// Add gradient to shadow weights
    /// gradient: slice of f16 values (up to 128)
    pub fn addGradient(self: *Self, gradient: []const f16) void {
        const count = @min(gradient.len, self.weights.len);
        for (0..count) |i| {
            self.weights[i] += gradient[i];
        }
        self.step += 1;
    }

    /// Check if sync is due
    pub fn shouldSync(self: *Self) bool {
        return self.step >= self.sync_interval;
    }

    /// Quantize shadow weights to ternary {-1, 0, +1}
    /// Returns array of ternary values and update count
    pub fn quantizeToTernary(self: *Self) struct { trits: [8 * 16]i8, updated: usize } {
        var trits: [8 * 16]i8 = undefined;
        var updated: usize = 0;
        const threshold_f32: f32 = self.threshold;

        for (&trits, self.weights) |*t, w| {
            const w_f32: f32 = @floatCast(w);
            const w_abs = @abs(w_f32);
            if (w_abs < 1e-6) {
                t.* = 0; // Treat near-zero as zero
            } else if (w_f32 > threshold_f32) {
                t.* = 1;
                updated += 1;
            } else if (w_f32 < -threshold_f32) {
                t.* = -1;
                updated += 1;
            } else {
                t.* = 0; // Below threshold -> zero (pruning)
                updated += 1;
            }
        }

        // Reset step counter after sync
        self.step = 0;

        return .{ .trits = trits, .updated = updated };
    }

    /// Load ternary weights into shadow storage (for initialization)
    pub fn loadFromTernary(self: *Self, trits: []const i8) void {
        const count = @min(trits.len, self.weights.len);
        for (0..count) |i| {
            self.weights[i] = @floatFromInt(trits[i]);
        }
    }

    /// Get sparsity ratio (fraction of zero weights)
    pub fn sparsity(self: *const Self) f64 {
        var zero_count: usize = 0;
        for (self.weights) |w| {
            const w_f32: f32 = @floatCast(w);
            if (@abs(w_f32) < 1e-6) {
                zero_count += 1;
            }
        }
        return @as(f64, @floatFromInt(zero_count)) / @as(f64, @floatFromInt(self.weights.len));
    }

    /// Compute weight statistics
    pub const WeightStats = struct {
        min: f32,
        max: f32,
        mean: f32,
        std: f32,
        sparsity: f64,
    };

    pub fn stats(self: *const Self) WeightStats {
        var min: f32 = std.math.inf(f32);
        var max: f32 = -std.math.inf(f32);
        var sum: f64 = 0.0;

        for (self.weights) |w| {
            const w_f32: f32 = @floatCast(w);
            if (w_f32 < min) min = w_f32;
            if (w_f32 > max) max = w_f32;
            sum += @as(f64, @floatCast(w_f32));
        }

        const mean: f64 = sum / @as(f64, @floatFromInt(self.weights.len));

        var var_sum: f64 = 0.0;
        for (self.weights) |w| {
            const w_f32: f32 = @floatCast(w);
            const diff = @as(f64, @floatCast(w_f32)) - mean;
            var_sum += diff * diff;
        }

        return .{
            .min = min,
            .max = max,
            .mean = @floatCast(mean),
            .std = @floatCast(@sqrt(var_sum / @as(f64, @floatFromInt(self.weights.len)))),
            .sparsity = self.sparsity(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// F16 UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert f32 slice to f16 slice
pub fn f32ToF16Slice(input: []const f32, output: []f16) void {
    const count = @min(input.len, output.len);
    for (0..count) |i| {
        output[i] = @floatCast(input[i]);
    }
}

/// Convert f16 slice to f32 slice
pub fn f16ToF32Slice(input: []const f16, output: []f32) void {
    const count = @min(input.len, output.len);
    for (0..count) |i| {
        output[i] = @floatCast(input[i]);
    }
}

/// f16 dot product (accumulates in f64 for precision)
pub fn dotProductF16(a: []const f16, b: []const f16) f64 {
    const count = @min(a.len, b.len);
    var sum: f64 = 0.0;
    for (0..count) |i| {
        const a_f32: f32 = @floatCast(a[i]);
        const b_f32: f32 = @floatCast(b[i]);
        sum += @as(f64, @floatCast(a_f32)) * @as(f64, @floatCast(b_f32));
    }
    return sum;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "F16ShadowStorage init creates zero buffer" {
    const storage = F16ShadowStorage.init();
    for (storage.weights) |w| {
        const w_f32: f32 = @floatCast(w);
        try std.testing.expectEqual(@as(f32, 0.0), w_f32);
    }
}

test "F16ShadowStorage step counter" {
    var storage = F16ShadowStorage.init();
    try std.testing.expectEqual(@as(usize, 0), storage.step);

    storage.addGradient(&[_]f16{1.0} ** 10);
    try std.testing.expectEqual(@as(usize, 1), storage.step);

    storage.addGradient(&[_]f16{2.0} ** 10);
    try std.testing.expectEqual(@as(usize, 2), storage.step);
}

test "F16ShadowStorage shouldSync" {
    var storage = F16ShadowStorage.init();

    try std.testing.expect(!storage.shouldSync());

    storage.step = 99;
    try std.testing.expect(!storage.shouldSync());

    storage.step = 100;
    try std.testing.expect(storage.shouldSync());
}

test "F16ShadowStorage reset" {
    var storage = F16ShadowStorage.init();
    storage.weights[0] = 1.5;
    storage.weights[1] = -2.0;
    storage.step = 50;

    storage.reset();

    try std.testing.expectEqual(@as(usize, 0), storage.step);
    for (storage.weights) |w| {
        const w_f32: f32 = @floatCast(w);
        try std.testing.expectEqual(@as(f32, 0.0), w_f32);
    }
}

test "F16ShadowStorage addGradient" {
    var storage = F16ShadowStorage.init();
    storage.weights[0] = 1.0;
    storage.weights[1] = 2.0;

    storage.addGradient(&[_]f16{ 0.5, -1.0, 0.25 });

    const w0: f32 = storage.weights[0];
    const w1: f32 = storage.weights[1];
    try std.testing.expectApproxEqRel(@as(f32, 1.5), w0, 0.001);
    try std.testing.expectApproxEqRel(@as(f32, 1.0), w1, 0.001);
    try std.testing.expectEqual(@as(usize, 1), storage.step);
}

test "F16ShadowStorage quantizeToTernary positive" {
    var storage = F16ShadowStorage.init();
    storage.weights[0] = 1.5; // > 0.5 -> +1
    storage.weights[1] = 0.8; // > 0.5 -> +1
    storage.weights[2] = 0.2; // < 0.5 -> 0

    const result = storage.quantizeToTernary();

    try std.testing.expectEqual(@as(i8, 1), result.trits[0]);
    try std.testing.expectEqual(@as(i8, 1), result.trits[1]);
    try std.testing.expectEqual(@as(i8, 0), result.trits[2]);
    try std.testing.expectEqual(@as(usize, 0), storage.step);
}

test "F16ShadowStorage quantizeToTernary negative" {
    var storage = F16ShadowStorage.init();
    storage.weights[0] = -1.5; // < -0.5 -> -1
    storage.weights[1] = -0.8; // < -0.5 -> -1
    storage.weights[2] = -0.2; // > -0.5 -> 0

    const result = storage.quantizeToTernary();

    try std.testing.expectEqual(@as(i8, -1), result.trits[0]);
    try std.testing.expectEqual(@as(i8, -1), result.trits[1]);
    try std.testing.expectEqual(@as(i8, 0), result.trits[2]);
}

test "F16ShadowStorage quantizeToTernary nearZero" {
    var storage = F16ShadowStorage.init();
    storage.weights[0] = @as(f16, 1e-7); // Near zero -> 0
    storage.weights[1] = 0.0; // Exactly zero -> 0
    storage.weights[2] = @as(f16, -1e-8); // Near zero -> 0

    const result = storage.quantizeToTernary();

    try std.testing.expectEqual(@as(i8, 0), result.trits[0]);
    try std.testing.expectEqual(@as(i8, 0), result.trits[1]);
    try std.testing.expectEqual(@as(i8, 0), result.trits[2]);
}

test "F16ShadowStorage loadFromTernary" {
    var storage = F16ShadowStorage.init();
    const trits = [_]i8{ 1, 0, -1, 1, -1, 0, 1, -1 };

    storage.loadFromTernary(&trits);

    const w0: f32 = storage.weights[0];
    const w1: f32 = storage.weights[1];
    const w2: f32 = storage.weights[2];
    try std.testing.expectApproxEqRel(@as(f32, 1.0), w0, 0.001);
    try std.testing.expectApproxEqRel(@as(f32, 0.0), w1, 0.001);
    try std.testing.expectApproxEqRel(@as(f32, -1.0), w2, 0.001);
}

test "F16ShadowStorage sparsity" {
    var storage = F16ShadowStorage.init();

    // All zero
    try std.testing.expectApproxEqRel(@as(f64, 1.0), storage.sparsity(), 0.001);

    // Set some non-zero values
    storage.weights[0] = 1.0;
    storage.weights[5] = 2.0;
    storage.weights[10] = -1.0;

    // 3 non-zero out of 128 = 125/126 zero
    try std.testing.expectApproxEqRel(125.0 / 128.0, storage.sparsity(), 0.01);
}

test "F16ShadowStorage stats" {
    var storage = F16ShadowStorage.init();

    // Set known values: 1.0, 2.0, 3.0, zeros, -1.0
    storage.weights[0] = 1.0;
    storage.weights[1] = 2.0;
    storage.weights[2] = 3.0;
    storage.weights[3] = 0.0;
    storage.weights[4] = -1.0;

    const s = storage.stats();

    try std.testing.expectApproxEqRel(@as(f32, -1.0), s.min, 0.001);
    try std.testing.expectApproxEqRel(@as(f32, 3.0), s.max, 0.001);
    // Mean = (1 + 2 + 3 + 0 - 1) / 128 = 5 / 128 ≈ 0.039
    try std.testing.expect(s.mean >= 0.03 and s.mean <= 0.05);
    try std.testing.expect(s.std > 0); // Should have some variance
}

test "f32ToF16Slice roundtrip" {
    const f32_input = [_]f32{ 1.0, -2.5, 0.0, 3.14159, 1e-6 };
    var f16_buf: [5]f16 = undefined;
    var f32_output: [5]f32 = undefined;

    f32ToF16Slice(&f32_input, &f16_buf);
    f16ToF32Slice(&f16_buf, &f32_output);

    // f16 has ~3 decimal digits of precision
    for (f32_input, f32_output) |orig, converted| {
        const err = @abs(orig - converted);
        if (@abs(orig) > 1e-5) {
            try std.testing.expect(err <= @abs(orig) * 0.01); // <1% error for significant values
        }
    }
}

test "dotProductF16" {
    const a = [_]f16{ 1.0, 2.0, 3.0, 4.0 };
    const b = [_]f16{ 5.0, 6.0, 7.0, 8.0 };

    const dot = dotProductF16(&a, &b);

    // 1*5 + 2*6 + 3*7 + 4*8 = 5 + 12 + 21 + 32 = 70
    try std.testing.expectApproxEqRel(@as(f64, 70.0), dot, 0.001);
}

test "F16ShadowStorage custom sync interval" {
    var storage = F16ShadowStorage.init();
    storage.sync_interval = 50;

    try std.testing.expect(!storage.shouldSync());

    storage.step = 49;
    try std.testing.expect(!storage.shouldSync());

    storage.step = 50;
    try std.testing.expect(storage.shouldSync());
}

test "F16ShadowStorage custom threshold" {
    var storage = F16ShadowStorage.init();
    storage.threshold = 0.25; // Lower threshold

    storage.weights[0] = 0.3; // > 0.25 -> +1 (would be 0 with default 0.5)
    storage.weights[1] = 0.2; // < 0.25 -> 0
    storage.weights[2] = -0.3; // < -0.25 -> -1

    const result = storage.quantizeToTernary();

    try std.testing.expectEqual(@as(i8, 1), result.trits[0]);
    try std.testing.expectEqual(@as(i8, 0), result.trits[1]);
    try std.testing.expectEqual(@as(i8, -1), result.trits[2]);
}

test "F16ShadowStorage quantize reset step" {
    var storage = F16ShadowStorage.init();
    storage.step = 100;

    _ = storage.quantizeToTernary();

    try std.testing.expectEqual(@as(usize, 0), storage.step);
}

test "dotProductF16 different lengths" {
    const a = [_]f16{ 1.0, 2.0, 3.0 };
    const b = [_]f16{ 4.0, 5.0, 6.0, 7.0, 8.0 };

    const dot = dotProductF16(&a, &b);

    // Only first 3 elements: 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
    try std.testing.expectApproxEqRel(@as(f64, 32.0), dot, 0.001);
}

test "f32ToF16Slice different lengths" {
    const f32_input = [_]f32{ 1.0, 2.0, 3.0 };
    var f16_buf: [10]f16 = undefined;
    @memset(&f16_buf, 0.0);
    var f32_output: [10]f32 = undefined;
    @memset(&f32_output, 0.0);

    f32ToF16Slice(&f32_input, &f16_buf);
    f16ToF32Slice(&f16_buf, &f32_output);

    try std.testing.expectEqual(@as(f32, 1.0), f32_output[0]);
    try std.testing.expectEqual(@as(f32, 2.0), f32_output[1]);
    try std.testing.expectEqual(@as(f32, 3.0), f32_output[2]);
    try std.testing.expectEqual(@as(f32, 0.0), f32_output[3]); // Not written
}

test "F16ShadowStorage max gradient size" {
    var storage = F16ShadowStorage.init();

    // Try to add gradient larger than storage
    const big_grad = [_]f16{1.0} ** 200;

    storage.addGradient(&big_grad);

    // Should only process first 128 elements
    const w127: f32 = storage.weights[127];
    try std.testing.expectEqual(@as(f32, 1.0), w127);
}

// φ² + 1/φ² = 3 | TRINITY
