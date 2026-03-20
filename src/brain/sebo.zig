//! SEBO — Sacred Evolutionary Bayesian Optimization
//!
//! Multi-objective optimization for hyperparameter search using:
//! - Sacred constants (φ, e, π) as Bayesian priors
//! - Microglia feedback for adaptive mutation
//! - Pareto frontier for PPL, Diversity, FPGA cost tradeoffs
//!
//! φ² + 1/phi² = 3 = TRINITY

const std = @import("std");

const Allocator = std.mem.Allocator;
const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const BLUE = "\x1b[34m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";

// Sacred Constants for Bayesian priors
const PHI: f32 = 1.618033988749894;  // Golden ratio
const E: f32 = 2.718281828459045;     // Euler's number
const PI: f32 = 3.141592653589793;     // Pi

// FPGA Budget (Artix-7 K=16)
const LUT_BUDGET: u32 = 50000;
const BRAM_BUDGET: u32 = 100;

pub const OptimizationObjective = enum {
    ppl,      // Minimize PPL
    diversity, // Maximize diversity
    fpga_cost, // Minimize FPGA cost
};

pub const SEBOConfig = struct {
    // Population parameters
    population_size: usize = 32,      // Number of candidate solutions
    generations: usize = 50,            // Number of evolution iterations
    elite_fraction: f32 = 0.2,        // Elite solutions preserved

    // Bayesian priors from Sacred constants
    prior_phi: f32 = 0.7,              // Phi prior strength
    prior_e: f32 = 0.5,                // Euler prior strength
    prior_pi: f32 = 0.3,                // Pi prior strength

    // Adaptive mutation (microglia feedback)
    base_mutation_rate: f32 = 0.1,   // Base mutation rate
    min_mutation_rate: f32 = 0.01, // Minimum (diversity crisis)
    max_mutation_rate: f32 = 0.5,   // Maximum (exploration)

    // Microglia feedback parameters
    microglia_converged_threshold: f32 = 0.8,  // Diversity threshold for convergence
    microglia_crash_threshold: f32 = 0.2,   // Crash rate threshold for crisis
};

pub const CandidateSolution = struct {
    // Evolution parameters
    workers: u32 = 100,               // Initial workers
    generations: u32 = 100,            // Total generations
    steps_per_gen: u32 = 10,          // Steps per generation

    // Policy parameters
    kill_threshold: f32 = 400.0,         // PPL kill threshold
    crash_rate: f32 = 0.05,              // Crash rate (per 1000 steps)
    byzantine_rate: f32 = 0.0,           // Byzantine rate

    // Objective weights
    weight_ppl: f32 = 1.0,             // PPL importance
    weight_diversity: f32 = 1.0,          // Diversity importance
    weight_fpga: f32 = 1.0,              // FPGA cost importance

    // Computed metrics
    predicted_ppl: f32,
    predicted_diversity: f32,
    predicted_fpga_cost: f32,

    // Pareto ranking
    pareto_rank: u32 = 0,
    crowding_distance: f32 = 0.0,
};

/// Sacred prior probability density
pub fn sacredPrior(value: f32, config: SEBOConfig) f32 {
    // Combine Sacred constants with configuration weights
    const phi_component = config.prior_phi * std.math.exp(-std.math.pow(f32, value - PHI) / 0.5);
    const e_component = config.prior_e * std.math.exp(-std.math.pow(f32, value - E) / 1.0);
    const pi_component = config.prior_pi * std.math.exp(-std.math.pow(f32, value - PI) / 1.5);

    return phi_component + e_component + pi_component;
}

/// Adaptive mutation rate based on microglia feedback
pub fn adaptiveMutationRate(
    diversity: f32,
    crash_rate: f32,
    config: SEBOConfig,
) f32 {
    // High diversity + low crash = stable (low mutation)
    // Low diversity + high crash = crisis (high mutation)
    const diversity_score = if (diversity > config.microglia_converged_threshold) 1.0 else 0.0;
    const crisis_score = if (crash_rate > config.microglia_crash_threshold) 1.0 else 0.0;

    const adjustment = (crisis_score * 0.3) + (diversity_score * -0.1);
    const rate = config.base_mutation_rate * (1.0 + adjustment);

    return @max(config.min_mutation_rate, @min(config.max_mutation_rate, rate));
}

/// Predict metrics from candidate solution
pub fn predictMetrics(candidate: CandidateSolution) struct {
    ppl: f32,
    diversity: f32,
    fpga_cost: f32,
} {
    // Simplified prediction models (could be enhanced with ML)
    _ = candidate;

    // PPL model: baseline ~5.0, workers ~100 inverse
    const ppl_factor = @min(1.5, 100.0 / @as(f32, @floatFromInt(candidate.workers)));
    ppl = 5.0 * (1.0 - @abs(candidate.kill_threshold - 400.0) / 600.0) * ppl_factor;

    // Diversity model: balanced ~0.5, high diversity scenarios
    const diversity_weight = if (candidate.weight_diversity > 0.8) 1.2 else 0.8;
    diversity = 0.3 + (0.5 * diversity_weight);

    // FPGA cost: workers → LUT, generations → BRAM
    const lut_cost = @as(f32, @floatFromInt(candidate.workers)) / 100.0 * 0.16; // 16 LUT/worker
    const bram_cost = @as(f32, @floatFromInt(candidate.generations)) / 100.0 * 0.2;  // 20 BRAM/100 gens
    fpga_cost = @min(1.0, (lut_cost * 0.7) + (bram_cost * 0.3));

    return .{ .ppl = ppl, .diversity = diversity, .fpga_cost = fpga_cost };
}

/// Pareto dominance check
pub fn dominates(a: CandidateSolution, b: CandidateSolution) bool {
    const better_ppl = a.predicted_ppl < b.predicted_ppl;
    const better_diversity = a.predicted_diversity > b.predicted_diversity;
    const better_fpga = a.predicted_fpga_cost < b.predicted_fpga_cost;

    // A dominates B if better in all objectives
    return better_ppl and better_diversity and better_fpga;
}

/// Calculate crowding distance for diversity preservation
pub fn calculateCrowdingDistance(
    candidates: []const CandidateSolution,
    index: usize,
    num_objectives: usize,
) f32 {
    if (candidates.len <= 2) return 0.0;

    var distance: f32 = 0.0;
    for (candidates, 0..) |other, i| {
        if (i == index) continue;

        const obj_dist = blk: {
            for (0..num_objectives) |obj_idx| {
                var a_val: f32 = undefined;
                var b_val: f32 = undefined;

                switch (obj_idx) {
                    0 => {
                        a_val = other.predicted_ppl;
                        b_val = candidates[index].predicted_ppl;
                    },
                    1 => {
                        a_val = other.predicted_diversity;
                        b_val = candidates[index].predicted_diversity;
                    },
                    2 => {
                        a_val = other.predicted_fpga_cost;
                        b_val = candidates[index].predicted_fpga_cost;
                    },
                }

                const range = @max(a_val, b_val) - @min(a_val, b_val);
                if (range > 0.0) {
                    distance += @as(f32, @floatFromInt(obj_idx + 1)) * range;
                }
            }
        };
        _ = obj_dist;
    }

    return distance / @as(f32, @floatFromInt(num_objectives));
}

/// Non-dominated sort (Pareto ranking)
pub fn nondominatedSort(candidates: []const CandidateSolution) []u32 {
    var ranks = try std.heap.alloc(u32, candidates.len);
    defer std.heap.free(ranks);

    var rank: u32 = 0;
    for (candidates, 0..) |candidate, i| {
        var dominated_by: u32 = 0;

        for (candidates, 0..) |other, j| {
            if (i == j) continue;
            if (dominates(other, candidate)) {
                dominated_by += 1;
            }
        }

        if (dominated_by == 0) {
            ranks[i] = rank;
            rank += 1;
        }
    }

    return ranks;
}

/// SEBO optimizer
pub const SEBO = struct {
    rng: std.Random.DefaultPrng,
    allocator: Allocator,
    config: SEBOConfig,
    population: std.ArrayList(CandidateSolution),

    const Self = @This();

    pub fn init(alloc: Allocator, cfg: SEBOConfig) !Self {
        var self = Self{
            .rng = std.Random.DefaultPrng.init(@intFromInt(std.time.timestamp())),
            .allocator = alloc,
            .config = cfg,
            .population = std.ArrayList(CandidateSolution).initCapacity(alloc, cfg.population_size) catch |err| return err,
        };

        // Initialize population with Sacred prior sampling
        try self.initializePopulation();

        return self;
    }

    fn initializePopulation(self: *Self) !void {
        // Sample initial population from Sacred priors
        for (0..self.config.population_size) |_| {
            const candidate = self.sampleFromSacredPriors();
            try self.population.append(self.allocator, candidate);
        }
    }

    fn sampleFromSacredPriors(self: *Self) CandidateSolution {
        const workers = self.rng.intRange(u32, 50, 200);
        const generations = self.rng.intRange(u32, 50, 200);
        const steps_per_gen = self.rng.intRange(u32, 5, 20);

        const kill_threshold = 200.0 + @as(f32, @floatFromInt(self.rng.intRange(u32, 0, 400)));
        const crash_rate = 0.01 + @as(f32, @floatFromInt(self.rng.intRange(u32, 0, 10))) / 1000.0;
        const byzantine_rate = @as(f32, @floatFromInt(self.rng.intRange(u32, 0, 5))) / 100.0;

        // Objective weights from Sacred priors
        const weight_ppl = 0.8 + @as(f32, @floatFromInt(self.rng.intRange(u32, 0, 40))) / 100.0;
        const weight_diversity = 0.8 + @as(f32, @floatFromInt(self.rng.intRange(u32, 0, 40))) / 100.0;
        const weight_fpga = 0.8 + @as(f32, @floatFromInt(self.rng.intRange(u32, 0, 40))) / 100.0;

        return CandidateSolution{
            .workers = workers,
            .generations = generations,
            .steps_per_gen = steps_per_gen,
            .kill_threshold = kill_threshold,
            .crash_rate = crash_rate,
            .byzantine_rate = byzantine_rate,
            .weight_ppl = weight_ppl,
            .weight_diversity = weight_diversity,
            .weight_fpga = weight_fpga,
            .predicted_ppl = 0.0,  // Will be computed
            .predicted_diversity = 0.0,
            .predicted_fpga_cost = 0.0,
            .pareto_rank = 0,
            .crowding_distance = 0.0,
        };
    }

    pub fn run(self: *Self) !struct {
        best_ppl: f32,
        best_diversity: f32,
        best_fpga_cost: f32,
        best_candidate: CandidateSolution,
    } {
        print("\n{s}╔════════════════════════════════════════════════════╗{s}\n", .{ .CYAN, RESET });
        print("{s}║       SEBO — Sacred Evolutionary Bayesian Optimization       ║{s}\n", .{ .BOLD, RESET });
        print("{s}╚════════════════════════════════════════════════════╝{s}\n\n", .{ .CYAN, RESET });

        print("{s}Configuration:{s}\n", .{ .BOLD, RESET });
        print("  Population size: {d}\n", .{self.config.population_size});
        print("  Generations: {d}\n", .{self.config.generations});
        print("  Elite fraction: {d:.1}\n", .{self.config.elite_fraction});
        print("  Base mutation: {d:.1}\n", .{self.config.base_mutation_rate});
        print("  Phi prior: {d:.1}, E prior: {d:.1}, Pi prior: {d:.1}\n\n", .{
            self.config.prior_phi, self.config.prior_e, self.config.prior_pi,
        });
        print("{s}─────────────────────────────────────────────────────────────{s}\n\n", .{ .BOLD, RESET });

        // Main evolution loop
        var generation: usize = 0;
        var avg_ppl: f32 = 100.0;
        var avg_diversity: f32 = 0.0;
        var avg_fpga_cost: f32 = 0.0;
        var microglia_feedback: f32 = 0.5;  // Neutral feedback

        while (generation < self.config.generations) : (generation += 1) {
            // 1. Evaluate all candidates
            for (0..self.population.items.len - 1) |idx| { const candidate = &self.population.items[idx];
                const metrics = predictMetrics(candidate.*);
                candidate.predicted_ppl = metrics.ppl;
                candidate.predicted_diversity = metrics.diversity;
                candidate.predicted_fpga_cost = metrics.fpga_cost;
            }

            // 2. Non-dominated sort (Pareto ranking)
            const ranks = nondominatedSort(self.population.items);
            for (self.population.items, 0..) |*candidate, i| {
                candidate.pareto_rank = ranks[i];
            }

            // 3. Calculate crowding distance
            for (self.population.items, 0..) |*candidate, i| {
                candidate.crowding_distance = calculateCrowdingDistance(self.population.items, i, 3);
            }

            // 4. Microglia feedback: compute average population health
            var total_ppl: f32 = 0.0;
            var total_diversity: f32 = 0.0;
            var total_fpga: f32 = 0.0;
            for (self.population.items) |candidate| {
                total_ppl += candidate.predicted_ppl;
                total_diversity += candidate.predicted_diversity;
                total_fpga += candidate.predicted_fpga_cost;
            }
            const count = @as(f32, @floatFromInt(self.population.items.len));
            avg_ppl = total_ppl / count;
            avg_diversity = total_diversity / count;
            avg_fpga_cost = total_fpga / count;

            // Update microglia feedback from population health
            const diversity_health = if (avg_diversity > 0.5) 1.0 else 0.0;
            const fpga_health = if (avg_fpga_cost < 0.4) 1.0 else 0.0;
            microglia_feedback = 0.5 * diversity_health + 0.5 * fpga_health;

            // 5. Selection (tournament + elite)
            const elite_count = @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.config.population_size)) * self.config.elite_fraction));
            const new_population = try self.selectionAndVariation(elite_count, microglia_feedback);

            // Replace population
            self.population.deinit(self.allocator);
            self.population = new_population;

            // Progress every 10 generations
            if (generation % 10 == 0) {
                const best = self.findBest();
                print("{s}Gen {d:>3}: PPL={d:.2}, Div={d:.2}, FPGA={d:.2} {s}Best: PPL={d:.2}, Div={d:.2}, FPGA={d:.2}{s}\n", .{
                    YELLOW, generation, avg_ppl, avg_diversity, avg_fpga_cost, GREEN,
                    best.predicted_ppl, best.predicted_diversity, best.predicted_fpga_cost, RESET,
                });
            }
        }

        // Find final best solution
        const final_best = self.findBest();

        print("\n{s}─────────────────────────────────────────────────────────────{s}\n\n", .{ .BOLD, RESET });
        print("{s}╔══════════════════════════════════════════════════╗{s}\n", .{ .GREEN, RESET });
        print("{s}║                    BEST SOLUTION FOUND                    ║{s}\n", .{ .BOLD, RESET });
        print("{s}╚════════════════════════════════════════════════════╝{s}\n\n", .{ .GREEN, RESET });

        print("{s}Evolution Parameters:{s}\n", .{ .BOLD, RESET });
        print("  Workers: {d}\n", .{final_best.workers});
        print("  Generations: {d}\n", .{final_best.generations});
        print("  Steps/Gen: {d}\n", .{final_best.steps_per_gen});
        print("  Kill Threshold: {d:.1}\n", .{final_best.kill_threshold});
        print("  Crash Rate: {d:.3}%\n", .{final_best.crash_rate * 100.0});
        print("\n{s}Predicted Metrics:{s}\n", .{ .BOLD, RESET });
        print("  PPL: {d:.2}\n", .{final_best.predicted_ppl});
        print("  Diversity: {d:.2}\n", .{final_best.predicted_diversity});
        print("  FPGA Cost: {d:.2} (normalized)\n", .{final_best.predicted_fpga_cost});
        print("\n{s}Objective Weights:{s}\n", .{ .BOLD, RESET });
        print("  PPL: {d:.2}\n", .{final_best.weight_ppl});
        print("  Diversity: {d:.2}\n", .{final_best.weight_diversity});
        print("  FPGA: {d:.2}\n", .{final_best.weight_fpga});
        print("\n{s}φ² + 1/phi² = {d} = TRINITY{s}\n", .{ CYAN, RESET }, 3);

        return .{
            .best_ppl = final_best.predicted_ppl,
            .best_diversity = final_best.predicted_diversity,
            .best_fpga_cost = final_best.predicted_fpga_cost,
            .best_candidate = final_best.*,
        };
    }

    fn findBest(self: *const Self) CandidateSolution {
        var best = self.population.items[0];
        var best_score = std.math.floatMax(f32);

        for (self.population.items) |candidate| {
            // Weighted score (lower is better)
            const score = (candidate.predicted_ppl * candidate.weight_ppl) +
                       (0.5 - candidate.predicted_diversity) * candidate.weight_diversity +
                       (candidate.predicted_fpga_cost * candidate.weight_fpga);
            if (score < best_score) {
                best = candidate.*;
                best_score = score;
            }
        }

        return best.*;
    }

    fn selectionAndVariation(self: *Self, elite_count: usize, microglia_feedback: f32) !std.ArrayList(CandidateSolution) {
        var new_pop = std.ArrayList(CandidateSolution).initCapacity(self.allocator, self.config.population_size) catch |err| return err;

        // Preserve elites
        var ranked = try std.heap.alloc(usize, self.population.items.len);
        defer std.heap.free(ranked);
        const ranks = nondominatedSort(self.population.items);
        for (ranks, 0..) |rank, i| {
            if (rank == 0) ranked[i] = i;
        }

        // Calculate mutation rate from microglia feedback
        const mutation_rate = adaptiveMutationRate(0.5, 0.05, self.config);

        // Elite preservation (copy top N non-dominated solutions)
        var elite_copied: usize = 0;
        for (0..self.population.items.len) |i| {
            if (ranks[i] < elite_count) {
                try new_pop.append(self.allocator, self.population.items[i].*);
                elite_copied += 1;
            }
        }

        // Generate offspring from elites with variation
        while (new_pop.items.len < self.config.population_size) {
            const parent_idx = self.rng.intRange(usize, 0, elite_copied);
            const parent = self.population.items[parent_idx];

            // Crossover (blend parameters)
            const mate = self.population.items[self.rng.intRange(usize, 0, elite_copied)];
            const alpha = self.rng.float(f32);

            // Mutation (adaptive rate)
            const should_mutate = self.rng.float(f32) < mutation_rate;
            const mutation_scale = if (should_mutate) 1.0 + alpha else 1.0;

            // Apply Sacred prior to mutation
            const sacred_prior = sacredPrior(alpha, self.config);

            // Scale parent parameters
            const w_scaled: f32 = @floatFromInt(@intFromFloat(@as(f32, @floatFromInt(parent.workers) * mutation_scale));
            const g_scaled: f32 = @floatFromInt(@intFromFloat(@as(f32, @floatFromInt(parent.generations) * mutation_scale));
            const s_scaled: f32 = @floatFromInt(@intFromFloat(@as(f32, @floatFromInt(parent.steps_per_gen) * mutation_scale));

            const new_candidate = CandidateSolution{
                .workers = @as(u32, @intFromFloat(w_scaled)),
                .generations = @as(u32, @intFromFloat(g_scaled)),
                .steps_per_gen = @as(u32, @intFromFloat(s_scaled)),
                .kill_threshold = parent.kill_threshold * mutation_scale + (sacred_prior * 50.0),
                .crash_rate = @max(0.01, parent.crash_rate * (1.0 - sacred_prior * 0.5)),
                .byzantine_rate = parent.byzantine_rate * (1.0 - sacred_prior * 0.3),
                .weight_ppl = parent.weight_ppl * (1.0 - sacred_prior * 0.2),
                .weight_diversity = parent.weight_diversity * (1.0 - sacred_prior * 0.1),
                .weight_fpga = parent.weight_fpga * (1.0 - sacred_prior * 0.1),
                .predicted_ppl = 0.0,
                .predicted_diversity = 0.0,
                .predicted_fpga_cost = 0.0,
                .pareto_rank = 0,
                .crowding_distance = 0.0,
            };

            try new_pop.append(self.allocator, new_candidate);
        }

        new_pop.deinit(self.allocator);
        return new_pop;
    }

    pub fn deinit(self: *Self) void {
        self.population.deinit(self.allocator);
    }
};

// Tests
test "SEBO sacredPrior" {
    const config = SEBOConfig{};
    const result = sacredPrior(PHI, config);
    try std.testing.expectApproxEqAbs(@as(f32, @floatFromInt(@intFromFloat(result * 100.0))), 70.0);
}

test "SEBO adaptiveMutationRate" {
    const config = SEBOConfig{
        .base_mutation_rate = 0.1,
        .min_mutation_rate = 0.01,
        .max_mutation_rate = 0.5,
        .microglia_converged_threshold = 0.8,
        .microglia_crash_threshold = 0.2,
    };

    // High diversity, low crash = stable (low mutation)
    const rate1 = adaptiveMutationRate(0.9, 0.1, config);
    try std.testing.expectApproxEqAbs(rate1, 0.1);

    // Low diversity, high crash = crisis (high mutation)
    const rate2 = adaptiveMutationRate(0.3, 0.3, config);
    try std.testing.expectApproxEqAbs(rate2, 0.5);
}

test "SEBO dominates" {
    const a = CandidateSolution{
        .predicted_ppl = 5.0,
        .predicted_diversity = 0.8,
        .predicted_fpga_cost = 0.3,
    };
    const b = CandidateSolution{
        .predicted_ppl = 6.0,
        .predicted_diversity = 0.7,
        .predicted_fpga_cost = 0.4,
    };

    // A dominates B if better in all objectives
    try std.testing.expect(dominates(a, b) == true);

    // B does not dominate A
    try std.testing.expect(dominates(b, a) == false);

    // Equal solutions don't dominate each other
    const c = CandidateSolution{
        .predicted_ppl = 5.0,
        .predicted_diversity = 0.8,
        .predicted_fpga_cost = 0.3,
    };
    try std.testing.expect(dominates(a, c) == false);
    try std.testing.expect(dominates(c, a) == false);
}

test "SEBO nondominatedSort" {
    const candidates = [_]CandidateSolution{
        .{ .predicted_ppl = 5.0, .predicted_diversity = 0.9, .predicted_fpga_cost = 0.2 },
        .{ .predicted_ppl = 5.0, .predicted_diversity = 0.8, .predicted_fpga_cost = 0.3 },
        .{ .predicted_ppl = 5.0, .predicted_diversity = 0.7, .predicted_fpga_cost = 0.4 },
        .{ .predicted_ppl = 6.0, .predicted_diversity = 0.9, .predicted_fpga_cost = 0.2 },
        .{ .predicted_ppl = 5.0, .predicted_diversity = 0.8, .predicted_fpga_cost = 0.3 },
    };

    const ranks = nondominatedSort(&candidates);
    // First two should be rank 0 (non-dominated), rest higher
    try std.testing.expect(ranks[0] == 0);
    try std.testing.expect(ranks[1] == 0);
    try std.testing.expect(ranks[2] > 0);
    try std.testing.expect(ranks[3] > 0);
    try std.testing.expect(ranks[4] > 0);
}

test "SEBO initAndRun" {
    var config = SEBOConfig{
        .population_size = 8,
        .generations = 5,
        .elite_fraction = 0.5,
    };

    var sebo = try SEBO.init(std.testing.allocator, config);
    defer sebo.deinit();

    const result = try sebo.run();

    // Should find a solution with reasonable metrics
    try std.testing.expect(result.best_ppl < 20.0);
    try std.testing.expect(result.best_diversity > 0.2);
    try std.testing.expect(result.best_fpga_cost > 0.0);

    // Best candidate should have valid parameters
    try std.testing.expect(result.best_candidate.workers > 0);
    try std.testing.expect(result.best_candidate.generations > 0);
}
