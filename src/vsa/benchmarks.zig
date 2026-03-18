const std = @import("std");
const vsa = @import("../vsa.zig");
const HybridBigInt = vsa.HybridBigInt;
const Trit = vsa.Trit;
const TextCorpus = vsa.TextCorpus;

/// VSA Operations Benchmarks
pub fn runBenchmarks() void {
    const iterations: u64 = 10000;
    const vec_size: usize = 256;

    std.debug.print("\nVSA Operations Benchmarks ({}D vectors)\n", .{vec_size});
    std.debug.print("==========================================\n\n", .{});

    var a = vsa.randomVector(vec_size, 111);
    var b = vsa.randomVector(vec_size, 222);
    var c = vsa.randomVector(vec_size, 333);

    // Bind benchmark
    const bind_start = std.time.nanoTimestamp();
    var bind_result = HybridBigInt.zero();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        bind_result = vsa.bind(&a, &b);
    }
    const bind_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(bind_result);
    const bind_ns = @as(u64, @intCast(bind_end - bind_start));

    std.debug.print("Bind x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ bind_ns, bind_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(bind_ns)) * 1000.0,
    });

    // Bundle benchmark
    const bundle_start = std.time.nanoTimestamp();
    var bundle_result = HybridBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        bundle_result = vsa.bundle3(&a, &b, &c);
    }
    const bundle_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(bundle_result);
    const bundle_ns = @as(u64, @intCast(bundle_end - bundle_start));

    std.debug.print("Bundle3 x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ bundle_ns, bundle_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(bundle_ns)) * 1000.0,
    });

    // Similarity benchmark
    const sim_start = std.time.nanoTimestamp();
    var sim_result: f64 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        sim_result = vsa.cosineSimilarity(&a, &b);
    }
    const sim_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(sim_result);
    const sim_ns = @as(u64, @intCast(sim_end - sim_start));

    std.debug.print("Cosine Similarity x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ sim_ns, sim_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(sim_ns)) * 1000.0,
    });

    // Dot product benchmark
    const dot_start = std.time.nanoTimestamp();
    var dot_result: i32 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        dot_result = a.dotProduct(&b);
    }
    const dot_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(dot_result);
    const dot_ns = @as(u64, @intCast(dot_end - dot_start));

    std.debug.print("Dot Product x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ dot_ns, dot_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(dot_ns)) * 1000.0,
    });

    // Permute benchmark
    const perm_start = std.time.nanoTimestamp();
    var perm_result = HybridBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        perm_result = vsa.permute(&a, 7);
    }
    const perm_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(perm_result);
    const perm_ns = @as(u64, @intCast(perm_end - perm_start));

    std.debug.print("Permute x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ perm_ns, perm_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(perm_ns)) * 1000.0,
    });

    std.debug.print("Summary:\n", .{});
    std.debug.print("  Bind:       {} ns/op\n", .{bind_ns / iterations});
    std.debug.print("  Bundle3:    {} ns/op\n", .{bundle_ns / iterations});
    std.debug.print("  Similarity: {} ns/op\n", .{sim_ns / iterations});
    std.debug.print("  Dot:        {} ns/op\n", .{dot_ns / iterations});
    std.debug.print("  Permute:    {} ns/op\n", .{perm_ns / iterations});
}
