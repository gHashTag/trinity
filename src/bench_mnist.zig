//! BENCH-004: MNIST Real Data Benchmark with Real Quantization
//!
//! Compare accuracy degradation on real MNIST test set with actual
//! format quantization (GF16, ternary, fp16, bf16 vs fp32 baseline).
//!
//! Usage:
//!   bench-mnist                        # Random weights (sanity-check)
//!   bench-mnist --weights=weights.bin   # Trained weights
//!
//! Model: MLP 784 -> 128 -> 10

const std = @import("std");
const mnist = @import("mnist_loader.zig");
const formats = @import("formats");

const LayerConfig = struct {
    input_size: usize,
    hidden_size: usize,
    output_size: usize,
};

fn relu(x: f32) f32 {
    return if (x > 0) x else 0;
}

// Helper: convert null-terminated string to slice
inline fn spanZ(ptr: [*:0]const u8) []const u8 {
    var len: usize = 0;
    while (ptr[len] != 0) : (len += 1) {}
    return ptr[0..len];
}

// Helper: compare null-terminated string with slice
inline fn strEql(a: [*:0]const u8, b: []const u8) bool {
    var i: usize = 0;
    while (i < b.len) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return a[i] == 0; // Also check null terminator
}

// Helper: check if a string starts with a prefix
inline fn startsWith(s: []const u8, prefix: []const u8) bool {
    if (s.len < prefix.len) return false;
    var i: usize = 0;
    while (i < prefix.len) : (i += 1) {
        if (s[i] != prefix[i]) return false;
    }
    return true;
}

pub fn main() !void {
    const config = LayerConfig{
        .input_size = 784, // 28x28 MNIST images
        .hidden_size = 128,
        .output_size = 10, // Digits 0-9
    };

    const allocator = std.heap.c_allocator;

    // Parse command line args for --weights flag
    // Supports both: --weights value and --weights=value
    const weights_path: ?[]const u8 = blk: {
        var i: usize = 1;
        while (i < std.os.argv.len) : (i += 1) {
            const arg = spanZ(std.os.argv[i]);

            // Check for --weights=value format
            if (startsWith(arg, "--weights=")) {
                break :blk arg["--weights=".len..];
            }

            // Check for --weights value format
            if (strEql(std.os.argv[i], "--weights")) {
                if (i + 1 < std.os.argv.len) {
                    break :blk spanZ(std.os.argv[i + 1]);
                }
            }
        }
        break :blk null;
    };

    // Ensure data directory exists
    try std.fs.cwd().makePath("data");

    std.debug.print(
        \\╔════════════════════════════════════════════════════════════╗
        \\║  BENCH-004: MNIST Real Data Benchmark (Quantized)        ║
        \\╚════════════════════════════════════════════════════════════╝
        \\
        \\Model: MLP ({d} -> {d} -> {d})
        \\Dataset: MNIST test set (10k images)
        \\Quantization: f32, fp16, bf16, GF16, ternary
        \\
    , .{ config.input_size, config.hidden_size, config.output_size });

    // Load MNIST data
    const images_path = "data/t10k-images-idx3-ubyte";
    const labels_path = "data/t10k-labels-idx1-ubyte";

    std.debug.print("Loading MNIST data...\n", .{});

    var mnist_data = mnist.MNIST.load(allocator, images_path) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("\nERROR: MNIST files not found.\n", .{});
            std.debug.print("\nDownload from ossci mirror:\n", .{});
            std.debug.print("  cd data && curl -LO https://ossci-datasets.s3.amazonaws.com/mnist/t10k-images-idx3-ubyte.gz\n", .{});
            std.debug.print("  cd data && curl -LO https://ossci-datasets.s3.amazonaws.com/mnist/t10k-labels-idx1-ubyte.gz\n", .{});
            std.debug.print("  cd data && gunzip t10k-images-idx3-ubyte.gz t10k-labels-idx1-ubyte.gz\n", .{});
            return err;
        }
        return err;
    };
    defer mnist_data.deinit();

    var mnist_labels = mnist.Labels.load(allocator, labels_path) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("\nERROR: MNIST labels not found.\n", .{});
            std.debug.print("See above for download instructions.\n", .{});
        }
        return err;
    };
    defer mnist_labels.deinit();

    const num_samples = @min(mnist_data.count(), mnist_labels.count());
    std.debug.print("Loaded {d} images\n\n", .{num_samples});

    // Load weights: either from file or generate random
    const weights1_size = config.input_size * config.hidden_size;
    const weights2_size = config.hidden_size * config.output_size;

    var weights1_f32: []f32 = undefined;
    var biases1_f32: []f32 = undefined;
    var weights2_f32: []f32 = undefined;
    var biases2_f32: []f32 = undefined;
    var using_loaded_weights = false;

    // Load weights variable - will be freed after inference
    var loaded_weights: ?formats.MlpWeights = null;

    if (weights_path) |path| {
        std.debug.print("Loading trained weights from: {s}\n", .{path});

        const loaded = try formats.loadMlpWeights(allocator, path);
        // NOTE: NOT calling loaded.deinit() - we'll free manually after inference

        // Validate dimensions
        if (loaded.input_dim != config.input_size or
            loaded.hidden_dim != config.hidden_size or
            loaded.output_dim != config.output_size)
        {
            std.debug.print("\nERROR: Weight dimensions mismatch!\n", .{});
            std.debug.print("  Expected: {}x{}x{}\n", .{ config.input_size, config.hidden_size, config.output_size });
            std.debug.print("  Got: {}x{}x{}\n", .{ loaded.input_dim, loaded.hidden_dim, loaded.output_dim });
            loaded.deinit(); // Free before returning
            return error.DimensionMismatch;
        }

        // Store loaded weights for later cleanup and assign slices
        loaded_weights = loaded;
        weights1_f32 = loaded.W1;
        biases1_f32 = loaded.b1;
        weights2_f32 = loaded.W2;
        biases2_f32 = loaded.b2;
        using_loaded_weights = true;
    }

    if (!using_loaded_weights) {
        std.debug.print("Using random weights (Xavier init, seed=42)\n", .{});

        // Generate random weights (using fixed seed for reproducibility)
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();

        // Allocate base f32 weights
        weights1_f32 = try allocator.alloc(f32, weights1_size);
        defer allocator.free(weights1_f32);
        biases1_f32 = try allocator.alloc(f32, config.hidden_size);
        defer allocator.free(biases1_f32);
        weights2_f32 = try allocator.alloc(f32, weights2_size);
        defer allocator.free(weights2_f32);
        biases2_f32 = try allocator.alloc(f32, config.output_size);
        defer allocator.free(biases2_f32);

        // Initialize with Xavier initialization
        const scale1 = std.math.sqrt(2.0 / @as(f32, @floatFromInt(config.input_size)));
        for (0..weights1_size) |i| {
            weights1_f32[i] = random.floatNorm(f32) * scale1;
        }
        for (0..config.hidden_size) |i| {
            biases1_f32[i] = 0;
        }

        const scale2 = std.math.sqrt(2.0 / @as(f32, @floatFromInt(config.hidden_size)));
        for (0..weights2_size) |i| {
            weights2_f32[i] = random.floatNorm(f32) * scale2;
        }
        for (0..config.output_size) |i| {
            biases2_f32[i] = 0;
        }
    }

    std.debug.print("\nRunning inference benchmarks...\n", .{});

    // Run inference for each format with REAL quantization
    const result_f32 = runMNISTInference(allocator, &mnist_data, &mnist_labels, weights1_f32, biases1_f32, weights2_f32, biases2_f32, config, num_samples, .fp32);
    const result_fp16 = runMNISTInference(allocator, &mnist_data, &mnist_labels, weights1_f32, biases1_f32, weights2_f32, biases2_f32, config, num_samples, .fp16);
    const result_bf16 = runMNISTInference(allocator, &mnist_data, &mnist_labels, weights1_f32, biases1_f32, weights2_f32, biases2_f32, config, num_samples, .bf16);
    const result_gf16 = runMNISTInference(allocator, &mnist_data, &mnist_labels, weights1_f32, biases1_f32, weights2_f32, biases2_f32, config, num_samples, .gf16);
    const result_ternary = runMNISTInference(allocator, &mnist_data, &mnist_labels, weights1_f32, biases1_f32, weights2_f32, biases2_f32, config, num_samples, .ternary);

    // Print results
    std.debug.print("\n┌──────────┬─────────────┬──────────┬──────────────────┐\n", .{});
    std.debug.print("│ Format  │ Accuracy % │ Loss     │ Bytes/weight     │\n", .{});
    std.debug.print("├──────────┼─────────────┼──────────┼──────────────────┤\n", .{});
    std.debug.print("│ f32      │ {d:9.2}   │ {d:8.4} │ 4                │\n", .{ result_f32.accuracy, result_f32.loss });
    std.debug.print("│ fp16     │ {d:9.2}   │ {d:8.4} │ 2                │\n", .{ result_fp16.accuracy, result_fp16.loss });
    std.debug.print("│ bf16     │ {d:9.2}   │ {d:8.4} │ 2                │\n", .{ result_bf16.accuracy, result_bf16.loss });
    std.debug.print("│ GF16     │ {d:9.2}   │ {d:8.4} │ 2                │\n", .{ result_gf16.accuracy, result_gf16.loss });
    std.debug.print("│ ternary  │ {d:9.2}   │ {d:8.4} │ 1                │\n", .{ result_ternary.accuracy, result_ternary.loss });
    std.debug.print("└──────────┴─────────────┴──────────┴──────────────────┘\n\n", .{});

    // Show accuracy gap relative to f32
    std.debug.print("Accuracy gap vs f32:\n", .{});
    const fp16_gap = result_fp16.accuracy - result_f32.accuracy;
    const bf16_gap = result_bf16.accuracy - result_f32.accuracy;
    const gf16_gap = result_gf16.accuracy - result_f32.accuracy;
    const ternary_gap = result_ternary.accuracy - result_f32.accuracy;
    std.debug.print("  fp16:    {s}{d:.2}%\n", .{ if (fp16_gap >= 0) "+" else "", fp16_gap });
    std.debug.print("  bf16:    {s}{d:.2}%\n", .{ if (bf16_gap >= 0) "+" else "", bf16_gap });
    std.debug.print("  GF16:    {s}{d:.2}%\n", .{ if (gf16_gap >= 0) "+" else "", gf16_gap });
    std.debug.print("  ternary: {s}{d:.2}%\n", .{ if (ternary_gap >= 0) "+" else "", ternary_gap });
    std.debug.print("\n", .{});

    // Ensure results directory exists
    try std.fs.cwd().makePath("results");

    // Write CSV
    const csv_path = "results/mnist_summary.csv";
    const file = try std.fs.cwd().createFile(csv_path, .{});
    defer file.close();

    // Format CSV data
    var csv_data: [1024]u8 = undefined;
    const csv = try std.fmt.bufPrint(&csv_data,
        \\format,accuracy_percent,loss,size_bytes
        \\f32,{d:.2},{d:.4},4
        \\fp16,{d:.2},{d:.4},2
        \\bf16,{d:.2},{d:.4},2
        \\gf16,{d:.2},{d:.4},2
        \\ternary,{d:.2},{d:.4},1
        \\
    , .{ result_f32.accuracy, result_f32.loss, result_fp16.accuracy, result_fp16.loss, result_bf16.accuracy, result_bf16.loss, result_gf16.accuracy, result_gf16.loss, result_ternary.accuracy, result_ternary.loss });

    try file.writeAll(csv);

    std.debug.print("CSV written to: {s}\n", .{csv_path});

    // Clean up loaded weights if any
    if (loaded_weights) |*lw| {
        lw.deinit();
    }

    return {};
}

const InferenceResult = struct {
    accuracy: f64,
    loss: f64,
};

const Format = enum {
    fp32,
    fp16,
    bf16,
    gf16,
    ternary,
};

/// Run MNIST inference with specified format quantization
/// Weights are quantized once at initialization, then used for all samples
fn runMNISTInference(
    allocator: std.mem.Allocator,
    mnist_data: *const mnist.MNIST,
    mnist_labels: *const mnist.Labels,
    weights1_f32: []const f32,
    biases1_f32: []const f32,
    weights2_f32: []const f32,
    biases2_f32: []const f32,
    config: LayerConfig,
    num_samples: usize,
    fmt: Format,
) InferenceResult {
    const formats_fmt = switch (fmt) {
        .fp32 => formats.Format.fp32,
        .fp16 => formats.Format.fp16,
        .bf16 => formats.Format.bf16,
        .gf16 => formats.Format.gf16,
        .ternary => formats.Format.ternary,
    };

    // Quantize weights to target format
    const weights1_q = quantizeWeights(allocator, weights1_f32, formats_fmt) catch unreachable;
    defer allocator.free(weights1_q);
    const biases1_q = quantizeWeights(allocator, biases1_f32, formats_fmt) catch unreachable;
    defer allocator.free(biases1_q);
    const weights2_q = quantizeWeights(allocator, weights2_f32, formats_fmt) catch unreachable;
    defer allocator.free(weights2_q);
    const biases2_q = quantizeWeights(allocator, biases2_f32, formats_fmt) catch unreachable;
    defer allocator.free(biases2_q);

    var correct: usize = 0;
    var total_loss: f64 = 0;

    // Pre-allocate buffers
    const hidden = allocator.alloc(f32, config.hidden_size) catch unreachable;
    defer allocator.free(hidden);
    const output = allocator.alloc(f32, config.output_size) catch unreachable;
    defer allocator.free(output);
    const input = allocator.alloc(f32, config.input_size) catch unreachable;
    defer allocator.free(input);

    for (0..num_samples) |i| {
        // Load and normalize image
        const image_raw = mnist_data.getImage(i);
        for (0..config.input_size) |j| {
            input[j] = @as(f32, @floatFromInt(image_raw[j])) / 255.0;
        }

        // Forward pass with quantized weights
        forwardPassQuantized(input, weights1_q, biases1_q, weights2_q, biases2_q, config, hidden, output, formats_fmt);

        // Find prediction (argmax)
        var max_val: f32 = output[0];
        var pred_idx: usize = 0;
        {
            var j: usize = 1;
            while (j < output.len) : (j += 1) {
                if (output[j] > max_val) {
                    max_val = output[j];
                    pred_idx = j;
                }
            }
        }

        const target = mnist_labels.get(i);
        if (pred_idx == @as(usize, @intCast(target))) correct += 1;

        // Cross-entropy loss (simplified)
        var max_output: f32 = output[0];
        {
            var j: usize = 1;
            while (j < output.len) : (j += 1) {
                max_output = @max(max_output, output[j]);
            }
        }
        var sum_exp: f32 = 0;
        {
            var j: usize = 0;
            while (j < output.len) : (j += 1) {
                sum_exp += @exp(output[j] - max_output);
            }
        }
        const log_sum = @log(sum_exp) + max_output;
        const target_idx: usize = @intCast(target);
        total_loss += @as(f64, log_sum - output[target_idx]);
    }

    return InferenceResult{
        .accuracy = @as(f64, @floatFromInt(correct)) * 100.0 / @as(f64, @floatFromInt(num_samples)),
        .loss = total_loss / @as(f64, @floatFromInt(num_samples)),
    };
}

/// Quantize f32 weights to target format, returns f32 array with quantized values
fn quantizeWeights(allocator: std.mem.Allocator, src: []const f32, fmt: formats.Format) ![]f32 {
    const dst = try allocator.alloc(f32, src.len);
    for (src, 0..) |val, i| {
        dst[i] = formats.quantizeValue(val, fmt);
    }
    return dst;
}

/// Forward pass with pre-quantized weights (stored as f32 for convenience)
fn forwardPassQuantized(
    input: []const f32,
    weights1: []const f32, // Already quantized
    biases1: []const f32,
    weights2: []const f32, // Already quantized
    biases2: []const f32,
    config: LayerConfig,
    hidden: []f32,
    output: []f32,
    fmt: formats.Format,
) void {
    _ = fmt; // Format-specific arithmetic paths to be added

    // Hidden layer: h = relu(W1 * x + b1)
    for (0..config.hidden_size) |h| {
        var sum: f32 = biases1[h];
        for (0..config.input_size) |i| {
            sum += input[i] * weights1[h * config.input_size + i];
        }
        hidden[h] = relu(sum);
    }

    // Output layer: y = W2 * h + b2
    for (0..config.output_size) |o| {
        var sum: f32 = biases2[o];
        for (0..config.hidden_size) |h| {
            sum += hidden[h] * weights2[o * config.hidden_size + h];
        }
        output[o] = sum;
    }
}
