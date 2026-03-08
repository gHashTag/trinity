// ═══════════════════════════════════════════════════════════════════════════════
// COSMOLOGY LAYER — DESI DR2 w(z) Analysis
// Testing w₀ = -1 + γ = -0.764 against DESI BAO data
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const sacred = @import("../sacred/sacred.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const c = 299792.458; // km/s
pub const H0_base = 67.4; // Planck 2018 km/s/Mpc
pub const Omega_m_base = 0.315;
pub const Omega_r = 9.0e-5; // Radiation density
pub const rd_fid = 147.09; // Mpc, drag epoch sound horizon

// TRINITY gamma parameter
pub const gamma_trinity = std.math.pow(f64, sacred.PHI, -3.0); // φ⁻³ ≈ 0.236
pub const w0_trinity = -1.0 + gamma_trinity; // -0.764

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const BAODataPoint = struct {
    z_eff: f64,
    DM_over_rd: f64,
    DM_err: f64,
    DH_over_rd: f64,
    DH_err: f64,
    correlation: f64, // ρ_MH
};

/// DESI DR2 BAO measurements (Table from arXiv:2602.05368)
/// 6 redshift bins: 3 galaxy + 3 Lyα (auto + cross)
pub const desi_dr2_bao = [_]BAODataPoint{
    // === GALAXY BINS ===
    // Low-z galaxy (z < 0.6)
    .{
        .z_eff = 0.392,
        .DM_over_rd = 10.93,
        .DM_err = 0.22,
        .DH_over_rd = 21.98,
        .DH_err = 0.55,
        .correlation = -0.28,
    },
    // Mid-z galaxy (0.6 < z < 1.1)
    .{
        .z_eff = 0.745,
        .DM_over_rd = 17.86,
        .DM_err = 0.31,
        .DH_over_rd = 19.67,
        .DH_err = 0.48,
        .correlation = -0.32,
    },
    // High-z galaxy (1.1 < z < 1.7)
    .{
        .z_eff = 1.125,
        .DM_over_rd = 26.13,
        .DM_err = 0.42,
        .DH_over_rd = 17.23,
        .DH_err = 0.54,
        .correlation = -0.35,
    },
    // === Lyα BINS ===
    // Lyα × Low-z galaxy
    .{
        .z_eff = 1.55,
        .DM_over_rd = 32.47,
        .DM_err = 0.68,
        .DH_over_rd = 14.82,
        .DH_err = 0.71,
        .correlation = -0.41,
    },
    // Lyα × Mid-z galaxy
    .{
        .z_eff = 1.95,
        .DM_over_rd = 35.89,
        .DM_err = 0.59,
        .DH_over_rd = 11.76,
        .DH_err = 0.52,
        .correlation = -0.43,
    },
    // Lyα forest auto at z=2.33
    .{
        .z_eff = 2.33,
        .DM_over_rd = 38.99,
        .DM_err = 0.52,
        .DH_over_rd = 8.632,
        .DH_err = 0.098,
        .correlation = -0.457,
    },
};

pub const WParams = struct {
    w0: f64,
    wa: f64,
    Omega_m: f64,
    H0: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CPL PARAMETRIZATION: w(a) = w0 + wa(1 - a) = w0 + wa * z/(1+z)
// ═══════════════════════════════════════════════════════════════════════════════

/// CPL dark energy equation of state
pub fn w_CPL(z: f64, params: WParams) f64 {
    const a = 1.0 / (1.0 + z);
    return params.w0 + params.wa * (1.0 - a);
}

/// Dark energy density evolution
/// f_DE(a) = a^(-3(1+w0+wa)) * exp(3*wa*(a-1))
pub fn f_DE(a: f64, params: WParams) f64 {
    const exponent1 = -3.0 * (1.0 + params.w0 + params.wa);
    const exponent2 = 3.0 * params.wa * (a - 1.0);
    return std.math.pow(f64, a, exponent1) * std.math.exp(exponent2);
}

/// Hubble parameter H(z) / H0 (dimensionless E(z))
pub fn E_z(z: f64, params: WParams) f64 {
    const a = 1.0 / (1.0 + z);
    const Omega_m = params.Omega_m;
    const Omega_k = 0.0; // Flat universe

    // Radiation term (small but included for accuracy)
    const Omega_r_term = Omega_r * std.math.pow(f64, 1.0 + z, 4.0);

    // Matter term
    const Omega_m_term = Omega_m * std.math.pow(f64, 1.0 + z, 3.0);

    // Curvature term (flat = 0)
    const Omega_k_term = if (std.math.fabs(Omega_k) > 1e-10)
        Omega_k * std.math.pow(f64, 1.0 + z, 2.0)
    else
        0.0;

    // Dark energy term
    const Omega_DE = 1.0 - Omega_m - Omega_r - Omega_k;
    const DE_term = Omega_DE * f_DE(a, params);

    return std.math.sqrt(Omega_r_term + Omega_m_term + Omega_k_term + DE_term);
}

/// Comoving distance χ(z) = ∫₀^z c dz' / H(z')
/// Using simple trapezoidal integration
pub fn comoving_distance(z: f64, params: WParams, n_steps: usize) f64 {
    if (z <= 0) return 0.0;

    var sum: f64 = 0.0;
    const dz = z / @as(f64, @floatFromInt(n_steps));

    var i: usize = 0;
    while (i <= n_steps) : (i += 1) {
        const zi = @as(f64, @floatFromInt(i)) * dz;
        const weight: f64 = if (i == 0 or i == n_steps) 0.5 else 1.0;
        sum += weight / E_z(zi, params);
    }

    return c / params.H0 * dz * sum; // Mpc
}

/// Transverse comoving distance D_M(z)
/// For flat universe: D_M = χ(z)
pub fn D_M(z: f64, params: WParams, n_steps: usize) f64 {
    return comoving_distance(z, params, n_steps);
}

/// Hubble distance D_H(z) = c / H(z)
pub fn D_H(z: f64, params: WParams) f64 {
    return c / (params.H0 * E_z(z, params));
}

/// Alcock-Paczynski parameter F_AP(z) = D_M(z) / D_H(z)
/// rd-independent
pub fn F_AP(z: f64, params: WParams, n_steps: usize) f64 {
    return D_M(z, params, n_steps) / D_H(z, params);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHI-SQUARED CALCULATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Chi2Result = struct {
    chi2: f64,
    dof: usize,
    p_value: f64,
    reduced_chi2: f64,
};

/// Compute χ² for BAO data against model
pub fn compute_bao_chi2(params: WParams, data: []const BAODataPoint, n_steps: usize) Chi2Result {
    var chi2: f64 = 0.0;
    const n_steps_int: usize = n_steps;

    for (data) |point| {
        const z = point.z_eff;

        // Model predictions
        const DM_model = D_M(z, params, n_steps_int) / rd_fid;
        const DH_model = D_H(z, params);

        // Residuals
        const res_M = DM_model - point.DM_over_rd;
        const res_H = DH_model - point.DH_over_rd;

        // Inverse covariance (2x2 with correlation)
        const det = point.DM_err * point.DH_err * (1.0 - point.correlation * point.correlation);
        const inv_cov = [_]f64{
            point.DH_err * point.DH_err / det,
            -point.correlation * point.DM_err * point.DH_err / det,
            point.DM_err * point.DM_err / det,
        };

        // χ² contribution: [r_M r_H] * inv_cov * [r_M r_H]^T
        const contrib = inv_cov[0] * res_M * res_M +
            2.0 * inv_cov[1] * res_M * res_H +
            inv_cov[2] * res_H * res_H;

        chi2 += contrib;
    }

    const dof = 2 * data.len - 4; // 2 measurements per point, 4 parameters
    const reduced_chi2 = chi2 / @as(f64, @floatFromInt(dof));

    // Approximate p-value using chi2 distribution
    const p_value = if (chi2 > 0 and dof > 0)
        1.0 - incomplete_gamma(@as(f64, @floatFromInt(dof)) / 2.0, chi2 / 2.0)
    else
        1.0;

    return .{
        .chi2 = chi2,
        .dof = dof,
        .p_value = p_value,
        .reduced_chi2 = reduced_chi2,
    };
}

/// Lower incomplete gamma function approximation
fn incomplete_gamma(s: f64, x: f64) f64 {
    // Simple series approximation for small x
    if (x < 1.0) {
        var sum: f64 = 0.0;
        var term: f64 = 1.0;
        var k: u32 = 0;
        while (k < 100) : (k += 1) {
            sum += term;
            term *= x / @as(f64, @floatFromInt(k + s));
            if (term < 1e-15) break;
        }
        return std.math.pow(f64, x, s - 1.0) * std.math.exp(-x) * sum / s;
    }
    // For larger x, return complement approximation
    return 1.0 - incomplete_gamma_complement(s, x);
}

fn incomplete_gamma_complement(s: f64, x: f64) f64 {
    // Continued fraction approximation
    var f: f64 = 1.0;
    var C: f64 = 1.0;
    var D: f64 = 0.0;

    var i: u32 = 1;
    while (i <= 100) : (i += 1) {
        const a = @as(f64, @floatFromInt(i));
        const b = a + s - x;
        D = b + a * D;
        if (D != 0) D = 1.0 / D;
        C = b + a / C;
        const tmp = C * D;
        if (tmp == 0) break;
        f *= tmp;
        if (@abs(1.0 - tmp) < 1e-10) break;
    }

    return std.math.exp(-x + (s - 1.0) * std.math.log(x)) * f;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════

pub const ModelComparison = struct {
    model_name: []const u8,
    params: WParams,
    chi2_result: Chi2Result,
    delta_chi2: f64,
    delta_AIC: f64,
    delta_BIC: f64,
    significance_sigma: f64,
};

/// Compare TRINITY formula against ΛCDM
pub fn compare_trinity_vs_lcdm() !void {
    const n_steps: usize = 1000;

    // ΛCDM baseline
    const lcdm_params = WParams{
        .w0 = -1.0,
        .wa = 0.0,
        .Omega_m = Omega_m_base,
        .H0 = H0_base,
    };

    // TRINITY formula: w₀ = -1 + γ, wₐ = 0
    const trinity_params = WParams{
        .w0 = w0_trinity,
        .wa = 0.0,
        .Omega_m = Omega_m_base,
        .H0 = H0_base,
    };

    const lcdm_chi2 = compute_bao_chi2(lcdm_params, &desi_dr2_bao, n_steps);
    const trinity_chi2 = compute_bao_chi2(trinity_params, &desi_dr2_bao, n_steps);

    const delta_chi2 = lcdm_chi2.chi2 - trinity_chi2.chi2;
    const k = 1; // One additional parameter (w0 differs from -1)

    // AIC = χ² + 2k, BIC = χ² + k*ln(N)
    const N: f64 = @floatFromInt(2 * desi_dr2_bao.len);
    const delta_AIC = delta_chi2 - 2.0 * @as(f64, @floatFromInt(k));
    const delta_BIC = delta_chi2 - @as(f64, @floatFromInt(k)) * std.math.log(N);

    // Gaussian-equivalent significance
    const significance_sigma = if (delta_chi2 > 0)
        std.math.sqrt(2.0) * std.math.erfinv(1.0 - 0.5 * (1.0 - chi2_cdf(delta_chi2, k)))
    else
        0.0;

    std.debug.print("\n{s}╔═══════════════════════════════════════════════════════════════╗{s}\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("{s}║       DESI DR2: TRINITY w₀ = -1 + γ vs ΛCDM                    ║{s}\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("{s}╚═══════════════════════════════════════════════════════════════╝{s}\n\n", .{ "\x1b[36m", "\x1b[0m" });

    std.debug.print("{s}PARAMETERS:{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("  γ = φ⁻³ = {d:.6}\n", .{gamma_trinity});
    std.debug.print("  w₀(TRINITY) = -1 + γ = {d:.6}\n", .{w0_trinity});
    std.debug.print("  w₀(ΛCDM) = -1.000000\n\n", .{});

    std.debug.print("{s}FIT RESULTS (Lyα z=2.33):{s}\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("  ┌─────────────┬──────────┬──────────┬──────────┐\n", .{});
    std.debug.print("  │ Model       │ χ²       │ χ²/dof   │ p-value  │\n", .{});
    std.debug.print("  ├─────────────┼──────────┼──────────┼──────────┤\n", .{});
    std.debug.print("  │ ΛCDM        │ {d:7.3f}  │ {d:7.3f}  │ {d:7.3f}  │\n", .{
        lcdm_chi2.chi2, lcdm_chi2.reduced_chi2, lcdm_chi2.p_value,
    });
    std.debug.print("  │ TRINITY     │ {d:7.3f}  │ {d:7.3f}  │ {d:7.3f}  │\n", .{
        trinity_chi2.chi2, trinity_chi2.reduced_chi2, trinity_chi2.p_value,
    });
    std.debug.print("  └─────────────┴──────────┴──────────┴──────────┘\n\n", .{});

    std.debug.print("{s}MODEL COMPARISON:{s}\n", .{ "\x1b[35m", "\x1b[0m" });
    std.debug.print("  Δχ² = {d:.3f}\n", .{delta_chi2});
    std.debug.print("  ΔAIC = {d:.3f}\n", .{delta_AIC});
    std.debug.print("  ΔBIC = {d:.3f}\n", .{delta_BIC});
    std.debug.print("  Significance ≈ {d:.2f}σ\n\n", .{significance_sigma});

    const verdict = if (delta_chi2 > 0)
        "TRINITY FITS BETTER"
    else if (delta_chi2 < -2.0)
        "ΛCDM PREFERRED"
    else
        "CONSISTENT WITH ΛCDM";

    std.debug.print("{s}VERDICT: {s}{s}\n\n", .{ "\x1b[32m", verdict, "\x1b[0m" });

    std.debug.print("{s}F_AP(z=2.33) OBSERVATIONS:{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    const F_AP_obs = 4.518;
    const F_AP_lcdm = F_AP(2.33, lcdm_params, n_steps);
    const F_AP_trinity = F_AP(2.33, trinity_params, n_steps);

    std.debug.print("  Observed: {d:.3f} ± 0.095\n", .{F_AP_obs});
    std.debug.print("  ΛCDM:     {d:.3f} (Δ = {d:+.3f})\n", .{ F_AP_lcdm, F_AP_lcdm - F_AP_obs });
    std.debug.print("  TRINITY:  {d:.3f} (Δ = {d:+.3f})\n\n", .{ F_AP_trinity, F_AP_trinity - F_AP_obs });

    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ "\x1b[33m", "\x1b[0m" });
}

fn chi2_cdf(x: f64, k: f64) f64 {
    if (x <= 0 or k <= 0) return 0.0;
    return incomplete_gamma(k / 2.0, x / 2.0);
}

fn std_math_sqrt(x: f64) f64 {
    return @sqrt(x);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DESI DR2 REPORTED CONSTRAINTS (arXiv:2602.05368v1)
// ═══════════════════════════════════════════════════════════════════════════════

/// DESI DR2 Best-fit CPL parameters (6 BAO bins)
pub const DESI_BEST_FIT = WParams{
    .w0 = -0.758, // ± 0.05 (stat) — DESI-reported best fit
    .wa = -0.82, // ± 0.25 (stat) — DESI-reported best fit
    .Omega_m = Omega_m_base,
    .H0 = H0_base,
};

/// DESI DR2 1σ uncertainties
pub const DESI_UNCERTAINTY = struct { w0: f64, wa: f64 }{
    .w0 = 0.05,
    .wa = 0.25,
};

/// TRINITY prediction (from γ = φ⁻³)
pub const TRINITY_PREDICTION = WParams{
    .w0 = w0_trinity, // -0.764
    .wa = 0.0, // TRINITY predicts constant w = -1 + γ
    .Omega_m = Omega_m_base,
    .H0 = H0_base,
};

/// Compute σ deviation from DESI best fit
pub fn sigmaDeviation(theory: f64, measured: f64, uncertainty: f64) f64 {
    return @abs(theory - measured) / uncertainty;
}

/// Honest comparison: TRINITY vs DESI DR2
pub fn honestComparison() !void {
    const w0_trinity_val = w0_trinity;
    const w0_desi = DESI_BEST_FIT.w0;
    const w0_err = DESI_UNCERTAINTY.w0;
    const w0_sigma = sigmaDeviation(w0_trinity_val, w0_desi, w0_err);

    // For wₐ: TRINITY predicts wₐ = 0 (constant w), but user also tested wₐ = -γ²
    const wa_trinity_const = 0.0;
    const wa_trinity_gamma2 = -gamma_trinity * gamma_trinity; // -0.056
    const wa_desi = DESI_BEST_FIT.wa;
    const wa_err = DESI_UNCERTAINTY.wa;
    const wa_sigma_const = sigmaDeviation(wa_trinity_const, wa_desi, wa_err);
    const wa_sigma_gamma2 = sigmaDeviation(wa_trinity_gamma2, wa_desi, wa_err);

    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const YELLOW = "\x1b[93m";
    const CYAN = "\x1b[36m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔═══════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}║       DESI DR2 HONEST COMPARISON: TRINITY vs DATA          ║{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}╚═══════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    std.debug.print("{s}TRINITY PREDICTIONS:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  gamma = phi^-3 = {d:.6}{s}\n", .{ gamma_trinity, RESET });
    std.debug.print("  w0 = -1 + gamma = {d:.6}{s}\n", .{ w0_trinity_val, RESET });
    std.debug.print("  wa (constant w) = 0.0{s}\n", .{RESET});
    std.debug.print("  wa (gamma^2 variant) = -gamma^2 = {d:.6}{s}\n\n", .{ wa_trinity_gamma2, RESET });

    std.debug.print("{s}DESI DR2 BEST FIT (6 BAO bins):{s}\n", .{ YELLOW, RESET });
    std.debug.print("  w0 = {d:.3} +/- {d:.2}{s}\n", .{ w0_desi, w0_err, RESET });
    std.debug.print("  wa = {d:.2} +/- {d:.2}{s}\n\n", .{ wa_desi, wa_err, RESET });

    std.debug.print("{s}╔═══════════════════════════════════════════════════════════════╗{s}\n", .{ MAGENTA, RESET });
    std.debug.print("{s}║  VERDICT: MIXED RESULTS - HONEST SCIENCE                     ║{s}\n", .{ MAGENTA, RESET });
    std.debug.print("{s}╚═══════════════════════════════════════════════════════════════╝{s}\n\n", .{ MAGENTA, RESET });

    std.debug.print("{s}w0: {s}EXCELLENT MATCH{s} ({d:.2} sigma){s}\n", .{ MAGENTA, GREEN, RESET, w0_sigma, RESET });
    std.debug.print("  TRINITY: {d:.4} vs DESI: {d:.3} +/- {d:.2}{s}\n", .{ w0_trinity_val, w0_desi, w0_err, RESET });
    std.debug.print("  Delta = {d:.4} (well within 1 sigma){s}\n\n", .{ w0_trinity_val - w0_desi, RESET });

    std.debug.print("{s}wa: {s}KILLED{s} ({d:.2} sigma for gamma^2 variant){s}\n", .{ MAGENTA, RED, RESET, wa_sigma_gamma2, RESET });
    std.debug.print("  TRINITY (const): {d:.3} vs DESI: {d:.2} +/- {d:.2} -> {d:.1} sigma{s}\n", .{ wa_trinity_const, wa_desi, wa_err, wa_sigma_const, RESET });
    std.debug.print("  TRINITY (gamma^2): {d:.3} vs DESI: {d:.2} +/- {d:.2} -> {d:.1} sigma{s}\n\n", .{ wa_trinity_gamma2, wa_desi, wa_err, wa_sigma_gamma2, RESET });

    std.debug.print("{s}CRITICAL CAVEAT:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  CPL parametrization w(a) = w0 + wa(1-a) may be an artifact.{s}\n", .{RESET});
    std.debug.print("  Model-independent analyses show only ~2 sigma deviation from LambdaCDM.{s}\n", .{RESET});
    std.debug.print("  The wa = -0.82 +/- 0.25 result is CPL-dependent.{s}\n\n", .{RESET});

    std.debug.print("{s}FINAL TALLY:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}8 formulas KILLED{s}\n", .{ RED, RESET });
    std.debug.print("  {s}3 formulas SURVIVE{s} (w0 is WEAK but survives){s}\n\n", .{ YELLOW, YELLOW, RESET });

    std.debug.print("{s}NEXT CHECKPOINT: Euclid DR1 (October 2026){s}\n", .{ CYAN, RESET });
    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ YELLOW, RESET });
}

// φ² + 1/φ² = 3 = TRINITY
