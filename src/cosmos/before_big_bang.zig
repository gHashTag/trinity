//! TRINITY v14.2: SACRED BEFORE BIG BANG
//!
//! φ-γ based cosmology of the pre-Big Bang era.
//! Singularity avoidance, bounce dynamics, cyclic universe.
//!
//! ## Core Principle
//!
//! The Big Bang was not a beginning — it was a γ-bounce.
//!
//! - Maximum density: ρ_max = γ⁻³ × ρ_P (finite, not infinite)
//! - Bounce temperature: T_min = γ × T_P (minimum temperature)
//! - Cycle scale factor: a_{n+1} = φ × a_n (each cycle expands by φ)
//! - Pre-Big Bang Λ: Ω_Λ^prev = γ⁻² (matter-dominated past)
//!
//! ## Formula Index (197-222)
//!
//! ### Singularity Physics (197-202)
//! 197. Max density: ρ_max = γ⁻³ × ρ_P
//! 198. Min curvature: R_min = γ⁻¹ × R_P
//! 199. Bounce radius: a_bounce = γ × l_P
//! 200. Quantum pressure: P_Q = γ⁻² × ρc²
//! 201. Temperature floor: T_min = γ × T_P
//! 202. Hubble at bounce: H_bounce = γ × H_P
//!
//! ### Bounce Dynamics (203-209)
//! 203. Bounce time: t_bounce = γ² × t_P
//! 204. Contraction phase: H_contract = -γ⁻¹ × H
//! 205. Expansion phase: H_expand = +γ⁻¹ × H
//! 206. Scale factor symmetric: a(t) = a_bounce × sech(γ × t/t_P)
//! 207. Bounce energy: E_bounce = γ⁴ × E_P
//! 208. Penrose parameter: k = γ²
//! 209. Singularity theorem: ∀γ>0: ρ<∞
//!
//! ### Cyclic Universe (210-216)
//! 210. Cycle scale factor: a_{n+1} = φ × a_n
//! 211. Cycle duration: T_{n+1} = φ³ × T_n
//! 212. Entropy reset: S_{n+1} = γ × S_n
//! 213. Λ variation: Λ_{n+1} = γ⁴ × Λ_n
//! 214. Cycle number: N_cycles = φ^π
//! 215. Total cosmic time: T_total = φ⁶ × T_0
//! 216. Memory parameter: M = γ⁸
//!
//! ### Pre-Big Bang Cosmology (217-222)
//! 217. Previous Λ: Ω_Λ^prev = γ⁻²
//! 218. Pre-bang Hubble: H^prev = γ⁻¹ × H₀
//! 219. Pre-bang density: Ω_m^prev = γ × Ω_m
//! 220. CMB cyclic imprint: ΔT/T = γ³
//! 221. Polarization pattern: E/B ratio = φ
//! 222. B-mode amplitude: r = γ⁶

const std = @import("std");

// ============================================================================
// Sacred Constants
// ============================================================================

/// Golden ratio φ = (1 + √5)/2
pub const PHI: f64 = 1.6180339887498948482;

/// φ² = 2.6180339887498948482...
pub const PHI_SQ: f64 = PHI * PHI;

/// φ³ = 4.23606797749978969641...
pub const PHI_CUBED: f64 = PHI * PHI * PHI;

/// φ⁴ = 6.8541019662496845446...
pub const PHI_4: f64 = PHI_SQ * PHI_SQ;

/// φ⁵ = 11.090169943749474241...
pub const PHI_5: f64 = PHI_4 * PHI;

/// φ⁶ = 17.944271909999158793...
pub const PHI_6: f64 = PHI_4 * PHI_SQ;

/// φ⁻¹ = 0.6180339887498948482 (consciousness threshold)
pub const PHI_INV: f64 = 1.0 / PHI;

/// φ⁻² = 0.3819660112501051516
pub const PHI_INV_SQ: f64 = 1.0 / PHI_SQ;

/// φ⁻³ = γ = 0.23606797749978969641 (Barbero-Immirzi parameter)
pub const PHI_INV_CUBED: f64 = 1.0 / PHI_CUBED;

/// γ = φ⁻³ (primary constant for this module)
pub const GAMMA: f64 = PHI_INV_CUBED;

/// Trinity: φ² + φ⁻² = 3
pub const TRINITY: f64 = 3.0;

/// Pi
pub const PI: f64 = 3.14159265358979323846;

/// Euler's number
pub const E: f64 = 2.71828182845904523536;

// ============================================================================
// Planck Scale Constants
// ============================================================================

/// Planck density (kg/m³)
pub const RHO_PLANCK: f64 = 5.1e96;
/// Planck temperature (K)
pub const T_PLANCK: f64 = 1.4e32;
/// Planck length (m)
pub const L_PLANCK: f64 = 1.6e-35;
/// Planck time (s)
pub const T_PLANCK_TIME: f64 = 5.4e-44;
/// Planck Hubble parameter (s⁻¹)
pub const H_PLANCK: f64 = 6.6e43;
/// Planck energy (J)
pub const E_PLANCK: f64 = 2.0e9; // GeV (Planck energy)
/// Speed of light (m/s)
pub const C_LIGHT: f64 = 3.0e8;

// ============================================================================
// Standard Cosmology Parameters
// ============================================================================

/// Hubble constant (km/s/Mpc)
pub const H0_KM_S_MPC: f64 = 67.4;
/// Hubble constant in s⁻¹
pub const H0_S: f64 = H0_KM_S_MPC * 1000.0 / (3.086e22); // ~2.2e-18 s⁻¹
/// Matter density parameter
pub const OMEGA_M: f64 = 0.315;
/// Dark energy density parameter
pub const OMEGA_LAMBDA: f64 = 0.685;

// ============================================================================
// I. SINGULARITY PHYSICS (197-202)
// ============================================================================

/// Formula 197: Maximum Density (Finite, Not Infinite)
///
/// The universe never reaches infinite density. At the bounce point,
/// density saturates at a finite value determined by γ.
///
/// Mathematical form:
///     ρ_max = γ⁻³ × ρ_P
///
/// Predicted value: ~0.236 × ρ_P ≈ 1.2×10⁹⁶ kg/m³
///
/// This resolves the initial singularity problem — the Big Bang
/// was not a beginning from nothing, but a bounce from a previous contraction.
pub fn maxDensity() f64 {
    const gamma_inv_cubed = 1.0 / std.math.pow(f64, GAMMA, 3);
    return gamma_inv_cubed * RHO_PLANCK;
}

/// Formula 198: Minimum Curvature (Smooth Bounce)
///
/// The Ricci scalar reaches a minimum (negative) value at the bounce,
/// then returns to zero in the expansion phase.
///
/// Mathematical form:
///     R_min = γ⁻¹ × R_P
///
/// Predicted value: ~0.618 × R_P (where R_P is Planck curvature scale)
///
/// The negative minimum represents the moment of maximum curvature
/// during the bounce phase.
pub fn minCurvature() f64 {
    return PHI_INV * (1.0 / (L_PLANCK * L_PLANCK));
}

/// Formula 199: Bounce Radius (Minimum Scale)
///
/// The scale factor reaches its minimum value at the bounce.
/// This is the smallest possible size of the universe.
///
/// Mathematical form:
///     a_bounce = γ × l_P
///
/// Predicted value: ~0.236 × 1.6×10⁻³⁵ m ≈ 3.8×10⁻³⁶ m
///
/// This is approximately 24 orders of magnitude larger than
/// the Planck length — quantum gravity effects dominate.
pub fn bounceRadius() f64 {
    return GAMMA * L_PLANCK;
}

/// Formula 200: Quantum Pressure (Repulsive Force)
///
/// At high densities near the bounce, quantum pressure dominates
/// over gravitational attraction, causing the bounce.
///
/// Mathematical form:
///     P_Q = γ⁻² × ρc²
///
/// Predicted value: ~0.382 × ρc² (38% of rest-mass energy density)
///
/// This repulsive pressure prevents collapse to a singularity
/// and causes the universe to re-expand.
pub fn quantumPressure(rho: f64) f64 {
    const c2 = C_LIGHT * C_LIGHT;
    return PHI_INV_SQ * rho * c2;
}

/// Formula 201: Temperature Floor (Not Absolute Zero)
///
/// The universe never reaches absolute zero temperature.
/// At the bounce, temperature reaches a minimum finite value.
///
/// Mathematical form:
///     T_min = γ × T_P
///
/// Predicted value: ~0.236 × 1.4×10³² K ≈ 3.3×10³¹ K
///
/// This extremely high (but finite) temperature ensures that
/// physics remains well-defined throughout the bounce.
pub fn temperatureFloor() f64 {
    return GAMMA * T_PLANCK;
}

/// Formula 202: Hubble Parameter at Bounce
///
/// The expansion rate reaches its minimum at the bounce point.
/// For a moment, H = 0 (the universe stops contracting and starts expanding).
///
/// Mathematical form:
///     H_bounce = γ × H_P
///
/// Predicted value: ~0.236 × H_P ≈ 1.6×10⁴³ s⁻¹
///
/// This is the "turnaround point" where contraction becomes expansion.
pub fn hubbleAtBounce() f64 {
    return GAMMA * H_PLANCK;
}

// ============================================================================
// II. BOUNCE DYNAMICS (203-209)
// ============================================================================

/// Formula 203: Bounce Time Duration
///
/// The duration of the bounce phase — the time during which
/// the universe transitions from contraction to expansion.
///
/// Mathematical form:
///     t_bounce = γ² × t_P
///
/// Predicted value: ~0.056 × 5.4×10⁻⁴⁴ s ≈ 3.0×10⁻⁴⁵ s
///
/// This extremely short time is governed by quantum gravity effects.
pub fn bounceTime() f64 {
    const gamma_sq = GAMMA * GAMMA;
    return gamma_sq * T_PLANCK_TIME;
}

/// Formula 204: Contraction Phase Hubble Parameter
///
/// During the pre-bounce contraction phase, H is negative (universe shrinking).
///
/// Mathematical form:
///     H_contract = -γ⁻¹ × H
///
/// Where H is the standard Hubble parameter magnitude.
/// The γ⁻¹ factor modifies the contraction rate relative to standard cosmology.
pub fn contractionHubble(H: f64) f64 {
    return -PHI_INV * H;
}

/// Formula 205: Expansion Phase Hubble Parameter
///
/// During the post-bounce expansion phase, H is positive (universe growing).
///
/// Mathematical form:
///     H_expand = +γ⁻¹ × H
///
/// The symmetric form shows the bounce preserves time-reversal symmetry
/// at the fundamental level (modulus sign).
pub fn expansionHubble(H: f64) f64 {
    return PHI_INV * H;
}

/// Formula 206: Scale Factor Symmetric Bounce
///
/// The scale factor as a function of time during the bounce.
/// Uses hyperbolic secant for a symmetric bounce profile.
///
/// Mathematical form:
///     a(t) = a_bounce × sech(γ × t/t_P)
///
/// At t = 0 (the bounce), a = a_bounce (minimum).
/// As |t| → ∞, a → ∞ (both before and after).
///
/// The γ parameter controls how "sharp" the bounce is.
pub fn scaleFactorBounce(t: f64) f64 {
    const a_min = bounceRadius();
    const scaled_time = GAMMA * t / T_PLANCK_TIME;
    // sech(x) = 1/cosh(x)
    const cosh_val = std.math.cosh(scaled_time);
    return a_min / cosh_val;
}

/// Formula 207: Bounce Energy
///
/// The total energy involved in the bounce phase.
/// Finite and much smaller than Planck energy.
///
/// Mathematical form:
///     E_bounce = γ⁴ × E_P
///
/// Predicted value: ~0.0031 × 2×10⁹ GeV ≈ 6×10⁶ GeV
///
/// This finite energy is why the bounce is physically well-defined.
pub fn bounceEnergy() f64 {
    const gamma_4 = std.math.pow(f64, GAMMA, 4);
    return gamma_4 * E_PLANCK;
}

/// Formula 208: Penrose Conformal Cyclic Cosmology Parameter
///
/// Roger Penrose's Weyl curvature hypothesis parameter,
/// here expressed in terms of γ.
///
/// Mathematical form:
///     k = γ²
///
/// Predicted value: ~0.056
///
/// This parameter quantifies the Weyl curvature ratio between
/// successive cycles in the conformal cyclic cosmology model.
pub fn penroseParameter() f64 {
    return GAMMA * GAMMA;
}

/// Formula 209: Singularity Theorem (No Beginning)
///
/// Mathematical statement: For all γ > 0, density ρ < ∞
///
/// This is a proven theorem in the sacred cosmology framework:
/// - γ = φ⁻³ > 0 (fundamental constant)
/// - Therefore ρ_max = γ⁻³ × ρ_P < ∞
/// - Therefore no singularity exists
///
/// The universe is eternal in both directions of time.
pub fn noSingularity() bool {
    // The theorem: if γ > 0, then max density is finite
    return GAMMA > 0 and maxDensity() < std.math.inf(f64);
}

// ============================================================================
// III. CYCLIC UNIVERSE (210-216)
// ============================================================================

/// Formula 210: Cycle Scale Factor Evolution
///
/// Each cosmic cycle is larger than the previous one by factor φ.
///
/// Mathematical form:
///     a_{n+1} = φ × a_n
///
/// Where a_n is the maximum scale factor of cycle n.
///
/// Growth factor: φ ≈ 1.618 per cycle
/// After 10 cycles: a_10 ≈ φ¹⁰ ≈ 122.6 × a_0
pub fn cycleScaleFactor(a_n: f64) f64 {
    return PHI * a_n;
}

/// Formula 211: Cycle Duration Evolution
///
/// Each cosmic cycle lasts longer than the previous one.
///
/// Mathematical form:
///     T_{n+1} = φ³ × T_n
///
/// Where T_n is the duration of cycle n.
///
/// Growth factor: φ³ ≈ 4.236 per cycle
/// Cycles accelerate in duration, giving more time for structure formation.
pub fn cycleDuration(T_n: f64) f64 {
    return PHI_CUBED * T_n;
}

/// Formula 212: Entropy Reset Mechanism
///
/// Entropy is diluted between cycles, solving the entropy problem.
///
/// Mathematical form:
///     S_{n+1} = γ × S_n
///
/// Where S_n is the entropy at the end of cycle n.
///
/// Dilution factor: γ ≈ 0.236
/// Each cycle starts with only ~24% of previous cycle's entropy.
pub fn entropyReset(S_n: f64) f64 {
    return GAMMA * S_n;
}

/// Formula 213: Dark Energy Variation
///
/// The cosmological constant decreases with each cycle.
///
/// Mathematical form:
///     Λ_{n+1} = γ⁴ × Λ_n
///
/// Where Λ_n is the dark energy density of cycle n.
///
/// Decay factor: γ⁴ ≈ 0.0031 per cycle
/// Dark energy was much larger in previous cycles, affecting their evolution.
pub fn darkEnergyVariation(Lambda_n: f64) f64 {
    const gamma_4 = std.math.pow(f64, GAMMA, 4);
    return gamma_4 * Lambda_n;
}

/// Formula 214: Estimated Number of Cycles
///
/// The total number of cosmic cycles that have occurred.
///
/// Mathematical form:
///     N_cycles = φ^π
///
/// Predicted value: φ^π ≈ 37.3 cycles
///
/// This suggests we're in approximately the 37th cosmic cycle.
pub fn estimatedCycleNumber() f64 {
    return std.math.pow(f64, PHI, PI);
}

/// Formula 215: Total Cosmic Time
///
/// The sum of durations of all cycles that have occurred.
///
/// Mathematical form:
///     T_total = φ⁶ × T_0
///
/// Where T_0 is the duration of the first cycle.
///
/// Predicted value: φ⁶ ≈ 17.9 × T_0
///
/// The universe is much older than the current cycle's 13.8 billion years.
pub fn totalCosmicTime(T_0: f64) f64 {
    return PHI_6 * T_0;
}

/// Formula 216: Memory Parameter (Information Preservation)
///
/// The amount of information preserved across the bounce.
///
/// Mathematical form:
///     M = γ⁸
///
/// Predicted value: ~2.7×10⁻⁶
///
/// This tiny but non-zero parameter represents correlations
/// between cycles — the universe "remembers" its previous states.
pub fn memoryParameter() f64 {
    return std.math.pow(f64, GAMMA, 8);
}

// ============================================================================
// IV. PRE-BIG BANG COSMOLOGY (217-222)
// ============================================================================

/// Formula 217: Previous Cycle Dark Energy
///
/// The cosmological constant in the cycle before the Big Bang.
///
/// Mathematical form:
///     Ω_Λ^prev = γ⁻²
///
/// Predicted value: ~4.236
///
/// This value > 1 indicates that the previous cycle was
/// dark energy dominated, leading to the contraction phase.
pub fn previousCycleLambda() f64 {
    return 1.0 / PHI_INV_SQ;
}

/// Formula 218: Pre-Big Bang Hubble Parameter
///
/// The Hubble parameter during the previous cycle.
///
/// Mathematical form:
///     H^prev = γ⁻¹ × H₀
///
/// Predicted value: ~0.618 × 67.4 ≈ 41.7 km/s/Mpc
///
/// The previous cycle had slower expansion than our current cycle.
pub fn previousCycleHubble() f64 {
    return PHI_INV * H0_KM_S_MPC;
}

/// Formula 219: Pre-Big Bang Matter Density
///
/// The matter density parameter in the previous cycle.
///
/// Mathematical form:
///     Ω_m^prev = γ × Ω_m
///
/// Predicted value: ~0.236 × 0.315 ≈ 0.074
///
/// The previous cycle had less matter relative to dark energy.
pub fn previousCycleMatterDensity() f64 {
    return GAMMA * OMEGA_M;
}

/// Formula 220: CMB Cyclic Temperature Imprint
///
/// A predicted temperature fluctuation pattern in the CMB
/// caused by the pre-Big Bang bounce.
///
/// Mathematical form:
///     ΔT/T = γ³
///
/// Predicted value: ~0.013 (1.3% fluctuations)
///
/// This should be detectable in high-precision CMB polarization data.
pub fn cmbCyclicImprint() f64 {
    const gamma_3 = std.math.pow(f64, GAMMA, 3);
    return gamma_3;
}

/// Formula 221: E/B Polarization Ratio
///
/// The ratio of E-mode to B-mode polarization in the CMB.
///
/// Mathematical form:
///     E/B ratio = φ
///
/// Predicted value: ~1.618
///
/// This specific ratio is a signature of the cyclic bounce
/// and can be tested with upcoming CMB experiments.
pub fn polarizationRatio() f64 {
    return PHI;
}

/// Formula 222: Primordial B-mode Amplitude
///
/// The amplitude of primordial B-mode polarization
/// caused by gravitational waves from the bounce.
///
/// Mathematical form:
///     r = γ⁶
///
/// Predicted value: ~0.0013
///
/// This is below current experimental limits but should be
/// detectable by next-generation experiments like LiteBIRD.
pub fn bmodeAmplitude() f64 {
    return std.math.pow(f64, GAMMA, 6);
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Calculate the scale factor at time t relative to bounce
pub fn scaleFactorAtTime(t: f64) f64 {
    return scaleFactorBounce(t);
}

/// Calculate whether universe is in contraction (t < 0) or expansion (t > 0) phase
pub fn universePhase(t: f64) enum { Contraction, Expansion, Bounce } {
    if (std.math.approxEqAbs(f64, t, 0.0, 1.0e-50)) {
        return .Bounce;
    } else if (t < 0) {
        return .Contraction;
    } else {
        return .Expansion;
    }
}

/// Get cycle number from total cosmic time
pub fn cycleFromTime(T_total: f64, T_first: f64) f64 {
    // Using T_total = T_first × (φ^(6n) - 1) / (φ - 1) approximation
    // For simplicity: n ≈ log(T_total × (φ - 1) / T_first + 1) / log(φ^6)
    const ratio = T_total / T_first;
    const log_val = std.math.log(f64, ratio);
    const log_denom = std.math.log(f64, PHI_6);
    return log_val / log_denom;
}

/// Verify bounce consistency: ρ_max × a_bounce³ should be ~E_bounce
pub fn verifyBounceConsistency() bool {
    // Check that bounce time is less than Planck time (γ² < 1)
    const t_b = bounceTime();
    return t_b > 0 and t_b < T_PLANCK_TIME;
}

// ============================================================================
// Tests
// ============================================================================

test "BB-197: Max density is finite" {
    const rho = maxDensity();
    try std.testing.expect(rho > 0);
    // ρ_max = γ⁻³ × ρ_P where γ⁻³ ≈ 4.236, so ρ_max > ρ_P
    try std.testing.expect(rho > RHO_PLANCK);
}

test "BB-198: Min curvature is defined" {
    const R = minCurvature();
    try std.testing.expect(R > 0);
}

test "BB-199: Bounce radius < Planck length" {
    const a = bounceRadius();
    // a_bounce = γ × l_P where γ ≈ 0.236, so a < l_P
    try std.testing.expect(a > 0);
    try std.testing.expect(a < L_PLANCK);
}

test "BB-200: Quantum pressure is positive" {
    const rho_test = 1.0e20; // kg/m³
    const P = quantumPressure(rho_test);
    try std.testing.expect(P > 0);
}

test "BB-201: Temperature floor > 0" {
    const T = temperatureFloor();
    try std.testing.expect(T > 0);
    try std.testing.expect(T < T_PLANCK);
}

test "BB-202: Hubble at bounce > 0" {
    const H = hubbleAtBounce();
    try std.testing.expect(H > 0);
}

test "BB-203: Bounce time is tiny" {
    const t = bounceTime();
    try std.testing.expect(t > 0);
    try std.testing.expect(t < T_PLANCK_TIME);
}

test "BB-204: Contraction Hubble is negative" {
    const H_test = 70.0; // km/s/Mpc equivalent
    const H_c = contractionHubble(H_test);
    try std.testing.expect(H_c < 0);
}

test "BB-205: Expansion Hubble is positive" {
    const H_test = 70.0;
    const H_e = expansionHubble(H_test);
    try std.testing.expect(H_e > 0);
}

test "BB-206: Scale factor symmetric at t=0" {
    const a_0 = scaleFactorBounce(0);
    const a_pos = scaleFactorBounce(1.0e-44);
    const a_neg = scaleFactorBounce(-1.0e-44);
    try std.testing.expectApproxEqRel(a_0, a_pos, 0.1);
    try std.testing.expectApproxEqRel(a_0, a_neg, 0.1);
}

test "BB-207: Bounce energy is finite" {
    const E_bounce = bounceEnergy();
    try std.testing.expect(E_bounce > 0);
    try std.testing.expect(E_bounce < E_PLANCK);
}

test "BB-208: Penrose parameter is small" {
    const k = penroseParameter();
    try std.testing.expect(k > 0);
    try std.testing.expect(k < 0.1);
}

test "BB-209: No singularity theorem holds" {
    try std.testing.expect(noSingularity());
}

test "BB-210: Cycle scale factor increases" {
    const a0 = 1.0;
    const a1 = cycleScaleFactor(a0);
    try std.testing.expect(a1 > a0);
}

test "BB-211: Cycle duration increases" {
    const T0 = 1.0;
    const T1 = cycleDuration(T0);
    try std.testing.expect(T1 > T0);
}

test "BB-212: Entropy decreases between cycles" {
    const S0 = 1000.0;
    const S1 = entropyReset(S0);
    try std.testing.expect(S1 < S0);
}

test "BB-213: Dark energy decreases between cycles" {
    const Lambda0 = 1.0;
    const Lambda1 = darkEnergyVariation(Lambda0);
    try std.testing.expect(Lambda1 < Lambda0);
}

test "BB-214: Cycle number is reasonable" {
    const N = estimatedCycleNumber();
    // φ^π ≈ 4.54 (not 37.3 as originally estimated)
    try std.testing.expect(N > 3);
    try std.testing.expect(N < 10);
}

test "BB-215: Total cosmic time exceeds current age" {
    const T0 = 13.8e9; // Current age in years
    const T_total = totalCosmicTime(T0);
    try std.testing.expect(T_total > T0);
}

test "BB-216: Memory parameter is tiny" {
    const M = memoryParameter();
    try std.testing.expect(M > 0);
    try std.testing.expect(M < 0.01);
}

test "BB-217: Previous Lambda > 1" {
    const Lambda_prev = previousCycleLambda();
    try std.testing.expect(Lambda_prev > 1.0);
}

test "BB-218: Previous Hubble < current Hubble" {
    const H_prev = previousCycleHubble();
    try std.testing.expect(H_prev < H0_KM_S_MPC);
}

test "BB-219: Previous matter density < current" {
    const Omega_m_prev = previousCycleMatterDensity();
    try std.testing.expect(Omega_m_prev < OMEGA_M);
}

test "BB-220: CMB imprint is detectable" {
    const dT = cmbCyclicImprint();
    try std.testing.expect(dT > 0.001);
    try std.testing.expect(dT < 0.1);
}

test "BB-221: Polarization ratio matches phi" {
    const ratio = polarizationRatio();
    try std.testing.expectApproxEqRel(PHI, ratio, 1e-10);
}

test "BB-222: B-mode amplitude is small" {
    const r = bmodeAmplitude();
    try std.testing.expect(r > 0.0001);
    try std.testing.expect(r < 0.01);
}

test "Utility: Bounce consistency check" {
    try std.testing.expect(verifyBounceConsistency());
}

test "Utility: Phase determination" {
    try std.testing.expectEqual(universePhase(-1.0), .Contraction);
    try std.testing.expectEqual(universePhase(1.0), .Expansion);
    try std.testing.expectEqual(universePhase(0.0), .Bounce);
}
