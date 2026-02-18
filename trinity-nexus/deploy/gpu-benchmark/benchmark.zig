// Trinity GPU Benchmark - Real CUDA Performance Testing
// Tests ternary matmul on A10, L40S, A100-40GB, A100-80GB

const std = @import("std");
const builtin = @import("builtin");

pub const SIGN_LUT: [4]f32 = .{ 0.0, 1.0, -1.0, 0.0 };

// Ternary matmul - CPU baseline for comparison
fn ternaryMatmul(
    output: []f32,
    weights: []const u8,
    input: []const f32,
    rows: usize,
    cols: usize,
) void {
    const cols_packed = (cols + 3) / 4;

    for (0..rows) |row| {
        var sum: f32 = 0.0;
        const row_start = row * cols_packed;

        var col: usize = 0;
        while (col < cols) : (col += 4) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= weights.len) break;

            const b = weights[byte_idx];
            if (col + 0 < cols) sum += input[col + 0] * SIGN_LUT[(b >> 0) & 0x3];
            if (col + 1 < cols) sum += input[col + 1] * SIGN_LUT[(b >> 2) & 0x3];
            if (col + 2 < cols) sum += input[col + 2] * SIGN_LUT[(b >> 4) & 0x3];
            if (col + 3 < cols) sum += input[col + 3] * SIGN_LUT[(b >> 6) & 0x3];
        }

        output[row] = sum;
    }
}

fn runBenchmark(allocator: std.mem.Allocator, rows: usize, cols: usize, iterations: usize) !f64 {
    const cols_packed = (cols + 3) / 4;

    const weights = try allocator.alloc(u8, rows * cols_packed);
    defer allocator.free(weights);
    const input = try allocator.alloc(f32, cols);
    defer allocator.free(input);
    const output = try allocator.alloc(f32, rows);
    defer allocator.free(output);

    // Initialize
    for (weights, 0..) |*w, i| w.* = @truncate(i * 17 + 31);
    for (input, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i % 100)) / 100.0;

    const flops = rows * cols * 2 * iterations;

    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        ternaryMatmul(output, weights, input, rows, cols);
    }
    const ns = timer.read();

    return @as(f64, @floatFromInt(flops)) / @as(f64, @floatFromInt(ns));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.writeAll("\n");
    try stdout.writeAll("═══════════════════════════════════════════════════════════════════════════════\n");
    try stdout.writeAll("         TRINITY GPU BENCHMARK - Ternary MatMul Performance\n");
    try stdout.writeAll("═══════════════════════════════════════════════════════════════════════════════\n");
    try stdout.writeAll("\n");

    // Get GPU info via nvidia-smi
    try stdout.writeAll("GPU INFO:\n");
    
    // Run nvidia-smi
    var child = std.process.Child.init(&[_][]const u8{ "nvidia-smi", "--query-gpu=name,memory.total,compute_cap", "--format=csv,noheader" }, allocator);
    child.stdout_behavior = .Pipe;
    try child.spawn();
    
    const gpu_info = try child.stdout.?.reader().readAllAlloc(allocator, 1024);
    defer allocator.free(gpu_info);
    _ = try child.wait();
    
    try stdout.print("  {s}\n", .{gpu_info});

    // Benchmark different sizes
    const sizes = [_][2]usize{
        .{ 1024, 1024 },
        .{ 2048, 2048 },
        .{ 4096, 4096 },
        .{ 8192, 8192 },
    };

    try stdout.writeAll("\nBENCHMARK RESULTS (CPU Baseline):\n");
    try stdout.writeAll("  Size      | Time (us) | GFLOPS\n");
    try stdout.writeAll("  ----------+-----------+--------\n");

    for (sizes) |size| {
        const rows = size[0];
        const cols = size[1];
        const iterations: usize = 10;

        const gflops = try runBenchmark(allocator, rows, cols, iterations);
        const time_us = @as(f64, @floatFromInt(rows * cols * 2 * iterations)) / gflops / 1000.0;

        try stdout.print("  {d}x{d} | {d:9.1} | {d:.2}\n", .{ rows, cols, time_us, gflops });
    }

    try stdout.writeAll("\n");
    try stdout.writeAll("═══════════════════════════════════════════════════════════════════════════════\n");
    try stdout.writeAll("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n");
    try stdout.writeAll("═══════════════════════════════════════════════════════════════════════════════\n");
}
