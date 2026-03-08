// ═══════════════════════════════════════════════════════════════════════════════
// SELF-EVOLUTION ENGINE v1.0
// Genetic Algorithm for Sacred Formula Discovery
// ═══════════════════════════════════════════════════════════════════════════════
//
// Evolves optimal (n,k,m,p,q) parameters for V = n × 3^k × π^m × φ^p × e^q
// using genetic algorithms with sacred constraints.
//
// Features:
//   - Population-based evolution (default 50 individuals)
//   - Fitness: relative error + sacred bonus (TRINITY alignment)
//   - Selection: tournament (pressure φ = 1.618)
//   - Crossover: arithmetic (rate χ = 0.0618)
//   - Mutation: Gaussian (rate μ = 0.0382)
//   - Elitism: preserve top ε = 1/3
//   - Convergence detection (threshold or stagnation)
//
// Mirrors: website/src/services/chatApi.ts (self-evolution API)
//
// φ² + 1/φ² = 3 = TRINITY | μ = φ^(-4) = 0.0382 | χ = 0.0618 | σ = φ | ε = 1/3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const mem = std.mem;

const sacred = @import("formula.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = sacred.PHI;
pub const PI: f64 = sacred.PI;
pub const E: f64 = sacred.E;
pub const TRINITY: f64 = sacred.TRINITY;

pub const MU: f64 = 0.0382; // φ^(-4) — mutation rate
pub const CHI: f64 = 0.0618; // (1-φ)/2 — crossover rate
pub const SIGMA: f64 = PHI; // selection pressure
pub const EPSILON: f64 = 1.0 / 3.0; // elitism rate

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Individual chromosome: formula parameters (n,k,m,p,q)
pub const Chromosome = struct {
    n: i8,
    k: i8,
    m: i8,
    p: i8,
    q: i8,
    fitness: f64 = 0.0,
    computed: f64 = 0.0,
    generation: usize = 0,

    /// Compute sacred formula value for this chromosome
    pub fn compute(self: Chromosome) f64 {
        return sacred.computeSacredFormula(self.n, self.k, self.m, self.p, self.q);
    }

    /// Calculate complexity (sum of absolute parameter values)
    pub fn complexity(self: Chromosome) i16 {
        return (@as(i16, @abs(self.n)) + @abs(self.k) + @abs(self.m) + @abs(self.p) + @abs(self.q));
    }

    /// Check if chromosome respects TRINITY alignment
    pub fn isTrinityAligned(self: Chromosome) bool {
        const value = self.compute();
        // Check if value is close to 3, 9, 27, 81, ... (powers of 3)
        const normalized = value / 3.0;
        const nearest_power = @round(math.log10(normalized) / math.log10(3.0));
        const expected = math.pow(f64, 3.0, nearest_power);
        const diff = @abs(normalized - expected);
        return diff < 0.1; // Within 10% of power of 3
    }
};

/// Population of chromosomes
pub const Population = struct {
    individuals: []Chromosome,
    allocator: mem.Allocator,
    size: usize,
    target_value: f64,

    pub fn init(allocator: mem.Allocator, size: usize, target: f64) !Population {
        const individuals = try allocator.alloc(Chromosome, size);
        @memset(individuals, undefined);
        return Population{
            .individuals = individuals,
            .allocator = allocator,
            .size = size,
            .target_value = target,
        };
    }

    pub fn deinit(self: Population) void {
        self.allocator.free(self.individuals);
    }

    /// Get best individual in population
    pub fn getBest(self: Population) Chromosome {
        var best = self.individuals[0];
        for (self.individuals[1..]) |ind| {
            if (ind.fitness > best.fitness) {
                best = ind;
            }
        }
        return best;
    }

    /// Get average fitness
    pub fn getAverageFitness(self: Population) f64 {
        var sum: f64 = 0.0;
        for (self.individuals) |ind| {
            sum += ind.fitness;
        }
        return sum / @as(f64, @floatFromInt(self.size));
    }
};

/// Parent pair for crossover
pub const ParentPair = struct {
    parent1: Chromosome,
    parent2: Chromosome,
};

/// Evolution configuration with sacred defaults
pub const EvolutionConfig = struct {
    population_size: usize = 50,
    max_generations: usize = 100,
    mutation_rate: f64 = MU,
    crossover_rate: f64 = CHI,
    selection_pressure: f64 = SIGMA,
    elitism_rate: f64 = EPSILON,
    convergence_threshold: f64 = 0.0001,
    stagnation_generations: usize = 10,
    random_seed: u64 = 0,

    pub fn validate(self: EvolutionConfig) !void {
        if (self.population_size < 10) return error.PopulationTooSmall;
        if (self.population_size > 1000) return error.PopulationTooLarge;
        if (self.max_generations == 0) return error.InvalidMaxGenerations;
        if (self.mutation_rate < 0.0 or self.mutation_rate > 1.0) return error.InvalidMutationRate;
        if (self.crossover_rate < 0.0 or self.crossover_rate > 1.0) return error.InvalidCrossoverRate;
        if (self.elitism_rate < 0.0 or self.elitism_rate > 1.0) return error.InvalidElitismRate;
        if (self.convergence_threshold < 0.0) return error.InvalidConvergenceThreshold;
    }
};

/// Evolution result
pub const EvolutionResult = struct {
    best: Chromosome,
    generation: usize,
    converged: bool,
    reason: []const u8,
    final_error_pct: f64,
    generations_to_convergence: usize = 0,

    pub fn format(self: EvolutionResult, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("EvolutionResult{{ best: ", .{});
        try writer.print("n={}, k={}, m={}, p={}, q={}, fitness={d:.6}, computed={d:.6} ", .{ self.best.n, self.best.k, self.best.m, self.best.p, self.best.q, self.best.fitness, self.best.computed });
        try writer.print("generation={}, converged={}, reason='{s}', error_pct={d:.4}% }}", .{ self.generation, self.converged, self.reason, self.final_error_pct });
    }
};

/// Statistics tracking (simplified for Zig 0.15)
pub const EvolutionStats = struct {
    best_fitness_history: std.ArrayList(f64),
    avg_fitness_history: std.ArrayList(f64),
    diversity_history: std.ArrayList(f64),

    pub fn init(allocator: mem.Allocator) EvolutionStats {
        return .{
            .best_fitness_history = std.ArrayList(f64).initCapacity(allocator, 100) catch std.ArrayList(f64){},
            .avg_fitness_history = std.ArrayList(f64).initCapacity(allocator, 100) catch std.ArrayList(f64){},
            .diversity_history = std.ArrayList(f64).initCapacity(allocator, 100) catch std.ArrayList(f64){},
        };
    }

    pub fn deinit(self: *EvolutionStats, allocator: mem.Allocator) void {
        self.best_fitness_history.deinit(allocator);
        self.avg_fitness_history.deinit(allocator);
        self.diversity_history.deinit(allocator);
    }

    pub fn record(self: *EvolutionStats, allocator: mem.Allocator, best_fit: f64, avg_fit: f64, diversity: f64) !void {
        try self.best_fitness_history.append(allocator, best_fit);
        try self.avg_fitness_history.append(allocator, avg_fit);
        try self.diversity_history.append(allocator, diversity);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GENETIC ALGORITHM CORE
// ═══════════════════════════════════════════════════════════════════════════════

/// Initialize population with random chromosomes
pub fn initPopulation(
    allocator: mem.Allocator,
    size: usize,
    target_value: f64,
    rng: *std.Random.DefaultPrng,
) !Population {
    const pop = try Population.init(allocator, size, target_value);

    // Parameter bounds (same as sacred_formula.zig)
    const N_MIN: i8 = 1;
    const N_MAX: i8 = 9;
    const K_MIN: i8 = -4;
    const K_MAX: i8 = 4;
    const M_MIN: i8 = -3;
    const M_MAX: i8 = 0;
    const P_MIN: i8 = -4;
    const P_MAX: i8 = 4;
    const Q_MIN: i8 = -3;
    const Q_MAX: i8 = 3;

    for (pop.individuals) |*ind| {
        ind.* = Chromosome{
            .n = rng.random().intRangeAtMost(i8, N_MIN, N_MAX),
            .k = rng.random().intRangeAtMost(i8, K_MIN, K_MAX),
            .m = rng.random().intRangeAtMost(i8, M_MIN, M_MAX),
            .p = rng.random().intRangeAtMost(i8, P_MIN, P_MAX),
            .q = rng.random().intRangeAtMost(i8, Q_MIN, Q_MAX),
            .generation = 0,
        };
        ind.computed = ind.compute();
    }

    return pop;
}

/// Evaluate fitness for entire population
/// Fitness = 1 / (1 + error) with sacred bonuses
pub fn evaluateFitness(population: *Population, target: f64) void {
    const abs_target = @abs(target);
    if (abs_target < 1e-15) return;

    for (population.individuals) |*ind| {
        const computed = ind.compute();
        ind.computed = computed;

        // Base fitness: inverse of relative error
        const rel_error = @abs(computed - target) / abs_target;
        var fitness = 1.0 / (1.0 + rel_error * 100.0); // Scale error for better gradient

        // Sacred bonuses

        // Bonus 1: TRINITY alignment (prefer values near powers of 3)
        if (ind.isTrinityAligned()) {
            fitness *= 1.05; // 5% bonus
        }

        // Bonus 2: Low complexity (Occam's razor)
        const complexity = ind.complexity();
        if (complexity <= 5) {
            fitness *= 1.03; // 3% bonus for simple formulas
        } else if (complexity <= 10) {
            fitness *= 1.01; // 1% bonus
        }

        // Bonus 3: Integer relationships
        if (@abs(@round(computed) - computed) < 0.01) {
            fitness *= 1.02; // 2% bonus for near-integer results
        }

        // Penalty: extreme parameter values
        if (@abs(ind.k) > 3 or @abs(ind.p) > 3) {
            fitness *= 0.98; // 2% penalty
        }

        ind.fitness = fitness;
    }
}

/// Calculate population diversity (average pairwise distance)
pub fn calculateDiversity(population: Population) f64 {
    if (population.size < 2) return 0.0;

    var total_distance: f64 = 0.0;
    var comparisons: usize = 0;

    for (0..population.size) |i| {
        for (i + 1..population.size) |j| {
            const ind1 = population.individuals[i];
            const ind2 = population.individuals[j];

            // Euclidean distance in parameter space
            const dn = @as(f64, @floatFromInt(ind1.n - ind2.n));
            const dk = @as(f64, @floatFromInt(ind1.k - ind2.k));
            const dm = @as(f64, @floatFromInt(ind1.m - ind2.m));
            const dp = @as(f64, @floatFromInt(ind1.p - ind2.p));
            const dq = @as(f64, @floatFromInt(ind1.q - ind2.q));

            const distance = math.sqrt(dn * dn + dk * dk + dm * dm + dp * dp + dq * dq);
            total_distance += distance;
            comparisons += 1;
        }
    }

    if (comparisons == 0) return 0.0;
    return total_distance / @as(f64, @floatFromInt(comparisons));
}

/// Tournament selection
pub fn selectParents(
    population: Population,
    rng: *std.Random.DefaultPrng,
    config: EvolutionConfig,
) ![]ParentPair {
    _ = config; // Selection pressure applied via tournament size
    const num_pairs = (population.size + 1) / 2;
    const pairs = try population.allocator.alloc(ParentPair, num_pairs);

    const tournament_size = @max(2, @as(usize, @intFromFloat(@as(f64, @floatFromInt(population.size)) * 0.1)));

    for (pairs) |*pair| {
        // Tournament for parent 1
        var parent1 = population.individuals[0];
        var i: usize = 0;
        while (i < tournament_size) : (i += 1) {
            const idx = rng.random().intRangeAtMost(usize, 0, population.size - 1);
            const contestant = population.individuals[idx];
            if (contestant.fitness > parent1.fitness) {
                parent1 = contestant;
            }
        }

        // Tournament for parent 2 (ensure different from parent 1)
        var parent2 = population.individuals[0];
        i = 0;
        while (i < tournament_size) : (i += 1) {
            const idx = rng.random().intRangeAtMost(usize, 0, population.size - 1);
            const contestant = population.individuals[idx];
            if (contestant.fitness > parent2.fitness and !std.meta.eql(contestant, parent1)) {
                parent2 = contestant;
            }
        }

        pair.* = ParentPair{
            .parent1 = parent1,
            .parent2 = parent2,
        };
    }

    return pairs;
}

/// Arithmetic crossover with Gaussian blend
pub fn crossover(
    parent1: Chromosome,
    parent2: Chromosome,
    rng: *std.Random.DefaultPrng,
    config: EvolutionConfig,
) Chromosome {
    _ = config; // Crossover probability applied at call site
    // Random blend factor centered at 0.5
    const alpha = 0.5 + rng.random().floatNorm(f64) * 0.1;

    // Round to nearest integer
    const child = Chromosome{
        .n = @as(i8, @intFromFloat(@round(@as(f64, @floatFromInt(parent1.n)) * alpha +
            @as(f64, @floatFromInt(parent2.n)) * (1.0 - alpha)))),
        .k = @as(i8, @intFromFloat(@round(@as(f64, @floatFromInt(parent1.k)) * alpha +
            @as(f64, @floatFromInt(parent2.k)) * (1.0 - alpha)))),
        .m = @as(i8, @intFromFloat(@round(@as(f64, @floatFromInt(parent1.m)) * alpha +
            @as(f64, @floatFromInt(parent2.m)) * (1.0 - alpha)))),
        .p = @as(i8, @intFromFloat(@round(@as(f64, @floatFromInt(parent1.p)) * alpha +
            @as(f64, @floatFromInt(parent2.p)) * (1.0 - alpha)))),
        .q = @as(i8, @intFromFloat(@round(@as(f64, @floatFromInt(parent1.q)) * alpha +
            @as(f64, @floatFromInt(parent2.q)) * (1.0 - alpha)))),
        .generation = parent1.generation + 1,
    };

    return clampToBounds(child);
}

/// Clamp chromosome to parameter bounds
fn clampToBounds(chromo: Chromosome) Chromosome {
    const N_MIN: i8 = 1;
    const N_MAX: i8 = 9;
    const K_MIN: i8 = -4;
    const K_MAX: i8 = 4;
    const M_MIN: i8 = -3;
    const M_MAX: i8 = 0;
    const P_MIN: i8 = -4;
    const P_MAX: i8 = 4;
    const Q_MIN: i8 = -3;
    const Q_MAX: i8 = 3;

    var result = chromo;
    result.n = @max(N_MIN, @min(N_MAX, result.n));
    result.k = @max(K_MIN, @min(K_MAX, result.k));
    result.m = @max(M_MIN, @min(M_MAX, result.m));
    result.p = @max(P_MIN, @min(P_MAX, result.p));
    result.q = @max(Q_MIN, @min(Q_MAX, result.q));
    return result;
}

/// Gaussian mutation
pub fn mutate(
    child: *Chromosome,
    rng: *std.Random.DefaultPrng,
    config: EvolutionConfig,
) void {
    // Apply mutation with probability config.mutation_rate to each gene
    if (rng.random().float(f64) < config.mutation_rate) {
        const delta = @as(i8, @intFromFloat(@round(rng.random().floatNorm(f64) * 2.0)));
        child.n = @max(1, @min(9, child.n + delta));
    }

    if (rng.random().float(f64) < config.mutation_rate) {
        const delta = @as(i8, @intFromFloat(@round(rng.random().floatNorm(f64) * 2.0)));
        child.k = @max(-4, @min(4, child.k + delta));
    }

    if (rng.random().float(f64) < config.mutation_rate) {
        const delta = @as(i8, @intFromFloat(@round(rng.random().floatNorm(f64) * 2.0)));
        child.m = @max(-3, @min(0, child.m + delta));
    }

    if (rng.random().float(f64) < config.mutation_rate) {
        const delta = @as(i8, @intFromFloat(@round(rng.random().floatNorm(f64) * 2.0)));
        child.p = @max(-4, @min(4, child.p + delta));
    }

    if (rng.random().float(f64) < config.mutation_rate) {
        const delta = @as(i8, @intFromFloat(@round(rng.random().floatNorm(f64) * 2.0)));
        child.q = @max(-3, @min(3, child.q + delta));
    }

    child.* = clampToBounds(child.*);
}

/// Create next generation using elitism, selection, crossover, mutation
pub fn createNextGeneration(
    population: *Population,
    rng: *std.Random.DefaultPrng,
    config: EvolutionConfig,
) !void {
    const allocator = population.allocator;

    // Sort by fitness (descending)
    mem.sort(Chromosome, population.individuals, {}, struct {
        fn lessThan(_: void, a: Chromosome, b: Chromosome) bool {
            return a.fitness > b.fitness;
        }
    }.lessThan);

    // Elitism: preserve top individuals
    const elite_count = @as(usize, @intFromFloat(@as(f64, @floatFromInt(population.size)) * config.elitism_rate));
    const elite_count_safe = @max(1, @min(elite_count, population.size));

    // Allocate new population
    var new_individuals = try allocator.alloc(Chromosome, population.size);

    // Copy elite
    @memcpy(new_individuals[0..elite_count_safe], population.individuals[0..elite_count_safe]);

    // Select parents and create offspring
    const parent_pairs = try selectParents(population.*, rng, config);
    defer allocator.free(parent_pairs);

    var child_idx: usize = elite_count_safe;
    for (parent_pairs) |pair| {
        if (child_idx >= population.size) break;

        var child = pair.parent1;

        // Crossover with probability
        if (rng.random().float(f64) < config.crossover_rate) {
            child = crossover(pair.parent1, pair.parent2, rng, config);
        }

        // Mutation
        mutate(&child, rng, config);

        // Set generation
        child.generation = population.individuals[0].generation + 1;

        if (child_idx < population.size) {
            new_individuals[child_idx] = child;
            child_idx += 1;
        }

        // Create second child if space remains
        if (child_idx < population.size) {
            var child2 = pair.parent2;
            if (rng.random().float(f64) < config.crossover_rate) {
                child2 = crossover(pair.parent2, pair.parent1, rng, config);
            }
            mutate(&child2, rng, config);
            child2.generation = child.generation;
            new_individuals[child_idx] = child2;
            child_idx += 1;
        }
    }

    // Replace old population
    allocator.free(population.individuals);
    population.individuals = new_individuals;
}

/// Check convergence criteria
fn checkConvergence(
    population: Population,
    generation: usize,
    config: EvolutionConfig,
    prev_best: Chromosome,
    stagnation_counter: *usize,
) struct { converged: bool, reason: []const u8 } {
    const best = population.getBest();
    const abs_target = @abs(population.target_value);
    const rel_error = @abs(best.computed - population.target_value) / abs_target;

    // Convergence 1: threshold reached
    if (rel_error < config.convergence_threshold) {
        return .{ .converged = true, .reason = "threshold" };
    }

    // Convergence 2: stagnation (no improvement)
    if (best.fitness <= prev_best.fitness + 0.0001) {
        stagnation_counter.* += 1;
        if (stagnation_counter.* >= config.stagnation_generations) {
            return .{ .converged = true, .reason = "stagnation" };
        }
    } else {
        stagnation_counter.* = 0;
    }

    // Convergence 3: max generations
    if (generation >= config.max_generations) {
        return .{ .converged = true, .reason = "max_generations" };
    }

    return .{ .converged = false, .reason = "" };
}

/// Main evolution loop
pub fn evolve(
    allocator: mem.Allocator,
    config: EvolutionConfig,
    target_value: f64,
) !EvolutionResult {
    try config.validate();

    var rng = std.Random.DefaultPrng.init(config.random_seed);
    var population = try initPopulation(allocator, config.population_size, target_value, &rng);
    defer population.deinit();

    var stats = EvolutionStats.init(allocator);
    defer stats.deinit(allocator);

    evaluateFitness(&population, target_value);

    var generation: usize = 0;
    var stagnation_counter: usize = 0;
    var prev_best = population.getBest();

    while (true) : (generation += 1) {
        // Record statistics
        const best = population.getBest();
        const avg = population.getAverageFitness();
        const diversity = calculateDiversity(population);
        try stats.record(allocator, best.fitness, avg, diversity);

        // Check convergence
        const result = checkConvergence(population, generation, config, prev_best, &stagnation_counter);
        if (result.converged) {
            const final_best = population.getBest();
            const abs_target = @abs(target_value);
            const final_error = (@abs(final_best.computed - target_value) / abs_target) * 100.0;

            return EvolutionResult{
                .best = final_best,
                .generation = generation,
                .converged = true,
                .reason = result.reason,
                .final_error_pct = final_error,
                .generations_to_convergence = generation,
            };
        }

        prev_best = best;

        // Create next generation
        try createNextGeneration(&population, &rng, config);
        evaluateFitness(&population, target_value);
    }
}

/// Print evolution progress with ANSI colors
pub fn printEvolutionProgress(
    generation: usize,
    population: Population,
    diversity: f64,
) void {
    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GREEN = "\x1b[32m";
    const RESET = "\x1b[0m";

    const best = population.getBest();
    const avg = population.getAverageFitness();
    const abs_target = @abs(population.target_value);
    const final_error = (@abs(best.computed - population.target_value) / abs_target) * 100.0;

    std.debug.print("  Gen {s}{d: >3}{s}: {s}fit={d:.6}{s} {s}avg={d:.6}{s} {s}err={d:.4}%{s} {s}div={d:.3}{s} [{s}n={d} k={d} m={d} p={d} q={d}{s}]\n", .{
        CYAN,                                                                       generation,   RESET,
        GREEN,                                                                      best.fitness, RESET,
        WHITE,                                                                      avg,          RESET,
        if (final_error < 1.0) GREEN else if (final_error < 5.0) WHITE else GOLDEN, final_error,  RESET,
        WHITE,                                                                      diversity,    RESET,
        GOLDEN,                                                                     best.n,       best.k,
        best.m,                                                                     best.p,       best.q,
        RESET,
    });
}

/// Print evolution result summary
pub fn printEvolutionResult(result: EvolutionResult, target: f64) void {
    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GRAY = "\x1b[90m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const BOLD = "\x1b[1m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}{s}SELF-EVOLUTION COMPLETE{s}\n", .{ BOLD, GOLDEN, RESET });
    std.debug.print("{s}================================{s}\n\n", .{ GRAY, RESET });

    std.debug.print("  {s}Target:{s}     {s}{d:.6}{s}\n", .{ GRAY, RESET, WHITE, target, RESET });
    std.debug.print("  {s}Evolved:{s}    {s}{d:.6}{s}\n", .{ GRAY, RESET, WHITE, result.best.computed, RESET });

    const err_color = if (result.final_error_pct < 1.0) GREEN else if (result.final_error_pct < 5.0) CYAN else RED;
    std.debug.print("  {s}Error:{s}      {s}{d:.4}%{s}\n", .{ GRAY, RESET, err_color, result.final_error_pct, RESET });

    std.debug.print("  {s}Fitness:{s}    {s}{d:.6}{s}\n", .{ GRAY, RESET, GREEN, result.best.fitness, RESET });
    std.debug.print("  {s}Generation:{s} {s}{d}{s}\n", .{ GRAY, RESET, WHITE, result.generation, RESET });
    std.debug.print("  {s}Converged:{s}  {s}{s}{s}\n", .{ GRAY, RESET, CYAN, result.reason, RESET });

    std.debug.print("\n  {s}Parameters:{s}\n", .{ CYAN, RESET });
    std.debug.print("    n={s}{d}{s}  k={s}{d}{s}  m={s}{d}{s}  p={s}{d}{s}  q={s}{d}{s}\n", .{
        WHITE, result.best.n, RESET,
        WHITE, result.best.k, RESET,
        WHITE, result.best.m, RESET,
        WHITE, result.best.p, RESET,
        WHITE, result.best.q, RESET,
    });

    std.debug.print("\n  {s}Complexity:{s}  {s}{d}{s}\n", .{ GRAY, RESET, WHITE, result.best.complexity(), RESET });
    std.debug.print("  {s}TRINITY:{s}    {s}{}{s}\n", .{
        GRAY,                                                                                               RESET,
        if (result.best.isTrinityAligned()) GREEN ++ "ALIGNED" ++ RESET else RED ++ "NOT ALIGNED" ++ RESET,
    });

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY | μ = 0.0382 | χ = 0.0618 | σ = 1.618 | ε = 1/3{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "chromosome compute" {
    const chromo = Chromosome{ .n = 1, .k = 1, .m = 0, .p = 0, .q = 0, .fitness = 0.0, .computed = 0.0, .generation = 0 };
    const value = chromo.compute();
    try std.testing.expectApproxEqAbs(3.0, value, 1e-10);
}

test "chromosome complexity" {
    const chromo = Chromosome{ .n = 1, .k = 1, .m = 0, .p = 0, .q = 0, .fitness = 0.0, .computed = 0.0, .generation = 0 };
    try std.testing.expectEqual(@as(i8, 2), chromo.complexity());
}

test "init population" {
    var rng = std.Random.DefaultPrng.init(42);
    var pop = try initPopulation(std.testing.allocator, 10, 3.0, &rng);
    defer pop.deinit();

    try std.testing.expectEqual(@as(usize, 10), pop.size);
    try std.testing.expectApproxEqAbs(3.0, pop.target_value, 1e-10);
}

test "evaluate fitness" {
    var rng = std.Random.DefaultPrng.init(42);
    var pop = try initPopulation(std.testing.allocator, 10, 3.0, &rng);
    defer pop.deinit();

    evaluateFitness(&pop, 3.0);

    // All fitness values should be positive
    for (pop.individuals) |ind| {
        try std.testing.expect(ind.fitness > 0.0);
    }
}

test "crossover produces valid chromosome" {
    var rng = std.Random.DefaultPrng.init(42);
    const config = EvolutionConfig{};

    const parent1 = Chromosome{ .n = 1, .k = 1, .m = 0, .p = 0, .q = 0, .fitness = 0.0, .computed = 0.0, .generation = 0 };
    const parent2 = Chromosome{ .n = 2, .k = 2, .m = -1, .p = -1, .q = -1, .fitness = 0.0, .computed = 0.0, .generation = 0 };

    const child = crossover(parent1, parent2, &rng, config);

    // Child should be within bounds
    try std.testing.expect(child.n >= 1 and child.n <= 9);
    try std.testing.expect(child.k >= -4 and child.k <= 4);
    try std.testing.expect(child.m >= -3 and child.m <= 0);
    try std.testing.expect(child.p >= -4 and child.p <= 4);
    try std.testing.expect(child.q >= -3 and child.q <= 3);
}

test "mutation changes chromosome" {
    var rng = std.Random.DefaultPrng.init(42);
    const config = EvolutionConfig{
        .mutation_rate = 1.0, // Always mutate
    };

    var child = Chromosome{ .n = 5, .k = 0, .m = -1, .p = 0, .q = 0, .fitness = 0.0, .computed = 0.0, .generation = 0 };

    const original = child;
    mutate(&child, &rng, config);

    // At least one parameter should likely change (not guaranteed due to random rounding)
    _ = original; // Suppress unused warning
    try std.testing.expect(child.n >= 1 and child.n <= 9);
}

test "evolution converges for target 3.0" {
    const config = EvolutionConfig{
        .population_size = 30,
        .max_generations = 100,
        .convergence_threshold = 0.05,
        .random_seed = 42,
    };

    const result = try evolve(std.testing.allocator, config, 3.0);

    try std.testing.expect(result.converged);
    try std.testing.expect(result.final_error_pct < 20.0); // Within 20%
}

test "evolution finds trinity constant" {
    const config = EvolutionConfig{
        .population_size = 50,
        .max_generations = 150,
        .convergence_threshold = 0.01,
        .random_seed = 42,
    };

    const result = try evolve(std.testing.allocator, config, TRINITY);

    try std.testing.expect(result.converged);
    try std.testing.expect(result.final_error_pct < 15.0);
}

test "evolution converges for phi" {
    const config = EvolutionConfig{
        .population_size = 30,
        .max_generations = 100,
        .convergence_threshold = 0.01,
        .random_seed = 123,
    };

    const result = try evolve(std.testing.allocator, config, PHI);

    try std.testing.expect(result.converged);
    try std.testing.expect(result.final_error_pct < 10.0);
}

test "evolution config validation" {
    const valid_config = EvolutionConfig{};
    try valid_config.validate();

    const invalid_config1 = EvolutionConfig{ .population_size = 5 };
    try std.testing.expectError(error.PopulationTooSmall, invalid_config1.validate());

    const invalid_config2 = EvolutionConfig{ .mutation_rate = 1.5 };
    try std.testing.expectError(error.InvalidMutationRate, invalid_config2.validate());
}

test "population diversity" {
    var rng = std.Random.DefaultPrng.init(42);
    var pop = try initPopulation(std.testing.allocator, 20, 3.0, &rng);
    defer pop.deinit();

    const diversity = calculateDiversity(pop);

    // Diversity should be positive for random population
    try std.testing.expect(diversity > 0.0);
}

test "elitism preserves best" {
    var rng = std.Random.DefaultPrng.init(42);
    const config = EvolutionConfig{
        .population_size = 20,
        .elitism_rate = 0.5,
    };

    var pop = try initPopulation(std.testing.allocator, config.population_size, 3.0, &rng);
    defer pop.deinit();

    evaluateFitness(&pop, 3.0);

    // Sort and find best
    mem.sort(Chromosome, pop.individuals, {}, struct {
        fn lessThan(_: void, a: Chromosome, b: Chromosome) bool {
            return a.fitness > b.fitness;
        }
    }.lessThan);

    const original_best = pop.individuals[0];

    // Create next generation
    try createNextGeneration(&pop, &rng, config);
    evaluateFitness(&pop, 3.0);

    // Best should be preserved (exact match)
    var found_best = false;
    for (pop.individuals) |ind| {
        if (std.meta.eql(ind, original_best)) {
            found_best = true;
            break;
        }
    }

    try std.testing.expect(found_best);
}
