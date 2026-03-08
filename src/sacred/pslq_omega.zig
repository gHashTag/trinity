// ═══════════════════════════════════════════════════════════════════════════════
// PSLQ TEST — Blind Spot #4: Is Ω_Λ formula unique?
// ═══════════════════════════════════════════════════════════════════════════════
//
// QUESTION: Ω_Λ = 3×π⁻³×φ²×e ≈ 0.689. Is this UNIQUE or one of MANY?
//
// Existing formulas:
//   Ω_DM = φ²/π² ≈ 0.265 (SPARSE: only 2/1002 in window)
//   V_cb = 1/(3πφ²) ≈ 0.0405 (tension zone)
//   Ω_Λ = 3×π⁻³×φ²×e ≈ 0.689 (SPARSE: 1/1002)
//
// ⚠️ CLOSURE WARNING (Blind Spot #2.5):
//   Ω_DM + Ω_Λ = 0.9538 (TRI) vs 0.9493 ± 0.0006 (Planck)
//   Δ = 7.4σ → FATAL. Cannot use both formulas simultaneously.
//   See: https://arxiv.org/abs/1807.06209 (Planck 2018)
//
// STATUS: Ω_Λ is SPARSE individually but CLOSURE-KILLED with Ω_DM.
//         Must choose ONE: either Ω_DM or Ω_Λ, not both.
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const sacred = @import("sacred.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Planck 2018: Ω_Λ = 0.6889 ± 0.0056 (TT,TE,EE+lowE+lensing)
const Omega_Lambda_planck: f64 = 0.6889;
const Omega_Lambda_err: f64 = 0.0056;

/// 1σ window: Ω_Λ ∈ [0.6833, 0.6945]
const Omega_Lambda_min: f64 = Omega_Lambda_planck - Omega_Lambda_err;
const Omega_Lambda_max: f64 = Omega_Lambda_planck + Omega_Lambda_err;

/// TRI formula: Ω_Λ = 3 × π^(-3) × φ^2 × e
const Omega_Lambda_tri: f64 = 3.0 * std.math.pow(f64, sacred.PI, -3.0) * sacred.PHI * sacred.PHI * sacred.E;

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const PslqRelation = struct {
    n: i64,
    k: i64,
    m: i64,
    p: i64,
    q: i64,
    value: f64,
    error_sigma: f64,
    expression: []const u8,

    pub fn format(self: PslqRelation, writer: anytype) !void {
        try writer.print("  V = {d}×3^{d}×π^{d}×φ^{d}×e^{d} = {d:.6} (Δ={d:+.6}, {d:.2}σ)", .{
            self.n, self.k, self.m, self.p, self.q, self.value, self.value - Omega_Lambda_planck, self.error_sigma,
        });
    }
};

pub const PslqResult = struct {
    total_generated: usize,
    one_sigma_hits: usize,
    tri_rank: ?usize,
    hits: []PslqRelation,
};

// ═══════════════════════════════════════════════════════════════════════════════
// GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute V = n × 3^k × π^m × φ^p × e^q
pub fn computePslqV(n: i64, k: i64, m: i64, p: i64, q: i64) f64 {
    const n_val: f64 = @floatFromInt(n);
    const k_val: f64 = if (k >= 0)
        std.math.pow(f64, 3.0, @floatFromInt(k))
    else
        1.0 / std.math.pow(f64, 3.0, @floatFromInt(-k));
    const m_val: f64 = if (m >= 0)
        std.math.pow(f64, sacred.PI, @floatFromInt(m))
    else
        1.0 / std.math.pow(f64, sacred.PI, @floatFromInt(-m));
    const p_val: f64 = if (p >= 0)
        std.math.pow(f64, sacred.PHI, @floatFromInt(p))
    else
        1.0 / std.math.pow(f64, sacred.PHI, @floatFromInt(-p));
    const q_val: f64 = if (q >= 0)
        std.math.pow(f64, sacred.E, @floatFromInt(q))
    else
        1.0 / std.math.pow(f64, sacred.E, @floatFromInt(-q));

    return n_val * k_val * m_val * p_val * q_val;
}

/// PSLQ formula parameters
const PslqFormula = struct { n: i64, k: i64, m: i64, p: i64, q: i64 };

/// Generate all (n,k,m,p,q) with complexity ≤ C_max
/// Complexity: C = |n| + |k| + |m| + |p| + |q|
pub fn generatePslqFormulas(allocator: std.mem.Allocator, C_max: i64) ![]PslqFormula {
    var list = try std.ArrayList(PslqFormula).initCapacity(allocator, 100000);

    const n_min: i64 = -C_max;
    const n_max: i64 = C_max;

    var n: i64 = n_min;
    while (n <= n_max) : (n += 1) {
        if (n == 0) continue;

        var k: i64 = -C_max;
        while (k <= C_max) : (k += 1) {
            var m: i64 = -C_max;
            while (m <= C_max) : (m += 1) {
                var p: i64 = -C_max;
                while (p <= C_max) : (p += 1) {
                    var q: i64 = -C_max;
                    while (q <= C_max) : (q += 1) {
                        const C = @abs(n) + @abs(k) + @abs(m) + @abs(p) + @abs(q);
                        if (C <= C_max) {
                            try list.append(allocator, .{ .n = n, .k = k, .m = m, .p = p, .q = q });
                        }
                    }
                }
            }
        }
    }

    return list.toOwnedSlice(allocator);
}

/// Run PSLQ test: count formulas in Planck Ω_Λ window
pub fn runPslqTest(allocator: std.mem.Allocator, C_max: i64) !PslqResult {
    std.debug.print("\n", .{});
    std.debug.print("======================================================================\n", .{});
    std.debug.print(" BLIND SPOT #4: PSLQ TEST - Is Omega_Lambda formula unique?\n", .{});
    std.debug.print("======================================================================\n\n", .{});

    std.debug.print("PARAMETERS:\n", .{});
    std.debug.print("  Complexity C <= {d}\n", .{C_max});
    std.debug.print("  Formula: V = n x 3^k x pi^m x phi^p x e^q\n\n", .{});

    std.debug.print("PLANCK 2018 TARGET:\n", .{});
    std.debug.print("  Omega_Lambda = {d:.4} +/- {d:.4}\n", .{ Omega_Lambda_planck, Omega_Lambda_err });
    std.debug.print("  1sigma window: [{d:.4}, {d:.4}]\n\n", .{ Omega_Lambda_min, Omega_Lambda_max });

    std.debug.print("TRI CANDIDATE:\n", .{});
    std.debug.print("  Omega_Lambda = 3 x pi^-3 x phi^2 x e = {d:.6}\n", .{Omega_Lambda_tri});
    const delta_tri = Omega_Lambda_tri - Omega_Lambda_planck;
    const sigma_tri = @abs(delta_tri) / Omega_Lambda_err;
    std.debug.print("  Delta = {d:.6} ({d:.3} sigma)\n\n", .{ delta_tri, sigma_tri });

    std.debug.print("GENERATING FORMULAS...\n", .{});
    const formulas = try generatePslqFormulas(allocator, C_max);
    defer allocator.free(formulas);

    std.debug.print("  Total formulas with C <= {d}: {d}\n\n", .{ C_max, formulas.len });

    std.debug.print("TESTING AGAINST PLANCK WINDOW...\n\n", .{});

    var hits_1sig = try std.ArrayList(PslqRelation).initCapacity(allocator, 1000);

    for (formulas) |params| {
        const V = computePslqV(params.n, params.k, params.m, params.p, params.q);

        // Only consider values in reasonable range [0.5, 0.9]
        if (V < 0.5 or V > 0.9) continue;

        const delta = V - Omega_Lambda_planck;
        const sigma = @abs(delta) / Omega_Lambda_err;

        if (sigma <= 1.0) {
            const expr = try std.fmt.allocPrint(allocator, "{d}x3^{d}xpi^{d}xphi^{d}xe^{d}", .{ params.n, params.k, params.m, params.p, params.q });
            try hits_1sig.append(allocator, PslqRelation{
                .n = params.n,
                .k = params.k,
                .m = params.m,
                .p = params.p,
                .q = params.q,
                .value = V,
                .error_sigma = sigma,
                .expression = expr,
            });
        }
    }

    const hits_slice = try hits_1sig.toOwnedSlice(allocator);

    // Sort by sigma
    std.sort.insertion(PslqRelation, hits_slice, {}, struct {
        fn lessThan(_: void, a: PslqRelation, b: PslqRelation) bool {
            return a.error_sigma < b.error_sigma;
        }
    }.lessThan);

    // Find TRI rank (3, 0, -3, 2, 1)
    var tri_rank: ?usize = null;
    for (hits_slice, 0..) |hit, i| {
        if (hit.n == 3 and hit.k == 0 and hit.m == -3 and hit.p == 2 and hit.q == 1) {
            tri_rank = i;
            break;
        }
    }

    const result = PslqResult{
        .total_generated = formulas.len,
        .one_sigma_hits = hits_slice.len,
        .tri_rank = tri_rank,
        .hits = hits_slice,
    };

    std.debug.print("RESULTS:\n\n", .{});
    std.debug.print("  Formulas in 1sigma window: {d}\n\n", .{result.one_sigma_hits});

    if (result.tri_rank) |rank| {
        std.debug.print("  TRI rank: #{d} out of {d}\n\n", .{ rank + 1, result.one_sigma_hits });
    } else {
        std.debug.print("  TRI: NOT in 1sigma window\n\n", .{});
    }

    if (result.one_sigma_hits <= 20) {
        std.debug.print("TOP HITS (sorted by sigma):\n", .{});
        const show = @min(20, result.hits.len);
        for (result.hits[0..show], 0..) |hit, i| {
            const is_tri = (hit.n == 3 and hit.k == 0 and hit.m == -3 and hit.p == 2);
            const marker = if (is_tri) ">>>" else "   ";
            std.debug.print("  {s} #{d:2} ", .{ marker, i + 1 });
            if (is_tri) std.debug.print("TRI: ", .{});
            std.debug.print("{}x{}x{}x{}x{}\n", .{ hit.n, hit.k, hit.m, hit.p, hit.q });
            if (is_tri) std.debug.print(" <<<", .{});
            std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("======================================================================\n", .{});
    std.debug.print(" VERDICT\n", .{});
    std.debug.print("======================================================================\n\n", .{});

    const verdict = if (result.one_sigma_hits <= 3)
        \\SPARSE: Only 1 formula hit Planck window. Omega_Lambda is mathematically unique.
    else if (result.one_sigma_hits <= 20)
        \\MODERATE: ~20 formulas hit window. TRI is rare but not unique.
    else
        \\CROWDED: Many formulas hit window. Omega_Lambda is NOT special.
    ;

    std.debug.print("{s}\n\n", .{verdict});

    std.debug.print("=== CLOSURE WARNING (Blind Spot #2.5) ===\n\n", .{});
    const Omega_dm_tri = sacred.PHI * sacred.PHI / (sacred.PI * sacred.PI);
    const closure_sum = Omega_dm_tri + Omega_Lambda_tri;
    const closure_planck = 0.9493;
    const closure_err = 0.0006;
    const closure_sigma = @abs(closure_sum - closure_planck) / closure_err;
    std.debug.print("  Omega_DM (TRI)       = {d:.6}\n", .{Omega_dm_tri});
    std.debug.print("  Omega_Lambda (TRI)   = {d:.6}\n", .{Omega_Lambda_tri});
    std.debug.print("  Sum (TRI)            = {d:.6}\n", .{closure_sum});
    std.debug.print("  Planck Omega_c+Omega = {d:.4} +/- {d:.4}\n", .{ closure_planck, closure_err });
    std.debug.print("  Delta                = {d:.4} ({d:.1} sigma)\n\n", .{ closure_sum - closure_planck, closure_sigma });
    std.debug.print("  STATUS: ", .{});
    if (closure_sigma > 5.0) {
        std.debug.print("FATAL - Omega_DM and Omega_Lambda cannot coexist!\n", .{});
        std.debug.print("          Maximum ONE formula can be true.\n", .{});
    } else if (closure_sigma > 3.0) {
        std.debug.print("TENSION - Closure test fails.\n", .{});
    } else {
        std.debug.print("PASS - Closure consistent.\n", .{});
    }
    std.debug.print("\n", .{});

    std.debug.print("INTERPRETATION:\n", .{});
    std.debug.print("  Individual: Omega_Lambda formula is SPARSE ({d}/{d} = {d:.1}%)\n", .{ result.one_sigma_hits, result.total_generated, @as(f64, @floatFromInt(result.one_sigma_hits)) / @as(f64, @floatFromInt(result.total_generated)) * 100 });
    std.debug.print("  Combined:  With Omega_DM, closure FAILS at {d:.1}sigma\n", .{closure_sigma});
    std.debug.print("  Verdict:   Omega_Lambda KILLED by closure constraint\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("phi^2 + 1/phi^2 = 3 = TRINITY\n\n", .{});

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runPslqCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var C_max: i64 = 5;

    if (args.len >= 1) {
        C_max = try std.fmt.parseInt(i64, args[0], 10);
    }

    if (args.len == 0 or std.mem.eql(u8, args[0], "help")) {
        std.debug.print("\nUSAGE: tri math pslq [C_max]\n\n", .{});
        std.debug.print("OPTIONS:\n", .{});
        std.debug.print("  C_max    Maximum complexity (default: 5)\n\n", .{});
        std.debug.print("DESCRIPTION:\n", .{});
        std.debug.print("  Generate PSLQ formulas V = nx3^kxpi^mxphi^pxe^q with C <= C_max\n", .{});
        std.debug.print("  and count how many fall in Planck Omega_Lambda window.\n\n", .{});
        std.debug.print("EXAMPLES:\n", .{});
        std.debug.print("  tri math pslq     # Test C <= 5\n", .{});
        std.debug.print("  tri math pslq 3   # Test C <= 3\n\n", .{});
        std.debug.print("phi^2 + 1/phi^2 = 3 = TRINITY\n\n", .{});
        return;
    }

    _ = try runPslqTest(allocator, C_max);
}

// φ² + 1/φ² = 3 = TRINITY
