// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BIOLOGY v14.0 — DNA GEOMETRY
// DNA double helix geometry with sacred constants
// ═══════════════════════════════════════════════════════════════════════════════

import { AMINO_ACIDS } from './aminoAcids';

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const PHI = 1.6180339887498948482;
const PHI_SQ = PHI * PHI;  // 2.618...

// DNA double helix geometry (B-form DNA)
export const DNA_HELIX = {
  // Sacred: 3.4 Å ≈ φ + 2, 34 ≈ φ⁴ (close)
  risePerBasePair: 3.4,      // Å — vertical rise per base pair
  twistPerBasePair: 36,      // degrees — 360°/10 = sacred 10
  basesPerTurn: 10,          // sacred number
  pitch: 34,                 // Å — 34 = FIBONACCI, close to φ⁴
  diameter: 20,              // Å — helix diameter
  helixRadius: 10,           // Å — radius from center to backbone
};

// Base pair properties
export const BASE_PAIR = {
  // A-T: 2 hydrogen bonds
  AT: { bonds: 2, energy: 7.2 },  // kcal/mol
  // G-C: 3 hydrogen bonds (sacred ternary +1)
  GC: { bonds: 3, energy: 9.8 },  // kcal/mol
};

// Colors for bases (following CPK convention with sacred highlights)
export const BASE_COLORS = {
  A: '#50C878',  // Adenine — green (Emerald)
  T: '#FF6B6B',  // Thymine — red (Ruby)
  G: '#FFD700',  // Guanine — gold (φ! sacred metal)
  C: '#6BCFFF',  // Cytosine — cyan (Sky)
  U: '#FF9EC4',  // Uracil — pink (RNA only)
};

// Backbone color
export const BACKBONE_COLOR = '#ffffff';
// Hydrogen bond color
export const BOND_COLOR = 'rgba(255, 255, 255, 0.4)';
// Golden glow for sacred positions
export const GOLDEN_GLOW = '#ffd700';

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface BasePair {
  base1: string;  // A, T, G, C
  base2: string;  // Complement
  position: [number, number, number];  // 3D position
  hydrogenBonds: number;  // 2 for A-T, 3 for G-C
}

export interface DnaGeometry {
  strand1: [number, number, number][];  // 5' to 3' strand positions
  strand2: [number, number, number][];  // 3' to 5' strand positions
  basePairs: BasePair[];
  length: number;
}

export interface DnaSegment {
  start: number;
  end: number;
  sequence: string;
  type: 'fibonacci' | 'golden' | 'sacred';
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELIX GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Generate DNA double helix geometry from sequence
 * @param sequence DNA sequence (5' to 3')
 * @param maxLength Maximum length to render (default: full sequence)
 */
export function generateDnaHelix(sequence: string, maxLength?: number): DnaGeometry {
  const seq = sequence.toUpperCase().replace(/[^ATGC]/g, '');
  const len = maxLength ? Math.min(seq.length, maxLength) : seq.length;
  const subsequence = seq.substring(0, len);

  const strand1: [number, number, number][] = [];
  const strand2: [number, number, number][] = [];
  const basePairs: BasePair[] = [];

  const { risePerBasePair, twistPerBasePair, helixRadius } = DNA_HELIX;
  const twistRad = (twistPerBasePair * Math.PI) / 180;

  for (let i = 0; i < len; i++) {
    const base1 = subsequence[i];
    const base2 = complementBase(base1);
    if (!base2) continue;

    const y = i * risePerBasePair;
    const angle = i * twistRad;

    // Strand 1 (5' to 3', going up)
    const x1 = helixRadius * Math.cos(angle);
    const z1 = helixRadius * Math.sin(angle);
    strand1.push([x1, y, z1]);

    // Strand 2 (3' to 5', opposite side, 180° offset)
    const x2 = helixRadius * Math.cos(angle + Math.PI);
    const z2 = helixRadius * Math.sin(angle + Math.PI);
    strand2.push([x2, y, z2]);

    basePairs.push({
      base1,
      base2,
      position: [0, y, 0],
      hydrogenBonds: base1 === 'A' || base1 === 'T' ? 2 : 3,
    });
  }

  return {
    strand1,
    strand2,
    basePairs,
    length: len,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// DNA ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Get complement base
 */
export function complementBase(base: string): string | null {
  const complements: Record<string, string> = {
    A: 'T',
    T: 'A',
    G: 'C',
    C: 'G',
  };
  return complements[base.toUpperCase()] || null;
}

/**
 * Get complement strand
 */
export function complementStrand(sequence: string): string {
  return sequence
    .toUpperCase()
    .split('')
    .map(b => complementBase(b) || 'N')
    .join('');
}

/**
 * Transcribe DNA to RNA (T → U)
 */
export function transcribeToRna(sequence: string): string {
  return sequence.replace(/t/gi, 'u').replace(/T/g, 'U');
}

/**
 * Count GC content
 */
export function countGC(sequence: string): { count: number; total: number; ratio: number } {
  const seq = sequence.toUpperCase();
  const gc = (seq.match(/[GC]/g) || []).length;
  const at = (seq.match(/[AT]/g) || []).length;
  const total = gc + at;
  const ratio = total > 0 ? gc / at : 0;
  return { count: gc, total, ratio };
}

/**
 * Check if GC ratio is close to φ (sacred genome)
 */
export function isPhiProportionedGC(ratio: number, tolerance = 0.1): boolean {
  return Math.abs(ratio - PHI) < tolerance;
}

/**
 * Calculate molecular weight of DNA
 */
export function dnaMolecularWeight(sequence: string): number {
  // Average molecular weights: A=331.2, T=322.2, G=347.2, C=307.2
  const weights: Record<string, number> = {
    A: 331.2,
    T: 322.2,
    G: 347.2,
    C: 307.2,
  };

  let weight = 0;
  for (const base of sequence.toUpperCase()) {
    weight += weights[base] || 0;
  }

  // Subtract water for each phosphodiester bond (n-1)
  weight -= (sequence.length - 1) * 18.015;

  return weight;
}

/**
 * Find Fibonacci-length segments in sequence
 */
export function findFibonacciSegments(sequence: string, minLen = 5): DnaSegment[] {
  const fib = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144];
  const segments: DnaSegment[] = [];

  for (const len of fib) {
    if (len < minLen || len > sequence.length) continue;

    for (let i = 0; i <= sequence.length - len; i++) {
      const segment = sequence.substring(i, i + len);
      const gc = countGC(segment);
      if (isPhiProportionedGC(gc.ratio)) {
        segments.push({
          start: i,
          end: i + len,
          sequence: segment,
          type: 'fibonacci',
        });
      }
    }
  }

  return segments;
}

/**
 * Find golden ratio proportioned regions
 */
export function findGoldenRegions(sequence: string): DnaSegment[] {
  const segments: DnaSegment[] = [];
  const windowSize = 21; // Fibonacci number

  for (let i = 0; i <= sequence.length - windowSize; i++) {
    const segment = sequence.substring(i, i + windowSize);
    const gc = countGC(segment);
    if (isPhiProportionedGC(gc.ratio, 0.15)) {
      segments.push({
        start: i,
        end: i + windowSize,
        sequence: segment,
        type: 'golden',
      });
    }
  }

  return segments;
}

/**
 * Check if position is a Fibonacci number (for sacred highlighting)
 */
export function isFibonacciPosition(n: number): boolean {
  const fib = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377];
  return fib.includes(n + 1); // 1-indexed
}

/**
 * Get sacred positions in sequence
 */
export function getSacredPositions(sequence: string): number[] {
  const positions: number[] = [];
  for (let i = 0; i < sequence.length; i++) {
    if (isFibonacciPosition(i)) {
      positions.push(i);
    }
  }
  return positions;
}

/**
 * Calculate ternary signature of DNA sequence
 * Maps A→+1, T→-1, G→+1, C→-1 (purines→+1, pyrimidines→-1)
 */
export function ternaryDnaSignature(sequence: string): {
  purines: number;
  pyrimidines: number;
  balance: number;  // purines - pyrimidines
  signature: number[];
} {
  const signature: number[] = [];
  let purines = 0;
  let pyrimidines = 0;

  for (const base of sequence.toUpperCase()) {
    const isPurine = base === 'A' || base === 'G';
    if (isPurine) {
      purines++;
      signature.push(1);
    } else {
      pyrimidines++;
      signature.push(-1);
    }
  }

  return {
    purines,
    pyrimidines,
    balance: purines - pyrimidines,
    signature,
  };
}

/**
 * Calculate codon positions
 */
export function getCodonPositions(sequence: string): Array<{
  start: number;
  codon: string;
  aminoAcid: string;
}> {
  const codons: Array<{ start: number; codon: string; aminoAcid: string }> = [];

  for (let i = 0; i + 2 < sequence.length; i += 3) {
    const codon = sequence.substring(i, i + 3);
    const rna = transcribeToRna(codon);
    const aa = AMINO_ACIDS[codonToAminoAcid(rna)]?.code1 || '?';
    codons.push({ start: i, codon, aminoAcid: aa });
  }

  return codons;
}

/**
 * Simple RNA codon to amino acid mapping (1-letter code)
 */
function codonToAminoAcid(rnaCodon: string): string {
  const codonTable: Record<string, string> = {
    UUU: 'F', UUC: 'F', UUA: 'L', UUG: 'L',
    CUU: 'L', CUC: 'L', CUA: 'L', CUG: 'L',
    AUU: 'I', AUC: 'I', AUA: 'I', AUG: 'M',
    GUU: 'V', GUC: 'V', GUA: 'V', GUG: 'V',
    UCU: 'S', UCC: 'S', UCA: 'S', UCG: 'S',
    CCU: 'P', CCC: 'P', CCA: 'P', CCG: 'P',
    ACU: 'T', ACC: 'T', ACA: 'T', ACG: 'T',
    GCU: 'A', GCC: 'A', GCA: 'A', GCG: 'A',
    UAU: 'Y', UAC: 'Y', UAA: '*', UAG: '*',
    CAU: 'H', CAC: 'H', CAA: 'Q', CAG: 'Q',
    AAU: 'N', AAC: 'N', AAA: 'K', AAG: 'K',
    GAU: 'D', GAC: 'D', GAA: 'E', GAG: 'E',
    UGU: 'C', UGC: 'C', UGA: '*', UGG: 'W',
    CGU: 'R', CGC: 'R', CGA: 'R', CGG: 'R',
    AGU: 'S', AGC: 'S', AGA: 'R', AGG: 'R',
    GGU: 'G', GGC: 'G', GGA: 'G', GGG: 'G',
  };
  return codonTable[rnaCodon.toUpperCase()] || 'X';
}
