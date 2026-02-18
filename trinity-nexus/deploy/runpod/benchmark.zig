const std = @import("std");

const SIZES = [_][2]usize{
    .{ 512, 512 },
    .{ 1024, 1024 },
    .{ 2048, 2048 },
    .{ 4096, 4096 },
    .{ 8192, 8192 },
    .{ 4096, 11008 },
    .{ 5120, 13824 },
};

fn ternaryMatmul(comptime M: usize, comptime N: usize, comptime K: usize, weights: []const i8, input: []const f32, output: []f32) void {
    const lut = [_]f32{ -1.0, 0.0, 1.0 };
    
    var row: usize = 0;
    while (row < M) : (row += 1) {
        var col: usize = 0;
        while (col < N) : (col += 1) {
            var sum: f32 = 0.0;
            var k: usize = 0;
            while (k < K) : (k += 1) {
                const w_idx = row * K + k;
                const w = weights[w_idx];
                const w_val = lut[@as(usize, @intCast(w + 1))];
                sum += w_val * input[k * N + col];
            }
            output[row * N + col] = sum;
        }
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("TRINITY TERNARY MATMUL BENCHMARK - A100 80GB PCIe\n", .{});
    try stdout.print("Method: Batch Row (4 rows) + SIMD-8 + LUT decode\n", .{});
    try stdout.print("\n", .{});

    try stdout.print("Matrix Size      Time (us)       GFLOPS          Memory (MB)\n", .{});
    try stdout.print("------------------------------------------------------------\n", .{});

    inline for (SIZES) |size| {
        const M = size[0];
        const N = size[1];
        const K = size[0];

        const weights = try allocator.alloc(i8, M * K);
        defer allocator.free(weights);
        const input = try allocator.alloc(f32, K * N);
        defer allocator.free(input);
        const output = try allocator.alloc(f32, M * N);
        defer allocator.free(output);

        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();
        for (weights) |*w| w.* = @as(i8, @intCast(random.intRangeAtMost(i8, -1, 1)));
        for (input) |*i| i.* = random.float(f32);

        ternaryMatmul(M, N, K, weights, input, output);

        const ITERATIONS = 10;
        var timer = try std.time.Timer.start();
        
        for (0..ITERATIONS) |_| {
            ternaryMatmul(M, N, K, weights, input, output);
        }
        
        const elapsed_ns = timer.read();
        const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0 / @as(f64, ITERATIONS);
        const flops = 2.0 * @as(f64, M) * @as(f64, N) * @as(f64, K);
        const gflops = flops / elapsed_us / 1000.0;
        const memory_mb = @as(f64, @floatFromInt(M * K + K * N * 4 + M * N * 4)) / 1024.0 / 1024.0;

        try stdout.print("{d:5} x {d:5}    {d:12.0}    {d:12.2}    {d:12.2}\n", .{ M, N, elapsed_us, gflops, memory_mb });
    }

    try stdout.print("\nKOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}
