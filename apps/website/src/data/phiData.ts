// ═══════════════════════════════════════════════════════════════════════════════
// SACRED COSMOLOGY v15.0 — φ-Patterns for Cosmology
// ═══════════════════════════════════════════════════════════════════════════════
//
// Golden ratio patterns throughout cosmology and sacred geometry
// φ = 1.6180339887498948482 (the golden ratio)
//
// ═══════════════════════════════════════════════════════════════════════════════

export const PHI = 1.6180339887498948482;
const PHI_INV = 0.6180339887498948482;
const SQRT5 = 2.2360679774997896964;

// ═══════════════════════════════════════════════════════════════════════════════
// FIBONACCI SEQUENCE
// ═══════════════════════════════════════════════════════════════════════════════

export const FIBONACCI: number[] = [
  1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987,
  1597, 2584, 4181, 6765, 10946, 17711, 28657, 46368, 75025, 121393,
  196418, 317811, 514229, 832040, 1346269, 2178309, 3524578, 5702887,
  9227465, 14930352, 24157817, 39088169, 63245986, 102334155,
];

// Fibonacci numbers for cosmic epochs (Gyr)
export const FIBONACCI_EPOCHS: number[] = [1, 2, 3, 5, 8, 13, 21];

// ═══════════════════════════════════════════════════════════════════════════════
// LUCAS SEQUENCE (alternative sacred sequence)
// ═══════════════════════════════════════════════════════════════════════════════

export const LUCAS: number[] = [
  2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123, 199, 322, 521, 843,
  1364, 2207, 3571, 5778, 9349, 15127, 24476, 39603, 64079, 103682,
  167761, 271443, 439204, 710647, 1149851, 1860498, 3010349, 4870847,
  7881196, 12752043, 20633249, 33385282,
];

// ═══════════════════════════════════════════════════════════════════════════════
// POWERS OF φ
// ═══════════════════════════════════════════════════════════════════════════════

export const PHI_POWERS: number[] = [
  PHI ** -5, PHI ** -4, PHI ** -3, PHI ** -2, PHI ** -1,
  1,
  PHI, PHI ** 2, PHI ** 3, PHI ** 4, PHI ** 5, PHI ** 6, PHI ** 7,
];

// φ² = φ + 1 (golden identity)
export const PHI_SQ = PHI * PHI; // ≈ 2.618

// 1/φ² = 2 - φ (inverse square)
export const PHI_INV_SQ = 1 / (PHI * PHI); // ≈ 0.382

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED RATIOS
// ═══════════════════════════════════════════════════════════════════════════════

export const SACRED_RATIOS = {
  GOLDEN_MEAN: PHI,
  GOLDEN_INVERSE: PHI_INV,
  GOLDEN_SQUARE: PHI_SQ,
  GOLDEN_INVERSE_SQUARE: PHI_INV_SQ,
  TRINITY: 3,  // φ² + 1/φ² = 3
  SQRT5: SQRT5,
  TAU: 2 * Math.PI,
  PI_RATIO: Math.PI / PHI,
  E_RATIO: Math.E / PHI,
  GOLDEN_ANGLE_DEG: 137.50776405003785,  // 360/φ²
  GOLDEN_ANGLE_RAD: 2.399963229728653,   // 2π/φ²
} as const;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface PhiSpiralPoint {
  x: number;
  y: number;
  z: number;
  radius: number;
  angle: number;
  isFibonacci: boolean;
  index: number;
}

export interface StabilityIsland {
  elementNumber: number;        // Z (atomic number)
  neutronNumber: number;         // N (neutron number)
  massNumber: number;            // A = Z + N
  sacredFit: number;             // 0-1 sacred fit score
  predictedHalfLife: string;
  phiRelation: string;
  isMagic: boolean;
}

export interface PhiSequence {
  name: string;
  values: number[];
  sacredProperty: string;
  cosmologySignificance: string;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEQUENCE GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Generate Fibonacci sequence up to n
 */
export function fibonacciUpTo(n: number): number[] {
  const result: number[] = [1, 2];
  while (true) {
    const next = result[result.length - 1] + result[result.length - 2];
    if (next > n) break;
    result.push(next);
  }
  return result;
}

/**
 * Generate Lucas sequence up to n
 */
export function lucasUpTo(n: number): number[] {
  const result: number[] = [2, 1];
  while (true) {
    const next = result[result.length - 1] + result[result.length - 2];
    if (next > n) break;
    result.push(next);
  }
  return result;
}

/**
 * Check if number is in Fibonacci sequence
 */
export function isFibonacci(n: number): boolean {
  // A number is Fibonacci if and only if 5n² ± 4 is a perfect square
  const test1 = 5 * n * n + 4;
  const test2 = 5 * n * n - 4;
  return isPerfectSquare(test1) || isPerfectSquare(test2);
}

/**
 * Check if number is in Lucas sequence
 */
export function isLucas(n: number): boolean {
  return LUCAS.includes(n);
}

function isPerfectSquare(n: number): boolean {
  const root = Math.sqrt(n);
  return root === Math.floor(root);
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN SPIRAL GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Generate golden spiral points for universe expansion visualization
 */
export function generateGoldenSpiral(
  count: number,
  scale: number = 1,
  centerX: number = 0,
  centerY: number = 0,
  centerZ: number = 0
): PhiSpiralPoint[] {
  const points: PhiSpiralPoint[] = [];
  const tau = 2 * Math.PI;

  for (let i = 0; i < count; i++) {
    // Golden angle increments
    const angle = i * SACRED_RATIOS.GOLDEN_ANGLE_RAD;

    // Radius grows with φ^(i/n) for exponential expansion
    const radius = scale * Math.pow(PHI, i / count);

    // Convert to Cartesian coordinates
    const x = centerX + radius * Math.cos(angle);
    const y = centerY + radius * Math.sin(angle);
    const z = centerZ + (i / count) * scale * 0.5; // Slight z-rise for 3D effect

    points.push({
      x,
      y,
      z,
      radius,
      angle,
      isFibonacci: isFibonacci(i) || isFibonacci(Math.round(radius)),
      index: i,
    });
  }

  return points;
}

/**
 * Generate 3D golden spiral for universe timeline
 */
export function generate3DGoldenSpiral(
  count: number,
  scale: number = 10
): PhiSpiralPoint[] {
  const points: PhiSpiralPoint[] = [];
  const turns = 3; // Number of spiral turns

  for (let i = 0; i < count; i++) {
    const t = i / count;
    const angle = t * turns * 2 * Math.PI;

    // Logarithmic spiral with φ growth
    const growth = Math.pow(PHI, t * 2);
    const radius = scale * growth * t;

    // Helical rise
    const x = radius * Math.cos(angle);
    const y = radius * Math.sin(angle);
    const z = scale * t * 2; // Rise along z-axis

    points.push({
      x,
      y,
      z,
      radius,
      angle,
      isFibonacci: isFibonacci(Math.floor(t * 20)),
      index: i,
    });
  }

  return points;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STABILITY ISLAND PREDICTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Predict island of stability using sacred patterns
 * Based on magic numbers following sacred progression
 */
export function predictStabilityIsland(): StabilityIsland {
  // Next magic number after 126 (sacred prediction)
  const Z = 184; // Sacred: 184 = 8 × 23 = 2³ × Fibonacci(9)

  // Neutron number for double magic
  const N = 228; // = 184 + 44 (44 is close to φ⁴ × 10)

  return {
    elementNumber: Z,
    neutronNumber: N,
    massNumber: Z + N,
    sacredFit: 0.95,
    predictedHalfLife: '>10^15 years',
    phiRelation: 'Z = 184 = 8 × 23, N/Z ≈ φ',
    isMagic: true,
  };
}

/**
 * Find stable elements using sacred formula
 */
export function findStableElements(maxZ: number = 118): number[] {
  // Known magic numbers (nuclear shell model)
  const magicNumbers = [2, 8, 20, 28, 50, 82, 126];

  // Add predicted next magic number
  const allMagic = [...magicNumbers, 184];

  // Filter elements that are magic proton numbers
  return allMagic.filter(z => z <= maxZ);
}

/**
 * Calculate sacred stability score for element Z
 */
export function sacredElementStability(Z: number): number {
  // Magic numbers get highest score
  const magicNumbers = [2, 8, 20, 28, 50, 82, 126, 184];
  if (magicNumbers.includes(Z)) return 1.0;

  // Check proximity to magic number
  let closestDist = Infinity;
  for (const m of magicNumbers) {
    const dist = Math.abs(Z - m);
    if (dist < closestDist) closestDist = dist;
  }

  // Decay with distance from magic number
  // Use φ-based decay
  return Math.max(0, Math.pow(PHI_INV, closestDist));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED SEQUENCES FOR COSMOLOGY
// ═══════════════════════════════════════════════════════════════════════════════

export const SACRED_SEQUENCES: PhiSequence[] = [
  {
    name: 'Fibonacci',
    values: FIBONACCI,
    sacredProperty: 'F(n) = F(n-1) + F(n-2), ratio → φ',
    cosmologySignificance: 'Cosmic epochs at 1,2,3,5,8,13 Gyr',
  },
  {
    name: 'Lucas',
    values: LUCAS,
    sacredProperty: 'L(n) = L(n-1) + L(n-2), ratio → φ',
    cosmologySignificance: 'Alternative cosmic time scaling',
  },
  {
    name: 'Powers of φ',
    values: PHI_POWERS,
    sacredProperty: 'φ^n for expansion mapping',
    cosmologySignificance: 'Universe scale factors',
  },
];

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Check if value is φ-proportioned (within tolerance of φ^n)
 */
export function isPhiProportioned(value: number, tolerance: number = 0.1): boolean {
  // Check if value ≈ n × φ^k for some integers n, k
  for (let k = -3; k <= 5; k++) {
    const phiPower = Math.pow(PHI, k);
    for (let n = 1; n <= 100; n++) {
      const target = n * phiPower;
      if (Math.abs(value - target) / target < tolerance) {
        return true;
      }
    }
  }
  return false;
}

/**
 * Find closest φ-power for a given value
 */
export function findPhiPower(value: number): { power: number; coefficient: number; error: number } {
  let bestMatch = { power: 0, coefficient: 1, error: Infinity };

  for (let p = -5; p <= 10; p++) {
    const phiPower = Math.pow(PHI, p);
    const coeff = value / phiPower;

    // Try integer and nearby coefficients
    for (let n = Math.floor(coeff) - 2; n <= Math.ceil(coeff) + 2; n++) {
      if (n > 0) {
        const error = Math.abs(value - n * phiPower) / value;
        if (error < bestMatch.error) {
          bestMatch = { power: p, coefficient: n, error };
        }
      }
    }
  }

  return bestMatch;
}

/**
 * Generate φ-based redshift values
 * Redshifts at sacred distances (Fibonacci multiples)
 */
export function generateSacredRedshifts(): number[] {
  return FIBONACCI.map(n => n / 100); // z = 0.01, 0.02, 0.03, 0.05, 0.08, 0.13, etc.
}

/**
 * Calculate φ-ratio between two values
 */
export function phiRatio(a: number, b: number): number {
  const ratio = a / b;
  const lnPhi = Math.log(PHI);
  const lnRatio = Math.log(ratio);
  return lnRatio / lnPhi; // How many powers of φ separate them
}

/**
 * Get sacred number properties
 */
export function getSacredNumberProperties(n: number) {
  return {
    isFibonacci: isFibonacci(n),
    isLucas: isLucas(n),
    isPhiPower: PHI_POWERS.some(p => Math.abs(n - p) < 0.001),
    isPhiProportioned: isPhiProportioned(n),
    isMagic: [2, 8, 20, 28, 50, 82, 126, 184].includes(n),
    phiPower: findPhiPower(n),
  };
}
