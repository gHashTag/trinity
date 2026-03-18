// Full Matrix Benchmark - All sizes for GPU comparison baseline
const std = @import("std");

pub const SIGN_LUT: [4]f32 = .{ 0.0, 1.0, -1.0, 0.0 };
pub const Vec8f32 = @Vector(8, f32);

inline fn decode8TritsF32(byte0: u8, byte1: u8) Vec8f32 {
    return .{
        SIGN_LUT[(byte0 >> 0) & 0x3],
        SIGN_LUT[(byte0 >> 2) & 0x3],
        SIGN_LUT[(byte0 >> 4) & 0x3],
        SIGN_LUT[(byte0 >> 6) & 0x3],
        SIGN_LUT[(byte1 >> 0) & 0x3],
        SIGN_LUT[(byte1 >> 2) & 0x3],
        SIGN_LUT[(byte1 >> 4) & 0x3],
        SIGN_LUT[(byte1 >> 6) & 0x3],
    };
}

fn batchRowTernaryMatmul(
    output: []f32,
    weights: []const u8,
    input: []const f32,
    rows: usize,
    cols: usize,
) void {
    const cols_packed = (cols + 3) / 4;

    var row: usize = 0;
    while (row + 4 <= rows) {
        var sum0: Vec8f32 = @splat(0.0);
        var sum1: Vec8f32 = @splat(0.0);
        var sum2: Vec8f32 = @splat(0.0);
        var sum3: Vec8f32 = @splat(0.0);

        const r0_start = row * cols_packed;
        const r1_start = (row + 1) * cols_packed;
        const r2_start = (row + 2) * cols_packed;
        const r3_start = (row + 3) * cols_packed;

        var col: usize = 0;
        while (col + 8 <= cols) {
            const col_byte = col / 4;
            const in_vec: Vec8f32 = input[col..][0..8].*;

            if (r0_start + col_byte + 1 < weights.len) {
                const s0 = decode8TritsF32(weights[r0_start + col_byte], weights[r0_start + col_byte + 1]);
                sum0 += in_vec * s0;
            }
            if (r1_start + col_byte + 1 < weights.len) {
                const s1 = decode8TritsF32(weights[r1_start + col_byte], weights[r1_start + col_byte + 1]);
                sum1 += in_vec * s1;
            }
            if (r2_start + col_byte + 1 < weights.len) {
                const s2 = decode8TritsF32(weights[r2_start + col_byte], weights[r2_start + col_byte + 1]);
                sum2 += in_vec * s2;
            }
            if (r3_start + col_byte + 1 < weights.len) {
                const s3 = decode8TritsF32(weights[r3_start + col_byte], weights[r3_start + col_byte + 1]);
                sum3 += in_vec * s3;
            }
            col += 8;
        }

        output[row] = @reduce(.Add, sum0);
        output[row + 1] = @reduce(.Add, sum1);
        output[row + 2] = @reduce(.Add, sum2);
        output[row + 3] = @reduce(.Add, sum3);
        row += 4;
    }

    while (row < rows) : (row += 1) {
        var sum: f32 = 0.0;
        const row_start = row * cols_packed;
        var col: usize = 0;
        while (col + 8 <= cols) {
            const byte_idx = row_start + col / 4;
            if (byte_idx + 1 >= weights.len) break;
            const in_vec: Vec8f32 = input[col..][0..8].*;
            const signs = decode8TritsF32(weights[byte_idx], weights[byte_idx + 1]);
            sum += @reduce(.Add, in_vec * signs);
            col += 8;
        }
        output[row] = sum;
    }
}

fn runBenchmark(allocator: std.mem.Allocator, rows: usize, cols: usize, iterations: usize) !struct { gflops: f64, time_us: f64 } {
    const cols_packed = (cols + 3) / 4;

    const weights = try allocator.alloc(u8, rows * cols_packed);
    defer allocator.free(weights);
    const input = try allocator.alloc(f32, cols);
    defer allocator.free(input);
    const output = try allocator.alloc(f32, rows);
    defer allocator.free(output);

    for (weights, 0..) |*w, i| w.* = @truncate(i * 17 + 31);
    for (input, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i % 100)) / 100.0;

    const flops = rows * cols * 2 * iterations;

    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        batchRowTernaryMatmul(output, weights, input, rows, cols);
    }
    const ns = timer.read();

    const gflops = @as(f64, @floatFromInt(flops)) / @as(f64, @floatFromInt(ns));
    const time_us = @as(f64, @floatFromInt(ns)) / 1000.0 / @as(f64, @floatFromInt(iterations));

    return .{ .gflops = gflops, .time_us = time_us };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.writeAll("\n");
    try stdout.writeAll("═══════════════════════════════════════════════════════════════════════════════\n");
    try stdout.writeAll("         TRINITY CPU BENCHMARK - All Matrix Sizes (Intel Xeon 8375C)\n");
    try stdout.writeAll("═══════════════════════════════════════════════════════════════════════════════\n");
    try stdout.writeAll("\n");

    const sizes = [_][2]usize{
        .{ 512, 512 },
        .{ 1024, 1024 },
        .{ 2048, 2048 },
        .{ 4096, 4096 },
        .{ 8192, 8192 },
        .{ 4096, 11008 },  // Llama-7B FFN
        .{ 4096, 4096 },   // Llama-7B attention
        .{ 5120, 13824 },  // Llama-13B FFN
    };

    try stdout.writeAll("  Matrix Size    | Time (us)  | GFLOPS  | Memory (MB)\n");
    try stdout.writeAll("  ---------------+------------+---------+------------\n");

    for (sizes) |size| {
        const rows = size[0];
        const cols = size[1];
        const iterations: usize = if (rows * cols > 16_000_000) 5 else 10;

        const result = try runBenchmark(allocator, rows, cols, iterations);
        const memory_mb = @as(f64, @floatFromInt(rows * ((cols + 3) / 4))) / (1024.0 * 1024.0);

        try stdout.print("  {d:5}x{d:5}   | {d:10.1} | {d:7.2} | {d:10.2}\n", .{
            rows, cols, result.time_us, result.gflops, memory_mb,
        });
    }

    try stdout.writeAll("\n");
    try stdout.writeAll("═══════════════════════════════════════════════════════════════════════════════\n");
    try stdout.writeAll("  CPU: Intel Xeon Platinum 8375C @ 2.90GHz\n");
    try stdout.writeAll("  Method: Batch Row (4 rows) + SIMD-8 + LUT decode\n");
    try stdout.writeAll("═══════════════════════════════════════════════════════════════════════════════\n");
    try stdout.writeAll("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n");
    try stdout.writeAll("═══════════════════════════════════════════════════════════════════════════════\n");
}
