// ============================================================================
// SACRED CHEMISTRY — Pure Functions
// Port of tri_chemistry.zig sacred commands to TypeScript
// ============================================================================

import { ELEMENTS, getElement, type Element } from '../data/elements';
import { fitSingleValue, computeSacredFormula, PARAM_BOUNDS } from '../services/chatApi';

const PHI = 1.6180339887498948482;
const GOLDEN_ANGLE = 137.50776405003785;

// 27 Coptic glyphs (mirrors chatApi.ts and gematria.zig)
const COPTIC_GLYPHS = [
  '\u2C80', '\u2C82', '\u2C84', '\u2C86', '\u2C88', '\u2C8A', '\u2C8C', '\u2C8E', '\u2C90',
  '\u2C92', '\u2C94', '\u2C96', '\u2C98', '\u2C9A', '\u2C9C', '\u2C9E', '\u2CA0', '\u2CA2',
  '\u03E2', '\u03E4', '\u03E6', '\u03E8', '\u03EA', '\u03EC', '\u03EE', '\u03E0', '\u03E4',
];
const GLYPH_VALUES = [
  1, 2, 3, 4, 5, 6, 7, 8, 9,
  10, 20, 30, 40, 50, 60, 70, 80, 90,
  100, 200, 300, 400, 500, 600, 700, 800, 900,
];

// ============================================================================
// Formula Parsing
// ============================================================================

export function parseFormula(formula: string): Map<string, number> {
  const result = new Map<string, number>();
  const stack: Map<string, number>[] = [result];

  let i = 0;
  while (i < formula.length) {
    if (formula[i] === '(') {
      const inner = new Map<string, number>();
      stack.push(inner);
      i++;
    } else if (formula[i] === ')') {
      i++;
      let num = 0;
      while (i < formula.length && /\d/.test(formula[i])) {
        num = num * 10 + parseInt(formula[i]);
        i++;
      }
      if (num === 0) num = 1;
      const inner = stack.pop()!;
      const outer = stack[stack.length - 1];
      for (const [sym, count] of inner) {
        outer.set(sym, (outer.get(sym) ?? 0) + count * num);
      }
    } else if (/[A-Z]/.test(formula[i])) {
      let sym = formula[i];
      i++;
      while (i < formula.length && /[a-z]/.test(formula[i])) {
        sym += formula[i];
        i++;
      }
      let num = 0;
      while (i < formula.length && /\d/.test(formula[i])) {
        num = num * 10 + parseInt(formula[i]);
        i++;
      }
      if (num === 0) num = 1;
      const current = stack[stack.length - 1];
      current.set(sym, (current.get(sym) ?? 0) + num);
    } else {
      i++;
    }
  }
  return result;
}

export function molarMass(composition: Map<string, number>): number {
  let total = 0;
  for (const [sym, count] of composition) {
    const el = getElement(sym);
    if (el) total += el.mass * count;
  }
  return total;
}

// ============================================================================
// Balanced Ternary
// ============================================================================

export function toBalancedTernary(z: number): number[] {
  if (z === 0) return [0];
  const trits: number[] = [];
  let n = z;
  while (n > 0) {
    let rem = n % 3;
    n = Math.floor(n / 3);
    if (rem === 2) { rem = -1; n += 1; }
    trits.push(rem);
  }
  return trits.reverse();
}

// ============================================================================
// Ternary Molecular Signature
// ============================================================================

export interface TernarySignature {
  atoms: number;
  electrons: number;
  bonds: number;
  sum: number;
  label: string;
}

function tritMod3(val: number): number {
  const m = val % 3;
  return m;
}

export function ternarySignature(totalAtoms: number, totalElectrons: number, totalBonds: number): TernarySignature {
  const atoms = tritMod3(totalAtoms);
  const electrons = tritMod3(totalElectrons);
  const bonds = tritMod3(totalBonds);
  const sum = atoms + electrons + bonds;
  let label: string;
  if (sum === 0) label = 'BALANCED';
  else if (sum % 3 === 0) label = 'HARMONIC';
  else if (sum > 3) label = 'CREATIVE';
  else label = 'DYNAMIC';
  return { atoms, electrons, bonds, sum, label };
}

// ============================================================================
// Bond Estimation
// ============================================================================

const VALENCE_TABLE: Record<string, number> = {
  H: 1, C: 4, N: 3, O: 2, F: 1, S: 2, P: 3, Cl: 1, Br: 1, I: 1,
  Na: 1, K: 1, Ca: 2, Mg: 2, Fe: 3, Al: 3, Si: 4, B: 3, Se: 2,
};

const BOND_ENERGIES: Record<string, number> = {
  'C-H': 413, 'O-H': 463, 'N-H': 391, 'C-C': 347, 'C=O': 799,
  'C-N': 305, 'C-O': 358, 'C=C': 614, 'N=N': 418, 'O=O': 498,
  'C-F': 485, 'C-Cl': 339, 'C-S': 259, 'S-H': 347, 'P-O': 335,
};

export function estimateBonds(composition: Map<string, number>): { totalBonds: number; bondEnergy: number } {
  let totalValence = 0;
  for (const [sym, count] of composition) {
    const v = VALENCE_TABLE[sym] ?? 2;
    totalValence += v * count;
  }
  const totalBonds = Math.max(1, Math.floor(totalValence / 2));

  // Estimate average bond energy
  let avgBondEnergy = 350;
  const syms = [...composition.keys()];
  if (syms.includes('O') && syms.includes('H')) avgBondEnergy = 463;
  else if (syms.includes('C') && syms.includes('H')) avgBondEnergy = 413;
  else if (syms.includes('C') && syms.includes('O')) avgBondEnergy = 358;
  else if (syms.includes('N') && syms.includes('H')) avgBondEnergy = 391;

  return { totalBonds, bondEnergy: avgBondEnergy * totalBonds };
}

// ============================================================================
// Fibonacci / Lucas
// ============================================================================

function fibSequence(limit: number): number[] {
  const seq = [0, 1];
  while (seq[seq.length - 1] < limit + 100) {
    seq.push(seq[seq.length - 1] + seq[seq.length - 2]);
  }
  return seq;
}

function lucasSequence(limit: number): number[] {
  const seq = [2, 1];
  while (seq[seq.length - 1] < limit + 100) {
    seq.push(seq[seq.length - 1] + seq[seq.length - 2]);
  }
  return seq;
}

export function isFibonacci(n: number): { is: boolean; index?: number } {
  const seq = fibSequence(n);
  const idx = seq.indexOf(n);
  return idx >= 0 ? { is: true, index: idx } : { is: false };
}

export function isLucas(n: number): { is: boolean; index?: number } {
  const seq = lucasSequence(n);
  const idx = seq.indexOf(n);
  return idx >= 0 ? { is: true, index: idx } : { is: false };
}

// ============================================================================
// Golden Angle
// ============================================================================

export function goldenAngle(z: number): { angle: number; sector: number } {
  const angle = (z * GOLDEN_ANGLE) % 360;
  const sector = Math.floor(angle / 45) + 1;
  return { angle, sector };
}

// ============================================================================
// Coptic Glyph
// ============================================================================

export function copticGlyph(index: number): { glyph: string; value: number; kingdom: string } {
  const i = ((index % 27) + 27) % 27;
  const kingdom = i < 9 ? 'Matter' : i < 18 ? 'Energy' : 'Info';
  return { glyph: COPTIC_GLYPHS[i], value: GLYPH_VALUES[i], kingdom };
}

// ============================================================================
// Sacred Formula formatting
// ============================================================================

export function formatSacredFormula(fit: { n: number; k: number; m: number; p: number; q: number }): string {
  const sup = (v: number) => (v < 0 ? '\u207B' + superDigit(Math.abs(v)) : superDigit(v));
  const parts: string[] = [`${fit.n}`];
  if (fit.k !== 0) parts.push('3' + sup(fit.k));
  if (fit.m !== 0) parts.push('\u03C0' + sup(fit.m));
  if (fit.p !== 0) parts.push('\u03C6' + sup(fit.p));
  if (fit.q !== 0) parts.push('e' + sup(fit.q));
  return parts.join(' \u00D7 ');
}

function superDigit(n: number): string {
  const supers = '\u2070\u00B9\u00B2\u00B3\u2074\u2075\u2076\u2077\u2078\u2079';
  return String(n).split('').map(d => supers[parseInt(d)]).join('');
}

export function formatFormulaPlain(fit: { n: number; k: number; m: number; p: number; q: number }): string {
  const parts: string[] = [`${fit.n}`];
  if (fit.k !== 0) parts.push(`3^${fit.k}`);
  if (fit.m !== 0) parts.push(`\u03C0^${fit.m}`);
  if (fit.p !== 0) parts.push(`\u03C6^${fit.p}`);
  if (fit.q !== 0) parts.push(`e^${fit.q}`);
  return parts.join(' \u00D7 ');
}

// ============================================================================
// High-level Analysis Functions
// ============================================================================

export interface MoleculeResult {
  formula: string;
  composition: Map<string, number>;
  molarMass: number;
  sacredFit: { n: number; k: number; m: number; p: number; q: number; computed: number; error_pct: number };
  elements: Array<{ element: Element; count: number; massContrib: number; pct: number }>;
  totalAtoms: number;
  totalElectrons: number;
  bonds: { totalBonds: number; bondEnergy: number };
  bondSacredFit: { n: number; k: number; m: number; p: number; q: number; computed: number; error_pct: number };
  signature: TernarySignature;
  coptic: { glyph: string; value: number; kingdom: string };
}

export async function analyzeMolecule(formula: string): Promise<MoleculeResult> {
  const composition = parseFormula(formula);
  const mass = molarMass(composition);
  const sacredFit = await fitSingleValue(mass);

  const elements: MoleculeResult['elements'] = [];
  let totalAtoms = 0;
  let totalElectrons = 0;
  for (const [sym, count] of composition) {
    const el = getElement(sym);
    if (el) {
      const contrib = el.mass * count;
      elements.push({ element: el, count, massContrib: contrib, pct: (contrib / mass) * 100 });
      totalAtoms += count;
      totalElectrons += el.number * count;
    }
  }

  const bonds = estimateBonds(composition);
  const bondSacredFit = await fitSingleValue(bonds.bondEnergy);
  const signature = ternarySignature(totalAtoms, totalElectrons, bonds.totalBonds);
  const coptic = copticGlyph(totalAtoms % 27);

  return {
    formula,
    composition,
    molarMass: mass,
    sacredFit: { ...sacredFit.fit, computed: sacredFit.computed, error_pct: sacredFit.error_pct },
    elements,
    totalAtoms,
    totalElectrons,
    bonds,
    bondSacredFit: { ...bondSacredFit.fit, computed: bondSacredFit.computed, error_pct: bondSacredFit.error_pct },
    signature,
    coptic,
  };
}

export interface ElementResult {
  element: Element;
  balancedTernary: number[];
  sacredMass: { n: number; k: number; m: number; p: number; q: number; computed: number; error_pct: number };
  sacredIE: { n: number; k: number; m: number; p: number; q: number; computed: number; error_pct: number } | null;
  sacredEN: { n: number; k: number; m: number; p: number; q: number; computed: number; error_pct: number } | null;
  fibonacci: { is: boolean; index?: number };
  lucas: { is: boolean; index?: number };
  golden: { angle: number; sector: number };
  coptic: { glyph: string; value: number; kingdom: string };
}

export async function analyzeElement(query: string): Promise<ElementResult | null> {
  const el = getElement(query);
  if (!el) return null;

  const bt = toBalancedTernary(el.number);
  const massFit = await fitSingleValue(el.mass);

  let ieFit = null;
  if (el.ionization_energy != null) {
    const f = await fitSingleValue(el.ionization_energy);
    ieFit = { ...f.fit, computed: f.computed, error_pct: f.error_pct };
  }

  let enFit = null;
  if (el.electronegativity != null) {
    const f = await fitSingleValue(el.electronegativity);
    enFit = { ...f.fit, computed: f.computed, error_pct: f.error_pct };
  }

  return {
    element: el,
    balancedTernary: bt,
    sacredMass: { ...massFit.fit, computed: massFit.computed, error_pct: massFit.error_pct },
    sacredIE: ieFit,
    sacredEN: enFit,
    fibonacci: isFibonacci(el.number),
    lucas: isLucas(el.number),
    golden: goldenAngle(el.number),
    coptic: copticGlyph(el.number % 27),
  };
}

export { getElement, ELEMENTS, fitSingleValue };
export type { Element };
