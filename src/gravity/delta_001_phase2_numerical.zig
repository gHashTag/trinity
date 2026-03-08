//! DELTA-001 Phase 2: Numerical Exploration of γ = φ⁻³ in LQG Spin Networks
//!
//! This module conducts systematic numerical investigation of the Barbero-Immirzi
//! parameter γ = φ⁻³ in Loop Quantum Gravity spin networks.
//!
//! ## Research Questions
//!
//! 1. Higher Spins: Do φ-coincidences persist for j > 3?
//! 2. Multi-Edge Networks: Does φ emerge in aggregated eigenvalues?
//! 3. γ Comparison: φ⁻³ vs Meissner (0.274) vs alternative (0.237)
//! 4. Optimization: Does γ = φ⁻³ minimize spectral gaps?
//!
//! ## Success Criteria
//!
//! - Clear pattern detection (or honest null result)
//! - Quantitative comparison of γ values
//! - Go/No-Go recommendation for Phase 3

const std = @import("std");
const math = std.math;
const print = std.debug.print;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Golden ratio φ = (1 + √5) / 2
pub const PHI: f64 = 1.6180339887498948482;

/// φ⁻³ = γ (Barbero-Immirzi parameter in TRINITY theory)
pub const GAMMA_TRINITY: f64 = 1.0 / (PHI * PHI * PHI);

/// Meissner γ value (black hole entropy fit)
pub const GAMMA_MEISSNER: f64 = 0.274;

/// Alternative γ value (alternative counting)
pub const GAMMA_ALTERNATIVE: f64 = 0.237;

/// π
pub const PI: f64 = 3.14159265358979323846;

// ═══════════════════════════════════════════════════════════════════════════════
// SPIN NETWORK CALCULATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Calculate SU(2) Casimir eigenvalue √(j(j+1))
pub fn casimirEigenvalue(j: f64) f64 {
    return math.sqrt(j * (j + 1.0));
}

/// Calculate area eigenvalue for a given γ
/// A = 8πγℓ_P² √(j(j+1))
/// We work in dimensionless units (8πℓ_P² = 1)
pub fn areaEigenvalue(j: f64, gamma: f64) f64 {
    return gamma * casimirEigenvalue(j);
}

/// Calculate ratio between two eigenvalues
pub fn eigenvalueRatio(j1: f64, j2: f64) f64 {
    return casimirEigenvalue(j1) / casimirEigenvalue(j2);
}

/// Check if value is within 1% of φ
pub fn isWithinOnePercentOfPhi(value: f64) bool {
    const rel_error = @abs(value - PHI) / PHI;
    return rel_error < 0.01;
}

/// Check if value is within 0.1% of φ
pub fn isWithinZeroPointOnePercentOfPhi(value: f64) bool {
    const rel_error = @abs(value - PHI) / PHI;
    return rel_error < 0.001;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 1: HIGHER SPINS ANALYSIS (j = 4 to 10)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn analyzeHigherSpins() void {
    const GOLD = "\x1b[33m";
    const MAGENTA = "\x1b[35m";
    const RED = "\x1b[31m";
    const RESET = "\x1b[0m";
    _ = .{ GOLD, RED }; // Mark as used

    print("\n{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ MAGENTA, RESET });
    print("{s}║     DELTA-001 PHASE 2: NUMERICAL EXPLORATION                    ║{s}\n", .{ GOLD, RESET });
    print("{s}║     γ = φ⁻³ in LQG Spin Networks                                  ║{s}\n", .{ GOLD, RESET });
    print("{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ MAGENTA, RESET });

    print("{s}=== SECTION 1: HIGHER SPINS (j = 4 to 10) ==={s}\n\n", .{ GOLD, RESET });

    // Analyze spins j = 4, 5, 6, 7, 8, 9, 10
    var phi_coincidences_1percent: usize = 0;
    var phi_coincidences_0_1percent: usize = 0;

    var j: f64 = 4.0;
    while (j <= 10.0) : (j += 1.0) {
        const eigenvalue = casimirEigenvalue(j);
        const ratio_to_phi = eigenvalue / PHI;
        const error_phi = @abs(eigenvalue - PHI) / PHI * 100.0;

        print("{s}Spin j = {d:.0}:{s}\n", .{ GOLD, j, RESET });
        print("  √(j(j+1))   = {d:.15}\n", .{eigenvalue});
        print("  vs φ        = {d:.15} (diff: {d:.6}%)\n", .{ PHI, error_phi });
        print("  ratio to φ  = {d:.15}\n", .{ratio_to_phi});

        // Check for φ-coincidences
        var found_pattern = false;

        if (isWithinOnePercentOfPhi(eigenvalue)) {
            print("  {s}✓ Within 1% of φ{s}\n", .{ GOLD, RESET });
            phi_coincidences_1percent += 1;
            found_pattern = true;
        }

        if (isWithinZeroPointOnePercentOfPhi(eigenvalue)) {
            print("  {s}✓ Within 0.1% of φ{s}\n", .{ GOLD, RESET });
            phi_coincidences_0_1percent += 1;
            found_pattern = true;
        }

        // Check if eigenvalue equals k × φ for integer k
        const k_approx = @round(eigenvalue / PHI);
        if (k_approx > 0) {
            const reconstructed = k_approx * PHI;
            const rel_error = @abs(eigenvalue - reconstructed) / eigenvalue;
            if (rel_error < 0.01) {
                print("  {s}✓ ≈ {d:.0} × φ (error: {d:.6}%){s}\n", .{ GOLD, k_approx, rel_error * 100.0, RESET });
                found_pattern = true;
            }
        }

        if (!found_pattern) {
            print("  {s}No φ-pattern found{s}\n", .{ RED, RESET });
        }

        print("\n", .{});
    }

    print("{s}=== HIGHER SPINS SUMMARY ==={s}\n", .{ GOLD, RESET });
    print("φ-coincidences (< 1%):    {d} / 7 ({d:.1}%)\n", .{ phi_coincidences_1percent, @as(f64, @floatFromInt(phi_coincidences_1percent)) / 7.0 * 100.0 });
    print("φ-coincidences (< 0.1%):  {d} / 7 ({d:.1}%)\n", .{ phi_coincidences_0_1percent, @as(f64, @floatFromInt(phi_coincidences_0_1percent)) / 7.0 * 100.0 });
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 2: RATIO ANALYSIS BETWEEN HIGHER SPINS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn analyzeHigherSpinRatios() void {
    const GOLD = "\x1b[33m";
    const RESET = "\x1b[0m";

    print("{s}=== HIGHER SPIN RATIO ANALYSIS ==={s}\n\n", .{ GOLD, RESET });

    const spins = [_]f64{ 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0 };
    var phi_ratio_count: usize = 0;

    for (spins, 0..) |j1, i| {
        for (spins[i..]) |j2| {
            if (j1 == j2) continue;

            const ratio = eigenvalueRatio(j1, j2);
            const phi_diff = @abs(ratio - PHI) / PHI * 100.0;

            print("√({d:.0}×{d:.0}) / √({d:.0}×{d:.0}) = {d:.15}", .{ j1, j1 + 1.0, j2, j2 + 1.0, ratio });

            if (phi_diff < 5.0) {
                print("  {s}≈ φ (error: {d:.4}%){s}\n", .{ GOLD, phi_diff, RESET });
                phi_ratio_count += 1;
            } else {
                print("\n", .{});
            }
        }
    }

    print("\n{s}Ratios within 5% of φ: {d}{s}\n\n", .{ GOLD, phi_ratio_count, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 3: MULTI-EDGE NETWORKS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn analyzeMultiEdgeNetworks() void {
    const GOLD = "\x1b[33m";
    const RESET = "\x1b[0m";

    print("{s}=== SECTION 2: MULTI-EDGE NETWORKS ==={s}\n\n", .{ GOLD, RESET });

    // Test various combinations of spins

    // Test case 1: Three j=1 edges
    {
        const spins = [_]f64{ 1.0, 1.0, 1.0 };
        var sum_eigenvalues: f64 = 0.0;
        for (spins) |j| {
            sum_eigenvalues += casimirEigenvalue(j);
        }
        const error_phi = @abs(sum_eigenvalues - PHI) / PHI * 100.0;
        const error_k_phi = @abs(sum_eigenvalues / 3.0 - PHI) / PHI * 100.0;

        print("{s}Test case: Three j=1 edges{s}\n", .{ GOLD, RESET });
        print("  ∑√(jᵢ(jᵢ+1)) = {d:.15}\n", .{sum_eigenvalues});
        print("  vs φ         = {d:.15} (diff: {d:.6}%)\n", .{ PHI, error_phi });
        print("  vs 3φ        = {d:.15} (diff: {d:.6}%)\n", .{ 3.0 * PHI, error_k_phi });
    }

    // Test case 2: j=1, 2, 3 combination
    {
        const spins = [_]f64{ 1.0, 2.0, 3.0 };
        var sum_eigenvalues: f64 = 0.0;
        for (spins) |j| {
            sum_eigenvalues += casimirEigenvalue(j);
        }
        const error_phi = @abs(sum_eigenvalues - PHI) / PHI * 100.0;
        const error_k_phi = @abs(sum_eigenvalues / 3.0 - PHI) / PHI * 100.0;

        print("{s}Test case: j=1, 2, 3 combination{s}\n", .{ GOLD, RESET });
        print("  ∑√(jᵢ(jᵢ+1)) = {d:.15}\n", .{sum_eigenvalues});
        print("  vs φ         = {d:.15} (diff: {d:.6}%)\n", .{ PHI, error_phi });
        print("  vs 3φ        = {d:.15} (diff: {d:.6}%)\n", .{ 3.0 * PHI, error_k_phi });
    }

    // Test case 3: Sequential spins 0.5, 1, 1.5, 2
    {
        const spins = [_]f64{ 0.5, 1.0, 1.5, 2.0 };
        var sum_eigenvalues: f64 = 0.0;
        for (spins) |j| {
            sum_eigenvalues += casimirEigenvalue(j);
        }
        const error_phi = @abs(sum_eigenvalues - PHI) / PHI * 100.0;
        const error_k_phi = @abs(sum_eigenvalues / 4.0 - PHI) / PHI * 100.0;

        print("{s}Test case: Sequential spins 0.5, 1, 1.5, 2{s}\n", .{ GOLD, RESET });
        print("  ∑√(jᵢ(jᵢ+1)) = {d:.15}\n", .{sum_eigenvalues});
        print("  vs φ         = {d:.15} (diff: {d:.6}%)\n", .{ PHI, error_phi });
        print("  vs 4φ        = {d:.15} (diff: {d:.6}%)\n", .{ 4.0 * PHI, error_k_phi });
    }

    // Test case 4: Four j=2 edges
    {
        const spins = [_]f64{ 2.0, 2.0, 2.0, 2.0 };
        var sum_eigenvalues: f64 = 0.0;
        for (spins) |j| {
            sum_eigenvalues += casimirEigenvalue(j);
        }
        const error_phi = @abs(sum_eigenvalues - PHI) / PHI * 100.0;
        const error_k_phi = @abs(sum_eigenvalues / 4.0 - PHI) / PHI * 100.0;

        print("{s}Test case: Four j=2 edges{s}\n", .{ GOLD, RESET });
        print("  ∑√(jᵢ(jᵢ+1)) = {d:.15}\n", .{sum_eigenvalues});
        print("  vs φ         = {d:.15} (diff: {d:.6}%)\n", .{ PHI, error_phi });
        print("  vs 4φ        = {d:.15} (diff: {d:.6}%)\n", .{ 4.0 * PHI, error_k_phi });
    }

    // Test case 5: Mixed j=1 and j=2
    {
        const spins = [_]f64{ 1.0, 1.0, 2.0, 2.0 };
        var sum_eigenvalues: f64 = 0.0;
        for (spins) |j| {
            sum_eigenvalues += casimirEigenvalue(j);
        }
        const error_phi = @abs(sum_eigenvalues - PHI) / PHI * 100.0;
        const error_k_phi = @abs(sum_eigenvalues / 4.0 - PHI) / PHI * 100.0;

        print("{s}Test case: Mixed j=1 and j=2{s}\n", .{ GOLD, RESET });
        print("  ∑√(jᵢ(jᵢ+1)) = {d:.15}\n", .{sum_eigenvalues});
        print("  vs φ         = {d:.15} (diff: {d:.6}%)\n", .{ PHI, error_phi });
        print("  vs 4φ        = {d:.15} (diff: {d:.6}%)\n", .{ 4.0 * PHI, error_k_phi });
    }

    // Test case 6: Three j=3 edges
    {
        const spins = [_]f64{ 3.0, 3.0, 3.0 };
        var sum_eigenvalues: f64 = 0.0;
        for (spins) |j| {
            sum_eigenvalues += casimirEigenvalue(j);
        }
        const error_phi = @abs(sum_eigenvalues - PHI) / PHI * 100.0;
        const error_k_phi = @abs(sum_eigenvalues / 3.0 - PHI) / PHI * 100.0;

        print("{s}Test case: Three j=3 edges{s}\n", .{ GOLD, RESET });
        print("  ∑√(jᵢ(jᵢ+1)) = {d:.15}\n", .{sum_eigenvalues});
        print("  vs φ         = {d:.15} (diff: {d:.6}%)\n", .{ PHI, error_phi });
        print("  vs 3φ        = {d:.15} (diff: {d:.6}%)\n", .{ 3.0 * PHI, error_k_phi });
    }

    print("{s}Multi-edge network analysis complete{s}\n\n", .{ GOLD, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 4: γ VALUE COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════

pub fn compareGammaValues() void {
    const GOLD = "\x1b[33m";
    const RESET = "\x1b[0m";

    print("{s}=== SECTION 3: γ VALUE COMPARISON ==={s}\n\n", .{ GOLD, RESET });

    print("γ values to compare:\n", .{});
    print("  γ₁ (TRINITY)    = φ⁻³ = {d:.15}\n", .{GAMMA_TRINITY});
    print("  γ₂ (Meissner)   = 0.274\n", .{});
    print("  γ₃ (Alternative)= 0.237\n\n", .{});

    // Calculate area spectra for j = 1/2 to 3
    const spins = [_]f64{ 0.5, 1.0, 1.5, 2.0, 2.5, 3.0 };

    print("{s}Area spectra for fundamental spins:{s}\n\n", .{ GOLD, RESET });

    for (spins) |j| {
        const A_trinity = areaEigenvalue(j, GAMMA_TRINITY);
        const A_meissner = areaEigenvalue(j, GAMMA_MEISSNER);
        const A_alternative = areaEigenvalue(j, GAMMA_ALTERNATIVE);

        const diff_meissner = @abs(A_trinity - A_meissner) / A_trinity * 100.0;
        const diff_alternative = @abs(A_trinity - A_alternative) / A_trinity * 100.0;

        print("j = {d:.1}:\n", .{j});
        print("  A(γ₁) = {d:.15} (TRINITY)\n", .{A_trinity});
        print("  A(γ₂) = {d:.15} (Meissner, diff: {d:.4}%)\n", .{ A_meissner, diff_meissner });
        print("  A(γ₃) = {d:.15} (Alt, diff: {d:.4}%)\n", .{ A_alternative, diff_alternative });
        print("\n", .{});
    }

    // Analyze spectral spacing
    print("{s}Spectral spacing analysis:{s}\n\n", .{ GOLD, RESET });

    var avg_spacing_trinity: f64 = 0.0;
    var avg_spacing_meissner: f64 = 0.0;
    var avg_spacing_alternative: f64 = 0.0;
    var spacing_count: usize = 0;

    for (spins, 0..) |j1, i| {
        if (i < spins.len - 1) {
            const j2 = spins[i + 1];
            const A1_t = areaEigenvalue(j1, GAMMA_TRINITY);
            const A2_t = areaEigenvalue(j2, GAMMA_TRINITY);
            const spacing_t = A2_t - A1_t;

            const A1_m = areaEigenvalue(j1, GAMMA_MEISSNER);
            const A2_m = areaEigenvalue(j2, GAMMA_MEISSNER);
            const spacing_m = A2_m - A1_m;

            const A1_a = areaEigenvalue(j1, GAMMA_ALTERNATIVE);
            const A2_a = areaEigenvalue(j2, GAMMA_ALTERNATIVE);
            const spacing_a = A2_a - A1_a;

            avg_spacing_trinity += spacing_t;
            avg_spacing_meissner += spacing_m;
            avg_spacing_alternative += spacing_a;
            spacing_count += 1;

            print("Gap j={d:.1} → j={d:.1}:\n", .{ j1, j2 });
            print("  ΔA(γ₁) = {d:.15}\n", .{spacing_t});
            print("  ΔA(γ₂) = {d:.15}\n", .{spacing_m});
            print("  ΔA(γ₃) = {d:.15}\n", .{spacing_a});
            print("\n", .{});
        }
    }

    avg_spacing_trinity /= @as(f64, @floatFromInt(spacing_count));
    avg_spacing_meissner /= @as(f64, @floatFromInt(spacing_count));
    avg_spacing_alternative /= @as(f64, @floatFromInt(spacing_count));

    print("{s}Average spectral spacing:{s}\n", .{ GOLD, RESET });
    print("  γ₁ (TRINITY):    {d:.15}\n", .{avg_spacing_trinity});
    print("  γ₂ (Meissner):   {d:.15} (ratio: {d:.6})\n", .{ avg_spacing_meissner, avg_spacing_meissner / avg_spacing_trinity });
    print("  γ₃ (Alternative): {d:.15} (ratio: {d:.6})\n\n", .{ avg_spacing_alternative, avg_spacing_alternative / avg_spacing_trinity });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 5: OPTIMIZATION ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn optimizationAnalysis() void {
    const GOLD = "\x1b[33m";
    const RESET = "\x1b[0m";

    print("{s}=== SECTION 4: OPTIMIZATION ANALYSIS ==={s}\n\n", .{ GOLD, RESET });

    // Test if γ = φ⁻³ minimizes anything
    const gamma_values = [_]f64{
        0.200, 0.210, 0.220, 0.230,
        GAMMA_TRINITY, // 0.236...
        0.240,
        0.250,
        0.260,
        0.270,
        GAMMA_MEISSNER, // 0.274
        0.280,
        0.290,
        0.300,
    };

    print("Testing optimization criteria across γ range:\n\n", .{});

    var best_gamma_variance: f64 = 0.0;
    var min_variance: f64 = 1e10;

    var best_gamma_ratio: f64 = 0.0;
    var min_ratio_deviation: f64 = 1e10;

    for (gamma_values) |gamma| {
        // Calculate variance in spectral spacing for j = 1/2 to 3
        const spins = [_]f64{ 0.5, 1.0, 1.5, 2.0, 2.5, 3.0 };

        var spacings: [5]f64 = undefined;
        var avg_spacing: f64 = 0.0;

        for (spins, 0..) |j, i| {
            if (i < spins.len - 1) {
                const j2 = spins[i + 1];
                const A1 = areaEigenvalue(j, gamma);
                const A2 = areaEigenvalue(j2, gamma);
                spacings[i] = A2 - A1;
                avg_spacing += spacings[i];
            }
        }
        avg_spacing /= 5.0;

        // Calculate variance
        var variance: f64 = 0.0;
        for (spacings) |s| {
            variance += (s - avg_spacing) * (s - avg_spacing);
        }
        variance /= 5.0;

        // Calculate deviation from φ-ratio
        var ratio_deviation: f64 = 0.0;
        for (spins, 0..) |j1, i| {
            if (i < spins.len - 1) {
                const j2 = spins[i + 1];
                const ratio = eigenvalueRatio(j2, j1);
                ratio_deviation += @abs(ratio - PHI) / PHI;
            }
        }

        if (variance < min_variance) {
            min_variance = variance;
            best_gamma_variance = gamma;
        }

        if (ratio_deviation < min_ratio_deviation) {
            min_ratio_deviation = ratio_deviation;
            best_gamma_ratio = gamma;
        }

        print("γ = {d:.6}: variance = {d:.15}, φ-dev = {d:.15}{}\n", .{
            gamma,
            variance,
            ratio_deviation,
            if (gamma == GAMMA_TRINITY) " [TRINITY]" else "",
        });
    }

    print("\n{s}OPTIMIZATION RESULTS:{s}\n", .{ GOLD, RESET });
    print("  Minimum spacing variance: γ = {d:.6}\n", .{best_gamma_variance});
    print("  Minimum φ-ratio deviation: γ = {d:.6}\n", .{best_gamma_ratio});

    const is_trinity_optimal_variance = @abs(best_gamma_variance - GAMMA_TRINITY) < 0.001;
    const is_trinity_optimal_ratio = @abs(best_gamma_ratio - GAMMA_TRINITY) < 0.001;

    if (is_trinity_optimal_variance) {
        print("  {s}✓ γ = φ⁻³ minimizes spectral variance!{s}\n", .{ GOLD, RESET });
    } else {
        print("  {s}✗ γ = φ⁻³ does NOT minimize variance{s}\n", .{ "\x1b[31m", RESET });
    }

    if (is_trinity_optimal_ratio) {
        print("  {s}✓ γ = φ⁻³ minimizes φ-ratio deviation!{s}\n", .{ GOLD, RESET });
    } else {
        print("  {s}✗ γ = φ⁻³ does NOT minimize φ-ratio deviation{s}\n", .{ "\x1b[31m", RESET });
    }

    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 6: RISK ASSESSMENT & GO/NO-GO
// ═══════════════════════════════════════════════════════════════════════════════

pub fn riskAssessment() void {
    const GOLD = "\x1b[33m";
    const RED = "\x1b[31m";
    const CYAN = "\x1b[36m";
    const RESET = "\x1b[0m";

    print("{s}=== SECTION 5: RISK ASSESSMENT ==={s}\n\n", .{ GOLD, RESET });

    print("{s}Encouraging Findings:{s}\n", .{ GOLD, RESET });
    print("  [1] √(8/3) = 1.633 ≈ φ = 1.618 (0.93% error) — from Phase 1\n", .{});
    print("  [2] γ = φ⁻³ = 0.236 is mathematically elegant\n", .{});
    print("  [3] Trinity identity: φ² + φ⁻² = 3\n", .{});
    print("  [4] γ connects to consciousness (f_γ = 56 Hz)\n\n", .{});

    print("{s}Concerns and Obstacles:{s}\n", .{ RED, RESET });
    print("  [1] Phase 1 only found ONE strong φ-coincidence (< 1%)\n", .{});
    print("  [2] √(8/3) ≈ φ may be numerical accident (no theoretical basis)\n", .{});
    print("  [3] Black hole entropy fits favor γ = 0.274 (Meissner) over φ⁻³\n", .{});
    print("  [4] No experimental data to distinguish γ values at Planck scale\n\n", .{});

    print("{s}Preliminary Go/No-Go Recommendation:{s}\n", .{ GOLD, RESET });
    print("  Status: {s}PROCEED WITH CAUTION{s} (Yellow Light)\n\n", .{ CYAN, RESET });

    print("  Rationale:\n", .{});
    print("  - Mathematical beauty of φ⁻³ is compelling\n", .{});
    print("  - Single φ-coincidence is weak but non-zero evidence\n", .{});
    print("  - Phase 2 numerical results needed for final decision\n", .{});
    print("  - If no new patterns emerge in j>3, pivot to alternative γ\n\n", .{});

    print("  Success criteria for Phase 3:\n", .{});
    print("  - Find at least 2 additional φ-coincidences (< 1%)\n", .{});
    print("  - Demonstrate γ = φ⁻³ optimizes some physical quantity\n", .{});
    print("  - Connect to experimental predictions (e.g., black hole entropy)\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    analyzeHigherSpins();
    analyzeHigherSpinRatios();
    analyzeMultiEdgeNetworks();
    compareGammaValues();
    optimizationAnalysis();
    riskAssessment();

    const MAGENTA = "\x1b[35m";
    const GOLD = "\x1b[33m";
    const RESET = "\x1b[0m";

    print("\n{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ MAGENTA, RESET });
    print("{s}║     NUMERICAL EXPLORATION COMPLETE                                ║{s}\n", .{ GOLD, RESET });
    print("{s}║     Full results: docs/research/delta_001_phase2_numerical.md    ║{s}\n", .{ GOLD, RESET });
    print("{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ MAGENTA, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Higher spin eigenvalues are positive" {
    var j: f64 = 4.0;
    while (j <= 10.0) : (j += 1.0) {
        const ev = casimirEigenvalue(j);
        try std.testing.expect(ev > 0);
    }
}

test "Area eigenvalues scale with gamma" {
    const j = 2.0;
    const A1 = areaEigenvalue(j, GAMMA_TRINITY);
    const A2 = areaEigenvalue(j, GAMMA_MEISSNER);
    try std.testing.expect(A1 > 0);
    try std.testing.expect(A2 > 0);
    try std.testing.expect(A2 > A1); // Meissner γ is larger
}

test "Gamma values are in expected range" {
    try std.testing.expect(GAMMA_TRINITY > 0.23);
    try std.testing.expect(GAMMA_TRINITY < 0.24);
    try std.testing.expect(GAMMA_MEISSNER > 0.27);
    try std.testing.expect(GAMMA_MEISSNER < 0.28);
}
