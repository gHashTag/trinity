// @origin(spec:ternary_gradients.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Ternary Gradients (TernGrad)
// Stochastic quantization of gradients to ternary {-1, 0, +1}.
// 16x compression: 7.8MB → 488KB (f32 → 2-bit + scale factor).
// Paper: Wen et al. "TernGrad: Ternary Gradients to Reduce Communication"

const std = @import("std");
const Trit = @import("trit_encoding.zig").Trit;

pub const TernaryGrad = struct {
    /// Ternarized gradient values
    signs: []Trit,
    /// Scaling factor: max(|grad|)
    scale: f32,
    /// Original length
    len: usize,
};

pub const TernGrad = struct {
    rng: std.Random.DefaultPrng,

    pub fn init(seed: u64) TernGrad {
        return .{ .rng = std.Random.DefaultPrng.init(seed) };
    }

    /// Stochastic ternarization: P(t_i = sign(g_i)) = |g_i| / max(|g|)
    pub fn quantize(self: *TernGrad, grad: []const f32, output_signs: []Trit) TernaryGrad {
        const random = self.rng.random();

        // Find max absolute value (scaling factor)
        var max_abs: f32 = 0.0;
        for (grad) |g| {
            const abs_g = @abs(g);
            if (abs_g > max_abs) max_abs = abs_g;
        }

        if (max_abs == 0.0) {
            @memset(output_signs[0..grad.len], 0);
            return .{ .signs = output_signs[0..grad.len], .scale = 0.0, .len = grad.len };
        }

        // Stochastic quantization
        for (grad, 0..) |g, i| {
            const prob = @abs(g) / max_abs;
            const rand_val = random.float(f32);
            if (rand_val < prob) {
                output_signs[i] = if (g >= 0) @as(Trit, 1) else @as(Trit, -1);
            } else {
                output_signs[i] = 0;
            }
        }

        return .{ .signs = output_signs[0..grad.len], .scale = max_abs, .len = grad.len };
    }

    /// Dequantize: grad_approx[i] = scale * signs[i]
    pub fn dequantize(tg: TernaryGrad, output: []f32) void {
        for (0..tg.len) |i| {
            output[i] = tg.scale * @as(f32, @floatFromInt(@as(i8, tg.signs[i])));
        }
    }

    /// Compression ratio: original f32 bytes / compressed bytes
    /// Compressed = signs (2 bits each) + 1 scale (4 bytes)
    pub fn compressionRatio(len: usize) f32 {
        const original_bytes: f32 = @floatFromInt(len * 4); // f32 = 4 bytes
        const compressed_bytes: f32 = @floatFromInt((len + 3) / 4 + 4); // 2 bits/trit + scale
        return original_bytes / compressed_bytes;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TernGrad direction preservation" {
    var tg = TernGrad.init(0xDEAD);

    const grad = [_]f32{ 1.0, -0.5, 0.8, -0.9, 0.1, -0.3, 0.7, -0.2 };
    var signs: [8]Trit = undefined;
    const result = tg.quantize(&grad, &signs);

    var output: [8]f32 = undefined;
    TernGrad.dequantize(result, &output);

    // Direction preservation: cosine similarity should be positive
    var dot: f32 = 0.0;
    var norm_a: f32 = 0.0;
    var norm_b: f32 = 0.0;
    for (0..8) |i| {
        dot += grad[i] * output[i];
        norm_a += grad[i] * grad[i];
        norm_b += output[i] * output[i];
    }
    if (norm_b > 0) {
        const cosine = dot / (@sqrt(norm_a) * @sqrt(norm_b));
        try std.testing.expect(cosine > 0.0); // Same general direction
    }
}

test "TernGrad compression ratio" {
    // 1M params: 4MB → should compress ~16x
    const ratio = TernGrad.compressionRatio(1_000_000);
    try std.testing.expect(ratio > 14.0);
    try std.testing.expect(ratio < 18.0);
}

test "TernGrad zero gradient" {
    var tg = TernGrad.init(0xBEEF);
    const grad = [_]f32{ 0.0, 0.0, 0.0, 0.0 };
    var signs: [4]Trit = undefined;
    const result = tg.quantize(&grad, &signs);

    try std.testing.expectEqual(@as(f32, 0.0), result.scale);
    for (result.signs) |s| {
        try std.testing.expectEqual(@as(Trit, 0), s);
    }
}

test "TernGrad output is ternary" {
    var tg = TernGrad.init(0xCAFE);
    const grad = [_]f32{ 0.5, -0.3, 0.9, -0.1, 0.7, -0.8, 0.2, -0.6 };
    var signs: [8]Trit = undefined;
    _ = tg.quantize(&grad, &signs);

    for (signs) |s| {
        const val: i8 = s;
        try std.testing.expect(val >= -1 and val <= 1);
    }
}
