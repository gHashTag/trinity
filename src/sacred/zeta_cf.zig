// ═══════════════════════════════════════════════════════════════════════════════
// ZETA CF — Continued Fraction Analysis of Zeta Zero Spacings
// File: src/sacred/zeta_cf.zig
// Session 9: Riemann Hypothesis CF Analysis
//
// PURPOSE: Run Palantir 10-test battery on zeta zero spacings
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const zeta_import = @import("zeta_import.zig");
const zeta_spacing = @import("zeta_spacing.zig");

// Import Palantir for CF analysis
const cfrac_palantir = @import("cfrac_palantir.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// Complete CF analysis result for zeta spacings
pub const ZetaCFResult = struct {
    spacings: *zeta_spacing.Spacings,
    cf_stats: CFStats,
    gue_comparison: zeta_spacing.GUEComparison,
    verdict: ZetaVerdict,
};

/// Verdict on zeta spacings based on CF analysis
pub const ZetaVerdict = enum {
    generic_transcendental, // Follows generic CF patterns
    gue_consistent, // Matches random matrix predictions
    anomalous, // Unexpected structure found
    inconclusive, // Need more data

    pub fn format(self: ZetaVerdict) []const u8 {
        return switch (self) {
            .generic_transcendental => "GENERIC TRANSCENDENTAL (no special structure)",
            .gue_consistent => "CONSISTENT WITH GUE (random matrix theory)",
            .anomalous => "ANOMALOUS (unusual arithmetic structure detected)",
            .inconclusive => "INCONCLUSIVE (need more data)",
        };
    }
};

/// CF statistics (subset of Palantir CFStats for spacing analysis)
pub const CFStats = struct {
    mu: f64, // Irrationality measure
    khinchin_k: f64, // Khinchin constant
    entropy: f64, // Information entropy
    gk_chi2: f64, // Gauss-Kuzmin χ² statistic
    max_partial: u64, // Maximum partial quotient
    mean_partial: f64, // Mean partial quotient

    pub fn init() CFStats {
        return CFStats{
            .mu = 0.0,
            .khinchin_k = 0.0,
            .entropy = 0.0,
            .gk_chi2 = 0.0,
            .max_partial = 0,
            .mean_partial = 0.0,
        };
    }
};

/// CF expansion result for a single spacing
pub const SpacingCF = struct {
    value: f64, // Original spacing value
    partials: []u64, // Partial quotients [a0; a1, a2, ...]
    depth: usize, // Number of terms computed

    pub fn deinit(self: *const SpacingCF, allocator: std.mem.Allocator) void {
        allocator.free(self.partials);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CF EXPANSION FOR SPACINGS
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute CF expansion of a spacing value
pub fn expandSpacingCF(allocator: std.mem.Allocator, value: f64, max_depth: usize) !SpacingCF {
    var partials = try std.ArrayList(u64).initCapacity(allocator, max_depth);
    errdefer partials.deinit(allocator);

    // Skip extreme values (likely outliers in synthetic data)
    if (@abs(value) > 100.0 or value == 0) {
        return SpacingCF{
            .value = value,
            .partials = try allocator.alloc(u64, 0),
            .depth = 0,
        };
    }

    var x = value;
    var depth: usize = 0;

    while (depth < max_depth) : (depth += 1) {
        const a = @floor(x);

        // Check for overflow before casting
        if (a < 0 or a > @as(f64, @floatFromInt(std.math.maxInt(u64)))) {
            break; // Skip this partial quotient
        }

        try partials.append(allocator, @intFromFloat(a));

        const frac = x - a;
        if (frac < 1e-15) break; // Terminating CF

        x = 1.0 / frac;
        if (x > 1e15 or x < 0) break; // Avoid overflow or invalid values
    }

    return SpacingCF{
        .value = value,
        .partials = try partials.toOwnedSlice(allocator),
        .depth = depth,
    };
}

/// Compute CF statistics for multiple spacings
pub fn computeSpacingCFStats(allocator: std.mem.Allocator, spacings: *const zeta_spacing.Spacings, n_samples: usize) !CFStats {
    var stats = CFStats.init();

    const sample_count = @min(n_samples, spacings.count);
    if (sample_count == 0) return stats;

    // Accumulate statistics across all sampled spacings
    var sum_mu: f64 = 0.0;
    var sum_k: f64 = 0.0;
    var sum_mean_partial: f64 = 0.0;
    var max_partial_all: u64 = 0;
    var valid_samples: usize = 0;

    // Collect all partial quotients for entropy calculation
    var all_partials = try std.ArrayList(u64).initCapacity(allocator, 10000);
    defer all_partials.deinit(allocator);

    for (0..sample_count) |i| {
        const spacing = spacings.values[i];
        const cf = try expandSpacingCF(allocator, spacing, 100);
        defer cf.deinit(allocator);

        if (cf.depth < 5) continue; // Skip very short CFs

        valid_samples += 1;

        // Irrationality measure approximation
        const mu = estimateMuFromCF(cf.partials);
        sum_mu += mu;

        // Khinchin K approximation (geometric mean)
        const k = estimateKhinchinFromCF(cf.partials);
        sum_k += k;

        // Collect partials for entropy
        for (cf.partials) |p| {
            try all_partials.append(allocator, p);
        }

        // Mean partial quotient
        var sum_p: f64 = 0.0;
        var max_p: u64 = 0;
        for (cf.partials) |p| {
            sum_p += @as(f64, @floatFromInt(p));
            if (p > max_p) max_p = p;
        }
        sum_mean_partial += sum_p / @as(f64, @floatFromInt(cf.partials.len));

        if (max_p > max_partial_all) max_partial_all = max_p;
    }

    if (valid_samples == 0) return stats;

    const n_f = @as(f64, @floatFromInt(valid_samples));
    stats.mu = sum_mu / n_f;
    stats.khinchin_k = sum_k / n_f;
    stats.mean_partial = sum_mean_partial / n_f;
    stats.max_partial = max_partial_all;

    // Compute entropy from ALL partial quotients together
    stats.entropy = try computeEntropyFromPartials(allocator, all_partials.items);

    // Gauss-Kuzmin χ² test: P(a_n = k) = -log2(1 - 1/(k+1)²)
    if (all_partials.items.len > 0) {
        var gk_counts = [_]u64{0} ** 5;
        for (all_partials.items) |p| {
            if (p == 0) continue;
            const idx = @min(4, p -| 1);
            gk_counts[idx] += 1;
        }
        const total_f: f64 = @floatFromInt(all_partials.items.len);
        const expected = [5]f64{ 0.415, 0.170, 0.093, 0.059, 0.263 };
        var chi2: f64 = 0.0;
        for (gk_counts, 0..) |c, idx| {
            const obs = @as(f64, @floatFromInt(c)) / total_f;
            const diff = obs - expected[idx];
            chi2 += (diff * diff) / expected[idx];
        }
        stats.gk_chi2 = chi2;
    }

    return stats;
}

/// Estimate irrationality measure from CF partial quotients
fn estimateMuFromCF(partials: []const u64) f64 {
    if (partials.len < 3) return 2.0;

    // μ ≈ 1 + lim sup(ln(a_{n+1}) / ln(q_n))
    // Simplified: use ratio of consecutive partial quotients
    var max_ratio: f64 = 0.0;
    for (1..@min(partials.len, 10)) |i| {
        if (partials[i] > 0) {
            const ratio = @as(f64, @floatFromInt(partials[i])) /
                @as(f64, @floatFromInt(@max(partials[i - 1], 1)));
            if (ratio > max_ratio) max_ratio = ratio;
        }
    }
    return 1.0 + @log(max_ratio + 1.0);
}

/// Estimate Khinchin K from CF partial quotients (geometric mean)
fn estimateKhinchinFromCF(partials: []const u64) f64 {
    if (partials.len == 0) return 2.685;

    var product: f64 = 1.0;
    const n = @min(partials.len, 50);
    for (partials[0..n]) |a| {
        if (a > 0) {
            product *= @as(f64, @floatFromInt(a));
        }
    }
    return std.math.pow(f64, product, 1.0 / @as(f64, @floatFromInt(n)));
}

/// Estimate entropy from CF partial quotients
fn estimateEntropyFromCF(partials: []const u64) f64 {
    if (partials.len == 0) return 0.0;

    var entropy: f64 = 0.0;
    var counts = std.AutoHashMap(u64, usize).init(std.heap.page_allocator);
    defer counts.deinit();

    for (partials) |a| {
        const gop = counts.getOrPut(a) catch continue;
        gop.value_ptr.* += 1;
    }

    const n = @as(f64, @floatFromInt(partials.len));
    var iter = counts.iterator();
    while (iter.next()) |entry| {
        const p = @as(f64, @floatFromInt(entry.value_ptr.*)) / n;
        if (p > 0) {
            entropy -= p * @log(p);
        }
    }

    return entropy;
}

/// Compute Shannon entropy from a collection of partial quotients
/// Simple approach: count frequencies directly
fn computeEntropyFromPartials(allocator: std.mem.Allocator, partials: []const u64) !f64 {
    if (partials.len == 0) return 0.0;

    // Count frequency of each partial quotient value
    var counts = std.AutoHashMap(u64, usize).init(allocator);
    defer {
        counts.deinit();
    }

    for (partials) |a| {
        const result = try counts.getOrPut(a);
        if (result.found_existing) {
            result.value_ptr.* += 1;
        } else {
            result.value_ptr.* = 1;
        }
    }

    // Compute Shannon entropy: H = -Σ p_i * log2(p_i)
    const n_f: f64 = @floatFromInt(partials.len);
    var entropy: f64 = 0.0;
    var iter = counts.iterator();

    while (iter.next()) |entry| {
        const count_f: f64 = @floatFromInt(entry.value_ptr.*);
        const p = count_f / n_f;
        if (p > 0) {
            const log2_p = std.math.log2(p);
            entropy -= p * log2_p;
        }
    }

    return entropy;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/// Analyze zeta spacings with full CF battery
pub fn analyzeZetaSpacings(allocator: std.mem.Allocator, zeros: *const zeta_import.ZerosData) !ZetaCFResult {
    // Compute spacings
    const spacings_ptr = try allocator.create(zeta_spacing.Spacings);
    spacings_ptr.* = try zeta_spacing.computeSpacings(allocator, zeros);

    // Compute CF statistics
    const cf_stats = try computeSpacingCFStats(allocator, spacings_ptr, 1000);

    // Compare to GUE
    const gue_comparison = try zeta_spacing.compareVsGUE(spacings_ptr, allocator);

    // Determine verdict
    const verdict = determineVerdict(&cf_stats, &gue_comparison);

    return ZetaCFResult{
        .spacings = spacings_ptr,
        .cf_stats = cf_stats,
        .gue_comparison = gue_comparison,
        .verdict = verdict,
    };
}

/// Determine verdict based on CF stats and GUE comparison
fn determineVerdict(cf_stats: *const CFStats, gue: *const zeta_spacing.GUEComparison) ZetaVerdict {
    // If GUE consistent and CF looks generic
    if (gue.ks_p_value > 0.05 and cf_stats.mu < 2.5) {
        return .gue_consistent;
    }

    // If CF looks anomalous
    if (cf_stats.mu > 3.0 or cf_stats.max_partial > 1000) {
        return .anomalous;
    }

    // If generic CF but GUE inconclusive
    if (cf_stats.mu < 2.3) {
        return .generic_transcendental;
    }

    return .inconclusive;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND: Full CF analysis
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runZetaCFCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║      ZETA CF — Continued Fraction Analysis            ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ GOLD, RESET });

    if (args.len < 1) {
        std.debug.print("USAGE:\n", .{});
        std.debug.print("  tri math zeta-cf <zeros_file>   Full CF analysis of spacings\n", .{});
        std.debug.print("  tri math zeta-cf --hardcoded    Use first 100 hardcoded zeros\n", .{});
        std.debug.print("  tri math zeta-cf --synthetic N  Use synthetic zeros\n\n", .{});
        return;
    }

    const arg = args[0];

    // Load zeros
    const zeros = if (std.mem.eql(u8, arg, "--hardcoded")) blk: {
        std.debug.print("{s}Loading first 100 hardcoded Odlyzko zeros...{s}\n", .{ CYAN, RESET });
        const data = try zeta_import.loadHardcodedZeros(allocator);
        const ptr = try allocator.create(zeta_import.ZerosData);
        ptr.* = data;
        break :blk ptr;
    } else if (std.mem.eql(u8, arg, "--synthetic")) blk: {
        const n_zeros = if (args.len >= 2)
            try std.fmt.parseInt(usize, args[1], 10)
        else
            10000;

        std.debug.print("{s}Generating {d} synthetic zeros...{s}\n", .{ CYAN, n_zeros, RESET });
        const data = try zeta_import.generateSyntheticZeros(allocator, n_zeros);
        const ptr = try allocator.create(zeta_import.ZerosData);
        ptr.* = data;
        break :blk ptr;
    } else blk: {
        std.debug.print("{s}Loading zeros from: {s}{s}\n", .{ CYAN, arg, RESET });
        const data = try zeta_import.loadOdlyzkoZeros(allocator, arg);
        const ptr = try allocator.create(zeta_import.ZerosData);
        ptr.* = data;
        break :blk ptr;
    };

    // Run analysis
    std.debug.print("\n{s}Running CF analysis...{s}\n", .{ CYAN, RESET });
    const result = try analyzeZetaSpacings(allocator, zeros);

    // Print results
    std.debug.print("\n{s}CF STATISTICS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Irrationality μ:     {d:.6}\n", .{result.cf_stats.mu});
    std.debug.print("  Khinchin K:          {d:.6}  (expected: 2.685)\n", .{result.cf_stats.khinchin_k});
    std.debug.print("  Entropy:             {d:.4} bits\n", .{result.cf_stats.entropy});
    std.debug.print("  Max partial:         {d}\n", .{result.cf_stats.max_partial});
    std.debug.print("  Mean partial:        {d:.4}\n", .{result.cf_stats.mean_partial});

    std.debug.print("\n{s}GUE COMPARISON:{s}\n", .{ CYAN, RESET });
    std.debug.print("  KS statistic:        {d:.6}\n", .{result.gue_comparison.ks_statistic});
    std.debug.print("  p-value:             {d:.6}\n", .{result.gue_comparison.ks_p_value});

    const verdict_color = switch (result.verdict) {
        .generic_transcendental => GREEN,
        .gue_consistent => GREEN,
        .anomalous => RED,
        .inconclusive => GOLD,
    };
    std.debug.print("\n{s}FINAL VERDICT:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}{s}{s}\n", .{ verdict_color, result.verdict.format(), RESET });

    // Sample CFs
    std.debug.print("\n{s}SAMPLE CFs (first 10 spacings):{s}\n", .{ CYAN, RESET });
    const sample_count = @min(10, result.spacings.count);
    for (0..sample_count) |i| {
        const spacing = result.spacings.values[i];
        const cf = try expandSpacingCF(allocator, spacing, 20);
        defer cf.deinit(allocator);

        std.debug.print("  s[{d}] = {d:.6} → CF: ", .{ i, spacing });
        if (cf.partials.len > 0) {
            std.debug.print("[{d}", .{cf.partials[0]});
            const show_len = @min(5, cf.partials.len);
            for (1..show_len) |j| {
                std.debug.print("; {d}", .{cf.partials[j]});
            }
            if (cf.partials.len > 5) {
                std.debug.print("; ... ({d} terms)", .{cf.partials.len});
            }
            std.debug.print("]\n", .{});
        } else {
            std.debug.print("[?]\n", .{});
        }
    }

    std.debug.print("\n{s}STATUS: Analysis complete{s}\n", .{ GREEN, RESET });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// REFERENCES
// ═══════════════════════════════════════════════════════════════════════════════
//
// [1] A. Khinchin, "Continued Fractions", 1964
// [2] A. M. Odlyzko, "The 10^20-th zero of the Riemann zeta function", 1989
// [3] H. Montgomery, "The pair correlation of zeros of the zeta function", 1973
//
// ═══════════════════════════════════════════════════════════════════════════════
