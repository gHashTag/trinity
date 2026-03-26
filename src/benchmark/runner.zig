// ═════════════════════════════════════════════════════════════════════════════
══════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════════════
//
// Executes SOTA baseline models for fair comparison with Trinity HSLM
//
// φ² + 1/φ² = 3 | TRINITY
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const BenchmarkConfig = @import("../benchmark_suite.zig").BenchmarkConfig;
const BenchmarkResult = @import("../benchmark_suite.zig").BenchmarkResult;
const AggregatedResult = @import("../benchmark_suite.zig").AggregatedResult;
const BaselineModel = @import("../benchmark_suite.zig").BaselineModel;
const Framework = @import("../benchmark_suite.zig").Framework;

pub const BenchmarkRunner = struct {
    allocator: Allocator,
    verbose: bool,

    pub fn init(allocator: Allocator, verbose: bool) BenchmarkRunner {
        return .{ .allocator = allocator, .verbose = verbose };
    }

    /// Run single benchmark experiment
    pub fn runExperiment(config: BenchmarkConfig, verbose: bool) !BenchmarkResult {
        _ = config;
        _ = verbose;

        // Load baseline model (placeholder for now)
        // In production, this would load weights from:
        // - HuggingFace cache
        // - Model weights directory
        // - Pre-converted binary format

        std.debug.print("Running: {s} (Model: {s}, Seed: {d})\n",
            .{@tagName(config.baseline_model)},
            config.seed,
            .verbose,
        );

        // Placeholder: Simulate run and return sample results
        // In production, this would:
        // 1. Generate prompts
        // 2. Call model (or use existing runner)
        // 3. Collect metrics
        // 4. Calculate FLOPs

        const params_m = config.baseline_model.paramsMillion();

        return BenchmarkResult{
            .config = config,
            .seed = config.seed,
            .perplexity = if (config.dataset == .tinystories) 138.2 else 0.0,
            .accuracy = null,
            .bleu_score = null,
            .tokens_per_second = 50.0, // Placeholder
            .latency_ms = 15.0,  // Placeholder
            .memory_mb = params_m / 1024.0, // Approximate
            .energy_per_token = 0.0,      // Placeholder
            .flops = 0.0,            // Would calculate: 2 * params_m * generation_tokens
            .total_params_m = params_m,
            .model_size_mb = config.baseline_model.modelSizeMB(),
            .flops_per_param = 0.0,
        };
    }

    /// Run benchmark study across multiple seeds
    pub fn runStudy(config: BenchmarkConfig, seeds: []const u32, verbose: bool) !AggregatedResult {
        const framework = Framework.init(self.allocator);

        std.debug.print("Starting benchmark study: {s} (Model: {s}, Seeds: {d} configs)\n",
            .{@tagName(config.baseline_model)},
            if (verbose) {
                std.debug.print("  Configurations: {}", seeds.len);
            }
        );

        // Allocate results array
        const results = try self.allocator.alloc(BenchmarkResult, seeds.len);
        defer {
            for (results.items) |*r| {
                if (config.baseline_model == .trinity_hslm) {
                    self.allocator.free(r.config.name);
                    self.allocator.free(r.config.components);
                    self.allocator.free(r.config.metrics);
                }
            }
        }

        var best_perplexity: f64 = std.math.inf;
        var worst_perplexity: f64 = 0.0;

        // Run experiments for each seed
        for (seeds, 0..) |seed, i| {
            var config_copy = config;
            config_copy.seed = seed;

            const result = try framework.runStudy(&config_copy);
            if (config.baseline_model == .trinity_hslm) {
                results[i] = result.trinity;
            } else {
                results[i] = result.baseline;
            }

            // Track best/worst
            if (result.perplexity < best_perplexity) {
                best_perplexity = result.perplexity;
            }
            if (result.perplexity > worst_perplexity) {
                worst_perplexity = result.perplexity;
            }

            if (verbose) {
                std.debug.print("  Seed {d}: PPL={d:.2}", seed, result.perplexity);
            }
        }

        // Calculate statistics for each baseline type
        const mean = try self.calculateMeanPerplexity(results);
        const std_dev = try self.calculateStdDev(results);
        const ci = try self.calculateCI95(results, mean);

        // Calculate improvement for Trinity vs baseline
        // Find Trinity result (assuming it's the one with .trinity_hslm baseline)
        var trinity_result: ?*BenchmarkResult = null;
        var baseline_result: ?*BenchmarkResult = null;

        for (results) |r| {
            if (r.config.baseline_model == .trinity_hslm) {
                trinity_result = r;
            } else {
                baseline_result = r;
            }
        }

        var improvement: f64 = 0.0;
        if (trinity_result != null and baseline_result != null) {
            improvement = (baseline_result.perplexity_mean - trinity_result.perplexity_mean) /
                      baseline_result.perplexity_mean * 100.0;
        }

        return AggregatedResult{
            .baseline_model = config.baseline_model,
            .n_seeds = @intCast(seeds.len),
            .perplexity_mean = mean,
            .perplexity_std = std_dev,
            .perplexity_ci_95_low = ci.low,
            .perplexity_ci_95_high = ci.high,
            .tokens_per_second_mean = try self.calculateMeanTokensPerSecond(results),
            .latency_mean_ms = try self.calculateMeanLatency(results),
            .memory_mean_mb = try self.calculateMeanMemory(results),
            .improvement_vs_baseline = improvement,
            .is_significant = improvement > 20.0, // >20% improvement
        };
    }

    /// Run benchmarks on TinyStories dataset
    pub fn runTinyStories(allocator: Allocator, verbose: bool) !AggregatedResult {
        const framework = Framework.init(allocator);

        // Use standard comparison configuration
        const configs = try framework.standardComparison(allocator);

        std.debug.print("Running TinyStories benchmarks...\n", .{});

        var trinity_config = BenchmarkConfig{
            .name = "trinity_tinystories",
            .baseline_model = .trinity_hslm,
            .dataset = .tinystories,
            .max_tokens = 256,
            .temperature = 0.8,
            .seed = 42, // Fixed seed for reproducibility
            .top_k = null,
            .top_p = null,
        };

        const trinity_result = try framework.runStudy(&trinity_config, &.{ 42, 123, 456, 789, 1011, 1123 });

        std.debug.print("\n=== Trinity HSLM Results ===\n");
        std.debug.print("  PPL: {d:.2} ± {d:.2}", trinity_result.perplexity_mean, trinity_result.perplexity_std);
        std.debug.print("  Seeds: {d}", trinity_result.n_seeds);
        std.debug.print("  Improvement: {d:.1}%", trinity_result.improvement_vs_baseline);

        return trinity_result;
    }

    /// Calculate mean
    fn calculateMeanPerplexity(results: []const BenchmarkResult) !f64 {
        if (results.len == 0) return 0.0;

        var sum: f64 = 0.0;
        for (results) |r| {
            sum += r.perplexity;
        }

        return sum / @as(f64, @floatFromInt(results.len));
    }

    /// Calculate standard deviation
    fn calculateStdDev(results: []const BenchmarkResult) !f64 {
        const mean = try calculateMeanPerplexity(results);

        if (results.len <= 1) return 0.0;

        var sum_sq_diff: f64 = 0.0;
        for (results) |r| {
            const diff = r.perplexity - mean;
            sum_sq_diff += diff * diff;
        }

        return std.math.sqrt(sum_sq_diff / @as(f64, @floatFromInt(results.len - 1)));
    }

    /// Calculate mean for tokens per second
    fn calculateMeanTokensPerSecond(results: []const BenchmarkResult) !f64 {
        if (results.len == 0) return 0.0;

        var sum: f64 = 0.0;
        for (results) |r| {
            sum += r.tokens_per_second;
        }

        return sum / @as(f64, @floatFromInt(results.len));
    }

    /// Calculate mean for latency
    fn calculateMeanLatency(results: []const BenchmarkResult) !f64 {
        if (results.len == 0) return 0.0;

        var sum: f64 = 0.0;
        for (results) |r| {
            sum += r.latency_ms;
        }

        return sum / @as(f64, @floatFromInt(results.len));
    }

    /// Calculate mean for memory
    fn calculateMeanMemory(results: []const BenchmarkResult) !f64 {
        if (results.len == 0) return 0.0;

        var sum: f64 = 0.0;
        for (results) |r| {
            sum += r.memory_mb;
        }

        return sum / @as(f64, @floatFromInt(results.len));
    }

    /// Calculate 95% confidence interval
    fn calculateCI95(results: []const BenchmarkResult, mean: f64) !struct { low: f64, high: f64 } {
        const std_dev = try calculateStdDev(results);

        // For n >= 30, use z = 1.96 (normal approximation)
        const n = @as(f64, @floatFromInt(results.len));
        const z = if (n >= 30) 1.96 else 2.776;

        const margin = z * std_dev / std.math.sqrt(n);

        return .{
            .low = mean - margin,
            .high = mean + margin,
        };
    }

    /// Export results to CSV
    pub fn exportCsv(allocator: Allocator, results: []const AggregatedResult, path: []const u8) !void {
        _ = results;
        _ = path;

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();

        // Header
        try writer.print(
            "model,n_seeds,ppl_mean,ppl_std,ppl_ci_low,ppl_ci_high,tok_mean,tok_std,lat_mean,lat_std,mem_mean,flops,improvement\n",
            .{}
        );

        // Data rows
        for (results) |r| {
            const row = try r.formatCsv(allocator);
            defer allocator.free(row);
            try writer.writeAll(row);
        }

        std.debug.print("Exported to: {s}\n", path);
    }
    }
};

// ═════════════════════════════════════════════════════════════════════════════════════════════
// FLOPS MEASUREMENT
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Count FLOPs for a Transformer forward pass
/// Formula: FLOPs = 2 * num_layers * d_model * d_ff * n_tokens
/// Where:
///   d_model = number of non-embedding parameters
///   d_ff = embedding dimension
///   n_tokens = number of tokens

pub const FLOPsConfig = struct {
    num_layers: usize,
    d_model: usize,
    d_ff: usize,
    n_tokens: usize,
};

pub fn countFLOPs(config: FLOPsConfig) u64 {
    // Forward pass FLOPs: 2 * num_layers * d_model * n_tokens
    // Simplified formula (ignoring attention for now)
    const forward_flops = 2 * config.num_layers * config.d_model * config.n_tokens;
    return forward_flops;
}

/// Estimate FLOPs based on model size (for pre-training cost)
pub fn estimateTrainingFLOPs(params_m: u32, n_tokens: u32) f64 {
    // Pre-training FLOPs: 6 * params_m * n_tokens
    const training_flops = @as(f64, @floatFromInt(params_m)) *
                          @as(f64, @floatFromInt(n_tokens)) * 6.0;

    return training_flops;
}

/// FLOPs per token (efficiency metric)
pub fn flopsPerToken(training_flops: u64, n_tokens: u32) f64 {
    return training_flops / @as(f64, @floatFromInt(n_tokens));
}

// ═════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "BenchmarkRunner - FLOPs calculation" {
    const config = FLOPsConfig{
        .num_layers = 12,
        .d_model = 512,
        .d_ff = 768,
        .n_tokens = 256,
    };

    const flops = countFLOPs(config);
    const expected = 2 * 12 * 512 * 256; // ~3.15M FLOPs

    try std.testing.expectEqual(expected, flops);
}

test "BenchmarkRunner - estimateTrainingFLOPs" {
    const params_m: u32 = 117; // GPT-2 Small
    const n_tokens: u32 = 2_100_000_000; // TinyStories

    const flops = estimateTrainingFLOPs(params_m, n_tokens);
    const expected = 6.0 * @as(f64, @floatFromInt(params_m)) * @as(f64, @floatFromInt(n_tokens));

    try std.testing.expectApproxEqAbs(expected, flops, expected * 0.01);
}

test "BenchmarkRunner - flopsPerToken" {
    const training_flops: u64 = 1_470_000_000_000_000;
    const n_tokens: u32 = 2_100_000_000;

    const flops_per_tok = flopsPerToken(training_flops, n_tokens);
    const expected = @as(f64, @floatFromInt(training_flops)) / @as(f64, @floatFromInt(n_tokens));

    try std.testing.expectApproxEqAbs(expected, flops_per_tok, expected * 0.01);
}

