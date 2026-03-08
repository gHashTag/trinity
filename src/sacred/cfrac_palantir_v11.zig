// ═══════════════════════════════════════════════════════════════════════════════
// PALANTIR v1.1 — ARITHMETIC STRUCTURE EXTENSIONS
// File: src/sacred/cfrac_palantir_v11.zig
// Extends: cfrac_palantir.zig (v1.0)
// Adds: Irrationality μ, Prime factorization, k-Automatic, Fibonacci detection
//
// REFERENCES:
//   - Roth's theorem (1955): algebraic irrationals have μ=2
//   - Khinchin's theorem: K → 2.685 for almost all α
//   - arXiv:2503.16330 (March 2025): p-adic transcendence
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 2+: Irrationality Measure μ
// Add to cfrac-stats after Khinchin K computation
// ═══════════════════════════════════════════════════════════════════════════════

/// μ = 1 + lim sup(ln(a_{k+1}) / ln(q_k))
/// For generic transcendental: μ = 2. For algebraic: μ = 2 (Roth).
/// μ > 2 indicates exceptional Diophantine approximability.
pub fn irrationality_measure(
    terms: []const u64,
    q_vals: []const u128,
    n: usize,
) f64 {
    var mu_max: f64 = 1.0;
    var k: usize = 1;
    while (k + 1 < n and k < q_vals.len and k < terms.len) : (k += 1) {
        const q_k = q_vals[k];
        const a_next = terms[k + 1];
        if (q_k > 1 and a_next > 0) {
            const ln_a = @log(@as(f64, @floatFromInt(@max(a_next, 1))));
            const ln_q = @log(@as(f64, @floatFromInt(q_k)));
            const mu_k = 1.0 + ln_a / ln_q;
            if (mu_k > mu_max) mu_max = mu_k;
        }
    }
    return mu_max;
}

pub const MuVerdict = enum {
    generic, // μ < 2.3
    elevated, // 2.3 ≤ μ < 3.0
    exceptional, // μ ≥ 3.0
};

pub fn classify_mu(mu: f64) MuVerdict {
    if (mu < 2.3) return .generic;
    if (mu < 3.0) return .elevated;
    return .exceptional;
}

pub fn print_mu_verdict(mu: f64, writer: anytype) !void {
    try writer.print("  Irrationality measure μ = {d:.4}\n", .{mu});
    switch (classify_mu(mu)) {
        .generic => try writer.print("  VERDICT: GENERIC (μ ≈ 2, typical transcendental)\n", .{}),
        .elevated => try writer.print("  VERDICT: SLIGHTLY ELEVATED — need more terms\n", .{}),
        .exceptional => try writer.print("  VERDICT: EXCEPTIONAL (μ >> 2) — special Diophantine properties!\n", .{}),
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 3+: Prime Factorization of q_k
// Add to cfrac-approx after convergent computation
// ═══════════════════════════════════════════════════════════════════════════════

pub const PrimePower = struct {
    prime: u64,
    exp: u8,
};

pub const FactorizationResult = struct {
    factors: []const PrimePower,
    count: usize,
    is_smooth: bool, // B-smooth for B=1000
    largest_prime: u64,
};

/// Trial division factorization for q_k denominators.
/// Sufficient for q_k up to ~10^15 (50 CF terms from float64).
pub fn prime_factorize(allocator: std.mem.Allocator, n: u64) !FactorizationResult {
    var factors = try std.ArrayList(PrimePower).initCapacity(allocator, 32);

    if (n <= 1) {
        return FactorizationResult{
            .factors = try factors.toOwnedSlice(allocator),
            .count = 0,
            .is_smooth = false,
            .largest_prime = 0,
        };
    }

    var val = n;
    var largest: u64 = 0;

    // Factor out 2
    if (val % 2 == 0) {
        var exp: u8 = 0;
        while (val % 2 == 0) : (exp += 1) {
            val /= 2;
        }
        try factors.append(allocator, .{ .prime = 2, .exp = exp });
        largest = 2;
    }

    // Odd factors
    var d: u64 = 3;
    while (d * d <= val) : (d += 2) {
        if (val % d == 0) {
            var exp: u8 = 0;
            while (val % d == 0) : (exp += 1) {
                val /= d;
            }
            try factors.append(allocator, .{ .prime = d, .exp = exp });
            if (d > largest) largest = d;
        }
    }
    if (val > 1) {
        try factors.append(allocator, .{ .prime = val, .exp = 1 });
        if (val > largest) largest = val;
    }

    const factors_slice = try factors.toOwnedSlice(allocator);
    const is_smooth = largest <= 1000;

    return FactorizationResult{
        .factors = factors_slice,
        .count = factors_slice.len,
        .is_smooth = is_smooth,
        .largest_prime = largest,
    };
}

pub fn format_factorization(factors: []const PrimePower, writer: anytype) !void {
    for (factors, 0..) |f, i| {
        if (i > 0) try writer.print(" x ", .{});
        try writer.print("{d}^{d}", .{ f.prime, f.exp });
    }
}

/// Check if n is a Fibonacci number using the property:
/// n is Fibonacci iff 5n²+4 or 5n²-4 is a perfect square.
pub fn is_fibonacci(n: u64) bool {
    if (n == 0) return true;
    const n2 = @as(u128, n) * @as(u128, n);
    const a = 5 * n2 + 4;
    const b = if (n2 >= 4) 5 * n2 - 4 else 0;
    return is_perfect_square(a) or is_perfect_square(b);
}

fn is_perfect_square(n: u128) bool {
    if (n == 0) return true;
    const s = math.sqrt(n);
    // Check if s*s == n without overflow
    const s_sq = @as(u256, s) * @as(u256, s);
    return s_sq == n;
}

pub const FibonacciSequence = struct {
    hits: usize,
    total: usize,
    hit_indices: []const usize,

    pub fn deinit(self: *const FibonacciSequence, allocator: std.mem.Allocator) void {
        allocator.free(self.hit_indices);
    }

    pub fn format(self: *const FibonacciSequence, writer: anytype) !void {
        try writer.print("{d}/{d} hits", .{ self.hits, self.total });
        if (self.hits > 0) {
            try writer.print(" at indices: ", .{});
            for (self.hit_indices, 0..) |idx, i| {
                if (i > 0) try writer.print(", ", .{});
                try writer.print("q_{d}", .{idx});
            }
        }
    }
};

/// Scan convergents for Fibonacci numbers in denominators.
pub fn scan_fibonacci(allocator: std.mem.Allocator, q_vals: []const i128) !FibonacciSequence {
    var hit_indices = try std.ArrayList(usize).initCapacity(allocator, 16);
    defer hit_indices.deinit(allocator);

    for (q_vals, 0..) |q, i| {
        if (q > 0 and q <= @as(i128, @intCast(std.math.maxInt(u64)))) {
            if (is_fibonacci(@intCast(q))) {
                try hit_indices.append(allocator, i);
            }
        }
    }

    const indices = try hit_indices.toOwnedSlice(allocator);

    return FibonacciSequence{
        .hits = indices.len,
        .total = q_vals.len,
        .hit_indices = indices,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 4+: k-Automatic Sequence Test
// Add to cfrac-detect after pattern detection
// ═══════════════════════════════════════════════════════════════════════════════

/// Subword complexity p(n) = distinct subwords of length n.
/// For k-automatic sequences: p(n) = O(n).
/// For random sequences: p(n) grows to min(|Σ|^n, N-n+1).
///
/// WARNING: Requires 500+ terms for reliable results.
/// With float64 (~50 terms), result is INCONCLUSIVE.
pub fn subword_complexity(
    seq: []const u64,
    window: usize,
    allocator: std.mem.Allocator,
) !usize {
    var seen = std.AutoHashMap(u64, void).init(allocator);
    defer seen.deinit();

    var i: usize = 0;
    while (i + window <= seq.len) : (i += 1) {
        var hash: u64 = 0xcbf29ce484222325; // FNV-1a offset
        for (seq[i..][0..window]) |val| {
            hash ^= val;
            hash *%= 0x100000001b3; // FNV prime
        }
        try seen.put(hash, {});
    }
    return seen.count();
}

pub const AutomaticTestResult = struct {
    p5: usize,
    p10: usize,
    ratio: f64,
    reliable: bool,
    verdict: []const u8,

    pub fn deinit(self: *const AutomaticTestResult, allocator: std.mem.Allocator) void {
        allocator.free(self.verdict);
    }
};

/// Determine if CF partial quotients are k-automatic.
/// Returns growth ratio p(2n)/p(n) at n=5.
/// automatic: ratio ≈ 2.0, random: ratio >> 2.0
/// CAUTION: unreliable with < 200 terms.
pub fn automatic_test(
    seq: []const u64,
    allocator: std.mem.Allocator,
) !AutomaticTestResult {
    const min_reliable = 200;
    const reliable = seq.len >= min_reliable;

    const p5 = try subword_complexity(seq, 5, allocator);
    const p10 = try subword_complexity(seq, 10, allocator);

    const ratio = if (p5 > 0)
        @as(f64, @floatFromInt(p10)) / @as(f64, @floatFromInt(p5))
    else
        0.0;

    const verdict = if (!reliable)
        try std.fmt.allocPrint(allocator, "INCONCLUSIVE (need 200+ terms, got {d})", .{seq.len})
    else if (ratio < 1.5)
        try allocator.dupe(u8, "SUBLINEAR growth (possibly automatic)")
    else if (ratio < 2.5)
        try allocator.dupe(u8, "LINEAR growth (consistent with automatic)")
    else
        try allocator.dupe(u8, "SUPERLINEAR growth (non-automatic/random)");

    return AutomaticTestResult{
        .p5 = p5,
        .p10 = p10,
        .ratio = ratio,
        .reliable = reliable,
        .verdict = verdict,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 5: Updated Verdict (cfrac-verdict)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ArithmeticProfile = struct {
    mu: f64,
    khinchin_k: f64,
    auto_ratio: f64,
    auto_reliable: bool,
    fibonacci_hits: usize,
    fibonacci_total: usize,

    pub fn verdict(self: @This()) []const u8 {
        // Count generic metrics
        var generic: u8 = 0;
        var special: u8 = 0;

        if (self.mu < 2.3) generic += 1 else special += 1;

        if (@abs(self.khinchin_k - 2.685) < 1.0) generic += 1 else special += 1;

        if (self.auto_reliable) {
            if (self.auto_ratio > 2.5) generic += 1 else special += 1;
        }

        // Fibonacci: significant if > 20% of denominators
        const fib_pct = if (self.fibonacci_total > 0)
            @as(f64, @floatFromInt(self.fibonacci_hits)) /
                @as(f64, @floatFromInt(self.fibonacci_total))
        else
            0.0;
        if (fib_pct < 0.2) generic += 1 else special += 1;

        if (special == 0) return "ARITHMETICALLY GENERIC";
        if (special == 1) return "MOSTLY GENERIC (1 anomaly)";
        if (special >= 2) return "ANOMALOUS — investigate further";
        return "UNKNOWN";
    }

    pub fn format(self: *const ArithmeticProfile, writer: anytype) !void {
        try writer.print("\n{s}─ ARITHMETIC PROFILE ─{s}\n\n", .{ "═", "═" });
        try writer.print("  μ = {d:.4} {s}\n", .{ self.mu, if (self.mu < 2.3) "(generic)" else "(elevated)" });
        try writer.print("  K = {d:.4} {s}\n", .{ self.khinchin_k, if (@abs(self.khinchin_k - 2.685) < 1.0) "(generic)" else "(anomaly)" });

        const auto_label = if (!self.auto_reliable) "INCONCLUSIVE" else if (self.auto_ratio > 2.5) "generic" else "suspicious";
        try writer.print("  p(10)/p(5) = {d:.3} ({s})\n", .{ self.auto_ratio, auto_label });

        const fib_pct = if (self.fibonacci_total > 0)
            @as(f64, @floatFromInt(self.fibonacci_hits)) * 100.0 /
                @as(f64, @floatFromInt(self.fibonacci_total))
        else
            0.0;
        try writer.print("  Fibonacci: {d}/{d} = {d:.1}% {s}\n", .{
            self.fibonacci_hits,                             self.fibonacci_total, fib_pct,
            if (fib_pct < 20) "(weak)" else "(significant)",
        });

        try writer.print("\n  {s}FINAL VERDICT: {s}{s}\n\n", .{ "══", self.verdict(), "══" });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION GUIDE
// ═══════════════════════════════════════════════════════════════════════════════
//
// In cfrac_palantir.zig, add:
//   const v11 = @import("cfrac_palantir_v11.zig");
//
// In runStats():
//   + const mu = v11.irrationality_measure(partials, q_vals, partials.len);
//   + try v11.print_mu_verdict(mu, std.io.getStdOut().writer());
//
// In runCFracApproxCommand():
//   + const fact = try v11.prime_factorize(allocator, @intCast(q_k));
//   + defer allocator.free(fact.factors);
//   + const is_fib = v11.is_fibonacci(@intCast(q_k));
//   + // print factorization and Fibonacci status
//
// In runCFracDetectCommand():
//   + const auto = try v11.automatic_test(partials, allocator);
//   + defer auto.deinit(allocator);
//   + // print ratio and reliability warning
//
// In runCFracVerdictCommand():
//   + const profile = v11.ArithmeticProfile{ ... };
//   + try profile.format(std.io.getStdOut().writer());
//
// ═══════════════════════════════════════════════════════════════════════════════

// φ² + 1/φ² = 3 = TRINITY
