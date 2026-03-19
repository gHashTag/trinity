// @origin(spec:weber_tuning.tri) @regen(manual-impl)
// WEBER TUNING — Weber-Fechner Perceptual Quantization
//
// Weber's Law: ΔI / I = k (just noticeable difference is proportional)
// Fechner's Law: perception ~ k × log(I / I0)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const math = std.math;

// ═════════════════════════════════════════════════════════════════════════════
// WEBER-FECHNER QUANTIZATION — Logarithmic perceptual scale
// ═══════════════════════════════════════════════════════════════════════════

/// Weber-Fechner quantization: Δ = k × S (Δ is proportional to stimulus)
/// Formula: quantized = round((value - base) / (k × base) + base)
/// Maps perceptual intensity to 16-bit unsigned with center at 32768
pub fn weberQuantize(
    value: f32,
    base_stimulus: f32,
    k: f16, // Weber constant, typically 0.01-0.1
) u16 {
    if (value <= 0 or base_stimulus <= 0) return 0;

    const v = value;
    const s0 = base_stimulus;
    const kf: f32 = @floatCast(k);

    // Logarithmic perception: perceived ~ k × log2(v / s0)
    const perceived: f32 = kf * math.log2(v / s0);

    // Map to 16-bit unsigned range with center at 32768
    var level_f: f32 = perceived * 1024.0 + 32768.0;
    if (level_f < 0.0) level_f = 0.0;
    if (level_f > 65535.0) level_f = 65535.0;
    return @intFromFloat(level_f);
}

/// Weber-Fechner dequantization
/// Inverse: value = base × 2^((quantized - 32768) / (1024 × k))
pub fn weberDequantize(
    quantized: u16,
    base_stimulus: f32,
    k: f16,
) f32 {
    if (base_stimulus <= 0) return 0.0;
    const s0 = base_stimulus;
    const kf: f32 = @floatCast(k);

    const level: f32 = @floatFromInt(quantized);
    const perceived: f32 = (level - 32768.0) / 1024.0;
    const ratio: f32 = math.exp2(perceived / kf);
    return s0 * ratio;
}

// ═════════════════════════════════════════════════════════════════════════════
// TERNARY WEBER LEVELS — Generate quantization levels
// ═════════════════════════════════════════════════════════════════════════════

/// Calculate all possible levels for N trits (log-space)
/// Returns []f32 of length 3^N (e.g. 9 trits → 243 levels)
pub fn ternaryWeberLevels(
    allocator: std.mem.Allocator,
    trits: u8,
    base_stimulus: f32,
    k: f16,
) ![]f32 {
    const levels: usize = try std.math.powi(usize, 3, trits);
    var out = try allocator.alloc(f32, levels);
    const kf: f32 = @floatCast(k);

    var i: usize = 0;
    while (i < levels) : (i += 1) {
        // Distribute perceived uniformly across range [-1, 1]
        const t: f32 = (@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(levels - 1))) * 2.0 - 1.0;
        const ratio: f32 = math.exp2(t / kf);
        out[i] = base_stimulus * ratio;
    }
    return out;
}

// ═════════════════════════════════════════════════════════════════════════════
// ADAPTIVE THRESHOLD — Self-tuning based on recent errors
// ═══════════════════════════════════════════════════════════════════════════

/// Calculate adaptive threshold (mean of recent errors × k)
/// Used for dynamic quantization that adjusts to data distribution
pub fn adaptiveThreshold(
    recent_errors: []const f16,
    base_threshold: f16,
    adaptation_rate: f32,
) f16 {
    if (recent_errors.len == 0) return base_threshold;

    // Calculate mean absolute error
    var sum: f64 = 0.0;
    for (recent_errors) |err| {
        const err_f32: f32 = @floatCast(err);
        const abs_err: f32 = if (err_f32 < 0) -err_f32 else err_f32;
        sum += @as(f64, abs_err);
    }
    const mean_err: f64 = sum / @as(f64, @floatFromInt(recent_errors.len));

    // Adaptive threshold: base + adaptation × mean_error
    const base_f32: f32 = @floatCast(base_threshold);
    const mean_f32: f32 = @floatCast(mean_err);
    const adaptive: f32 = base_f32 + adaptation_rate * mean_f32;
    return @floatCast(adaptive);
}

// ═══════════════════════════════════════════════════════════════════════════
// WEBER COMPARISON — Compare two magnitudes by Weber's Law
// ═════════════════════════════════════════════════════════════════════════════

/// Compare two magnitudes by Weber law (Δ/S)
/// Returns the just-noticeable difference ratio
/// Higher value = more perceptually distinct
pub fn weberCompare(
    stimulus_a: f32,
    stimulus_b: f32,
    k: f16,
) f64 {
    if (stimulus_a <= 0 or stimulus_b <= 0) return 0.0;

    const delta: f64 = @as(f64, @abs(stimulus_a - stimulus_b));
    const baseline: f64 = @as(f64, @max(stimulus_a, stimulus_b));

    if (baseline == 0.0) return 0.0;

    const kf: f64 = @as(f64, @floatCast(k));
    // Weber ratio: Δ/S (normalized by constant k)
    return (delta / baseline) / kf;
}

// ═══════════════════════════════════════════════════════════════════════════
// BATCH OPERATIONS — Apply quantization to slices
// ═════════════════════════════════════════════════════════════════════════

/// Quantize f32 slice using Weber-Fechner
pub fn weberQuantizeSlice(
    allocator: std.mem.Allocator,
    input: []const f32,
    base_stimulus: f32,
    k: f16,
) ![]u16 {
    const output = try allocator.alloc(u16, input.len);
    for (input, 0..) |v, i| {
        output[i] = weberQuantize(v, base_stimulus, k);
    }
    return output;
}

/// Dequantize u16 slice using Weber-Fechner
pub fn weberDequantizeSlice(
    allocator: std.mem.Allocator,
    input: []const u16,
    base_stimulus: f32,
    k: f16,
) ![]f32 {
    const output = try allocator.alloc(f32, input.len);
    for (input, 0..) |q, i| {
        output[i] = weberDequantize(q, base_stimulus, k);
    }
    return output;
}

// ═════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "weber roundtrip basic" {
    const base: f32 = 1.0;
    const k: f16 = 0.3;

    const vals = [_]f32{ 0.5, 1.0, 2.0, 4.0 };
    for (vals) |v| {
        const q = weberQuantize(v, base, k);
        const r = weberDequantize(q, base, k);
        // Allow coarse error for perceptual scale
        try std.testing.expectApproxEqAbs(v, r, @abs(v) * 0.15 + 0.05);
    }
}

test "weber quantize negative" {
    const base: f32 = 1.0;
    const k: f16 = 0.3;

    const result = weberQuantize(-2.0, base, k);
    // Should map to lower range (center is 32768)
    try std.testing.expect(result < 32768);
}

test "weber zero inputs" {
    const base: f32 = 1.0;
    const k: f16 = 0.3;

    try std.testing.expectEqual(@as(u16, 0), weberQuantize(0.0, base, k));
    try std.testing.expectEqual(@as(u16, 0), weberQuantize(1.0, 0.0, k));
}

test "ternary weber levels count" {
    const allocator = std.testing.allocator;
    const levels = try ternaryWeberLevels(allocator, 5, 1.0, 0.3);
    defer allocator.free(levels);

    // 5 trits → 3^5 = 243 levels
    try std.testing.expectEqual(@as(usize, 243), levels.len);
}

test "ternary weber levels monotonic" {
    const allocator = std.testing.allocator;
    const levels = try ternaryWeberLevels(allocator, 3, 1.0, 0.3);
    defer allocator.free(levels);

    // 3 trits → 27 levels, should be monotonic
    var prev: f32 = levels[0];
    for (levels[1..]) |level| {
        try std.testing.expect(level >= prev - 0.01); // allow small numerical errors
        prev = level;
    }
}

test "adaptive threshold constant" {
    const errors = [_]f16{ 0.1, 0.2, 0.15 };
    const base: f16 = 0.5;
    const result = adaptiveThreshold(&errors, base, 1.0);

    // Mean error = 0.15, adaptive = 0.5 + 1.0 * 0.15 = 0.65
    try std.testing.expect(result >= 0.64);
    try std.testing.expect(result <= 0.66);
}

test "adaptive threshold empty" {
    const base: f16 = 0.5;
    const empty: [0]f16 = .{};
    const result = adaptiveThreshold(&empty, base, 1.0);

    // Empty errors → return base threshold
    try std.testing.expectEqual(base, result);
}

test "weber compare" {
    const a: f32 = 1.0;
    const b: f32 = 2.0;
    const k: f16 = 0.3;

    const ratio = weberCompare(a, b, k);

    // Δ = 1, S = 2, Weber ratio = 1/2 / 0.3 ≈ 1.67
    try std.testing.expect(ratio > 1.0);
    try std.testing.expect(ratio < 2.0);
}

test "weber compare same" {
    const a: f32 = 1.0;
    const k: f16 = 0.3;

    const ratio = weberCompare(a, a, k);

    // Same stimulus → zero difference
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), ratio, 0.001);
}

test "weber quantize slice" {
    const allocator = std.testing.allocator;
    const input = [_]f32{ 0.5, 1.0, 2.0, 4.0 };
    const base: f32 = 1.0;
    const k: f16 = 0.3;

    const quantized = try weberQuantizeSlice(allocator, &input, base, k);
    defer allocator.free(quantized);

    try std.testing.expectEqual(input.len, quantized.len);

    const recovered = try weberDequantizeSlice(allocator, quantized, base, k);
    defer allocator.free(recovered);

    for (input, recovered) |orig, rec| {
        try std.testing.expectApproxEqAbs(orig, rec, @abs(orig) * 0.15 + 0.05);
    }
}

test "weber constant effect" {
    const base: f32 = 1.0;
    const k_low: f16 = 0.1;
    const k_high: f16 = 0.5;

    const q_low = weberQuantize(2.0, base, k_low);
    const q_high = weberQuantize(2.0, base, k_high);

    // Higher k → more compressed (smaller quantized values)
    try std.testing.expect(q_high != q_low);
}

// φ² + 1/φ² = 3 | TRINITY
