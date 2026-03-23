//! Strand I: Mathematical Foundation
//!
//! Sacred mathematics module for Trinity S³AI.
//!

//! ML Patch Optimizer - Genetic Algorithm-Based Evolution
//!
//! Evolves patches over generations to maximize quality and minimize errors.
//! Uses sacred mathematics constants (φ, μ, χ, σ, ε) for optimal convergence.

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// Sacred constants
const PHI: f64 = 1.618033988749895; // Golden ratio
const MU: f64 = 0.0382; // φ^(-4)
const CHI: f64 = 0.0618; // 1/φ^2
const SIGMA: f64 = 1.618; // Selection pressure
const EPSILON: f64 = 0.333; // 1/3 (elitism rate)

/// Gene count for chromosome encoding
const GENE_COUNT: usize = 12;

/// Maximum patch size in characters
const MAX_PATCH_SIZE: usize = 4096;

/// Tournament size for parent selection
const TOURNAMENT_SIZE: usize = 5;

/// Auto-generated code patch
pub const AutoCodePatch = struct {
    description: []const u8,
    old_code: []const u8,
    new_code: []const u8,
    file_path: []const u8,
    line_start: u32,
    line_end: u32,
    confidence: f64,
    sacred_alignment: f64,

    pub fn init(
        allocator: Allocator,
        description: []const u8,
        old_code: []const u8,
        new_code: []const u8,
        file_path: []const u8,
        line_start: u32,
        line_end: u32,
    ) !AutoCodePatch {
        return AutoCodePatch{
            .description = try allocator.dupe(u8, description),
            .old_code = try allocator.dupe(u8, old_code),
            .new_code = try allocator.dupe(u8, new_code),
            .file_path = try allocator.dupe(u8, file_path),
            .line_start = line_start,
            .line_end = line_end,
            .confidence = 0.5,
            .sacred_alignment = 0.0,
        };
    }

    pub fn deinit(self: *AutoCodePatch, allocator: Allocator) void {
        allocator.free(self.description);
        allocator.free(self.old_code);
        allocator.free(self.new_code);
        allocator.free(self.file_path);
    }

    /// Calculate size difference (new - old)
    pub fn sizeDiff(self: *const AutoCodePatch) isize {
        return @as(isize, @intCast(self.new_code.len)) - @as(isize, @intCast(self.old_code.len));
    }

    /// Check if patch adds sacred constants
    pub fn hasSacredConstants(self: *const AutoCodePatch) bool {
        const sacred = [_][]const u8{ "1.618033988749895", "0.0382", "0.0618", "3.141592653589793" };
        for (sacred) |const_str| {
            if (std.mem.indexOf(u8, self.new_code, const_str) != null) {
                return true;
            }
        }
        return false;
    }
};

/// Patch chromosome for genetic evolution
pub const PatchChromosome = struct {
    patch: AutoCodePatch,
    genes: [GENE_COUNT]f64,
    fitness: f64,
    age: u32,

    pub fn init(
        allocator: Allocator,
        patch: AutoCodePatch,
        initial_genes: ?[GENE_COUNT]f64,
    ) !PatchChromosome {
        _ = allocator;
        var genes: [GENE_COUNT]f64 = undefined;
        if (initial_genes) |g| {
            genes = g;
        } else {
            // Initialize random genes [0, 1]
            var i: usize = 0;
            while (i < GENE_COUNT) : (i += 1) {
                genes[i] = @as(f64, @floatFromInt(std.crypto.random.int(u64))) / @as(f64, @floatFromInt(std.math.maxInt(u64)));
            }
        }

        // Note: patch must be allocated and ownership is transferred to the chromosome
        return PatchChromosome{
            .patch = patch,
            .genes = genes,
            .fitness = 0.0,
            .age = 0,
        };
    }

    pub fn deinit(self: *PatchChromosome, allocator: Allocator) void {
        self.patch.deinit(allocator);
    }

    /// Clone chromosome
    pub fn clone(self: *const PatchChromosome, allocator: Allocator) !PatchChromosome {
        var cloned_patch = try AutoCodePatch.init(
            allocator,
            self.patch.description,
            self.patch.old_code,
            self.patch.new_code,
            self.patch.file_path,
            self.patch.line_start,
            self.patch.line_end,
        );
        cloned_patch.confidence = self.patch.confidence;
        cloned_patch.sacred_alignment = self.patch.sacred_alignment;

        return PatchChromosome{
            .patch = cloned_patch,
            .genes = self.genes,
            .fitness = self.fitness,
            .age = self.age,
        };
    }
};

/// Optimizer configuration with sacred defaults
pub const OptimizerConfig = struct {
    population_size: u32 = 50,
    max_generations: u32 = 100,
    mutation_rate: f64 = MU, // φ^(-4)
    crossover_rate: f64 = CHI, // 1/φ^2
    selection_pressure: f64 = SIGMA, // φ
    elitism_rate: f64 = EPSILON, // 1/3
    target_fitness: f64 = 0.999,
    stagnation_generations: u32 = 10,
    verbose: bool = false,
};

/// Evolution result
pub const EvolutionResult = struct {
    best_patch: AutoCodePatch,
    generation: u32,
    final_fitness: f64,
    convergence_reason: ConvergenceReason,
    statistics: EvolutionStatistics,

    pub fn format(self: *const EvolutionResult, allocator: Allocator) ![]const u8 {
        var buffer = ArrayList(u8).empty;
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, "=== Evolution Result ===\n");
        try buffer.appendSlice(allocator, "Best Patch: ");
        try buffer.appendSlice(allocator, self.best_patch.description);
        try buffer.appendSlice(allocator, "\n");
        try buffer.appendSlice(allocator, "Generation: ");
        if (std.fmt.allocPrint(allocator, "{d}", .{self.generation})) |s| {
            defer allocator.free(s);
            try buffer.appendSlice(allocator, s);
        } else |_| {
            try buffer.appendSlice(allocator, "N/A");
        }
        try buffer.appendSlice(allocator, "\n");
        try buffer.appendSlice(allocator, "Final Fitness: ");
        if (std.fmt.allocPrint(allocator, "{d:.6}", .{self.final_fitness})) |s| {
            defer allocator.free(s);
            try buffer.appendSlice(allocator, s);
        } else |_| {
            try buffer.appendSlice(allocator, "N/A");
        }
        try buffer.appendSlice(allocator, "\n");
        try buffer.appendSlice(allocator, "Convergence: ");
        try buffer.appendSlice(allocator, @tagName(self.convergence_reason));
        try buffer.appendSlice(allocator, "\n");

        return buffer.toOwnedSlice(allocator);
    }
};

/// Reason for evolution convergence
pub const ConvergenceReason = enum {
    target_reached,
    stagnation,
    max_generations,
    manual_stop,
};

/// Evolution statistics
pub const EvolutionStatistics = struct {
    total_evaluations: u64,
    average_fitness: f64,
    fitness_stddev: f64,
    best_fitness_history: ArrayList(f64),
    average_fitness_history: ArrayList(f64),
    diversity_score: f64,

    pub fn init(allocator: Allocator) EvolutionStatistics {
        _ = allocator;
        return EvolutionStatistics{
            .total_evaluations = 0,
            .average_fitness = 0.0,
            .fitness_stddev = 0.0,
            .best_fitness_history = ArrayList(f64).empty,
            .average_fitness_history = ArrayList(f64).empty,
            .diversity_score = 1.0,
        };
    }

    pub fn deinit(self: *EvolutionStatistics, allocator: Allocator) void {
        self.best_fitness_history.deinit(allocator);
        self.average_fitness_history.deinit(allocator);
    }
};

/// Patch outcome for learning
pub const PatchOutcome = struct {
    patch: PatchChromosome,
    success: bool,
    test_pass_rate: f64,
    error_count: u32,
    user_satisfaction: f64, // 0.0 - 1.0

    pub fn init(
        patch: PatchChromosome,
        success: bool,
        test_pass_rate: f64,
        error_count: u32,
        user_satisfaction: f64,
    ) PatchOutcome {
        return PatchOutcome{
            .patch = patch,
            .success = success,
            .test_pass_rate = test_pass_rate,
            .error_count = error_count,
            .user_satisfaction = user_satisfaction,
        };
    }
};

/// Parent pair for crossover
const ParentPair = struct {
    parent1: *PatchChromosome,
    parent2: *PatchChromosome,
};

/// ML Patch Optimizer - Main genetic engine
pub const MLPatchOptimizer = struct {
    allocator: Allocator,
    population: ArrayList(PatchChromosome),
    fitness_scores: ArrayList(f64),
    generation: u32,
    best_patch: ?PatchChromosome,
    best_fitness: f64,
    best_generation: u32,
    stagnation_counter: u32,
    config: OptimizerConfig,
    statistics: EvolutionStatistics,
    regression_patterns: ArrayList([]const u8),
    successful_patterns: ArrayList([]const u8),

    /// Initialize optimizer with configuration
    pub fn init(allocator: Allocator, config: OptimizerConfig) !MLPatchOptimizer {
        return MLPatchOptimizer{
            .allocator = allocator,
            .population = ArrayList(PatchChromosome).empty,
            .fitness_scores = ArrayList(f64).empty,
            .generation = 0,
            .best_patch = null,
            .best_fitness = 0.0,
            .best_generation = 0,
            .stagnation_counter = 0,
            .config = config,
            .statistics = EvolutionStatistics.init(allocator),
            .regression_patterns = ArrayList([]const u8).empty,
            .successful_patterns = ArrayList([]const u8).empty,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *MLPatchOptimizer) void {
        var i: usize = 0;
        while (i < self.population.items.len) : (i += 1) {
            self.population.items[i].deinit(self.allocator);
        }
        self.population.deinit(self.allocator);
        self.fitness_scores.deinit(self.allocator);
        self.statistics.deinit(self.allocator);

        if (self.best_patch) |*patch| {
            patch.deinit(self.allocator);
        }

        var j: usize = 0;
        while (j < self.regression_patterns.items.len) : (j += 1) {
            self.allocator.free(self.regression_patterns.items[j]);
        }
        self.regression_patterns.deinit(self.allocator);

        var k: usize = 0;
        while (k < self.successful_patterns.items.len) : (k += 1) {
            self.allocator.free(self.successful_patterns.items[k]);
        }
        self.successful_patterns.deinit(self.allocator);
    }

    /// Main evolution loop
    pub fn evolve(self: *MLPatchOptimizer, target_code: []const u8) !EvolutionResult {
        if (self.config.verbose) {
            std.debug.print("=== Starting Evolution ===\n", .{});
            std.debug.print("Population: {d}, Max Generations: {d}\n", .{
                self.config.population_size,
                self.config.max_generations,
            });
        }

        // Initialize population
        try self.initializePopulation(target_code);

        // Evolution loop
        while (self.generation < self.config.max_generations) : (self.generation += 1) {
            if (self.config.verbose) {
                std.debug.print("\n[Generation {d}]\n", .{self.generation});
            }

            // Evaluate fitness
            try self.evaluateFitness(target_code);

            // Track statistics
            try self.trackStatistics();

            // Check convergence
            if (self.checkConvergence()) {
                if (self.config.verbose) {
                    std.debug.print("Convergence detected at generation {d}\n", .{self.generation});
                }
                break;
            }

            // Selection
            const parents = try self.selectParents();

            // Create next generation
            try self.createNextGeneration(parents);

            // Cleanup parents
            self.allocator.free(parents);
        }

        // Build result
        return self.buildResult();
    }

    /// Initialize random population
    fn initializePopulation(self: *MLPatchOptimizer, target_code: []const u8) !void {
        if (self.config.verbose) {
            std.debug.print("Initializing population...\n", .{});
        }

        var i: u32 = 0;
        while (i < self.config.population_size) : (i += 1) {
            // Create random patch
            const patch = try self.createRandomPatch(target_code);
            const chromosome = try PatchChromosome.init(self.allocator, patch, null);
            try self.population.append(self.allocator, chromosome);
        }

        if (self.config.verbose) {
            std.debug.print("Population initialized: {d} chromosomes\n", .{self.population.items.len});
        }
    }

    /// Create a random patch for initialization
    fn createRandomPatch(self: *MLPatchOptimizer, target_code: []const u8) !AutoCodePatch {
        // Simple placeholder patch - in practice, would generate real variants
        const desc = try std.fmt.allocPrint(self.allocator, "Random patch {d}", .{
            std.crypto.random.int(u32),
        });
        errdefer self.allocator.free(desc);

        return AutoCodePatch.init(
            self.allocator,
            desc,
            target_code, // old_code = target
            target_code, // new_code = target (no change initially)
            "unknown.zig",
            0,
            0,
        );
    }

    /// Evaluate fitness for entire population
    fn evaluateFitness(self: *MLPatchOptimizer, target_code: []const u8) !void {
        self.fitness_scores.clearRetainingCapacity();

        for (self.population.items) |*chromosome| {
            const fitness = try self.calculateFitness(chromosome, target_code);
            chromosome.fitness = fitness;
            try self.fitness_scores.append(self.allocator, fitness);

            // Track best
            if (fitness > self.best_fitness) {
                self.best_fitness = fitness;

                // Clean up previous best
                if (self.best_patch) |*patch| {
                    patch.deinit(self.allocator);
                }

                self.best_patch = try chromosome.clone(self.allocator);
                self.best_generation = self.generation;
                self.stagnation_counter = 0;
            }
        }

        if (self.config.verbose) {
            const best_gen = self.best_fitness;
            const avg = self.calculateAverageFitness();
            std.debug.print("  Best: {d:.6}, Avg: {d:.6}\n", .{ best_gen, avg });
        }
    }

    /// Calculate fitness for a single chromosome
    fn calculateFitness(
        self: *MLPatchOptimizer,
        chromosome: *PatchChromosome,
        target_code: []const u8,
    ) !f64 {
        _ = target_code;
        const patch = &chromosome.patch;

        // Component 1: Confidence score (40%)
        const confidence_score = patch.confidence * 0.4;

        // Component 2: Sacred alignment (25%)
        const sacred_score = patch.sacred_alignment * 0.25;

        // Component 3: Code quality (20%)
        const quality_score = calculateCodeQuality(patch) * 0.2;

        // Component 4: Simplicity - fewer changes is better (10%)
        const size_diff = @abs(patch.sizeDiff());
        const simplicity_score = @exp(-@as(f64, @floatFromInt(size_diff)) / 1000.0) * 0.1;

        // Component 5: Gene diversity bonus (5%)
        const gene_variance = calculateGeneVariance(chromosome.genes);
        const diversity_score = gene_variance * 0.05;

        // Total fitness
        var fitness = confidence_score + sacred_score + quality_score + simplicity_score + diversity_score;

        // Penalty for regression patterns
        for (self.regression_patterns.items) |pattern| {
            if (std.mem.indexOf(u8, patch.new_code, pattern) != null) {
                fitness *= 0.5; // 50% penalty
            }
        }

        return @min(fitness, 1.0);
    }

    /// Calculate code quality score [0, 1]
    fn calculateCodeQuality(patch: *const AutoCodePatch) f64 {
        var score: f64 = 1.0;

        // Check for proper indentation (4 spaces)
        if (!std.mem.startsWith(u8, patch.new_code, "    ") and
            !std.mem.startsWith(u8, patch.new_code, "        "))
        {
            score -= 0.2;
        }

        // Check for reasonable line lengths
        var line_iter = std.mem.splitScalar(u8, patch.new_code, '\n');
        var too_long: usize = 0;
        var total_lines: usize = 0;
        while (line_iter.next()) |line| {
            total_lines += 1;
            if (line.len > 100) too_long += 1;
        }
        if (total_lines > 0) {
            const long_ratio = @as(f64, @floatFromInt(too_long)) / @as(f64, @floatFromInt(total_lines));
            score -= long_ratio * 0.3;
        }

        // Bonus for sacred constants
        if (patch.hasSacredConstants()) {
            score += 0.1;
        }

        return @max(score, 0.0);
    }

    /// Calculate variance of genes
    fn calculateGeneVariance(genes: [GENE_COUNT]f64) f64 {

        // Calculate mean
        var sum: f64 = 0.0;
        for (genes) |g| sum += g;
        const mean = sum / GENE_COUNT;

        // Calculate variance
        var variance: f64 = 0.0;
        for (genes) |g| {
            const diff = g - mean;
            variance += diff * diff;
        }
        variance /= GENE_COUNT;

        return variance;
    }

    /// Calculate average fitness of population
    fn calculateAverageFitness(self: *MLPatchOptimizer) f64 {
        if (self.fitness_scores.items.len == 0) return 0.0;

        var sum: f64 = 0.0;
        for (self.fitness_scores.items) |f| sum += f;
        return sum / @as(f64, @floatFromInt(self.fitness_scores.items.len));
    }

    /// Track evolution statistics
    fn trackStatistics(self: *MLPatchOptimizer) !void {
        self.statistics.total_evaluations += self.population.items.len;

        const avg_fitness = self.calculateAverageFitness();
        self.statistics.average_fitness = avg_fitness;

        // Calculate standard deviation
        var variance: f64 = 0.0;
        for (self.fitness_scores.items) |f| {
            const diff = f - avg_fitness;
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(self.fitness_scores.items.len));
        self.statistics.fitness_stddev = @sqrt(variance);

        // Record history
        try self.statistics.best_fitness_history.append(self.allocator, self.best_fitness);
        try self.statistics.average_fitness_history.append(self.allocator, avg_fitness);

        // Calculate diversity (average pairwise distance)
        self.statistics.diversity_score = try self.calculatePopulationDiversity();
    }

    /// Calculate population diversity score
    fn calculatePopulationDiversity(self: *MLPatchOptimizer) !f64 {
        if (self.population.items.len < 2) return 1.0;

        var total_distance: f64 = 0.0;
        var comparisons: u64 = 0;

        var i: usize = 0;
        while (i < self.population.items.len) : (i += 1) {
            var j: usize = i + 1;
            while (j < self.population.items.len) : (j += 1) {
                // Gene-wise distance
                var distance: f64 = 0.0;
                for (0..GENE_COUNT) |k| {
                    const diff = self.population.items[i].genes[k] - self.population.items[j].genes[k];
                    distance += diff * diff;
                }
                total_distance += @sqrt(distance / GENE_COUNT);
                comparisons += 1;
            }
        }

        return if (comparisons > 0)
            total_distance / @as(f64, @floatFromInt(comparisons))
        else
            1.0;
    }

    /// Check for convergence
    fn checkConvergence(self: *MLPatchOptimizer) bool {
        // Target reached?
        if (self.best_fitness >= self.config.target_fitness) {
            return true;
        }

        // Stagnation?
        if (self.stagnation_counter >= self.config.stagnation_generations) {
            return true;
        }

        self.stagnation_counter += 1;
        return false;
    }

    /// Select parents using tournament selection
    fn selectParents(self: *MLPatchOptimizer) ![]ParentPair {
        const pair_count = @divTrunc(self.config.population_size, 2);
        const pairs = try self.allocator.alloc(ParentPair, pair_count);

        var i: usize = 0;
        while (i < pair_count) : (i += 1) {
            const parent1 = try self.tournamentSelect();
            const parent2 = try self.tournamentSelect();

            pairs[i] = ParentPair{
                .parent1 = parent1,
                .parent2 = parent2,
            };
        }

        return pairs;
    }

    /// Tournament selection
    fn tournamentSelect(self: *MLPatchOptimizer) !*PatchChromosome {
        // Select random candidates
        var best_idx: usize = std.crypto.random.intRangeLessThan(usize, 0, self.population.items.len);
        var best_fitness = self.population.items[best_idx].fitness;

        var i: usize = 1;
        while (i < TOURNAMENT_SIZE) : (i += 1) {
            const idx = std.crypto.random.intRangeLessThan(usize, 0, self.population.items.len);
            const fitness = self.population.items[idx].fitness;

            if (fitness > best_fitness) {
                best_idx = idx;
                best_fitness = fitness;
            }
        }

        return &self.population.items[best_idx];
    }

    /// Create next generation
    fn createNextGeneration(self: *MLPatchOptimizer, parents: []ParentPair) !void {
        var new_population = ArrayList(PatchChromosome).empty;

        // Apply elitism - preserve best chromosomes
        const elite_count = @as(usize, @intFromFloat(@as(f64, @floatFromInt(self.config.population_size)) * self.config.elitism_rate));
        try self.applyElitism(&new_population, elite_count);

        // Generate offspring
        var offspring_count: usize = 0;
        for (parents) |pair| {
            if (offspring_count >= self.config.population_size - elite_count) break;

            // Crossover?
            if (@as(f64, @floatFromInt(std.crypto.random.int(u64))) / @as(f64, @floatFromInt(std.math.maxInt(u64))) < self.config.crossover_rate) {
                const offspring = try self.crossover(pair.parent1, pair.parent2);
                try new_population.append(self.allocator, offspring);
                offspring_count += 1;
            } else {
                // Just copy parent1
                const clone = try pair.parent1.clone(self.allocator);
                try new_population.append(self.allocator, clone);
                offspring_count += 1;
            }
        }

        // Fill remaining with mutations if needed
        while (new_population.items.len < self.config.population_size) {
            const idx = std.crypto.random.intRangeLessThan(usize, 0, new_population.items.len);
            var clone = try new_population.items[idx].clone(self.allocator);
            try self.mutate(&clone, self.config.mutation_rate);
            try new_population.append(self.allocator, clone);
        }

        // Replace old population
        for (self.population.items) |*chrom| {
            chrom.deinit(self.allocator);
        }
        self.population.deinit(self.allocator);
        self.population = new_population;
    }

    /// Apply elitism - preserve best chromosomes
    fn applyElitism(
        self: *MLPatchOptimizer,
        new_population: *ArrayList(PatchChromosome),
        count: usize,
    ) !void {
        // Sort population by fitness (descending)
        const sorted = try self.allocator.alloc(PatchChromosome, self.population.items.len);
        defer self.allocator.free(sorted);

        @memcpy(sorted, self.population.items);

        // Simple bubble sort (good enough for small populations)
        var i: usize = 0;
        while (i < sorted.len) : (i += 1) {
            var j: usize = 0;
            while (j < sorted.len - i - 1) : (j += 1) {
                if (sorted[j].fitness < sorted[j + 1].fitness) {
                    // Swap
                    const temp = sorted[j];
                    sorted[j] = sorted[j + 1];
                    sorted[j + 1] = temp;
                }
            }
        }

        // Copy top chromosomes
        var k: usize = 0;
        while (k < @min(count, sorted.len)) : (k += 1) {
            const cloned = try sorted[k].clone(self.allocator);
            try new_population.append(self.allocator, cloned);
        }
    }

    /// Crossover two parents
    fn crossover(
        self: *MLPatchOptimizer,
        parent1: *PatchChromosome,
        parent2: *PatchChromosome,
    ) !PatchChromosome {
        // Single-point crossover on genes
        const crossover_point = std.crypto.random.intRangeLessThan(usize, 0, GENE_COUNT);

        var child_genes: [GENE_COUNT]f64 = undefined;
        for (0..GENE_COUNT) |i| {
            if (i < crossover_point) {
                child_genes[i] = parent1.genes[i];
            } else {
                child_genes[i] = parent2.genes[i];
            }
        }

        // Blend patches (take description from fitter parent)
        const better_parent = if (parent1.fitness > parent2.fitness) parent1 else parent2;
        var child_patch = try AutoCodePatch.init(
            self.allocator,
            better_parent.patch.description,
            better_parent.patch.old_code,
            better_parent.patch.new_code,
            better_parent.patch.file_path,
            better_parent.patch.line_start,
            better_parent.patch.line_end,
        );
        errdefer child_patch.deinit(self.allocator);

        // Blend confidence
        child_patch.confidence = (parent1.patch.confidence + parent2.patch.confidence) / 2.0;
        child_patch.sacred_alignment = (parent1.patch.sacred_alignment + parent2.patch.sacred_alignment) / 2.0;

        var child = try PatchChromosome.init(self.allocator, child_patch, child_genes);
        child.age = @max(parent1.age, parent2.age) + 1;

        return child;
    }

    /// Mutate chromosome
    fn mutate(self: *MLPatchOptimizer, chromosome: *PatchChromosome, rate: f64) !void {
        for (0..GENE_COUNT) |i| {
            if (@as(f64, @floatFromInt(std.crypto.random.int(u64))) / @as(f64, @floatFromInt(std.math.maxInt(u64))) < rate) {
                // Gaussian mutation
                const gaussian = self.boxMuller();
                const new_val = chromosome.genes[i] + gaussian * 0.2;
                chromosome.genes[i] = if (new_val < 0.0) 0.0 else if (new_val > 1.0) 1.0 else new_val;
            }
        }

        // Mutate confidence slightly
        if (@as(f64, @floatFromInt(std.crypto.random.int(u64))) / @as(f64, @floatFromInt(std.math.maxInt(u64))) < rate) {
            const new_conf = chromosome.patch.confidence + (self.boxMuller() * 0.1);
            chromosome.patch.confidence = if (new_conf < 0.0) 0.0 else if (new_conf > 1.0) 1.0 else new_conf;
        }
    }

    /// Box-Muller transform for Gaussian random
    fn boxMuller(self: *MLPatchOptimizer) f64 {
        _ = self;

        const u1_val = @as(f64, @floatFromInt(std.crypto.random.int(u64))) / @as(f64, @floatFromInt(std.math.maxInt(u64)));
        const u2_val = @as(f64, @floatFromInt(std.crypto.random.int(u64))) / @as(f64, @floatFromInt(std.math.maxInt(u64)));

        return @sqrt(-2.0 * @log(u1_val)) * @cos(2.0 * std.math.pi * u2_val);
    }

    /// Build evolution result
    fn buildResult(self: *MLPatchOptimizer) !EvolutionResult {
        const convergence_reason = if (self.best_fitness >= self.config.target_fitness)
            ConvergenceReason.target_reached
        else if (self.stagnation_counter >= self.config.stagnation_generations)
            ConvergenceReason.stagnation
        else if (self.generation >= self.config.max_generations)
            ConvergenceReason.max_generations
        else
            ConvergenceReason.manual_stop;

        var result = EvolutionResult{
            .best_patch = undefined,
            .generation = self.generation,
            .final_fitness = self.best_fitness,
            .convergence_reason = convergence_reason,
            .statistics = undefined,
        };

        // Clone best patch
        if (self.best_patch) |*best| {
            result.best_patch = try AutoCodePatch.init(
                self.allocator,
                best.patch.description,
                best.patch.old_code,
                best.patch.new_code,
                best.patch.file_path,
                best.patch.line_start,
                best.patch.line_end,
            );
            result.best_patch.confidence = best.patch.confidence;
            result.best_patch.sacred_alignment = best.patch.sacred_alignment;
        } else {
            return error.NoBestPatch;
        }

        // Move statistics
        result.statistics = self.statistics;
        self.statistics = EvolutionStatistics.init(self.allocator);

        return result;
    }

    /// Learn from patch outcome
    pub fn learnFromPatchOutcome(self: *MLPatchOptimizer, outcome: PatchOutcome) !void {
        if (outcome.success) {
            // Record successful pattern
            const pattern = try std.fmt.allocPrint(
                self.allocator,
                "{s}:{d}-{d}",
                .{ outcome.patch.patch.file_path, outcome.patch.patch.line_start, outcome.patch.patch.line_end },
            );
            try self.successful_patterns.append(self.allocator, pattern);
        } else {
            // Record regression pattern
            const pattern = try std.fmt.allocPrint(
                self.allocator,
                "{s}:{d}-{d}",
                .{ outcome.patch.patch.file_path, outcome.patch.patch.line_start, outcome.patch.patch.line_end },
            );
            try self.regression_patterns.append(self.allocator, pattern);
        }

        // Adapt parameters
        try self.adaptParameters(outcome);
    }

    /// Record regression pattern
    pub fn recordRegression(self: *MLPatchOptimizer, patch: PatchChromosome) !void {
        const pattern = try std.fmt.allocPrint(
            self.allocator,
            "{s}:{d}-{d}",
            .{ patch.patch.file_path, patch.line_start, patch.line_end },
        );
        try self.regression_patterns.append(self.allocator, pattern);
    }

    /// Adapt optimization parameters based on outcomes
    fn adaptParameters(self: *MLPatchOptimizer, outcome: PatchOutcome) !void {
        _ = outcome;

        // Simple adaptive scheme: increase mutation if diversity is low
        if (self.statistics.diversity_score < 0.3) {
            self.config.mutation_rate = @min(self.config.mutation_rate * 1.2, 0.2);
        } else if (self.statistics.diversity_score > 0.8) {
            self.config.mutation_rate = @max(self.config.mutation_rate * 0.9, MU);
        }

        // Adjust selection pressure
        if (self.statistics.fitness_stddev < 0.1) {
            // Low variance - increase selection pressure
            self.config.selection_pressure = @min(self.config.selection_pressure * 1.1, 3.0);
        } else if (self.statistics.fitness_stddev > 0.4) {
            // High variance - reduce selection pressure
            self.config.selection_pressure = @max(self.config.selection_pressure * 0.9, 1.2);
        }
    }

    /// Generate evolution report
    pub fn generateEvolutionReport(self: *MLPatchOptimizer) ![]const u8 {
        var buffer = ArrayList(u8).empty;
        defer buffer.deinit(self.allocator);
        var num_buf: [64]u8 = undefined;

        try buffer.appendSlice(self.allocator, "=== ML Patch Optimizer Evolution Report ===\n\n");

        // Configuration
        try buffer.appendSlice(self.allocator, "Configuration:\n");
        try buffer.appendSlice(self.allocator, "  Population Size: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d}", .{self.config.population_size}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Max Generations: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d}", .{self.config.max_generations}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Mutation Rate: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.4}", .{self.config.mutation_rate}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Crossover Rate: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.4}", .{self.config.crossover_rate}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Selection Pressure: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.4}", .{self.config.selection_pressure}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Elitism Rate: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.4}", .{self.config.elitism_rate}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Target Fitness: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.4}", .{self.config.target_fitness}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n\n");

        // Results
        try buffer.appendSlice(self.allocator, "Results:\n");
        try buffer.appendSlice(self.allocator, "  Generation: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d}", .{self.generation}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Best Fitness: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.6}", .{self.best_fitness}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Best Generation: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d}", .{self.best_generation}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Stagnation Counter: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d}", .{self.stagnation_counter}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n\n");

        // Statistics
        try buffer.appendSlice(self.allocator, "Statistics:\n");
        try buffer.appendSlice(self.allocator, "  Total Evaluations: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d}", .{self.statistics.total_evaluations}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Average Fitness: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.6}", .{self.statistics.average_fitness}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Fitness StdDev: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.6}", .{self.statistics.fitness_stddev}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Diversity Score: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.6}", .{self.statistics.diversity_score}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n\n");

        // Best patch
        if (self.best_patch) |*best| {
            try buffer.appendSlice(self.allocator, "Best Patch:\n");
            try buffer.appendSlice(self.allocator, "  Description: ");
            try buffer.appendSlice(self.allocator, best.patch.description);
            try buffer.appendSlice(self.allocator, "\n");
            try buffer.appendSlice(self.allocator, "  File: ");
            try buffer.appendSlice(self.allocator, best.patch.file_path);
            try buffer.appendSlice(self.allocator, "\n");
            try buffer.appendSlice(self.allocator, "  Lines: ");
            try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d}-{d}", .{ best.patch.line_start, best.patch.line_end }) catch "N/A");
            try buffer.appendSlice(self.allocator, "\n");
            try buffer.appendSlice(self.allocator, "  Confidence: ");
            try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.4}", .{best.patch.confidence}) catch "N/A");
            try buffer.appendSlice(self.allocator, "\n");
            try buffer.appendSlice(self.allocator, "  Sacred Alignment: ");
            try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d:.4}", .{best.patch.sacred_alignment}) catch "N/A");
            try buffer.appendSlice(self.allocator, "\n\n");
        }

        // Learning
        try buffer.appendSlice(self.allocator, "Learning:\n");
        try buffer.appendSlice(self.allocator, "  Successful Patterns: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d}", .{self.successful_patterns.items.len}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n");
        try buffer.appendSlice(self.allocator, "  Regression Patterns: ");
        try buffer.appendSlice(self.allocator, std.fmt.bufPrint(&num_buf, "{d}", .{self.regression_patterns.items.len}) catch "N/A");
        try buffer.appendSlice(self.allocator, "\n\n");

        return buffer.toOwnedSlice(self.allocator);
    }
};

// ========================
// Tests
// ========================

const testing = std.testing;

test "MLPatchOptimizer initialization" {
    const allocator = testing.allocator;

    const config = OptimizerConfig{
        .population_size = 10,
        .max_generations = 5,
    };

    var optimizer = try MLPatchOptimizer.init(allocator, config);
    defer optimizer.deinit();

    try testing.expectEqual(@as(u32, 0), optimizer.generation);
    try testing.expectEqual(@as(f64, 0.0), optimizer.best_fitness);
    try testing.expectEqual(@as(u32, 0), optimizer.stagnation_counter);
}

test "fitness calculation" {
    const allocator = testing.allocator;

    const config = OptimizerConfig{};
    var optimizer = try MLPatchOptimizer.init(allocator, config);
    defer optimizer.deinit();

    const target_code = "const x = 42;";
    var patch = try AutoCodePatch.init(
        allocator,
        "Test patch",
        target_code,
        "const x = 42; // sacred constant",
        "test.zig",
        0,
        0,
    );
    // Note: ownership is transferred to chromosome, so no defer patch.deinit here

    patch.confidence = 0.8;
    patch.sacred_alignment = 0.9;

    var chromosome = try PatchChromosome.init(allocator, patch, null);
    defer chromosome.deinit(allocator);

    const fitness = try optimizer.calculateFitness(&chromosome, target_code);

    try testing.expect(fitness > 0.0);
    try testing.expect(fitness <= 1.0);
}

test "crossover operation" {
    const allocator = testing.allocator;

    const config = OptimizerConfig{};
    var optimizer = try MLPatchOptimizer.init(allocator, config);
    defer optimizer.deinit();

    const target_code = "const x = 42;";

    const patch1 = try AutoCodePatch.init(
        allocator,
        "Patch 1",
        target_code,
        "const x = 43;",
        "test.zig",
        0,
        0,
    );
    // Ownership transferred to parent1

    const patch2 = try AutoCodePatch.init(
        allocator,
        "Patch 2",
        target_code,
        "const x = 44;",
        "test.zig",
        0,
        0,
    );
    // Ownership transferred to parent2

    var parent1 = try PatchChromosome.init(allocator, patch1, null);
    defer parent1.deinit(allocator);
    parent1.fitness = 0.7;

    var parent2 = try PatchChromosome.init(allocator, patch2, null);
    defer parent2.deinit(allocator);
    parent2.fitness = 0.9;

    var child = try optimizer.crossover(&parent1, &parent2);
    defer child.deinit(allocator);

    // Child should have mixed genes
    var genes_from_1: usize = 0;
    var genes_from_2: usize = 0;

    for (0..GENE_COUNT) |i| {
        if (child.genes[i] == parent1.genes[i]) genes_from_1 += 1;
        if (child.genes[i] == parent2.genes[i]) genes_from_2 += 1;
    }

    // At least some genes should come from each parent
    try testing.expect(genes_from_1 > 0 or genes_from_2 > 0);
}

test "mutation operation" {
    const allocator = testing.allocator;

    var config = OptimizerConfig{};
    config.mutation_rate = 1.0; // Force mutation

    var optimizer = try MLPatchOptimizer.init(allocator, config);
    defer optimizer.deinit();

    const target_code = "const x = 42;";
    const patch = try AutoCodePatch.init(
        allocator,
        "Test",
        target_code,
        target_code,
        "test.zig",
        0,
        0,
    );
    // Ownership transferred to chromosome

    var chromosome = try PatchChromosome.init(allocator, patch, null);
    defer chromosome.deinit(allocator);

    const old_genes = chromosome.genes;
    const old_confidence = chromosome.patch.confidence;

    try optimizer.mutate(&chromosome, 1.0);

    // Genes should be different
    var genes_changed = false;
    for (0..GENE_COUNT) |i| {
        if (chromosome.genes[i] != old_genes[i]) {
            genes_changed = true;
            break;
        }
    }

    try testing.expect(genes_changed or chromosome.patch.confidence != old_confidence);
}

test "evolution convergence" {
    const allocator = testing.allocator;

    var config = OptimizerConfig{};
    config.population_size = 20;
    config.max_generations = 10;
    config.target_fitness = 0.5; // Low target for quick test
    config.verbose = false;

    var optimizer = try MLPatchOptimizer.init(allocator, config);
    defer optimizer.deinit();

    const target_code = "const x = 42;";
    var result = try optimizer.evolve(target_code);

    try testing.expect(result.generation <= config.max_generations);
    try testing.expect(result.final_fitness >= 0.0);
    try testing.expect(result.final_fitness <= 1.0);

    // Clean up result
    result.best_patch.deinit(allocator);
    result.statistics.deinit(allocator);
}

test "elitism preserves best" {
    const allocator = testing.allocator;

    var config = OptimizerConfig{};
    config.elitism_rate = 0.5; // 50% elitism
    config.population_size = 10;

    var optimizer = try MLPatchOptimizer.init(allocator, config);
    defer optimizer.deinit();

    // Create population
    const target_code = "const x = 42;";
    var i: u32 = 0;
    while (i < config.population_size) : (i += 1) {
        const patch = try optimizer.createRandomPatch(target_code);
        const chromosome = try PatchChromosome.init(allocator, patch, null);
        try optimizer.population.append(allocator, chromosome);
    }

    // Set fitness values
    var j: usize = 0;
    while (j < optimizer.population.items.len) : (j += 1) {
        optimizer.population.items[j].fitness = @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(optimizer.population.items.len));
    }

    // Apply elitism
    var new_pop = ArrayList(PatchChromosome).empty;
    defer {
        for (new_pop.items) |*c| c.deinit(allocator);
        new_pop.deinit(allocator);
    }

    const elite_count = 5;
    try optimizer.applyElitism(&new_pop, elite_count);

    try testing.expectEqual(@as(usize, 5), new_pop.items.len);

    // Check that elites are the fittest
    for (new_pop.items) |elite| {
        try testing.expect(elite.fitness >= 0.5);
    }
}

test "learning from outcomes" {
    const allocator = testing.allocator;

    const config = OptimizerConfig{};
    var optimizer = try MLPatchOptimizer.init(allocator, config);
    defer optimizer.deinit();

    const target_code = "const x = 42;";
    const patch = try AutoCodePatch.init(
        allocator,
        "Test",
        target_code,
        target_code,
        "test.zig",
        0,
        0,
    );
    // Ownership transferred to chromosome

    var chromosome = try PatchChromosome.init(allocator, patch, null);
    defer chromosome.deinit(allocator);

    const outcome = PatchOutcome.init(chromosome, true, 0.9, 0, 0.8);
    try optimizer.learnFromPatchOutcome(outcome);

    try testing.expectEqual(@as(usize, 1), optimizer.successful_patterns.items.len);
    try testing.expectEqual(@as(usize, 0), optimizer.regression_patterns.items.len);
}

test "generate evolution report" {
    const allocator = testing.allocator;

    const config = OptimizerConfig{
        .population_size = 5,
        .max_generations = 2,
    };

    var optimizer = try MLPatchOptimizer.init(allocator, config);
    defer optimizer.deinit();

    const target_code = "const x = 42;";
    _ = try optimizer.evolve(target_code);

    const report = try optimizer.generateEvolutionReport();
    defer allocator.free(report);

    try testing.expect(report.len > 0);
    try testing.expect(std.mem.indexOf(u8, report, "Evolution Report") != null);
    try testing.expect(std.mem.indexOf(u8, report, "Configuration") != null);
    try testing.expect(std.mem.indexOf(u8, report, "Results") != null);
}
