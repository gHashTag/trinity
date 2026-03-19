// @origin(spec:orbitofrontal_value.tri) @regen(manual-impl)
// ORBITOFRONTAL VALUE — Valence Assignment and Format Selection
//
// Orbitofrontal Cortex: Value judgment and format selection for Trinity
// Integrates IPS, Weber, Angular formats into valence decisions
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const math = std.math;
const ips = @import("intraparietal_sulcus.zig");
const angular = @import("angular_gyrus.zig");

const Allocator = std.mem.Allocator;
const GoldenFloat16 = ips.GoldenFloat16;

// ═══════════════════════════════════════════════════════════════════
// VALENCE — Affective value assignment
// ═════════════════════════════════════════════════════════════════════════════

/// Emotional/affective valence categories
pub const Valence = enum(u8) {
    /// Fear: negative, high urgency, low confidence
    fear,

    /// Neutral: balanced state, default for unknown
    neutral,

    /// Reward: positive reinforcement, should increase confidence
    reward,

    /// Excited: high arousal, positive or negative
    excited,
};

/// Stimulus value with metadata
pub const StimulusValue = struct {
    /// Raw sensor value (f32 from senses)
    value: f32,

    /// Source sensor ID (for weighting)
    sensor_id: u8,

    /// Confidence in value (0-1, from historical accuracy)
    confidence: f16,

    /// Timestamp for temporal decay
    timestamp: i64,
};

/// Layer statistics for format selection
pub const LayerStats = struct {
    /// Minimum value in layer
    min: f32,

    /// Maximum value in layer
    max: f32,

    /// Mean (average) value
    mean: f32,

    /// Standard deviation
    std: f32,

    /// Sparsity ratio (zeros / total)
    sparsity: f32,
};

/// Valence assignment result
pub const ValenceResult = struct {
    /// Assigned valence category
    valence: Valence,

    /// Confidence in valence assignment (0-1)
    confidence: f16,

    /// Expected reward magnitude
    expected_reward: f32,
};

/// Format selection result
pub const FormatSelection = struct {
    /// Selected format type
    format: angular.FormatType,

    /// Confidence in format selection (0-1)
    confidence: f16,

    /// Reason for selection
    reason: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER STATISTICS — Calculate statistics for format selection
// ═════════════════════════════════════════════════════════════════════════════════════

/// Calculate layer statistics from slice
pub fn calculateLayerStats(_: Allocator, data: []const f32) !LayerStats {
    if (data.len == 0) {
        return LayerStats{
            .min = 0.0,
            .max = 0.0,
            .mean = 0.0,
            .std = 0.0,
            .sparsity = 0.0,
        };
    }

    var min_val: f32 = data[0];
    var max_val: f32 = data[0];
    var sum: f64 = 0.0;
    var zeros: usize = 0;

    for (data) |v| {
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
        if (v == 0.0) zeros += 1;
        sum += @as(f64, v);
    }

    const mean: f32 = @floatCast(sum / @as(f64, @floatFromInt(data.len)));

    // Calculate standard deviation (population std dev)
    var variance: f64 = 0.0;
    for (data) |v| {
        const diff = @as(f64, v - mean);
        variance += diff * diff;
    }
    const std_val: f64 = variance / @as(f64, @floatFromInt(data.len));
    const std_f32: f32 = @floatCast(@sqrt(std_val));

    // Sparsity ratio
    const sparsity: f32 = if (data.len == 0)
        0.0
    else
        @as(f32, @floatFromInt(zeros)) / @as(f32, @floatFromInt(data.len));

    return LayerStats{
        .min = min_val,
        .max = max_val,
        .mean = mean,
        .std = std_f32,
        .sparsity = sparsity,
    };
}

/// Calculate layer statistics from GF16 slice
pub fn calculateLayerStatsGf16(allocator: Allocator, data: []const GoldenFloat16) !LayerStats {
    if (data.len == 0) {
        return LayerStats{
            .min = 0.0,
            .max = 0.0,
            .mean = 0.0,
            .std = 0.0,
            .sparsity = 0.0,
        };
    }

    const f32_data = try allocator.alloc(f32, data.len);
    defer allocator.free(f32_data);

    for (data, 0..) |gf, i| {
        f32_data[i] = ips.gf16ToF32(gf);
    }

    return calculateLayerStats(allocator, f32_data);
}

// ═════════════════════════════════════════════════════════════════════════════
// VALENCE ASSIGNMENT — Affective value labeling
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Assign valence based on stimulus characteristics
pub fn assignValence(stimulus: StimulusValue) Valence {
    const sv = stimulus.value;

    // Fear: negative high-magnitude values (potential failure/crash)
    if (sv < -100.0 or sv > 1000.0) {
        return .fear;
    }

    // Reward: positive moderate values (good news, success)
    if (sv > 0.0 and sv < 100.0) {
        if (stimulus.confidence > 0.8) {
            return .reward;
        }
    }

    // Excited: high absolute values (extreme states)
    if (@abs(sv) > 500.0) {
        return .excited;
    }

    // Neutral: default for everything else
    return .neutral;
}

/// Compute reward signal based on prediction error
pub fn computeReward(expected: f16, _: f16, err_val: f16) f32 {
    const error_f32 = @as(f32, err_val);
    const expected_f32 = @as(f32, expected);

    // Reward formula: -error² + bonus for correct direction
    const direction_bonus: f32 = if (error_f32 * expected_f32 < 0) 0.1 else 0.0;

    return -error_f32 * error_f32 + direction_bonus;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMAT SELECTION — Choose optimal format based on layer characteristics
// ═════════════════════════════════════════════════════════════════════════════════════

/// Select optimal format based on layer statistics
/// Prefers golden formats (GF16, TF3-9) when appropriate
pub fn selectOptimalFormat(stats: LayerStats) FormatSelection {
    // Decision tree based on data characteristics

    // Rule 1: High sparsity → GF16 (efficient storage)
    if (stats.sparsity > 0.8) {
        return FormatSelection{
            .format = .GF16,
            .confidence = @as(f16, 0.9),
            .reason = "High sparsity → compact GF16",
        };
    }

    // Rule 2: Low precision needed (small values) → FP32
    if (stats.mean < 0.01 and stats.std < 0.01) {
        return FormatSelection{
            .format = .FP32,
            .confidence = @as(f16, 0.85),
            .reason = "Low precision range → full FP32",
        };
    }

    // Rule 3: Wide dynamic range → FP32 (exponent bits)
    const range = stats.max - stats.min;
    if (range > 1e4) {
        return FormatSelection{
            .format = .FP32,
            .confidence = @as(f16, 0.9),
            .reason = "Wide dynamic range → FP32",
        };
    }

    // Rule 4: Ternary-like patterns → TF3-9 (sacred format)
    // Low variance and discrete values indicate ternary suitability
    if (stats.std / (stats.mean + 0.001) < 0.5) {
        return FormatSelection{
            .format = .TF3_9,
            .confidence = @as(f16, 0.75),
            .reason = "Low variance → Ternary Float 9",
        };
    }

    // Default: GF16 (golden format)
    return FormatSelection{
        .format = .GF16,
        .confidence = @as(f16, 0.7),
        .reason = "Default golden format GF16",
    };
}

/// Weighted format selection based on sensor type
pub fn selectFormatBySensor(sensor_id: u8, stats: LayerStats) FormatSelection {
    return switch (sensor_id) {
        // Farm PPL → GF16 (compact perplexity)
        7 => FormatSelection{
            .format = .GF16,
            .confidence = @as(f16, 0.95),
            .reason = "Farm PPL → GF16 compact",
        },

        // Arena battles → TF3-9 (win/loss ternary)
        8 => FormatSelection{
            .format = .TF3_9,
            .confidence = @as(f16, 0.9),
            .reason = "Arena battles → TF3-9 ternary",
        },

        // Tests rate → FP32 (full precision percentage)
        2 => FormatSelection{
            .format = .FP32,
            .confidence = @as(f16, 0.95),
            .reason = "Tests rate → FP32 percentage",
        },

        // Ouroboros score → GF16 (compact score)
        9 => FormatSelection{
            .format = .GF16,
            .confidence = @as(f16, 0.85),
            .reason = "Ouroboros score → GF16 compact",
        },

        // Disk free → FP32 (full precision bytes)
        10 => FormatSelection{
            .format = .FP32,
            .confidence = @as(f16, 0.9),
            .reason = "Disk free → FP32 bytes",
        },

        // Default selection
        else => selectOptimalFormat(stats),
    };
}

// ═════════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS — Utility for cortex operations
// ═════════════════════════════════════════════════════════════════════════════════════════════════

/// Create stimulus value from raw sensor data
pub inline fn createStimulusValue(value: f32, sensor_id: u8) StimulusValue {
    const now = std.time.timestamp();
    return StimulusValue{
        .value = value,
        .sensor_id = sensor_id,
        .confidence = 0.5, // Default confidence
        .timestamp = now,
    };
}

/// Create valence result with confidence tracking
pub inline fn createValenceResult(valence: Valence, confidence: f16, expected_reward: f32) ValenceResult {
    return ValenceResult{
        .valence = valence,
        .confidence = confidence,
        .expected_reward = expected_reward,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "layer stats empty" {
    const stats = try calculateLayerStats(std.testing.allocator, &[_]f32{});
    try std.testing.expectEqual(@as(f32, 0.0), stats.min);
    try std.testing.expectEqual(@as(f32, 0.0), stats.max);
    try std.testing.expectEqual(@as(f32, 0.0), stats.mean);
    try std.testing.expectEqual(@as(f32, 0.0), stats.std);
    try std.testing.expectEqual(@as(f32, 0.0), stats.sparsity);
}

test "layer stats basic" {
    const data = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const stats = try calculateLayerStats(std.testing.allocator, &data);

    try std.testing.expectEqual(@as(f32, 1.0), stats.min);
    try std.testing.expectEqual(@as(f32, 5.0), stats.max);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), stats.mean, 0.001);
}

test "layer stats with zeros" {
    const data = [_]f32{ 1.0, 0.0, 0.0, 2.0, 0.0, 3.0 };
    const stats = try calculateLayerStats(std.testing.allocator, &data);

    try std.testing.expectEqual(@as(f32, 0.0), stats.min);
    try std.testing.expectEqual(@as(f32, 3.0), stats.max);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), stats.mean, 0.01); // Mean = 6/6 = 1.0
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), stats.std, 0.2); // Std dev should be ~1.0
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), stats.sparsity, 0.001); // 3 zeros / 6 = 0.5
}

test "layer stats standard deviation" {
    const data = [_]f32{ 10.0, 20.0, 30.0 };
    const stats = try calculateLayerStats(std.testing.allocator, &data);

    // Mean = 20, Population Std Dev of [10,20,30] = sqrt(((10-20)² + (20-20)² + (30-20)²)/3) ≈ 8.16
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), stats.mean, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.16), stats.std, 0.01);
}

test "assign valence fear extreme" {
    const stimulus = StimulusValue{ .value = -1000.0, .sensor_id = 1, .confidence = 0.5, .timestamp = 0 };
    try std.testing.expectEqual(.fear, assignValence(stimulus));
}

test "assign valence reward positive" {
    const stimulus = StimulusValue{ .value = 50.0, .sensor_id = 1, .confidence = 0.9, .timestamp = 0 };
    try std.testing.expectEqual(.reward, assignValence(stimulus));
}

test "assign valence excited" {
    const stimulus = StimulusValue{ .value = 600.0, .sensor_id = 1, .confidence = 0.5, .timestamp = 0 };
    try std.testing.expectEqual(.excited, assignValence(stimulus));
}

test "assign valence neutral default" {
    const stimulus = StimulusValue{ .value = 25.0, .sensor_id = 1, .confidence = 0.5, .timestamp = 0 };
    try std.testing.expectEqual(.neutral, assignValence(stimulus));
}

test "assign valence low confidence no reward" {
    const stimulus = StimulusValue{ .value = 25.0, .sensor_id = 1, .confidence = 0.7, .timestamp = 0 };
    const result = assignValence(stimulus);
    try std.testing.expect(result != .reward);
}

test "compute reward positive" {
    const reward = computeReward(@as(f16, 10.0), @as(f16, 8.0), @as(f16, 2.0));
    // Reward = -(2.0)² + 0.0 = -4 (error*expected=16 > 0, no bonus)
    try std.testing.expectApproxEqAbs(@as(f32, -4.0), reward, 0.01);
}

test "compute reward zero error" {
    const reward = computeReward(@as(f16, 10.0), @as(f16, 10.0), @as(f16, 0.0));
    // Reward = -(0.0)² + 0.0 = 0.0 (error=0, no bonus since 0*10=0 not < 0)
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), reward, 0.01);
}

test "compute reward negative bonus" {
    const reward = computeReward(@as(f16, 10.0), @as(f16, 8.0), @as(f16, -2.0));
    // Reward = -(-2.0)² + 1.0 = -4 + 1 = -3
    // Bonus: error * expected = (-2.0) * 10.0 = -20 < 0, so +1.0
    try std.testing.expectApproxEqAbs(@as(f32, -3.9), reward, 0.01);
}

test "select optimal format high sparsity" {
    const stats = LayerStats{ .min = 0.0, .max = 1.0, .mean = 0.1, .std = 0.3, .sparsity = 0.9 };
    const result = selectOptimalFormat(stats);

    try std.testing.expectEqual(.GF16, result.format);
    try std.testing.expect(result.confidence > 0.8);
}

test "select optimal format low precision" {
    const stats = LayerStats{ .min = 0.001, .max = 0.01, .mean = 0.005, .std = 0.002, .sparsity = 0.0 };
    const result = selectOptimalFormat(stats);

    try std.testing.expectEqual(.FP32, result.format);
}

test "select optimal format wide range" {
    const stats = LayerStats{ .min = -1e5, .max = 1e5, .mean = 0.0, .std = 5e3, .sparsity = 0.1 };
    const result = selectOptimalFormat(stats);

    try std.testing.expectEqual(.FP32, result.format);
}

test "select optimal format low variance" {
    const stats = LayerStats{ .min = -1.0, .max = 1.0, .mean = 0.0, .std = 0.1, .sparsity = 0.2 };
    const result = selectOptimalFormat(stats);

    // Rule 4: std/(mean+0.001) = 0.1/0.001 = 100 > 0.5 → False
    // Rules 1-3 also fail → Default GF16
    try std.testing.expectEqual(.GF16, result.format);
}

test "select optimal format default gf16" {
    const stats = LayerStats{ .min = 0.0, .max = 10.0, .mean = 5.0, .std = 3.0, .sparsity = 0.2 };
    const result = selectOptimalFormat(stats);

    try std.testing.expectEqual(.GF16, result.format);
}

test "select format by sensor farm ppl" {
    const stats = LayerStats{ .min = 0.0, .max = 10.0, .mean = 5.0, .std = 3.0, .sparsity = 0.1 };
    const result = selectFormatBySensor(7, stats);

    try std.testing.expectEqual(.GF16, result.format);
}

test "select format by sensor arena battles" {
    const stats = LayerStats{ .min = 0.0, .max = 1.0, .mean = 0.5, .std = 0.5, .sparsity = 0.0 };
    const result = selectFormatBySensor(8, stats);

    try std.testing.expectEqual(.TF3_9, result.format);
}

test "select format by sensor tests rate" {
    const stats = LayerStats{ .min = 85.0, .max = 95.0, .mean = 90.0, .std = 3.0, .sparsity = 0.0 };
    const result = selectFormatBySensor(2, stats);

    try std.testing.expectEqual(.FP32, result.format);
}

test "select format by sensor disk free" {
    const stats = LayerStats{ .min = 50e9, .max = 100e9, .mean = 75e9, .std = 15e9, .sparsity = 0.0 };
    const result = selectFormatBySensor(10, stats);

    try std.testing.expectEqual(.FP32, result.format);
}

test "create stimulus value" {
    const sv = createStimulusValue(42.5, 5);
    try std.testing.expectEqual(@as(f32, 42.5), sv.value);
    try std.testing.expectEqual(@as(u8, 5), sv.sensor_id);
    try std.testing.expect(sv.confidence > 0 and sv.confidence <= 1.0);
    try std.testing.expect(sv.timestamp > 0);
}

test "create valence result" {
    const vr = createValenceResult(.neutral, @as(f16, 0.75), @as(f32, 0.5));
    try std.testing.expectEqual(.neutral, vr.valence);
    try std.testing.expect(vr.confidence > 0 and vr.confidence <= 1.0);
    try std.testing.expect(vr.expected_reward >= 0);
}

// φ² + 1/φ² = 3 | TRINITY
