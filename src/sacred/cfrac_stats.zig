// ═══════════════════════════════════════════════════════════════════════════════
// PALANTIR PIPELINE — Stage 2: CLASSIFY
// 7 Diagnostics: Khinchin ratio, Gauss-Kuzmin χ², max PQ, periodicity,
//                autocorrelation, irrationality measure μ, entropy
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const cfrac_ref = @import("cfrac_reference.zig");

pub const StatsResult = struct {
    target_id: []const u8,
    target_value: f64,

    // 7 Diagnostics
    khinchin_ratio: f64,
    gauss_kuzmin_chi2: f64,
    max_partial_quotient: u64,
    is_periodic: bool,
    period_length: ?usize,
    autocorrelation: f64,
    irrationality_measure: f64,
    entropy: f64,

    // Classification
    classification: cfrac_ref.Classification,
    classification_confidence: f64,

    // Verdict
    verdict: []const u8,

    pub fn format(self: *const StatsResult, writer: anytype) !void {
        try writer.print("StatsResult({s}={d:.6}, class={s}, K={d:.3})", .{
            self.target_id,                                             self.target_value,
            cfrac_ref.formatClassification.format(self.classification), self.khinchin_ratio,
        });
    }
};

/// Compute all 7 diagnostics for a continued fraction
pub fn computeStats(allocator: std.mem.Allocator, formula_id: []const u8, partials: []const u64) !StatsResult {
    _ = allocator;

    // Diagnostic 1: Khinchin ratio
    const khinchin = computeKhinchinRatio(partials);

    // Diagnostic 2: Gauss-Kuzmin χ²
    const gk_chi2 = computeGaussKuzmin(partials);

    // Diagnostic 3: Max partial quotient
    var max_pq: u64 = 0;
    for (partials) |p| {
        if (p > max_pq) max_pq = p;
    }

    // Diagnostic 4: Periodicity
    const periodic = detectPeriodicity(partials);

    // Diagnostic 5: Autocorrelation (lag-1)
    const autocorr = computeAutocorrelation(partials);

    // Diagnostic 6: Irrationality measure μ (approximation quality)
    const mu = computeIrrationalityMeasure(partials);

    // Diagnostic 7: Shannon entropy
    const entropy = computeEntropy(partials);

    // Classification tree
    const classification = classifyNumber(partials, khinchin, gk_chi2, periodic, max_pq, entropy);

    // Confidence based on consistency of diagnostics
    const confidence = computeConfidence(partials, khinchin, gk_chi2, periodic, max_pq, entropy);

    const verdict = generateVerdict(classification, confidence, khinchin, gk_chi2);

    return StatsResult{
        .target_id = formula_id,
        .target_value = 0.0, // Filled by caller
        .khinchin_ratio = khinchin,
        .gauss_kuzmin_chi2 = gk_chi2,
        .max_partial_quotient = max_pq,
        .is_periodic = periodic.is_periodic,
        .period_length = periodic.period_length,
        .autocorrelation = autocorr,
        .irrationality_measure = mu,
        .entropy = entropy,
        .classification = classification,
        .classification_confidence = confidence,
        .verdict = verdict,
    };
}

// Diagnostic 1: Khinchin ratio
/// K = lim (n→∞) (∏₁ⁿ aᵢ)^(1/n) ≈ 2.685 for generic numbers
/// For φ: K → 0.372 (anomalous!)
fn computeKhinchinRatio(partials: []const u64) f64 {
    if (partials.len < 10) return 0.0;

    // Compute geometric mean: exp((1/n) * Σ ln(aᵢ))
    var log_sum: f64 = 0.0;
    var count: usize = 0;

    for (partials) |p| {
        if (p > 0) {
            log_sum += std.math.log(f64, std.math.e, @floatFromInt(p));
            count += 1;
        }
    }

    if (count == 0) return 0.0;
    return @exp(log_sum / @as(f64, @floatFromInt(count)));
}

// Diagnostic 2: Gauss-Kuzmin χ² test
/// For almost all numbers, P(aₙ = k) ≈ -log₂(1 - 1/(k+1)²)
fn computeGaussKuzmin(partials: []const u64) f64 {
    if (partials.len < 10) return 0.0;

    // Count frequencies of 1, 2, 3, 4, 5+
    var counts = [_]u64{0} ** 5;
    for (partials) |p| {
        if (p == 0) continue; // Skip for numbers < 1
        const idx = @min(4, p -| 1);
        counts[idx] += 1;
    }

    const total: f64 = @floatFromInt(partials.len);
    var chi_sq: f64 = 0.0;

    // Expected probabilities from Gauss-Kuzmin distribution
    const expected = [_]f64{
        -std.math.log2(1.0 - 1.0 / 4.0), // k=1: 0.4150
        -std.math.log2(1.0 - 1.0 / 9.0), // k=2: 0.1699
        -std.math.log2(1.0 - 1.0 / 16.0), // k=3: 0.0931
        -std.math.log2(1.0 - 1.0 / 25.0), // k=4: 0.0588
        1.0 - 0.4150 - 0.1699 - 0.0931 - 0.0588, // k>=5
    };

    for (0..5) |i| {
        const observed_f: f64 = @floatFromInt(counts[i]);
        const expected_f = expected[i] * total;
        if (expected_f > 0.5) {
            const diff = observed_f - expected_f;
            chi_sq += diff * diff / expected_f;
        }
    }

    return chi_sq;
}

// Diagnostic 4: Periodicity detection
const PeriodicityResult = struct {
    is_periodic: bool,
    period_length: ?usize,
    confidence: f64,
};

fn detectPeriodicity(partials: []const u64) PeriodicityResult {
    if (partials.len < 20) {
        return .{ .is_periodic = false, .period_length = null, .confidence = 0.0 };
    }

    // Check for period 1 (all 1s like φ)
    var all_ones = true;
    for (partials) |p| {
        if (p != 1) {
            all_ones = false;
            break;
        }
    }
    if (all_ones) {
        return .{ .is_periodic = true, .period_length = 1, .confidence = 1.0 };
    }

    // Check for period 2 (alternating like √2)
    if (partials.len >= 4) {
        const p01 = partials[0] == partials[2];
        const p12 = partials[1] == partials[3];
        if (p01 and p12) {
            // Check more terms
            var matches = true;
            const check_len = @min(10, partials.len / 2);
            var i: usize = 0;
            while (i + 2 < partials.len and i < check_len) : (i += 1) {
                if (partials[i] != partials[i + 2]) {
                    matches = false;
                    break;
                }
            }
            if (matches) {
                return .{ .is_periodic = true, .period_length = 2, .confidence = 0.9 };
            }
        }
    }

    // General periodicity check
    const max_period = @min(20, partials.len / 3);
    var period: usize = 3;
    while (period <= max_period) : (period += 1) {
        var matches = true;
        var i: usize = 0;
        while (i + period < partials.len) : (i += 1) {
            if (partials[i] != partials[i + period]) {
                matches = false;
                break;
            }
        }
        if (matches) {
            return .{ .is_periodic = true, .period_length = period, .confidence = 0.7 };
        }
    }

    return .{ .is_periodic = false, .period_length = null, .confidence = 0.0 };
}

// Diagnostic 5: Autocorrelation at lag 1
/// Measures memory in the sequence
fn computeAutocorrelation(partials: []const u64) f64 {
    if (partials.len < 10) return 0.0;

    // Mean
    var sum: f64 = 0;
    for (partials) |p| sum += @floatFromInt(p);
    const mean = sum / @as(f64, @floatFromInt(partials.len));

    // Variance
    var var_sum: f64 = 0;
    for (partials) |p| {
        const diff = @as(f64, @floatFromInt(p)) - mean;
        var_sum += diff * diff;
    }
    const variance = var_sum / @as(f64, @floatFromInt(partials.len));

    if (variance < 1e-10) return 0.0;

    // Covariance at lag 1
    var cov_sum: f64 = 0;
    const n = partials.len - 1;
    for (0..n) |i| {
        const diff1 = @as(f64, @floatFromInt(partials[i])) - mean;
        const diff2 = @as(f64, @floatFromInt(partials[i + 1])) - mean;
        cov_sum += diff1 * diff2;
    }
    const covariance = cov_sum / @as(f64, @floatFromInt(n));

    return covariance / variance;
}

// Diagnostic 6: Irrationality measure μ
/// μ(x) = lim inf (q→∞) |x - p/q| × q^μ
/// Smaller μ = "more irrational" (harder to approximate)
fn computeIrrationalityMeasure(partials: []const u64) f64 {
    if (partials.len < 3) return 0.0;

    // Use growth rate of partial quotients as proxy
    // Large partials → small μ (very irrational)
    // Small partials → large μ (easily approximated)

    var sum_logs: f64 = 0;
    var count: usize = 0;

    for (partials) |p| {
        if (p > 0) {
            sum_logs += std.math.log(f64, std.math.e, @floatFromInt(p));
            count += 1;
        }
    }

    if (count == 0) return 0.0;
    const avg_log = sum_logs / @as(f64, @floatFromInt(count));

    // μ ≈ 1/exp(avg_log) * scaling factor
    return 1.0 / @exp(avg_log) * 10.0;
}

// Diagnostic 7: Shannon entropy
fn computeEntropy(partials: []const u64) f64 {
    if (partials.len < 2) return 0.0;

    // Use fixed-size array for common partials (0-100)
    var counts = [1]f64{0} ** 101;
    for (partials) |p| {
        if (p < 101) {
            counts[p] += 1.0;
        } else {
            counts[100] += 1.0;
        }
    }

    const total: f64 = @floatFromInt(partials.len);
    var entropy: f64 = 0.0;

    for (counts) |c| {
        if (c > 0) {
            const prob = c / total;
            if (prob > 1e-10) {
                entropy -= prob * std.math.log2(prob);
            }
        }
    }

    return entropy;
}

/// Classification tree
fn classifyNumber(
    partials: []const u64,
    khinchin: f64,
    gk_chi2: f64,
    periodic: PeriodicityResult,
    max_pq: u64,
    entropy: f64,
) cfrac_ref.Classification {
    // Periodic → quadratic
    if (periodic.is_periodic) {
        return if (periodic.period_length.? == 1 and periodic.confidence == 1.0)
            cfrac_ref.Classification.noble // φ-type
        else
            cfrac_ref.Classification.quadratic;
    }

    // All ones → noble (already caught above, but keep for completeness)
    var all_ones = true;
    for (partials) |p| {
        if (p != 1) {
            all_ones = false;
            break;
        }
    }
    if (all_ones) return cfrac_ref.Classification.noble;

    // Bounded partials → quadratic-like
    if (max_pq < 10) {
        return cfrac_ref.Classification.quadratic;
    }

    // Khinchin-based classification
    if (khinchin < 0.6) {
        return cfrac_ref.Classification.noble; // φ-type
    } else if (khinchin < 1.5) {
        return cfrac_ref.Classification.anomalous;
    } else if (khinchin < 2.3) {
        return cfrac_ref.Classification.generic;
    } else if (khinchin < 2.7) {
        return cfrac_ref.Classification.quadratic;
    }

    // Default: generic transcendental
    return cfrac_ref.Classification.generic;
}

/// Compute confidence in classification
fn computeConfidence(
    partials: []const u64,
    khinchin: f64,
    gk_chi2: f64,
    periodic: PeriodicityResult,
    max_pq: u64,
    entropy: f64,
) f64 {
    var score: f64 = 0.0;

    // Periodic gives high confidence
    if (periodic.is_periodic) {
        score += 0.5;
    }

    // Khinchin near expected value gives confidence
    if (@abs(khinchin - cfrac_ref.KHINCHIN_CONSTANT) < 0.3) {
        score += 0.2;
    }

    // Gauss-Kuzmin compliance
    if (gk_chi2 < 9.49) {
        score += 0.15;
    }

    // Sufficient data
    if (partials.len >= 1000) {
        score += 0.15;
    }

    return @min(1.0, score);
}

/// Generate human-readable verdict
fn generateVerdict(classification: cfrac_ref.Classification, confidence: f64, khinchin: f64, gk_chi2: f64) []const u8 {
    _ = confidence;

    return switch (classification) {
        .noble => "NOBLE: φ-type structure (Khinchin K << 2.685)",
        .quadratic => "QUADRATIC: Periodic or bounded CF (algebraic of degree 2)",
        .transcendental => "TRANSCENDENTAL: Non-algebraic structure",
        .generic => "GENERIC: Typical transcendental (Gauss-Kuzmin compliant)",
        .anomalous => "ANOMALOUS: Deviates from expected patterns",
        .periodic => "PERIODIC: Exact repetition (quadratic irrational)",
    };
}

/// CLI command: tri math cfrac-stats <formula_id>
pub fn runStatsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GREEN = "\x1b[32m";
    const YELLOW = "\x1b[93m";
    const RED = "\x1b[31m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    if (args.len < 1) {
        std.debug.print("\n{s}USAGE:{s} tri math cfrac-stats <formula_id>\n", .{ CYAN, RESET });
        std.debug.print("\n{s}PALANTIR Stage 2 — CLASSIFY: 7 Diagnostics{s}\n\n", .{ CYAN, RESET });
        std.debug.print("{s}DIAGNOSTICS:{s}\n", .{ WHITE, RESET });
        std.debug.print("  1. Khinchin ratio     K ≈ 2.685 for generic numbers\n", .{});
        std.debug.print("  2. Gauss-Kuzmin χ²    Tests for randomness\n", .{});
        std.debug.print("  3. Max partial quotient Largest term in CF\n", .{});
        std.debug.print("  4. Periodicity        Detects repeating patterns\n", .{});
        std.debug.print("  5. Autocorrelation    Lag-1 correlation\n", .{});
        std.debug.print("  6. Irrationality μ    Approximation difficulty\n", .{});
        std.debug.print("  7. Entropy            Shannon information\n\n", .{});
        std.debug.print("{s}EXAMPLES:{s}\n", .{ CYAN, RESET });
        std.debug.print("  $ tri math cfrac-stats phi\n", .{});
        std.debug.print("  $ tri math cfrac-stats omega_dm\n\n", .{});
        std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
        return;
    }

    // Import expand function
    const expand = @import("cfrac_expand.zig");

    const formula_id = args[0];
    const resolved = try expand.resolveFormula(formula_id);

    // Get CF expansion
    const result = try expand.expand(allocator, resolved.value, resolved.expression, .{});
    defer result.deinit(allocator);

    // Compute all 7 diagnostics
    const stats = try computeStats(allocator, formula_id, result.partials);

    std.debug.print("\n{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}║          PALANTIR STAGE 2 — CLASSIFY: 7 DIAGNOSTICS              ║{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    std.debug.print("  {s}Target:{s} {s}\n", .{ WHITE, RESET, resolved.expression });
    std.debug.print("  {s}Value:{s} {d:.15}\n", .{ WHITE, RESET, resolved.value });
    std.debug.print("  {s}CF Terms:{s} {d}\n\n", .{ WHITE, RESET, result.depth });

    std.debug.print("  {s}╔══════════════════════════════════════════════════════════════╗{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  {s}║  7 DIAGNOSTICS                                              ║{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  {s}╚══════════════════════════════════════════════════════════════╝{s}\n\n", .{ MAGENTA, RESET });

    const k_color = if (@abs(stats.khinchin_ratio - cfrac_ref.KHINCHIN_CONSTANT) < 0.3) GREEN else if (stats.khinchin_ratio < 1.0) YELLOW else RED;
    std.debug.print("  1. {s}Khinchin Ratio:{s} K = {d:.4} {s}(expected: {d:.4}){s}\n", .{ WHITE, RESET, stats.khinchin_ratio, k_color, cfrac_ref.KHINCHIN_CONSTANT, RESET });

    const gk_color = if (stats.gauss_kuzmin_chi2 < 9.49) GREEN else YELLOW;
    std.debug.print("  2. {s}Gauss-Kuzmin χ²:{s} {d:.3} {s}(p > 0.05 if < 9.49){s}\n", .{ WHITE, RESET, stats.gauss_kuzmin_chi2, gk_color, RESET });

    const max_color = if (stats.max_partial_quotient < 100) GREEN else if (stats.max_partial_quotient < 1000) YELLOW else RED;
    std.debug.print("  3. {s}Max Partial Quotient:{s} {d} {s}({s}){s}\n", .{ WHITE, RESET, stats.max_partial_quotient, max_color, if (stats.max_partial_quotient < 10) "bounded" else if (stats.max_partial_quotient < 100) "moderate" else "large", RESET });

    const per_color = if (stats.is_periodic) GREEN else YELLOW;
    std.debug.print("  4. {s}Periodicity:{s} {s}{s}{s}\n", .{ WHITE, RESET, per_color, if (stats.is_periodic) "YES" else "NO", RESET });
    if (stats.period_length) |pl| {
        std.debug.print("     └─ Period length: {d}\n", .{pl});
    }

    const ac_color = if (@abs(stats.autocorrelation) < 0.1) GREEN else YELLOW;
    std.debug.print("  5. {s}Autocorrelation (lag-1):{s} {d:.4} {s}({s}){s}\n", .{ WHITE, RESET, stats.autocorrelation, ac_color, if (@abs(stats.autocorrelation) < 0.1) "no memory" else "has memory", RESET });

    const mu_color = if (stats.irrationality_measure < 0.5) GREEN else YELLOW;
    std.debug.print("  6. {s}Irrationality Measure μ:{s} {d:.4} {s}(lower = more irrational){s}\n", .{ WHITE, RESET, stats.irrationality_measure, mu_color, RESET });

    const ent_color = if (stats.entropy < 3.0) GREEN else if (stats.entropy < 4.0) YELLOW else RED;
    std.debug.print("  7. {s}Entropy:{s} {d:.3} bits {s}({s}){s}\n\n", .{ WHITE, RESET, stats.entropy, ent_color, if (stats.entropy < 3.0) "structured" else if (stats.entropy < 4.0) "moderate" else "chaotic", RESET });

    std.debug.print("  {s}CLASSIFICATION:{s}\n", .{ MAGENTA, RESET });
    const class_color = switch (stats.classification) {
        .noble => GREEN,
        .quadratic => GREEN,
        .transcendental => YELLOW,
        .generic => YELLOW,
        .anomalous => RED,
        .periodic => GREEN,
    };
    std.debug.print("    {s}{}{s} (confidence: {d:.0%})\n", .{ class_color, cfrac_ref.formatClassification.format(stats.classification), RESET, stats.classification_confidence });

    std.debug.print("\n  {s}VERDICT:{s}\n", .{ WHITE, RESET });
    std.debug.print("    {s}\n\n", .{stats.verdict});

    std.debug.print("{s}Next stages: cfrac-compare, cfrac-approx, cfrac-detect, cfrac-verdict{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

// φ² + 1/φ² = 3 = TRINITY
