// ═══════════════════════════════════════════════════════════════════════════════
// 3D MOLECULE GEOMETRIES — Hardcoded atom positions for common molecules
// Used by MoleculeViewer3D for ball-and-stick rendering
// ═══════════════════════════════════════════════════════════════════════════════

export interface Atom3DData {
  element: string;
  position: [number, number, number];
}

export interface Bond3DData {
  from: number; // atom index
  to: number;   // atom index
  order: 1 | 2 | 3;
}

export interface MoleculeGeometry {
  atoms: Atom3DData[];
  bonds: Bond3DData[];
}

// ═══════════════════════════════════════════════════════════════════════════════
// HARDCODED GEOMETRIES
// ═══════════════════════════════════════════════════════════════════════════════

export const GEOMETRIES: Record<string, MoleculeGeometry> = {
  // ─── Diatomic ───────────────────────────────────────────
  H2: {
    atoms: [
      { element: 'H', position: [-0.37, 0, 0] },
      { element: 'H', position: [0.37, 0, 0] },
    ],
    bonds: [{ from: 0, to: 1, order: 1 }],
  },
  O2: {
    atoms: [
      { element: 'O', position: [-0.6, 0, 0] },
      { element: 'O', position: [0.6, 0, 0] },
    ],
    bonds: [{ from: 0, to: 1, order: 2 }],
  },
  N2: {
    atoms: [
      { element: 'N', position: [-0.55, 0, 0] },
      { element: 'N', position: [0.55, 0, 0] },
    ],
    bonds: [{ from: 0, to: 1, order: 3 }],
  },
  HCl: {
    atoms: [
      { element: 'H', position: [-0.64, 0, 0] },
      { element: 'Cl', position: [0.64, 0, 0] },
    ],
    bonds: [{ from: 0, to: 1, order: 1 }],
  },
  NaCl: {
    atoms: [
      { element: 'Na', position: [-1.18, 0, 0] },
      { element: 'Cl', position: [1.18, 0, 0] },
    ],
    bonds: [{ from: 0, to: 1, order: 1 }],
  },

  // ─── Triatomic ──────────────────────────────────────────
  H2O: {
    atoms: [
      { element: 'O', position: [0, 0, 0] },
      { element: 'H', position: [-0.76, 0.59, 0] },
      { element: 'H', position: [0.76, 0.59, 0] },
    ],
    bonds: [
      { from: 0, to: 1, order: 1 },
      { from: 0, to: 2, order: 1 },
    ],
  },
  CO2: {
    atoms: [
      { element: 'C', position: [0, 0, 0] },
      { element: 'O', position: [-1.16, 0, 0] },
      { element: 'O', position: [1.16, 0, 0] },
    ],
    bonds: [
      { from: 0, to: 1, order: 2 },
      { from: 0, to: 2, order: 2 },
    ],
  },

  // ─── 4 atoms ────────────────────────────────────────────
  NH3: {
    atoms: [
      { element: 'N', position: [0, 0.37, 0] },
      { element: 'H', position: [-0.94, -0.31, 0] },
      { element: 'H', position: [0.47, -0.31, 0.82] },
      { element: 'H', position: [0.47, -0.31, -0.82] },
    ],
    bonds: [
      { from: 0, to: 1, order: 1 },
      { from: 0, to: 2, order: 1 },
      { from: 0, to: 3, order: 1 },
    ],
  },

  // ─── 5 atoms (Tetrahedral) ──────────────────────────────
  CH4: {
    atoms: [
      { element: 'C', position: [0, 0, 0] },
      { element: 'H', position: [0.63, 0.63, 0.63] },
      { element: 'H', position: [-0.63, -0.63, 0.63] },
      { element: 'H', position: [-0.63, 0.63, -0.63] },
      { element: 'H', position: [0.63, -0.63, -0.63] },
    ],
    bonds: [
      { from: 0, to: 1, order: 1 },
      { from: 0, to: 2, order: 1 },
      { from: 0, to: 3, order: 1 },
      { from: 0, to: 4, order: 1 },
    ],
  },
  HNO3: {
    atoms: [
      { element: 'N', position: [0, 0, 0] },
      { element: 'O', position: [1.2, 0.2, 0] },
      { element: 'O', position: [-0.6, 1.04, 0] },
      { element: 'O', position: [-0.6, -1.04, 0] },
      { element: 'H', position: [-1.3, -1.5, 0] },
    ],
    bonds: [
      { from: 0, to: 1, order: 2 },
      { from: 0, to: 2, order: 1 },
      { from: 0, to: 3, order: 1 },
      { from: 3, to: 4, order: 1 },
    ],
  },

  // ─── Calcium hydroxide ──────────────────────────────────
  'Ca(OH)2': {
    atoms: [
      { element: 'Ca', position: [0, 0, 0] },
      { element: 'O', position: [-1.2, 0.8, 0] },
      { element: 'H', position: [-2.0, 1.3, 0] },
      { element: 'O', position: [1.2, -0.8, 0] },
      { element: 'H', position: [2.0, -1.3, 0] },
    ],
    bonds: [
      { from: 0, to: 1, order: 1 },
      { from: 1, to: 2, order: 1 },
      { from: 0, to: 3, order: 1 },
      { from: 3, to: 4, order: 1 },
    ],
  },

  // ─── Sulfuric acid ──────────────────────────────────────
  H2SO4: {
    atoms: [
      { element: 'S', position: [0, 0, 0] },
      { element: 'O', position: [1.0, 1.0, 0] },
      { element: 'O', position: [-1.0, 1.0, 0] },
      { element: 'O', position: [1.0, -1.0, 0] },
      { element: 'O', position: [-1.0, -1.0, 0] },
      { element: 'H', position: [1.7, -1.5, 0] },
      { element: 'H', position: [-1.7, -1.5, 0] },
    ],
    bonds: [
      { from: 0, to: 1, order: 2 },
      { from: 0, to: 2, order: 2 },
      { from: 0, to: 3, order: 1 },
      { from: 0, to: 4, order: 1 },
      { from: 3, to: 5, order: 1 },
      { from: 4, to: 6, order: 1 },
    ],
  },

  // ─── Ethanol ────────────────────────────────────────────
  C2H5OH: {
    atoms: [
      { element: 'C', position: [-0.75, 0, 0] },
      { element: 'C', position: [0.75, 0, 0] },
      { element: 'O', position: [1.5, 1.1, 0] },
      { element: 'H', position: [2.2, 1.5, 0] },
      { element: 'H', position: [-1.2, 0.6, 0.8] },
      { element: 'H', position: [-1.2, 0.6, -0.8] },
      { element: 'H', position: [-1.2, -0.95, 0] },
      { element: 'H', position: [1.2, -0.5, 0.85] },
      { element: 'H', position: [1.2, -0.5, -0.85] },
    ],
    bonds: [
      { from: 0, to: 1, order: 1 },
      { from: 1, to: 2, order: 1 },
      { from: 2, to: 3, order: 1 },
      { from: 0, to: 4, order: 1 },
      { from: 0, to: 5, order: 1 },
      { from: 0, to: 6, order: 1 },
      { from: 1, to: 7, order: 1 },
      { from: 1, to: 8, order: 1 },
    ],
  },

  // ─── Benzene ring ───────────────────────────────────────
  C6H6: {
    atoms: [
      // Carbon ring (flat hexagon)
      { element: 'C', position: [1.4, 0, 0] },
      { element: 'C', position: [0.7, 1.21, 0] },
      { element: 'C', position: [-0.7, 1.21, 0] },
      { element: 'C', position: [-1.4, 0, 0] },
      { element: 'C', position: [-0.7, -1.21, 0] },
      { element: 'C', position: [0.7, -1.21, 0] },
      // Hydrogens
      { element: 'H', position: [2.48, 0, 0] },
      { element: 'H', position: [1.24, 2.15, 0] },
      { element: 'H', position: [-1.24, 2.15, 0] },
      { element: 'H', position: [-2.48, 0, 0] },
      { element: 'H', position: [-1.24, -2.15, 0] },
      { element: 'H', position: [1.24, -2.15, 0] },
    ],
    bonds: [
      { from: 0, to: 1, order: 2 }, { from: 1, to: 2, order: 1 },
      { from: 2, to: 3, order: 2 }, { from: 3, to: 4, order: 1 },
      { from: 4, to: 5, order: 2 }, { from: 5, to: 0, order: 1 },
      { from: 0, to: 6, order: 1 }, { from: 1, to: 7, order: 1 },
      { from: 2, to: 8, order: 1 }, { from: 3, to: 9, order: 1 },
      { from: 4, to: 10, order: 1 }, { from: 5, to: 11, order: 1 },
    ],
  },

  // ─── Glucose (simplified chair) ─────────────────────────
  C6H12O6: {
    atoms: [
      // Ring: C1-C5 + O (pyranose ring)
      { element: 'C', position: [1.2, 0.3, 0.3] },
      { element: 'C', position: [0.6, 1.3, -0.5] },
      { element: 'C', position: [-0.9, 1.2, -0.3] },
      { element: 'C', position: [-1.4, 0, 0.4] },
      { element: 'C', position: [-0.6, -1.0, -0.3] },
      { element: 'O', position: [0.8, -0.9, 0.1] },
      // Substituents: OH groups + CH2OH
      { element: 'O', position: [2.5, 0.4, 0.0] },
      { element: 'O', position: [1.1, 2.5, -0.2] },
      { element: 'O', position: [-1.5, 2.2, 0.3] },
      { element: 'O', position: [-2.7, -0.1, 0.1] },
      { element: 'C', position: [-1.0, -2.3, 0.3] },
      { element: 'O', position: [-0.2, -3.3, -0.2] },
      // Hydrogen placeholders (simplified — only some shown)
      { element: 'H', position: [1.2, 0.3, 1.4] },
      { element: 'H', position: [0.9, 1.3, -1.6] },
      { element: 'H', position: [-1.3, 1.2, -1.4] },
      { element: 'H', position: [-1.3, 0.0, 1.5] },
      { element: 'H', position: [-0.6, -1.0, -1.4] },
      { element: 'H', position: [3.0, 0.9, 0.5] },
      { element: 'H', position: [0.6, 3.1, -0.6] },
      { element: 'H', position: [-2.0, 2.8, -0.1] },
      { element: 'H', position: [-3.1, -0.7, 0.6] },
      { element: 'H', position: [-2.1, -2.4, 0.1] },
      { element: 'H', position: [-0.8, -2.3, 1.4] },
      { element: 'H', position: [0.4, -3.8, 0.3] },
    ],
    bonds: [
      // Ring bonds
      { from: 0, to: 1, order: 1 }, { from: 1, to: 2, order: 1 },
      { from: 2, to: 3, order: 1 }, { from: 3, to: 4, order: 1 },
      { from: 4, to: 5, order: 1 }, { from: 5, to: 0, order: 1 },
      // OH/CH2OH
      { from: 0, to: 6, order: 1 }, { from: 1, to: 7, order: 1 },
      { from: 2, to: 8, order: 1 }, { from: 3, to: 9, order: 1 },
      { from: 4, to: 10, order: 1 }, { from: 10, to: 11, order: 1 },
      // C-H bonds
      { from: 0, to: 12, order: 1 }, { from: 1, to: 13, order: 1 },
      { from: 2, to: 14, order: 1 }, { from: 3, to: 15, order: 1 },
      { from: 4, to: 16, order: 1 },
      // O-H bonds
      { from: 6, to: 17, order: 1 }, { from: 7, to: 18, order: 1 },
      { from: 8, to: 19, order: 1 }, { from: 9, to: 20, order: 1 },
      { from: 10, to: 21, order: 1 }, { from: 10, to: 22, order: 1 },
      { from: 11, to: 23, order: 1 },
    ],
  },
};

// ═══════════════════════════════════════════════════════════════════════════════
// VSEPR FALLBACK — Generate geometry for unknown molecules
// ═══════════════════════════════════════════════════════════════════════════════

/** Generate a VSEPR-based approximate geometry from parsed formula */
export function generateVSEPR(parsed: { symbol: string; count: number }[]): MoleculeGeometry {
  const atoms: Atom3DData[] = [];
  const bonds: Bond3DData[] = [];

  // Flatten into individual atoms
  const allAtoms: string[] = [];
  for (const { symbol, count } of parsed) {
    for (let i = 0; i < count; i++) allAtoms.push(symbol);
  }

  if (allAtoms.length === 0) return { atoms: [], bonds: [] };
  if (allAtoms.length === 1) {
    atoms.push({ element: allAtoms[0], position: [0, 0, 0] });
    return { atoms, bonds };
  }

  // Place central atom at origin (heaviest non-H element)
  const centralIdx = allAtoms.findIndex(s => s !== 'H') >= 0
    ? allAtoms.findIndex(s => s !== 'H')
    : 0;
  const central = allAtoms[centralIdx];
  atoms.push({ element: central, position: [0, 0, 0] });

  // Remove central from list
  const remaining = [...allAtoms];
  remaining.splice(centralIdx, 1);
  const n = remaining.length;

  // Distribute remaining atoms in 3D based on count
  for (let i = 0; i < n; i++) {
    const r = 1.2 + (remaining[i] === 'H' ? 0 : 0.3);
    let x: number, y: number, z: number;

    if (n === 1) {
      [x, y, z] = [r, 0, 0];
    } else if (n === 2) {
      // Linear
      const angle = i === 0 ? 0 : Math.PI;
      [x, y, z] = [r * Math.cos(angle), r * Math.sin(angle), 0];
    } else if (n === 3) {
      // Trigonal planar
      const angle = (i * 2 * Math.PI) / 3;
      [x, y, z] = [r * Math.cos(angle), r * Math.sin(angle), 0];
    } else if (n === 4) {
      // Tetrahedral
      const tet: [number, number, number][] = [
        [1, 1, 1], [-1, -1, 1], [-1, 1, -1], [1, -1, -1],
      ];
      const s = r / Math.sqrt(3);
      [x, y, z] = [tet[i][0] * s, tet[i][1] * s, tet[i][2] * s];
    } else if (n === 5) {
      // Trigonal bipyramidal
      if (i < 3) {
        const angle = (i * 2 * Math.PI) / 3;
        [x, y, z] = [r * Math.cos(angle), r * Math.sin(angle), 0];
      } else {
        [x, y, z] = [0, 0, i === 3 ? r : -r];
      }
    } else if (n === 6) {
      // Octahedral
      const oct: [number, number, number][] = [
        [1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1],
      ];
      [x, y, z] = [oct[i][0] * r, oct[i][1] * r, oct[i][2] * r];
    } else {
      // Spherical distribution (Fibonacci spiral on sphere)
      const golden = (1 + Math.sqrt(5)) / 2;
      const theta = Math.acos(1 - 2 * (i + 0.5) / n);
      const phi = 2 * Math.PI * (i / golden);
      [x, y, z] = [
        r * Math.sin(theta) * Math.cos(phi),
        r * Math.sin(theta) * Math.sin(phi),
        r * Math.cos(theta),
      ];
    }

    atoms.push({ element: remaining[i], position: [x, y, z] });
    bonds.push({ from: 0, to: i + 1, order: 1 });
  }

  return { atoms, bonds };
}

/** Get geometry: hardcoded if available, VSEPR fallback otherwise */
export function getGeometry(formula: string, parsed: { symbol: string; count: number }[]): MoleculeGeometry {
  if (GEOMETRIES[formula]) return GEOMETRIES[formula];
  return generateVSEPR(parsed);
}
