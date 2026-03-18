// Trinity Benchmark Tests
const std = @import("std");
const vsa = @import("vsa");

const ITERATIONS = 10000;

test "Benchmark Bind 1000D" {
    var a = vsa.randomVector(1000, 12345);
    var b = vsa.randomVector(1000, 67890);

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..ITERATIONS) |_| {
        _ = vsa.bind(&a, &b);
    }

    const elapsed_ns = timer.read() - start;
    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    std.debug.print("BIND 1000D: {d:.2} ops/sec ({d:.2} ns/op)\n", .{ops_per_sec, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(ITERATIONS))});
}

test "Benchmark Bundle 1000D" {
    var a = vsa.randomVector(1000, 11111);
    var b = vsa.randomVector(1000, 22222);

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..ITERATIONS) |_| {
        _ = vsa.bundle2(&a, &b);
    }

    const elapsed_ns = timer.read() - start;
    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    std.debug.print("BUNDLE 1000D: {d:.2} ops/sec ({d:.2} ns/op)\n", .{ops_per_sec, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(ITERATIONS))});
}

test "Benchmark Similarity 1000D" {
    var a = vsa.randomVector(1000, 44444);
    var b = vsa.randomVector(1000, 55555);

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..ITERATIONS) |_| {
        _ = vsa.cosineSimilarity(&a, &b);
    }

    const elapsed_ns = timer.read() - start;
    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    std.debug.print("SIMILARITY 1000D: {d:.2} ops/sec ({d:.2} ns/op)\n", .{ops_per_sec, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(ITERATIONS))});
}

test "Benchmark Bind 4000D" {
    var a = vsa.randomVector(4000, 12345);
    var b = vsa.randomVector(4000, 67890);

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..ITERATIONS) |_| {
        _ = vsa.bind(&a, &b);
    }

    const elapsed_ns = timer.read() - start;
    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    std.debug.print("BIND 4000D: {d:.2} ops/sec ({d:.2} ns/op)\n", .{ops_per_sec, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(ITERATIONS))});
}

test "Benchmark Bundle 4000D" {
    var a = vsa.randomVector(4000, 11111);
    var b = vsa.randomVector(4000, 22222);

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..ITERATIONS) |_| {
        _ = vsa.bundle2(&a, &b);
    }

    const elapsed_ns = timer.read() - start;
    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0);
    std.debug.print("BUNDLE 4000D: {d:.2} ops/sec ({d:.2} ns/op)\n", .{ops_per_sec, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(ITERATIONS))});
}

test "Benchmark Similarity 4000D" {
    var a = vsa.randomVector(4000, 44444);
    var b = vsa.randomVector(4000, 55555);

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..ITERATIONS) |_| {
        _ = vsa.cosineSimilarity(&a, &b);
    }

    const elapsed_ns = timer.read() - start;
    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    std.debug.print("SIMILARITY 4000D: {d:.2} ops/sec ({d:.2} ns/op)\n", .{ops_per_sec, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(ITERATIONS))});
}

test "Benchmark Bind 10000D" {
    var a = vsa.randomVector(10000, 12345);
    var b = vsa.randomVector(10000, 67890);

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..ITERATIONS) |_| {
        _ = vsa.bind(&a, &b);
    }

    const elapsed_ns = timer.read() - start;
    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    std.debug.print("BIND 10000D: {d:.2} ops/sec ({d:.2} ns/op)\n", .{ops_per_sec, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(ITERATIONS))});
}

test "Benchmark Bundle 10000D" {
    var a = vsa.randomVector(10000, 11111);
    var b = vsa.randomVector(10000, 22222);

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..ITERATIONS) |_| {
        _ = vsa.bundle2(&a, &b);
    }

    const elapsed_ns = timer.read() - start;
    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    std.debug.print("BUNDLE 10000D: {d:.2} ops/sec ({d:.2} ns/op)\n", .{ops_per_sec, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(ITERATIONS))});
}

test "Benchmark Similarity 10000D" {
    var a = vsa.randomVector(10000, 44444);
    var b = vsa.randomVector(10000, 55555);

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..ITERATIONS) |_| {
        _ = vsa.cosineSimilarity(&a, &b);
    }

    const elapsed_ns = timer.read() - start;
    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    std.debug.print("SIMILARITY 10000D: {d:.2} ops/sec ({d:.2} ns/op)\n", .{ops_per_sec, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(ITERATIONS))});
}

test "Memory Efficiency Analysis" {
    const dimensions = [_]usize{ 1000, 4000, 10000 };

    std.debug.print("\n=== MEMORY EFFICIENCY ===\n", .{});

    for (dimensions) |dim| {
        const naive_bytes = dim * 1; // 1 byte per trit (naive)
        const packed_bytes = (dim + 4) / 5; // 5 trits per byte (packed)
        const theoretical_bits = @as(f64, @floatFromInt(dim)) * 1.585; // log2(3) bits per trit
        const theoretical_bytes = @as(usize, @intFromFloat(theoretical_bits / 8.0)) + 1;

        const compression_ratio = @as(f64, @floatFromInt(naive_bytes)) / @as(f64, @floatFromInt(packed_bytes));
        const efficiency = @as(f64, @floatFromInt(theoretical_bytes)) / @as(f64, @floatFromInt(packed_bytes)) * 100.0;

        std.debug.print("\nDimension {d}:\n", .{dim});
        std.debug.print("  Naive (1 byte/trit):     {d} bytes\n", .{naive_bytes});
        std.debug.print("  Packed (5 trits/byte):   {d} bytes\n", .{packed_bytes});
        std.debug.print("  Theoretical minimum:     {d} bytes\n", .{theoretical_bytes});
        std.debug.print("  Compression ratio:       {d:.2}x\n", .{compression_ratio});
        std.debug.print("  Packing efficiency:      {d:.1}%\n", .{efficiency});
    }
}
