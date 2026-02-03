// ═══════════════════════════════════════════════════════════════════════════════
// FIREBIRD EVOLUTION - Genetic Algorithm for Fingerprint Evasion
// Self-evolving fingerprints via φ-spiral mutations
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const vsa = @import("vsa.zig");
const vsa_simd = @import("vsa_simd.zig");
const firebird = @import("firebird.zig");

const TritVec = vsa.TritVec;
const Trit = vsa.Trit;
const PhiSpiral = firebird.PhiSpiral;

// Use SIMD operations for performance
const cosineSimilarity = vsa_simd.cosineSimilaritySimd;
const dotProduct = vsa_simd.dotProductSimd;
const hammingDistance = vsa_simd.hammingDistanceSimd;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEFAULT_POPULATION_SIZE: usize = 50;
pub const DEFAULT_MAX_GENERATIONS: usize = 100;
pub const DEFAULT_TOURNAMENT_SIZE: usize = 3;
pub const TARGET_FITNESS: f64 = 0.95;

// Evolution parameters (from firebird)
pub const MU: f64 = firebird.MU; // 0.0382
pub const CHI: f64 = firebird.CHI; // 0.0618
pub const SIGMA: f64 = firebird.SIGMA; // 1.618
pub const EPSILON: f64 = firebird.EPSILON; // 0.333

pub const PHI: f64 = firebird.PHI;
pub const HUMAN_SIMILARITY_THRESHOLD: f64 = firebird.HUMAN_SIMILARITY_THRESHOLD;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Individual in the population
pub const Individual = struct {
    allocator: std.mem.Allocator,
    chromosome: TritVec,
    fitness: f64,
    age: u32,

    pub fn init(allocator: std.mem.Allocator, dim: usize, seed: u64) !Individual {
        return Individual{
            .allocator = allocator,
            .chromosome = try TritVec.random(allocator, dim, seed),
            .fitness = 0.0,
            .age = 0,
        };
    }

    pub fn fromChromosome(allocator: std.mem.Allocator, chromosome: TritVec) Individual {
        return Individual{
            .allocator = allocator,
            .chromosome = chromosome,
            .fitness = 0.0,
            .age = 0,
        };
    }

    pub fn deinit(self: *Individual) void {
        self.chromosome.deinit();
    }

    pub fn clone(self: *const Individual) !Individual {
        return Individual{
            .allocator = self.allocator,
            .chromosome = try self.chromosome.clone(),
            .fitness = self.fitness,
            .age = self.age,
        };
    }
};

/// Population of individuals
pub const Population = struct {
    allocator: std.mem.Allocator,
    individuals: []Individual,
    size: usize,
    generation: u32,
    best_fitness: f64,
    best_index: usize,
    spiral: PhiSpiral,

    pub fn init(allocator: std.mem.Allocator, size: usize, dim: usize, base_seed: u64) !Population {
        const individuals = try allocator.alloc(Individual, size);
        errdefer allocator.free(individuals);

        for (0..size) |i| {
            individuals[i] = try Individual.init(allocator, dim, base_seed +% @as(u64, @intCast(i)));
        }

        return Population{
            .allocator = allocator,
            .individuals = individuals,
            .size = size,
            .generation = 0,
            .best_fitness = 0.0,
            .best_index = 0,
            .spiral = PhiSpiral.init(0),
        };
    }

    pub fn deinit(self: *Population) void {
        for (self.individuals) |*ind| {
            ind.deinit();
        }
        self.allocator.free(self.individuals);
    }

    /// Get the best individual
    pub fn getBest(self: *const Population) *const Individual {
        return &self.individuals[self.best_index];
    }

    /// Get average fitness
    pub fn getAverageFitness(self: *const Population) f64 {
        var sum: f64 = 0.0;
        for (self.individuals) |ind| {
            sum += ind.fitness;
        }
        return sum / @as(f64, @floatFromInt(self.size));
    }
};

/// Evolution configuration
pub const EvolutionConfig = struct {
    population_size: usize = DEFAULT_POPULATION_SIZE,
    max_generations: usize = DEFAULT_MAX_GENERATIONS,
    tournament_size: usize = DEFAULT_TOURNAMENT_SIZE,
    mutation_rate: f64 = MU,
    crossover_rate: f64 = CHI,
    selection_pressure: f64 = SIGMA,
    elitism_ratio: f64 = EPSILON,
    target_fitness: f64 = TARGET_FITNESS,
    adaptive_mutation: bool = true,
};

/// Evolution statistics
pub const EvolutionStats = struct {
    generations: u32,
    best_fitness: f64,
    avg_fitness: f64,
    converged: bool,
    final_similarity: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FITNESS EVALUATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute fitness based on similarity to human pattern (SIMD-accelerated)
/// Fitness is maximized when similarity is close to HUMAN_SIMILARITY_THRESHOLD
/// 
/// For high dimensions, random vectors are orthogonal (sim ~0).
/// We use a progressive fitness that rewards ANY movement towards target.
pub fn computeFitness(individual: *const Individual, human_pattern: *const TritVec) f64 {
    const sim = cosineSimilarity(&individual.chromosome, human_pattern);

    // Target similarity is ~0.7 (human-like but not identical)
    const target = HUMAN_SIMILARITY_THRESHOLD;

    // Progressive fitness function:
    // - If sim < target: reward progress towards target (sim / target)
    // - If sim >= target: reward being in sweet spot, penalize being too similar
    var fitness: f64 = 0.0;

    if (sim < target) {
        // Below target: fitness proportional to progress (0 to 1 as sim goes 0 to 0.7)
        fitness = sim / target;
    } else if (sim <= 0.85) {
        // Sweet spot (0.7 - 0.85): maximum fitness
        fitness = 1.0 + (sim - target) * 0.5; // Bonus for being slightly above
    } else if (sim <= 0.95) {
        // Getting too similar (0.85 - 0.95): decreasing fitness
        fitness = 1.0 - (sim - 0.85) * 2.0;
    } else {
        // Too similar (> 0.95): detectable as copy
        fitness = 0.5 - (sim - 0.95) * 5.0;
    }

    return @max(0.0, @min(1.1, fitness));
}

/// Evaluate fitness for entire population
pub fn evaluatePopulation(population: *Population, human_pattern: *const TritVec) void {
    var best_fitness: f64 = 0.0;
    var best_index: usize = 0;

    for (population.individuals, 0..) |*ind, i| {
        ind.fitness = computeFitness(ind, human_pattern);
        if (ind.fitness > best_fitness) {
            best_fitness = ind.fitness;
            best_index = i;
        }
    }

    population.best_fitness = best_fitness;
    population.best_index = best_index;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOURNAMENT SELECTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Select parent via tournament selection
pub fn tournamentSelect(
    population: *const Population,
    tournament_size: usize,
    rng: *std.Random.DefaultPrng,
) usize {
    const rand = rng.random();
    var best_index: usize = rand.intRangeAtMost(usize, 0, population.size - 1);
    var best_fitness = population.individuals[best_index].fitness;

    for (1..tournament_size) |_| {
        const candidate = rand.intRangeAtMost(usize, 0, population.size - 1);
        const candidate_fitness = population.individuals[candidate].fitness;

        if (candidate_fitness > best_fitness) {
            best_index = candidate;
            best_fitness = candidate_fitness;
        }
    }

    return best_index;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-POINT CROSSOVER
// ═══════════════════════════════════════════════════════════════════════════════

/// Multi-point crossover (2 crossover points)
pub fn multiPointCrossover(
    allocator: std.mem.Allocator,
    parent1: *const Individual,
    parent2: *const Individual,
    crossover_rate: f64,
    rng: *std.Random.DefaultPrng,
) !Individual {
    const rand = rng.random();
    const len = @min(parent1.chromosome.len, parent2.chromosome.len);

    // Check if crossover happens
    if (rand.float(f64) > crossover_rate) {
        // No crossover - return clone of random parent
        if (rand.float(f64) < 0.5) {
            return parent1.clone();
        } else {
            return parent2.clone();
        }
    }

    const data = try allocator.alloc(Trit, len);

    // Two crossover points
    const point1 = rand.intRangeAtMost(usize, 0, len / 2);
    const point2 = rand.intRangeAtMost(usize, len / 2, len - 1);

    // Copy segments alternating between parents
    for (0..len) |i| {
        if (i < point1) {
            data[i] = parent1.chromosome.data[i];
        } else if (i < point2) {
            data[i] = parent2.chromosome.data[i];
        } else {
            data[i] = parent1.chromosome.data[i];
        }
    }

    const chromosome = TritVec{
        .allocator = allocator,
        .data = data,
        .len = len,
    };

    return Individual.fromChromosome(allocator, chromosome);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTIVE MUTATION WITH φ-SPIRAL
// ═══════════════════════════════════════════════════════════════════════════════

/// Adaptive mutation rate based on φ-spiral and fitness
pub fn adaptiveMutationRate(
    base_rate: f64,
    fitness: f64,
    spiral: *const PhiSpiral,
) f64 {
    // Lower mutation for high-fitness individuals
    const fitness_factor = 1.0 - (fitness * 0.5);

    // φ-spiral modulation
    const pos = spiral.getPosition();
    const spiral_factor = 1.0 + 0.3 * @sin(pos.x / 50.0) * @cos(pos.y / 50.0);

    return base_rate * fitness_factor * spiral_factor;
}

/// Mutate individual with adaptive rate
pub fn mutateAdaptive(
    allocator: std.mem.Allocator,
    individual: *const Individual,
    base_rate: f64,
    spiral: *const PhiSpiral,
    rng: *std.Random.DefaultPrng,
) !Individual {
    const rate = adaptiveMutationRate(base_rate, individual.fitness, spiral);
    const rand = rng.random();

    const data = try allocator.alloc(Trit, individual.chromosome.len);
    @memcpy(data, individual.chromosome.data);

    for (data) |*trit| {
        if (rand.float(f64) < rate) {
            // Balanced ternary mutation
            const current = trit.*;
            const r = rand.float(f32);

            if (current == 0) {
                trit.* = if (r < 0.5) -1 else 1;
            } else if (current == 1) {
                trit.* = if (r < 0.5) -1 else 0;
            } else {
                trit.* = if (r < 0.5) 0 else 1;
            }
        }
    }

    const chromosome = TritVec{
        .allocator = allocator,
        .data = data,
        .len = individual.chromosome.len,
    };

    return Individual.fromChromosome(allocator, chromosome);
}

/// Guided mutation that moves vector towards human pattern
/// This is essential for high-dimensional spaces where random mutation
/// cannot increase similarity (curse of dimensionality)
pub fn mutateGuided(
    allocator: std.mem.Allocator,
    individual: *const Individual,
    human_pattern: *const TritVec,
    guide_rate: f64,
    noise_rate: f64,
    rng: *std.Random.DefaultPrng,
) !Individual {
    const rand = rng.random();
    const len = @min(individual.chromosome.len, human_pattern.len);

    const data = try allocator.alloc(Trit, len);
    @memcpy(data, individual.chromosome.data[0..len]);

    for (0..len) |i| {
        const r = rand.float(f64);

        if (r < guide_rate) {
            // Guided mutation: copy from human pattern
            data[i] = human_pattern.data[i];
        } else if (r < guide_rate + noise_rate) {
            // Random noise mutation
            const current = data[i];
            const nr = rand.float(f32);
            if (current == 0) {
                data[i] = if (nr < 0.5) -1 else 1;
            } else if (current == 1) {
                data[i] = if (nr < 0.5) -1 else 0;
            } else {
                data[i] = if (nr < 0.5) 0 else 1;
            }
        }
        // else: keep original value
    }

    const chromosome = TritVec{
        .allocator = allocator,
        .data = data,
        .len = len,
    };

    return Individual.fromChromosome(allocator, chromosome);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ELITISM
// ═══════════════════════════════════════════════════════════════════════════════

/// Get indices of elite individuals (top ε fraction)
pub fn getEliteIndices(
    allocator: std.mem.Allocator,
    population: *const Population,
    elitism_ratio: f64,
) ![]usize {
    const elite_count = @max(1, @as(usize, @intFromFloat(@as(f64, @floatFromInt(population.size)) * elitism_ratio)));

    // Create index array
    const indices = try allocator.alloc(usize, population.size);
    defer allocator.free(indices);
    for (0..population.size) |i| indices[i] = i;

    // Sort by fitness (descending)
    const fitness_slice = population.individuals;
    std.mem.sort(usize, indices, fitness_slice, struct {
        fn lessThan(ctx: []Individual, a: usize, b: usize) bool {
            return ctx[a].fitness > ctx[b].fitness;
        }
    }.lessThan);

    // Return top elite_count indices
    const result = try allocator.alloc(usize, elite_count);
    @memcpy(result, indices[0..elite_count]);

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVOLUTION LOOP
// ═══════════════════════════════════════════════════════════════════════════════

/// Run one generation of evolution
pub fn evolveGeneration(
    allocator: std.mem.Allocator,
    population: *Population,
    human_pattern: *const TritVec,
    config: *const EvolutionConfig,
    rng: *std.Random.DefaultPrng,
) !void {
    // Evaluate current population
    evaluatePopulation(population, human_pattern);

    // Get elite indices
    const elite_indices = try getEliteIndices(allocator, population, config.elitism_ratio);
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

    // Fill rest with offspring
    var offspring_idx = elite_indices.len;
    while (offspring_idx < population.size) : (offspring_idx += 1) {
        // Tournament selection
        const parent1_idx = tournamentSelect(population, config.tournament_size, rng);
        const parent2_idx = tournamentSelect(population, config.tournament_size, rng);

        // Crossover
        var child = try multiPointCrossover(
            allocator,
            &population.individuals[parent1_idx],
            &population.individuals[parent2_idx],
            config.crossover_rate,
            rng,
        );

        // Mutation - use guided mutation for high-dimensional spaces
        // Guide rate decreases as fitness increases (less guidance needed)
        const current_fitness = population.best_fitness;
        // Higher guide rate (20%) to reach target faster in high dimensions
        const guide_rate = 0.2 * (1.0 - current_fitness * 0.8); // 20% when fitness=0, 4% when fitness=1
        const noise_rate = config.mutation_rate;

        const mutated = try mutateGuided(allocator, &child, human_pattern, guide_rate, noise_rate, rng);
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

    // Update best
    evaluatePopulation(population, human_pattern);
}

/// Run full evolution until convergence or max generations
pub fn evolve(
    allocator: std.mem.Allocator,
    population: *Population,
    human_pattern: *const TritVec,
    config: *const EvolutionConfig,
    seed: u64,
) !EvolutionStats {
    var rng = std.Random.DefaultPrng.init(seed);

    // Initial evaluation
    evaluatePopulation(population, human_pattern);

    var converged = false;

    while (population.generation < config.max_generations) {
        // Check convergence
        if (population.best_fitness >= config.target_fitness) {
            converged = true;
            break;
        }

        // Evolve one generation
        try evolveGeneration(allocator, population, human_pattern, config, &rng);
    }

    // Final evaluation
    evaluatePopulation(population, human_pattern);

    const best = population.getBest();
    const final_similarity = cosineSimilarity(&best.chromosome, human_pattern);

    return EvolutionStats{
        .generations = population.generation,
        .best_fitness = population.best_fitness,
        .avg_fitness = population.getAverageFitness(),
        .converged = converged,
        .final_similarity = final_similarity,
    };
}

/// Evolve a single fingerprint to evade detection
pub fn evolveFingerprint(
    allocator: std.mem.Allocator,
    initial_fingerprint: *const TritVec,
    human_pattern: *const TritVec,
    config: *const EvolutionConfig,
    seed: u64,
) !struct { fingerprint: TritVec, stats: EvolutionStats } {
    // Initialize population with variations of initial fingerprint
    var population = try Population.init(allocator, config.population_size, initial_fingerprint.len, seed);
    errdefer population.deinit();

    // Replace first individual with initial fingerprint
    population.individuals[0].chromosome.deinit();
    population.individuals[0].chromosome = try initial_fingerprint.clone();

    // Run evolution
    const stats = try evolve(allocator, &population, human_pattern, config, seed);

    // Get best fingerprint
    const best = population.getBest();
    const result_fingerprint = try best.chromosome.clone();

    population.deinit();

    return .{
        .fingerprint = result_fingerprint,
        .stats = stats,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub const EvolutionBenchmark = struct {
    total_ns: u64,
    generations: u32,
    ns_per_generation: u64,
    final_fitness: f64,
};

/// Benchmark evolution performance
pub fn benchmarkEvolution(
    allocator: std.mem.Allocator,
    dim: usize,
    pop_size: usize,
    generations: usize,
    seed: u64,
) !EvolutionBenchmark {
    var human = try TritVec.random(allocator, dim, seed);
    defer human.deinit();

    var population = try Population.init(allocator, pop_size, dim, seed +% 1);
    defer population.deinit();

    const config = EvolutionConfig{
        .population_size = pop_size,
        .max_generations = generations,
        .tournament_size = 3,
        .target_fitness = 2.0, // Unreachable - run all generations
    };

    var timer = try std.time.Timer.start();

    var rng = std.Random.DefaultPrng.init(seed +% 2);
    evaluatePopulation(&population, &human);

    for (0..generations) |_| {
        try evolveGeneration(allocator, &population, &human, &config, &rng);
    }

    const total_ns = timer.read();

    return EvolutionBenchmark{
        .total_ns = total_ns,
        .generations = @intCast(generations),
        .ns_per_generation = total_ns / generations,
        .final_fitness = population.best_fitness,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "individual creation" {
    const allocator = std.testing.allocator;

    var ind = try Individual.init(allocator, 100, 12345);
    defer ind.deinit();

    try std.testing.expectEqual(@as(usize, 100), ind.chromosome.len);
    try std.testing.expectEqual(@as(f64, 0.0), ind.fitness);
}

test "population creation" {
    const allocator = std.testing.allocator;

    var pop = try Population.init(allocator, 10, 100, 12345);
    defer pop.deinit();

    try std.testing.expectEqual(@as(usize, 10), pop.size);
    try std.testing.expectEqual(@as(u32, 0), pop.generation);
}

test "fitness evaluation" {
    const allocator = std.testing.allocator;

    var ind = try Individual.init(allocator, 100, 11111);
    defer ind.deinit();

    var human = try TritVec.random(allocator, 100, 22222);
    defer human.deinit();

    const fitness = computeFitness(&ind, &human);

    // Fitness should be in [0, 1]
    try std.testing.expect(fitness >= 0.0);
    try std.testing.expect(fitness <= 1.0);
}

test "tournament selection" {
    const allocator = std.testing.allocator;

    var pop = try Population.init(allocator, 10, 100, 33333);
    defer pop.deinit();

    // Set varying fitness
    for (pop.individuals, 0..) |*ind, i| {
        ind.fitness = @as(f64, @floatFromInt(i)) / 10.0;
    }

    var rng = std.Random.DefaultPrng.init(44444);
    const selected = tournamentSelect(&pop, 3, &rng);

    try std.testing.expect(selected < pop.size);
}

test "multi-point crossover" {
    const allocator = std.testing.allocator;

    var parent1 = try Individual.init(allocator, 100, 55555);
    defer parent1.deinit();
    var parent2 = try Individual.init(allocator, 100, 66666);
    defer parent2.deinit();

    var rng = std.Random.DefaultPrng.init(77777);
    var child = try multiPointCrossover(allocator, &parent1, &parent2, 1.0, &rng);
    defer child.deinit();

    try std.testing.expectEqual(@as(usize, 100), child.chromosome.len);
}

test "adaptive mutation" {
    const allocator = std.testing.allocator;

    var ind = try Individual.init(allocator, 100, 88888);
    defer ind.deinit();
    ind.fitness = 0.5;

    const spiral = PhiSpiral.init(5);
    var rng = std.Random.DefaultPrng.init(99999);

    var mutated = try mutateAdaptive(allocator, &ind, 0.1, &spiral, &rng);
    defer mutated.deinit();

    // Should be different
    const distance = vsa.hammingDistance(&ind.chromosome, &mutated.chromosome);
    try std.testing.expect(distance > 0);
}

test "evolution improves fitness" {
    const allocator = std.testing.allocator;

    var pop = try Population.init(allocator, 20, 100, 11111);
    defer pop.deinit();

    var human = try TritVec.random(allocator, 100, 22222);
    defer human.deinit();

    // Initial evaluation
    evaluatePopulation(&pop, &human);
    const initial_best = pop.best_fitness;

    // Run a few generations
    const config = EvolutionConfig{
        .population_size = 20,
        .max_generations = 10,
        .tournament_size = 3,
    };

    var rng = std.Random.DefaultPrng.init(33333);
    for (0..5) |_| {
        try evolveGeneration(allocator, &pop, &human, &config, &rng);
    }

    // Fitness should improve or stay same (elitism)
    try std.testing.expect(pop.best_fitness >= initial_best - 0.1);
}

test "evolve fingerprint" {
    const allocator = std.testing.allocator;

    var initial = try TritVec.random(allocator, 100, 44444);
    defer initial.deinit();

    var human = try TritVec.random(allocator, 100, 55555);
    defer human.deinit();

    const config = EvolutionConfig{
        .population_size = 10,
        .max_generations = 5,
        .tournament_size = 2,
    };

    const result = try evolveFingerprint(allocator, &initial, &human, &config, 66666);
    defer @constCast(&result.fingerprint).deinit();

    try std.testing.expect(result.stats.generations <= 5);
    try std.testing.expect(result.stats.best_fitness >= 0.0);
}

test "adaptive mutation rate varies with fitness" {
    const spiral = PhiSpiral.init(0);

    const rate_low_fitness = adaptiveMutationRate(0.1, 0.2, &spiral);
    const rate_high_fitness = adaptiveMutationRate(0.1, 0.9, &spiral);

    // Higher fitness should have lower mutation rate
    try std.testing.expect(rate_high_fitness < rate_low_fitness);
}

test "benchmark evolution with SIMD" {
    const allocator = std.testing.allocator;

    // Small benchmark: 1000 dim, 20 pop, 10 generations
    const result = try benchmarkEvolution(allocator, 1000, 20, 10, 12345);

    std.debug.print("\nEvolution benchmark (DIM=1000, POP=20, GEN=10):\n", .{});
    std.debug.print("  Total: {d}ms\n", .{result.total_ns / 1_000_000});
    std.debug.print("  Per generation: {d}us\n", .{result.ns_per_generation / 1000});
    std.debug.print("  Final fitness: {d:.4}\n", .{result.final_fitness});

    try std.testing.expect(result.final_fitness > 0.0);
}

test "benchmark evolution large dimension" {
    const allocator = std.testing.allocator;

    // Larger benchmark: 10000 dim, 30 pop, 5 generations
    const result = try benchmarkEvolution(allocator, 10000, 30, 5, 67890);

    std.debug.print("\nEvolution benchmark (DIM=10000, POP=30, GEN=5):\n", .{});
    std.debug.print("  Total: {d}ms\n", .{result.total_ns / 1_000_000});
    std.debug.print("  Per generation: {d}ms\n", .{result.ns_per_generation / 1_000_000});
    std.debug.print("  Final fitness: {d:.4}\n", .{result.final_fitness});

    try std.testing.expect(result.final_fitness > 0.0);
}
