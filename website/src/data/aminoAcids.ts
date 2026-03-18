// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BIOLOGY v14.0 — AMINO ACIDS
// 20 standard amino acids with sacred properties
// ═══════════════════════════════════════════════════════════════════════════════

export interface AminoAcid {
  name: string;
  code3: string;      // 3-letter code (e.g., "Ala")
  code1: string;      // 1-letter code (e.g., "A")
  mass: number;       // molecular weight (Daltons)
  pKa: number;        // isoelectric point
  codons: string[];   // DNA codon triplets
  fibonacciIndex?: number;  // if mass is near Fibonacci number
  phiRelated?: boolean;     // structurally related to φ
}

// 20 standard amino acids with sacred properties
export const AMINO_ACIDS: Record<string, AminoAcid> = {
  // Nonpolar, aliphatic
  A: { name: 'Alanine', code3: 'Ala', code1: 'A', mass: 89.09, pKa: 6.01, codons: ['GCT', 'GCC', 'GCA', 'GCG'], fibonacciIndex: 5 }, // 89 ≈ 89 (Fibonacci F11)
  G: { name: 'Glycine', code3: 'Gly', code1: 'G', mass: 75.07, pKa: 5.97, codons: ['GGT', 'GGC', 'GGA', 'GGG'] },
  I: { name: 'Isoleucine', code3: 'Ile', code1: 'I', mass: 131.17, pKa: 6.02, codons: ['ATT', 'ATC', 'ATA'] },
  L: { name: 'Leucine', code3: 'Leu', code1: 'L', mass: 131.17, pKa: 5.98, codons: ['TTA', 'TTG', 'CTT', 'CTC', 'CTA', 'CTG'], phiRelated: true }, // 6 codons (sacred)
  V: { name: 'Valine', code3: 'Val', code1: 'V', mass: 117.15, pKa: 5.97, codons: ['GTT', 'GTC', 'GTA', 'GTG'] },
  P: { name: 'Proline', code3: 'Pro', code1: 'P', mass: 115.13, pKa: 6.30, codons: ['CCT', 'CCC', 'CCA', 'CCG'] },

  // Aromatic
  F: { name: 'Phenylalanine', code3: 'Phe', code1: 'F', mass: 165.19, pKa: 5.48, codons: ['TTT', 'TTC'], phiRelated: true }, // Benzene ring φ-resonance
  W: { name: 'Tryptophan', code3: 'Trp', code1: 'W', mass: 204.23, pKa: 5.89, codons: ['TGG'] }, // Largest, indole ring
  Y: { name: 'Tyrosine', code3: 'Tyr', code1: 'Y', mass: 181.19, pKa: 5.66, codons: ['TAT', 'TAC'] },

  // Polar, uncharged
  C: { name: 'Cysteine', code3: 'Cys', code1: 'C', mass: 121.16, pKa: 5.07, codons: ['TGT', 'TGC'] },
  M: { name: 'Methionine', code3: 'Met', code1: 'M', mass: 149.21, pKa: 5.74, codons: ['ATG'] }, // START codon
  N: { name: 'Asparagine', code3: 'Asn', code1: 'N', mass: 132.12, pKa: 5.41, codons: ['AAT', 'AAC'] },
  Q: { name: 'Glutamine', code3: 'Gln', code1: 'Q', mass: 146.15, pKa: 5.65, codons: ['CAA', 'CAG'] },
  S: { name: 'Serine', code3: 'Ser', code1: 'S', mass: 105.09, pKa: 5.68, codons: ['TCT', 'TCC', 'TCA', 'TCG', 'AGT', 'AGC'] },
  T: { name: 'Threonine', code3: 'Thr', code1: 'T', mass: 119.12, pKa: 5.60, codons: ['ACT', 'ACC', 'ACA', 'ACG'] },

  // Positively charged
  H: { name: 'Histidine', code3: 'His', code1: 'H', mass: 155.16, pKa: 7.59, codons: ['CAT', 'CAC'] },
  K: { name: 'Lysine', code3: 'Lys', code1: 'K', mass: 146.19, pKa: 9.74, codons: ['AAA', 'AAG'] },
  R: { name: 'Arginine', code3: 'Arg', code1: 'R', mass: 174.20, pKa: 10.76, codons: ['CGT', 'CGC', 'CGA', 'CGG', 'AGA', 'AGG'] },

  // Negatively charged
  D: { name: 'Aspartic acid', code3: 'Asp', code1: 'D', mass: 133.10, pKa: 2.77, codons: ['GAT', 'GAC'] },
  E: { name: 'Glutamic acid', code3: 'Glu', code1: 'E', mass: 147.13, pKa: 3.22, codons: ['GAA', 'GAG'] },
};

// Genetic code table (64 codons → 20 amino acids + stop)
// RNA codons (U instead of T)
export const CODON_TABLE_RNA: Record<string, string> = {
  // Phenylalanine
  'UUU': 'F', 'UUC': 'F',
  // Leucine
  'UUA': 'L', 'UUG': 'L', 'CUU': 'L', 'CUC': 'L', 'CUA': 'L', 'CUG': 'L',
  // Isoleucine
  'AUU': 'I', 'AUC': 'I', 'AUA': 'I',
  // Methionine (START)
  'AUG': 'M',
  // Valine
  'GUU': 'V', 'GUC': 'V', 'GUA': 'V', 'GUG': 'V',
  // Serine
  'UCU': 'S', 'UCC': 'S', 'UCA': 'S', 'UCG': 'S', 'AGU': 'S', 'AGC': 'S',
  // Proline
  'CCU': 'P', 'CCC': 'P', 'CCA': 'P', 'CCG': 'P',
  // Threonine
  'ACU': 'T', 'ACC': 'T', 'ACA': 'T', 'ACG': 'T',
  // Alanine
  'GCU': 'A', 'GCC': 'A', 'GCA': 'A', 'GCG': 'A',
  // Tyrosine
  'UAU': 'Y', 'UAC': 'Y',
  // STOP
  'UAA': '*', 'UAG': '*', 'UGA': '*',
  // Histidine
  'CAU': 'H', 'CAC': 'H',
  // Glutamine
  'CAA': 'Q', 'CAG': 'Q',
  // Asparagine
  'AAU': 'N', 'AAC': 'N',
  // Lysine
  'AAA': 'K', 'AAG': 'K',
  // Aspartic acid
  'GAU': 'D', 'GAC': 'D',
  // Glutamic acid
  'GAA': 'E', 'GAG': 'E',
  // Cysteine
  'UGU': 'C', 'UGC': 'C',
  // Tryptophan
  'UGG': 'W',
  // Arginine
  'CGU': 'R', 'CGC': 'R', 'CGA': 'R', 'CGG': 'R', 'AGA': 'R', 'AGG': 'R',
  // Glycine
  'GGU': 'G', 'GGC': 'G', 'GGA': 'G', 'GGG': 'G',
};

// DNA codons (T instead of U)
export const CODON_TABLE_DNA: Record<string, string> = Object.fromEntries(
  Object.entries(CODON_TABLE_RNA).map(([k, v]) => [k.replace(/U/g, 'T'), v])
);

// Get amino acid by single-letter code
export function getAminoAcid(code: string): AminoAcid | null {
  return AMINO_ACIDS[code.toUpperCase()] || null;
}

// Get amino acid from RNA codon
export function getCodonRna(codon: string): string | null {
  return CODON_TABLE_RNA[codon.toUpperCase()] || null;
}

// Get amino acid from DNA codon
export function getCodonDna(codon: string): string | null {
  return CODON_TABLE_DNA[codon.toUpperCase()] || null;
}

// Translate RNA sequence to amino acids
export function translateRna(rna: string): string[] {
  const proteins: string[] = [];
  for (let i = 0; i + 2 < rna.length; i += 3) {
    const codon = rna.substring(i, i + 3);
    const aa = getCodonRna(codon);
    if (aa === '*') break; // STOP codon
    if (aa) proteins.push(aa);
  }
  return proteins;
}

// Translate DNA sequence to amino acids
export function translateDna(dna: string): string[] {
  // Convert T to U for RNA
  const rna = dna.replace(/T/gi, 'U');
  return translateRna(rna);
}

// Get amino acid objects from DNA sequence
export function translateDnaToProteins(dna: string): AminoAcid[] {
  const codes = translateDna(dna);
  const proteins: AminoAcid[] = [];
  for (const code of codes) {
    const aa = getAminoAcid(code);
    if (aa) proteins.push(aa);
  }
  return proteins;
}

// Check if amino acid mass is near a Fibonacci number
export function isFibonacciMass(mass: number): boolean {
  const fib = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377];
  return fib.some(f => Math.abs(mass - f * 10) < 2); // Check against scaled Fibonacci
}

// Get phi-related amino acids (aromatic rings, golden proportion structures)
export function getPhiRelatedAminoAcids(): AminoAcid[] {
  return Object.values(AMINO_ACIDS).filter(aa => aa.phiRelated);
}
