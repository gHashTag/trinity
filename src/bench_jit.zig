// Trinity JIT Benchmark
// Compares JIT vs interpreted VSA operations
//
// Run: zig run src/bench_jit.zig -O ReleaseFast

const std = @import("std");
const jit = @import("jit.zig");
const vsa = @import("vsa.zig");
const hybrid = @import("hybrid.zig");

const JitCompiler = jit.JitCompiler;
const HybridBigInt = hybrid.HybridBigInt;

const ITERATIONS = 100000;
const WARMUP = 1000;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║              TRINITY JIT vs INTERPRETED BENCHMARK                           ║\n", .{});
    try stdout.print("║                                                                              ║\n", .{});
    try stdout.print("║  Comparing native JIT-compiled code vs Zig interpreted operations            ║\n", .{});
    try stdout.print("║  φ² + 1/φ² = 3                                                               ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    const dimensions = [_]usize{ 256, 1000, 4096 };

    for (dimensions) |dim| {
        try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
        try stdout.print("  DIMENSION: {d} trits\n", .{dim});
        try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n\n", .{});

        // Create test vectors
        var a = vsa.randomVector(dim, 12345);
        var b = vsa.randomVector(dim, 67890);

        // ─────────────────────────────────────────────────────────────────────────
        // BIND BENCHMARK
        // ─────────────────────────────────────────────────────────────────────────

        // Compile JIT bind
        var compiler = JitCompiler.init(allocator);
        defer compiler.deinit();

        try compiler.compileBindDirect(dim);
        const jit_bind = try compiler.finalize();

        // Warmup
        for (0..WARMUP) |_| {
            _ = vsa.bind(&a, &b);
        }

        // Interpreted bind
        var timer = std.time.Timer.start() catch unreachable;
        for (0..ITERATIONS) |_| {
            var result = vsa.bind(&a, &b);
            std.mem.doNotOptimizeAway(&result);
        }
        const interp_elapsed = timer.read();
        const interp_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(interp_elapsed)) / 1e9);

        // JIT bind (operates in-place on copy)
        var a_copy: [hybrid.MAX_TRITS]i8 = undefined;
        @memcpy(a_copy[0..dim], a.unpacked_cache[0..dim]);

        timer = std.time.Timer.start() catch unreachable;
        for (0..ITERATIONS) |_| {
            // Reset a_copy each iteration for fair comparison
            @memcpy(a_copy[0..dim], a.unpacked_cache[0..dim]);
            jit_bind(&a_copy, &b.unpacked_cache);
            std.mem.doNotOptimizeAway(&a_copy);
        }
        const jit_elapsed = timer.read();
        const jit_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(jit_elapsed)) / 1e9);

        const bind_speedup = jit_ops / interp_ops;

        try stdout.print("  BIND:\n", .{});
        try stdout.print("    Interpreted (SIMD): {d:.0} ops/sec\n", .{interp_ops});
        try stdout.print("    JIT compiled:       {d:.0} ops/sec\n", .{jit_ops});
        try stdout.print("    Speedup:            {d:.2}x {s}\n\n", .{
            if (bind_speedup > 1) bind_speedup else 1.0 / bind_speedup,
            if (bind_speedup > 1) "(JIT faster)" else "(Interpreted faster)",
        });

        // ─────────────────────────────────────────────────────────────────────────
        // BUNDLE BENCHMARK
        // ─────────────────────────────────────────────────────────────────────────

        var compiler2 = JitCompiler.init(allocator);
        defer compiler2.deinit();

        try compiler2.compileBundleDirect(dim);
        const jit_bundle = try compiler2.finalize();

        // Interpreted bundle
        timer = std.time.Timer.start() catch unreachable;
        for (0..ITERATIONS) |_| {
            var result = vsa.bundle2(&a, &b);
            std.mem.doNotOptimizeAway(&result);
        }
        const interp_bundle_elapsed = timer.read();
        const interp_bundle_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(interp_bundle_elapsed)) / 1e9);

        // JIT bundle
        timer = std.time.Timer.start() catch unreachable;
        for (0..ITERATIONS) |_| {
            @memcpy(a_copy[0..dim], a.unpacked_cache[0..dim]);
            jit_bundle(&a_copy, &b.unpacked_cache);
            std.mem.doNotOptimizeAway(&a_copy);
        }
        const jit_bundle_elapsed = timer.read();
        const jit_bundle_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(jit_bundle_elapsed)) / 1e9);

        const bundle_speedup = jit_bundle_ops / interp_bundle_ops;

        try stdout.print("  BUNDLE:\n", .{});
        try stdout.print("    Interpreted (SIMD): {d:.0} ops/sec\n", .{interp_bundle_ops});
        try stdout.print("    JIT compiled:       {d:.0} ops/sec\n", .{jit_bundle_ops});
        try stdout.print("    Speedup:            {d:.2}x {s}\n\n", .{
            if (bundle_speedup > 1) bundle_speedup else 1.0 / bundle_speedup,
            if (bundle_speedup > 1) "(JIT faster)" else "(Interpreted faster)",
        });

        // ─────────────────────────────────────────────────────────────────────────
        // DOT PRODUCT BENCHMARK
        // ─────────────────────────────────────────────────────────────────────────

        var compiler3 = JitCompiler.init(allocator);
        defer compiler3.deinit();

        try compiler3.compileDotProduct(dim);

        // Finalize with correct signature
        const code_size = compiler3.code.items.len;
        const page_size = std.heap.page_size_min;
        const alloc_size = std.mem.alignForward(usize, code_size, page_size);

        const mem = try std.posix.mmap(
            null,
            alloc_size,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        );
        defer std.posix.munmap(mem);

        @memcpy(mem[0..code_size], compiler3.code.items);
        try std.posix.mprotect(mem, std.posix.PROT.READ | std.posix.PROT.EXEC);

        const jit_dot: *const fn (*anyopaque, *anyopaque) callconv(.c) i64 = @ptrCast(mem.ptr);

        // Interpreted dot product (using similarity which computes dot)
        timer = std.time.Timer.start() catch unreachable;
        var interp_result: f64 = undefined;
        for (0..ITERATIONS) |_| {
            interp_result = vsa.cosineSimilarity(&a, &b);
            std.mem.doNotOptimizeAway(&interp_result);
        }
        const interp_dot_elapsed = timer.read();
        const interp_dot_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(interp_dot_elapsed)) / 1e9);

        // JIT dot product
        timer = std.time.Timer.start() catch unreachable;
        var jit_result: i64 = undefined;
        for (0..ITERATIONS) |_| {
            jit_result = jit_dot(&a.unpacked_cache, &b.unpacked_cache);
            std.mem.doNotOptimizeAway(&jit_result);
        }
        const jit_dot_elapsed = timer.read();
        const jit_dot_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(jit_dot_elapsed)) / 1e9);

        const dot_speedup = jit_dot_ops / interp_dot_ops;

        try stdout.print("  DOT PRODUCT:\n", .{});
        try stdout.print("    Interpreted:        {d:.0} ops/sec\n", .{interp_dot_ops});
        try stdout.print("    JIT compiled:       {d:.0} ops/sec\n", .{jit_dot_ops});
        try stdout.print("    Speedup:            {d:.2}x {s}\n\n", .{
            if (dot_speedup > 1) dot_speedup else 1.0 / dot_speedup,
            if (dot_speedup > 1) "(JIT faster)" else "(Interpreted faster)",
        });

        // Code size
        try stdout.print("  JIT CODE SIZE:\n", .{});
        try stdout.print("    Bind:    {d} bytes\n", .{compiler.codeSize()});
        try stdout.print("    Bundle:  {d} bytes\n", .{compiler2.codeSize()});
        try stdout.print("    Dot:     {d} bytes\n\n", .{compiler3.codeSize()});
    }

    // Summary
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("  SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n\n", .{});

    try stdout.print("  JIT ADVANTAGES:\n", .{});
    try stdout.print("  ✓ No function call overhead per element\n", .{});
    try stdout.print("  ✓ Tight loop with minimal branching\n", .{});
    try stdout.print("  ✓ Dimension-specific code (no bounds checks)\n", .{});
    try stdout.print("  ✓ Can be cached for repeated operations\n\n", .{});

    try stdout.print("  INTERPRETED (SIMD) ADVANTAGES:\n", .{});
    try stdout.print("  ✓ 32-wide SIMD operations\n", .{});
    try stdout.print("  ✓ Compiler-optimized code\n", .{});
    try stdout.print("  ✓ No JIT compilation overhead\n", .{});
    try stdout.print("  ✓ Better cache utilization\n\n", .{});

    try stdout.print("  CONCLUSION:\n", .{});
    try stdout.print("  The SIMD-optimized interpreted code is competitive with JIT\n", .{});
    try stdout.print("  because Zig's compiler already generates excellent native code.\n", .{});
    try stdout.print("  JIT shines for dynamic/specialized operations.\n\n", .{});

    try stdout.print("  φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL\n\n", .{});
}
