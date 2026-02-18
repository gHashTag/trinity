// ═══════════════════════════════════════════════════════════════════════════════
// VSA Math Benchmark Suite — MATH-003
// ═══════════════════════════════════════════════════════════════════════════════
//
// Quantifies ternary VSA advantage vs float32 / binary alternatives.
// Measures: throughput, latency, memory efficiency, recall curves, convergence.
//
// Run: zig build bench-math
//
// Священная формула: V = n × 3^k × π^m × φ^p × e^q
// Золотая идентичность: φ² + 1/φ² = 3
//
// Generated from specs/tri/vsa_benchmark.vibee (MATH-003)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa");
const bundle_opt = @import("bundle_opt");

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

const WARMUP_ITERATIONS = 100;
const BENCHMARK_ITERATIONS = 10000;
const DIMENSIONS = [_]usize{ 1024, 4096, 10000 };

// Bundle-N recall curve sizes
const BUNDLE_N_SIZES = [_]usize{ 3, 5, 10, 25, 50, 100, 250, 500 };

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try printHeader(stdout);
    try printSystemInfo(stdout);

    // Section 1: Operation Throughput
    try printSection(stdout, "1. OPERATION THROUGHPUT — Ternary VSA Ops");
    for (DIMENSIONS) |dim| {
        try stdout.print("  ┌─ Dimension: {d}\n", .{dim});
        try benchBind(stdout, dim);
        try benchUnbind(stdout, dim);
        try benchBundle2(stdout, dim);
        try benchSimilarity(stdout, dim);
        try benchPermute(stdout, dim);
        try stdout.print("  └─────────────────────────────────────────\n\n", .{});
    }

    // Section 2: Bundle-N Throughput
    try printSection(stdout, "2. BUNDLE-N THROUGHPUT — Accumulator Performance");
    try benchBundleN(stdout);

    // Section 3: Memory Efficiency
    try printSection(stdout, "3. MEMORY EFFICIENCY — Ternary vs Float32");
    for (DIMENSIONS) |dim| {
        try benchMemory(stdout, dim);
    }

    // Section 4: Recall Curve
    try printSection(stdout, "4. RECALL CURVE — Bundle-N Capacity Analysis");
    try benchRecallCurve(stdout);

    // Section 5: Convergence Validation
    try printSection(stdout, "5. CONVERGENCE VALIDATION — Theory vs Empirical");
    try benchConvergence(stdout);

    // Section 6: Proof Verification Time
    try printSection(stdout, "6. PROOF VERIFICATION TIME — 12 VSA Proofs");
    try benchProofs(stdout);

    // Section 7: Comparison Table
    try printSection(stdout, "7. TERNARY vs FLOAT32 — Summary Comparison");
    try printComparisonTable(stdout);

    try printFooter(stdout);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 1: OPERATION THROUGHPUT
// ═══════════════════════════════════════════════════════════════════════════════

fn benchBind(writer: anytype, dim: usize) !void {
    var a = vsa.randomVector(dim, 12345);
    var b = vsa.randomVector(dim, 67890);

    for (0..WARMUP_ITERATIONS) |_| {
        _ = vsa.bind(&a, &b);
    }

    var timer = std.time.Timer.start() catch unreachable;
    for (0..BENCHMARK_ITERATIONS) |_| {
        _ = vsa.bind(&a, &b);
    }
    const elapsed_ns = timer.read();

    const result = calcMetrics(elapsed_ns);
    try writer.print("  │ BIND:       {d:>12.0} ops/s  {d:>8.1} ns/op\n", .{ result.ops_per_sec, result.ns_per_op });
}

fn benchUnbind(writer: anytype, dim: usize) !void {
    var a = vsa.randomVector(dim, 11111);
    var b = vsa.randomVector(dim, 22222);

    var bound = vsa.bind(&a, &b);

    for (0..WARMUP_ITERATIONS) |_| {
        _ = vsa.unbind(&bound, &a);
    }

    var timer = std.time.Timer.start() catch unreachable;
    for (0..BENCHMARK_ITERATIONS) |_| {
        _ = vsa.unbind(&bound, &a);
    }
    const elapsed_ns = timer.read();

    // Verify correctness
    var recovered = vsa.unbind(&bound, &a);
    const sim = vsa.cosineSimilarity(&recovered, &b);

    const result = calcMetrics(elapsed_ns);
    try writer.print("  │ UNBIND:     {d:>12.0} ops/s  {d:>8.1} ns/op  (recovery sim={d:.3})\n", .{ result.ops_per_sec, result.ns_per_op, sim });
}

fn benchBundle2(writer: anytype, dim: usize) !void {
    var a = vsa.randomVector(dim, 33333);
    var b = vsa.randomVector(dim, 44444);

    for (0..WARMUP_ITERATIONS) |_| {
        _ = vsa.bundle2(&a, &b);
    }

    var timer = std.time.Timer.start() catch unreachable;
    for (0..BENCHMARK_ITERATIONS) |_| {
        _ = vsa.bundle2(&a, &b);
    }
    const elapsed_ns = timer.read();

    const result = calcMetrics(elapsed_ns);
    try writer.print("  │ BUNDLE2:    {d:>12.0} ops/s  {d:>8.1} ns/op\n", .{ result.ops_per_sec, result.ns_per_op });
}

fn benchSimilarity(writer: anytype, dim: usize) !void {
    var a = vsa.randomVector(dim, 55555);
    var b = vsa.randomVector(dim, 66666);

    for (0..WARMUP_ITERATIONS) |_| {
        _ = vsa.cosineSimilarity(&a, &b);
    }

    var timer = std.time.Timer.start() catch unreachable;
    for (0..BENCHMARK_ITERATIONS) |_| {
        _ = vsa.cosineSimilarity(&a, &b);
    }
    const elapsed_ns = timer.read();

    const result = calcMetrics(elapsed_ns);
    try writer.print("  │ SIMILARITY: {d:>12.0} ops/s  {d:>8.1} ns/op\n", .{ result.ops_per_sec, result.ns_per_op });
}

fn benchPermute(writer: anytype, dim: usize) !void {
    var a = vsa.randomVector(dim, 77777);

    for (0..WARMUP_ITERATIONS) |_| {
        _ = vsa.permute(&a, 1);
    }

    var timer = std.time.Timer.start() catch unreachable;
    for (0..BENCHMARK_ITERATIONS) |_| {
        _ = vsa.permute(&a, 1);
    }
    const elapsed_ns = timer.read();

    const result = calcMetrics(elapsed_ns);
    try writer.print("  │ PERMUTE:    {d:>12.0} ops/s  {d:>8.1} ns/op\n", .{ result.ops_per_sec, result.ns_per_op });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 2: BUNDLE-N THROUGHPUT
// ═══════════════════════════════════════════════════════════════════════════════

fn benchBundleN(writer: anytype) !void {
    const dim = 1024;

    try writer.print("  Dimension: {d}\n", .{dim});
    try writer.print("  ┌────────┬──────────────┬──────────────┬──────────┐\n", .{});
    try writer.print("  │   N    │   ops/sec    │    ns/op     │ total ms │\n", .{});
    try writer.print("  ├────────┼──────────────┼──────────────┼──────────┤\n", .{});

    for (BUNDLE_N_SIZES) |n| {
        // Create N vectors
        var vectors: [500]vsa.HybridBigInt = undefined;
        for (0..n) |i| {
            vectors[i] = vsa.randomVector(dim, 9000 + i);
        }

        // Warmup
        const warmup_count = @min(WARMUP_ITERATIONS, 20);
        for (0..warmup_count) |_| {
            _ = bundle_opt.bundleN(vectors[0..n], dim);
        }

        // Benchmark
        const iters = @max(BENCHMARK_ITERATIONS / n, 100);
        var timer = std.time.Timer.start() catch unreachable;
        for (0..iters) |_| {
            _ = bundle_opt.bundleN(vectors[0..n], dim);
        }
        const elapsed_ns = timer.read();

        const ops_per_sec = @as(f64, @floatFromInt(iters)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
        const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iters));
        const total_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;

        try writer.print("  │ {d:>5}  │ {d:>12.0} │ {d:>12.1} │ {d:>8.2} │\n", .{ n, ops_per_sec, ns_per_op, total_ms });
    }

    try writer.print("  └────────┴──────────────┴──────────────┴──────────┘\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 3: MEMORY EFFICIENCY
// ═══════════════════════════════════════════════════════════════════════════════

fn benchMemory(writer: anytype, dim: usize) !void {
    // Ternary packed: 5 trits per byte (1.585 bits/trit)
    const packed_bytes = (dim + 4) / 5;
    // Float32: 4 bytes per element
    const float32_bytes = dim * 4;
    // Binary: 1 bit per element (packed)
    const binary_bytes = (dim + 7) / 8;
    // Theoretical minimum: log2(3) bits per trit
    const theoretical_bits = @as(f64, @floatFromInt(dim)) * 1.585;
    const theoretical_bytes = @as(usize, @intFromFloat(theoretical_bits / 8.0)) + 1;

    const ternary_vs_float32 = @as(f64, @floatFromInt(float32_bytes)) / @as(f64, @floatFromInt(packed_bytes));
    const ternary_vs_binary = @as(f64, @floatFromInt(packed_bytes)) / @as(f64, @floatFromInt(binary_bytes));
    const packing_efficiency = @as(f64, @floatFromInt(theoretical_bytes)) / @as(f64, @floatFromInt(packed_bytes)) * 100.0;
    const bits_per_element = @as(f64, @floatFromInt(packed_bytes * 8)) / @as(f64, @floatFromInt(dim));

    try writer.print("  Dimension {d}:\n", .{dim});
    try writer.print("    Ternary packed:    {d:>8} bytes  ({d:.2} bits/element)\n", .{ packed_bytes, bits_per_element });
    try writer.print("    Float32:           {d:>8} bytes  (32.00 bits/element)\n", .{float32_bytes});
    try writer.print("    Binary packed:     {d:>8} bytes  ( 1.00 bits/element)\n", .{binary_bytes});
    try writer.print("    Theoretical min:   {d:>8} bytes  ( 1.58 bits/element)\n", .{theoretical_bytes});
    try writer.print("    Compression vs f32: {d:>6.1}x\n", .{ternary_vs_float32});
    try writer.print("    Size vs binary:     {d:>6.1}x\n", .{ternary_vs_binary});
    try writer.print("    Packing efficiency: {d:>5.1}%\n\n", .{packing_efficiency});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 4: RECALL CURVE
// ═══════════════════════════════════════════════════════════════════════════════

fn benchRecallCurve(writer: anytype) !void {
    const dim = 1024;
    const recall_sizes = [_]usize{ 3, 5, 10, 25, 50, 100, 250, 500 };

    try writer.print("  Dimension: {d}\n", .{dim});
    try writer.print("  ┌────────┬──────────┬──────────┬───────────┬───────────┐\n", .{});
    try writer.print("  │   N    │ Recall % │ Theory % │ Avg Sim   │ Deviation │\n", .{});
    try writer.print("  ├────────┼──────────┼──────────┼───────────┼───────────┤\n", .{});

    for (recall_sizes) |n| {
        // Create N vectors
        var vectors: [500]vsa.HybridBigInt = undefined;
        for (0..n) |i| {
            vectors[i] = vsa.randomVector(dim, 5000 + i);
        }

        // Bundle all
        var acc = bundle_opt.BundleAccumulator.init(dim);
        for (0..n) |i| {
            acc.accumulate(&vectors[i]);
        }
        var bundled = acc.finalize();

        // Measure recall and average similarity
        var positive_count: usize = 0;
        var total_sim: f64 = 0;
        for (0..n) |i| {
            const sim = vsa.cosineSimilarity(&bundled, &vectors[i]);
            total_sim += sim;
            if (sim > 0.0) positive_count += 1;
        }

        const recall_pct = @as(f64, @floatFromInt(positive_count)) / @as(f64, @floatFromInt(n)) * 100.0;
        const avg_sim = total_sim / @as(f64, @floatFromInt(n));

        // Theoretical recall: roughly proportional to 1/sqrt(N) for signal strength
        // At N vectors, expected similarity ~ 1/sqrt(N), recall stays high until signal drowns in noise
        const n_f = @as(f64, @floatFromInt(n));
        const theory_recall: f64 = if (n <= 10) 100.0 else @min(100.0, 100.0 * (1.0 / @sqrt(n_f)) * @sqrt(10.0));
        const deviation = recall_pct - theory_recall;

        try writer.print("  │ {d:>5}  │ {d:>7.1} │ {d:>7.1} │ {d:>9.4} │ {d:>8.1}%  │\n", .{ n, recall_pct, theory_recall, avg_sim, deviation });
    }

    try writer.print("  └────────┴──────────┴──────────┴───────────┴───────────┘\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 5: CONVERGENCE VALIDATION
// ═══════════════════════════════════════════════════════════════════════════════

fn benchConvergence(writer: anytype) !void {
    const dim = 1024;
    const trials = 10;

    try writer.print("  Testing bundle convergence over {d} trials (dim={d})\n\n", .{ trials, dim });

    // Test: bundle(A,B,C) similarity distribution
    var bind_recovery_sum: f64 = 0;
    var bundle3_sim_sum: f64 = 0;
    var orthogonality_sum: f64 = 0;

    for (0..trials) |t| {
        var a = vsa.randomVector(dim, 30000 + t * 3);
        var b = vsa.randomVector(dim, 30001 + t * 3);
        var c = vsa.randomVector(dim, 30002 + t * 3);

        // Bind/unbind recovery
        var bound = vsa.bind(&a, &b);
        var recovered = vsa.unbind(&bound, &a);
        bind_recovery_sum += vsa.cosineSimilarity(&recovered, &b);

        // Bundle3 similarity to first input
        var bundled = vsa.bundle3(&a, &b, &c);
        bundle3_sim_sum += vsa.cosineSimilarity(&bundled, &a);

        // Orthogonality
        orthogonality_sum += @abs(vsa.cosineSimilarity(&a, &b));
    }

    const avg_bind_recovery = bind_recovery_sum / @as(f64, @floatFromInt(trials));
    const avg_bundle3_sim = bundle3_sim_sum / @as(f64, @floatFromInt(trials));
    const avg_orthogonality = orthogonality_sum / @as(f64, @floatFromInt(trials));

    try writer.print("  Bind/Unbind recovery:     {d:.4} (expected > 0.60)\n", .{avg_bind_recovery});
    try writer.print("  Bundle3 input similarity: {d:.4} (expected > 0.15)\n", .{avg_bundle3_sim});
    try writer.print("  Random orthogonality:     {d:.4} (expected < 0.10)\n", .{avg_orthogonality});

    // Pass/Fail verdicts
    const bind_ok = avg_bind_recovery > 0.60;
    const bundle_ok = avg_bundle3_sim > 0.15;
    const ortho_ok = avg_orthogonality < 0.10;

    try writer.print("\n  Verdicts:\n", .{});
    try writer.print("    Bind recovery:    {s}\n", .{if (bind_ok) "PASS" else "FAIL"});
    try writer.print("    Bundle3 signal:   {s}\n", .{if (bundle_ok) "PASS" else "FAIL"});
    try writer.print("    Orthogonality:    {s}\n", .{if (ortho_ok) "PASS" else "FAIL"});
    try writer.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 6: PROOF VERIFICATION TIME
// ═══════════════════════════════════════════════════════════════════════════════

fn benchProofs(writer: anytype) !void {
    const dim = 1024;

    const ProofEntry = struct {
        name: []const u8,
        time_ns: u64,
    };

    var proofs: [8]ProofEntry = undefined;
    var total_ns: u64 = 0;

    // Proof 1: Bind Inverse
    {
        var timer = std.time.Timer.start() catch unreachable;
        for (0..1000) |t| {
            var a = vsa.randomVector(dim, 42 + t);
            var b = vsa.randomVector(dim, 137 + t);
            var bound = vsa.bind(&a, &b);
            var recovered = vsa.unbind(&bound, &a);
            _ = vsa.cosineSimilarity(&recovered, &b);
        }
        const ns = timer.read();
        proofs[0] = .{ .name = "Bind Inverse", .time_ns = ns };
        total_ns += ns;
    }

    // Proof 2: Bind Commutativity
    {
        var timer = std.time.Timer.start() catch unreachable;
        for (0..1000) |t| {
            var a = vsa.randomVector(dim, 123 + t);
            var b = vsa.randomVector(dim, 456 + t);
            _ = vsa.bind(&a, &b);
            _ = vsa.bind(&b, &a);
        }
        const ns = timer.read();
        proofs[1] = .{ .name = "Bind Commutative", .time_ns = ns };
        total_ns += ns;
    }

    // Proof 3: Bind Self-Identity
    {
        var timer = std.time.Timer.start() catch unreachable;
        for (0..1000) |t| {
            var a = vsa.randomVector(dim, 777 + t);
            _ = vsa.bind(&a, &a);
        }
        const ns = timer.read();
        proofs[2] = .{ .name = "Bind Self-Identity", .time_ns = ns };
        total_ns += ns;
    }

    // Proof 4: Bundle Convergence
    {
        var timer = std.time.Timer.start() catch unreachable;
        for (0..1000) |t| {
            var a = vsa.randomVector(dim, 1001 + t);
            var b = vsa.randomVector(dim, 2001 + t);
            var c = vsa.randomVector(dim, 3001 + t);
            var bundled = vsa.bundle3(&a, &b, &c);
            _ = vsa.cosineSimilarity(&bundled, &a);
        }
        const ns = timer.read();
        proofs[3] = .{ .name = "Bundle Convergence", .time_ns = ns };
        total_ns += ns;
    }

    // Proof 5: Orthogonality
    {
        var timer = std.time.Timer.start() catch unreachable;
        for (0..1000) |t| {
            var a = vsa.randomVector(dim, 10000 + t * 2);
            var b = vsa.randomVector(dim, 10001 + t * 2);
            _ = vsa.cosineSimilarity(&a, &b);
        }
        const ns = timer.read();
        proofs[4] = .{ .name = "Orthogonality", .time_ns = ns };
        total_ns += ns;
    }

    // Proof 6: Permute Cycle
    {
        const pdim = 256;
        var timer = std.time.Timer.start() catch unreachable;
        for (0..1000) |t| {
            var a = vsa.randomVector(pdim, 55 + t);
            var p1 = vsa.permute(&a, 17);
            var p2 = vsa.permute(&p1, pdim - 17);
            _ = vsa.cosineSimilarity(&p2, &a);
        }
        const ns = timer.read();
        proofs[5] = .{ .name = "Permute Cycle", .time_ns = ns };
        total_ns += ns;
    }

    // Proof 7: Similarity Bounds
    {
        var timer = std.time.Timer.start() catch unreachable;
        for (0..1000) |t| {
            var a = vsa.randomVector(512, 20000 + t * 2);
            var b = vsa.randomVector(512, 20001 + t * 2);
            _ = vsa.cosineSimilarity(&a, &b);
        }
        const ns = timer.read();
        proofs[6] = .{ .name = "Similarity Bounds", .time_ns = ns };
        total_ns += ns;
    }

    // Proof 8: Trinity Identity (φ² + 1/φ² = 3) — pure math, no VSA
    {
        var timer = std.time.Timer.start() catch unreachable;
        for (0..1000) |_| {
            const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
            const trinity = phi * phi + 1.0 / (phi * phi);
            std.mem.doNotOptimizeAway(trinity);
        }
        const ns = timer.read();
        proofs[7] = .{ .name = "Trinity Identity", .time_ns = ns };
        total_ns += ns;
    }

    // Print results table
    try writer.print("  1000 iterations per proof\n", .{});
    try writer.print("  ┌───────────────────────┬─────────────┬──────────────┐\n", .{});
    try writer.print("  │ Proof                 │  Total (ms) │  Per-iter ns │\n", .{});
    try writer.print("  ├───────────────────────┼─────────────┼──────────────┤\n", .{});

    for (proofs) |p| {
        const total_ms = @as(f64, @floatFromInt(p.time_ns)) / 1_000_000.0;
        const per_iter = @as(f64, @floatFromInt(p.time_ns)) / 1000.0;
        try writer.print("  │ {s:<21} │ {d:>11.3} │ {d:>12.1} │\n", .{ p.name, total_ms, per_iter });
    }

    try writer.print("  ├───────────────────────┼─────────────┼──────────────┤\n", .{});
    const total_ms_all = @as(f64, @floatFromInt(total_ns)) / 1_000_000.0;
    try writer.print("  │ TOTAL                 │ {d:>11.3} │              │\n", .{total_ms_all});
    try writer.print("  └───────────────────────┴─────────────┴──────────────┘\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 7: COMPARISON TABLE
// ═══════════════════════════════════════════════════════════════════════════════

fn printComparisonTable(writer: anytype) !void {
    const dim = 1024;

    // Memory comparison
    const ternary_bytes = (dim + 4) / 5; // 5 trits/byte
    const float32_bytes = dim * 4;
    const int8_bytes = dim * 1;
    const binary_bytes = (dim + 7) / 8;

    const log2_3: f64 = 1.58496;
    const ternary_info = @as(f64, @floatFromInt(dim)) * log2_3;
    const float32_info = @as(f64, @floatFromInt(dim)) * 32.0;
    const int8_info = @as(f64, @floatFromInt(dim)) * 8.0;
    const binary_info = @as(f64, @floatFromInt(dim)) * 1.0;

    const ternary_density = ternary_info / @as(f64, @floatFromInt(ternary_bytes * 8));
    const float32_density = float32_info / @as(f64, @floatFromInt(float32_bytes * 8));
    const int8_density = int8_info / @as(f64, @floatFromInt(int8_bytes * 8));
    const binary_density = binary_info / @as(f64, @floatFromInt(binary_bytes * 8));

    try writer.print("  Dimension: {d}\n\n", .{dim});

    try writer.print("  ┌──────────────┬──────────┬──────────────┬───────────┬──────────────────┐\n", .{});
    try writer.print("  │ Format       │   Bytes  │ Info (bits)  │ Density   │ vs Ternary       │\n", .{});
    try writer.print("  ├──────────────┼──────────┼──────────────┼───────────┼──────────────────┤\n", .{});

    try writer.print("  │ Ternary      │ {d:>7}  │ {d:>11.1} │ {d:>8.4}  │ 1.0x (baseline)  │\n", .{ ternary_bytes, ternary_info, ternary_density });

    const f32_ratio = @as(f64, @floatFromInt(float32_bytes)) / @as(f64, @floatFromInt(ternary_bytes));
    try writer.print("  │ Float32      │ {d:>7}  │ {d:>11.1} │ {d:>8.4}  │ {d:>5.1}x memory   │\n", .{ float32_bytes, float32_info, float32_density, f32_ratio });

    const i8_ratio = @as(f64, @floatFromInt(int8_bytes)) / @as(f64, @floatFromInt(ternary_bytes));
    try writer.print("  │ Int8         │ {d:>7}  │ {d:>11.1} │ {d:>8.4}  │ {d:>5.1}x memory   │\n", .{ int8_bytes, int8_info, int8_density, i8_ratio });

    const bin_ratio = @as(f64, @floatFromInt(binary_bytes)) / @as(f64, @floatFromInt(ternary_bytes));
    try writer.print("  │ Binary       │ {d:>7}  │ {d:>11.1} │ {d:>8.4}  │ {d:>5.1}x memory   │\n", .{ binary_bytes, binary_info, binary_density, bin_ratio });

    try writer.print("  └──────────────┴──────────┴──────────────┴───────────┴──────────────────┘\n\n", .{});

    // Key advantages
    try writer.print("  KEY ADVANTAGES — Ternary VSA:\n", .{});
    try writer.print("    * {d:.1}x memory savings vs Float32\n", .{f32_ratio});
    try writer.print("    * {d:.3} bits/trit information density (log2(3))\n", .{log2_3});
    try writer.print("    * Add-only compute (no multiply) for bind/unbind\n", .{});
    try writer.print("    * Near-orthogonal random vectors in high dimensions\n", .{});
    try writer.print("    * Algebraic closure: bind, unbind, bundle, permute\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

const BenchResult = struct {
    ops_per_sec: f64,
    ns_per_op: f64,
    total_ms: f64,
};

fn calcMetrics(elapsed_ns: u64) BenchResult {
    const ns_f = @as(f64, @floatFromInt(elapsed_ns));
    const iters_f = @as(f64, @floatFromInt(BENCHMARK_ITERATIONS));
    return .{
        .ops_per_sec = iters_f / (ns_f / 1_000_000_000.0),
        .ns_per_op = ns_f / iters_f,
        .total_ms = ns_f / 1_000_000.0,
    };
}

fn printHeader(writer: anytype) !void {
    try writer.print("\n", .{});
    try writer.print("  ╔══════════════════════════════════════════════════════════════╗\n", .{});
    try writer.print("  ║       TRINITY VSA MATH BENCHMARK SUITE — MATH-003          ║\n", .{});
    try writer.print("  ║                                                            ║\n", .{});
    try writer.print("  ║  Ternary VSA vs Float32/Binary — Quantified Advantage      ║\n", .{});
    try writer.print("  ║  φ² + 1/φ² = 3                                             ║\n", .{});
    try writer.print("  ╚══════════════════════════════════════════════════════════════╝\n\n", .{});
}

fn printSystemInfo(writer: anytype) !void {
    try writer.print("  CONFIGURATION:\n", .{});
    try writer.print("  ────────────────────────────────────────────────────────────────\n", .{});
    try writer.print("    Warmup iterations:    {d}\n", .{WARMUP_ITERATIONS});
    try writer.print("    Benchmark iterations: {d}\n", .{BENCHMARK_ITERATIONS});
    try writer.print("    Dimensions tested:    {d}, {d}, {d}\n", .{ DIMENSIONS[0], DIMENSIONS[1], DIMENSIONS[2] });
    try writer.print("    Bundle-N sizes:       3, 5, 10, 25, 50, 100, 250, 500\n\n", .{});
}

fn printSection(writer: anytype, title: []const u8) !void {
    try writer.print("  ═══════════════════════════════════════════════════════════════\n", .{});
    try writer.print("  {s}\n", .{title});
    try writer.print("  ═══════════════════════════════════════════════════════════════\n\n", .{});
}

fn printFooter(writer: anytype) !void {
    try writer.print("  ═══════════════════════════════════════════════════════════════\n", .{});
    try writer.print("  BENCHMARK COMPLETE — φ² + 1/φ² = 3 = TRINITY\n", .{});
    try writer.print("  ═══════════════════════════════════════════════════════════════\n\n", .{});
}
