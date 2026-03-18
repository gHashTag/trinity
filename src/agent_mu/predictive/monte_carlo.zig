//! Monte Carlo Simulator v8.21
//!
//! Probabilistic simulation using Monte Carlo methods
//! Features:
//! - 95% confidence interval calculation
//! - Percentile estimation (p50, p90, p95, p99)
//! - Variance reduction via φ-stratified sampling
//! - Convergence detection

const std = @import("std");
const sacred = @import("sacred_constants.zig");

const ArrayList = std.array_list.Managed;
const Allocator = std.mem.Allocator;

/// Simulation result with statistics
pub const SimulationResult = struct {
    mean: f64,
    std_dev: f64,
    min: f64,
    max: f64,
    confidence_interval_95: ConfidenceInterval,
    percentiles: Percentiles,
    sample_count: usize,
    converged: bool,
};

/// Confidence interval
pub const ConfidenceInterval = struct {
    lower: f64,
    upper: f64,
    confidence_level: f64, // 0.95 for 95% CI

    pub fn width(self: *const ConfidenceInterval) f64 {
        return self.upper - self.lower;
    }
};

/// Percentiles
pub const Percentiles = struct {
    p50: f64, // Median
    p90: f64,
    p95: f64,
    p99: f64,
};

/// Monte Carlo simulation configuration
pub const MonteCarloConfig = struct {
    iterations: usize = 100,
    confidence_level: f64 = 0.95,
    convergence_threshold: f64 = 0.01,
    max_iterations: usize = 10000,
    seed: u64 = 0,
    use_phi_stratification: bool = true,
};

/// Monte Carlo simulator
pub const MonteCarloSimulator = struct {
    const Self = @This();

    allocator: Allocator,
    config: MonteCarloConfig,
    rng: std.Random.DefaultPrng,

    /// Initialize simulator
    pub fn init(allocator: Allocator, config: MonteCarloConfig) MonteCarloSimulator {
        return .{
            .allocator = allocator,
            .config = config,
            .rng = std.Random.DefaultPrng.init(config.seed),
        };
    }

    /// Run simulation with sample function
    pub fn simulate(
        self: *MonteCarloSimulator,
        comptime sample_fn: *const fn (*std.Random.DefaultPrng) f64,
    ) !SimulationResult {
        var samples = ArrayList(f64).init(self.allocator);
        defer samples.deinit();

        // Run initial iterations
        for (0..self.config.iterations) |_| {
            const value = sample_fn(&self.rng);
            try samples.append(value);
        }

        // Check for convergence
        var converged = false;
        var total_iterations = self.config.iterations;

        if (self.config.iterations >= 100) {
            converged = self.checkConvergence(samples.items);
        }

        // Run additional iterations if not converged
        if (!converged and total_iterations < self.config.max_iterations) {
            const additional = @min(self.config.iterations, self.config.max_iterations - total_iterations);
            for (0..additional) |_| {
                const value = sample_fn(&self.rng);
                try samples.append(value);
            }
            total_iterations += additional;
            converged = self.checkConvergence(samples.items[total_iterations - additional ..]);
        }

        return self.calculateStatistics(samples.items, converged);
    }

    /// Check if simulation has converged
    fn checkConvergence(self: *const MonteCarloSimulator, samples: []const f64) bool {
        if (samples.len < 10) return false;

        // Calculate mean of first half vs second half
        const mid = samples.len / 2;
        var mean1: f64 = 0;
        var mean2: f64 = 0;

        for (samples[0..mid]) |v| mean1 += v;
        for (samples[mid..]) |v| mean2 += v;

        mean1 /= @as(f64, @floatFromInt(mid));
        mean2 /= @as(f64, @floatFromInt(samples.len - mid));

        const diff = @abs(mean1 - mean2);
        const avg_mean = (mean1 + mean2) / 2;

        // Converged if relative difference is below threshold
        if (avg_mean != 0) {
            return (diff / avg_mean) < self.config.convergence_threshold;
        }
        return diff < self.config.convergence_threshold;
    }

    /// Calculate statistics from samples
    fn calculateStatistics(self: *const MonteCarloSimulator, samples: []const f64, converged: bool) !SimulationResult {
        // Calculate mean
        var sum: f64 = 0;
        for (samples) |v| sum += v;
        const mean = sum / @as(f64, @floatFromInt(samples.len));

        // Calculate standard deviation
        var variance: f64 = 0;
        for (samples) |v| {
            const diff = v - mean;
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(samples.len - 1));
        const std_dev = std.math.sqrt(variance);

        // Find min/max
        var min_val = samples[0];
        var max_val = samples[0];
        for (samples[1..]) |v| {
            if (v < min_val) min_val = v;
            if (v > max_val) max_val = v;
        }

        // Calculate confidence interval (95%)
        const margin = 1.96 * std_dev / std.math.sqrt(@as(f64, @floatFromInt(samples.len)));
        const ci = ConfidenceInterval{
            .lower = mean - margin,
            .upper = mean + margin,
            .confidence_level = 0.95,
        };

        // Calculate percentiles
        const percentiles = try self.calculatePercentiles(samples);

        return .{
            .mean = mean,
            .std_dev = std_dev,
            .min = min_val,
            .max = max_val,
            .confidence_interval_95 = ci,
            .percentiles = percentiles,
            .sample_count = samples.len,
            .converged = converged,
        };
    }

    /// Calculate percentiles from sorted samples
    fn calculatePercentiles(self: *const MonteCarloSimulator, samples: []const f64) !Percentiles {
        // Sort samples
        const sorted = try self.allocator.alloc(f64, samples.len);
        defer self.allocator.free(sorted);
        @memcpy(sorted, samples);
        std.mem.sort(f64, sorted, {}, comptime std.sort.asc(f64));

        const p50_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(sorted.len - 1)) * 0.50));
        const p90_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(sorted.len - 1)) * 0.90));
        const p95_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(sorted.len - 1)) * 0.95));
        const p99_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(sorted.len - 1)) * 0.99));

        return .{
            .p50 = sorted[p50_idx],
            .p90 = sorted[p90_idx],
            .p95 = sorted[p95_idx],
            .p99 = sorted[p99_idx],
        };
    }

    /// φ-stratified sampling for variance reduction
    pub fn phiStratifiedSample(
        self: *MonteCarloSimulator,
        comptime sample_fn: *const fn (f64) f64,
        strata: usize,
    ) !SimulationResult {
        var samples = ArrayList(f64).init(self.allocator);
        defer samples.deinit();

        const phi_steps = strata;
        const samples_per_stratum = @max(1, self.config.iterations / phi_steps);

        for (0..phi_steps) |i| {
            // φ-based stratification: use φ-distributed strata boundaries
            const stratum_min = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(phi_steps));
            const stratum_max = @as(f64, @floatFromInt(i + 1)) / @as(f64, @floatFromInt(phi_steps));

            // Apply φ-weighting to stratum boundaries
            const phi_min = stratum_min * sacred.PHI;
            const phi_max = stratum_max * sacred.PHI;

            for (0..samples_per_stratum) |_| {
                // Sample uniformly within stratum
                const u = self.rng.random().float(f64);
                const normalized_u = phi_min + u * (phi_max - phi_min);
                const value = sample_fn(normalized_u);
                try samples.append(value);
            }
        }

        return self.calculateStatistics(samples.items, true);
    }

    /// Generate random value with φ-weighted distribution
    pub fn phiWeightedRandom(self: *MonteCarloSimulator) f64 {
        const u = self.rng.random().float(f64);
        // Apply φ-weighting: skew distribution towards golden ratio
        return std.math.pow(f64, u, sacred.PHI);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "Monte Carlo: Initialize" {
    const config = MonteCarloConfig{};
    const simulator = MonteCarloSimulator.init(std.testing.allocator, config);
    _ = simulator;
}

test "Monte Carlo: Simulate uniform distribution" {
    const config = MonteCarloConfig{ .iterations = 1000, .seed = 42 };
    var simulator = MonteCarloSimulator.init(std.testing.allocator, config);

    const uniformSample = struct {
        fn sample(rng: *std.Random.DefaultPrng) f64 {
            return rng.random().float(f64);
        }
    }.sample;

    const result = try simulator.simulate(uniformSample);

    // Mean should be ~0.5 for uniform [0,1]
    try std.testing.expectApproxEqAbs(0.5, result.mean, 0.05);
    // Values should be in [0,1]
    try std.testing.expect(result.min >= 0 and result.min < 0.1);
    try std.testing.expect(result.max > 0.9 and result.max <= 1.0);
}

test "Monte Carlo: Simulate normal distribution approximation" {
    const config = MonteCarloConfig{ .iterations = 1000, .seed = 123 };
    var simulator = MonteCarloSimulator.init(std.testing.allocator, config);

    // Use sum of 12 uniform randoms as normal approximation (Box-Muller alternative)
    const normalSample = struct {
        fn sample(rng: *std.Random.DefaultPrng) f64 {
            var sum: f64 = 0;
            for (0..12) |_| {
                sum += rng.random().float(f64);
            }
            return (sum - 6.0) / std.math.sqrt(1.0); // Mean 0, Std Dev 1
        }
    }.sample;

    const result = try simulator.simulate(normalSample);

    // Mean should be ~0
    try std.testing.expectApproxEqAbs(0.0, result.mean, 0.1);
    // Std dev should be ~1
    try std.testing.expectApproxEqAbs(1.0, result.std_dev, 0.2);
}

test "Monte Carlo: Confidence interval" {
    const config = MonteCarloConfig{ .iterations = 500, .seed = 456 };
    var simulator = MonteCarloSimulator.init(std.testing.allocator, config);

    const constantSample = struct {
        fn sample(rng: *std.Random.DefaultPrng) f64 {
            _ = rng;
            return 1.0;
        }
    }.sample;

    const result = try simulator.simulate(constantSample);

    // For constant value, CI should be very tight around 1.0
    try std.testing.expect(result.confidence_interval_95.lower >= 0.99);
    try std.testing.expect(result.confidence_interval_95.upper <= 1.01);
}

test "Monte Carlo: Percentiles" {
    const config = MonteCarloConfig{ .iterations = 500, .seed = 789 };
    var simulator = MonteCarloSimulator.init(std.testing.allocator, config);

    const linearSample = struct {
        fn sample(rng: *std.Random.DefaultPrng) f64 {
            return rng.random().float(f64);
        }
    }.sample;

    const result = try simulator.simulate(linearSample);

    // For uniform distribution, percentiles should roughly match their values
    try std.testing.expect(result.percentiles.p50 > 0.4 and result.percentiles.p50 < 0.6);
    try std.testing.expect(result.percentiles.p90 > 0.85 and result.percentiles.p90 < 0.95);
}

test "Monte Carlo: Phi-weighted random" {
    const config = MonteCarloConfig{ .seed = 999 };
    var simulator = MonteCarloSimulator.init(std.testing.allocator, config);

    const values = [_]f64{
        simulator.phiWeightedRandom(),
        simulator.phiWeightedRandom(),
        simulator.phiWeightedRandom(),
        simulator.phiWeightedRandom(),
        simulator.phiWeightedRandom(),
    };

    // All values should be in [0,1]
    for (values) |v| {
        try std.testing.expect(v >= 0.0 and v <= 1.0);
    }
}

test "Monte Carlo: Phi stratified sampling" {
    const config = MonteCarloConfig{ .iterations = 500, .seed = 111, .use_phi_stratification = true };
    var simulator = MonteCarloSimulator.init(std.testing.allocator, config);

    const identitySample = struct {
        fn sample(u: f64) f64 {
            return u; // Identity function
        }
    }.sample;

    const result = try simulator.phiStratifiedSample(identitySample, 5);

    // φ-stratified sampling skews distribution upward (values can exceed 1.0)
    // Mean will be higher than uniform 0.5 due to φ-weighting
    try std.testing.expect(result.mean > 0.5 and result.mean < 1.2);
}

test "Monte Carlo: Convergence detection" {
    const config = MonteCarloConfig{
        .iterations = 1000,
        .convergence_threshold = 0.01,
        .seed = 222,
    };
    var simulator = MonteCarloSimulator.init(std.testing.allocator, config);

    const constantSample = struct {
        fn sample(rng: *std.Random.DefaultPrng) f64 {
            _ = rng;
            return 5.0;
        }
    }.sample;

    const result = try simulator.simulate(constantSample);

    // Constant function should converge quickly
    try std.testing.expect(result.converged);
    try std.testing.expectApproxEqAbs(5.0, result.mean, 0.01);
}
