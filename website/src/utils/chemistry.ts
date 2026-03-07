// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CHEMISTRY UTILITIES
// Formula parsing, molar mass, ternary encoding, sacred formula fitting
// Used by SacredChemistryWidget.tsx
// ═══════════════════════════════════════════════════════════════════════════════

import { getElement } from '../data/elements';
import { fitSingleValue } from '../services/chatApi';

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface SacredFit {
  n: number; k: number; m: number; p: number; q: number;
  computed: number; error_pct: number;
}

export interface ElementEntry {
  symbol: string;
  name: string;
  number: number;
  mass: number;
  group: number;
  period: number;
  block: string;
  category: string;
  electronegativity?: number;
  ionization_energy?: number;
}

export interface MoleculeElement {
  element: ElementEntry;
  count: number;
  massContrib: number;
  pct: number;
}

export interface BondInfo {
  totalBonds: number;
  bondEnergy: number;
}

export interface TernarySignature {
  atoms: number;
  electrons: number;
  bonds: number;
  sum: number;
  label: string;
}

export interface CopticInfo {
  glyph: string;
  value: number;
  kingdom: string;
}

export interface MoleculeResult {
  formula: string;
  molarMass: number;
  elements: MoleculeElement[];
  totalAtoms: number;
  totalElectrons: number;
  sacredFit: SacredFit;
  bonds: BondInfo;
  bondSacredFit: SacredFit;
  signature: TernarySignature;
  coptic: CopticInfo;
}

export interface ElementResult {
  element: ElementEntry;
  balancedTernary: number[];
  sacredMass: SacredFit;
  sacredIE?: SacredFit;
  sacredEN?: SacredFit;
  fibonacci: { is: boolean; index: number };
  lucas: { is: boolean; index: number };
  golden: { angle: number; sector: number };
  coptic: CopticInfo;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const GOLDEN_ANGLE = 137.5077640500378;

// Bond energies (kJ/mol) — approximate averages
// Note: Values used in estimateBonds below

// 27 Coptic glyphs
const COPTIC_GLYPHS = [
  '\u2C80', '\u2C82', '\u2C84', '\u2C86', '\u2C88', '\u2C8A', '\u2C8C', '\u2C8E', '\u2C90',
  '\u2C92', '\u2C94', '\u2C96', '\u2C98', '\u2C9A', '\u2C9C', '\u2C9E', '\u2CA0', '\u2CA2',
  '\u2CA4', '\u2CA6', '\u2CA8', '\u2CAA', '\u2CAC', '\u2CAE', '\u2CB0', '\u03E2', '\u03E4',
];
const GLYPH_VALUES = [
  1, 2, 3, 4, 5, 6, 7, 8, 9,
  10, 20, 30, 40, 50, 60, 70, 80, 90,
  100, 200, 300, 400, 500, 600, 700, 800, 900,
];

// ═══════════════════════════════════════════════════════════════════════════════
// FORMULA PARSING
// ═══════════════════════════════════════════════════════════════════════════════

/** Parse chemical formula into element-count pairs. Handles parentheses. */
export function parseFormula(formula: string): { symbol: string; count: number }[] {
  const stack: { symbol: string; count: number }[][] = [[]];

  let i = 0;
  while (i < formula.length) {
    const ch = formula[i];

    if (ch === '(') {
      stack.push([]);
      i++;
    } else if (ch === ')') {
      i++;
      let num = '';
      while (i < formula.length && formula[i] >= '0' && formula[i] <= '9') {
        num += formula[i++];
      }
      const multiplier = num ? parseInt(num, 10) : 1;
      const group = stack.pop()!;
      const current = stack[stack.length - 1];
      for (const item of group) {
        const existing = current.find(e => e.symbol === item.symbol);
        if (existing) existing.count += item.count * multiplier;
        else current.push({ symbol: item.symbol, count: item.count * multiplier });
      }
    } else if (ch >= 'A' && ch <= 'Z') {
      let symbol = ch;
      i++;
      while (i < formula.length && formula[i] >= 'a' && formula[i] <= 'z') {
        symbol += formula[i++];
      }
      let num = '';
      while (i < formula.length && formula[i] >= '0' && formula[i] <= '9') {
        num += formula[i++];
      }
      const count = num ? parseInt(num, 10) : 1;
      const current = stack[stack.length - 1];
      const existing = current.find(e => e.symbol === symbol);
      if (existing) existing.count += count;
      else current.push({ symbol, count });
    } else {
      i++;
    }
  }

  return stack[0];
}

/** Calculate molar mass from formula string */
export function molarMass(formula: string): number {
  const parts = parseFormula(formula);
  let mass = 0;
  for (const { symbol, count } of parts) {
    const el = getElement(symbol);
    if (el) mass += el.mass * count;
  }
  return mass;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BALANCED TERNARY
// ═══════════════════════════════════════════════════════════════════════════════

/** Convert integer to balanced ternary representation */
export function toBalancedTernary(n: number): number[] {
  if (n === 0) return [0];
  const trits: number[] = [];
  let val = Math.abs(Math.round(n));
  const sign = n < 0 ? -1 : 1;

  while (val > 0) {
    let rem = val % 3;
    val = Math.floor(val / 3);
    if (rem === 2) {
      rem = -1;
      val += 1;
    }
    trits.push(rem * sign);
  }

  return trits.reverse();
}

/** Compute ternary signature: atoms mod 3, electrons mod 3, bonds mod 3 */
export function ternarySignature(atoms: number, electrons: number, bonds: number): TernarySignature {
  const a = atoms % 3;
  const e = electrons % 3;
  const b = bonds % 3;
  const sum = (a + e + b) % 3;
  const labels = ['Neutral', 'Positive', 'Negative'];
  return { atoms: a, electrons: e, bonds: b, sum, label: labels[sum] };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOND ESTIMATION
// ═══════════════════════════════════════════════════════════════════════════════

/** Estimate bonds and bond energy from parsed formula */
export function estimateBonds(elements: { symbol: string; count: number }[]): BondInfo {
  let totalAtoms = 0;
  let totalH = 0;
  let totalC = 0;
  let totalO = 0;
  let totalN = 0;

  for (const { symbol, count } of elements) {
    totalAtoms += count;
    if (symbol === 'H') totalH = count;
    if (symbol === 'C') totalC = count;
    if (symbol === 'O') totalO = count;
    if (symbol === 'N') totalN = count;
  }

  // Heuristic bond count based on element valences
  let bonds = 0;
  let energy = 0;

  if (totalC > 0) {
    // Organic: C-H bonds + C-C bonds + C-O bonds
    const ch = Math.min(totalH, totalC * 4);
    bonds += ch;
    energy += ch * 413;
    const cc = Math.max(0, totalC - 1);
    bonds += cc;
    energy += cc * 347;
    if (totalO > 0) {
      bonds += totalO;
      energy += totalO * 358;
    }
    if (totalN > 0) {
      bonds += totalN;
      energy += totalN * 305;
    }
  } else {
    // Inorganic: estimate from atom count
    bonds = Math.max(1, totalAtoms - 1);
    energy = bonds * 350; // average bond energy
  }

  return { totalBonds: bonds, bondEnergy: energy };
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIBONACCI / LUCAS / GOLDEN
// ═══════════════════════════════════════════════════════════════════════════════

/** Check if n is a Fibonacci number; return index if so */
export function isFibonacci(n: number): { is: boolean; index: number } {
  let a = 0, b = 1, idx = 0;
  n = Math.round(n);
  while (a < n) { [a, b] = [b, a + b]; idx++; }
  return { is: a === n, index: a === n ? idx : -1 };
}

/** Check if n is a Lucas number; return index if so */
export function isLucas(n: number): { is: boolean; index: number } {
  let a = 2, b = 1, idx = 0;
  n = Math.round(n);
  if (n === 2) return { is: true, index: 0 };
  if (n === 1) return { is: true, index: 1 };
  while (a < n) { [a, b] = [b, a + b]; idx++; }
  return { is: a === n, index: a === n ? idx : -1 };
}

/** Compute golden angle position for a given atomic number or mass */
export function goldenAngle(n: number): { angle: number; sector: number } {
  const angle = (n * GOLDEN_ANGLE) % 360;
  const sector = Math.floor(angle / 45) + 1;
  return { angle, sector };
}

// ═══════════════════════════════════════════════════════════════════════════════
// COPTIC GLYPH
// ═══════════════════════════════════════════════════════════════════════════════

/** Map an atomic number to a Coptic glyph */
export function copticGlyph(atomicNumber: number): CopticInfo {
  const idx = (atomicNumber - 1) % 27;
  const glyph = COPTIC_GLYPHS[idx];
  const value = GLYPH_VALUES[idx];
  const kingdom = atomicNumber <= 36 ? 'Matter' : atomicNumber <= 86 ? 'Energy' : 'Spirit';
  return { glyph, value, kingdom };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED FORMULA FORMATTING
// ═══════════════════════════════════════════════════════════════════════════════

/** Format sacred formula fit as human-readable string */
export function formatSacredFormula(fit: { n: number; k: number; m: number; p: number; q: number; computed: number; error_pct: number }): string {
  let s = `${fit.n}`;
  if (fit.k !== 0) s += fit.k === 1 ? '\u00D73' : `\u00D73\u207F${superscript(fit.k)}`;
  if (fit.m !== 0) s += fit.m === 1 ? '\u00D7\u03C0' : `\u00D7\u03C0${superscript(fit.m)}`;
  if (fit.p !== 0) s += fit.p === 1 ? '\u00D7\u03C6' : `\u00D7\u03C6${superscript(fit.p)}`;
  if (fit.q !== 0) s += fit.q === 1 ? '\u00D7e' : `\u00D7e${superscript(fit.q)}`;
  return s;
}

function superscript(n: number): string {
  const sup: Record<string, string> = {
    '0': '\u2070', '1': '\u00B9', '2': '\u00B2', '3': '\u00B3', '4': '\u2074',
    '5': '\u2075', '6': '\u2076', '7': '\u2077', '8': '\u2078', '9': '\u2079',
    '-': '\u207B',
  };
  return String(n).split('').map(c => sup[c] || c).join('');
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANALYSIS FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/** Full molecule analysis — returns MoleculeResult */
export async function analyzeMolecule(formula: string): Promise<MoleculeResult> {
  const parsed = parseFormula(formula);
  const elements: MoleculeElement[] = [];
  let totalMass = 0;
  let totalAtoms = 0;
  let totalElectrons = 0;

  for (const { symbol, count } of parsed) {
    const el = getElement(symbol);
    if (!el) continue;
    const contrib = el.mass * count;
    totalMass += contrib;
    totalAtoms += count;
    totalElectrons += el.number * count;
    elements.push({
      element: el as ElementEntry,
      count,
      massContrib: contrib,
      pct: 0,
    });
  }

  // Compute percentages
  for (const e of elements) {
    e.pct = totalMass > 0 ? (e.massContrib / totalMass) * 100 : 0;
  }

  // Sacred fit for molar mass
  const sacredFit = await fitSingleValue(totalMass);

  // Bond analysis
  const bonds = estimateBonds(parsed);
  const bondSacredFit = await fitSingleValue(bonds.bondEnergy);

  // Ternary signature
  const signature = ternarySignature(totalAtoms, totalElectrons, bonds.totalBonds);

  // Coptic — use sum of atomic numbers
  const atomicSum = elements.reduce((s, e) => s + e.element.number * e.count, 0);
  const coptic = copticGlyph(atomicSum);

  return {
    formula,
    molarMass: totalMass,
    elements,
    totalAtoms,
    totalElectrons,
    sacredFit: { ...sacredFit.fit, computed: sacredFit.computed, error_pct: sacredFit.error_pct },
    bonds,
    bondSacredFit: { ...bondSacredFit.fit, computed: bondSacredFit.computed, error_pct: bondSacredFit.error_pct },
    signature,
    coptic,
  };
}

/** Single element analysis — returns ElementResult */
export async function analyzeElement(query: string): Promise<ElementResult | null> {
  const el = getElement(query);
  if (!el) return null;

  const entry = el as ElementEntry;

  // Balanced ternary of atomic number
  const bt = toBalancedTernary(entry.number);

  // Sacred fit for mass
  const massFit = await fitSingleValue(entry.mass);
  const sacredMass: SacredFit = { ...massFit.fit, computed: massFit.computed, error_pct: massFit.error_pct };

  // Sacred fit for ionization energy (if available)
  let sacredIE: SacredFit | undefined;
  if (entry.ionization_energy) {
    const ieFit = await fitSingleValue(entry.ionization_energy);
    sacredIE = { ...ieFit.fit, computed: ieFit.computed, error_pct: ieFit.error_pct };
  }

  // Sacred fit for electronegativity (if available)
  let sacredEN: SacredFit | undefined;
  if (entry.electronegativity) {
    const enFit = await fitSingleValue(entry.electronegativity);
    sacredEN = { ...enFit.fit, computed: enFit.computed, error_pct: enFit.error_pct };
  }

  // Fibonacci / Lucas checks on atomic number
  const fib = isFibonacci(entry.number);
  const luc = isLucas(entry.number);

  // Golden angle
  const golden = goldenAngle(entry.number);

  // Coptic
  const coptic = copticGlyph(entry.number);

  return { element: entry, balancedTernary: bt, sacredMass, sacredIE, sacredEN, fibonacci: fib, lucas: luc, golden, coptic };
}
