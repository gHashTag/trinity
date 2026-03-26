// ==============================================
// BENCHMARK RUNNER
// ==============================================
//
// Executes SOTA baseline models for fair comparison with Trinity HSLM
//
// φ² + 1/φ² = 3 | TRINITY
// ==============================================

const std = @import("std");
const Allocator = std.mem.Allocator;

const BenchmarkConfig = @import("benchmark_suite").BenchmarkConfig;
const BenchmarkResult = @import("benchmark_suite").BenchmarkResult;
const AggregatedResult = @import("benchmark_suite").AggregatedResult;
const BaselineModel = @import("benchmark_suite").BaselineModel;
const Framework = @import("benchmark_suite").Framework;

pub const BenchmarkRunner = struct {
    allocator: Allocator,
    verbose: bool,

    pub fn init(allocator: Allocator, verbose: bool) BenchmarkRunner {
        return .{ .allocator = allocator, .verbose = verbose };
    }

    /// Run single benchmark experiment
    pub fn runExperiment(self: *const BenchmarkRunner, config: BenchmarkConfig) !BenchmarkResult {
        _ = self;

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
            .tokens_per_second = 50.0,
            .latency_ms = 15.0,
            .memory_mb = @as(f64, @floatFromInt(params_m)) / 1024.0,
            .energy_per_token = 0.0,
            .flops = 0.0,
            .total_params_m = params_m,
            .model_size_mb = config.baseline_model.modelSizeMB(),
            .flops_per_param = 0.0,
        };
    }

    /// Calculate mean for perplexity
    fn calculateMeanPerplexity(results: []const BenchmarkResult) !f64 {
        if (results.len == 0) return 0.0;

        var sum: f64 = 0.0;
        for (results) |r| {
            sum += r.perplexity;
        }

        return sum / @as(f64, @floatFromInt(results.len));
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

    /// Calculate 95% confidence interval
    fn calculateCI95(results: []const BenchmarkResult, mean: f64) !struct { low: f64, high: f64 } {
        const std_dev = try calculateStdDev(results);

        const n = @as(f64, @floatFromInt(results.len));
        const z = if (n >= 30) 1.96 else 2.776;

        const margin = z * std_dev / std.math.sqrt(n);

        return .{
            .low = mean - margin,
            .high = mean + margin,
        };
    }

    /// Export results to CSV
    pub fn exportCsv(_self: *const BenchmarkRunner, results: []const AggregatedResult, path: []const u8) !void {
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
            const row = try r.formatCsv(_self.allocator);
            defer _self.allocator.free(row);
            try writer.writeAll(row);
        }

        std.debug.print("Exported to: {s}\n", path);
    }
};

// ==============================================
// FLOPS MEASUREMENT
// ==============================================

pub const FLOPsConfig = struct {
    num_layers: usize,
    d_model: usize,
    d_ff: usize,
    n_tokens: usize,
};

pub fn countFLOPs(config: FLOPsConfig) u64 {
    const forward_flops = 2 * config.num_layers * config.d_model * config.n_tokens;
    return forward_flops;
}

pub fn estimateTrainingFLOPs(params_m: u32, n_tokens: u32) f64 {
    const training_flops = @as(f64, @floatFromInt(params_m)) *
                          @as(f64, @floatFromInt(n_tokens)) * 6.0;
    return training_flops;
}

pub fn flopsPerToken(training_flops: u64, n_tokens: u32) f64 {
    return @as(f64, @floatFromInt(training_flops)) / @as(f64, @floatFromInt(n_tokens));
}

// ==============================================
// TESTS
// ==============================================

test "BenchmarkRunner - FLOPs calculation" {
    const config = FLOPsConfig{
        .num_layers = 12,
        .d_model = 512,
        .d_ff = 768,
        .n_tokens = 256,
    };

    const flops = countFLOPs(config);
    const expected: u64 = 2 * 12 * 512 * 256;

    try std.testing.expectEqual(expected, flops);
}

test "BenchmarkRunner - estimateTrainingFLOPs" {
    const params_m: u32 = 117;
    const n_tokens: u32 = 2_100_000_000;

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
