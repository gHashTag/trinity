// ═══════════════════════════════════════════════════════════════════════════
// BENCHMARK SUITE IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════
// Benchmark Suite for Trinity S³AI Research
// Implements SOTA baseline models for fair comparison
//
// Generated from: specs/tri-lang/benchmark.tri
//
// φ² + 1/φ² = 3 | TRINITY
// ═════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const BenchmarkSuite = @This();

// ═════════════════════════════════════════════════════════════════════════════════════════
// TYPES
// ═════════════════════════════════════════════════════════════════════════════════════════

pub const BaselineModel = union(enum) {
    gpt2_small,
    phi3_mini,
    tinyllama,
    gpt2_base,
    llama7b,
    mistral7b,
    gpt2_xl,
    mixtral,
    phi3_small,
    ternary_transformer,
    trinity_hslm,

    pub fn format(self: BaselineModel, allocator: Allocator) ![]const u8 {
        return switch (self) {
            .gpt2_small => std.fmt.allocPrint(allocator, "GPT-2 Small", .{}),
            .phi3_mini => std.fmt.allocPrint(allocator, "Phi-3 Mini", .{}),
            .tinyllama => std.fmt.allocPrint(allocator, "TinyLLaMA", .{}),
            .gpt2_base => std.fmt.allocPrint(allocator, "GPT-2 Base", .{}),
            .llama7b => std.fmt.allocPrint(allocator, "LLaMA-7B", .{}),
            .mistral7b => std.fmt.allocPrint(allocator, "Mistral 7B", .{}),
            .gpt2_xl => std.fmt.allocPrint(allocator, "GPT-2 XL", .{}),
            .mixtral => std.fmt.allocPrint(allocator, "Mixtral 8x7B", .{}),
            .phi3_small => std.fmt.allocPrint(allocator, "Phi-3 Small", .{}),
            .ternary_transformer => std.fmt.allocPrint(allocator, "Ternary Transformer", .{}),
            .trinity_hslm => std.fmt.allocPrint(allocator, "Trinity HSLM", .{}),
        };
    }

    pub fn paramsMillion(self: BaselineModel) u32 {
        return switch (self) {
            .gpt2_small => 117,
            .phi3_mini => 4,
            .tinyllama => 15,
            .gpt2_base => 770,
            .llama7b => 7000,
            .mistral7b => 7000,
            .gpt2_xl => 1558,
            .mixtral => 47000,
            .phi3_small => 7000,
            .ternary_transformer => 117, // Approx same as GPT-2 Small
            .trinity_hslm => 2, // 1.95M params
        };
    }

    pub fn modelSizeMB(self: BaselineModel) f32 {
        return switch (self) {
            .gpt2_small => 500, // ~500MB
            .phi3_mini => 8,
            .tinyllama => 60,
            .gpt2_base => 3000,
            .llama7b => 13000,
            .mistral7b => 14000,
            .gpt2_xl => 6000,
            .mixtral => 87000,
            .phi3_small => 14000,
            .ternary_transformer => 250, // Ternary encoding saves space
            .trinity_hslm => 8, // Very small due to sparsity
        };
    }

    pub fn flopsPerToken(self: BaselineModel) f64 {
        // Approximate FLOPs per token (2 * params for forward pass)
        const params_m = self.paramsMillion();
        const params = @as(f64, @floatFromInt(params_m)) * 1e6;
        return 2.0 * params;
    }

    pub fn isTernary(self: BaselineModel) bool {
        return switch (self) {
            .ternary_transformer, .trinity_hslm => true,
            else => false,
        };
    }
};

pub const Dataset = union(enum) {
    tinystories,
    wiktext,
    custom,

    pub fn format(self: Dataset, allocator: Allocator) ![]const u8 {
        return switch (self) {
            .tinystories => std.fmt.allocPrint(allocator, "TinyStories", .{}),
            .wiktext => std.fmt.allocPrint(allocator, "WikiText", .{}),
            .custom => std.fmt.allocPrint(allocator, "Custom", .{}),
        };
    }

    pub fn tokensBillions(self: Dataset) f64 {
        return switch (self) {
            .tinystories => 2.1,
            .wiktext => 5.0,
            .custom => 0.0, // User-provided
        };
    }
};

pub const BenchmarkConfig = struct {
    name: []const u8,
    baseline_model: BaselineModel,
    dataset: Dataset,
    max_tokens: usize,
    temperature: f64,
    top_k: ?usize,
    top_p: ?f64,
    seed: u32,

    pub fn format(self: *const BenchmarkConfig, allocator: Allocator) ![]const u8 {
        const model_name = try self.baseline_model.format(allocator);
        defer allocator.free(model_name);

        const dataset_name = try self.dataset.format(allocator);
        defer allocator.free(dataset_name);

        return std.fmt.allocPrint(allocator,
            \\BenchmarkConfig("{s}"):
            \\  Model: {s} ({d}M params)
            \\  Dataset: {s} ({d:.1}B tokens)
            \\  Max Tokens: {d}
            \\  Temperature: {d:.2}
            \\  Seed: {d}
        , .{
            self.name,
            model_name,
            self.baseline_model.paramsMillion(),
            dataset_name,
            self.dataset.tokensBillions(),
            self.max_tokens,
            self.temperature,
            self.seed,
        });
    }
};

pub const BenchmarkResult = struct {
    config: BenchmarkConfig,
    seed: u32,
    perplexity: f64,
    accuracy: ?f64,
    bleu_score: ?f64,
    tokens_per_second: f64,
    latency_ms: f64,
    memory_mb: f64,
    energy_per_token: f64,
    flops: f64,
    total_params_m: u32,
    model_size_mb: f32,
    flops_per_param: f32,

    pub fn formatCsv(self: *const BenchmarkResult, allocator: Allocator) ![]const u8 {
        const model_name = try self.config.baseline_model.format(allocator);
        defer allocator.free(model_name);

        return std.fmt.allocPrint(allocator, "{s},{s},{d},{d:.4},{d:.2},{d:.2},{d:.2},{d:.6},{d:.2},{d:.2},{d:.1},{d}\n", .{
            self.config.name,
            model_name,
            self.seed,
            self.perplexity,
            self.tokens_per_second,
            self.latency_ms,
            self.memory_mb,
            self.energy_per_token,
            self.flops,
            self.total_params_m,
            self.model_size_mb,
            self.flops_per_param,
        });
    }
};

pub const AggregatedResult = struct {
    baseline_model: BaselineModel,
    n_seeds: usize,
    perplexity_mean: f64,
    perplexity_std: f64,
    perplexity_ci_95_low: f64,
    perplexity_ci_95_high: f64,
    tokens_per_second_mean: f64,
    tokens_per_second_std: f64,
    latency_mean_ms: f64,
    memory_mean_mb: f64,
    flops_mean: f64,
    improvement_vs_baseline: f64,
    is_significant: bool,

    pub fn formatCsv(self: *const AggregatedResult, allocator: Allocator) ![]const u8 {
        const model_name = try self.baseline_model.format(allocator);
        defer allocator.free(model_name);

        return std.fmt.allocPrint(allocator, "{s},{d},{d:.4},{d:.4},{d:.4},{d:.4},{d:.2},{d:.2},{d:.2},{d:.2},{d:.2},{d:.1}\n", .{
            model_name,
            self.n_seeds,
            self.perplexity_mean,
            self.perplexity_std,
            self.perplexity_ci_95_low,
            self.perplexity_ci_95_high,
            self.tokens_per_second_mean,
            self.tokens_per_second_std,
            self.latency_mean_ms,
            self.memory_mean_mb,
            self.flops_mean,
            self.improvement_vs_baseline,
        });
    }

    pub fn formatLatex(self: *const AggregatedResult, allocator: Allocator) ![]const u8 {
        const model_name = try self.baseline_model.format(allocator);
        defer allocator.free(model_name);

        // Format: Model & PPL & tok/s & Latency (ms) & Params (M) \\ (LaTeX line break)
        return std.fmt.allocPrint(allocator, "{s} & {d:.2} $\\pm$ {d:.2} & {d:.1} $\\pm$ {d:.1} & {d:.2} $\\pm$ {d:.2} & {d} \\\\", .{
            model_name,
            self.perplexity_mean,
            self.perplexity_std,
            self.tokens_per_second_mean,
            self.tokens_per_second_std,
            self.latency_mean_ms,
            5.0, // Placeholder std
            self.baseline_model.paramsMillion(),
        });
    }
};

pub const SummaryReport = struct {
    baseline_model: BaselineModel,
    n_benchmarks: usize,
    avg_perplexity: f64,
    avg_tokens_per_second: f64,
    avg_latency_ms: f64,
    avg_memory_mb: f64,
    avg_flops: f64,
    best_perplexity: f64,
    worst_perplexity: f64,
    recommendation: []const u8,
};

// ═════════════════════════════════════════════════════════════════════════════════════════
// STATISTICAL FUNCTIONS
// ═════════════════════════════════════════════════════════════════════════════════════════

fn mean(values: []const f64) f64 {
    if (values.len == 0) return 0.0;
    var sum: f64 = 0.0;
    for (values) |v| sum += v;
    return sum / @as(f64, @floatFromInt(values.len));
}

fn stdDev(values: []const f64, mu: f64) f64 {
    if (values.len <= 1) return 0.0;
    var sum_sq_diff: f64 = 0.0;
    for (values) |v| {
        const diff = v - mu;
        sum_sq_diff += diff * diff;
    }
    return std.math.sqrt(sum_sq_diff / @as(f64, @floatFromInt(values.len - 1)));
}

fn confidenceInterval95(values: []const f64, mu: f64, sigma: f64) struct { low: f64, high: f64 } {
    const n = @as(f64, @floatFromInt(values.len));
    const z = if (n >= 30) 1.96 else if (n >= 10) 2.262 else 2.776;
    const margin = z * sigma / std.math.sqrt(n);
    return .{ .low = mu - margin, .high = mu + margin };
}

fn pairedTTest(values_a: []const f64, values_b: []const f64) f64 {
    if (values_a.len != values_b.len or values_a.len < 2) return 1.0;
    const n = @as(f64, @floatFromInt(values_a.len));

    var sum_diff: f64 = 0.0;
    var sum_sq_diff: f64 = 0.0;
    for (values_a, values_b) |a, b| {
        const diff = a - b;
        sum_diff += diff;
        sum_sq_diff += diff * diff;
    }

    const mean_diff = sum_diff / n;
    const var_diff = (sum_sq_diff - n * mean_diff * mean_diff) / (n - 1.0);

    if (var_diff <= 0.0) return 1.0;

    const t_stat = mean_diff / std.math.sqrt(var_diff / n);
    const abs_t = if (t_stat < 0) -t_stat else t_stat;

    // Simplified p-value approximation
    if (abs_t >= 3.0) return 0.01;
    if (abs_t >= 2.0) return 0.05;
    if (abs_t >= 1.0) return 0.3;
    return 0.5;
}

// ═════════════════════════════════════════════════════════════════════════════════════════
// FRAMEWORK API
// ═════════════════════════════════════════════════════════════════════════════════════════

pub const Framework = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Framework {
        return .{ .allocator = allocator };
    }

    /// Run single benchmark (placeholder for actual implementation)
    pub fn runBenchmark(self: *const Framework, config: BenchmarkConfig) !BenchmarkResult {
        _ = self;

        // Placeholder: In production, this would:
        // 1. Load model weights
        // 2. Initialize RNG with seed
        // 3. Run generation
        // 4. Collect metrics

        const params_m = config.baseline_model.paramsMillion();
        const model_size_mb = config.baseline_model.modelSizeMB();
        const flops = config.baseline_model.flopsPerToken();

        return BenchmarkResult{
            .config = config,
            .seed = config.seed,
            .perplexity = 0.0,
            .accuracy = null,
            .bleu_score = null,
            .tokens_per_second = 0.0,
            .latency_ms = 0.0,
            .memory_mb = 0.0,
            .energy_per_token = 0.0,
            .flops = flops,
            .total_params_m = params_m,
            .model_size_mb = model_size_mb,
            .flops_per_param = 0.0,
        };
    }

    /// Run benchmark study across multiple seeds
    pub fn runStudy(self: *const Framework, config: BenchmarkConfig, seeds: []const u32) !AggregatedResult {
        const results = try self.allocator.alloc(BenchmarkResult, seeds.len);
        defer self.allocator.free(results);

        // Run experiments for each seed
        for (seeds, 0..) |seed, i| {
            var config_copy = config;
            config_copy.seed = seed;
            results[i] = try self.runBenchmark(&config_copy);
        }

        // Extract metric arrays
        const perplexities = try self.allocator.alloc(f64, seeds.len);
        defer self.allocator.free(perplexities);
        const tps = try self.allocator.alloc(f64, seeds.len);
        defer self.allocator.free(tps);
        const latencies = try self.allocator.alloc(f64, seeds.len);
        defer self.allocator.free(latencies);
        const memories = try self.allocator.alloc(f64, seeds.len);
        defer self.allocator.free(memories);

        for (results, 0..) |r, i| {
            perplexities[i] = r.perplexity;
            tps[i] = r.tokens_per_second;
            latencies[i] = r.latency_ms;
            memories[i] = r.memory_mb;
        }

        // Compute statistics
        const ppl_mu = mean(perplexities);
        const ppl_sigma = stdDev(perplexities, ppl_mu);
        const ppl_ci = confidenceInterval95(perplexities, ppl_mu, ppl_sigma);

        const tps_mu = mean(tps);
        const tps_sigma = stdDev(tps, tps_mu);

        const lat_mu = mean(latencies);
        const mem_mu = mean(memories);
        const flops_mu = results[0].flops;

        return AggregatedResult{
            .baseline_model = config.baseline_model,
            .n_seeds = @intCast(seeds.len),
            .perplexity_mean = ppl_mu,
            .perplexity_std = ppl_sigma,
            .perplexity_ci_95_low = ppl_ci.low,
            .perplexity_ci_95_high = ppl_ci.high,
            .tokens_per_second_mean = tps_mu,
            .tokens_per_second_std = tps_sigma,
            .latency_mean_ms = lat_mu,
            .memory_mean_mb = mem_mu,
            .flops_mean = flops_mu,
            .improvement_vs_baseline = 0.0,
            .is_significant = false,
        };
    }

    /// Compare Trinity HSLM with baseline
    pub fn compareWithBaseline(self: *const Framework, trinity_config: BenchmarkConfig, baseline_config: BenchmarkConfig, seeds: []const u32) !struct { trinity: AggregatedResult, baseline: AggregatedResult, comparison: f64, significant: bool } {
        const trinity_result = try self.runStudy(trinity_config, seeds);
        const baseline_result = try self.runStudy(baseline_config, seeds);

        // Calculate improvement
        const improvement = (baseline_result.perplexity_mean - trinity_result.perplexity_mean) /
            baseline_result.perplexity_mean * 100.0;

        // Run paired t-test
        const trinity_ppls = try self.allocator.alloc(f64, seeds.len);
        defer self.allocator.free(trinity_ppls);
        const baseline_ppls = try self.allocator.alloc(f64, seeds.len);
        defer self.allocator.free(baseline_ppls);

        // Fill with placeholder values (would be real in production)
        for (0..seeds.len) |i| {
            trinity_ppls[i] = trinity_result.perplexity_mean;
            baseline_ppls[i] = baseline_result.perplexity_mean;
        }

        const p_value = pairedTTest(trinity_ppls, baseline_ppls);
        const is_significant = p_value < 0.05;

        return .{
            .trinity = trinity_result,
            .baseline = baseline_result,
            .comparison = improvement,
            .significant = is_significant,
        };
    }

    /// Export results to CSV
    pub fn exportCsv(self: *const Framework, results: []const AggregatedResult, path: []const u8) !void {
        _ = self;

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();

        // Header
        try writer.print("model,n_seeds,ppl_mean,ppl_std,ppl_ci_low,ppl_ci_high,tps_mean,tps_std,latency_ms,memory_mb,flops,improvement\n", .{});

        // Data rows
        for (results) |r| {
            const row = try r.formatCsv(self.allocator);
            defer self.allocator.free(row);
            try writer.writeAll(row);
        }
    }

    /// Generate publication-ready LaTeX table
    pub fn generateLatexTable(self: *const Framework, results: []const AggregatedResult) ![]const u8 {
        var table = std.ArrayList(u8).init(self.allocator);

        try table.appendSlice(
            \\% Benchmark Results
            \\% Generated by Trinity S³AI Benchmark Suite
            \\\\begin{table}[t]
            \\  \\centering
            \\  \\caption{Benchmark Results: Trinity HSLM vs SOTA Baselines}
            \\  \\label{tab:benchmark}
            \\  \\begin{tabular}{lccccc}
            \\    \\toprule
            \\    Model & PPL & tok/s & Latency (ms) & Params (M) \\\\
            \\    \\midrule
        );

        for (results) |r| {
            const row = try r.formatLatex(self.allocator);
            defer self.allocator.free(row);
            try table.appendSlice(row);
        }

        try table.appendSlice(
            \\    \\bottomrule
            \\  \\end{tabular}
            \\\\end{table}
        );

        return table.toOwnedSlice();
    }
};

// ═════════════════════════════════════════════════════════════════════════════════════════
// STANDARD BENCHMARK CONFIGURATIONS
// ═════════════════════════════════════════════════════════════════════════════════════════

pub const standardConfigs = struct {
    pub fn quickValidation(allocator: Allocator) ![]const BenchmarkConfig {
        const configs = try allocator.alloc(BenchmarkConfig, 3);

        configs[0] = .{
            .name = "gpt2_small_quick",
            .baseline_model = .gpt2_small,
            .dataset = .tinystories,
            .max_tokens = 256,
            .temperature = 1.0,
            .top_k = null,
            .top_p = null,
            .seed = 42,
        };

        configs[1] = .{
            .name = "phi3_mini_quick",
            .baseline_model = .phi3_mini,
            .dataset = .tinystories,
            .max_tokens = 256,
            .temperature = 1.0,
            .top_k = null,
            .top_p = null,
            .seed = 42,
        };

        configs[2] = .{
            .name = "tinyllama_quick",
            .baseline_model = .tinyllama,
            .dataset = .tinystories,
            .max_tokens = 256,
            .temperature = 1.0,
            .top_k = null,
            .top_p = null,
            .seed = 42,
        };

        return configs;
    }

    pub fn standardComparison(allocator: Allocator) ![]const BenchmarkConfig {
        const models = [_]BaselineModel{
            .gpt2_small,
            .phi3_mini,
            .tinyllama,
            .trinity_hslm,
        };

        const seeds = [_]u32{ 42, 123, 456, 789, 1011 };

        const configs = try allocator.alloc(BenchmarkConfig, models.len * seeds.len);

        for (models, 0..) |model, i| {
            for (seeds, 0..) |seed, j| {
                const idx = i * seeds.len + j;
                configs[idx] = .{
                    .name = try std.fmt.allocPrint(allocator, "{s}_seed{d}", .{ @tagName(model), seed }),
                    .baseline_model = model,
                    .dataset = .tinystories,
                    .max_tokens = 512,
                    .temperature = 0.8,
                    .top_k = null,
                    .top_p = null,
                    .seed = seed,
                };
            }
        }

        return configs;
    }
};

// ═════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════

test "BenchmarkSuite - BaselineModel properties" {
    const gpt2_small = BaselineModel.gpt2_small;

    try std.testing.expectEqual(@as(u32, 117), gpt2_small.paramsMillion());
    try std.testing.expectEqual(@as(f32, 500), gpt2_small.modelSizeMB());

    const trinity = BaselineModel.trinity_hslm;
    try std.testing.expectEqual(@as(u32, 2), trinity.paramsMillion());
    try std.testing.expectEqual(@as(f32, 8), trinity.modelSizeMB());
    try std.testing.expect(trinity.isTernary());
}

test "BenchmarkSuite - Statistical functions" {
    const values = [_]f64{ 100.0, 110.0, 105.0, 115.0, 108.0 };

    const mu = mean(&values);
    try std.testing.expectApproxEqAbs(@as(f64, 107.6), mu, 0.1);

    const sigma = stdDev(&values, mu);
    try std.testing.expectApproxEqAbs(@as(f64, 5.5), sigma, 0.2);
}

test "BenchmarkSuite - Confidence interval" {
    const values = [_]f64{ 100.0, 110.0, 105.0, 115.0, 108.0 };
    const mu = mean(&values);
    const sigma = stdDev(&values, mu);
    const ci = confidenceInterval95(&values, mu, sigma);

    try std.testing.expect(ci.low < mu);
    try std.testing.expect(ci.high > mu);
}

test "BenchmarkSuite - Quick validation configs" {
    const allocator = std.testing.allocator;

    const configs = try standardConfigs.quickValidation(allocator);
    defer {
        for (configs) |c| {
            allocator.free(c.name);
        }
        allocator.free(configs);
    }

    try std.testing.expectEqual(@as(usize, 3), configs.len);
    try std.testing.expectEqual(BaselineModel.gpt2_small, configs[0].baseline_model);
}

test "BenchmarkSuite - AggregatedResult formatting" {
    const allocator = std.testing.allocator;

    const result = AggregatedResult{
        .baseline_model = .trinity_hslm,
        .n_seeds = 5,
        .perplexity_mean = 105.7,
        .perplexity_std = 3.8,
        .perplexity_ci_95_low = 102.5,
        .perplexity_ci_95_high = 108.9,
        .tokens_per_second_mean = 1250.0,
        .tokens_per_second_std = 50.0,
        .latency_mean_ms = 12.5,
        .memory_mean_mb = 450.0,
        .flops_mean = 4e9,
        .improvement_vs_baseline = 23.5,
        .is_significant = true,
    };

    const csv = try result.formatCsv(allocator);
    defer allocator.free(csv);

    try std.testing.expect(csv.len > 0);
}

test "BenchmarkSuite - LaTeX table generation" {
    const allocator = std.testing.allocator;

    const framework = Framework.init(allocator);

    const results = [_]AggregatedResult{.{
        .baseline_model = .trinity_hslm,
        .n_seeds = 5,
        .perplexity_mean = 105.7,
        .perplexity_std = 3.8,
        .perplexity_ci_95_low = 102.5,
        .perplexity_ci_95_high = 108.9,
        .tokens_per_second_mean = 1250.0,
        .tokens_per_second_std = 50.0,
        .latency_mean_ms = 12.5,
        .memory_mean_mb = 450.0,
        .flops_mean = 4e9,
        .improvement_vs_baseline = 23.5,
        .is_significant = true,
    }};

    const latex = try framework.generateLatexTable(&results);
    defer allocator.free(latex);

    try std.testing.expect(latex.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, latex, "\\begin{table}") != null);
}
