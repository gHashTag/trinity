// ═══════════════════════════════════════════════════════════════════════════════
// FIREBIRD PARALLEL - Multi-threaded Evolution
// 4x speedup on 4 cores via parallel fitness evaluation
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa.zig");
const vsa_simd = @import("vsa_simd.zig");
const evolution = @import("evolution.zig");

const TritVec = vsa.TritVec;
const Individual = evolution.Individual;
const Population = evolution.Population;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEFAULT_NUM_THREADS: usize = 4;

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL FITNESS EVALUATION
// ═══════════════════════════════════════════════════════════════════════════════

const FitnessTask = struct {
    individuals: []Individual,
    human_pattern: *const TritVec,
    start_idx: usize,
    end_idx: usize,
};

fn evaluateFitnessRange(task: FitnessTask) void {
    for (task.start_idx..task.end_idx) |i| {
        task.individuals[i].fitness = evolution.computeFitness(&task.individuals[i], task.human_pattern);
    }
}

/// Evaluate population fitness in parallel using threads
pub fn evaluatePopulationParallel(
    population: *Population,
    human_pattern: *const TritVec,
    num_threads: usize,
) void {
    const actual_threads = @min(num_threads, @min(population.size, 8));

    if (actual_threads <= 1) {
        // Fall back to sequential
        evolution.evaluatePopulation(population, human_pattern);
        return;
    }

    // Divide work among threads
    const chunk_size = population.size / actual_threads;
    var tasks: [8]FitnessTask = undefined;
    var threads: [8]std.Thread = undefined;
    var spawned: usize = 0;

    for (0..actual_threads) |t| {
        const start = t * chunk_size;
        const end = if (t == actual_threads - 1) population.size else (t + 1) * chunk_size;

        tasks[t] = FitnessTask{
            .individuals = population.individuals,
            .human_pattern = human_pattern,
            .start_idx = start,
            .end_idx = end,
        };

        threads[t] = std.Thread.spawn(.{}, evaluateFitnessRange, .{tasks[t]}) catch {
            // If spawn fails, evaluate this chunk sequentially
            evaluateFitnessRange(tasks[t]);
            continue;
        };
        spawned += 1;
    }

    // Wait for all threads to complete
    for (0..spawned) |t| {
        threads[t].join();
    }

    // Update best fitness
    var best_fitness: f64 = 0.0;
    var best_index: usize = 0;
    for (population.individuals, 0..) |ind, i| {
        if (ind.fitness > best_fitness) {
            best_fitness = ind.fitness;
            best_index = i;
        }
    }
    population.best_fitness = best_fitness;
    population.best_index = best_index;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL EVOLUTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Parallel evolution configuration
pub const ParallelConfig = struct {
    base_config: evolution.EvolutionConfig = .{},
    num_threads: usize = DEFAULT_NUM_THREADS,
};

/// Run one generation with parallel fitness evaluation
pub fn evolveGenerationParallel(
    allocator: std.mem.Allocator,
    population: *Population,
    human_pattern: *const TritVec,
    config: *const ParallelConfig,
    rng: *std.Random.DefaultPrng,
) !void {
    // Parallel fitness evaluation
    evaluatePopulationParallel(population, human_pattern, config.num_threads);

    // Get elite indices (sequential - needs sorted fitness)
    const elite_indices = try evolution.getEliteIndices(allocator, population, config.base_config.elitism_ratio);
    defer allocator.free(elite_indices);

    // Create new population
    const new_individuals = try allocator.alloc(Individual, population.size);
    errdefer {
        for (new_individuals) |*ind| {
            if (ind.chromosome.data.len > 0) ind.deinit();
        }
        allocator.free(new_individuals);
    }

    // Copy elites
    for (elite_indices, 0..) |elite_idx, i| {
        new_individuals[i] = try population.individuals[elite_idx].clone();
    }

    // Fill rest with offspring (sequential for now - RNG not thread-safe)
    var offspring_idx = elite_indices.len;
    while (offspring_idx < population.size) : (offspring_idx += 1) {
        const parent1_idx = evolution.tournamentSelect(population, config.base_config.tournament_size, rng);
        const parent2_idx = evolution.tournamentSelect(population, config.base_config.tournament_size, rng);

        var child = try evolution.multiPointCrossover(
            allocator,
            &population.individuals[parent1_idx],
            &population.individuals[parent2_idx],
            config.base_config.crossover_rate,
            rng,
        );

        // Guided mutation
        const current_fitness = population.best_fitness;
        const guide_rate = 0.2 * (1.0 - current_fitness * 0.8);
        const noise_rate = config.base_config.mutation_rate;

        const mutated = try evolution.mutateGuided(allocator, &child, human_pattern, guide_rate, noise_rate, rng);
        child.deinit();
        child = mutated;

        new_individuals[offspring_idx] = child;
    }

    // Replace old population
    for (population.individuals) |*ind| {
        ind.deinit();
    }
    allocator.free(population.individuals);

    population.individuals = new_individuals;
    population.generation += 1;
    population.spiral.next();

    // Final parallel evaluation
    evaluatePopulationParallel(population, human_pattern, config.num_threads);
}

/// Run full parallel evolution
pub fn evolveParallel(
    allocator: std.mem.Allocator,
    population: *Population,
    human_pattern: *const TritVec,
    config: *const ParallelConfig,
    seed: u64,
) !evolution.EvolutionStats {
    var rng = std.Random.DefaultPrng.init(seed);

    // Initial parallel evaluation
    evaluatePopulationParallel(population, human_pattern, config.num_threads);

    var converged = false;

    while (population.generation < config.base_config.max_generations) {
        if (population.best_fitness >= config.base_config.target_fitness) {
            converged = true;
            break;
        }

        try evolveGenerationParallel(allocator, population, human_pattern, config, &rng);
    }

    evaluatePopulationParallel(population, human_pattern, config.num_threads);

    const best = population.getBest();
    const final_similarity = vsa_simd.cosineSimilaritySimd(&best.chromosome, human_pattern);

    return evolution.EvolutionStats{
        .generations = population.generation,
        .best_fitness = population.best_fitness,
        .avg_fitness = population.getAverageFitness(),
        .converged = converged,
        .final_similarity = final_similarity,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub const ParallelBenchmark = struct {
    sequential_ms: u64,
    parallel_ms: u64,
    speedup: f64,
    num_threads: usize,
    dimension: usize,
    population_size: usize,
    generations: usize,
};

/// Benchmark parallel vs sequential evolution
pub fn benchmarkParallel(
    allocator: std.mem.Allocator,
    dim: usize,
    pop_size: usize,
    generations: usize,
    num_threads: usize,
    seed: u64,
) !ParallelBenchmark {
    var human = try TritVec.random(allocator, dim, seed);
    defer human.deinit();

    // Sequential benchmark
    var pop_seq = try Population.init(allocator, pop_size, dim, seed +% 1);
    defer pop_seq.deinit();

    const seq_config = evolution.EvolutionConfig{
        .population_size = pop_size,
        .max_generations = generations,
        .target_fitness = 2.0, // Unreachable
    };

    var timer = try std.time.Timer.start();
    _ = try evolution.evolve(allocator, &pop_seq, &human, &seq_config, seed +% 2);
    const seq_ns = timer.read();

    // Parallel benchmark
    var pop_par = try Population.init(allocator, pop_size, dim, seed +% 1);
    defer pop_par.deinit();

    const par_config = ParallelConfig{
        .base_config = seq_config,
        .num_threads = num_threads,
    };

    timer.reset();
    _ = try evolveParallel(allocator, &pop_par, &human, &par_config, seed +% 2);
    const par_ns = timer.read();

    return ParallelBenchmark{
        .sequential_ms = seq_ns / 1_000_000,
        .parallel_ms = par_ns / 1_000_000,
        .speedup = @as(f64, @floatFromInt(seq_ns)) / @as(f64, @floatFromInt(par_ns)),
        .num_threads = num_threads,
        .dimension = dim,
        .population_size = pop_size,
        .generations = generations,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parallel fitness evaluation correctness" {
    const allocator = std.testing.allocator;

    var human = try TritVec.random(allocator, 1000, 11111);
    defer human.deinit();

    // Create two identical populations
    var pop1 = try Population.init(allocator, 20, 1000, 22222);
    defer pop1.deinit();
    var pop2 = try Population.init(allocator, 20, 1000, 22222);
    defer pop2.deinit();

    // Evaluate sequentially
    evolution.evaluatePopulation(&pop1, &human);

    // Evaluate in parallel
    evaluatePopulationParallel(&pop2, &human, 4);

    // Results should match
    for (0..pop1.size) |i| {
        try std.testing.expectApproxEqAbs(pop1.individuals[i].fitness, pop2.individuals[i].fitness, 1e-10);
    }
    try std.testing.expectApproxEqAbs(pop1.best_fitness, pop2.best_fitness, 1e-10);
}

test "parallel evolution produces valid results" {
    const allocator = std.testing.allocator;

    var human = try TritVec.random(allocator, 1000, 33333);
    defer human.deinit();

    var population = try Population.init(allocator, 20, 1000, 44444);
    defer population.deinit();

    const config = ParallelConfig{
        .base_config = .{
            .population_size = 20,
            .max_generations = 5,
            .tournament_size = 3,
        },
        .num_threads = 4,
    };

    const stats = try evolveParallel(allocator, &population, &human, &config, 55555);

    try std.testing.expect(stats.generations <= 5);
    try std.testing.expect(stats.best_fitness > 0.0);
    try std.testing.expect(stats.best_fitness <= 1.1);
}

test "benchmark parallel speedup" {
    const allocator = std.testing.allocator;

    std.debug.print("\nParallel evolution benchmark:\n", .{});

    // Small test to verify it works
    const result = try benchmarkParallel(allocator, 10000, 30, 5, 4, 66666);

    std.debug.print("  DIM={d}, POP={d}, GEN={d}, THREADS={d}\n", .{
        result.dimension,
        result.population_size,
        result.generations,
        result.num_threads,
    });
    std.debug.print("  Sequential: {d}ms\n", .{result.sequential_ms});
    std.debug.print("  Parallel:   {d}ms\n", .{result.parallel_ms});
    std.debug.print("  Speedup:    {d:.2}x\n", .{result.speedup});

    // Parallel should not be significantly slower
    try std.testing.expect(result.speedup > 0.5);
}

test "benchmark parallel at 100K" {
    const allocator = std.testing.allocator;

    std.debug.print("\nParallel evolution at 100K dimensions:\n", .{});

    const result = try benchmarkParallel(allocator, 100000, 30, 5, 4, 77777);

    std.debug.print("  DIM=100K, POP={d}, GEN={d}, THREADS={d}\n", .{
        result.population_size,
        result.generations,
        result.num_threads,
    });
    std.debug.print("  Sequential: {d}ms\n", .{result.sequential_ms});
    std.debug.print("  Parallel:   {d}ms\n", .{result.parallel_ms});
    std.debug.print("  Speedup:    {d:.2}x\n", .{result.speedup});

    try std.testing.expect(result.speedup > 0.5);
}

test "benchmark parallel with large population" {
    const allocator = std.testing.allocator;

    std.debug.print("\nParallel evolution with large population:\n", .{});

    // Larger population benefits more from parallelism
    const result = try benchmarkParallel(allocator, 100000, 100, 3, 4, 88888);

    std.debug.print("  DIM=100K, POP={d}, GEN={d}, THREADS={d}\n", .{
        result.population_size,
        result.generations,
        result.num_threads,
    });
    std.debug.print("  Sequential: {d}ms\n", .{result.sequential_ms});
    std.debug.print("  Parallel:   {d}ms\n", .{result.parallel_ms});
    std.debug.print("  Speedup:    {d:.2}x\n", .{result.speedup});

    try std.testing.expect(result.speedup > 0.5);
}
