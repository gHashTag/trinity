// ═══════════════════════════════════════════════════════════════════════════════
// DEGENERACY TEST — Blind Spot #1: Is Ω_DM = φ²/π² unique?
// ═══════════════════════════════════════════════════════════════════════════════
//
// QUESTION: How many formulas V = n×3^k×π^m×φ^p×e^q with C≤5 fall in Planck window?
//
// COMPLEXITY: C = |n| + |k| + |m| + |p| + |q| ≤ 5
// TARGET: Ω_c = 0.2597 ± 0.0026 (Planck PR4 2024, derived from Table 3)
//
// PR3 RESULT: Ω_c = 0.2642 ± 0.0026, φ²/π² = 0.2653 at 0.41σ (EXCELLENT)
// PR4 RESULT: Ω_c = 0.2597 ± 0.0026, φ²/π² = 0.2653 at 2.12σ (TENSION)
//
// STATUS: TENSION ⚠️ (2-3σ) — PR4 weakens but does not falsify.
//
// UPDATE (March 8, 2026): Planck PR4 (Tristram et al. 2024, A&A 682)
//   - Ω_ch² = 0.1188 ± 0.00121 (Table 3, TTTEEE)
//   - H0 = 67.64 ± 0.52 km/s/Mpc → h = 0.6764
//   - Ω_c = Ω_ch²/h² = 0.1188/0.4575 ≈ 0.2597
//   - φ²/π² moved from 0.41σ (PR3) to 2.12σ (PR4)
//   - 1.75σ downward shift in Ω_c from PR3 to PR4
//
// See: https://arxiv.org/abs/2309.10034 (Tristram et al. 2024)
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const sacred = @import("sacred.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Planck PR4 (2024) - Tristram et al., A&A 682
/// Source: Table 3, TTTEEE combination of https://arxiv.org/abs/2309.10034
/// Ω_ch² = 0.1188 ± 0.00121
/// H0 = 67.64 ± 0.52 km/s/Mpc → h = 0.6764
/// Ω_c = Ω_ch²/h² = 0.1188/0.4575 ≈ 0.2597
const Omega_dm_planck: f64 = 0.2597;
const Omega_dm_err: f64 = 0.0026;
const Omega_dm_h2_planck: f64 = 0.1188;
const Omega_dm_h2_err: f64 = 0.00121;
const h2_planck: f64 = 0.6764 * 0.6764; // = 0.4575

/// 1σ window: Ω_dm ∈ [0.2571, 0.2623]
const Omega_dm_min: f64 = Omega_dm_planck - Omega_dm_err;
const Omega_dm_max: f64 = Omega_dm_planck + Omega_dm_err;

/// 2σ window: Ω_dm ∈ [0.2545, 0.2649]
const Omega_dm_min_2sig: f64 = Omega_dm_planck - 2.0 * Omega_dm_err;
const Omega_dm_max_2sig: f64 = Omega_dm_planck + 2.0 * Omega_dm_err;

/// TRINITY candidate: Ω_DM = φ²/π²
const Omega_dm_trinity: f64 = (sacred.PHI * sacred.PHI) / (sacred.PI * sacred.PI);

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const FormulaParams = struct {
    n: i64,
    k: i64,
    m: i64,
    p: i64,
    q: i64,

    pub fn complexity(self: FormulaParams) i64 {
        const abs_n: i64 = if (self.n < 0) -self.n else self.n;
        const abs_k: i64 = if (self.k < 0) -self.k else self.k;
        const abs_m: i64 = if (self.m < 0) -self.m else self.m;
        const abs_p: i64 = if (self.p < 0) -self.p else self.p;
        const abs_q: i64 = if (self.q < 0) -self.q else self.q;
        return abs_n + abs_k + abs_m + abs_p + abs_q;
    }

    pub fn format(self: FormulaParams, allocator: std.mem.Allocator) ![]u8 {
        const n_str = try std.fmt.allocPrint(allocator, "{d}", .{self.n});
        const k_str = if (self.k >= 0) try std.fmt.allocPrint(allocator, "3^{d}", .{self.k}) else try std.fmt.allocPrint(allocator, "3^{{{d}}}", .{self.k});
        const m_str = if (self.m >= 0) try std.fmt.allocPrint(allocator, "π^{d}", .{self.m}) else try std.fmt.allocPrint(allocator, "π^{{{d}}}", .{self.m});
        const p_str = if (self.p >= 0) try std.fmt.allocPrint(allocator, "φ^{d}", .{self.p}) else try std.fmt.allocPrint(allocator, "φ^{{{d}}}", .{self.p});
        const q_str = if (self.q >= 0) try std.fmt.allocPrint(allocator, "e^{d}", .{self.q}) else try std.fmt.allocPrint(allocator, "e^{{{d}}}", .{self.q});

        const result = try std.fmt.allocPrint(allocator, "{s}×{s}×{s}×{s}×{s}", .{ n_str, k_str, m_str, p_str, q_str });

        allocator.free(n_str);
        allocator.free(k_str);
        allocator.free(m_str);
        allocator.free(p_str);
        allocator.free(q_str);

        return result;
    }

    pub fn formatCompact(self: FormulaParams, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "({d},{d},{d},{d},{d})", .{ self.n, self.k, self.m, self.p, self.q });
    }
};

pub const FormulaHit = struct {
    params: FormulaParams,
    value: f64,
    error_sigma: f64, // How many σ from Planck center
    expression: []const u8,

    pub fn format(self: *const FormulaHit, writer: anytype) !void {
        const delta = self.value - Omega_dm_planck;
        const delta_str = if (delta >= 0) "+" else "";
        try writer.print("V = {s} = {d:.6} (Δ = {s}{d:.6}, {d:.2}σ)", .{
            self.expression, self.value, delta_str, delta, self.error_sigma,
        });
    }
};

pub const DegeneracyResult = struct {
    total_generated: usize,
    one_sigma_hits: usize,
    two_sigma_hits: usize,
    hits: []FormulaHit, // Allocator-managed
    phi2_pi2_rank: ?usize, // Position of φ²/π² in sorted list

    pub fn deinit(self: *DegeneracyResult, allocator: std.mem.Allocator) void {
        for (self.hits) |*hit| {
            allocator.free(hit.expression);
        }
        if (self.hits.len > 0) {
            allocator.free(self.hits);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute V = n × 3^k × π^m × φ^p × e^q
pub fn computeV(params: FormulaParams) f64 {
    const n_val: f64 = @floatFromInt(params.n);
    const k_val: f64 = if (params.k >= 0)
        std.math.pow(f64, 3.0, @floatFromInt(params.k))
    else
        1.0 / std.math.pow(f64, 3.0, @floatFromInt(-params.k));
    const m_val: f64 = if (params.m >= 0)
        std.math.pow(f64, sacred.PI, @floatFromInt(params.m))
    else
        1.0 / std.math.pow(f64, sacred.PI, @floatFromInt(-params.m));
    const p_val: f64 = if (params.p >= 0)
        std.math.pow(f64, sacred.PHI, @floatFromInt(params.p))
    else
        1.0 / std.math.pow(f64, sacred.PHI, @floatFromInt(-params.p));
    const q_val: f64 = if (params.q >= 0)
        std.math.pow(f64, sacred.E, @floatFromInt(params.q))
    else
        1.0 / std.math.pow(f64, sacred.E, @floatFromInt(-params.q));

    return n_val * k_val * m_val * p_val * q_val;
}

/// Generate all (n,k,m,p,q) with complexity ≤ C_max
pub fn generateFormulas(allocator: std.mem.Allocator, C_max: i64) ![]FormulaParams {
    // Estimate: for C_max=5, roughly (2*C_max+1)^5 ≈ 11^5 ≈ 161,051 combinations
    // But many will have C > C_max, so actual is smaller
    var list = try std.ArrayList(FormulaParams).initCapacity(allocator, 100000);

    const n_min: i64 = -C_max;
    const n_max: i64 = C_max;

    var n: i64 = n_min;
    while (n <= n_max) : (n += 1) {
        if (n == 0) continue; // Skip n=0 (gives zero)

        var k: i64 = -C_max;
        while (k <= C_max) : (k += 1) {
            var m: i64 = -C_max;
            while (m <= C_max) : (m += 1) {
                var p: i64 = -C_max;
                while (p <= C_max) : (p += 1) {
                    var q: i64 = -C_max;
                    while (q <= C_max) : (q += 1) {
                        const params = FormulaParams{ .n = n, .k = k, .m = m, .p = p, .q = q };
                        if (params.complexity() <= C_max) {
                            try list.append(allocator, params);
                        }
                    }
                }
            }
        }
    }

    return list.toOwnedSlice(allocator);
}

/// Run degeneracy test: count formulas in Planck window
pub fn runDegeneracyTest(allocator: std.mem.Allocator, C_max: i64) !DegeneracyResult {
    const CYAN = "\x1b[36m";
    const YELLOW = "\x1b[93m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔══════════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}║   BLIND SPOT #1: Ω_DM DEGENERACY TEST — Is φ²/π² unique?     ║{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    std.debug.print("{s}PARAMETERS:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Complexity C ≤ {d}{s}\n", .{ C_max, RESET });
    std.debug.print("  Formula: V = n × 3^k × π^m × φ^p × e^q{s}\n\n", .{RESET});
    std.debug.print("  C = |n| + |k| + |m| + |p| + |q|{s}\n\n", .{RESET});

    std.debug.print("{s}PLANCK PR4 TARGET (Tristram et al. 2024):{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Omega_ch2 = {d:.4} +/- {d:.5}{s}\n", .{ Omega_dm_h2_planck, Omega_dm_h2_err, RESET });
    std.debug.print("  H0 = 67.64 +/- 0.52 -> h = 0.6764, h^2 = {d:.4}{s}\n", .{ h2_planck, RESET });
    std.debug.print("  Omega_c = {d:.4} +/- {d:.4} (DERIVED){s}\n", .{ Omega_dm_planck, Omega_dm_err, RESET });
    std.debug.print("  Source: Table 3, TTTEEE of https://arxiv.org/abs/2309.10034{s}\n", .{RESET});

    std.debug.print("  1σ window: [{d:.4}, {d:.4}]{s}\n", .{ Omega_dm_min, Omega_dm_max, RESET });
    std.debug.print("  2σ window: [{d:.4}, {d:.4}]{s}\n\n", .{ Omega_dm_min_2sig, Omega_dm_max_2sig, RESET });

    std.debug.print("{s}TRINITY CANDIDATE:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Omega_dm = phi^2/pi^2 = {d:.6}{s}\n", .{ Omega_dm_trinity, RESET });
    const phi_sigma = @abs(Omega_dm_trinity - Omega_dm_planck) / Omega_dm_err;
    const delta_phi = Omega_dm_trinity - Omega_dm_planck;
    const delta_str = if (delta_phi >= 0) "+" else "";
    std.debug.print("  Delta = {s}{d:.6} ({d:.3} sigma){s}\n\n", .{ delta_str, delta_phi, phi_sigma, RESET });

    std.debug.print("{s}GENERATING FORMULAS...{s}\n", .{ MAGENTA, RESET });

    const formulas = try generateFormulas(allocator, C_max);
    defer allocator.free(formulas);

    std.debug.print("  Total formulas with C ≤ {d}: {d}{s}\n\n", .{ C_max, formulas.len, RESET });

    std.debug.print("{s}TESTING AGAINST PLANCK WINDOW...{s}\n\n", .{ MAGENTA, RESET });

    var hits_1sig = try std.ArrayList(FormulaHit).initCapacity(allocator, 1000);
    var hits_2sig = try std.ArrayList(FormulaHit).initCapacity(allocator, 1000);

    for (formulas) |params| {
        const V = computeV(params);

        // Only consider values in reasonable range [0.001, 1.0]
        if (V < 0.001 or V > 1.0) continue;

        const delta = V - Omega_dm_planck;
        const sigma = @abs(delta) / Omega_dm_err;

        if (sigma <= 1.0) {
            const expr = try params.format(allocator);
            try hits_1sig.append(allocator, FormulaHit{
                .params = params,
                .value = V,
                .error_sigma = sigma,
                .expression = expr,
            });
        }

        if (sigma <= 2.0) {
            if (sigma > 1.0) {
                const expr = try params.format(allocator);
                try hits_2sig.append(allocator, FormulaHit{
                    .params = params,
                    .value = V,
                    .error_sigma = sigma,
                    .expression = expr,
                });
            }
        }
    }

    const hits_1sig_slice = try hits_1sig.toOwnedSlice(allocator);
    const hits_2sig_slice = try hits_2sig.toOwnedSlice(allocator);

    // Combine hits for the result (1σ + additional 2σ)
    var all_hits = try allocator.alloc(FormulaHit, hits_1sig_slice.len + hits_2sig_slice.len);
    @memcpy(all_hits[0..hits_1sig_slice.len], hits_1sig_slice);
    @memcpy(all_hits[hits_1sig_slice.len..], hits_2sig_slice);

    // Find φ²/π² rank
    var phi2_pi2_rank: ?usize = null;
    for (all_hits, 0..) |hit, i| {
        if (hit.params.n == 1 and hit.params.k == 0 and hit.params.m == -2 and hit.params.p == 2 and hit.params.q == 0) {
            phi2_pi2_rank = i;
            break;
        }
    }

    // Sort by sigma
    std.sort.insertion(FormulaHit, all_hits, {}, struct {
        fn lessThan(_: void, a: FormulaHit, b: FormulaHit) bool {
            return a.error_sigma < b.error_sigma;
        }
    }.lessThan);

    // Find sorted rank
    for (all_hits, 0..) |hit, i| {
        if (hit.params.n == 1 and hit.params.k == 0 and hit.params.m == -2 and hit.params.p == 2 and hit.params.q == 0) {
            phi2_pi2_rank = i;
            break;
        }
    }

    const result = DegeneracyResult{
        .total_generated = formulas.len,
        .one_sigma_hits = hits_1sig_slice.len,
        .two_sigma_hits = all_hits.len,
        .hits = all_hits,
        .phi2_pi2_rank = phi2_pi2_rank,
    };

    std.debug.print("{s}RESULTS:{s}\n\n", .{ CYAN, RESET });
    std.debug.print("  Formulas in 1σ window: {d}{s}\n", .{ result.one_sigma_hits, RESET });
    std.debug.print("  Formulas in 2σ window: {d}{s}\n\n", .{ result.two_sigma_hits, RESET });

    if (result.phi2_pi2_rank) |rank| {
        std.debug.print("  φ²/π² rank: #{d} out of {d}{s}\n\n", .{ rank + 1, result.two_sigma_hits, RESET });
    } else {
        std.debug.print("  φ²/π²: NOT in 2σ window{s}\n\n", .{RESET});
    }

    if (result.two_sigma_hits <= 10) {
        std.debug.print("{s}TOP HITS (sorted by σ):{s}\n", .{ GREEN, RESET });
        const show = @min(10, result.hits.len);
        for (result.hits[0..show], 0..) |hit, i| {
            const is_phi = (hit.params.n == 1 and hit.params.k == 0 and hit.params.m == -2 and hit.params.p == 2);
            const marker: []const u8 = if (is_phi) "►" else " ";
            std.debug.print("  {s}#{d:2} ", .{ marker, i + 1 });
            if (is_phi) std.debug.print("{s}", .{GREEN});
            const expr = try hit.params.format(std.heap.page_allocator);
            defer std.heap.page_allocator.free(expr);
            const delta = hit.value - Omega_dm_planck;
            const sign_str = if (delta >= 0) "+" else "";
            std.debug.print("V = {s} = {d:.6} (Δ = {s}{d:.6}, {d:.2}σ)", .{ expr, hit.value, sign_str, delta, hit.error_sigma });
            if (is_phi) std.debug.print("{s} ◄ TRINITY", .{RESET});
            std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("{s}╔══════════════════════════════════════════════════════════════════╗{s}\n", .{ MAGENTA, RESET });
    std.debug.print("{s}║  VERDICT                                                      ║{s}\n", .{ MAGENTA, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════════════╝{s}\n\n", .{ MAGENTA, RESET });

    const verdict_color = if (result.two_sigma_hits <= 3) GREEN else if (result.two_sigma_hits <= 20) YELLOW else RED;
    const verdict = if (result.two_sigma_hits <= 3)
        \\UNIQUE: φ²/π² is one of only 3 formulas. 0.000σ match is SIGNIFICANT.
    else if (result.two_sigma_hits <= 20)
        \\MODERATE: φ²/π² is one of ~20 formulas. Still RARE, but not unique.
    else
        \\DEGENERATE: Many formulas hit Planck window. φ²/π² is NOT special.
    ;

    std.debug.print("  {s}{s}{s}\n\n", .{ verdict_color, verdict, RESET });

    std.debug.print("{s}INTERPRETATION:{s}\n", .{ YELLOW, RESET });
    if (result.two_sigma_hits <= 3) {
        std.debug.print("  The formula space is SPARSE. Finding a 0.000σ match by chance is{s}\n", .{RESET});
        std.debug.print("  extremely UNLIKELY. φ²/π² is a UNIQUE mathematical relationship.{s}\n\n", .{RESET});
    } else if (result.two_sigma_hits <= 20) {
        std.debug.print("  The formula space has MODERATE density. φ²/π² is rare but{s}\n", .{RESET});
        std.debug.print("  not unique. The 0.000σ match is INTERESTING but not PROOF.{s}\n\n", .{RESET});
    } else {
        std.debug.print("  The formula space is DENSE. Many simple formulas hit the Planck{s}\n", .{RESET});
        std.debug.print("  window. φ²/π² is NOT special — it's one of MANY coincidences.{s}\n\n", .{RESET});
    }

    std.debug.print("{s}PR3 vs PR4 COMPARISON:{s}\n", .{ MAGENTA, RESET });
    const pr3_value: f64 = 0.2642;
    const pr3_delta = Omega_dm_trinity - pr3_value;
    const pr3_sigma = @abs(pr3_delta) / 0.0026;
    const pr4_delta = Omega_dm_trinity - Omega_dm_planck;
    const pr4_sigma = phi_sigma;
    _ = pr4_delta; // Suppress unused warning
    std.debug.print("  PR3 (2018): Omega_c = {d:.4}, phi^2/pi^2 at {d:.2} sigma{s}{s}\n", .{ pr3_value, pr3_sigma, "     ", RESET });
    std.debug.print("  PR4 (2024): Omega_c = {d:.4}, phi^2/pi^2 at {d:.2} sigma ⚠️ {s}\n", .{ Omega_dm_planck, pr4_sigma, RESET });
    std.debug.print("  Shift: {d:.2} sigma downward (PR3 -> PR4 increased tension){s}\n\n", .{ pr3_sigma - pr4_sigma, RESET });

    if (pr4_sigma < 1.0) {
        std.debug.print("  PR4 STRENGTHENS the formula (sub-1sigma agreement).{s}\n", .{GREEN});
        std.debug.print("  TRINITY Omega_dm = phi^2/pi^2 is ROBUST.{s}\n\n", .{GREEN});
    } else if (pr4_sigma < 2.0) {
        std.debug.print("  PR4 WEAKENS the formula (1-2sigma tension).{s}\n", .{YELLOW});
        std.debug.print("  TRINITY Omega_dm = phi^2/pi^2 is TOLERABLE but not EXCELLENT.{s}\n\n", .{YELLOW});
    } else if (pr4_sigma < 3.0) {
        std.debug.print("  PR4 creates TENSION with the formula (2-3sigma).{s}\n", .{RED});
        std.debug.print("  TRINITY Omega_dm = phi^2/pi^2 is CHALLENGED but not FALSIFIED.{s}\n\n", .{RED});
    } else {
        std.debug.print("  PR4 FALSIFIES the formula (>3sigma).{s}\n", .{RED});
        std.debug.print("  TRINITY Omega_dm = phi^2/pi^2 is KILLED.{s}\n\n", .{RED});
    }

    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ YELLOW, RESET });

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDegeneracyCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const CYAN = "\x1b[36m";
    const RESET = "\x1b[0m";

    var C_max: i64 = 5;

    if (args.len >= 1) {
        C_max = try std.fmt.parseInt(i64, args[0], 10);
    }

    if (args.len == 0 or std.mem.eql(u8, args[0], "help")) {
        std.debug.print("\n{s}USAGE:{s} tri math degeneracy [C_max]\n\n", .{ CYAN, RESET });
        std.debug.print("{s}OPTIONS:{s}\n", .{ CYAN, RESET });
        std.debug.print("  C_max    Maximum complexity (default: 5){s}\n\n", .{RESET});
        std.debug.print("{s}DESCRIPTION:{s}\n", .{ CYAN, RESET });
        std.debug.print("  Generate all formulas V = n×3^k×π^m×φ^p×e^q with C ≤ C_max{s}\n", .{RESET});
        std.debug.print("  and count how many fall in the Planck Ω_dm window.{s}\n\n", .{RESET});
        std.debug.print("  If FEW formulas hit: φ²/π² is UNIQUE → 0.000σ match is SIGNIFICANT{s}\n", .{RESET});
        std.debug.print("  If MANY formulas hit: φ²/π² is DEGENERATE → 0.000σ match means nothing{s}\n\n", .{RESET});
        std.debug.print("{s}EXAMPLES:{s}\n", .{ CYAN, RESET });
        std.debug.print("  tri math degeneracy     # Test C ≤ 5{s}\n", .{RESET});
        std.debug.print("  tri math degeneracy 3   # Test C ≤ 3{s}\n\n", .{RESET});
        std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ CYAN, RESET });
        return;
    }

    _ = try runDegeneracyTest(allocator, C_max);
}

// φ² + 1/φ² = 3 = TRINITY
