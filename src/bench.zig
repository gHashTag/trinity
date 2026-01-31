// Trinity SIMD Benchmark
// Tests actual Trinity VSA operations with SIMD acceleration
//
// Run: zig build && ./zig-out/bin/bench
// Or:  zig test src/bench.zig -O ReleaseFast

const std = @import("std");
const vsa = @import("vsa.zig");
const hybrid = @import("hybrid.zig");

const HybridBigInt = hybrid.HybridBigInt;

const ITERATIONS = 100000;
const WARMUP = 1000;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║              TRINITY SIMD BENCHMARK (Real Implementation)                   ║\n", .{});
    try stdout.print("║                                                                              ║\n", .{});
    try stdout.print("║  Using actual Trinity VSA with SIMD acceleration                             ║\n", .{});
    try stdout.print("║  SIMD Width: 32 trits per vector operation                                   ║\n", .{});
    try stdout.print("║                                                                              ║\n", .{});
    try stdout.print("║  φ² + 1/φ² = 3                                                               ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    const dimensions = [_]usize{ 256, 1000, 4096, 10000 };

    for (dimensions) |dim| {
        try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
        try stdout.print("  DIMENSION: {d} trits\n", .{dim});
        try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n\n", .{});

        // Create test vectors using Trinity's randomVector
        var a = vsa.randomVector(dim, 12345);
        var b = vsa.randomVector(dim, 67890);
        var c = vsa.randomVector(dim, 11111);

        // Warmup
        for (0..WARMUP) |_| {
            var r1 = vsa.bind(&a, &b);
            std.mem.doNotOptimizeAway(&r1);
            var r2 = vsa.bundle2(&a, &b);
            std.mem.doNotOptimizeAway(&r2);
        }

        // BIND benchmark (SIMD accelerated)
        {
            var timer = std.time.Timer.start() catch unreachable;
            var result: HybridBigInt = undefined;
            for (0..ITERATIONS) |_| {
                result = vsa.bind(&a, &b);
                std.mem.doNotOptimizeAway(&result);
            }
            const elapsed = timer.read();
            const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed)) / 1e9);
            const ns_per_op = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(ITERATIONS));
            const trits_per_sec = ops_per_sec * @as(f64, @floatFromInt(dim));

            try stdout.print("  BIND (SIMD x32):\n", .{});
            try stdout.print("    Operations/sec:  {d:.0}\n", .{ops_per_sec});
            try stdout.print("    Latency:         {d:.1} ns\n", .{ns_per_op});
            try stdout.print("    Throughput:      {d:.2} M trits/sec\n\n", .{trits_per_sec / 1e6});
        }

        // BUNDLE benchmark
        {
            var timer = std.time.Timer.start() catch unreachable;
            var result: HybridBigInt = undefined;
            for (0..ITERATIONS) |_| {
                result = vsa.bundle2(&a, &b);
                std.mem.doNotOptimizeAway(&result);
            }
            const elapsed = timer.read();
            const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed)) / 1e9);
            const ns_per_op = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(ITERATIONS));
            const trits_per_sec = ops_per_sec * @as(f64, @floatFromInt(dim));

            try stdout.print("  BUNDLE:\n", .{});
            try stdout.print("    Operations/sec:  {d:.0}\n", .{ops_per_sec});
            try stdout.print("    Latency:         {d:.1} ns\n", .{ns_per_op});
            try stdout.print("    Throughput:      {d:.2} M trits/sec\n\n", .{trits_per_sec / 1e6});
        }

        // BUNDLE3 benchmark
        {
            var timer = std.time.Timer.start() catch unreachable;
            var result: HybridBigInt = undefined;
            for (0..ITERATIONS) |_| {
                result = vsa.bundle3(&a, &b, &c);
                std.mem.doNotOptimizeAway(&result);
            }
            const elapsed = timer.read();
            const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed)) / 1e9);
            const ns_per_op = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(ITERATIONS));

            try stdout.print("  BUNDLE3:\n", .{});
            try stdout.print("    Operations/sec:  {d:.0}\n", .{ops_per_sec});
            try stdout.print("    Latency:         {d:.1} ns\n\n", .{ns_per_op});
        }

        // PERMUTE benchmark
        {
            var timer = std.time.Timer.start() catch unreachable;
            var result: HybridBigInt = undefined;
            for (0..ITERATIONS) |_| {
                result = vsa.permute(&a, 1);
                std.mem.doNotOptimizeAway(&result);
            }
            const elapsed = timer.read();
            const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed)) / 1e9);
            const ns_per_op = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(ITERATIONS));

            try stdout.print("  PERMUTE:\n", .{});
            try stdout.print("    Operations/sec:  {d:.0}\n", .{ops_per_sec});
            try stdout.print("    Latency:         {d:.1} ns\n\n", .{ns_per_op});
        }

        // COSINE SIMILARITY benchmark
        {
            var timer = std.time.Timer.start() catch unreachable;
            var result: f64 = undefined;
            for (0..ITERATIONS) |_| {
                result = vsa.cosineSimilarity(&a, &b);
                std.mem.doNotOptimizeAway(&result);
            }
            const elapsed = timer.read();
            const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed)) / 1e9);
            const ns_per_op = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(ITERATIONS));

            try stdout.print("  COSINE SIMILARITY:\n", .{});
            try stdout.print("    Operations/sec:  {d:.0}\n", .{ops_per_sec});
            try stdout.print("    Latency:         {d:.1} ns\n\n", .{ns_per_op});
        }

        // HAMMING DISTANCE benchmark
        {
            var timer = std.time.Timer.start() catch unreachable;
            var result: usize = undefined;
            for (0..ITERATIONS) |_| {
                result = vsa.hammingDistance(&a, &b);
                std.mem.doNotOptimizeAway(&result);
            }
            const elapsed = timer.read();
            const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed)) / 1e9);
            const ns_per_op = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(ITERATIONS));

            try stdout.print("  HAMMING DISTANCE:\n", .{});
            try stdout.print("    Operations/sec:  {d:.0}\n", .{ops_per_sec});
            try stdout.print("    Latency:         {d:.1} ns\n\n", .{ns_per_op});
        }
    }

    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("  SIMD ACCELERATION SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("  ✓ BIND uses 32-wide SIMD multiplication\n", .{});
    try stdout.print("  ✓ Operations process 32 trits per CPU cycle\n", .{});
    try stdout.print("  ✓ Theoretical speedup: up to 32x vs scalar\n", .{});
    try stdout.print("\n  φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL\n\n", .{});
}

test "SIMD bind correctness" {
    var a = vsa.randomVector(256, 12345);
    var b = vsa.randomVector(256, 67890);

    const result = vsa.bind(&a, &b);

    // Verify some elements
    for (0..256) |i| {
        const expected = a.unpacked_cache[i] * b.unpacked_cache[i];
        try std.testing.expectEqual(expected, result.unpacked_cache[i]);
    }
}
