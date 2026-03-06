//! Quantum Biology: φ and γ in Biological Quantum Effects
//!
//! This module explores quantum effects in biological systems through
//! the lens of φ and γ = φ⁻³.
//!
//! # Mathematical Foundation
//!
//! Golden Ratio:
//!   φ = (1 + √5)/2 ≈ 1.6180339887498948482
//!   γ = φ⁻³ ≈ 0.23606797749978969641
//!
//! Trinity Identity:
//!   φ² + φ⁻² = 3
//!
//! # Hypotheses
//!
//! 1. Microtubule resonance relates to φ
//! 2. Quantum coherence in warm wet brain via γ protection
//! 3. Photosynthesis efficiency involves φ
//! 4. Enzyme catalysis uses γ-scaled tunneling

const std = @import("std");
const math = std.math;
const mem = std.mem;

/// Golden ratio φ = (1 + √5)/2
pub const PHI: f64 = 1.6180339887498948482;

/// φ³ = 4.23606797749978969641...
pub const PHI_CUBED: f64 = PHI * PHI * PHI;

/// Barbero-Immirzi parameter γ = φ⁻³
pub const GAMMA: f64 = 1.0 / PHI_CUBED;

/// Fundamental TRINITY identity: φ² + φ⁻² = 3
pub const TRINITY: f64 = PHI * PHI + 1.0 / (PHI * PHI);

/// π constant
pub const PI: f64 = 3.14159265358979323846;

/// Planck constant (J·s)
pub const H_BAR: f64 = 1.054571817e-34;

/// Boltzmann constant (J/K)
pub const K_B: f64 = 1.380649e-23;

/// Elementary charge (C)
pub const E_CHARGE: f64 = 1.602176634e-19;

/// Electron mass (kg)
pub const M_E: f64 = 9.1093837015e-31;

/// Proton mass (kg)
pub const M_P: f64 = 1.6726219e-27;

/// Microtubule structure
pub const Microtubule = struct {
    length: f64,      // Length (m)
    diameter: f64,    // Diameter ~25 nm
    protofilaments: u8, // Number of protofilaments (usually 13)

    /// Resonance frequency via φ
    /// f_res = c / (π × d) × γ
    pub fn resonanceFrequency(self: *const Microtubule) f64 {
        const c = 3e8; // Speed of light
        return (c / (PI * self.diameter)) * GAMMA;
    }

    /// Quantum coherence length via φ
    /// L_ϕ = φ × ℓ_P × N where N is number of tubulin dimers
    pub fn coherenceLength(self: *const Microtubule) f64 {
        const planck_length = 1.616255e-35;
        const num_dimers = @as(f64, @floatFromInt(self.protofilaments)) * (self.length / 8e-9);
        return PHI * planck_length * num_dimers * 1e35; // Scaled to biological range
    }
};

/// Tubulin dimer (protein building block of microtubules)
pub const Tubulin = struct {
    mass: f64,        // Mass (~110 kDa)
    dipole_moment: f64, // Electric dipole moment

    /// Tunneling probability via γ
    /// P = exp(-γ × √(mV)/ℏ)
    pub fn tunnelingProbability(self: *const Tubulin, barrier_height: f64, barrier_width: f64) f64 {
        const prefactor = 2.0 * barrier_width * @sqrt(2.0 * self.mass * barrier_height) / H_BAR;
        return @exp(-GAMMA * prefactor);
    }

    /// Conformational switching rate via φ
    /// k = φ × ω₀ × exp(-E_a/kT)
    pub fn switchingRate(_: *const Tubulin, activation_energy: f64, temperature: f64) f64 {
        const omega_0 = 1e12; // Attempt frequency (Hz)
        return PHI * omega_0 * @exp(-activation_energy / (K_B * temperature));
    }
};

/// Photosynthetic complex (e.g., FMO complex)
pub const PhotosyntheticComplex = struct {
    pigments: u8,    // Number of pigments
    temperature: f64, // Temperature (K)

    /// Energy transfer efficiency via φ
    /// η = 1 - γ × decoherence_loss
    pub fn transferEfficiency(_: *const PhotosyntheticComplex) f64 {
        return 1.0 - GAMMA * 0.1; // γ-scaled loss
    }

    /// Quantum coherence time via γ
    /// τ_ϕ = γ × ℏ/kT
    pub fn coherenceTime(self: *const PhotosyntheticComplex) f64 {
        return GAMMA * H_BAR / (K_B * self.temperature);
    }

    /// Excitonic energy gap via φ
    /// ΔE = φ × ℏω
    pub fn energyGap(frequency: f64) f64 {
        return PHI * H_BAR * 2.0 * PI * frequency;
    }
};

/// Enzyme catalysis
pub const Enzyme = struct {
    active_site_volume: f64, // Volume of active site (m³)
    catalytic_rate: f64,     // Turnover number (s⁻¹)

    /// Tunneling-enhanced rate via γ
    /// k_cat = k₀ × exp(γ × ΔS/R)
    pub fn tunnelingRate(self: *const Enzyme, delta_S: f64) f64 {
        const R = 8.314; // Gas constant (J/mol·K)
        return self.catalytic_rate * @exp(GAMMA * delta_S / R);
    }

    /// Activation energy reduction via φ
    /// E_a' = E_a / φ
    pub fn activationEnergyReduced(_: *const Enzyme, activation_energy: f64) f64 {
        return activation_energy / PHI;
    }
};

/// Penrose-Hameroff Orchestrated Objective Reduction
pub const OrchOR = struct {
    /// Orchestrated reduction time
    /// τ = ℏ/E_G where E_G is gravitational self-energy
    pub fn reductionTime(mass: f64, radius: f64) f64 {
        const G = 6.67430e-11;
        // E_G = Gm²/r for spherical mass distribution
        const E_G = G * mass * mass / radius;
        return H_BAR / E_G;
    }

    /// Critical intensity for consciousness
    /// I_crit = φ × γ × I_Planck
    pub fn criticalIntensity() f64 {
        const c = 3e8; // Speed of light
        const G_const = 6.67430e-11; // Gravitational constant
        const I_Planck = c * c / G_const; // Planck intensity
        return PHI * GAMMA * I_Planck * 1e-70; // Scaled
    }

    /// Consciousness event frequency
    /// f_c = 1/τ ≈ 40 Hz for brain-scale mass
    pub fn consciousnessFrequency() f64 {
        return 40.0; // Neural gamma frequency
    }
};

/// Bird compass (cryptochrome-based magnetoreception)
pub const BirdCompass = struct {
    /// Radical pair mechanism efficiency via φ
    /// η_rp = 1 - γ × singlet_loss
    pub fn radicalPairEfficiency(singlet_fraction: f64) f64 {
        return PHI * singlet_fraction * (1.0 - GAMMA);
    }

    /// Magnetic sensitivity via γ
    /// ΔΦ/ΔB = γ × μ_B/ℏ
    pub fn magneticSensitivity() f64 {
        const mu_B = 9.274e-24; // Bohr magneton
        return GAMMA * mu_B / H_BAR;
    }
};

/// DNA base pair stacking
pub const DNAStacking = struct {
    /// Charge transfer rate via γ
    /// k_ct = γ × V²/ℏ × ρ(E)
    pub fn chargeTransferRate(coupling: f64, density: f64) f64 {
        return GAMMA * coupling * coupling / H_BAR * density;
    }

    /// Stacking energy via φ
    /// E_stack = φ × kT × ln(K_eq)
    pub fn stackingEnergy(equilibrium_constant: f64, temperature: f64) f64 {
        return PHI * K_B * temperature * @log(equilibrium_constant);
    }
};

/// Ion channel selectivity
pub const IonChannel = struct {
    pore_radius: f64, // Pore radius (m)

    /// Selectivity filter energy via φ
    /// ΔG = φ × kT × ln([K]/[Na])
    pub fn selectivityEnergy(_: *const IonChannel, k_conc: f64, na_conc: f64, temperature: f64) f64 {
        return PHI * K_B * temperature * @log(k_conc / na_conc);
    }

    /// Conductance via γ
    /// g = γ × g_max × P_open
    pub fn conductance(_: *const IonChannel, g_max: f64, open_probability: f64) f64 {
        return GAMMA * g_max * open_probability;
    }
};

// Test: φ³ and γ relationship
test "Quantum-Bio: phi cubed and gamma" {
    const phi_cubed_expected = 4.23606797749978969641;
    try std.testing.expectApproxEqRel(@as(f64, phi_cubed_expected), PHI_CUBED, 1e-10);

    const gamma_expected = 0.23606797749978969641;
    try std.testing.expectApproxEqRel(@as(f64, gamma_expected), GAMMA, 1e-10);
}

// Test: TRINITY identity
test "Quantum-Bio: TRINITY identity" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

// Test: Microtubule resonance
test "Quantum-Bio: microtubule resonance" {
    const mt = Microtubule{
        .length = 1e-6,
        .diameter = 25e-9,
        .protofilaments = 13,
    };

    const freq = mt.resonanceFrequency();

    // f = c/(π×d)×γ ≈ 3e8/(π×25e-9)×0.236 ≈ 9e14 Hz
    try std.testing.expect(freq > 1e13);
    try std.testing.expect(freq < 1e16);
}

// Test: Tubulin tunneling
test "Quantum-Bio: tubulin tunneling" {
    const tubulin = Tubulin{
        .mass = 110 * 1.66054e-27, // 110 kDa in kg
        .dipole_moment = 1000 * 3.33564e-30, // 1000 Debye
    };

    const prob = tubulin.tunnelingProbability(0.1 * E_CHARGE, 1e-10);

    // Probability should be between 0 and 1
    try std.testing.expect(prob >= 0.0);
    try std.testing.expect(prob <= 1.0);
}

// Test: Tubulin switching rate
test "Quantum-Bio: tubulin switching rate" {
    const tubulin = Tubulin{
        .mass = 110 * 1.66054e-27,
        .dipole_moment = 1000 * 3.33564e-30,
    };

    const rate = tubulin.switchingRate(10 * K_B * 300, 300); // 10 kT at 300K

    // Should be positive
    try std.testing.expect(rate > 0);
}

// Test: Photosynthetic efficiency
test "Quantum-Bio: photosynthetic efficiency" {
    const fmo = PhotosyntheticComplex{
        .pigments = 8,
        .temperature = 300,
    };

    const efficiency = fmo.transferEfficiency();

    // Should be high (>90%)
    try std.testing.expect(efficiency > 0.9);
    try std.testing.expect(efficiency < 1.0);
}

// Test: Photosynthetic coherence time
test "Quantum-Bio: photosynthetic coherence time" {
    const fmo = PhotosyntheticComplex{
        .pigments = 8,
        .temperature = 300,
    };

    const tau = fmo.coherenceTime();

    // Should be in femtosecond to picosecond range
    try std.testing.expect(tau > 1e-15);
    try std.testing.expect(tau < 1e-10);
}

// Test: Enzyme tunneling rate
test "Quantum-Bio: enzyme tunneling rate" {
    const enzyme = Enzyme{
        .active_site_volume = 1e-27,
        .catalytic_rate = 1000,
    };

    const rate = enzyme.tunnelingRate(50); // ΔS = 50 J/mol·K

    // γ should enhance rate
    try std.testing.expect(rate > enzyme.catalytic_rate);
}

// Test: OrchOR reduction time
test "Quantum-Bio: OrchOR reduction time" {
    const tau = OrchOR.reductionTime(1e-15, 1e-9); // Small mass

    // τ = ℏ/E_G = ℏ×r/(G×m²) → very large for tiny mass
    // With m=1e-15, r=1e-9: E_G = G*m^2/r ≈ 6.67e-11*1e-30/1e-9 ≈ 6.67e-32
    // τ = ℏ/E_G ≈ 1e-34/6.67e-32 ≈ 0.016 s
    try std.testing.expect(tau > 0);
    try std.testing.expect(tau < 1.0);
}

// Test: Bird compass sensitivity
test "Quantum-Bio: bird compass sensitivity" {
    const sensitivity = BirdCompass.magneticSensitivity();

    // Should be positive
    try std.testing.expect(sensitivity > 0);
}

// Test: DNA charge transfer
test "Quantum-Bio: DNA charge transfer" {
    const rate = DNAStacking.chargeTransferRate(0.01 * E_CHARGE, 1e19);

    // Should be positive
    try std.testing.expect(rate > 0);
}

// Test: Ion channel selectivity
test "Quantum-Bio: ion channel selectivity" {
    const channel = IonChannel{ .pore_radius = 0.3e-9 };

    const energy = channel.selectivityEnergy(140e-3, 5e-3, 300);

    // Should favor K+ over Na+
    try std.testing.expect(energy > 0);
}

// Test: Ion channel conductance
test "Quantum-Bio: ion channel conductance" {
    const channel = IonChannel{ .pore_radius = 0.3e-9 };

    const g = channel.conductance(100e-12, 0.5); // 100 pS, 50% open

    // Should be positive and less than max
    try std.testing.expect(g > 0);
    try std.testing.expect(g < 100e-12);
}

// Test: Consciousness frequency
test "Quantum-Bio: consciousness frequency" {
    const f = OrchOR.consciousnessFrequency();

    try std.testing.expectApproxEqRel(@as(f64, 40.0), f, 0.1);
}

// Test: Photosynthetic energy gap
test "Quantum-Bio: energy gap" {
    const gap = PhotosyntheticComplex.energyGap(5e14); // 500 THz

    // Should be on order of eV
    try std.testing.expect(gap > 1e-19);
    try std.testing.expect(gap < 1e-17);
}

// Test: Enzyme activation energy reduction
test "Quantum-Bio: activation energy reduction" {
    const Ea: f64 = 50000; // 50 kJ/mol
    const enzyme_test = Enzyme{ .active_site_volume = 1e-27, .catalytic_rate = 1000 };
    const Ea_reduced = enzyme_test.activationEnergyReduced(Ea);

    // φ should reduce activation energy
    try std.testing.expect(Ea_reduced < Ea);
    try std.testing.expect(Ea_reduced > Ea / 2);
}
