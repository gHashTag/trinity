//! BENCH-F0.2: CIFAR-10 CNN Benchmark with Real Quantization
//!
//! Compare accuracy degradation on CIFAR-10 test set with actual
//! format quantization (GF16, fp16, bf16 vs fp32 baseline).
//!
//! Model: Small CNN — Conv(3→16)→ReLU→Pool → Conv(16→32)→ReLU→Pool → FC(2048→128) → FC(128→10)
//!
//! Usage:
//!   bench-cifar10                      # Random weights (sanity-check)
//!   bench-cifar10 --weights=weights.bin  # Trained weights
//!
//

const std = @import("std");
const cifar10_loader = @import("cifar10_loader.zig");
const formats = @import("formats.zig");

const LayerConfig = struct {
    input_height: u32,
    input_width: u32,
    input_channels: u32,
    conv1_out: u32,
    conv1_kernel: u32,
    pool1_kernel: u32,
    conv2_out: u32,
    conv2_kernel: u32,
    pool2_kernel: u32,
    fc1_out: u32,
    output_size: u32,
};

fn relu(x: f32) f32 {
    return if (x > 0) x else 0;
}

/// Load trained weights from binary file
/// Expected layout: conv1_w (1440 floats) -> conv1_b (16 floats) ->
///                   conv2_w (4608 floats) -> conv2_b (32 floats) ->
///                   fc1_w (262144 floats) -> fc1_b (128 floats) ->
///                   fc2_w (1280 floats) -> fc2_b (10 floats)
/// Total: 268,650 floats × 4 bytes = 1,074,600 bytes
fn loadWeights(
    allocator: std.mem.Allocator,
    path: []const u8,
    conv1_w: *[]f32,
    conv1_b: *[]f32,
    conv2_w: *[]f32,
    conv2_b: *[]f32,
    fc1_w: *[]f32,
    fc1_b: *[]f32,
    fc2_w: *[]f32,
    fc2_b: *[]f32,
) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_stat = try file.stat();
    const expected_size: usize = 268_650 * 4; // 1,074,600 bytes

    if (file_stat.size != expected_size) {
        std.debug.print("ERROR: Expected {d} bytes, got {d}\n", .{ expected_size, file_stat.size });
        return error.InvalidData;
    }

    const buffer = try allocator.alloc(u8, expected_size);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);

    var offset: usize = 0;

    // conv1_w: 3×16×3×3 = 1440 floats
    conv1_w.* = try allocator.alloc(f32, 1440);
    for (0..1440) |i| {
        const i32_val = std.mem.readInt(u32, buffer[offset..][0..4], .little);
        conv1_w.*[i] = @bitCast(i32_val);
        offset += 4;
    }

    // conv1_b: 16 floats
    conv1_b.* = try allocator.alloc(f32, 16);
    for (0..16) |i| {
        const i32_val = std.mem.readInt(u32, buffer[offset..][0..4], .little);
        conv1_b.*[i] = @bitCast(i32_val);
        offset += 4;
    }

    // conv2_w: 16×32×3×3 = 4608 floats
    conv2_w.* = try allocator.alloc(f32, 4608);
    for (0..4608) |i| {
        const i32_val = std.mem.readInt(u32, buffer[offset..][0..4], .little);
        conv2_w.*[i] = @bitCast(i32_val);
        offset += 4;
    }

    // conv2_b: 32 floats
    conv2_b.* = try allocator.alloc(f32, 32);
    for (0..32) |i| {
        const i32_val = std.mem.readInt(u32, buffer[offset..][0..4], .little);
        conv2_b.*[i] = @bitCast(i32_val);
        offset += 4;
    }

    // fc1_w: 2048×128 = 262,144 floats
    fc1_w.* = try allocator.alloc(f32, 262144);
    for (0..262144) |i| {
        const i32_val = std.mem.readInt(u32, buffer[offset..][0..4], .little);
        fc1_w.*[i] = @bitCast(i32_val);
        offset += 4;
    }

    // fc1_b: 128 floats
    fc1_b.* = try allocator.alloc(f32, 128);
    for (0..128) |i| {
        const i32_val = std.mem.readInt(u32, buffer[offset..][0..4], .little);
        fc1_b.*[i] = @bitCast(i32_val);
        offset += 4;
    }

    // fc2_w: 128×10 = 1,280 floats
    fc2_w.* = try allocator.alloc(f32, 1280);
    for (0..1280) |i| {
        const i32_val = std.mem.readInt(u32, buffer[offset..][0..4], .little);
        fc2_w.*[i] = @bitCast(i32_val);
        offset += 4;
    }

    // fc2_b: 10 floats
    fc2_b.* = try allocator.alloc(f32, 10);
    for (0..10) |i| {
        const i32_val = std.mem.readInt(u32, buffer[offset..][0..4], .little);
        fc2_b.*[i] = @bitCast(i32_val);
        offset += 4;
    }

    std.debug.print("Loaded weights: conv1={d}, conv2={d}, fc1={d}, fc2={d}\n", .{
        conv1_w.*.len, conv2_w.*.len, fc1_w.*.len, fc2_w.*.len });
}

pub fn main() !void {
    const config = LayerConfig{
        .input_height = 32,
        .input_width = 32,
        .input_channels = 3,
        .conv1_out = 16,
        .conv1_kernel = 3,
        .pool1_kernel = 2,
        .conv2_out = 32,
        .conv2_kernel = 3,
        .pool2_kernel = 2,
        .fc1_out = 128,
        .output_size = 10,
    };

    const allocator = std.heap.c_allocator;

    // Parse command line args for --weights flag
    // Supports both: --weights value and --weights=value
    var weights_path: ?[]const u8 = blk: {
        var idx: usize = 1;
        while (idx < std.os.argv.len) : (idx += 1) {
            const arg = spanZ(std.os.argv[idx]);

            // Check for --weights=value format
            if (startsWith(arg, "--weights=")) {
                break :blk arg["--weights=".len..];
            }

            // Check for --weights value format
            if (strEql(std.os.argv[idx], "--weights")) {
                if (idx + 1 < std.os.argv.len) {
                    break :blk spanZ(std.os.argv[idx + 1]);
                }
            }
        }
        break :blk null;
    };

    // Load CIFAR-10 test data (data_dir = "data")
    const data_dir = "data";
    const loader = cifar10_loader.CIFAR10Loader.init();
    var test_data = loader.loadTest(allocator, data_dir) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("\nERROR: CIFAR-10 test file not found.\n", .{});
            std.debug.print("Expected: data/test_batch.bin\n", .{});
            std.debug.print("Create data/ directory and place test_batch.bin there.\n", .{});
            return err;
        }
        return err;
    };
    defer test_data.deinit(allocator);

    const num_samples = test_data.len();
    std.debug.print("Loaded {d} test images\n\n", .{num_samples});

    // Load weights or generate random
    var conv1_weights_f32: []f32 = undefined;
    var conv1_biases_f32: []f32 = undefined;
    var conv2_weights_f32: []f32 = undefined;
    var conv2_biases_f32: []f32 = undefined;
    var fc1_weights_f32: []f32 = undefined;
    var fc1_biases_f32: []f32 = undefined;
    var fc2_weights_f32: []f32 = undefined;
    var fc2_biases_f32: []f32 = undefined;

    if (weights_path) |path| {
        std.debug.print("Loading trained weights from: {s}\n", .{path});
        loadWeights(allocator, path, &conv1_weights_f32, &conv1_biases_f32, &conv2_weights_f32, &conv2_biases_f32, &fc1_weights_f32, &fc1_biases_f32, &fc2_weights_f32, &fc2_biases_f32) catch |err| {
            std.debug.print("Failed to load weights: {s}\n", .{@errorName(err)});
            std.debug.print("Using random weights instead.\n", .{});
            // Fall through to random init below
            weights_path = null;
        };
    }

    if (weights_path == null) {
        std.debug.print("Using random weights (Xavier init, seed=42)\n", .{});

        // Generate random weights
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();

        // Xavier initialization scale: sqrt(2 / fan_in)
        const conv1_scale = std.math.sqrt(2.0 / @as(f32, @floatFromInt(config.input_channels * config.conv1_kernel * config.conv1_kernel)));
        const conv2_scale = std.math.sqrt(2.0 / @as(f32, @floatFromInt(config.conv1_out * config.conv2_kernel * config.conv2_kernel)));

        // FC1: fan_in is fc1_out
        const fc1_scale = std.math.sqrt(2.0 / @as(f32, @floatFromInt(config.fc1_out)));

        // FC2: fan_in is fc1_out
        const fc2_scale = std.math.sqrt(2.0 / @as(f32, @floatFromInt(config.fc1_out)));

        // Conv1 weights
        conv1_weights_f32 = try allocator.alloc(f32, 1440);
        defer allocator.free(conv1_weights_f32);
        conv1_biases_f32 = try allocator.alloc(f32, 16);
        defer allocator.free(conv1_biases_f32);

        for (0..1440) |i| {
            conv1_weights_f32[i] = random.floatNorm(f32) * conv1_scale;
        }
        for (0..16) |i| {
            conv1_biases_f32[i] = 0;
        }

        // Conv2 weights
        conv2_weights_f32 = try allocator.alloc(f32, 4608);
        defer allocator.free(conv2_weights_f32);
        conv2_biases_f32 = try allocator.alloc(f32, 32);
        defer allocator.free(conv2_biases_f32);

        for (0..4608) |i| {
            conv2_weights_f32[i] = random.floatNorm(f32) * conv2_scale;
        }
        for (0..32) |i| {
            conv2_biases_f32[i] = 0;
        }

        // FC1 weights
        fc1_weights_f32 = try allocator.alloc(f32, 262144);
        defer allocator.free(fc1_weights_f32);
        fc1_biases_f32 = try allocator.alloc(f32, 128);
        defer allocator.free(fc1_biases_f32);

        for (0..262144) |i| {
            fc1_weights_f32[i] = random.floatNorm(f32) * fc1_scale;
        }
        for (0..128) |i| {
            fc1_biases_f32[i] = 0;
        }

        // FC2 weights (no bias for output layer)
        fc2_weights_f32 = try allocator.alloc(f32, 1280);
        defer allocator.free(fc2_weights_f32);
        fc2_biases_f32 = try allocator.alloc(f32, 10);
        defer allocator.free(fc2_biases_f32);

        for (0..1280) |i| {
            fc2_weights_f32[i] = random.floatNorm(f32) * fc2_scale;
        }
        for (0..10) |i| {
            fc2_biases_f32[i] = 0;
        }
    }

    std.debug.print("\nRunning inference benchmarks...\n", .{});

    // Run inference for each format
    const result_f32 = runCIFAR10Inference(allocator, &test_data, conv1_weights_f32, conv1_biases_f32, conv2_weights_f32, conv2_biases_f32, fc1_weights_f32, fc1_biases_f32, fc2_weights_f32, fc2_biases_f32, config, num_samples, .fp32);
    const result_fp16 = runCIFAR10Inference(allocator, &test_data, conv1_weights_f32, conv1_biases_f32, conv2_weights_f32, conv2_biases_f32, fc1_weights_f32, fc1_biases_f32, fc2_weights_f32, fc2_biases_f32, config, num_samples, .fp16);
    const result_bf16 = runCIFAR10Inference(allocator, &test_data, conv1_weights_f32, conv1_biases_f32, conv2_weights_f32, conv2_biases_f32, fc1_weights_f32, fc1_biases_f32, fc2_weights_f32, fc2_biases_f32, config, num_samples, .bf16);
    const result_gf16 = runCIFAR10Inference(allocator, &test_data, conv1_weights_f32, conv1_biases_f32, conv2_weights_f32, conv2_biases_f32, fc1_weights_f32, fc1_biases_f32, fc2_weights_f32, fc2_biases_f32, config, num_samples, .gf16);

    // Print results
    std.debug.print("\n┌──────────┬─────────────┬──────────┬──────────────────┐\n", .{});
    std.debug.print("│ Format  │ Accuracy % │ Loss     │ Bytes/weight     │\n", .{});
    std.debug.print("├──────────┼─────────────┼──────────┼──────────────────┤\n", .{});
    std.debug.print("│ f32      │ {d:9.2}   │ {d:8.4} │ 4                │\n", .{ result_f32.accuracy, result_f32.loss });
    std.debug.print("│ fp16     │ {d:9.2}   │ {d:8.4} │ 2                │\n", .{ result_fp16.accuracy, result_fp16.loss });
    std.debug.print("│ bf16     │ {d:9.2}   │ {d:8.4} │ 2                │\n", .{ result_bf16.accuracy, result_bf16.loss });
    std.debug.print("│ GF16     │ {d:9.2}   │ {d:8.4} │ 2                │\n", .{ result_gf16.accuracy, result_gf16.loss });
    std.debug.print("└──────────┴─────────────┴──────────┴──────────────────┘\n\n", .{});

    // Show accuracy gap relative to f32
    std.debug.print("Accuracy gap vs f32:\n", .{});
    const fp16_gap = result_fp16.accuracy - result_f32.accuracy;
    const bf16_gap = result_bf16.accuracy - result_f32.accuracy;
    const gf16_gap = result_gf16.accuracy - result_f32.accuracy;
    std.debug.print("  fp16:    {s}{d:.2}%\n", .{ if (fp16_gap >= 0) "+" else "", fp16_gap });
    std.debug.print("  bf16:    {s}{d:.2}%\n", .{ if (bf16_gap >= 0) "+" else "", bf16_gap });
    std.debug.print("  GF16:    {s}{d:.2}%\n", .{ if (gf16_gap >= 0) "+" else "", gf16_gap });
    std.debug.print("\n", .{});

    // Ensure results directory exists
    try std.fs.cwd().makePath("results");

    // Write JSON output
    const json_path = "results/cifar10_metrics.json";
    const json_file = try std.fs.cwd().createFile(json_path, .{});
    defer json_file.close();

    const json = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "dataset": "CIFAR-10",
        \\  "architecture": "CNN Conv({d})→Pool→Conv({d})→Pool→FC({d})→FC({d})",
        \\  "samples": {d},
        \\  "results": {{
        \\    "f32": {{ "accuracy_percent": {d:.2}, "loss": {d:.4} }},
        \\    "fp16": {{ "accuracy_percent": {d:.2}, "loss": {d:.4} }},
        \\    "bf16": {{ "accuracy_percent": {d:.2}, "loss": {d:.4} }},
        \\    "gf16": {{ "accuracy_percent": {d:.2}, "loss": {d:.4} }}
        \\}}
        \\}}
        \\
        , .{
            config.input_channels, config.conv1_out, config.conv2_out, config.fc1_out,
            num_samples,
            result_f32.accuracy, result_f32.loss,
            result_fp16.accuracy, result_fp16.loss,
            result_bf16.accuracy, result_bf16.loss,
            result_gf16.accuracy, result_gf16.loss,
        });

    try json_file.writeAll(json);
    std.debug.print("JSON written to: {s}\n", .{json_path});

    // Also write CSV for compatibility
    const csv_path = "results/cifar10_summary.csv";
    const csv_file = try std.fs.cwd().createFile(csv_path, .{});
    defer csv_file.close();

    var csv_data: [1024]u8 = undefined;
    const csv = try std.fmt.bufPrint(&csv_data,
        \\format,accuracy_percent,loss,size_bytes
        \\f32,{d:.2},{d:.4},4
        \\fp16,{d:.2},{d:.4},2
        \\bf16,{d:.2},{d:.4},2
        \\gf16,{d:.2},{d:.4},2
        \\
        , .{
            result_f32.accuracy, result_f32.loss,
            result_fp16.accuracy, result_fp16.loss,
            result_bf16.accuracy, result_bf16.loss,
            result_gf16.accuracy, result_gf16.loss,
        });
    try csv_file.writeAll(csv);
    std.debug.print("CSV written to: {s}\n", .{csv_path});

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
};

/// Run CIFAR-10 CNN inference with specified format quantization
/// Weights are quantized once at initialization, then used for all samples
fn runCIFAR10Inference(
    allocator: std.mem.Allocator,
    test_data: *const cifar10_loader.Dataset,
    conv1_weights_f32: []const f32,
    conv1_biases_f32: []const f32,
    conv2_weights_f32: []const f32,
    conv2_biases_f32: []const f32,
    fc1_weights_f32: []const f32,
    fc1_biases_f32: []const f32,
    fc2_weights_f32: []const f32,
    fc2_biases_f32: []const f32,
    config: LayerConfig,
    num_samples: usize,
    fmt: Format,
) InferenceResult {
    const formats_fmt = switch (fmt) {
        .fp32 => formats.Format.fp32,
        .fp16 => formats.Format.fp16,
        .bf16 => formats.Format.bf16,
        .gf16 => formats.Format.gf16,
    };

    // Quantize weights to target format
    const conv1_w_q = quantizeWeights(allocator, conv1_weights_f32, formats_fmt) catch unreachable;
    defer allocator.free(conv1_w_q);
    const conv1_b_q = quantizeWeights(allocator, conv1_biases_f32, formats_fmt) catch unreachable;
    defer allocator.free(conv1_b_q);
    const conv2_w_q = quantizeWeights(allocator, conv2_weights_f32, formats_fmt) catch unreachable;
    defer allocator.free(conv2_w_q);
    const conv2_b_q = quantizeWeights(allocator, conv2_biases_f32, formats_fmt) catch unreachable;
    defer allocator.free(conv2_b_q);
    const fc1_w_q = quantizeWeights(allocator, fc1_weights_f32, formats_fmt) catch unreachable;
    defer allocator.free(fc1_w_q);
    const fc1_b_q = quantizeWeights(allocator, fc1_biases_f32, formats_fmt) catch unreachable;
    defer allocator.free(fc1_b_q);
    const fc2_w_q = quantizeWeights(allocator, fc2_weights_f32, formats_fmt) catch unreachable;
    defer allocator.free(fc2_w_q);
    const fc2_b_q = quantizeWeights(allocator, fc2_biases_f32, formats_fmt) catch unreachable;
    defer allocator.free(fc2_b_q);

    // Calculate dimensions
    const pool1_out_h = config.input_height / config.pool1_kernel; // 32/2 = 16
    const pool1_out_w = config.input_width / config.pool1_kernel;  // 32/2 = 16
    const pool2_out_h = pool1_out_h / config.pool2_kernel;   // 16/2 = 8
    const pool2_out_w = pool1_out_w / config.pool2_kernel;   // 16/2 = 8
    const fc1_input_size = pool2_out_h * pool2_out_w * config.conv2_out; // 8*8*32 = 2048

    // Pre-allocate buffers
    const conv1_out = allocator.alloc(f32, 16384) catch unreachable;
    defer allocator.free(conv1_out);
    const pool1_out = allocator.alloc(f32, 4096) catch unreachable;
    defer allocator.free(pool1_out);
    const conv2_out = allocator.alloc(f32, 8192) catch unreachable;
    defer allocator.free(conv2_out);
    const pool2_out = allocator.alloc(f32, 2048) catch unreachable;
    defer allocator.free(pool2_out);
    const fc1_out = allocator.alloc(f32, 128) catch unreachable;
    defer allocator.free(fc1_out);
    const fc2_out = allocator.alloc(f32, 10) catch unreachable;
    defer allocator.free(fc2_out);

    var correct: usize = 0;
    var total_loss: f64 = 0;

    for (0..num_samples) |i| {
        const sample = test_data.get(i);
        const input = sample.flatten();

        // Conv1: input (3072) -> conv1_out (16384)
        formats.conv2d(
            input,
            conv1_w_q,
            conv1_b_q,
            conv1_out,
            .{
                .in_channels = config.input_channels,
                .out_channels = config.conv1_out,
                .in_height = config.input_height,
                .in_width = config.input_width,
                .kernel_size = config.conv1_kernel,
                .stride = 1,
                .padding = 1,
            },
        );

        // ReLU
        var j: usize = 0;
        while (j < conv1_out.len) : (j += 1) {
            conv1_out[j] = relu(conv1_out[j]);
        }

        // Pool1: conv1_out -> pool1_out (4096)
        formats.maxPool2d(
            conv1_out,
            pool1_out,
            .{
                .height = config.input_height,
                .width = config.input_width,
                .channels = config.conv1_out,
                .kernel_size = config.pool1_kernel,
                .stride = config.pool1_kernel,
            },
        );

        // Conv2: pool1_out -> conv2_out (8192)
        formats.conv2d(
            pool1_out,
            conv2_w_q,
            conv2_b_q,
            conv2_out,
            .{
                .in_channels = config.conv1_out,
                .out_channels = config.conv2_out,
                .in_height = pool1_out_h,
                .in_width = pool1_out_w,
                .kernel_size = config.conv2_kernel,
                .stride = 1,
                .padding = 1,
            },
        );

        // ReLU
        j = 0;
        while (j < conv2_out.len) : (j += 1) {
            conv2_out[j] = relu(conv2_out[j]);
        }

        // Pool2: conv2_out -> pool2_out (2048)
        formats.maxPool2d(
            conv2_out,
            pool2_out,
            .{
                .height = pool1_out_h,
                .width = pool1_out_w,
                .channels = config.conv2_out,
                .kernel_size = config.pool2_kernel,
                .stride = config.pool2_kernel,
            },
        );

        // FC1: pool2_out (2048) -> fc1_out (128)
        for (0..config.fc1_out) |o| {
            var sum: f32 = fc1_b_q[o];
            var k: usize = 0;
            while (k < fc1_input_size) : (k += 1) {
                sum += pool2_out[k] * fc1_w_q[o * fc1_input_size + k];
            }
            fc1_out[o] = relu(sum);
        }

        // FC2: fc1_out (128) -> fc2_out (10)
        for (0..config.output_size) |o| {
            var sum: f32 = fc2_b_q[o];
            var k: usize = 0;
            while (k < config.fc1_out) : (k += 1) {
                sum += fc1_out[k] * fc2_w_q[o * config.fc1_out + k];
            }
            fc2_out[o] = sum;
        }

        // Find prediction (argmax)
        var max_val: f32 = fc2_out[0];
        var pred_idx: usize = 0;
        {
            var jj: usize = 1;
            while (jj < fc2_out.len) : (jj += 1) {
                if (fc2_out[jj] > max_val) {
                    max_val = fc2_out[jj];
                    pred_idx = jj;
                }
            }
        }

        const target = sample.label;
        if (pred_idx == @as(usize, @intCast(target))) correct += 1;

        // Cross-entropy loss
        var max_output: f32 = fc2_out[0];
        {
            var jj: usize = 1;
            while (jj < fc2_out.len) : (jj += 1) {
                max_output = @max(max_output, fc2_out[jj]);
            }
        }
        var sum_exp: f32 = 0;
        {
            var jj: usize = 0;
            while (jj < fc2_out.len) : (jj += 1) {
                sum_exp += @exp(fc2_out[jj] - max_output);
            }
        }
        const log_sum = @log(sum_exp) + max_output;
        const target_idx: usize = @intCast(target);
        total_loss += @as(f64, log_sum - fc2_out[target_idx]);
    }

    return InferenceResult{
        .accuracy = @as(f64, @floatFromInt(correct)) * 100.0 / @as(f64, @floatFromInt(num_samples)),
        .loss = total_loss / @as(f64, @floatFromInt(num_samples)),
    };
}

/// Quantize f32 weights to target format, returns f32 array with quantized values
fn quantizeWeights(allocator: std.mem.Allocator, src: []const f32, fmt: formats.Format) ![]f32 {
    const dst = try allocator.alloc(f32, src.len);
    for (src, 0..) |val, idx| {
        dst[idx] = formats.quantizeValue(val, fmt);
    }
    return dst;
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
    return a[i] == 0;
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
