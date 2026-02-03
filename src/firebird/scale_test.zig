// ═══════════════════════════════════════════════════════════════════════════════
// FIREBIRD SCALE TEST - Testing 100K Dimensions
// Validates orthogonality and evolution at extreme scales
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa.zig");
const vsa_simd = @import("vsa_simd.zig");
const evolution = @import("evolution.zig");

const TritVec = vsa.TritVec;

// ═══════════════════════════════════════════════════════════════════════════════
// SCALE CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DIM_10K: usize = 10_000;
pub const DIM_50K: usize = 50_000;
pub const DIM_100K: usize = 100_000;

// ═══════════════════════════════════════════════════════════════════════════════
// ORTHOGONALITY ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

pub const OrthogonalityStats = struct {
    dimension: usize,
    num_pairs: usize,
    mean_similarity: f64,
    max_similarity: f64,
    min_similarity: f64,
    std_dev: f64,
    orthogonal_ratio: f64, // Fraction with |sim| < 0.1
};

/// Analyze orthogonality of random vectors at given dimension
pub fn analyzeOrthogonality(
    allocator: std.mem.Allocator,
    dim: usize,
    num_vectors: usize,
    seed: u64,
) !OrthogonalityStats {
    // Create random vectors
    const vectors = try allocator.alloc(TritVec, num_vectors);
    defer {
        for (vectors) |*v| v.deinit();
        allocator.free(vectors);
    }

    for (0..num_vectors) |i| {
        vectors[i] = try TritVec.random(allocator, dim, seed +% @as(u64, @intCast(i)));
    }

    // Compute pairwise similarities
    const num_pairs = (num_vectors * (num_vectors - 1)) / 2;
    const similarities = try allocator.alloc(f64, num_pairs);
    defer allocator.free(similarities);

    var pair_idx: usize = 0;
    for (0..num_vectors) |i| {
        for ((i + 1)..num_vectors) |j| {
            similarities[pair_idx] = vsa_simd.cosineSimilaritySimd(&vectors[i], &vectors[j]);
            pair_idx += 1;
        }
    }

    // Compute statistics
    var sum: f64 = 0;
    var max_sim: f64 = -2.0;
    var min_sim: f64 = 2.0;
    var orthogonal_count: usize = 0;

    for (similarities) |sim| {
        sum += sim;
        if (sim > max_sim) max_sim = sim;
        if (sim < min_sim) min_sim = sim;
        if (@abs(sim) < 0.1) orthogonal_count += 1;
    }

    const mean = sum / @as(f64, @floatFromInt(num_pairs));

    // Compute std dev
    var variance_sum: f64 = 0;
    for (similarities) |sim| {
        const diff = sim - mean;
        variance_sum += diff * diff;
    }
    const std_dev = @sqrt(variance_sum / @as(f64, @floatFromInt(num_pairs)));

    return OrthogonalityStats{
        .dimension = dim,
        .num_pairs = num_pairs,
        .mean_similarity = mean,
        .max_similarity = max_sim,
        .min_similarity = min_sim,
        .std_dev = std_dev,
        .orthogonal_ratio = @as(f64, @floatFromInt(orthogonal_count)) / @as(f64, @floatFromInt(num_pairs)),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScaleBenchmark = struct {
    dimension: usize,
    bind_ns: u64,
    dot_product_ns: u64,
    similarity_ns: u64,
    memory_bytes: usize,
};

/// Benchmark operations at given dimension
pub fn benchmarkScale(allocator: std.mem.Allocator, dim: usize, iterations: usize, seed: u64) !ScaleBenchmark {
    var a = try TritVec.random(allocator, dim, seed);
    defer a.deinit();
    var b = try TritVec.random(allocator, dim, seed +% 1);
    defer b.deinit();

    // Warmup
    for (0..5) |_| {
        var r = try vsa_simd.bindSimd(allocator, &a, &b);
        r.deinit();
    }

    // Bind benchmark
    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        var r = try vsa_simd.bindSimd(allocator, &a, &b);
        r.deinit();
    }
    const bind_ns = timer.read() / iterations;

    // Dot product benchmark
    timer.reset();
    for (0..iterations) |_| {
        _ = vsa_simd.dotProductSimd(&a, &b);
    }
    const dot_ns = timer.read() / iterations;

    // Similarity benchmark
    timer.reset();
    for (0..iterations) |_| {
        _ = vsa_simd.cosineSimilaritySimd(&a, &b);
    }
    const sim_ns = timer.read() / iterations;

    return ScaleBenchmark{
        .dimension = dim,
        .bind_ns = bind_ns,
        .dot_product_ns = dot_ns,
        .similarity_ns = sim_ns,
        .memory_bytes = dim * @sizeOf(vsa.Trit),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVOLUTION AT SCALE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScaleEvolutionResult = struct {
    dimension: usize,
    generations: u32,
    total_ms: u64,
    ms_per_generation: u64,
    final_fitness: f64,
    converged: bool,
};

/// Run evolution at given dimension
pub fn evolveAtScale(
    allocator: std.mem.Allocator,
    dim: usize,
    pop_size: usize,
    max_generations: usize,
    seed: u64,
) !ScaleEvolutionResult {
    var human = try TritVec.random(allocator, dim, seed);
    defer human.deinit();

    var population = try evolution.Population.init(allocator, pop_size, dim, seed +% 1);
    defer population.deinit();

    const config = evolution.EvolutionConfig{
        .population_size = pop_size,
        .max_generations = max_generations,
        .tournament_size = 3,
        .target_fitness = 0.9,
    };

    var timer = try std.time.Timer.start();
    const stats = try evolution.evolve(allocator, &population, &human, &config, seed +% 2);
    const total_ns = timer.read();

    return ScaleEvolutionResult{
        .dimension = dim,
        .generations = stats.generations,
        .total_ms = total_ns / 1_000_000,
        .ms_per_generation = if (stats.generations > 0) total_ns / 1_000_000 / stats.generations else 0,
        .final_fitness = stats.best_fitness,
        .converged = stats.converged,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVASION QUALITY COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════

pub const EvasionQuality = struct {
    dimension: usize,
    fingerprint_uniqueness: f64, // How different from other fingerprints
    human_similarity: f64, // How similar to human pattern
    detection_resistance: f64, // Combined score
};

/// Compare evasion quality at different dimensions
pub fn compareEvasionQuality(
    allocator: std.mem.Allocator,
    dim: usize,
    num_fingerprints: usize,
    seed: u64,
) !EvasionQuality {
    // Create human pattern
    var human = try TritVec.random(allocator, dim, seed);
    defer human.deinit();

    // Create evolved fingerprints
    const fingerprints = try allocator.alloc(TritVec, num_fingerprints);
    defer {
        for (fingerprints) |*f| f.deinit();
        allocator.free(fingerprints);
    }

    var total_human_sim: f64 = 0;

    for (0..num_fingerprints) |i| {
        var initial = try TritVec.random(allocator, dim, seed +% @as(u64, @intCast(i)) +% 100);
        defer initial.deinit();

        const config = evolution.EvolutionConfig{
            .population_size = 30,
            .max_generations = 20, // More generations to reach target
            .tournament_size = 3,
        };

        const result = try evolution.evolveFingerprint(allocator, &initial, &human, &config, seed +% @as(u64, @intCast(i)) +% 200);
        fingerprints[i] = result.fingerprint;
        total_human_sim += vsa_simd.cosineSimilaritySimd(&fingerprints[i], &human);
    }

    // Compute uniqueness (average pairwise distance)
    var total_distance: f64 = 0;
    var pair_count: usize = 0;
    for (0..num_fingerprints) |i| {
        for ((i + 1)..num_fingerprints) |j| {
            const sim = vsa_simd.cosineSimilaritySimd(&fingerprints[i], &fingerprints[j]);
            total_distance += 1.0 - @abs(sim); // Distance = 1 - |similarity|
            pair_count += 1;
        }
    }

    const avg_uniqueness = if (pair_count > 0) total_distance / @as(f64, @floatFromInt(pair_count)) else 1.0;
    const avg_human_sim = total_human_sim / @as(f64, @floatFromInt(num_fingerprints));

    // Detection resistance = uniqueness * (1 - |human_sim - 0.7|)
    // Best when fingerprints are unique AND have ~0.7 similarity to human
    const human_sim_score = 1.0 - @abs(avg_human_sim - 0.7);
    const detection_resistance = avg_uniqueness * human_sim_score;

    return EvasionQuality{
        .dimension = dim,
        .fingerprint_uniqueness = avg_uniqueness,
        .human_similarity = avg_human_sim,
        .detection_resistance = detection_resistance,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "orthogonality at 10K dimensions" {
    const allocator = std.testing.allocator;
    const stats = try analyzeOrthogonality(allocator, DIM_10K, 10, 12345);

    std.debug.print("\nOrthogonality at DIM=10K:\n", .{});
    std.debug.print("  Mean similarity: {d:.6}\n", .{stats.mean_similarity});
    std.debug.print("  Max similarity: {d:.6}\n", .{stats.max_similarity});
    std.debug.print("  Std dev: {d:.6}\n", .{stats.std_dev});
    std.debug.print("  Orthogonal ratio: {d:.2}%\n", .{stats.orthogonal_ratio * 100});

    // At 10K, random vectors should be nearly orthogonal
    try std.testing.expect(@abs(stats.mean_similarity) < 0.05);
    try std.testing.expect(stats.orthogonal_ratio > 0.8);
}

test "orthogonality at 50K dimensions" {
    const allocator = std.testing.allocator;
    const stats = try analyzeOrthogonality(allocator, DIM_50K, 10, 23456);

    std.debug.print("\nOrthogonality at DIM=50K:\n", .{});
    std.debug.print("  Mean similarity: {d:.6}\n", .{stats.mean_similarity});
    std.debug.print("  Max similarity: {d:.6}\n", .{stats.max_similarity});
    std.debug.print("  Std dev: {d:.6}\n", .{stats.std_dev});
    std.debug.print("  Orthogonal ratio: {d:.2}%\n", .{stats.orthogonal_ratio * 100});

    // At 50K, should be even more orthogonal
    try std.testing.expect(@abs(stats.mean_similarity) < 0.02);
    try std.testing.expect(stats.orthogonal_ratio > 0.95);
}

test "orthogonality at 100K dimensions" {
    const allocator = std.testing.allocator;
    const stats = try analyzeOrthogonality(allocator, DIM_100K, 10, 34567);

    std.debug.print("\nOrthogonality at DIM=100K:\n", .{});
    std.debug.print("  Mean similarity: {d:.6}\n", .{stats.mean_similarity});
    std.debug.print("  Max similarity: {d:.6}\n", .{stats.max_similarity});
    std.debug.print("  Std dev: {d:.6}\n", .{stats.std_dev});
    std.debug.print("  Orthogonal ratio: {d:.2}%\n", .{stats.orthogonal_ratio * 100});

    // At 100K, should be extremely orthogonal
    try std.testing.expect(@abs(stats.mean_similarity) < 0.01);
    try std.testing.expect(stats.orthogonal_ratio > 0.99);
}

test "benchmark 10K vs 50K vs 100K" {
    const allocator = std.testing.allocator;

    const bench_10k = try benchmarkScale(allocator, DIM_10K, 100, 11111);
    const bench_50k = try benchmarkScale(allocator, DIM_50K, 100, 22222);
    const bench_100k = try benchmarkScale(allocator, DIM_100K, 100, 33333);

    std.debug.print("\nPerformance comparison:\n", .{});
    std.debug.print("  DIM=10K:  bind={d}us, dot={d}us, sim={d}us, mem={d}KB\n", .{
        bench_10k.bind_ns / 1000,
        bench_10k.dot_product_ns / 1000,
        bench_10k.similarity_ns / 1000,
        bench_10k.memory_bytes / 1024,
    });
    std.debug.print("  DIM=50K:  bind={d}us, dot={d}us, sim={d}us, mem={d}KB\n", .{
        bench_50k.bind_ns / 1000,
        bench_50k.dot_product_ns / 1000,
        bench_50k.similarity_ns / 1000,
        bench_50k.memory_bytes / 1024,
    });
    std.debug.print("  DIM=100K: bind={d}us, dot={d}us, sim={d}us, mem={d}KB\n", .{
        bench_100k.bind_ns / 1000,
        bench_100k.dot_product_ns / 1000,
        bench_100k.similarity_ns / 1000,
        bench_100k.memory_bytes / 1024,
    });

    // 100K should be ~10x slower than 10K (linear scaling)
    try std.testing.expect(bench_100k.bind_ns < bench_10k.bind_ns * 20);
}

test "evolution at 100K dimensions" {
    const allocator = std.testing.allocator;

    // Run 20 generations to reach target
    const result = try evolveAtScale(allocator, DIM_100K, 30, 20, 44444);

    std.debug.print("\nEvolution at DIM=100K (20 generations):\n", .{});
    std.debug.print("  Generations: {d}\n", .{result.generations});
    std.debug.print("  Total time: {d}ms\n", .{result.total_ms});
    std.debug.print("  Per generation: {d}ms\n", .{result.ms_per_generation});
    std.debug.print("  Final fitness: {d:.4}\n", .{result.final_fitness});
    std.debug.print("  Converged: {}\n", .{result.converged});

    // Should complete in reasonable time
    try std.testing.expect(result.total_ms < 30000); // < 30 seconds
    try std.testing.expect(result.final_fitness > 0.5);
}

test "evasion quality comparison 10K vs 100K" {
    const allocator = std.testing.allocator;

    std.debug.print("\nEvasion quality comparison (this may take a moment)...\n", .{});

    const quality_10k = try compareEvasionQuality(allocator, DIM_10K, 5, 55555);
    const quality_100k = try compareEvasionQuality(allocator, DIM_100K, 5, 66666);

    std.debug.print("\nEvasion quality at DIM=10K:\n", .{});
    std.debug.print("  Uniqueness: {d:.4}\n", .{quality_10k.fingerprint_uniqueness});
    std.debug.print("  Human similarity: {d:.4}\n", .{quality_10k.human_similarity});
    std.debug.print("  Detection resistance: {d:.4}\n", .{quality_10k.detection_resistance});

    std.debug.print("\nEvasion quality at DIM=100K:\n", .{});
    std.debug.print("  Uniqueness: {d:.4}\n", .{quality_100k.fingerprint_uniqueness});
    std.debug.print("  Human similarity: {d:.4}\n", .{quality_100k.human_similarity});
    std.debug.print("  Detection resistance: {d:.4}\n", .{quality_100k.detection_resistance});

    // 100K should have better uniqueness (more orthogonal)
    try std.testing.expect(quality_100k.fingerprint_uniqueness >= quality_10k.fingerprint_uniqueness - 0.1);
}
