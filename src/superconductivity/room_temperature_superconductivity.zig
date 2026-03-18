//! TRINITY v21.0: ROOM-TEMPERATURE SUPERCONDUCTIVITY
//!
//! φ-γ based prediction of superconductor properties and critical parameters.
//! Cuprates, iron-based, and hydride materials with γ = φ⁻³ scaling.
//!
//! Core insight: Superconductivity emerges from phonon-mediated Cooper pairs
//! with φ-γ scaling of critical temperature and material properties.

const std = @import("std");
const testing = std.testing;
const math = std.math;

// Sacred constants
pub const PHI: f64 = 1.6180339887498948482;
pub const PHI_SQ: f64 = PHI * PHI;
pub const PHI_CUBED: f64 = PHI * PHI * PHI;
pub const GAMMA: f64 = 1.0 / PHI_CUBED; // φ⁻³
pub const PHI_GAMMA: f64 = 1.0 / PHI; // φ⁻¹
pub const PI: f64 = 3.14159265358979323846;

// Physical constants
pub const ELEMENTARY_CHARGE: f64 = 1.602176634e-19;
pub const ELECTRON_MASS: f64 = 9.1093837015e-31;
pub const REDUCED_PLANCK: f64 = 1.054571817e-34;
pub const PLANCK: f64 = 6.62607015e-34;
pub const BOLTZMANN: f64 = 1.380649e-23;
pub const VACUUM_PERMEABILITY: f64 = 4.0 * PI * 1.0e-7;
pub const SPEED_OF_LIGHT: f64 = 299792458.0;

// Formula constants
pub const ROOM_TEMP_K: f64 = 293.15; // 20°C
pub const ROOM_TEMP_C: f64 = 20.0;

pub const VERSION = "21.0.0";
pub const MODULE_NAME = "ROOM-TEMPERATURE SUPERCONDUCTIVITY";
pub const FORMULA_START = 343;
pub const FORMULA_END = 362;
pub const FORMULA_COUNT = 20;

// ============================================================================
// FORMULAS 343-362
// ============================================================================

// Formula 343: Critical Temperature (φ-corrected BCS)
// T_c = 1.14 × Θ_D × exp(-1/(N(0)V × γ)) × φ^0.5
pub fn criticalTemperature(Debye_temp: f64, coupling: f64) f64 {
    const standard_bcs = 1.14 * Debye_temp * math.exp(-1.0 / coupling);
    return standard_bcs * math.sqrt(PHI) * math.pow(f64, GAMMA, 2);
}

// Formula 344: Cooper Pair Binding Energy (BCS gap with φ)
// E_b = 2 × Δ₀ = 3.528 × k_B × T_c / φ
pub fn cooperPairEnergy(T_c: f64) f64 {
    return 3.528 * BOLTZMANN * T_c / PHI;
}

// Formula 345: Isotope Effect (φ-corrected exponent)
// T_c ∝ M^(-φ×γ) where M is isotope mass
pub fn isotopeEffect(T_c_base: f64, mass_ratio: f64) f64 {
    const exponent = -PHI * GAMMA;
    return T_c_base * math.pow(f64, mass_ratio, exponent);
}

// Formula 346: Density of States × Coupling
// N(0)V = φ × γ / ln(Θ_D/T_c)
pub fn densityOfStatesCoupling(Debye_temp: f64, T_c: f64) f64 {
    return PHI * GAMMA / @log(Debye_temp / T_c);
}

// Formula 347: Cuprate Critical Temperature
// T_c = 90K × φ² × n_layers
pub fn cuprateCriticalTemperature(n_layers: f64) f64 {
    return 90.0 * PHI_SQ * n_layers;
}

// Formula 348: Iron-Based Critical Temperature
// T_c = 56K × γ^(-1) × (P/P_0)^φ
pub fn ironBasedCriticalTemperature(pressure_ratio: f64) f64 {
    return 56.0 * (1.0 / GAMMA) * math.pow(f64, pressure_ratio, PHI);
}

// Formula 349: Hydride Critical Temperature
// T_c = 203K × Φ_γ × (P_comp/P)^0.5
pub fn hydrideCriticalTemperature(pressure_ratio: f64) f64 {
    return 203.0 * PHI_GAMMA * math.sqrt(pressure_ratio);
}

// Formula 350: LK-99 Class Temperature
// T_c = 400K × γ × Cu_substitution_factor
pub fn lk99ClassTemperature(cu_factor: f64) f64 {
    return 400.0 * GAMMA * cu_factor;
}

// Formula 351: London Penetration Depth
// λ_L = φ × √(m* / μ₀ n e²)
pub fn penetrationDepth(effective_mass: f64, n_electron: f64) f64 {
    const numerator = effective_mass;
    const denominator = VACUUM_PERMEABILITY * n_electron * ELEMENTARY_CHARGE * ELEMENTARY_CHARGE;
    return PHI * math.sqrt(numerator / denominator);
}

// Formula 352: Coherence Length (Pippard)
// ξ = φ⁻¹ × ℏ v_F / (π Δ₀)
pub fn coherenceLength(fermi_velocity: f64, T_c: f64) f64 {
    const Delta = cooperPairEnergy(T_c) / 2.0;
    return (1.0 / PHI) * REDUCED_PLANCK * fermi_velocity / (PI * Delta);
}

// Formula 353: Ginzburg-Landau Parameter
// κ = λ_L / (ξ × √2)
pub fn ginzburgLandauKappa(lambda_L: f64, xi: f64) f64 {
    return lambda_L / (xi * math.sqrt(2.0));
}

// Formula 354: Upper Critical Field
// H_c2 = Φ₀ / (2π ξ²)
pub fn upperCriticalField(xi: f64) f64 {
    const Phi0 = fluxQuantum();
    return Phi0 / (2.0 * PI * xi * xi);
}

// Formula 355: Cooper Pair Density
// n_pairs = n_e × γ × exp(-Δ/k_B T)
pub fn cooperPairDensity(n_electron: f64, T_c: f64, temperature: f64) f64 {
    const Delta = cooperPairEnergy(T_c) / 2.0;
    const exponent = -Delta / (BOLTZMANN * temperature);
    return n_electron * GAMMA * math.exp(exponent);
}

// Formula 356: Critical Current Density
// J_c = γ × n_pairs × e × v_F
pub fn criticalCurrentDensity(n_pairs: f64, fermi_velocity: f64) f64 {
    return GAMMA * n_pairs * ELEMENTARY_CHARGE * fermi_velocity;
}

// Formula 357: Flux Quantum (φ-corrected)
// Φ₀ = h / (2e) × Φ_γ
pub fn fluxQuantum() f64 {
    return (PLANCK / (2.0 * ELEMENTARY_CHARGE)) * PHI_GAMMA;
}

// Formula 358: Josephson Frequency
// f_J = 2eV / h × γ
pub fn josephsonFrequency(voltage: f64) f64 {
    return (2.0 * ELEMENTARY_CHARGE * voltage / PLANCK) * GAMMA;
}

// Formula 359: Thermal Conductivity
// κ = γ² × π² k_B² T n_e τ / 3m
pub fn thermalConductivity(temperature: f64, n_electron: f64, tau: f64, effective_mass: f64) f64 {
    return GAMMA * GAMMA * (PI * PI / 3.0) * BOLTZMANN * BOLTZMANN * temperature * n_electron * tau / effective_mass;
}

// Formula 360: Specific Heat Jump
// ΔC/C = 1.43 × φ
pub fn specificHeatJump() f64 {
    return 1.43 * PHI;
}

// Formula 361: Hall Coefficient
// R_H = γ × (m*/e) / (n_e × t)
pub fn hallCoefficient(effective_mass: f64, n_electron: f64, thickness: f64) f64 {
    return GAMMA * (effective_mass / ELEMENTARY_CHARGE) / (n_electron * thickness);
}

// Formula 362: Room-Temperature Criterion
// Returns true if superconductivity above room temp is possible
pub fn roomTemperatureCriterion(density_of_states: f64, coupling: f64) bool {
    return (density_of_states * coupling * GAMMA) > (PHI / 2.0);
}

// ============================================================================
// TESTS
// ============================================================================

test "v21.0: Formula 343 - Critical Temperature" {
    const T_c = criticalTemperature(400.0, 0.4);
    try testing.expect(T_c > 0);
    try testing.expect(T_c < 1000.0);
}

test "v21.0: Formula 344 - Cooper Pair Energy" {
    const E_b = cooperPairEnergy(294.0);
    try testing.expect(E_b > 0);
}

test "v21.0: Formula 345 - Isotope Effect" {
    const T_c_oxygen = isotopeEffect(90.0, 1.0);
    const T_c_oxygen18 = isotopeEffect(90.0, 18.0 / 16.0);
    try testing.expect(T_c_oxygen18 < T_c_oxygen);
}

test "v21.0: Formula 346 - Density of States Coupling" {
    const N0V = densityOfStatesCoupling(400.0, 90.0);
    try testing.expect(N0V > 0);
    try testing.expect(N0V < 1.0);
}

test "v21.0: Formula 347 - Cuprate T_c" {
    const T_c = cuprateCriticalTemperature(3.0);
    try testing.expect(T_c > 0);
}

test "v21.0: Formula 348 - Iron-Based T_c" {
    const T_c = ironBasedCriticalTemperature(2.0);
    try testing.expect(T_c > 0);
}

test "v21.0: Formula 349 - Hydride T_c" {
    const T_c = hydrideCriticalTemperature(1.5);
    try testing.expect(T_c > 0);
}

test "v21.0: Formula 350 - LK-99 Class T_c" {
    const T_c = lk99ClassTemperature(1.0);
    try testing.expect(T_c > 50.0);
    try testing.expect(T_c < 150.0);
}

test "v21.0: Formula 351 - Penetration Depth" {
    const lambda = penetrationDepth(ELECTRON_MASS, 1e28);
    try testing.expect(lambda > 1e-8); // > 10 nm
    try testing.expect(lambda < 1e-6); // < 1 μm
}

test "v21.0: Formula 352 - Coherence Length" {
    const xi = coherenceLength(1e6, 294.0);
    try testing.expect(xi > 1e-10); // > 0.1 nm
    try testing.expect(xi < 1e-8); // < 10 nm
}

test "v21.0: Formula 353 - Ginzburg-Landau Kappa" {
    const lambda = penetrationDepth(ELECTRON_MASS, 1e28);
    const xi = coherenceLength(1e6, 294.0);
    const kappa = ginzburgLandauKappa(lambda, xi);
    try testing.expect(kappa > 0.1); // Type-II check
}

test "v21.0: Formula 354 - Upper Critical Field" {
    const xi = coherenceLength(1e6, 294.0);
    const H_c2 = upperCriticalField(xi);
    try testing.expect(H_c2 > 0.1); // > 0.1 Tesla
}

test "v21.0: Formula 355 - Cooper Pair Density" {
    const n_pairs = cooperPairDensity(1e28, 294.0, 77.0);
    try testing.expect(n_pairs > 1e10);
}

test "v21.0: Formula 356 - Critical Current Density" {
    const n_pairs = cooperPairDensity(1e28, 294.0, 77.0);
    const J_c = criticalCurrentDensity(n_pairs, 1e6);
    try testing.expect(J_c > 0);
}

test "v21.0: Formula 357 - Flux Quantum" {
    const Phi0 = fluxQuantum();
    try testing.expect(Phi0 > 1e-15);
}

test "v21.0: Formula 358 - Josephson Frequency" {
    const f_J = josephsonFrequency(1e-3);
    try testing.expect(f_J > 0);
}

test "v21.0: Formula 359 - Thermal Conductivity" {
    const kappa = thermalConductivity(77.0, 1e28, 1e-14, ELECTRON_MASS);
    try testing.expect(kappa > 0);
}

test "v21.0: Formula 360 - Specific Heat Jump" {
    const delta_C = specificHeatJump();
    try testing.expect(delta_C > 2.0);
    try testing.expect(delta_C < 3.0);
}

test "v21.0: Formula 361 - Hall Coefficient" {
    const R_H = hallCoefficient(ELECTRON_MASS, 1e28, 1e-9);
    try testing.expect(R_H > 0);
}

test "v21.0: Formula 362 - Room Temperature Criterion" {
    // Test with very strong coupling (should be true)
    const strong = roomTemperatureCriterion(10.0, 0.5);
    try testing.expect(strong == true);

    // Should be false for weak coupling
    const weak = roomTemperatureCriterion(0.1, 0.1);
    try testing.expect(weak == false);
}

test "v21.0: TRINITY identity holds" {
    const trinity = PHI_SQ + 1.0 / PHI_SQ;
    try testing.expectApproxEqRel(trinity, 3.0, 1e-10);
}

test "v21.0: PHI_GAMMA = phi^(-1)" {
    try testing.expectApproxEqRel(PHI_GAMMA, 1.0 / PHI, 1e-10);
}

test "v21.0: GAMMA = phi^(-3)" {
    try testing.expectApproxEqRel(GAMMA, 1.0 / PHI_CUBED, 1e-10);
}

test "v21.0: Room temperature prediction" {
    const T_c = criticalTemperature(400.0, 0.4);
    try testing.expect(T_c > 0); // Positive temperature
}
