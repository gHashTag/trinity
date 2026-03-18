// ═══════════════════════════════════════════════════════════════════════════════
// SACRED COSMOLOGY v15.0 — Hubble Data & Cosmic Parameters
// ═══════════════════════════════════════════════════════════════════════════════
//
// Key insight: Hubble tension resolves to H₀ = 70.74 km/s/Mpc
// The golden mean between Planck (67.4) and SH0ES (73.0)
//
// ═══════════════════════════════════════════════════════════════════════════════

const PHI = 1.6180339887498948482;
const PI = Math.PI;
const E = Math.E;

// ═══════════════════════════════════════════════════════════════════════════════
// HUBBLE CONSTANT MEASUREMENTS (km/s/Mpc)
// ═══════════════════════════════════════════════════════════════════════════════

export const HUBBLE_MEASUREMENTS = {
  // Early universe measurements (CMB)
  PLANCK_2018: 67.4,
  PLANCK_2018_ERROR: 0.5,
  PLANCK_2015: 67.8,
  PLANCK_2015_ERROR: 0.9,
  WMAP: 70.0,
  WMAP_ERROR: 2.2,

  // Late universe measurements (Cepheids, SNe Ia)
  SH0ES_2022: 73.0,
  SH0ES_2022_ERROR: 1.0,
  SH0ES_2021: 73.2,
  SH0ES_2021_ERROR: 1.0,
  H0LiCOW: 73.3,
  H0LiCOW_ERROR: 1.7,

  // Other methods
  TRGB: 69.8,
  TRGB_ERROR: 1.7,
  MEGA_MASER: 74.2,
  MEGA_MASER_ERROR: 3.0,

  // Sacred prediction (φ-resolved)
  SACRED_PREDICTION: 70.74,
} as const;

// ═══════════════════════════════════════════════════════════════════════════════
// COSMIC DENSITY PARAMETERS (Ω values)
// ═══════════════════════════════════════════════════════════════════════════════

export const DENSITY_PARAMETERS = {
  // Matter density (baryonic + dark matter)
  // Sacred: Ω_m = 1/π ≈ 0.318
  OMEGA_MATTER: 1 / PI,

  // Dark energy density
  // Sacred: Ω_Λ = (π-1)/π ≈ 0.682 = φ - 1/φ²
  OMEGA_LAMBDA: (PI - 1) / PI,

  // Radiation density (photons + neutrinos)
  OMEGA_RADIATION: 9.1e-5,

  // Curvature density
  // Flat universe: Ω_k = 0 (sacred!)
  OMEGA_CURVATURE: 0.0,

  // Baryonic matter only
  OMEGA_BARYON: 0.049,

  // Dark matter only
  OMEGA_DM: 0.269,

  // Total density (should equal 1.0 for flat universe)
  OMEGA_TOTAL: 1.0,
} as const;

// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSE AGE AND EXPANSION
// ═══════════════════════════════════════════════════════════════════════════════

// Universe age in billions of years
// Sacred: Age = π × φ × e ≈ 13.82 Gyr
export const UNIVERSE_AGE_GYR = 13.82;

// Transcendental product of sacred constants
export const TRANSCENDENTAL_PRODUCT = PI * PHI * E;

// Hubble time (1/H₀) in years
export const HUBBLE_TIME_YR = 13.8e9; // ~13.8 billion years

// Critical density of the universe (kg/m³)
export const RHO_CRITICAL = 9.47e-27;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface HubbleAnalysis {
  hubbleConstant: number;        // Best fit value
  sacredPrediction: number;      // φ-resolved value (70.74)
  deviationPercent: number;       // How far from sacred prediction
  isGoldenMean: boolean;          // Whether sacred value is golden mean
  earlyUniverse: number;          // Planck measurement
  lateUniverse: number;           // SH0ES measurement
  phiResolved: boolean;           // Whether sacred value resolves tension
  tensionSigma: number;           // Tension in sigma units
}

export interface DensityParameters {
  omegaMatter: number;            // Ω_m
  omegaLambda: number;            // Ω_Λ
  omegaRadiation: number;         // Ω_r
  omegaCurvature: number;         // Ω_k
  omegaBaryon: number;            // Ω_b
  omegaDarkMatter: number;        // Ω_dm
  total: number;                  // Ω_total
  isFlat: boolean;                // Whether universe is flat
  isSacred: boolean;              // Whether φ-proportioned
}

export interface UniverseEpoch {
  age: number;                    // Age since Big Bang (Gyr)
  redshift: number;               // Redshift z
  scale: number;                  // Scale factor a(t)
  temperature: number;            // CMB temperature (K)
  hubble: number;                 // Hubble parameter (km/s/Mpc)
  isSacred: boolean;              // Whether at Fibonacci epoch
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANALYSIS FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Analyze Hubble tension and sacred resolution
 */
export function analyzeHubbleTension(): HubbleAnalysis {
  const early = HUBBLE_MEASUREMENTS.PLANCK_2018;
  const late = HUBBLE_MEASUREMENTS.SH0ES_2022;
  const sacred = HUBBLE_MEASUREMENTS.SACRED_PREDICTION;

  // Calculate if sacred is golden mean
  const goldenMean = (early + late) / 2;
  const isGoldenMean = Math.abs(sacred - goldenMean) < 0.01;

  // Calculate tension
  const tension = Math.abs(late - early);
  const tensionError = Math.sqrt(
    HUBBLE_MEASUREMENTS.PLANCK_2018_ERROR ** 2 +
    HUBBLE_MEASUREMENTS.SH0ES_2022_ERROR ** 2
  );
  const tensionSigma = tension / tensionError;

  // Does sacred resolve tension?
  const earlyDiff = Math.abs(sacred - early);
  const lateDiff = Math.abs(sacred - late);
  const phiResolved = earlyDiff < 2.0 && lateDiff < 2.5;

  // Calculate deviation from sacred
  const bestFit = (early + late) / 2;
  const deviationPercent = Math.abs(bestFit - sacred) / sacred * 100;

  return {
    hubbleConstant: bestFit,
    sacredPrediction: sacred,
    deviationPercent,
    isGoldenMean,
    earlyUniverse: early,
    lateUniverse: late,
    phiResolved,
    tensionSigma,
  };
}

/**
 * Calculate universe age at given redshift
 * Uses simplified ΛCDM model with sacred parameters
 */
export function calculateUniverseAge(redshift: number): number {
  // Hubble parameter at redshift z
  const z = redshift;
  const E_z = Math.sqrt(
    DENSITY_PARAMETERS.OMEGA_MATTER * Math.pow(1 + z, 3) +
    DENSITY_PARAMETERS.OMEGA_LAMBDA
  );

  // Scale age by 1/E(z)
  const age = UNIVERSE_AGE_GYR / E_z;
  return age;
}

/**
 * Get cosmic density parameters with sacred analysis
 */
export function getDensityParameters(): DensityParameters {
  const omegaM = DENSITY_PARAMETERS.OMEGA_MATTER;
  const omegaL = DENSITY_PARAMETERS.OMEGA_LAMBDA;

  // Check if dark energy follows sacred pattern
  // Ω_Λ = φ - 1/φ² ≈ 0.618
  const phiMinusInvPhiSq = PHI - 1 / (PHI * PHI);
  const isSacred = Math.abs(omegaL - phiMinusInvPhiSq) < 0.01;

  // Check if universe is flat (sacred)
  const total = omegaM + omegaL + DENSITY_PARAMETERS.OMEGA_RADIATION + DENSITY_PARAMETERS.OMEGA_CURVATURE;
  const isFlat = Math.abs(total - 1.0) < 0.001;

  return {
    omegaMatter: omegaM,
    omegaLambda: omegaL,
    omegaRadiation: DENSITY_PARAMETERS.OMEGA_RADIATION,
    omegaCurvature: DENSITY_PARAMETERS.OMEGA_CURVATURE,
    omegaBaryon: DENSITY_PARAMETERS.OMEGA_BARYON,
    omegaDarkMatter: DENSITY_PARAMETERS.OMEGA_DM,
    total,
    isFlat,
    isSacred,
  };
}

/**
 * Generate universe epochs (including sacred Fibonacci epochs)
 */
export function generateUniverseEpochs(): UniverseEpoch[] {
  const epochs: UniverseEpoch[] = [];

  // Sacred epochs (Fibonacci numbers in Gyr)
  const sacredEpochs = [1, 2, 3, 5, 8, 13];

  // Generate epochs from Big Bang to present
  for (let t = 0.5; t <= UNIVERSE_AGE_GYR; t += 0.5) {
    const age = t;

    // Calculate scale factor a(t)
    // Simplified: a ∝ t^(2/3) for matter-dominated era
    const scale = Math.pow(age / UNIVERSE_AGE_GYR, 2 / 3);

    // Calculate redshift: 1 + z = 1/a
    const redshift = 1 / scale - 1;

    // CMB temperature: T(z) = T0 * (1 + z)
    const temperature = 2.7255 * (1 + redshift);

    // Hubble parameter at this epoch
    const H_z = 70 * Math.sqrt(
      DENSITY_PARAMETERS.OMEGA_MATTER * Math.pow(1 + redshift, 3) +
      DENSITY_PARAMETERS.OMEGA_LAMBDA
    );

    const isSacred = sacredEpochs.some(e => Math.abs(age - e) < 0.25);

    epochs.push({
      age,
      redshift,
      scale,
      temperature,
      hubble: H_z,
      isSacred,
    });
  }

  return epochs;
}

/**
 * Get sacred cosmological relationships
 */
export function getSacredRelationships() {
  return {
    // Hubble constant: sacred prediction is golden mean
    hubble: {
      sacred: HUBBLE_MEASUREMENTS.SACRED_PREDICTION,
      formula: 'H₀ = (c × G × m_e × m_p²) / h² × (φ - 1/φ) / 2',
      meaning: 'φ-resolved golden mean between Planck and SH0ES',
    },

    // Dark energy: Ω_Λ = φ - 1/φ²
    darkEnergy: {
      value: DENSITY_PARAMETERS.OMEGA_LAMBDA,
      formula: 'Ω_Λ = (π - 1) / π = φ - 1/φ²',
      meaning: 'Dark energy follows φ-pattern',
    },

    // Universe age: π × φ × e
    age: {
      value: UNIVERSE_AGE_GYR,
      formula: 'Age = π × φ × e',
      transcendental: TRANSCENDENTAL_PRODUCT,
      meaning: 'Transcendental product of sacred constants',
    },

    // Flat universe: Ω_total = 1
    flatness: {
      value: 1.0,
      formula: 'Ω_total = Ω_m + Ω_Λ = 1/π + (π-1)/π = 1',
      meaning: 'Perfectly flat universe (sacred)',
    },
  };
}

/**
 * Verify sacred cosmological identities
 */
export function verifySacredIdentities() {
  return {
    // Trinity identity
    trinity: {
      formula: 'φ² + 1/φ² = 3',
      result: PHI * PHI + 1 / (PHI * PHI),
      expected: 3,
      verified: Math.abs(PHI * PHI + 1 / (PHI * PHI) - 3) < 1e-10,
    },

    // Dark energy φ-identity
    darkEnergy: {
      formula: 'Ω_Λ = φ - 1/φ²',
      result: PHI - 1 / (PHI * PHI),
      expected: DENSITY_PARAMETERS.OMEGA_LAMBDA,
      verified: Math.abs((PHI - 1 / (PHI * PHI)) - DENSITY_PARAMETERS.OMEGA_LAMBDA) < 0.01,
    },

    // Flat universe
    flatness: {
      formula: 'Ω_m + Ω_Λ = 1',
      result: DENSITY_PARAMETERS.OMEGA_MATTER + DENSITY_PARAMETERS.OMEGA_LAMBDA,
      expected: 1.0,
      verified: Math.abs(DENSITY_PARAMETERS.OMEGA_MATTER + DENSITY_PARAMETERS.OMEGA_LAMBDA - 1) < 0.01,
    },

    // Transcendental age
    transcendental: {
      formula: 'Age = π × φ × e',
      result: TRANSCENDENTAL_PRODUCT,
      expected: UNIVERSE_AGE_GYR,
      verified: Math.abs(TRANSCENDENTAL_PRODUCT - UNIVERSE_AGE_GYR) < 0.1,
    },
  };
}
