// ═══════════════════════════════════════════════════════════════════════
// ABLATION FRAMEWORK IMPLEMENTATION
// ═════════════════════════════════════════════════════════════════════
// Systematic Ablation Study Framework for Trinity S³AI Research
//
// Generated from: specs/tri-lang/ablation.tri
//
// φ² + 1/φ² = 3 | TRINITY
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ComponentToggle = union(enum) {
    enable_sacred_scaling,
    disable_sacred_scaling,
    enable_ternary_encoding,
    disable_ternary_encoding,
    enable_vsa,
    disable_vsa,
    enable_sevo,
    disable_sevo,
    enable_temple,
    disable_temple,
    enable_tri27,
    disable_tri27,
    enable_hslm,
    disable_hslm,
    enable_phoenix,
    disable_phoenix,
    enable_queen,
    disable_queen,
    baseline_only,
    full_system,
};

pub const Metric = union(enum) {
    perplexity,
    accuracy,
    loss,
    convergence_steps,
    tokens_per_second,
    energy_per_token,
    memory_usage,
    l1_distance,
    cosine_similarity,
    capacity_bound,
    gradient_scale,
};

pub const Dataset = union(enum) {
    tinystories,
    wiktext,
    custom,
};

pub const AblationConfig = struct {
    name: []const u8,
    components: []const ComponentToggle,
    seeds: []const u32,
    dataset: Dataset,
    epochs: usize,
    batch_size: usize,
    learning_rate: f64,
    metrics: []const Metric,
    output_path: []const u8,
};

pub const ExperimentResult = struct {
    config: AblationConfig,
    seed: u32,
    epoch: usize,
    train_loss: f64,
    val_loss: f64,
    test_loss: f64,
    perplexity: f64,
    tokens_per_second: f64,
    energy_joules: f64,
    memory_mb: f64,
    convergence_epoch: ?usize,
};

pub const AggregatedResult = struct {
    config: AblationConfig,
    n_seeds: usize,
    train_loss_mean: f64,
    train_loss_std: f64,
    train_loss_ci_95_low: f64,
    train_loss_ci_95_high: f64,
    val_loss_mean: f64,
    val_loss_std: f64,
    test_loss_mean: f64,
    perplexity_mean: f64,
    perplexity_std: f64,
    significance_paired: f64,
    effect_size: f64,
};

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

test "AblationFramework - Statistical functions" {
    const values = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };

    const mu = mean(&values);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), mu, 0.01);

    const sigma = stdDev(&values, mu);
    try std.testing.expectApproxEqAbs(@as(f64, 1.58), sigma, 0.01);
}
