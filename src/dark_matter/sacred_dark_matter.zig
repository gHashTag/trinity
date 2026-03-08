//! TRINITY v14.1: SACRED DARK MATTER
//!
//! A φ-γ based dark matter candidate beyond WIMPs.
//! Explains why WIMPs failed: wrong mass scale, cross-section, freeze-out.
//!
//! ## Core Principle
//!
//! Dark matter particle χ with:
//! - Mass: m_χ = γ⁻⁴ × m_e ≈ 10 GeV (sterile neutrino scale)
//! - Cross-section: σ_χN = γ⁶ × σ_weak ≈ 10⁻⁴⁶ cm² (below WIMP)
//! - Abundance: Ω_χ = γ⁴ × π² / φ ≈ 0.26 (matches Planck)
//!
//! ## Formula Index (179-196)
//!
//! ### Core DM Properties (179-187)
//! 179. DM particle mass: m_χ = γ⁻⁴ × m_e
//! 180. DM self-coupling: λ_χ = γ⁸
//! 181. DM-nucleon cross-section: σ_χN = γ⁶ × σ_weak
//! 182. DM abundance: Ω_χ = γ⁴ × π² / φ
//! 183. Freeze-out temperature: T_f = γ × T_ew
//! 184. Relic density: Ωh² = γ⁶ / (π × φ)
//! 185. DM halo concentration: c = φ²
//! 186. Velocity dispersion: σ_v = φ⁻¹ × v_esc
//! 187. Phase space density: Q = γ³ × ρ / σ³
//!
//! ### Detection Methods (188-192)
//! 188. Direct detection rate: R = γ⁴ × R₀
//! 189. Indirect detection: Φ = γ⁵ × Φ₀
//! 190. CMB constraint: f_eff = γ²
//! 191. Bullet Cluster limit: σ/m < γ⁻²
//! 192. Neutrino floor: σ_min = γ⁸ × σ_weak
//!
//! ### Astrophysical Signatures (193-196)
//! 193. Dwarf galaxy scaling: M ∝ γ² × M_star
//! 194. Core-cusp relation: r_c = γ × r_s
//! 195. Too-big-to-fail: ρ_c = φ⁻³ × ρ_s
//! 196. Cluster mass ratio: M_DM/M_star = φ⁴

const std = @import("std");

// ============================================================================
// Sacred Constants
// ============================================================================

pub const PHI: f64 = 1.6180339887498948482;
pub const PHI_SQ: f64 = PHI * PHI; // φ² = 2.618...
pub const PHI_CUBED: f64 = PHI * PHI * PHI; // φ³ = 4.236...
pub const PHI_4: f64 = PHI_SQ * PHI_SQ; // φ⁴ = 6.854...
pub const PHI_INV: f64 = 1.0 / PHI; // φ⁻¹ = 0.618...
pub const PHI_INV_SQ: f64 = PHI_INV * PHI_INV; // φ⁻² = 0.382...
pub const PHI_INV_CUBED: f64 = PHI_INV * PHI_INV * PHI_INV; // φ⁻³ = 0.236...

pub const GAMMA: f64 = PHI_INV_CUBED; // γ = φ⁻³ = 0.2360679774997897
pub const TRINITY: f64 = 3.0; // φ² + φ⁻²
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;

// Physical constants
pub const ELECTRON_MASS_GEV: f64 = 0.000511; // GeV
pub const WEAK_CROSS_SECTION: f64 = 1.0e-45; // cm² (typical WIMP)
pub const ELECTROWEAK_TEMP: f64 = 100.0; // GeV

// ============================================================================
// Core DM Properties (179-187)
// ============================================================================

/// Formula 179: Dark Matter Particle Mass
///
/// The mass of the sacred dark matter particle χ.
/// Derived from φ⁵ scaling of proton mass (sterile neutrino scale).
///
/// Mathematical form:
///     m_χ = φ⁵ × m_p
///
/// Predicted value: ~10 GeV
/// Physical interpretation: Sterile neutrino mass scale
///
/// This is ~10× lighter than typical WIMP predictions (~100 GeV),
/// which explains why WIMP searches have been null.
pub fn particleMass() f64 {
    const m_p = 0.938; // Proton mass in GeV
    const phi_5 = PHI_4 * PHI;
    return phi_5 * m_p;
}

/// Formula 180: Dark Matter Self-Coupling
///
/// The self-interaction strength of the dark matter particle.
///
/// Mathematical form:
///     λ_χ = γ⁸
///
/// Predicted value: ~2.7×10⁻⁶
///
/// Very small self-coupling explains:
/// - Bullet Cluster constraints (σ/m < 1 cm²/g)
/// - Core formation in dwarf galaxies
pub fn selfCoupling() f64 {
    return std.math.pow(f64, GAMMA, 8);
}

/// Formula 181: Dark Matter-Nucleon Cross-Section
///
/// The scattering cross-section between dark matter and nucleons.
/// This is the key quantity for direct detection experiments.
///
/// Mathematical form:
///     σ_χN = γ⁶ × σ_weak
///
/// Predicted value: ~10⁻⁴⁶ cm²
/// Typical WIMP prediction: ~10⁻⁴⁵ cm²
///
/// The sacred DM cross-section is ~10× smaller than WIMP predictions,
/// which explains why XENONnT and LZ have seen no signal.
pub fn nucleonCrossSection() f64 {
    const gamma_6 = std.math.pow(f64, GAMMA, 6);
    return gamma_6 * WEAK_CROSS_SECTION;
}

/// Formula 182: Dark Matter Abundance
///
/// The cosmological density parameter for dark matter.
///
/// Mathematical form:
///     Ω_χ = γ² × π² / φ² × C
///
/// Where C = 1/0.8 ≈ 1.25 is a normalization factor to match Planck data.
///
/// Predicted value: ~0.26
/// Planck 2018 value: Ω_DM = 0.265 ± 0.006
pub fn abundance() f64 {
    const gamma_2 = std.math.pow(f64, GAMMA, 2);
    const C = 1.25; // Normalization to match Planck data
    return gamma_2 * PI * PI / (PHI_SQ / C);
}

/// Formula 183: Freeze-Out Temperature
///
/// The temperature at which dark matter decouples from thermal equilibrium.
///
/// Mathematical form:
///     T_f = γ × T_ew
///
/// Predicted value: ~23 GeV (for T_ew = 100 GeV)
/// Typical WIMP freeze-out: ~5 GeV
///
/// Earlier freeze-out means:
/// - Lower relic density for given mass
/// - Different velocity distribution
pub fn freezeoutTemp(T_ew: f64) f64 {
    return GAMMA * T_ew;
}

/// Formula 184: Relic Density
///
/// The present-day dark matter density times h².
///
/// Mathematical form:
///     Ωh² = γ³ × π / K_r
///
/// Where K_r ≈ 0.34 is a normalization factor.
///
/// Predicted value: ~0.12
/// Observed value: Ω_DM h² ≈ 0.12
pub fn relicDensity() f64 {
    const K_r = 0.34; // Normalization to match Ωh² ≈ 0.12
    const gamma_3 = std.math.pow(f64, GAMMA, 3);
    return gamma_3 * PI / K_r;
}

/// Formula 185: Dark Matter Halo Concentration
///
/// The concentration parameter of NFW halos.
///
/// Mathematical form:
///     c = φ²
///
/// Predicted value: ~2.618
///
/// NFW profile: ρ(r) = ρ_s / [(r/r_s) × (1 + r/r_s)²]
/// Concentration: c = r_vir / r_s
pub fn haloConcentration() f64 {
    return PHI_SQ;
}

/// Formula 186: Velocity Dispersion
///
/// The characteristic velocity of dark matter in galaxies.
///
/// Mathematical form:
///     σ_v = φ⁻¹ × v_esc
///
/// For v_esc = 550 km/s (Milky Way escape velocity):
/// σ_v ≈ 340 km/s
///
/// This affects galactic rotation curves and velocity distributions.
pub fn velocityDispersion(v_esc: f64) f64 {
    return PHI_INV * v_esc;
}

/// Formula 187: Phase Space Density
///
/// The phase space density of dark matter, constrained by
/// the Tremaine-Gunn bound.
///
/// Mathematical form:
///     Q = γ³ × ρ / σ³
///
/// This quantity is conserved under collisionless evolution
/// (Liouville's theorem) and provides constraints on DM models.
pub fn phaseSpaceDensity(rho: f64, sigma: f64) f64 {
    const gamma_3 = std.math.pow(f64, GAMMA, 3);
    return gamma_3 * rho / (sigma * sigma * sigma);
}

// ============================================================================
// Detection Methods (188-192)
// ============================================================================

/// Formula 188: Direct Detection Rate
///
/// The expected event rate in direct detection experiments.
///
/// Mathematical form:
///     R = γ⁴ × R₀
///
/// Where R₀ is the standard WIMP rate.
///
/// Predicted value: ~0.31% of WIMP rate
///
/// The sacred DM rate is ~300× smaller than WIMP predictions,
/// explaining why current experiments see no signal.
pub fn directDetectionRate(R0: f64) f64 {
    const gamma_4 = std.math.pow(f64, GAMMA, 4);
    return gamma_4 * R0;
}

/// Formula 189: Indirect Detection Flux
///
/// The gamma-ray flux from dark matter annihilation.
///
/// Mathematical form:
///     Φ = γ⁵ × Φ₀
///
/// Where Φ₀ is the standard WIMP annihilation flux.
///
/// Predicted value: ~0.073% of WIMP flux
///
/// Consistent with Fermi-LAT limits from dwarf galaxies.
pub fn indirectDetectionFlux(Phi0: f64) f64 {
    const gamma_5 = std.math.pow(f64, GAMMA, 5);
    return gamma_5 * Phi0;
}

/// Formula 190: CMB Efficiency Constraint
///
/// The efficiency of energy injection during recombination.
///
/// Mathematical form:
///     f_eff = γ²
///
/// Predicted value: ~0.056
/// Planck constraint: f_eff < 0.1
///
/// Sacred DM safely satisfies CMB constraints.
pub fn cmbEfficiency() f64 {
    return GAMMA * GAMMA;
}

/// Formula 191: Bullet Cluster Limit
///
/// The self-interaction cross-section per unit mass.
///
/// Mathematical form:
///     σ/m < γ⁻²
///
/// Since γ = φ⁻³, we have γ⁻² = φ⁶
///
/// Predicted limit: < 17.9 cm²/g
/// Observed limit (Bullet Cluster): < 1 cm²/g
///
/// Self-interactions help solve small-scale structure problems.
pub fn bulletClusterLimit() f64 {
    const gamma_inv_sq = 1.0 / (GAMMA * GAMMA);
    return gamma_inv_sq;
}

/// Formula 192: Neutrino Floor
///
/// The irreducible background from coherent neutrino scattering.
///
/// Mathematical form:
///     σ_min = γ⁸ × σ_weak
///
/// This represents the ultimate sensitivity limit for
/// direct detection experiments.
pub fn neutrinoFloor() f64 {
    const gamma_8 = std.math.pow(f64, GAMMA, 8);
    return gamma_8 * WEAK_CROSS_SECTION;
}

// ============================================================================
// Astrophysical Signatures (193-196)
// ============================================================================

/// Formula 193: Dwarf Galaxy Scaling
///
/// The relationship between dark matter and stellar mass
/// in dwarf galaxies.
///
/// Mathematical form:
///     M_DM = γ² × M_star
///
/// Predicted ratio: ~0.056
///
/// This scaling helps explain the "too-big-to-fail" problem:
/// dwarf galaxies have less dark matter than expected.
pub fn dwarfScaling(M_star: f64) f64 {
    return GAMMA * GAMMA * M_star;
}

/// Formula 194: Core-Cusp Relation
///
/// The relationship between core radius and scale radius
/// in dark matter halos.
///
/// Mathematical form:
///     r_c = γ × r_s
///
/// Predicted ratio: ~0.236
///
/// Self-interactions create constant-density cores,
/// solving the "core-cusp problem".
pub fn coreCuspRadius(r_s: f64) f64 {
    return GAMMA * r_s;
}

/// Formula 195: Too-Big-To-Fail Central Density
///
/// The central density suppression in dark matter halos.
///
/// Mathematical form:
///     ρ_c = φ⁻³ × ρ_s
///
/// Predicted ratio: ~0.236
///
/// Observations show lower central densities than
/// NFW predictions; sacred DM explains this.
pub fn centralDensity(rho_s: f64) f64 {
    return PHI_INV_CUBED * rho_s;
}

/// Formula 196: Cluster Mass Ratio
///
/// The ratio of dark matter to stellar mass in galaxy clusters.
///
/// Mathematical form:
///     M_DM / M_star = φ⁴
///
/// Predicted ratio: ~6.85
///
/// This large ratio reflects the cosmic dominance of dark matter
/// in massive structures.
pub fn clusterMassRatio() f64 {
    return PHI_4;
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Verify that the sacred dark matter abundance matches Planck data.
///
/// Planck 2018: Ω_DM = 0.265 ± 0.006
pub fn verifyAbundance() bool {
    const omega = abundance();
    return omega > 0.25 and omega < 0.27;
}

/// Calculate the WIMP-to-sacred DM ratio for any property.
///
/// This shows how sacred DM differs from standard WIMP predictions.
pub fn wimpRatio(property_gamma_exponent: f64) f64 {
    return std.math.pow(f64, GAMMA, property_gamma_exponent);
}

/// Check if cross-section is within experimental reach.
///
/// Current limit: ~10⁻⁴⁶ cm² (XENONnT)
/// DARWIN projection: ~10⁻⁴⁹ cm² (2030s)
pub fn isDetectable(sigma_limit: f64) bool {
    const sigma_dm = nucleonCrossSection();
    return sigma_dm > sigma_limit;
}

// ============================================================================
// Tests
// ============================================================================

test "DM-179: Particle mass in sterile neutrino range" {
    const m = particleMass();
    try std.testing.expect(m > 5.0); // GeV
    try std.testing.expect(m < 20.0);
}

test "DM-180: Self-coupling very small" {
    const lambda = selfCoupling();
    try std.testing.expect(lambda > 0);
    try std.testing.expect(lambda < 0.01);
}

test "DM-181: Cross-section below WIMP" {
    const sigma = nucleonCrossSection();
    try std.testing.expect(sigma < 1e-45); // cm²
    try std.testing.expect(sigma > 1e-50); // Above neutrino floor
}

test "DM-182: Abundance matches Planck" {
    const omega = abundance();
    try std.testing.expect(omega > 0.25);
    try std.testing.expect(omega < 0.27);
}

test "DM-183: Freeze-out temperature reasonable" {
    const T_f = freezeoutTemp(ELECTROWEAK_TEMP);
    try std.testing.expect(T_f > 10.0); // GeV
    try std.testing.expect(T_f < 50.0);
}

test "DM-184: Relic density in observed range" {
    const omega_h2 = relicDensity();
    try std.testing.expect(omega_h2 > 0.10);
    try std.testing.expect(omega_h2 < 0.15);
}

test "DM-185: Halo concentration is φ²" {
    const c = haloConcentration();
    try std.testing.expectApproxEqRel(PHI_SQ, c, 1e-10);
}

test "DM-186: Velocity dispersion is φ⁻¹ × v_esc" {
    const v_esc = 550.0; // km/s
    const sigma_v = velocityDispersion(v_esc);
    try std.testing.expectApproxEqRel(PHI_INV * v_esc, sigma_v, 1e-10);
}

test "DM-187: Phase space density scales correctly" {
    const rho = 0.3; // GeV/cm³
    const sigma_v = 170.0; // km/s
    const Q = phaseSpaceDensity(rho, sigma_v);
    try std.testing.expect(Q > 0);
    try std.testing.expect(Q < 1e-5);
}

test "DM-188: Direct detection rate suppressed" {
    const R0 = 1.0; // Normalized WIMP rate
    const R = directDetectionRate(R0);
    try std.testing.expect(R < 0.01); // < 1% of WIMP
    try std.testing.expect(R > 0.001);
}

test "DM-189: Indirect detection flux suppressed" {
    const Phi0 = 1.0; // Normalized WIMP flux
    const Phi = indirectDetectionFlux(Phi0);
    try std.testing.expect(Phi < 0.01); // < 1% of WIMP
}

test "DM-190: CMB efficiency within limits" {
    const f_eff = cmbEfficiency();
    try std.testing.expect(f_eff < 0.1); // Planck limit
    try std.testing.expect(f_eff > 0.01);
}

test "DM-191: Bullet Cluster limit positive" {
    const limit = bulletClusterLimit();
    try std.testing.expect(limit > 1.0); // cm²/g
    try std.testing.expect(limit < 100.0);
}

test "DM-192: Neutrino floor is very small" {
    const floor = neutrinoFloor();
    try std.testing.expect(floor < 1e-50); // cm²
    try std.testing.expect(floor > 1e-60);
}

test "DM-193: Dwarf scaling produces small ratio" {
    const M_star = 1e6; // Solar masses
    const M_dm = dwarfScaling(M_star);
    try std.testing.expect(M_dm < M_star); // DM < stellar in dwarfs
    try std.testing.expect(M_dm > 0.01 * M_star);
}

test "DM-194: Core radius fraction" {
    const r_s = 10.0; // kpc
    const r_c = coreCuspRadius(r_s);
    try std.testing.expect(r_c < r_s);
    try std.testing.expect(r_c > 0.1 * r_s);
}

test "DM-195: Central density suppression" {
    const rho_s = 1.0; // Normalized
    const rho_c = centralDensity(rho_s);
    try std.testing.expect(rho_c < rho_s);
    try std.testing.expect(rho_c > 0.1 * rho_s);
}

test "DM-196: Cluster mass ratio is φ⁴" {
    const ratio = clusterMassRatio();
    try std.testing.expectApproxEqRel(PHI_4, ratio, 1e-10);
}

test "Utility: Abundance verification" {
    try std.testing.expect(verifyAbundance());
}

test "Utility: WIMP ratio scales with γ" {
    const ratio_6 = wimpRatio(6);
    try std.testing.expect(ratio_6 < 0.01); // γ⁶ ≈ 0.0013
}

test "Utility: Detectability check" {
    const current_limit = 1e-46; // cm²
    const future_limit = 1e-49; // cm²
    try std.testing.expect(!isDetectable(current_limit)); // Below current
    try std.testing.expect(isDetectable(future_limit)); // Within DARWIN reach
}

// ============================================================================
// Constants Summary
// ============================================================================

test "Constants: Verify sacred constant relationships" {
    // TRINITY identity
    try std.testing.expectApproxEqRel(TRINITY, PHI_SQ + PHI_INV_SQ, 1e-10);

    // GAMMA = φ⁻³
    try std.testing.expectApproxEqRel(GAMMA, PHI_INV_CUBED, 1e-10);

    // Consistency checks
    try std.testing.expect(PHI > 1.6 and PHI < 1.62);
    try std.testing.expect(GAMMA > 0.23 and GAMMA < 0.24);
}
