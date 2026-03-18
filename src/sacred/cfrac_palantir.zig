// ═══════════════════════════════════════════════════════════════════════════════
// PALANTIR PIPELINE v1.1 — Consolidated Implementation
// All 6 stages of continued fraction analysis in one file
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const sacred = @import("sacred.zig");
const v11 = @import("cfrac_palantir_v11.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const ResolveResult = struct {
    value: f64,
    expression: []const u8,
};

pub fn resolveFormula(formula_id: []const u8) !ResolveResult {
    if (std.mem.eql(u8, formula_id, "phi")) {
        return ResolveResult{ .value = sacred.PHI, .expression = "φ" };
    } else if (std.mem.eql(u8, formula_id, "pi")) {
        return ResolveResult{ .value = sacred.PI, .expression = "π" };
    } else if (std.mem.eql(u8, formula_id, "e")) {
        return ResolveResult{ .value = sacred.E, .expression = "e" };
    } else if (std.mem.eql(u8, formula_id, "sqrt2")) {
        return ResolveResult{ .value = std.math.sqrt2, .expression = "√2" };
    } else if (std.mem.eql(u8, formula_id, "omega_dm")) {
        return ResolveResult{ .value = (sacred.PHI * sacred.PHI) / (sacred.PI * sacred.PI), .expression = "φ²/π²" };
    } else if (std.mem.eql(u8, formula_id, "v_cb")) {
        return ResolveResult{ .value = 1.0 / (3.0 * sacred.PI * sacred.PHI * sacred.PHI), .expression = "1/(3πφ²)" };
    } else {
        const value = try std.fmt.parseFloat(f64, formula_id);
        return ResolveResult{ .value = value, .expression = formula_id };
    }
}

pub fn expandCF(allocator: std.mem.Allocator, value: f64, max_depth: usize) ![]u64 {
    var partials = try allocator.alloc(u64, max_depth);
    var remaining = value;
    var depth: usize = 0;

    while (depth < max_depth) : (depth += 1) {
        const a = @floor(remaining);
        if (a < 0 or a > 1e12) break;
        const a_int: u64 = @intFromFloat(a);
        partials[depth] = a_int;

        const frac = remaining - a;
        if (frac < 1e-15) break;

        remaining = 1.0 / frac;
        if (!std.math.isFinite(remaining)) break;
    }

    return allocator.realloc(partials, depth);
}

pub const CFStats = struct {
    khinchin: f64,
    entropy: f64,
    max_pq: u64,
    gk_chi2: f64,
    is_periodic: bool,
    irrationality_mu: f64, // IRRATIONALITY MEASURE (v1.1)
};

pub const Convergent = struct {
    k: usize,
    p: i128,
    q: i128,
    value: f64,
    error_val: f64,
    mu_k: f64,
};

pub const PrimeFactorization = struct {
    q: i128,
    factors: []const PrimeFactor,
    is_smooth: bool,
    largest_prime: i64,
};

pub const PrimeFactor = struct {
    prime: i64,
    exponent: u32,
};

// Helper function to format prime factorization locally (Zig 0.15 compatible)
fn formatFactorizationLocal(factors: []const PrimeFactor) void {
    if (factors.len == 0) {
        std.debug.print("1", .{});
        return;
    }
    for (factors, 0..) |f, i| {
        if (i > 0) std.debug.print(" x ", .{});
        std.debug.print("{d}^{d}", .{ f.prime, f.exponent });
    }
}

pub fn computeCFStats(partials: []const u64) CFStats {
    // Khinchin
    var log_sum: f64 = 0;
    var count: usize = 0;
    var max_pq: u64 = 0;

    for (partials) |p| {
        if (p > 0) {
            log_sum += std.math.log(f64, std.math.e, @floatFromInt(p));
            count += 1;
        }
        if (p > max_pq) max_pq = p;
    }

    const khinchin = if (count > 0) @exp(log_sum / @as(f64, @floatFromInt(count))) else 0;

    // Entropy
    var counts = [1]f64{0} ** 101;
    for (partials) |p| {
        if (p < 101) counts[p] += 1 else counts[100] += 1;
    }
    const total: f64 = @floatFromInt(partials.len);
    var entropy: f64 = 0;
    for (counts) |c| {
        if (c > 0) {
            const prob = c / total;
            if (prob > 1e-10) entropy -= prob * std.math.log2(prob);
        }
    }

    // Gauss-Kuzmin
    var gk_counts = [_]u64{0} ** 5;
    for (partials) |p| {
        if (p == 0) continue;
        const idx = @min(4, p -| 1);
        gk_counts[idx] += 1;
    }
    const gk_expected = [_]f64{ 0.4150, 0.1699, 0.0931, 0.0588, 1.0 - 0.4150 - 0.1699 - 0.0931 - 0.0588 };
    var gk_chi2: f64 = 0;
    for (0..5) |i| {
        const observed: f64 = @floatFromInt(gk_counts[i]);
        const expected_f = gk_expected[i] * total;
        if (expected_f > 0.5) {
            const diff = observed - expected_f;
            gk_chi2 += diff * diff / expected_f;
        }
    }

    // Periodicity check
    var is_periodic = false;
    if (partials.len >= 6) {
        var all_ones = true;
        for (partials) |p| {
            if (p != 1) {
                all_ones = false;
                break;
            }
        }
        is_periodic = all_ones;
    }

    return .{
        .khinchin = khinchin,
        .entropy = entropy,
        .max_pq = max_pq,
        .gk_chi2 = gk_chi2,
        .is_periodic = is_periodic,
        .irrationality_mu = 0.0, // Will be updated by computeConvergents
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERGENTS + PRIME FACTORIZATION (v1.1)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn computeConvergents(
    allocator: std.mem.Allocator,
    partials: []const u64,
    target: f64,
) !struct { convergents: []Convergent, factors: []PrimeFactorization, mu_estimate: f64 } {
    var convs = try std.ArrayList(Convergent).initCapacity(allocator, partials.len);
    var facts = try std.ArrayList(PrimeFactorization).initCapacity(allocator, partials.len);

    var p_prev_prev: i128 = 0;
    var p_prev: i128 = 1;
    var q_prev_prev: i128 = 1;
    var q_prev: i128 = 0;

    var max_mu: f64 = 0.0;

    for (partials, 0..) |a_u, k| {
        const a_big: i128 = @intCast(a_u);

        const p_mul = @mulWithOverflow(p_prev, a_big);
        if (p_mul[1] != 0) break;
        const p_add = @addWithOverflow(p_mul[0], p_prev_prev);
        if (p_add[1] != 0) break;
        const p_k = p_add[0];

        const q_mul = @mulWithOverflow(q_prev, a_big);
        if (q_mul[1] != 0) break;
        const q_add = @addWithOverflow(q_mul[0], q_prev_prev);
        if (q_add[1] != 0) break;
        const q_k = q_add[0];

        if (q_k == 0) break;

        const p_f: f64 = @floatFromInt(p_k);
        const q_f: f64 = @floatFromInt(q_k);
        const approx = p_f / q_f;
        const err = @abs(target - approx);

        // Local irrationality measure: μ_k = log(q_k) / log(|α - p_k/q_k|)
        const mu_k: f64 = if (err > 1e-300)
            @log(@as(f64, @floatFromInt(q_k))) / @log(err)
        else
            0.0;

        if (mu_k > max_mu and mu_k < 100.0) {
            max_mu = mu_k;
        }

        try convs.append(allocator, Convergent{
            .k = k,
            .p = p_k,
            .q = q_k,
            .value = approx,
            .error_val = err,
            .mu_k = mu_k,
        });

        // Prime factorization of q_k (only if fits in u64)
        const q_u_opt = @abs(q_k);
        const q_u: u64 = if (q_u_opt > std.math.maxInt(u64))
            std.math.maxInt(u64) // Skip factorization if too large
        else
            @intCast(q_u_opt);

        var factors: []PrimeFactor = &[_]PrimeFactor{};
        var max_prime: i64 = 0;
        var is_smooth = false;

        if (q_u_opt <= std.math.maxInt(u64)) {
            factors = try primeFactorize(allocator, q_u);
            for (factors) |f| {
                if (@as(i64, f.prime) > max_prime) max_prime = f.prime;
                if (f.prime > 1000) is_smooth = false;
            }
            is_smooth = max_prime <= 1000;
        }

        try facts.append(allocator, PrimeFactorization{
            .q = q_k,
            .factors = factors,
            .is_smooth = is_smooth,
            .largest_prime = max_prime,
        });

        p_prev_prev = p_prev;
        p_prev = p_k;
        q_prev_prev = q_prev;
        q_prev = q_k;
    }

    return .{
        .convergents = try convs.toOwnedSlice(allocator),
        .factors = try facts.toOwnedSlice(allocator),
        .mu_estimate = max_mu,
    };
}

fn primeFactorize(allocator: std.mem.Allocator, n: u64) ![]PrimeFactor {
    var factors = try std.ArrayList(PrimeFactor).initCapacity(allocator, 16);

    var m = n;
    var d: u64 = 2;

    while (d * d <= m) {
        if (m % d == 0) {
            var exp: u32 = 0;
            while (m % d == 0) {
                m /= d;
                exp += 1;
            }
            try factors.append(allocator, PrimeFactor{
                .prime = @intCast(d),
                .exponent = exp,
            });
        }
        d += if (d == 2) 1 else 2;
    }

    if (m > 1) {
        try factors.append(allocator, PrimeFactor{
            .prime = @intCast(m),
            .exponent = 1,
        });
    }

    return factors.toOwnedSlice(allocator);
}

pub const Classification = enum {
    noble,
    quadratic,
    transcendental,
    generic,
    anomalous,
};

pub fn classifyNumber(stats: CFStats) Classification {
    if (stats.is_periodic) return .noble;
    if (stats.max_pq < 10) return .quadratic;
    if (stats.khinchin < 0.6) return .noble;
    if (stats.khinchin > 3.0) return .generic;
    return .transcendental;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

fn runExpand(allocator: std.mem.Allocator, formula_id: []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const RESET = "\x1b[0m";

    const resolved = try resolveFormula(formula_id);
    const partials = try expandCF(allocator, resolved.value, 1000);
    defer allocator.free(partials);

    std.debug.print("\n{s}PALANTIR Stage 1 — EXTRACT: CF expansion{s}\n\n", .{ CYAN, RESET });
    std.debug.print("Target: {s} = {d:.15}\n", .{ resolved.expression, resolved.value });
    std.debug.print("Depth: {d} terms\n", .{partials.len});
    std.debug.print("CF: [{d}", .{partials[0]});
    const show = @min(10, partials.len);
    for (partials[1..show]) |p| std.debug.print(",{d}", .{p});
    std.debug.print(",...]\n\n", .{});
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

fn runStats(allocator_: std.mem.Allocator, formula_id: []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const YELLOW = "\x1b[93m";
    const RED = "\x1b[31m";
    const RESET = "\x1b[0m";

    const resolved = try resolveFormula(formula_id);
    const partials = try expandCF(std.heap.page_allocator, resolved.value, 500);

    var stats = computeCFStats(partials);

    // Compute convergents to get q_k for irrationality measure
    var q_vals = try std.ArrayList(u128).initCapacity(allocator_, 100);
    defer q_vals.deinit(allocator_);

    var p_prev_prev: i128 = 0;
    var p_prev: i128 = 1;
    var q_prev_prev: i128 = 1;
    var q_prev: i128 = 0;

    for (partials) |a_u| {
        const a_big: i128 = @intCast(a_u);

        const p_mul = @mulWithOverflow(p_prev, a_big);
        if (p_mul[1] != 0) break;
        const p_add = @addWithOverflow(p_mul[0], p_prev_prev);
        if (p_add[1] != 0) break;

        const q_mul = @mulWithOverflow(q_prev, a_big);
        if (q_mul[1] != 0) break;
        const q_add = @addWithOverflow(q_mul[0], q_prev_prev);
        if (q_add[1] != 0) break;
        const q_k = q_add[0];

        if (q_k > 0) {
            try q_vals.append(allocator_, @intCast(q_k));
        }

        p_prev_prev = p_prev;
        p_prev = p_add[0];
        q_prev_prev = q_prev;
        q_prev = q_k;
    }

    // IRRATIONALITY MEASURE (v1.1)
    const mu = v11.irrationality_measure(partials, q_vals.items, q_vals.items.len);
    stats.irrationality_mu = mu;

    const class_str = switch (classifyNumber(stats)) {
        .noble => "NOBLE (φ-type)",
        .quadratic => "QUADRATIC",
        .transcendental => "TRANSCENDENTAL",
        .generic => "GENERIC",
        .anomalous => "ANOMALOUS",
    };

    std.debug.print("\n{s}PALANTIR Stage 2 — CLASSIFY: 8 Diagnostics (v1.1){s}\n\n", .{ CYAN, RESET });
    std.debug.print("Target: {s} = {d:.15}\n\n", .{ resolved.expression, resolved.value });

    const k_color = if (@abs(stats.khinchin - 2.685) < 0.3) GREEN else YELLOW;
    std.debug.print("  Khinchin K: {d:.4} {s}(expected: 2.685){s}\n", .{ stats.khinchin, k_color, RESET });

    const gk_color = if (stats.gk_chi2 < 9.49) GREEN else YELLOW;
    std.debug.print("  Gauss-Kuzmin χ²: {d:.3} {s}(p > 0.05 if < 9.49){s}\n", .{ stats.gk_chi2, gk_color, RESET });

    const p_color = if (stats.is_periodic) GREEN else YELLOW;
    std.debug.print("  Periodicity: {s}{s}{s}\n", .{ p_color, if (stats.is_periodic) "YES (φ-like)" else "NO", RESET });

    std.debug.print("  Max PQ: {d}\n", .{stats.max_pq});
    std.debug.print("  Entropy: {d:.3} bits\n", .{stats.entropy});

    // IRRATIONALITY MEASURE (v1.1)
    const mu_color = if (mu < 2.3) RED else if (mu < 3.0) YELLOW else GREEN;
    std.debug.print("  Irrationality μ: {s}{d:.4}{s} ", .{ mu_color, mu, RESET });
    // Note: print_mu_verdict call removed - std.io.getStdErr() not available in Zig 0.15
    // TODO: implement alternative output method
    std.debug.print("\n", .{});

    std.debug.print("\n  Classification: {s}\n\n", .{class_str});
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });

    std.heap.page_allocator.free(partials);
}

fn runVerdict(allocator_: std.mem.Allocator, formula_id: []const u8) !void {
    _ = allocator_;
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const YELLOW = "\x1b[93m";
    const MAGENTA = "\x1b[35m";
    const RED = "\x1b[31m";
    const GREEN = "\x1b[32m";
    const RESET = "\x1b[0m";

    const resolved = try resolveFormula(formula_id);
    const partials = try expandCF(std.heap.page_allocator, resolved.value, 500);

    var stats = computeCFStats(partials);

    // Compute convergents to get irrationality measure
    const conv_data = computeConvergents(std.heap.page_allocator, partials, resolved.value) catch |e| {
        std.heap.page_allocator.free(partials);
        return e;
    };
    defer {
        std.heap.page_allocator.free(conv_data.convergents);
        for (conv_data.factors) |*f| {
            std.heap.page_allocator.free(f.factors);
        }
        std.heap.page_allocator.free(conv_data.factors);
    }

    stats.irrationality_mu = conv_data.mu_estimate;
    const classification = classifyNumber(stats);

    std.debug.print("\n{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}║         PALANTIR Stage 6 — VERDICT: FINAL ANALYSIS (v1.1)    ║{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    std.debug.print("  Target: {s} = {d:.15}\n\n", .{ resolved.expression, resolved.value });

    std.debug.print("  {s}METRICS:{s}\n", .{ YELLOW, RESET });
    std.debug.print("    Khinchin K: {d:.4} (expected: 2.685)\n", .{stats.khinchin});
    std.debug.print("    Entropy: {d:.3} bits\n", .{stats.entropy});
    std.debug.print("    Irrationality μ: {d:.6}", .{stats.irrationality_mu});
    if (stats.irrationality_mu < 2.5) {
        std.debug.print(" {s}(GENERIC: μ≈2){s}\n", .{ RED, RESET });
    } else if (stats.irrationality_mu < 5.0) {
        std.debug.print(" {s}(MODERATE: μ>2){s}\n", .{ YELLOW, RESET });
    } else {
        std.debug.print(" {s}(EXCEPTIONAL: μ>>2){s}\n", .{ GREEN, RESET });
    }

    std.debug.print("\n  {s}FINAL VERDICT:{s}\n", .{ MAGENTA, RESET });

    // Enhanced verdict using μ
    const verdict = if (stats.irrationality_mu > 5.0 or classification == .noble)
        "EXCEPTIONAL — Strong mathematical structure detected"
    else if (stats.irrationality_mu > 2.5 or classification == .quadratic)
        "SPECIAL — Some non-generic properties found"
    else if (stats.irrationality_mu < 2.5 and classification == .generic)
        "GENERIC — No special CF structure (μ≈2)"
    else
        "TRANSCENDENTAL — Non-algebraic";

    const verdict_color = if (stats.irrationality_mu > 2.5 or classification == .noble or classification == .quadratic)
        "\x1b[32m" // GREEN
    else if (stats.irrationality_mu < 2.5)
        "\x1b[31m" // RED
    else
        "\x1b[93m"; // YELLOW

    std.debug.print("    {s}{s}{s}\n\n", .{ verdict_color, verdict, RESET });

    std.debug.print("  {s}INTERPRETATION:{s}\n", .{ YELLOW, RESET });
    if (stats.irrationality_mu < 2.5) {
        std.debug.print("    φ²/π² appears GENERIC with respect to continued fractions.\n", .{});
        std.debug.print("    This DOES NOT support the hypothesis of special structure.\n", .{});
        std.debug.print("    Result aligns with Planck PR4 tension: formula may be\n", .{});
        std.debug.print("    coincidental rather than fundamental.\n\n", .{});
    } else if (stats.irrationality_mu > 5.0) {
        std.debug.print("    φ²/π² shows EXCEPTIONAL CF structure.\n", .{});
        std.debug.print("    This SUPPORTS special arithmetic hypothesis.\n\n", .{});
    } else {
        std.debug.print("    φ²/π² shows SOME non-generic properties.\n", .{});
        std.debug.print("    Further investigation needed.\n\n", .{});
    }

    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });

    std.heap.page_allocator.free(partials);
}

pub fn runCFracExpandCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("USAGE: tri math cfrac-expand <formula_id>\n", .{});
        return;
    }
    try runExpand(allocator, args[0]);
}

pub fn runCFracStatsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("USAGE: tri math cfrac-stats <formula_id>\n", .{});
        return;
    }
    try runStats(allocator, args[0]);
}

pub fn runCFracCompareCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("USAGE: tri math cfrac-compare <formula_id>\n", .{});
        return;
    }
    try runStats(allocator, args[0]);
}

pub fn runCFracApproxCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const YELLOW = "\x1b[93m";
    const RESET = "\x1b[0m";

    if (args.len < 1) {
        std.debug.print("USAGE: tri math cfrac-approx <formula_id>\n", .{});
        return;
    }

    const resolved = try resolveFormula(args[0]);
    const partials = try expandCF(allocator, resolved.value, 500);
    defer allocator.free(partials);

    const conv_data = try computeConvergents(allocator, partials, resolved.value);
    defer {
        allocator.free(conv_data.convergents);
        for (conv_data.factors) |*f| {
            allocator.free(f.factors);
        }
        allocator.free(conv_data.factors);
    }

    // Scan for Fibonacci numbers in denominators (v1.1)
    var q_vals = try std.ArrayList(i128).initCapacity(allocator, @intCast(conv_data.convergents.len));
    defer q_vals.deinit(allocator);
    for (conv_data.convergents) |conv| {
        try q_vals.append(allocator, conv.q);
    }
    const fib_scan = try v11.scan_fibonacci(allocator, q_vals.items);
    defer fib_scan.deinit(allocator);

    std.debug.print("\n{s}PALANTIR Stage 3 — APPROX: Convergents + Prime Factors (v1.1){s}\n\n", .{ CYAN, RESET });
    std.debug.print("Target: {s} = {d:.15}\n", .{ resolved.expression, resolved.value });
    std.debug.print("Convergents: {d}\n\n", .{conv_data.convergents.len});

    // Show last 5 convergents with prime factorization and Fibonacci check
    std.debug.print("LAST 5 CONVERGENTS (p_k/q_k):\n", .{});
    const start_idx = if (conv_data.convergents.len > 5) conv_data.convergents.len - 5 else 0;
    for (start_idx..conv_data.convergents.len) |i| {
        const conv = conv_data.convergents[i];
        const fact = conv_data.factors[i];
        const abs_q = @abs(conv.q);
        const is_fib = abs_q <= std.math.maxInt(u64) and v11.is_fibonacci(@intCast(abs_q));

        std.debug.print("  [{d:3}] {d}/{d} = {d:.15}\n", .{ conv.k, conv.p, conv.q, conv.value });
        std.debug.print("       q_k = ", .{});
        formatFactorizationLocal(fact.factors);
        if (fact.is_smooth) std.debug.print(" {s}[1000-smooth]{s}", .{ GREEN, RESET });
        if (is_fib) std.debug.print(" {s}[FIBONACCI]{s}", .{ YELLOW, RESET });
        std.debug.print("\n", .{});
    }

    std.debug.print("\n{s}FIBONACCI SCAN:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Found {d}/{d} Fibonacci hits: ", .{ fib_scan.hits, fib_scan.total });
    for (fib_scan.hit_indices, 0..) |idx, i| {
        if (i > 0) std.debug.print(", ", .{});
        std.debug.print("{d}", .{idx});
    }
    std.debug.print("\n", .{});

    std.debug.print("\n{s}IRRATIONALITY MEASURE μ ≈ {d:.6}{s}\n", .{ GOLD, conv_data.mu_estimate, RESET });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

pub fn runCFracDetectCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const YELLOW = "\x1b[93m";
    const RED = "\x1b[31m";
    const RESET = "\x1b[0m";

    if (args.len < 1) {
        std.debug.print("USAGE: tri math cfrac-detect <formula_id>\n", .{});
        return;
    }

    const resolved = try resolveFormula(args[0]);
    const partials = try expandCF(allocator, resolved.value, 500);
    defer allocator.free(partials);

    // Skip a0 (integer part) for automatic sequence test
    const seq = partials[1..];

    std.debug.print("\n{s}PALANTIR Stage 4 — DETECT: k-Automatic Test (v1.1){s}\n\n", .{ CYAN, RESET });
    std.debug.print("Target: {s} = {d:.15}\n", .{ resolved.expression, resolved.value });
    std.debug.print("Sequence length: {d} terms\n\n", .{seq.len});

    const auto = try v11.automatic_test(seq, allocator);
    defer auto.deinit(allocator);

    std.debug.print("{s}SUBWORD COMPLEXITY:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  p(5)  = {d} distinct subwords\n", .{auto.p5});
    std.debug.print("  p(10) = {d} distinct subwords\n", .{auto.p10});
    std.debug.print("  Ratio p(10)/p(5) = {d:.3}\n\n", .{auto.ratio});

    const ratio_color = if (!auto.reliable) RED else if (auto.ratio > 2.5) GREEN else YELLOW;
    std.debug.print("{s}VERDICT:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}{s}{s}\n\n", .{ ratio_color, auto.verdict, RESET });

    if (!auto.reliable) {
        std.debug.print("{s}WARNING:{s} Need 200+ terms for reliable result.\n", .{ RED, RESET });
        std.debug.print("         Current sequence length ({d}) is INCONCLUSIVE.\n", .{seq.len});
        std.debug.print("         Use mpfr/mpmath for extended precision.\n\n", .{});
    }

    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

pub fn runCFracVerdictCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("USAGE: tri math cfrac-verdict <formula_id>\n", .{});
        return;
    }
    try runVerdict(allocator, args[0]);
}

// φ² + 1/φ² = 3 = TRINITY
