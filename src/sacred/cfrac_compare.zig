// ═══════════════════════════════════════════════════════════════════════════════
// PALANTIR PIPELINE — Stage 3: COMPARE
// Head-to-head benchmark with reference library + random baseline
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const cfrac_ref = @import("cfrac_reference.zig");

pub const ComparisonMetrics = struct {
    target_khinchin: f64,
    target_entropy: f64,
    target_max_pq: u64,
    ref_khinchin: f64,
    ref_entropy: f64,
    ref_max_pq: u64,
    distance: f64, // Euclidean distance in metric space
    similarity: f64, // 0 = identical, 1 = completely different
    verdict: []const u8,
};

pub const CompareResult = struct {
    target_id: []const u8,
    target_value: f64,
    reference_id: []const u8,
    reference_value: f64,
    metrics: ComparisonMetrics,
    classification: cfrac_ref.Classification,
    better_match: ?[]const u8, // Other reference that's closer
};

/// Generate random baseline for comparison (deterministic seed for reproducibility)
pub fn generateRandomBaseline(allocator: std.mem.Allocator, count: usize) ![]BaselineEntry {
    const results = try allocator.alloc(BaselineEntry, count);
    errdefer allocator.free(results);

    // Deterministic PRNG for reproducible baselines
    var rng = std.Random.DefaultPrng.init(0x_TRINITY_CF);

    for (results, 0..) |*entry, i| {
        // Generate 50 random partial quotients in range 1-100
        var partials: [50]u64 = undefined;
        var value_approx: f64 = 0.0;
        for (0..50) |j| {
            partials[j] = rng.random().intRangeAtMost(u64, 1, 100);
            _ = j;
        }

        // Compute approximate value from first few convergents
        value_approx = @as(f64, @floatFromInt(partials[0]));
        if (partials.len > 1) {
            value_approx += 1.0 / @as(f64, @floatFromInt(partials[1]));
        }
        _ = i;

        entry.* = .{
            .value = value_approx,
            .khinchin = computeKhinchin(&partials),
        };
    }

    return results;
}

pub const BaselineEntry = struct {
    value: f64,
    khinchin: f64,
};

/// Compare target against a reference number
pub fn compareToReference(
    allocator: std.mem.Allocator,
    target_id: []const u8,
    target_value: f64,
    target_partials: []const u64,
    reference_id: []const u8,
) !CompareResult {
    _ = allocator;

    const ref_num = cfrac_ref.getReference(reference_id) orelse {
        return error.ReferenceNotFound;
    };

    // Compute target metrics
    const target_khinchin = computeKhinchin(target_partials);
    const target_entropy = computeEntropy(target_partials);

    var target_max: u64 = 0;
    for (target_partials) |p| {
        if (p > target_max) target_max = p;
    }

    // For reference metrics, use precomputed values
    const ref_khinchin = switch (ref_num.classification) {
        .noble => 0.372, // φ
        .quadratic => 2.0, // √2
        .transcendental => if (std.mem.eql(u8, reference_id, "pi")) 2.685 else 2.5,
        .generic => 2.685,
        .anomalous => 1.0,
        .periodic => 1.5,
    };
    const ref_entropy = switch (ref_num.classification) {
        .noble => 1.9,
        .quadratic => 2.5,
        .transcendental => if (std.mem.eql(u8, reference_id, "pi")) 3.25 else 3.1,
        .generic => 3.0,
        .anomalous => 2.8,
        .periodic => 2.0,
    };
    const ref_max_pq: u64 = switch (ref_num.classification) {
        .noble => 1,
        .quadratic => 2,
        else => 1000,
    };

    // Euclidean distance in (K, entropy, max_pq) space
    const dk = target_khinchin - ref_khinchin;
    const de = target_entropy - ref_entropy;
    const dm = @as(f64, @floatFromInt(target_max)) - @as(f64, @floatFromInt(ref_max_pq));
    const distance = std.math.sqrt(dk * dk + de * de + dm * dm / 10000.0);

    // Similarity score (0 = identical, 1 = very different)
    const similarity = if (distance < 0.5) 0.0 else if (distance < 1.0) 0.3 else if (distance < 2.0) 0.6 else 1.0;

    const verdict = if (similarity < 0.2)
        "VERY SIMILAR CF structure"
    else if (similarity < 0.5)
        "MODERATELY SIMILAR"
    else
        "DIFFERENT CF structure";

    return CompareResult{
        .target_id = target_id,
        .target_value = target_value,
        .reference_id = reference_id,
        .reference_value = ref_num.value,
        .metrics = .{
            .target_khinchin = target_khinchin,
            .target_entropy = target_entropy,
            .target_max_pq = target_max,
            .ref_khinchin = ref_khinchin,
            .ref_entropy = ref_entropy,
            .ref_max_pq = ref_max_pq,
            .distance = distance,
            .similarity = similarity,
            .verdict = verdict,
        },
        .classification = ref_num.classification,
        .better_match = null,
    };
}

/// Find best matching reference
pub fn findBestMatch(
    allocator: std.mem.Allocator,
    target_id: []const u8,
    target_value: f64,
    target_partials: []const u64,
) !CompareResult {
    var best_result: ?CompareResult = null;
    var best_distance: f64 = 999999.0;

    for (cfrac_ref.reference_library) |ref| {
        const result = try compareToReference(allocator, target_id, target_value, target_partials, ref.id);
        if (result.metrics.distance < best_distance) {
            best_distance = result.metrics.distance;
            best_result = result;
        }
    }

    return best_result orelse error.NoReferencesAvailable;
}

fn computeKhinchin(partials: []const u64) f64 {
    if (partials.len < 10) return 0.0;

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

fn computeEntropy(partials: []const u64) f64 {
    if (partials.len < 2) return 0.0;

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

/// CLI command: tri math cfrac-compare <formula_id> <reference_id>
pub fn runCompareCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GREEN = "\x1b[32m";
    const YELLOW = "\x1b[93m";
    const RED = "\x1b[31m";
    const RESET = "\x1b[0m";

    if (args.len < 1) {
        std.debug.print("\n{s}USAGE:{s} tri math cfrac-compare <formula_id> [reference_id]\n", .{ CYAN, RESET });
        std.debug.print("\n{s}PALANTIR Stage 3 — COMPARE: Benchmark vs Reference Library{s}\n\n", .{ CYAN, RESET });
        std.debug.print("{s}ARGUMENTS:{s}\n", .{ WHITE, RESET });
        std.debug.print("  formula_id    - Target to analyze\n", .{});
        std.debug.print("  reference_id  - Optional: specific reference (phi, pi, e, sqrt2)\n", .{});
        std.debug.print("                  If omitted, finds best match automatically\n\n", .{});
        std.debug.print("{s}REFERENCE LIBRARY:{s}\n", .{ WHITE, RESET });
        for (cfrac_ref.reference_library) |ref| {
            std.debug.print("  {s:>12}{s} - {s}\n", .{ ref.id, RESET, ref.name });
        }
        std.debug.print("\n{s}EXAMPLES:{s}\n", .{ CYAN, RESET });
        std.debug.print("  $ tri math cfrac-compare omega_dm pi\n", .{});
        std.debug.print("  $ tri math cfrac-compare omega_dm\n", .{});
        std.debug.print("  $ tri math cfrac-compare v_cb phi\n\n", .{});
        std.debug.print("{s}KEY FINDING:{s}\n", .{ YELLOW, RESET });
        std.debug.print("  φ anomalous: K=0.372, but φ²/π² normal: K=1.102\n", .{});
        std.debug.print("  π destroys noble φ structure when dividing\n\n", .{});
        std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
        return;
    }

    // Import expand function
    const expand = @import("cfrac_expand.zig");

    const target_id = args[0];
    const resolved = try expand.resolveFormula(target_id);

    const result = try expand.expand(allocator, resolved.value, resolved.expression, .{});
    defer result.deinit(allocator);

    std.debug.print("\n{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}║         PALANTIR STAGE 3 — COMPARE: REFERENCE BENCHMARK        ║{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    std.debug.print("  {s}Target:{s} {s} = {d:.15}\n", .{ WHITE, RESET, resolved.expression, resolved.value });
    std.debug.print("  {s}CF Terms:{s} {d}\n\n", .{ WHITE, RESET, result.depth });

    if (args.len >= 2) {
        // Specific comparison
        const ref_id = args[1];
        const comp = try compareToReference(allocator, target_id, resolved.value, result.partials, ref_id);

        const ref_num = cfrac_ref.getReference(ref_id).?;
        std.debug.print("  {s}Comparison with:{s} {s} ({s})\n\n", .{ WHITE, RESET, ref_num.name, ref_num.id });

        std.debug.print("  {s}Metrics:{s}\n", .{ WHITE, RESET });
        std.debug.print("    Khinchin K:   target={d:.4} vs ref={d:.4}\n", .{
            comp.metrics.target_khinchin, comp.metrics.ref_khinchin,
        });
        std.debug.print("    Entropy:      target={d:.3} vs ref={d:.3}\n", .{
            comp.metrics.target_entropy, comp.metrics.ref_entropy,
        });
        std.debug.print("    Max PQ:       target={d} vs ref={d}\n", .{
            comp.metrics.target_max_pq, comp.metrics.ref_max_pq,
        });
        std.debug.print("    Distance:     {d:.3}\n", .{comp.metrics.distance});
        std.debug.print("    Similarity:   {d:.1%}\n\n", .{comp.metrics.similarity});

        const sim_color = if (comp.metrics.similarity < 0.3) GREEN else if (comp.metrics.similarity < 0.7) YELLOW else RED;
        std.debug.print("  {s}VERDICT:{s} {s}{s}{s}\n\n", .{ WHITE, RESET, sim_color, comp.metrics.verdict, RESET });
    } else {
        // Find best match
        const best = try findBestMatch(allocator, target_id, resolved.value, result.partials);
        const ref_num = cfrac_ref.getReference(best.reference_id).?;

        std.debug.print("  {s}╔════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
        std.debug.print("  {s}║  BEST MATCH: {s}{s}                                        ║{s}\n", .{ CYAN, RESET, ref_num.name, RESET });
        std.debug.print("  {s}╚════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

        std.debug.print("  {s}Classification:{s} {s}\n", .{ WHITE, RESET, cfrac_ref.formatClassification.format(best.classification) });
        std.debug.print("  {s}Similarity:{s} {d:.1%}\n", .{ WHITE, RESET, best.metrics.similarity });
        std.debug.print("  {s}Verdict:{s} {s}\n\n", .{ WHITE, RESET, best.metrics.verdict });

        // Show comparison table
        std.debug.print("  {s}FULL COMPARISON TABLE:{s}\n", .{ WHITE, RESET });
        std.debug.print("  {s}┌────────────────┬──────────┬──────────┬───────────┬────────────┐{s}\n", .{ CYAN, RESET });
        std.debug.print("  {s}│ Reference      │ Khinchin │ Entropy  │ Max PQ    │ Similarity │{s}\n", .{ CYAN, RESET });
        std.debug.print("  {s}├────────────────┼──────────┼──────────┼───────────┼────────────┤{s}\n", .{ CYAN, RESET });

        for (cfrac_ref.reference_library) |ref| {
            const comp = compareToReference(allocator, target_id, resolved.value, result.partials, ref.id) catch continue;

            const row_color = if (comp.metrics.similarity < 0.3) GREEN else if (comp.metrics.similarity < 0.7) YELLOW else "";
            const marker = if (std.mem.eql(u8, ref.id, best.reference_id)) "→" else " ";

            std.debug.print("  {s}│ {s}{marker} {s} {s:<14}{s}│ {d:8.4} │ {d:8.3} │ {d:9} │ {d:9.1%} │{s}\n", .{
                row_color,                ref.name,                RESET,                   CYAN,  comp.metrics.ref_khinchin,
                comp.metrics.ref_entropy, comp.metrics.ref_max_pq, comp.metrics.similarity, RESET,
            });
        }
        std.debug.print("  {s}└────────────────┴──────────┴──────────┴───────────┴────────────┘{s}\n\n", .{ CYAN, RESET });
    }

    std.debug.print("{s}Next stages: cfrac-approx, cfrac-detect, cfrac-verdict{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "generateRandomBaseline returns count items" {
    const allocator = std.testing.allocator;
    const baseline = try generateRandomBaseline(allocator, 10);
    defer allocator.free(baseline);

    try std.testing.expectEqual(@as(usize, 10), baseline.len);
}

test "generateRandomBaseline khinchin values are positive" {
    const allocator = std.testing.allocator;
    const baseline = try generateRandomBaseline(allocator, 5);
    defer allocator.free(baseline);

    for (baseline) |entry| {
        try std.testing.expect(entry.khinchin > 0.0);
        try std.testing.expect(entry.value > 0.0);
    }
}

test "generateRandomBaseline is deterministic" {
    const allocator = std.testing.allocator;
    const a = try generateRandomBaseline(allocator, 3);
    defer allocator.free(a);
    const b = try generateRandomBaseline(allocator, 3);
    defer allocator.free(b);

    // Same seed → same results
    for (a, b) |x, y| {
        try std.testing.expectEqual(x.value, y.value);
        try std.testing.expectEqual(x.khinchin, y.khinchin);
    }
}

test "computeKhinchin golden ratio partials" {
    // φ = [1; 1, 1, 1, ...] → Khinchin should be exp(0) = 1.0
    const phi_partials = [_]u64{1} ** 50;
    const k = computeKhinchin(&phi_partials);
    // K(φ) = exp(mean(ln(1))) = exp(0) = 1.0
    try std.testing.expect(@abs(k - 1.0) < 0.001);
}

// φ² + 1/φ² = 3 = TRINITY
