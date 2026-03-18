// Trinity Science - Statistical Analysis Example
// Demonstrates scientific computing capabilities for researchers
//
// Run: zig build-exe examples/science_analysis.zig --mod trinity:src/trinity.zig -OReleaseFast

const std = @import("std");
const trinity = @import("trinity");

const Hypervector = trinity.Hypervector;
const VectorStats = trinity.VectorStats;
const DistanceMetric = trinity.DistanceMetric;
const computeStats = trinity.computeStats;
const distance = trinity.distance;
const mutualInformation = trinity.mutualInformation;
const batchBundle = trinity.batchBundle;
const weightedBundle = trinity.weightedBundle;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                TRINITY SCIENCE ANALYSIS\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n\n", .{});

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Statistical Analysis
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("1. STATISTICAL ANALYSIS\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    var hv = Hypervector.random(10000, 42);
    const stats = computeStats(&hv);

    try stdout.print("Hypervector Statistics (dim={d}):\n", .{stats.dimension});
    try stdout.print("  Positive trits: {d} ({d:.1}%)\n", .{ stats.positive_count, @as(f64, @floatFromInt(stats.positive_count)) / @as(f64, @floatFromInt(stats.dimension)) * 100 });
    try stdout.print("  Negative trits: {d} ({d:.1}%)\n", .{ stats.negative_count, @as(f64, @floatFromInt(stats.negative_count)) / @as(f64, @floatFromInt(stats.dimension)) * 100 });
    try stdout.print("  Zero trits:     {d} ({d:.1}%)\n", .{ stats.zero_count, @as(f64, @floatFromInt(stats.zero_count)) / @as(f64, @floatFromInt(stats.dimension)) * 100 });
    try stdout.print("  Density:        {d:.4}\n", .{stats.density});
    try stdout.print("  Balance:        {d:.4}\n", .{stats.balance});
    try stdout.print("  Entropy:        {d:.4} (max=1.0 for ternary)\n", .{stats.entropy});
    try stdout.print("  Mean:           {d:.4}\n", .{stats.mean});
    try stdout.print("  Std Dev:        {d:.4}\n\n", .{stats.std_dev});

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Distance Metrics
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("2. DISTANCE METRICS\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    var a = Hypervector.random(1000, 11111);
    var b = Hypervector.random(1000, 22222);

    try stdout.print("Distance between random vectors (dim=1000):\n", .{});
    try stdout.print("  Hamming:    {d:.4}\n", .{distance(&a, &b, .hamming)});
    try stdout.print("  Cosine:     {d:.4}\n", .{distance(&a, &b, .cosine)});
    try stdout.print("  Euclidean:  {d:.2}\n", .{distance(&a, &b, .euclidean)});
    try stdout.print("  Manhattan:  {d:.2}\n", .{distance(&a, &b, .manhattan)});
    try stdout.print("  Jaccard:    {d:.4}\n", .{distance(&a, &b, .jaccard)});
    try stdout.print("  Dice:       {d:.4}\n\n", .{distance(&a, &b, .dice)});

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Information Theory
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("3. INFORMATION THEORY\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    var x = Hypervector.random(1000, 33333);
    var y = x.clone(); // Identical
    var z = Hypervector.random(1000, 44444); // Independent

    try stdout.print("Mutual Information:\n", .{});
    try stdout.print("  MI(x, x):  {d:.4} (self)\n", .{mutualInformation(&x, &x)});
    try stdout.print("  MI(x, y):  {d:.4} (identical copy)\n", .{mutualInformation(&x, &y)});
    try stdout.print("  MI(x, z):  {d:.4} (independent)\n\n", .{mutualInformation(&x, &z)});

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Batch Operations
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("4. BATCH OPERATIONS\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    var vectors: [10]Hypervector = undefined;
    for (0..10) |i| {
        vectors[i] = Hypervector.random(1000, @as(u64, i * 1000 + 55555));
    }

    const bundled = batchBundle(&vectors);
    try stdout.print("Batch bundle of 10 vectors:\n", .{});

    var avg_sim: f64 = 0;
    for (&vectors) |*v| {
        avg_sim += bundled.similarity(v);
    }
    avg_sim /= 10;
    try stdout.print("  Average similarity to inputs: {d:.4}\n", .{avg_sim});

    // Weighted bundle
    var weights = [_]f64{ 0.5, 0.3, 0.1, 0.05, 0.02, 0.01, 0.01, 0.005, 0.003, 0.002 };
    const weighted = weightedBundle(&vectors, &weights);

    try stdout.print("  Weighted bundle similarity to first: {d:.4}\n", .{weighted.similarity(&vectors[0])});
    try stdout.print("  Weighted bundle similarity to last:  {d:.4}\n\n", .{weighted.similarity(&vectors[9])});

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Golden Ratio Verification
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("5. GOLDEN RATIO VERIFICATION\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    const phi = trinity.PHI;
    const phi_sq = trinity.PHI_SQUARED;
    const identity = phi_sq + 1.0 / phi_sq;

    try stdout.print("φ (golden ratio):     {d:.15}\n", .{phi});
    try stdout.print("φ²:                   {d:.15}\n", .{phi_sq});
    try stdout.print("φ² + 1/φ²:            {d:.15}\n", .{identity});
    try stdout.print("Expected (3):         {d:.15}\n", .{trinity.GOLDEN_IDENTITY});
    try stdout.print("Error:                {e:.2}\n\n", .{@abs(identity - 3.0)});

    // ─────────────────────────────────────────────────────────────────────────
    // Summary
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                    SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("✓ Statistical analysis: entropy, density, balance\n", .{});
    try stdout.print("✓ Distance metrics: Hamming, Cosine, Euclidean, etc.\n", .{});
    try stdout.print("✓ Information theory: mutual information\n", .{});
    try stdout.print("✓ Batch operations: bundle, weighted bundle\n", .{});
    try stdout.print("✓ Mathematical constants: φ, φ², golden identity\n", .{});
    try stdout.print("\nⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q\n\n", .{});
}
