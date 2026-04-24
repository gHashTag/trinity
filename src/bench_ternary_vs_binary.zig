// BENCH-001: Ternary vs f16/bf16 Comparison
// Minimal research benchmark for TRI-27 algorithms
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const print = std.debug.print;

const LayerConfig = struct {
    input_size: usize,
    hidden_size: usize,
    output_size: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FORMATS (reuse from src/formats.zig)
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantize f32 value to ternary {-1, 0, +1}
fn quantizeTernary(x: f32) i2 {
    if (x > 0.5) return 1;
    if (x < -0.5) return -1;
    return 0;
}

/// Quantize f32 to FP16 (truncate mantissa to 10 bits)
fn quantizeFP16(x: f32) u16 {
    const bits = @as(u32, @bitCast(x));
    const sign = @as(u16, @truncate(bits >> 16));
    const exp_all = @as(u16, @truncate(bits >> 23));
    const mantissa = @as(u16, @truncate(bits >> 13)) & 0x3FF;
    return sign | (exp_all << 10) | mantissa;
}

/// Quantize f32 to BF16 (truncate mantissa to 7 bits)
fn quantizeBF16(x: f32) u16 {
    const bits = @as(u32, @bitCast(x));
    const sign = @as(u16, @truncate(bits >> 16));
    const exp_all = @as(u16, @truncate(bits >> 23));
    const mantissa = @as(u16, @truncate(bits >> 16)) & 0x7F;
    return sign | (exp_all << 7) | mantissa;
}

/// Simple FP16 decode (for testing)
fn decodeFP16(bits: u16) f32 {
    const sign = if (bits & 0x8000 != 0) @as(u32, 0x80000000) else 0;
    const exp = @as(u32, (bits & 0x7C00) >> 10) << 23;
    const mant = @as(u32, (bits & 0x3FF) << 13);
    return @bitCast(f32, sign | exp | mant);
}

/// Simple BF16 decode (for testing)
fn decodeBF16(bits: u16) f32 {
    const sign = if (bits & 0x8000 != 0) @as(u32, 0x80000000) else 0;
    const exp = @as(u32, (bits & 0x7F80) >> 7) << 23;
    const mant = @as(u32, (bits & 0x007F) << 16);
    return @bitCast(f32, sign | exp | mant);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MLP FORWARD (reuse from test_mlp_semantic.zig)
// ═══════════════════════════════════════════════════════════════════════════════

fn relu(x: f32) f32 {
    return if (x > 0) x else 0;
}

fn mlpForward(
    input: []const f32,
    w1: []const f32,
    b1: []const f32,
    w2: []const f32,
    b2: []const f32,
    hidden: []f32,
    output: []f32,
    config: LayerConfig,
) void {
    // Layer 1: Dense + ReLU
    for (0..config.hidden_size) |h| {
        var sum_h = b1[h];
        for (0..config.input_size) |i| {
            sum_h += input[i] * w1[i * config.hidden_size + h];
        }
        hidden[h] = relu(sum_h);
    }

    // Layer 2: Dense + ReLU
    for (0..config.output_size) |o| {
        var sum_o = b2[o];
        for (0..config.hidden_size) |h| {
            sum_o += hidden[h] * w2[h * config.output_size + o];
        }
        output[o] = relu(sum_o);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const config = LayerConfig{
        .input_size = 4,
        .hidden_size = 8,
        .output_size = 3,
    };

    print("\n╔═══════════════════════════════════════════════════════════════╗\n", .{});
    print("║   BENCH-001: Ternary vs f16/bf16 Comparison                    ║\n", .{});
    print("╚═══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Test input: [1.0, 0.0, 0.0, 0.0]
    const input = [_]f32{ 1.0, 0.0, 0.0, 0.0 };

    // Identity weights (for reproducible results)
    var w1_f32: [32]f32 = undefined;
    var b1_f32: [8]f32 = undefined;
    var w2_f32: [24]f32 = undefined;
    var b2_f32: [3]f32 = undefined;

    {
        var i: usize = 0;
        while (i < 32) : (i += 1) {
            const row = i / 8;
            const col = i % 8;
            w1_f32[i] = if (row == col) 1.0 else 0.0;
        }
    }
    for (&b1_f32) |*b| b.* = 0;
    {
        var i: usize = 0;
        while (i < 24) : (i += 1) {
            const row = i / 3;
            const col = i % 3;
            w2_f32[i] = if (row == col) 1.0 else 0.0;
        }
    }
    for (&b2_f32) |*b| b.* = 0;

    // ─────────────────────────────────────────────────────────────────────
    // Experiment 1: FP32 Baseline
    // ─────────────────────────────────────────────────────────────────────

    var hidden_f32: [8]f32 = undefined;
    var output_f32: [3]f32 = undefined;
    mlpForward(&input, &w1_f32, &b1_f32, &w2_f32, &b2_f32, &hidden_f32, &output_f32, config);

    print("Experiment 1: FP32 Baseline\n", .{});
    print("  Output: [{d:.3}, {d:.3}, {d:.3}]\n", .{ output_f32[0], output_f32[1], output_f32[2] });

    // ─────────────────────────────────────────────────────────────────────
    // Experiment 2: Ternary Weights
    // ─────────────────────────────────────────────────────────────────────

    var w1_ternary: [32]i2 = undefined;
    var b1_ternary: [8]i2 = undefined;
    var w2_ternary: [24]i2 = undefined;
    var b2_ternary: [3]i2 = undefined;

    for (&w1_f32, 0..) |w, i| w1_ternary[i] = quantizeTernary(w.*);
    for (&b1_f32, 0..) |b, i| b1_ternary[i] = quantizeTernary(b.*);
    for (&w2_f32, 0..) |w, i| w2_ternary[i] = quantizeTernary(w.*);
    for (&b2_f32, 0..) |b, i| b2_ternary[i] = quantizeTernary(b.*);

    // Convert ternary back to f32 for forward pass
    var w1_t_f32: [32]f32 = undefined;
    var b1_t_f32: [8]f32 = undefined;
    var w2_t_f32: [24]f32 = undefined;
    var b2_t_f32: [3]f32 = undefined;

    for (&w1_ternary, 0..) |w, i| w1_t_f32[i] = @as(f32, @floatFromInt(w.*));
    for (&b1_ternary, 0..) |b, i| b1_t_f32[i] = @as(f32, @floatFromInt(b.*));
    for (&w2_ternary, 0..) |w, i| w2_t_f32[i] = @as(f32, @floatFromInt(w.*));
    for (&b2_ternary, 0..) |b, i| b2_t_f32[i] = @as(f32, @floatFromInt(b.*));

    var hidden_ternary: [8]f32 = undefined;
    var output_ternary: [3]f32 = undefined;
    mlpForward(&input, &w1_t_f32, &b1_t_f32, &w2_t_f32, &b2_t_f32, &hidden_ternary, &output_ternary, config);

    print("Experiment 2: Ternary Weights\n", .{});
    print("  Output: [{d:.3}, {d:.3}, {d:.3}]\n", .{ output_ternary[0], output_ternary[1], output_ternary[2] });

    // ─────────────────────────────────────────────────────────────────────
    // Experiment 3: FP16 Weights
    // ─────────────────────────────────────────────────────────────────────

    var w1_fp16: [32]u16 = undefined;
    for (&w1_f32, 0..) |w, i| w1_fp16[i] = quantizeFP16(w.*);

    print("Experiment 3: FP16 Weights\n", .{});
    print("  (Not implemented - requires full FP16 arithmetic)\n", .{});

    // ─────────────────────────────────────────────────────────────────────
    // Experiment 4: BF16 Weights
    // ─────────────────────────────────────────────────────────────────────

    var w1_bf16: [32]u16 = undefined;
    for (&w1_f32, 0..) |w, i| w1_bf16[i] = quantizeBF16(w.*);

    print("Experiment 4: BF16 Weights\n", .{});
    print("  (Not implemented - requires full BF16 arithmetic)\n", .{});

    // ─────────────────────────────────────────────────────────────────────
    // Results Summary
    // ─────────────────────────────────────────────────────────────────────

    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("Results Summary:\n", .{});
    print("  Format   | Output[0] | Output[1] | Output[2]\n", .{});
    print("  ─────────┼───────────┼───────────┼───────────\n", .{});
    print("  FP32     |   {d:.3}   |   {d:.3}   |   {d:.3}   \n", .{ output_f32[0], output_f32[1], output_f32[2] });
    print("  Ternary  |   {d:.3}   |   {d:.3}   |   {d:.3}   \n", .{ output_ternary[0], output_ternary[1], output_ternary[2] });
    print("═══════════════════════════════════════════════════════════════\n\n", .{});

    // Accuracy comparison
    const diff0 = @abs(output_f32[0] - output_ternary[0]);
    const diff1 = @abs(output_f32[1] - output_ternary[1]);
    const diff2 = @abs(output_f32[2] - output_ternary[2]);
    const max_diff = @max(@max(diff0, diff1), diff2);

    print("Ternary vs FP32:\n", .{});
    print("  Max difference: {d:.3}\n", .{max_diff});
    if (max_diff < 0.5) {
        print("  ✅ PASS: difference < 0.5\n", .{});
    } else {
        print("  ❌ FAIL: difference >= 0.5\n", .{});
    }
    print("\n✅ Trinity Identity: φ² + 1/φ² = {d:.15} ≈ 3.0\n", .{2.618033988749895 + 1.0 / 2.618033988749895});
}
