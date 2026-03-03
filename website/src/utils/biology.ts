// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BIOLOGY v14.0 — BIOLOGY UTILITIES
// DNA/RNA/protein analysis, sacred formula fitting, ternary encoding
// ═══════════════════════════════════════════════════════════════════════════════

import {
  complementBase,
  complementStrand,
  transcribeToRna,
  countGC,
  dnaMolecularWeight,
  findFibonacciSegments,
  findGoldenRegions,
  isPhiProportionedGC,
  ternaryDnaSignature,
} from '../data/dnaData';
import { AMINO_ACIDS, translateDnaToProteins, CODON_TABLE_RNA } from '../data/aminoAcids';
import { fitSingleValue } from '../services/chatApi';
import { toBalancedTernary } from './chemistry';

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const PHI = 1.6180339887498948482;
const FIBONACCI = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377];
const LUCAS = [2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123, 199, 322];

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface SacredFit {
  n: number;
  k: number;
  m: number;
  p: number;
  q: number;
  computed: number;
  error_pct: number;
}

export interface TernarySignature {
  purines: number;
  pyrimidines: number;
  balance: number;
  signature: number[];
}

export interface CodonInfo {
  position: number;
  codon: string;
  aminoAcid: string;
  aminoAcidName: string;
  isStart: boolean;
  isStop: boolean;
}

export interface DnaAnalysis {
  sequence: string;
  length: number;
  complement: string;
  rna: string;
  gcContent: number;
  gcRatio: number;
  gcPercent: number;
  molecularWeight: number;
  sacredFit: SacredFit;
  ternary: TernarySignature;
  isFibonacciLength: boolean;
  isLucasLength: boolean;
  isPhiProportioned: boolean;
  fibonacciSegments: Array<{ start: number; end: number; sequence: string; type: string }>;
  goldenRegions: Array<{ start: number; end: number; sequence: string; type: string }>;
  codons: CodonInfo[];
  protein: string;
  proteinLength: number;
}

export interface ProteinAnalysis {
  sequence: string;
  length: number;
  molecularWeight: number;
  sacredFit: SacredFit;
  isFibonacciLength: boolean;
  phiContent: number;  // % of amino acids related to φ
  aminoAcidComposition: Record<string, number>;
  hydrophobicRatio: number;
  chargeAtPh7: number;
}

export interface RnaAnalysis {
  sequence: string;
  length: number;
  dnaTemplate: string;
  molecularWeight: number;
  sacredFit: SacredFit;
  codons: CodonInfo[];
  protein: string;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DNA ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Full DNA sequence analysis with sacred mathematics
 */
export async function analyzeDna(sequence: string): Promise<DnaAnalysis> {
  // Normalize sequence
  const seq = sequence.toUpperCase().replace(/[^ATGC]/g, '');
  const len = seq.length;

  // Basic analysis
  const complement = complementStrand(seq);
  const rna = transcribeToRna(seq);
  const gc = countGC(seq);
  const mw = dnaMolecularWeight(seq);
  const ternary = ternaryDnaSignature(seq);

  // Sacred fit for length
  const lengthFit = await fitSingleValue(len);

  // Check Fibonacci/Lucas
  const isFib = FIBONACCI.includes(len);
  const isLucas = LUCAS.includes(len);

  // Check φ-proportioned GC content
  const isPhi = isPhiProportionedGC(gc.ratio, 0.15);

  // Find sacred segments
  const fibSegs = findFibonacciSegments(seq);
  const goldRegs = findGoldenRegions(seq);

  // Translate to protein
  const codons = getCodons(seq);
  const protein = translateToProtein(seq);
  const proteinLen = protein.length;

  return {
    sequence: seq,
    length: len,
    complement,
    rna,
    gcContent: gc.count,
    gcRatio: gc.ratio,
    gcPercent: gc.total > 0 ? (gc.count / gc.total) * 100 : 0,
    molecularWeight: mw,
    sacredFit: { ...lengthFit.fit, computed: lengthFit.computed, error_pct: lengthFit.error_pct },
    ternary,
    isFibonacciLength: isFib,
    isLucasLength: isLucas,
    isPhiProportioned: isPhi,
    fibonacciSegments: fibSegs,
    goldenRegions: goldRegs,
    codons,
    protein,
    proteinLength: proteinLen,
  };
}

/**
 * Get codon information for DNA sequence
 */
export function getCodons(sequence: string): CodonInfo[] {
  const codons: CodonInfo[] = [];
  const rna = transcribeToRna(sequence);

  for (let i = 0; i + 2 < rna.length; i += 3) {
    const codon = rna.substring(i, i + 3);
    const aa = CODON_TABLE_RNA[codon] || '?';
    const aminoAcid = AMINO_ACIDS[aa];

    codons.push({
      position: i / 3,
      codon,
      aminoAcid: aa,
      aminoAcidName: aminoAcid?.name || 'Unknown',
      isStart: codon === 'AUG',
      isStop: codon === 'UAA' || codon === 'UAG' || codon === 'UGA',
    });
  }

  return codons;
}

/**
 * Translate DNA to protein string (1-letter codes)
 */
export function translateToProtein(sequence: string): string {
  const rna = transcribeToRna(sequence);
  let protein = '';

  for (let i = 0; i + 2 < rna.length; i += 3) {
    const codon = rna.substring(i, i + 3);
    const aa = CODON_TABLE_RNA[codon];
    if (aa === '*') break; // STOP
    if (aa) protein += aa;
  }

  return protein;
}

/**
 * Find open reading frames (ORFs)
 */
export function findOrfs(sequence: string, minLen = 30): Array<{
  start: number;
  end: number;
  length: number;
  protein: string;
}> {
  const orfs: Array<{ start: number; end: number; length: number; protein: string }> = [];
  const seq = sequence.toUpperCase();

  // Check all 3 reading frames on both strands
  for (let strand = 0; strand < 2; strand++) {
    const workingSeq = strand === 0 ? seq : complementStrand(seq).split('').reverse().join('');

    for (let frame = 0; frame < 3; frame++) {
      let inOrf = false;
      let orfStart = 0;
      let currentProtein = '';

      for (let i = frame; i + 2 < workingSeq.length; i += 3) {
        const codon = transcribeToRna(workingSeq.substring(i, i + 3));
        const aa = CODON_TABLE_RNA[codon];

        if (codon === 'AUG' && !inOrf) {
          // START codon
          inOrf = true;
          orfStart = i;
          currentProtein = '';
        } else if ((aa === '*') && inOrf) {
          // STOP codon
          if (currentProtein.length >= minLen) {
            orfs.push({
              start: orfStart,
              end: i + 3,
              length: currentProtein.length,
              protein: currentProtein,
            });
          }
          inOrf = false;
          currentProtein = '';
        } else if (inOrf && aa && aa !== '*') {
          currentProtein += aa;
        }
      }
    }
  }

  return orfs.sort((a, b) => b.length - a.length);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RNA ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Analyze RNA sequence
 */
export async function analyzeRna(rnaSequence: string): Promise<RnaAnalysis> {
  // Normalize (convert T to U)
  const seq = rnaSequence.toUpperCase().replace(/T/g, 'U').replace(/t/g, 'u');
  const len = seq.length;

  // Convert to DNA template
  const dna = seq.replace(/U/g, 'T');

  // Molecular weight (slightly different from DNA)
  // Average: A=347.2, U=324.2, G=363.2, C=323.2
  const weights: Record<string, number> = {
    A: 347.2,
    U: 324.2,
    G: 363.2,
    C: 323.2,
  };
  let mw = 0;
  for (const base of seq) {
    mw += weights[base] || 0;
  }
  mw -= (len - 1) * 18.015;

  // Sacred fit
  const fit = await fitSingleValue(len);

  // Codons
  const codons = getCodons(dna);

  // Protein
  const protein = translateToProtein(dna);

  return {
    sequence: seq,
    length: len,
    dnaTemplate: dna,
    molecularWeight: mw,
    sacredFit: { ...fit.fit, computed: fit.computed, error_pct: fit.error_pct },
    codons,
    protein,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROTEIN ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Analyze protein sequence (1-letter codes)
 */
export async function analyzeProtein(sequence: string): Promise<ProteinAnalysis> {
  // Normalize
  const seq = sequence.toUpperCase().replace(/[^ACDEFGHIKLMNPQRSTVWY]/g, '');
  const len = seq.length;

  // Molecular weight
  let mw = 0;
  const composition: Record<string, number> = {};

  for (const aa of seq) {
    composition[aa] = (composition[aa] || 0) + 1;
    const aminoAcid = AMINO_ACIDS[aa];
    if (aminoAcid) {
      mw += aminoAcid.mass;
    }
  }
  // Subtract water for peptide bonds
  mw -= (len - 1) * 18.015;

  // Sacred fit
  const fit = await fitSingleValue(len);

  // Is Fibonacci length?
  const isFib = FIBONACCI.includes(len);

  // φ-content (aromatic amino acids + those with sacred properties)
  const phiRelated = ['F', 'W', 'Y', 'H']; // Aromatic rings
  const phiCount = seq.split('').filter(aa => phiRelated.includes(aa)).length;
  const phiContent = (phiCount / len) * 100;

  // Hydrophobic ratio (A, V, I, L, F, W, M, P)
  const hydrophobic = ['A', 'V', 'I', 'L', 'F', 'W', 'M', 'P'];
  const hydrophobicCount = seq.split('').filter(aa => hydrophobic.includes(aa)).length;
  const hydrophobicRatio = hydrophobicCount / len;

  // Charge at pH 7
  const positive = ['K', 'R', 'H']; // At pH 7, H is ~10% charged
  const negative = ['D', 'E'];
  const posCount = seq.split('').filter(aa => positive.includes(aa)).length;
  const negCount = seq.split('').filter(aa => negative.includes(aa)).length;
  // H at pH 7: pKa = 7.59, so ~50% protonated
  const hCount = (seq.split('').filter(aa => aa === 'H').length || 0) * 0.5;
  const charge = posCount + hCount - negCount;

  return {
    sequence: seq,
    length: len,
    molecularWeight: mw,
    sacredFit: { ...fit.fit, computed: fit.computed, error_pct: fit.error_pct },
    isFibonacciLength: isFib,
    phiContent,
    aminoAcidComposition: composition,
    hydrophobicRatio,
    chargeAtPh7: charge,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BIOLOGY DETECTION
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Check if sequence has Fibonacci pattern
 */
export function hasFibonacciPattern(seq: string): boolean {
  const len = seq.length;
  return FIBONACCI.includes(len);
}

/**
 * Check if ratio is φ-proportioned
 */
export function isPhiProportioned(ratio: number, tolerance = 0.1): boolean {
  return Math.abs(ratio - PHI) < tolerance;
}

/**
 * Find golden ratio splice sites
 */
export function findGoldenSpliceSites(seq: string): number[] {
  const sites: number[] = [];
  const golden = 0.618; // 1/φ

  for (let i = 1; i < seq.length; i++) {
    const ratio = i / seq.length;
    if (Math.abs(ratio - golden) < 0.05) {
      sites.push(i);
    }
  }

  return sites;
}

/**
 * Convert sequence to balanced ternary
 */
export function ternaryGenome(seq: string): number[] {
  // Map bases to trits: A=+1, T=-1, G=+1, C=-1 (purines/pyrimidines)
  const trits: number[] = [];
  for (const base of seq.toUpperCase()) {
    if (base === 'A' || base === 'G') {
      trits.push(1);
    } else if (base === 'T' || base === 'C') {
      trits.push(-1);
    } else {
      trits.push(0);
    }
  }
  return trits;
}

/**
 * Convert balanced ternary to DNA
 */
export function ternaryToDna(trits: number[]): string {
  const bases: string[] = [];
  for (const t of trits) {
    if (t === 1) {
      bases.push('A'); // or G
    } else if (t === -1) {
      bases.push('T'); // or C
    } else {
      bases.push('N');
    }
  }
  return bases.join('');
}

/**
 * Find sacred codons (codons at Fibonacci positions)
 */
export function findSacredCodons(seq: string): Array<{
  position: number;
  codon: string;
  aminoAcid: string;
}> {
  const sacred: Array<{ position: number; codon: string; aminoAcid: string }> = [];

  for (let i = 0; i + 2 < seq.length; i += 3) {
    const codonPos = i / 3;
    if (FIBONACCI.includes(codonPos + 1)) {
      const codon = seq.substring(i, i + 3);
      const aa = CODON_TABLE_RNA[transcribeToRna(codon)] || '?';
      sacred.push({ position: codonPos, codon, aminoAcid: aa });
    }
  }

  return sacred;
}

/**
 * Calculate genome entropy (information content)
 */
export function calculateGenomeEntropy(seq: string): number {
  const freq: Record<string, number> = { A: 0, T: 0, G: 0, C: 0 };
  const len = seq.length;

  for (const base of seq.toUpperCase()) {
    if (base in freq) {
      freq[base]++;
    }
  }

  let entropy = 0;
  for (const base of Object.keys(freq)) {
    const p = freq[base] / len;
    if (p > 0) {
      entropy -= p * Math.log2(p);
    }
  }

  return entropy;
}

/**
 * Check if genome is "sacred" (high phi alignment)
 */
export function isSacredGenome(seq: string): {
  isSacred: boolean;
  score: number;
  reasons: string[];
} {
  const reasons: string[] = [];
  let score = 0;

  const gc = countGC(seq);
  const ternary = ternaryDnaSignature(seq);

  // Check GC ratio
  if (isPhiProportionedGC(gc.ratio, 0.15)) {
    score += 30;
    reasons.push(`GC ratio (${gc.ratio.toFixed(3)}) close to φ`);
  }

  // Check ternary balance
  const balanceRatio = Math.abs(ternary.balance) / seq.length;
  if (balanceRatio < 0.1) {
    score += 25;
    reasons.push('Purine-pyrimidine balanced');
  }

  // Check Fibonacci length
  if (FIBONACCI.includes(seq.length)) {
    score += 25;
    reasons.push('Fibonacci length');
  }

  // Check entropy
  const entropy = calculateGenomeEntropy(seq);
  if (entropy > 1.9) {
    score += 20;
    reasons.push('High information entropy');
  }

  return {
    isSacred: score >= 50,
    score,
    reasons,
  };
}
