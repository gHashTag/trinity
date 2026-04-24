// BENCH-001: Ternary vs FP16/BF16/GF16 on MNIST
// Scientific benchmark for TRI-27 algorithms
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const print = std.debug.print;

// ═══════════════════════════════════════════════════════════════════════════════
// FORMATS
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantize f32 to ternary {-1, 0, +1}
fn quantizeTernary(x: f32) i2 {
    if (x > 0.5) return 1;
    if (x < -0.5) return -1;
    return 0;
}

/// Ternary to f32
fn ternaryToF32(t: i2) f32 {
    return @as(f32, @floatFromInt(t));
}

/// GF16 encode (reuse from formats.zig)
fn f32ToGf16(x: f32) u16 {
    if (x == 0.0) return 0;
    const sign_bit: u16 = if (x < 0) 0x8000 else 0;
    const abs = if (x < 0) -x else x;
    if (std.math.isPositiveInf(abs)) return sign_bit | 0x7E00;
    if (std.math.isNan(abs)) return sign_bit | 0x7E01;

    const frexp_result = std.math.frexp(abs);
    var m = frexp_result.significand;
    var exp_i = frexp_result.exponent;
    m *= 2.0;
    exp_i -= 1;

    const Bias: i32 = 31;
    const ExpMax: u16 = 63;
    const e = exp_i + Bias;
    if (e <= 0) return sign_bit;
    if (e >= ExpMax) return sign_bit | 0x7E00;

    const mant_f = (m - 1.0) * 512.0;
    const mantissa: u16 = @intFromFloat(@round(mant_f));
    return sign_bit | (@as(u16, @intCast(e)) << 9) | (mantissa & 0x01FF);
}

/// GF16 decode
fn gf16ToF32(x: u16) f32 {
    const s = @as(i32, (x >> 15) & 1);
    const e = @as(i32, (x & 0x7E00) >> 9);
    const m = @as(i32, x & 0x01FF);

    const Bias: i32 = 31;
    if (e == 0 and m == 0) return if (s == 0) 0.0 else -0.0;
    if (e == 0) {
        const exp = 1 - Bias;
        const frac = @as(f32, @floatFromInt(m)) / 512.0;
        const val = std.math.exp2(@as(f32, @floatFromInt(exp))) * frac;
        return if (s == 0) val else -val;
    }
    if (e == 63) {
        if (m == 0) return if (s == 0) std.math.inf(f32) else -std.math.inf(f32);
        return std.math.nan(f32);
    }
    const exp = e - Bias;
    const frac = 1.0 + @as(f32, @floatFromInt(m)) / 512.0;
    const val = frac * std.math.exp2(@as(f32, @floatFromInt(exp)));
    return if (s == 0) val else -val;
}

/// FP16 encode (IEEE 754 half precision)
fn f32ToFp16(x: f32) u16 {
    if (x == 0.0) return if (x < 0) 0x8000 else 0;
    const bits = @as(u32, @bitCast(x));
    const sign = @as(u16, @truncate(bits >> 16));
    const exp_all = @as(u32, @truncate(bits >> 23));
    const mantissa = @as(u16, @truncate(bits >> 13)) & 0x3FF;
    return sign | (@as(u16, @intCast(exp_all)) << 10) | mantissa;
}

/// FP16 decode
fn fp16ToF32(x: u16) f32 {
    const sign = if (x & 0x8000 != 0) @as(u32, 0x80000000) else 0;
    const exp = @as(u32, (x & 0x7C00) >> 10) << 23;
    const mant = @as(u32, (x & 0x3FF)) << 13;
    return @bitCast(@as(u32, sign | exp | mant));
}

/// BF16 encode (truncate mantissa to 7 bits)
fn f32ToBf16(x: f32) u16 {
    if (x == 0.0) return if (x < 0) 0x8000 else 0;
    const bits = @as(u32, @bitCast(x));
    const sign = @as(u16, @truncate(bits >> 16));
    const exp_all = @as(u16, @truncate(bits >> 23));
    const mantissa = @as(u16, @truncate(bits >> 16)) & 0x007F;
    return sign | (exp_all << 7) | mantissa;
}

/// BF16 decode
fn bf16ToF32(x: u16) f32 {
    const sign = if (x & 0x8000 != 0) @as(u32, 0x80000000) else 0;
    const exp = @as(u32, (x & 0x7F80) >> 7) << 23;
    const mant = @as(u32, (x & 0x007F)) << 16;
    return @bitCast(@as(u32, sign | exp | mant));
}

// ═══════════════════════════════════════════════════════════════════════════════
// MLP LAYER
// ═══════════════════════════════════════════════════════════════════════════════

const LayerConfig = struct {
    input_size: usize,
    hidden_size: usize,
    output_size: usize,
};

fn relu(x: f32) f32 {
    return if (x > 0) x else 0;
}

fn denseLayer(
    input: []const f32,
    weights: []const f32,
    bias: []const f32,
    output: []f32,
    in_size: usize,
    out_size: usize,
) void {
    for (0..out_size) |o| {
        var sum = bias[o];
        for (0..in_size) |i| {
            sum += input[i] * weights[i * out_size + o];
        }
        output[o] = relu(sum);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTIZED FORWARD PASS
// ═══════════════════════════════════════════════════════════════════════════════

fn forwardTernary(
    input: []const f32,
    w1: []const i2,
    b1: []const i2,
    w2: []const i2,
    b2: []const i2,
    hidden: []f32,
    output: []f32,
    config: LayerConfig,
) void {
    // Layer 1
    for (0..config.hidden_size) |h| {
        var sum: f32 = ternaryToF32(b1[h]);
        for (0..config.input_size) |i| {
            sum += input[i] * ternaryToF32(w1[i * config.hidden_size + h]);
        }
        hidden[h] = relu(sum);
    }
    // Layer 2
    for (0..config.output_size) |o| {
        var sum: f32 = ternaryToF32(b2[o]);
        for (0..config.hidden_size) |h| {
            sum += hidden[h] * ternaryToF32(w2[h * config.output_size + o]);
        }
        output[o] = relu(sum);
    }
}

fn forwardGf16(
    input: []const f32,
    w1: []const u16,
    b1: []const u16,
    w2: []const u16,
    b2: []const u16,
    hidden: []f32,
    output: []f32,
    config: LayerConfig,
) void {
    // Layer 1
    for (0..config.hidden_size) |h| {
        var sum: f32 = gf16ToF32(b1[h]);
        for (0..config.input_size) |i| {
            const w_val = gf16ToF32(w1[i * config.hidden_size + h]);
            sum += input[i] * w_val;
        }
        hidden[h] = relu(sum);
    }
    // Layer 2
    for (0..config.output_size) |o| {
        var sum: f32 = gf16ToF32(b2[o]);
        for (0..config.hidden_size) |h| {
            const w_val = gf16ToF32(w2[h * config.output_size + o]);
            sum += hidden[h] * w_val;
        }
        output[o] = relu(sum);
    }
}

fn forwardFp16(
    input: []const f32,
    w1: []const u16,
    b1: []const u16,
    w2: []const u16,
    b2: []const u16,
    hidden: []f32,
    output: []f32,
    config: LayerConfig,
) void {
    // Layer 1
    for (0..config.hidden_size) |h| {
        var sum: f32 = fp16ToF32(b1[h]);
        for (0..config.input_size) |i| {
            sum += input[i] * fp16ToF32(w1[i * config.hidden_size + h]);
        }
        hidden[h] = relu(sum);
    }
    // Layer 2
    for (0..config.output_size) |o| {
        var sum: f32 = fp16ToF32(b2[o]);
        for (0..config.hidden_size) |h| {
            sum += hidden[h] * fp16ToF32(w2[h * config.output_size + o]);
        }
        output[o] = relu(sum);
    }
}

fn forwardBf16(
    input: []const f32,
    w1: []const u16,
    b1: []const u16,
    w2: []const u16,
    b2: []const u16,
    hidden: []f32,
    output: []f32,
    config: LayerConfig,
) void {
    // Layer 1
    for (0..config.hidden_size) |h| {
        var sum: f32 = bf16ToF32(b1[h]);
        for (0..config.input_size) |i| {
            sum += input[i] * bf16ToF32(w1[i * config.hidden_size + h]);
        }
        hidden[h] = relu(sum);
    }
    // Layer 2
    for (0..config.output_size) |o| {
        var sum: f32 = bf16ToF32(b2[o]);
        for (0..config.hidden_size) |h| {
            sum += hidden[h] * bf16ToF32(w2[h * config.output_size + o]);
        }
        output[o] = relu(sum);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESULTS
// ═══════════════════════════════════════════════════════════════════════════════

const BenchmarkResult = struct {
    format: []const u8,
    accuracy: f32,
    loss: f32,
    bytes_per_weight: f32,
};

fn computeAccuracy(predictions: []const f32, labels: []const u8, num_classes: usize) f32 {
    var correct: usize = 0;
    const num_samples = labels.len;
    for (0..num_samples) |i| {
        const pred = predictions[i * num_classes ..][0..num_classes];
        var max_idx: usize = 0;
        var max_val: f32 = pred[0];
        for (1..num_classes) |j| {
            if (pred[j] > max_val) {
                max_val = pred[j];
                max_idx = j;
            }
        }
        if (max_idx == labels[i]) correct += 1;
    }
    return @as(f32, @floatFromInt(correct)) / @as(f32, @floatFromInt(num_samples));
}

fn mseLoss(predictions: []const f32, targets: []const f32) f32 {
    var sum: f32 = 0;
    for (predictions, targets) |p, t| {
        const diff = p - t;
        sum += diff * diff;
    }
    return sum / @as(f32, @floatFromInt(predictions.len));
}

// ═══════════════════════════════════════════════════════════════════════════════
// CSV OUTPUT
// ═══════════════════════════════════════════════════════════════════════════════

fn writeCsv(results: []const BenchmarkResult, filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    var line_buf: [256]u8 = undefined;

    const header = "format,accuracy,loss,bytes_per_weight\n";
    try file.writeAll(header);

    for (results) |r| {
        const line = try std.fmt.bufPrint(&line_buf, "{s},{d:.4},{d:.6},{d:.3}\n", .{ r.format, r.accuracy, r.loss, r.bytes_per_weight });
        try file.writeAll(line);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MNIST LOADER (simplified)
// ═══════════════════════════════════════════════════════════════════════════════

const MnistHeader = struct {
    magic: u32,
    count: u32,
    rows: u32,
    cols: u32,
};

fn readMnistImages(filename: []const u8, allocator: std.mem.Allocator) !struct {
    data: []f32,
    count: usize,
    rows: usize,
    cols: usize,
} {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const bytes = try allocator.alloc(u8, file_size);
    defer allocator.free(bytes);
    _ = try file.readAll(bytes);

    // Parse header
    var header: [4]u32 = undefined;
    for (&header, 0..) |*h, i| {
        h.* = std.mem.readInt(u32, bytes[i * 4 ..][0..4], .big);
    }

    const count = header[1];
    const rows = header[2];
    const cols = header[3];
    const total = count * rows * cols;
    const header_size = 16;

    const data = try allocator.alloc(f32, total);
    for (0..total) |i| {
        data[i] = @as(f32, @floatFromInt(bytes[header_size + i])) / 255.0;
    }

    return .{ .data = data, .count = count, .rows = rows, .cols = cols };
}

fn readMnistLabels(filename: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const bytes = try allocator.alloc(u8, file_size);
    defer allocator.free(bytes);
    _ = try file.readAll(bytes);

    const count = std.mem.readInt(u32, bytes[4..8], .big);
    const labels = try allocator.alloc(u8, count);
    for (0..count) |i| {
        labels[i] = bytes[8 + i];
    }

    return labels;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = LayerConfig{
        .input_size = 784, // 28x28
        .hidden_size = 128,
        .output_size = 10,
    };

    print("\n╔═══════════════════════════════════════════════════════════════╗\n", .{});
    print("║   BENCH-001: Ternary vs FP16/BF16/GF16 on MNIST            ║\n", .{});
    print("╚═══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Load MNIST (use test set for speed)
    const max_samples: usize = 1000; // Subset for faster benchmark
    print("Loading MNIST data ({} samples)...\n", .{max_samples});

    const images = try readMnistImages("data/t10k-images-idx3-ubyte", allocator);
    defer allocator.free(images.data);
    const labels = try readMnistLabels("data/t10k-labels-idx1-ubyte", allocator);
    defer allocator.free(labels);

    print("Loaded {} images ({}x{})\n", .{ images.count, images.rows, images.cols });

    // Initialize random weights
    var rnd = std.Random.DefaultPrng.init(42);
    const random = rnd.random();

    const w1_size = config.input_size * config.hidden_size;
    const b1_size = config.hidden_size;
    const w2_size = config.hidden_size * config.output_size;
    const b2_size = config.output_size;

    const w1_f32 = try allocator.alloc(f32, w1_size);
    defer allocator.free(w1_f32);
    const b1_f32 = try allocator.alloc(f32, b1_size);
    defer allocator.free(b1_f32);
    const w2_f32 = try allocator.alloc(f32, w2_size);
    defer allocator.free(w2_f32);
    const b2_f32 = try allocator.alloc(f32, b2_size);
    defer allocator.free(b2_f32);

    // Xavier initialization
    const std1 = std.math.sqrt(2.0 / @as(f32, @floatFromInt(config.input_size)));
    for (w1_f32) |*w| w.* = random.floatNorm(f32) * std1;
    for (b1_f32) |*b| b.* = 0;
    const std2 = std.math.sqrt(2.0 / @as(f32, @floatFromInt(config.hidden_size)));
    for (w2_f32) |*w| w.* = random.floatNorm(f32) * std2;
    for (b2_f32) |*b| b.* = 0;

    // Quantize weights
    var w1_ternary = try allocator.alloc(i2, w1_size);
    defer allocator.free(w1_ternary);
    var w1_gf16 = try allocator.alloc(u16, w1_size);
    defer allocator.free(w1_gf16);
    var w1_fp16 = try allocator.alloc(u16, w1_size);
    defer allocator.free(w1_fp16);
    var w1_bf16 = try allocator.alloc(u16, w1_size);
    defer allocator.free(w1_bf16);

    for (w1_f32, 0..) |w, i| {
        w1_ternary[i] = quantizeTernary(w);
        w1_gf16[i] = f32ToGf16(w);
        w1_fp16[i] = f32ToFp16(w);
        w1_bf16[i] = f32ToBf16(w);
    }

    var w2_ternary = try allocator.alloc(i2, w2_size);
    defer allocator.free(w2_ternary);
    var w2_gf16 = try allocator.alloc(u16, w2_size);
    defer allocator.free(w2_gf16);
    var w2_fp16 = try allocator.alloc(u16, w2_size);
    defer allocator.free(w2_fp16);
    var w2_bf16 = try allocator.alloc(u16, w2_size);
    defer allocator.free(w2_bf16);

    for (w2_f32, 0..) |w, i| {
        w2_ternary[i] = quantizeTernary(w);
        w2_gf16[i] = f32ToGf16(w);
        w2_fp16[i] = f32ToFp16(w);
        w2_bf16[i] = f32ToBf16(w);
    }

    var b1_ternary = try allocator.alloc(i2, b1_size);
    defer allocator.free(b1_ternary);
    var b1_gf16 = try allocator.alloc(u16, b1_size);
    defer allocator.free(b1_gf16);
    var b1_fp16 = try allocator.alloc(u16, b1_size);
    defer allocator.free(b1_fp16);
    var b1_bf16 = try allocator.alloc(u16, b1_size);
    defer allocator.free(b1_bf16);

    for (b1_f32, 0..) |b, i| {
        b1_ternary[i] = quantizeTernary(b);
        b1_gf16[i] = f32ToGf16(b);
        b1_fp16[i] = f32ToFp16(b);
        b1_bf16[i] = f32ToBf16(b);
    }

    var b2_ternary = try allocator.alloc(i2, b2_size);
    defer allocator.free(b2_ternary);
    var b2_gf16 = try allocator.alloc(u16, b2_size);
    defer allocator.free(b2_gf16);
    var b2_fp16 = try allocator.alloc(u16, b2_size);
    defer allocator.free(b2_fp16);
    var b2_bf16 = try allocator.alloc(u16, b2_size);
    defer allocator.free(b2_bf16);

    for (b2_f32, 0..) |b, i| {
        b2_ternary[i] = quantizeTernary(b);
        b2_gf16[i] = f32ToGf16(b);
        b2_fp16[i] = f32ToFp16(b);
        b2_bf16[i] = f32ToBf16(b);
    }

    // Allocate buffers
    const hidden_f32 = try allocator.alloc(f32, config.hidden_size);
    defer allocator.free(hidden_f32);
    const output_f32 = try allocator.alloc(f32, config.output_size);
    defer allocator.free(output_f32);

    var predictions_f32 = try allocator.alloc(f32, max_samples * config.output_size);
    defer allocator.free(predictions_f32);
    var predictions_ternary = try allocator.alloc(f32, max_samples * config.output_size);
    defer allocator.free(predictions_ternary);
    var predictions_gf16 = try allocator.alloc(f32, max_samples * config.output_size);
    defer allocator.free(predictions_gf16);
    var predictions_fp16 = try allocator.alloc(f32, max_samples * config.output_size);
    defer allocator.free(predictions_fp16);
    var predictions_bf16 = try allocator.alloc(f32, max_samples * config.output_size);
    defer allocator.free(predictions_bf16);

    var targets = try allocator.alloc(f32, max_samples * config.output_size);
    defer allocator.free(targets);

    // ─────────────────────────────────────────────────────────────────────
    // Run benchmarks
    // ─────────────────────────────────────────────────────────────────────

    print("\nRunning inference...\n", .{});

    // FP32 baseline
    for (0..max_samples) |i| {
        const img = images.data[i * 784 ..][0..784];
        const pred = predictions_f32[i * 10 ..][0..10];

        denseLayer(img, w1_f32, b1_f32, hidden_f32, config.input_size, config.hidden_size);
        denseLayer(hidden_f32, w2_f32, b2_f32, pred, config.hidden_size, config.output_size);

        // One-hot target
        for (0..10) |j| {
            targets[i * 10 + j] = if (j == labels[i]) 1.0 else 0.0;
        }
    }

    // Ternary
    for (0..max_samples) |i| {
        const img = images.data[i * 784 ..][0..784];
        const pred = predictions_ternary[i * 10 ..][0..10];
        forwardTernary(img, w1_ternary, b1_ternary, w2_ternary, b2_ternary, hidden_f32, pred, config);
    }

    // GF16
    for (0..max_samples) |i| {
        const img = images.data[i * 784 ..][0..784];
        const pred = predictions_gf16[i * 10 ..][0..10];
        forwardGf16(img, w1_gf16, b1_gf16, w2_gf16, b2_gf16, hidden_f32, pred, config);
    }

    // FP16
    for (0..max_samples) |i| {
        const img = images.data[i * 784 ..][0..784];
        const pred = predictions_fp16[i * 10 ..][0..10];
        forwardFp16(img, w1_fp16, b1_fp16, w2_fp16, b2_fp16, hidden_f32, pred, config);
    }

    // BF16
    for (0..max_samples) |i| {
        const img = images.data[i * 784 ..][0..784];
        const pred = predictions_bf16[i * 10 ..][0..10];
        forwardBf16(img, w1_bf16, b1_bf16, w2_bf16, b2_bf16, hidden_f32, pred, config);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Compute metrics
    // ─────────────────────────────────────────────────────────────────────

    const acc_f32 = computeAccuracy(predictions_f32, labels[0..max_samples], 10);
    const acc_ternary = computeAccuracy(predictions_ternary, labels[0..max_samples], 10);
    const acc_gf16 = computeAccuracy(predictions_gf16, labels[0..max_samples], 10);
    const acc_fp16 = computeAccuracy(predictions_fp16, labels[0..max_samples], 10);
    const acc_bf16 = computeAccuracy(predictions_bf16, labels[0..max_samples], 10);

    const loss_f32 = mseLoss(predictions_f32, targets);
    const loss_ternary = mseLoss(predictions_ternary, targets);
    const loss_gf16 = mseLoss(predictions_gf16, targets);
    const loss_fp16 = mseLoss(predictions_fp16, targets);
    const loss_bf16 = mseLoss(predictions_bf16, targets);

    // ─────────────────────────────────────────────────────────────────────
    // Print results
    // ─────────────────────────────────────────────────────────────────────

    print("\n╔═══════════════════════════════════════════════════════════════╗\n", .{});
    print("║ RESULTS                                                      ║\n", .{});
    print("╚═══════════════════════════════════════════════════════════════╝\n\n", .{});

    print("┌──────────┬─────────────┬──────────┬──────────────────┐\n", .{});
    print("│ Format   │ Accuracy %  │ Loss     │ Bytes/weight     │\n", .{});
    print("├──────────┼─────────────┼──────────┼──────────────────┤\n", .{});
    print("│ f32      │   {d:8.2}   │  {d:6.4}  │ 16.0              │\n", .{ acc_f32 * 100, loss_f32 });
    print("│ GF16     │   {d:8.2}   │  {d:6.4}  │  2.0              │\n", .{ acc_gf16 * 100, loss_gf16 });
    print("│ FP16     │   {d:8.2}   │  {d:6.4}  │  2.0              │\n", .{ acc_fp16 * 100, loss_fp16 });
    print("│ BF16     │   {d:8.2}   │  {d:6.4}  │  2.0              │\n", .{ acc_bf16 * 100, loss_bf16 });
    print("│ Ternary  │   {d:8.2}   │  {d:6.4}  │  0.125 (1 bit)    │\n", .{ acc_ternary * 100, loss_ternary });
    print("└──────────┴─────────────┴──────────┴──────────────────┘\n\n", .{});

    print("Gap vs f32:\n", .{});
    print("  GF16:    {d:.2} pct\n", .{(acc_gf16 - acc_f32) * 100});
    print("  FP16:    {d:.2} pct\n", .{(acc_fp16 - acc_f32) * 100});
    print("  BF16:    {d:.2} pct\n", .{(acc_bf16 - acc_f32) * 100});
    print("  Ternary: {d:.2} pct\n", .{(acc_ternary - acc_f32) * 100});

    // ─────────────────────────────────────────────────────────────────────
    // Write CSV
    // ─────────────────────────────────────────────────────────────────────

    const results = [_]BenchmarkResult{
        .{ .format = "f32", .accuracy = acc_f32, .loss = loss_f32, .bytes_per_weight = 4.0 },
        .{ .format = "GF16", .accuracy = acc_gf16, .loss = loss_gf16, .bytes_per_weight = 2.0 },
        .{ .format = "FP16", .accuracy = acc_fp16, .loss = loss_fp16, .bytes_per_weight = 2.0 },
        .{ .format = "BF16", .accuracy = acc_bf16, .loss = loss_bf16, .bytes_per_weight = 2.0 },
        .{ .format = "Ternary", .accuracy = acc_ternary, .loss = loss_ternary, .bytes_per_weight = 0.125 },
    };

    try std.fs.cwd().makePath("results");
    try writeCsv(&results, "results/bench_001_summary.csv");
    print("\n✅ Results saved to results/bench_001_summary.csv\n", .{});
}
