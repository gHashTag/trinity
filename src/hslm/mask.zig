// @origin(manual) @regen(pending)
// T-JEPA — Block Masking for Sequences
// Contiguous span masking: harder prediction → better representations
// Spans aligned to ternary powers (3^1=3, 3^2=9)
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const constants = @import("constants.zig");

const CONTEXT_LEN = constants.CONTEXT_LEN;

// ═══════════════════════════════════════════════════════════════════════════════
// MASK CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const MaskConfig = struct {
    mask_ratio: f32 = 0.3, // 30% masked
    min_span: usize = 3, // 3^1
    max_span: usize = 9, // 3^2 (ctx=27 can't fit 3 spans of 27)
    num_spans: usize = 2, // 2 spans fit in ctx=27..81
};

pub const MaskResult = struct {
    visible: [CONTEXT_LEN]bool, // true = visible, false = masked
    num_visible: usize,
    num_masked: usize,
    masked_positions: [CONTEXT_LEN]usize, // packed list of masked indices
    visible_positions: [CONTEXT_LEN]usize, // packed list of visible indices

    pub fn init() MaskResult {
        return .{
            .visible = [_]bool{true} ** CONTEXT_LEN,
            .num_visible = 0,
            .num_masked = 0,
            .masked_positions = [_]usize{0} ** CONTEXT_LEN,
            .visible_positions = [_]usize{0} ** CONTEXT_LEN,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MASK GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate contiguous span mask for a sequence
/// 1. Sample num_spans spans of length uniform[min_span, max_span]
/// 2. Random start positions, merge overlaps
/// 3. Clamp total masked ≤ seq_len * mask_ratio
pub fn generateMask(seq_len: usize, config: MaskConfig, rng: std.Random) MaskResult {
    var result = MaskResult.init();
    if (seq_len == 0) return result;

    const effective_len = @min(seq_len, CONTEXT_LEN);
    const max_masked = @as(usize, @intFromFloat(@as(f32, @floatFromInt(effective_len)) * config.mask_ratio));

    // Mark all as visible initially
    for (0..CONTEXT_LEN) |i| {
        result.visible[i] = true;
    }

    // Generate spans
    var total_masked: usize = 0;
    for (0..config.num_spans) |_| {
        if (total_masked >= max_masked) break;

        // Sample span length
        const span_range = config.max_span - config.min_span + 1;
        const span_len = config.min_span + rng.uintLessThan(usize, span_range);
        const actual_span = @min(span_len, max_masked - total_masked);

        if (actual_span == 0) break;
        if (effective_len <= actual_span) break;

        // Random start position
        const max_start = effective_len - actual_span;
        const start = rng.uintLessThan(usize, max_start + 1);

        // Mark span as masked
        for (start..start + actual_span) |pos| {
            if (result.visible[pos]) {
                result.visible[pos] = false;
                total_masked += 1;
                if (total_masked >= max_masked) break;
            }
        }
    }

    // Build packed position arrays
    var vi: usize = 0;
    var mi: usize = 0;
    for (0..effective_len) |i| {
        if (result.visible[i]) {
            result.visible_positions[vi] = i;
            vi += 1;
        } else {
            result.masked_positions[mi] = i;
            mi += 1;
        }
    }
    result.num_visible = vi;
    result.num_masked = mi;

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "mask valid split" {
    var prng = std.Random.DefaultPrng.init(42);
    const result = generateMask(27, .{}, prng.random());
    // visible + masked = seq_len
    try std.testing.expectEqual(@as(usize, 27), result.num_visible + result.num_masked);
}

test "mask ratio approximate" {
    var prng = std.Random.DefaultPrng.init(123);
    // Run multiple times and check average
    var total_masked: usize = 0;
    const trials = 100;
    const seq_len: usize = 81;
    for (0..trials) |_| {
        const result = generateMask(seq_len, .{}, prng.random());
        total_masked += result.num_masked;
    }
    const avg_ratio = @as(f32, @floatFromInt(total_masked)) / @as(f32, @floatFromInt(trials * seq_len));
    // Should be within 20% of 0.3 → between 0.1 and 0.5
    try std.testing.expect(avg_ratio > 0.1);
    try std.testing.expect(avg_ratio < 0.5);
}

test "mask spans contiguous" {
    var prng = std.Random.DefaultPrng.init(777);
    const result = generateMask(81, .{ .num_spans = 1, .min_span = 5, .max_span = 9 }, prng.random());
    // With 1 span, masked positions should be contiguous
    if (result.num_masked > 1) {
        for (0..result.num_masked - 1) |i| {
            const diff = result.masked_positions[i + 1] - result.masked_positions[i];
            try std.testing.expectEqual(@as(usize, 1), diff);
        }
    }
}

test "mask deterministic seed" {
    var prng1 = std.Random.DefaultPrng.init(42);
    var prng2 = std.Random.DefaultPrng.init(42);
    const r1 = generateMask(27, .{}, prng1.random());
    const r2 = generateMask(27, .{}, prng2.random());
    try std.testing.expectEqual(r1.num_masked, r2.num_masked);
    for (0..r1.num_masked) |i| {
        try std.testing.expectEqual(r1.masked_positions[i], r2.masked_positions[i]);
    }
}
