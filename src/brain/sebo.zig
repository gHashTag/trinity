//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! SEBO — Sacred Evolutionary Bayesian Optimization (Simplified)
//!
//! Multi-objective hyperparameter optimization using Sacred constants as
//! Bayesian priors for brain evolution search.
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

const Allocator = std.mem.Allocator;

// Sacred constants as Bayesian priors
pub const SACRED_PRIORS = struct {
    pub const PHI: f32 = 1.618033988749895; // Golden ratio
    pub const E: f32 = 2.718281828459045; // Euler's number
    pub const PI: f32 = 3.141592653589793; // Pi
    pub const PHI_INVERSE: f32 = 0.61803398874989; // 1/φ
};

/// Multi-objective evaluation metrics
pub const Objectives = struct {
    ppl: f32 = std.math.inf(f32), // Lower is better
    diversity: f32 = 0.0, // Higher is better
    fpga_cost: f32 = std.math.inf(f32), // Lower is better

    pub fn weightedFitness(self: Objectives) f32 {
        // Bayesian posterior: P(θ|D) ∝ P(D|θ) × P(θ)
        const ppl_term = self.ppl / SACRED_PRIORS.PHI;
        const diversity_term = (1.0 - self.diversity) / SACRED_PRIORS.E;
        const fpga_term = self.fpga_cost / SACRED_PRIORS.PI;
        return ppl_term + diversity_term + fpga_term;
    }

    pub fn dominates(self: *const Objectives, other: *const Objectives) bool {
        return (self.ppl <= other.ppl and
            self.diversity >= other.diversity and
            self.fpga_cost <= other.fpga_cost) and
            (self.ppl < other.ppl or
                self.diversity > other.diversity or
                self.fpga_cost < other.fpga_cost);
    }
};

/// Hyperparameter configuration
pub const HyperparameterConfig = struct {
    workers: u32 = 100,
    steps: u32 = 100,
    crash_rate: f32 = 0.0,
    byzantine_rate: f32 = 0.0,
    ntp_weight: f32 = 0.5,
    jepa_weight: f32 = 0.25,
    nca_weight: f32 = 0.25,
    kill_threshold: f32 = 0.3,
};

/// Search result
pub const SearchResult = struct {
    config: HyperparameterConfig,
    objectives: Objectives,
    fitness: f32,

    pub fn init(alloc: Allocator) !SearchResult {
        _ = alloc;
        return SearchResult{
            .config = .{},
            .objectives = .{},
            .fitness = 0.0,
        };
    }
};

/// SEBO Search Configuration
pub const SeboConfig = struct {
    population_size: u32 = 20,
    generations: u32 = 50,
    steps: u32 = 100,
    use_simulation: bool = false,
    mutation_rate: f32 = 0.1,
    crossover_rate: f32 = 0.7,
    elitism: u32 = 2,
};

/// SEBO Optimizer (simplified for Zig 0.15)
pub const SeboOptimizer = struct {
    alloc: Allocator,
    config: SeboConfig,
    prng: std.Random.DefaultPrng,
    population: std.ArrayList(SearchResult),
    steps: u32,
    use_simulation: bool,

    pub fn init(alloc: Allocator, config: SeboConfig) !SeboOptimizer {
        const prng = std.Random.DefaultPrng.init(std.crypto.random.int(u64));
        var sebo = SeboOptimizer{
            .alloc = alloc,
            .config = config,
            .prng = prng,
            .population = undefined,
            .steps = config.steps,
            .use_simulation = config.use_simulation,
        };
        sebo.population = std.ArrayList(SearchResult).initCapacity(alloc, 0) catch |err| return err;
        return sebo;
    }

    pub fn deinit(self: *SeboOptimizer) void {
        self.population.deinit(self.alloc);
    }

    /// Run full optimization
    pub fn run(self: *SeboOptimizer) !void {
        // Initialize random population
        try self.initializePopulation();

        for (0..self.config.generations) |gen| {
            const fitness = self.getBestFitness();
            std.debug.print("SEBO Generation {d}: Best fitness={d:.4}\n", .{ gen + 1, fitness });
            try self.evolve();
        }

        std.debug.print("\nSEBO Complete!\n", .{});
        const best = self.getBest();
        std.debug.print("Best Objectives: PPL={d:.2}, Diversity={d:.3}, FPGA={d:.3}\n", .{
            best.objectives.ppl,
            best.objectives.diversity,
            best.objectives.fpga_cost,
        });
    }

    /// Initialize population with Sacred priors
    fn initializePopulation(self: *SeboOptimizer) !void {
        for (0..self.config.population_size) |_| {
            var result = try SearchResult.init(self.alloc);

            // Apply Sacred priors
            result.config.ntp_weight = self.sampleWithPrior(0.0, 1.0);
            result.config.jepa_weight = self.sampleWithPrior(0.0, 1.0);
            result.config.nca_weight = self.sampleWithPrior(0.0, 1.0);
            result.config.workers = @as(u32, @intFromFloat(self.sampleWithPrior(50.0, 200.0)));
            result.config.kill_threshold = self.sampleWithPrior(0.1, 0.5);
            result.config.steps = self.steps;

            // Evaluate
            if (self.use_simulation) {
                const seed = self.prng.random().int(u64);
                result.objectives = try evaluateWithSimulation(self.alloc, result.config, seed);
            } else {
                result.objectives = try self.evaluate(&result.config);
            }
            result.fitness = result.objectives.weightedFitness();

            try self.population.append(self.alloc, result);
        }
    }

    /// Sample parameter with Sacred prior bias
    fn sampleWithPrior(self: *SeboOptimizer, min: f32, max: f32) f32 {
        const phi_bias = SACRED_PRIORS.PHI_INVERSE * 0.5; // Reduced bias
        const random = self.prng.random().float(f32);
        const value = min + (max - min) * random;
        // Apply φ-based bias towards golden mean (capped at max)
        const biased = @min(max, value * SACRED_PRIORS.PHI + (1.0 - SACRED_PRIORS.PHI) * (1.0 - phi_bias));
        return biased;
    }

    /// Evaluate configuration (synthetic - integrate with evolution_simulation.zig)
    fn evaluate(self: *const SeboOptimizer, config: *const HyperparameterConfig) !Objectives {
        _ = self;
        // TODO: Integrate with evolution_simulation.zig
        // For now, synthetic objectives

        var obj = Objectives{};

        // Synthetic PPL: improves with balanced objectives
        obj.ppl = 15.0 * (1.0 - config.ntp_weight - config.jepa_weight) + 5.0;

        // Synthetic diversity: peaks at balanced weights
        obj.diversity = 0.8 * (1.0 - @abs(config.ntp_weight - 0.5) - @abs(config.jepa_weight - 0.25));

        // Synthetic FPGA cost: scales with workers
        obj.fpga_cost = @as(f32, @floatFromInt(config.workers)) / 200.0;

        return obj;
    }

    /// Evaluate configuration with real evolution simulation
    /// This function runs a full simulation and returns actual objectives
    pub fn evaluateWithSimulation(
        alloc: Allocator,
        config: HyperparameterConfig,
        seed: u64,
    ) !Objectives {
        // Import evolution simulation module directly
        const evo_sim = @import("evolution_simulation");

        // Build objectives array from config
        const objectives = [_]evo_sim.EvolutionSimulationConfig.ObjectiveConfig{
            .{ .name = "ntp", .weight = config.ntp_weight },
            .{ .name = "jepa", .weight = config.jepa_weight },
            .{ .name = "nca", .weight = config.nca_weight },
        };

        // Create evolution config
        const evo_config = evo_sim.EvolutionSimulationConfig{
            .workers = config.workers,
            .steps = config.steps,
            .crash_rate = config.crash_rate,
            .byzantine_rate = config.byzantine_rate,
            .seed = seed,
            .objectives = &objectives,
            .microglia_interval = 30,
            .fpga_lut = @as(u32, @intFromFloat(@as(f32, @floatFromInt(config.workers)) / 200.0 * 50000)),
            .fpga_bram = @as(u32, @intFromFloat(@as(f32, @floatFromInt(config.workers)) / 200.0 * 200)),
            .fpga_dsp = 0,
        };

        // Run simulation
        var sim = try evo_sim.EvolutionSimulator.init(alloc, evo_config);
        defer sim.deinit();

        var result = try sim.run("SEBO_Eval");

        const obj = Objectives{
            .ppl = result.final_ppl,
            .diversity = result.diversity_index,
            .fpga_cost = @as(f32, @floatFromInt(evo_config.fpga_lut)) / 50000.0 * 0.7 +
                @as(f32, @floatFromInt(evo_config.fpga_bram)) / 200.0 * 0.3,
        };

        // Cleanup result
        result.deinit(alloc);

        return obj;
    }

    /// Evolve population for one generation
    fn evolve(self: *SeboOptimizer) !void {
        const pop_size = self.population.items.len;

        // Create new population
        var new_pop = std.ArrayList(SearchResult).initCapacity(self.alloc, pop_size) catch |err| return err;
        defer new_pop.deinit(self.alloc);

        // Sort population for elitism (in-place sort)
        std.sort.insertion(SearchResult, self.population.items, {}, struct {
            fn less(_: void, a: SearchResult, b: SearchResult) bool {
                return a.fitness < b.fitness;
            }
        }.less);

        // Keep elites (top 2)
        const elites_to_keep = @min(self.config.elitism, self.population.items.len);
        for (0..elites_to_keep) |i| {
            try new_pop.append(self.alloc, self.population.items[i]);
        }

        // Generate offspring
        while (new_pop.items.len < pop_size) {
            // Selection: tournament
            const parent1 = try self.tournamentSelect();
            const parent2 = try self.tournamentSelect();

            // Crossover
            var offspring = try self.crossover(&parent1, &parent2);

            // Mutation (simplified - small random perturbation)
            if (self.prng.random().float(f32) < self.config.mutation_rate) {
                offspring.config.ntp_weight = @max(0.0, @min(1.0, offspring.config.ntp_weight + (self.prng.random().float(f32) - 0.5) * 0.1));
                offspring.config.jepa_weight = @max(0.0, @min(1.0, offspring.config.jepa_weight + (self.prng.random().float(f32) - 0.5) * 0.1));
                offspring.config.nca_weight = @max(0.0, @min(1.0, offspring.config.nca_weight + (self.prng.random().float(f32) - 0.5) * 0.1));
            }
            offspring.config.steps = self.steps;

            // Evaluate
            if (self.use_simulation) {
                const seed = self.prng.random().int(u64);
                offspring.objectives = try evaluateWithSimulation(self.alloc, offspring.config, seed);
            } else {
                offspring.objectives = try self.evaluate(&offspring.config);
            }
            offspring.fitness = offspring.objectives.weightedFitness();

            try new_pop.append(self.alloc, offspring);
        }

        // Replace population
        self.population.clearRetainingCapacity();
        for (new_pop.items) |r| {
            try self.population.append(self.alloc, r);
        }
    }

    /// Tournament selection
    fn tournamentSelect(self: *SeboOptimizer) !SearchResult {
        const tournament_size = 3;
        var best: ?*const SearchResult = null;

        for (0..tournament_size) |_| {
            const idx = self.prng.random().uintLessThan(usize, self.population.items.len);
            const cand = &self.population.items[idx];
            if (best == null or cand.fitness < best.?.fitness) {
                best = cand;
            }
        }

        return SearchResult{
            .config = best.?.config,
            .objectives = best.?.objectives,
            .fitness = best.?.fitness,
        };
    }

    /// Crossover: blend two parent configs
    fn crossover(self: *const SeboOptimizer, a: *const SearchResult, b: *const SearchResult) !SearchResult {
        const alpha = self.config.crossover_rate;

        var result = try SearchResult.init(self.alloc);

        // Blend parameters
        result.config.ntp_weight = alpha * a.config.ntp_weight + (1.0 - alpha) * b.config.ntp_weight;
        result.config.jepa_weight = alpha * a.config.jepa_weight + (1.0 - alpha) * b.config.jepa_weight;
        result.config.nca_weight = alpha * a.config.nca_weight + (1.0 - alpha) * b.config.nca_weight;
        result.config.workers = @as(u32, @intFromFloat(alpha * @as(f32, @floatFromInt(a.config.workers)) + (1.0 - alpha) * @as(f32, @floatFromInt(b.config.workers))));
        result.config.kill_threshold = alpha * a.config.kill_threshold + (1.0 - alpha) * b.config.kill_threshold;

        return result;
    }

    /// Get best fitness
    fn getBestFitness(self: *const SeboOptimizer) f32 {
        if (self.population.items.len == 0) return std.math.inf(f32);
        var best: f32 = std.math.inf(f32);
        for (self.population.items) |r| {
            if (r.fitness < best) best = r.fitness;
        }
        return best;
    }

    /// Get best candidate
    pub fn getBest(self: *const SeboOptimizer) SearchResult {
        if (self.population.items.len == 0) {
            return SearchResult{
                .config = .{},
                .objectives = .{},
                .fitness = std.math.inf(f32),
            };
        }
        var best: SearchResult = self.population.items[0];
        for (self.population.items[1..]) |r| {
            if (r.fitness < best.fitness) best = r;
        }
        return best;
    }
};

test "SEBO basic functionality" {
    const alloc = std.testing.allocator;

    const config = SeboConfig{
        .population_size = 10,
        .generations = 3,
    };

    var sebo = try SeboOptimizer.init(alloc, config);
    defer sebo.deinit();

    try sebo.run();

    const best = sebo.getBest();
    try std.testing.expect(best.fitness < std.math.inf(f32));
}

test "Sacred priors" {
    try std.testing.expectApproxEqAbs(SACRED_PRIORS.PHI, 1.6180, 0.001);
    try std.testing.expectApproxEqAbs(SACRED_PRIORS.E, 2.7183, 0.001);
    try std.testing.expectApproxEqAbs(SACRED_PRIORS.PI, 3.1416, 0.001);
    try std.testing.expectApproxEqAbs(SACRED_PRIORS.PHI_INVERSE, 0.6180, 0.001);
}

test "Pareto dominance" {
    const obj1 = Objectives{ .ppl = 5.0, .diversity = 0.8, .fpga_cost = 0.5 };
    const obj2 = Objectives{ .ppl = 6.0, .diversity = 0.7, .fpga_cost = 0.6 };
    const obj3 = Objectives{ .ppl = 4.0, .diversity = 0.9, .fpga_cost = 0.4 };

    try std.testing.expect(obj1.dominates(&obj2)); // obj1 better on all
    try std.testing.expect(!obj2.dominates(&obj1));
    try std.testing.expect(obj3.dominates(&obj1)); // obj3 even better
}
